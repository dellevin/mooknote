import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../l10n/app_strings.dart';
import '../../utils/server_config.dart';
import '../../utils/user_prefs.dart';
import '../sync/incremental/sync_identity.dart';
import 'cloud_auth_service.dart';
import 'cloud_movie_data_service.dart' show CloudPage;

/// 云模式（纯实时）书籍 / 游戏 / 笔记数据 HTTP 客户端。
///
/// 与 [CloudMovieDataService] 同构，但走服务端 app/domains、app/domain-child、
/// app/domain-entities 三组通用路由，domain 取 books / games，笔记走 domain-entities。
/// 模型解析器由调用方传入，本类不绑定具体媒体模型。
class CloudDomainDataService {
  CloudDomainDataService._();
  static final CloudDomainDataService instance = CloudDomainDataService._();

  String get _base => '${ServerConfig.cloudApiBase}/app';
  String get _token => CloudAuthService.instance.token;

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'token': _token};

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_base/$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v)),
    );
    final http.BaseRequest request = http.Request(method, uri)
      ..headers.addAll(_headers);
    if (body != null && (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
      (request as http.Request).body = jsonEncode(body);
    }
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final bodyBytes = await streamed.stream.toBytes();
    if (streamed.statusCode != 200) {
      throw StateError(
          '云端请求失败 (HTTP {code})'.trf({'code': streamed.statusCode}));
    }
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('云端响应解析失败'.tr);
    }
    if (data['code'] == 401) {
      await UserPrefs().clearCloudAccount();
      throw StateError('登录失效，已切换成本地数据，请重新登录'.tr);
    }
    if (data['code'] != 0) {
      throw StateError(data['msg']?.toString() ?? '云端操作失败'.tr);
    }
    return data['data'];
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);
  Future<dynamic> _post(String path, Map<String, dynamic> body) =>
      _request('POST', path, body: body);
  Future<dynamic> _put(String path, Map<String, dynamic> body) =>
      _request('PUT', path, body: body);
  Future<dynamic> _patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body: body);
  Future<dynamic> _delete(String path) => _request('DELETE', path);

  Future<Map<String, dynamic>> _withClientId(Map<String, dynamic> body) async =>
      {'clientId': await SyncIdentity.clientId(), ...body};

  static List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) parser) =>
      ((data as List?) ?? const [])
          .map((e) => parser(Map<String, dynamic>.from(e as Map)))
          .toList();

  // ------------------------------------------------------------------
  // 主表（books / games）
  // ------------------------------------------------------------------

  Future<CloudPage<T>> pageMain<T>(
    String domain,
    T Function(Map<String, dynamic>) parser, {
    String? status,
    String? category,
    String? keyword,
    String? publisher,
    int sortMode = 0,
    int offset = 0,
    int limit = 20,
  }) async {
    final data = await _get('domains/$domain/page', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (publisher != null && publisher.isNotEmpty) 'publisher': publisher,
      'sortMode': '$sortMode',
      'offset': '$offset',
      'limit': '$limit',
    }) as Map<String, dynamic>;
    return CloudPage(
      _parseList(data['list'], parser),
      (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  /// 出版社名录：服务端按 TRIM(publisher) 分组统计，返回社名 + 书籍数（count 倒序）。
  /// 出版社无独立数据表，客户端内存聚合会受主表首页 50 条上限影响，故走独立聚合接口。
  Future<List<MapEntry<String, int>>> fetchPublishers() async {
    final data = await _get('domains/books/publishers');
    if (data is! List) return const [];
    return data.map((e) {
      final row = Map<String, dynamic>.from(e as Map);
      return MapEntry(
        row['name']?.toString() ?? '',
        (row['count'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<T>> deletedMain<T>(
          String domain, T Function(Map<String, dynamic>) parser) async =>
      _parseList(await _get('domains/$domain/deleted'), parser);

  /// 详情聚合原始 map（含主行、groups、其余子表），由调用方按域解析
  Future<Map<String, dynamic>?> detail(String domain, String id) async {
    final data = await _get('domains/$domain/$id');
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<void> createMain(String domain, Map<String, dynamic> row,
          {Map<String, dynamic>? groups}) async =>
      _post('domains/$domain',
          await _withClientId({'row': row, if (groups != null) 'groups': groups}));

  Future<void> updateMain(String domain, String id, Map<String, dynamic> row,
          {Map<String, dynamic>? groups}) async =>
      _put('domains/$domain/$id',
          await _withClientId({'row': row, if (groups != null) 'groups': groups}));

  Future<void> updateCoverOffset(String domain, String id, double offset) =>
      _patch('domains/$domain/$id/cover', {'cover_offset': offset});

  Future<void> softDeleteMain(String domain, String id) =>
      _delete('domains/$domain/$id');

  Future<void> restoreMain(String domain, String id) async =>
      _post('domains/$domain/$id/restore', await _withClientId({}));

  Future<void> permanentDeleteMain(String domain, String id) =>
      _delete('domains/$domain/$id/permanent');

  // ------------------------------------------------------------------
  // 子资源（resource 为服务端注册的本地表名）
  // ------------------------------------------------------------------

  Future<List<T>> listChildren<T>(String domain, String parentId, String resource,
          T Function(Map<String, dynamic>) parser) async =>
      _parseList(await _get('domains/$domain/$parentId/$resource'), parser);

  Future<int> countChildren(String domain, String parentId, String resource) async {
    final data = await _get('domains/$domain/$parentId/$resource/count');
    return (data as num?)?.toInt() ?? 0;
  }

  Future<List<T>> allChildren<T>(String resource,
          T Function(Map<String, dynamic>) parser) async =>
      _parseList(await _get('domain-child/$resource/all'), parser);

  Future<void> createChild(
          String domain, String parentId, String resource, Map<String, dynamic> row) async =>
      _post('domains/$domain/$parentId/$resource',
          await _withClientId({'row': row}));

  Future<void> updateChild(String resource, String rowId, Map<String, dynamic> row) async =>
      _put('domain-child/$resource/$rowId', await _withClientId({'row': row}));

  Future<void> deleteChild(String resource, String rowId) =>
      _delete('domain-child/$resource/$rowId');

  Future<void> restoreChild(String resource, String rowId) async =>
      _post('domain-child/$resource/$rowId/restore', await _withClientId({}));

  Future<void> permanentDeleteChild(String resource, String rowId) =>
      _delete('domain-child/$resource/$rowId/permanent');

  Future<List<T>> deletedChildren<T>(String resource,
          T Function(Map<String, dynamic>) parser) async =>
      _parseList(await _get('domain-child/$resource/deleted'), parser);

  Future<void> replacePeople(
          String domain, String parentId, List<Map<String, dynamic>> rows) async =>
      _post('domains/$domain/$parentId/people/replace',
          await _withClientId({'rows': rows}));

  /// 人物参与的书籍/游戏：返回 (主行, 关联行列表) 原始 map 集合，由调用方按模型解析
  Future<List<({Map<String, dynamic> work, List<Map<String, dynamic>> relations})>>
      personWorks(String domain, String personId) async {
    final data = await _get('people/$personId/works', query: {'domain': domain}) as List?;
    return (data ?? const []).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final work = Map<String, dynamic>.from(map['work'] as Map);
      final relations = ((map['relations'] as List?) ?? const [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
      return (work: work, relations: relations);
    }).toList();
  }

  Future<void> reorderMedia(String domain, String parentId, List<String> orderedIds) async =>
      _post('domains/$domain/$parentId/media/reorder',
          await _withClientId({'ids': orderedIds}));

  // ------------------------------------------------------------------
  // 独立实体（笔记 notes）
  // ------------------------------------------------------------------

  Future<List<T>> listEntities<T>(
          String resource, T Function(Map<String, dynamic>) parser) async =>
      _parseList(await _get('domain-entities/$resource'), parser);

  Future<Map<String, dynamic>?> getEntity(String resource, String id) async {
    final data = await _get('domain-entities/$resource/$id');
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<void> createEntity(String resource, Map<String, dynamic> row) async =>
      _post('domain-entities/$resource', await _withClientId({'row': row}));

  Future<void> updateEntity(String resource, String id, Map<String, dynamic> row) async =>
      _put('domain-entities/$resource/$id', await _withClientId({'row': row}));

  Future<void> deleteEntity(String resource, String id) =>
      _delete('domain-entities/$resource/$id');

  Future<List<T>> deletedEntities<T>(String resource,
          T Function(Map<String, dynamic>) parser) async =>
      _parseList(await _get('domain-entities/$resource/deleted'), parser);

  Future<void> restoreEntity(String resource, String id) async =>
      _post('domain-entities/$resource/$id/restore', await _withClientId({}));

  Future<void> permanentDeleteEntity(String resource, String id) =>
      _delete('domain-entities/$resource/$id/permanent');
}
