import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../utils/server_config.dart';
import 'cloud_auth_service.dart';
import 'cloud_stats_dto.dart';

/// 探索页（数据统计/漫步/相遇/已阅/人物/图库）聚合接口客户端。
/// 统计只回轻量行（实体 fromJson 对缺列有默认值兜底）；漫步为服务端加权随机抽卡。
class CloudExploreService {
  CloudExploreService._();
  static final CloudExploreService instance = CloudExploreService._();

  String get _base => '${ServerConfig.cloudApiBase}/app/explore';
  String get _token => CloudAuthService.instance.token;

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse(_base + path).replace(queryParameters: query);
    final http.Response resp;
    try {
      resp = await http
          .get(uri, headers: {'token': _token})
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('[CloudExplore] GET $uri 网络异常: $e');
      rethrow;
    }
    if (resp.statusCode != 200) {
      final snippet = utf8.decode(resp.bodyBytes, allowMalformed: true);
      debugPrint('[CloudExplore] GET $uri HTTP ${resp.statusCode}: '
          '${snippet.length > 300 ? snippet.substring(0, 300) : snippet}');
      throw StateError(
          '云端请求失败 (HTTP {code})'.trf({'code': resp.statusCode}));
    }
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (e) {
      final snippet = utf8.decode(resp.bodyBytes, allowMalformed: true);
      debugPrint('[CloudExplore] GET $uri 返回非 JSON: $e\n'
          '${snippet.length > 300 ? snippet.substring(0, 300) : snippet}');
      throw StateError('云端响应解析失败'.tr);
    }
    if (data['code'] == 401) {
      await CloudAuthService.instance.handleSessionExpired();
      throw StateError('登录失效，已切换成本地数据，请重新登录'.tr);
    }
    if (data['code'] != 0) {
      debugPrint('[CloudExplore] GET $uri 业务错误 code=${data['code']} msg=${data['msg']}');
      throw StateError(data['msg']?.toString() ?? '云端操作失败'.tr);
    }
    return data['data'];
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final resp = await http
        .post(Uri.parse(_base + path),
            headers: {'token': _token, 'Content-Type': 'application/json'},
            body: jsonEncode(body))
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
  }

  /// 数据统计聚合：服务端按统计页 10 个分区口径聚合后只回结果（数 KB），
  /// 含周/月/年三个 range，避免下发全量原始行（旧 stats 接口约 100KB）。
  Future<CloudStatsAggregate> fetchStatsAggregate(List<String> types) async {
    final data = await _get('/stats/aggregate', {'types': types.join(',')});
    return CloudStatsAggregate.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : const {});
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

  /// 相遇统计：影视/书籍/笔记记录数、笔记总字数、图片总数。
  /// 后端 SUM(...) 返回 Long，会被 Jackson 序列化为字符串（如 "239"），
  /// COUNT(*) 的 Integer 仍是数字，两种都要兼容，直接 as num 会抛 TypeError。
  Future<Map<String, int>> fetchEncounter() async {
    final data = await _get('/encounter', const {});
    if (data is! Map) return const {};
    return data.map((k, v) => MapEntry(
        k.toString(),
        v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0)));
  }

  /// 已阅轻量行：返回 movies/books/games 键（按 types 裁剪），各域只含完成态
  Future<Map<String, dynamic>> fetchReviewed(List<String> types) async {
    final data = await _get('/reviewed', {'types': types.join(',')});
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// 人物名录轻量行分页：page 从 0 开始，作品行按创建时间倒序；
  /// 人物姓名由客户端在累积的作品行上聚合，hasMore 为影视/书籍两域任一还有后续
  Future<PersonsPage> fetchPersons({int page = 0, int size = 50}) async {
    final data = await _get('/persons', {'page': '$page', 'size': '$size'});
    final map = data is Map ? Map<String, dynamic>.from(data) : const {};
    return PersonsPage(
      movies: ((map['movies'] as List?) ?? const [])
          .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      books: ((map['books'] as List?) ?? const [])
          .map((e) => Book.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: map['hasMore'] == true,
    );
  }

  /// 图库瀑布流：服务端已扁平化并关联自定义名，按创建时间倒序
  Future<List<GalleryItem>> fetchGallery() async {
    final data = await _get('/gallery', const {});
    if (data is! List) return const [];
    return data.map((e) {
      final json = Map<String, dynamic>.from(e as Map);
      return GalleryItem(
        path: json['path']?.toString() ?? '',
        category: json['category']?.toString() ?? '',
        entityType: json['entity_type']?.toString() ?? '',
        entityId: json['entity_id']?.toString() ?? '',
        entityTitle: json['entity_title']?.toString() ?? '',
        parentTitle: json['parent_title']?.toString(),
        customTitle: json['custom_title']?.toString(),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );
    }).toList();
  }

  /// 保存图库图片自定义名。[logicalPath] 为 images/ 下相对路径；title 传空串表示清除恢复默认
  Future<void> saveImageAsset(String logicalPath, String title) =>
      _post('/image-asset', {'path': logicalPath, 'title': title});

  /// OSS lite URL 反解为 images/ 下逻辑路径（与服务端 urlToLogicalPath 对齐）：
  /// 截取 /images/ 之后部分，并去掉扩展名前的 -lite 后缀
  static String? logicalPathFromUrl(String url) {
    final idx = url.indexOf('/images/');
    if (idx < 0) return null;
    var p = url.substring(idx + 8);
    final dot = p.lastIndexOf('.');
    if (dot > 0) {
      final name = p.substring(0, dot);
      final ext = p.substring(dot);
      if (name.endsWith('-lite')) {
        p = name.substring(0, name.length - 5) + ext;
      }
    }
    return p;
  }
}

/// 人物名录一页作品轻量行（人物姓名聚合在客户端累积的多页数据上进行）
class PersonsPage {
  final List<Movie> movies;
  final List<Book> books;

  /// 影视/书籍两域是否任一还有下一页
  final bool hasMore;

  const PersonsPage({
    required this.movies,
    required this.books,
    required this.hasMore,
  });
}
