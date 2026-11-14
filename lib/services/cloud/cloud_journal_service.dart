import 'dart:convert';

import 'package:http/http.dart' as http;

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
      date: DateTime.tryParse(json['event_date']?.toString() ?? '') ?? DateTime.now(),
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
    final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    if (data['code'] == 401) {
      throw StateError('登录失效，已切换成本地数据，请重新登录');
    }
    if (data['code'] != 0) {
      throw StateError(data['msg']?.toString() ?? '云端操作失败');
    }
    final rows = (data['data'] as List?) ?? const [];
    return rows
        .map((e) => JournalEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 当月记录。mode：0=创建日期，1=观看/阅读日期
  Future<List<JournalEvent>> fetchMonth(int year, int month, int mode) =>
      _get('/month', {'year': '$year', 'month': '$month', 'mode': '$mode'});

  /// 当年记录
  Future<List<JournalEvent>> fetchYear(int year, int mode) =>
      _get('/year', {'year': '$year', 'mode': '$mode'});
}
