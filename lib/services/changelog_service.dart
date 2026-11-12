import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/server_config.dart';

/// 更新日志数据模型
class ChangelogItem {
  final String version;
  final String date;
  final List<String> features;

  ChangelogItem({
    required this.version,
    required this.date,
    required this.features,
  });

  factory ChangelogItem.fromJson(Map<String, dynamic> json) {
    return ChangelogItem(
      version: json['version'] ?? '',
      date: json['date'] ?? '',
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// 版本更新检查服务
class ChangelogService {
  static const _apiUrl = '${ServerConfig.apiBase}/changelog';

  /// 获取更新日志列表
  static Future<List<ChangelogItem>> fetchChangelog() async {
    try {
      final resp = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final items = (data['items'] as List<dynamic>?)
                ?.map((e) => ChangelogItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        return items;
      }
    } catch (_) {}
    return [];
  }

  /// 获取最新版本号
  static Future<String?> fetchLatestVersion() async {
    final items = await fetchChangelog();
    if (items.isNotEmpty) return items.first.version;
    return null;
  }

  /// 比较两版本号，a > b 则返回 1，a < b 返回 -1，相等返回 0
  /// 去掉 v 前缀后按 '.' 拆段，逐段按整数比较（如 0.1.100 > 0.1.99）
  static int compareVersion(String a, String b) {
    List<int> toSegments(String v) => v
        .replaceFirst('v', '')
        .split('.')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .toList();

    final aSeg = toSegments(a);
    final bSeg = toSegments(b);
    final len = aSeg.length > bSeg.length ? aSeg.length : bSeg.length;
    for (var i = 0; i < len; i++) {
      final x = i < aSeg.length ? aSeg[i] : 0;
      final y = i < bSeg.length ? bSeg[i] : 0;
      if (x != y) {
        debugPrint('[Update] compare: "$a" vs "$b" → 段$i $x vs $y');
        return x > y ? 1 : -1;
      }
    }
    return 0;
  }

  /// 检查是否有新版本（远程 > 本地）
  static Future<bool> hasUpdate() async {
    final latest = await fetchLatestVersion();
    if (latest == null) return false;
    final info = await PackageInfo.fromPlatform();
    final local = 'v${info.version}';
    debugPrint('[Update] 远程: $latest, 本地: $local');
    final result = compareVersion(latest, local) > 0;
    debugPrint('[Update] 远程 > 本地? $result');
    return result;
  }
}
