import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/server_config.dart';
import 'cloud_auth_service.dart';

/// 探索页（数据统计/漫步）聚合接口客户端。
/// 统计只回轻量行（实体 fromJson 对缺列有默认值兜底）；漫步为服务端加权随机抽卡。
class CloudExploreService {
  CloudExploreService._();
  static final CloudExploreService instance = CloudExploreService._();

  String get _base => '${ServerConfig.cloudApiBase}/app/explore';
  String get _token => CloudAuthService.instance.token;

  Future<dynamic> _get(String path, Map<String, String> query) async {
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
    return data['data'];
  }

  /// 数据统计轻量行：返回 movies/books/games/notes 四个键（按 types 裁剪），值为行数组
  Future<Map<String, dynamic>> fetchStats(List<String> types) async {
    final data = await _get('/stats', {'types': types.join(',')});
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// 漫步抽卡：每行带 type 鉴别字段，exclude 为已展示过的实体 id
  Future<List<Map<String, dynamic>>> fetchStroll({
    required List<String> types,
    required int limit,
    List<String> exclude = const [],
  }) async {
    final data = await _get('/stroll', {
      'types': types.join(','),
      'limit': '$limit',
      if (exclude.isNotEmpty) 'exclude': exclude.join(','),
    });
    if (data is! List) return const [];
    return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
