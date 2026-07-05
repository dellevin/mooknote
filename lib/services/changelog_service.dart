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
  static final _apiUrl = '${ServerConfig.apiBase}/changelog';

  /// 获取更新日志列表
  static Future<List<ChangelogItem>> fetchChangelog() async {
    try {
      final resp = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
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
  /// v0.1.9 → 当成数字 "0.19" = 0.19，0.1.88 → "0.188" = 0.188，所以 0.19 > 0.188
  /// 实现方式：去掉 v，把第一个点后的数字拼接再转 double 比较
  static int compareVersion(String a, String b) {
    double toNum(String v) {
      final s = v.replaceFirst('v', '');
      final dot = s.indexOf('.');
      if (dot == -1) return double.tryParse(s) ?? 0;
      // "0.1.9" → "0." + "19" = "0.19"；"0.1.88" → "0." + "188" = "0.188"
      final major = s.substring(0, dot + 1); // "0."
      final rest = s.substring(dot + 1).replaceAll('.', ''); // "19" 或 "188"
      return double.tryParse('$major$rest') ?? 0;
    }

    final aVal = toNum(a);
    final bVal = toNum(b);
    debugPrint('[Update] compare: "$a"→$aVal vs "$b"→$bVal');
    if (aVal > bVal) return 1;
    if (aVal < bVal) return -1;
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
