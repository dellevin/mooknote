import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/database_helper.dart';
import '../utils/server_config.dart';
import '../utils/user_prefs.dart';

/// 徽章定义（服务端下发）
/// 解锁判定完全由 [ruleSql] 决定：在本地数据库执行该单条 SELECT，
/// 取结果首行首列数值与 [threshold] 比较。客户端不识别任何规则含义。
/// [metric] 仅作为 App 端分组展示类别。
class BadgeDef {
  final String slug;
  final String name;
  final String desc;
  final String icon; // SVG 代码
  final String metric; // 分组类别（观影/阅读/游戏/评论/其他）
  final String ruleSql;
  final int threshold;

  const BadgeDef({
    required this.slug,
    required this.name,
    required this.desc,
    required this.icon,
    required this.metric,
    required this.ruleSql,
    required this.threshold,
  });

  factory BadgeDef.fromJson(Map<String, dynamic> json) => BadgeDef(
        slug: json['slug'] ?? '',
        name: json['name'] ?? '',
        desc: json['desc'] ?? '',
        icon: json['icon'] ?? '',
        metric: json['metric'] ?? '',
        ruleSql: json['rule_sql'] ?? '',
        threshold: (json['threshold'] as num?)?.toInt() ?? 1,
      );
}

/// 成就徽章服务：拉取服务端定义，在本地数据库执行规则 SQL 判定解锁，
/// 解锁后静默上报。规则完全由服务端配置，客户端只是执行器。
class BadgeService {
  BadgeService._();

  static final _url = '${ServerConfig.apiBase}/badges';

  /// 拉取徽章定义（网络失败时回退本地缓存，无缓存返回空）
  static Future<List<BadgeDef>> fetchDefs() async {
    final fresh = await tryFetchFresh();
    if (fresh != null) return fresh;
    return _parseDefs(UserPrefs().badgeDefsCache);
  }

  /// 仅从网络拉取最新定义并写缓存；网络失败返回 null（用于判断离线）
  static Future<List<BadgeDef>?> tryFetchFresh() async {
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
    return null;
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

  /// 校验规则只允许单条 SELECT 语句（服务端已校验一次，这里兜底）
  static String? _sanitizeRule(String sql) {
    var s = sql.trim();
    if (s.endsWith(';')) s = s.substring(0, s.length - 1).trim();
    if (s.isEmpty || s.contains(';')) return null;
    if (!s.toUpperCase().startsWith('SELECT')) return null;
    return s;
  }

  /// 注入上下文临时表：数据库以外的值（first_use / streak_days）
  static Future<void> _ensureCtxTable(dynamic db) async {
    await db.execute(
        'CREATE TEMP TABLE IF NOT EXISTS _badge_ctx (key TEXT PRIMARY KEY, value INTEGER)');
    await db.execute('DELETE FROM _badge_ctx');
    await db.insert('_badge_ctx', {'key': 'first_use', 'value': 1});
    await db.insert(
        '_badge_ctx', {'key': 'streak_days', 'value': UserPrefs().streakDays});
  }

  /// 执行所有徽章的规则 SQL，返回 slug → 当前值（规则缺失/非法/出错的不包含）
  static Future<Map<String, int>> computeValues(List<BadgeDef> defs) async {
    final db = await DatabaseHelper.instance.database;
    await _ensureCtxTable(db);
    final values = <String, int>{};
    for (final d in defs) {
      final sql = _sanitizeRule(d.ruleSql);
      if (sql == null) continue;
      try {
        final rows = await db.rawQuery(sql);
        if (rows.isEmpty) continue;
        final v = rows.first.values.first;
        values[d.slug] = (v as num?)?.toInt() ?? 0;
      } catch (_) {}
    }
    return values;
  }

  /// 评估解锁：执行规则 SQL 对比阈值，持久化新解锁并静默上报，返回新解锁的徽章
  static Future<List<BadgeDef>> evaluate(List<BadgeDef> defs) async {
    final values = await computeValues(defs);
    final prefs = UserPrefs();
    final unlocked = Map<String, String>.from(prefs.badgeUnlocked);
    final nowIso = DateTime.now().toIso8601String();
    final newOnes = <BadgeDef>[];
    for (final d in defs) {
      if (unlocked.containsKey(d.slug)) continue;
      if ((values[d.slug] ?? 0) >= d.threshold) {
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
