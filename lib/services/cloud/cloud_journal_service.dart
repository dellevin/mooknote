import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../l10n/app_strings.dart';
import '../../utils/server_config.dart';
import 'cloud_auth_service.dart';

/// 碎阅日历的一条轻量记录（服务端多表 UNION 聚合，仅含日历格子/卡片所需字段）。
/// 完整实体在点击进入详情时另行拉取，不在此传输。
class JournalEvent {
  /// movie / book / game
  final String type;
  final String parentId;
  final String title;
  final String? coverPath;
  final double? rating;

  /// 导演 / 作者 / 开发者（服务端存 JSON 字符串，已解析为列表）
  final List<String> creators;
  final DateTime date;

  const JournalEvent({
    required this.type,
    required this.parentId,
    required this.title,
    required this.coverPath,
    required this.rating,
    required this.creators,
    required this.date,
  });

  factory JournalEvent.fromJson(Map<String, dynamic> json) {
    final creatorsRaw = json['creators'];
    var creators = const <String>[];
    if (creatorsRaw is String && creatorsRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(creatorsRaw);
        if (parsed is List) creators = parsed.map((e) => e.toString()).toList();
      } catch (_) {
        // 历史脏数据不是合法 JSON 时按空列表处理
      }
    }
    return JournalEvent(
      type: json['type']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverPath: json['cover_path']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
      creators: creators,
      date: DateTime.parse(json['event_date'] as String),
    );
  }
}

/// 碎阅聚合接口客户端：按月/按年拉取，服务端按日期前缀过滤后只返轻量字段
class CloudJournalService {
  CloudJournalService._();
  static final CloudJournalService instance = CloudJournalService._();

  String get _base => '${ServerConfig.cloudApiBase}/app/journal';
  String get _token => CloudAuthService.instance.token;

  Future<List<JournalEvent>> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse(_base + path).replace(queryParameters: query);
    final resp = await http
        .get(uri, headers: {'token': _token})
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw StateError(
          '云端请求失败 (HTTP {code})'.trf({'code': resp.statusCode}));
    }
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('云端响应解析失败'.tr);
    }
    if (data['code'] == 401) {
      await CloudAuthService.instance.handleSessionExpired();
      throw StateError('登录失效，已切换成本地数据，请重新登录'.tr);
    }
    if (data['code'] != 0) {
      throw StateError(data['msg']?.toString() ?? '云端操作失败'.tr);
    }
    final rows = (data['data'] as List?) ?? const [];
    final result = <JournalEvent>[];
    for (final e in rows) {
      try {
        result.add(JournalEvent.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        // event_date 缺失/非法的脏数据无法定位日历日期，丢弃而非伪装成今天
        debugPrint('[CloudJournal] 跳过无法解析的记录: $e');
      }
    }
    return result;
  }

  /// 当月记录。mode：0=创建日期，1=观看/阅读日期
  Future<List<JournalEvent>> fetchMonth(int year, int month, int mode) =>
      _get('/month', {'year': '$year', 'month': '$month', 'mode': '$mode'});

  /// 当年记录
  Future<List<JournalEvent>> fetchYear(int year, int mode) =>
      _get('/year', {'year': '$year', 'mode': '$mode'});
}
