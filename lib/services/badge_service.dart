import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/database_helper.dart';
import '../utils/server_config.dart';
import '../utils/user_prefs.dart';

/// 徽章定义（服务端下发）
class BadgeDef {
  final String slug;
  final String name;
  final String desc;
  final String icon; // SVG 代码
  final String metric;
  final int threshold;

  const BadgeDef({
    required this.slug,
    required this.name,
    required this.desc,
    required this.icon,
    required this.metric,
    required this.threshold,
  });

  factory BadgeDef.fromJson(Map<String, dynamic> json) => BadgeDef(
        slug: json['slug'] ?? '',
        name: json['name'] ?? '',
        desc: json['desc'] ?? '',
        icon: json['icon'] ?? '',
        metric: json['metric'] ?? '',
        threshold: (json['threshold'] as num?)?.toInt() ?? 1,
      );
}

/// 成就徽章服务：拉取服务端定义，本地统计数据判定解锁，解锁后静默上报
class BadgeService {
  BadgeService._();

  static final _url = '${ServerConfig.apiBase}/badges';

  /// 拉取徽章定义（网络失败时回退本地缓存，无缓存返回空）
  static Future<List<BadgeDef>> fetchDefs() async {
    try {
      final resp = await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        await UserPrefs().setBadgeDefsCache(body);
        return _parseDefs(body);
      }
    } catch (_) {}
    return _parseDefs(UserPrefs().badgeDefsCache);
  }

  static List<BadgeDef> _parseDefs(String body) {
    if (body.isEmpty) return [];
    try {
      final items = (jsonDecode(body)['items'] as List<dynamic>?) ?? [];
      return items
          .map((e) => BadgeDef.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 同步读取本地缓存的徽章定义（无网络时的即时展示，如"我的"页浮动图标）
  static List<BadgeDef> cachedDefs() => _parseDefs(UserPrefs().badgeDefsCache);

  /// 记录今日活跃并返回连续使用天数（每天打开一次算一天，断签清零重计）
  static Future<int> recordActiveDay() async {
    final prefs = UserPrefs();
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (prefs.lastActiveDate == today) return prefs.streakDays;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month}-${yesterday.day}';
    final streak = prefs.lastActiveDate == yesterdayStr
        ? prefs.streakDays + 1
        : 1;
    await prefs.setLastActiveDate(today);
    await prefs.setStreakDays(streak);
    return streak;
  }

  /// 采集各指标当前值（排除回收站软删除数据）
  static Future<Map<String, int>> collectMetrics() async {
    final db = await DatabaseHelper.instance.database;
    Future<int> count(String table) async {
      final rows = await db
          .rawQuery('SELECT COUNT(*) AS c FROM $table WHERE is_deleted = 0');
      return (rows.first['c'] as num?)?.toInt() ?? 0;
    }

    return {
      'first_use': 1,
      'streak_days': UserPrefs().streakDays,
      'movie_count': await count('movies'),
      'book_count': await count('books'),
      'game_count': await count('games'),
      'movie_review_count': await count('movie_reviews'),
      'book_review_count': await count('book_reviews'),
      'game_review_count': await count('game_reviews'),
    };
  }

  /// 评估解锁：对比指标与阈值，持久化新解锁并静默上报，返回新解锁的徽章
  static Future<List<BadgeDef>> evaluate(
      List<BadgeDef> defs, Map<String, int> metrics) async {
    final prefs = UserPrefs();
    final unlocked = Map<String, String>.from(prefs.badgeUnlocked);
    final nowIso = DateTime.now().toIso8601String();
    final newOnes = <BadgeDef>[];
    for (final d in defs) {
      if (unlocked.containsKey(d.slug)) continue;
      if ((metrics[d.metric] ?? 0) >= d.threshold) {
        unlocked[d.slug] = nowIso;
        newOnes.add(d);
      }
    }
    if (newOnes.isNotEmpty) {
      await prefs.setBadgeUnlocked(unlocked);
      // 记入待庆祝队列，进入徽章页时统一弹出庆祝
      final pending = prefs.badgePendingCelebrate
        ..addAll(newOnes.map((e) => e.slug));
      await prefs.setBadgePendingCelebrate(pending);
      for (final d in newOnes) {
        _reportUnlock(d.slug);
      }
    }
    return newOnes;
  }

  /// 上报解锁（匿名，失败静默忽略）
  static Future<void> _reportUnlock(String slug) async {
    final deviceId = UserPrefs().deviceId;
    if (deviceId.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$_url/unlock'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_hash': deviceId, 'slug': slug}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}
