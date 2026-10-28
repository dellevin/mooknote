import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'api_proxy_client.dart';

/// Bangumi Token 测试结果
enum BangumiTestStatus { ok, invalidToken, networkError }

/// Token 认证失败（401）
class BangumiAuthException implements Exception {}

/// 网络不通 / 请求失败
class BangumiNetworkException implements Exception {}

/// Bangumi API 服务
/// 文档：https://bangumi.github.io/api/
class BangumiService {
  BangumiService._();
  static final BangumiService instance = BangumiService._();

  static const String _base = 'https://api.bgm.tv';

  /// 搜索的条目类型：1=书籍 2=动画 4=游戏 6=三次元（音乐 type 3 不支持）
  static const List<int> subjectTypes = [1, 2, 4, 6];

  static const int pageSize = 30;

  String _token = '';
  String _proxy = '';
  String? _userAgent;
  http.Client _client = http.Client();

  bool get isConfigured => _token.isNotEmpty;

  /// 用已保存的凭证配置服务
  void configure(String token, {String proxy = ''}) {
    _token = token;
    if (proxy != _proxy) {
      _proxy = proxy;
      _client.close();
      _client = buildProxyClient(proxy);
    }
  }

  /// Bangumi 要求非浏览器 API 使用者携带含开发者 ID 和应用名的 UA
  Future<String> userAgent() async {
    if (_userAgent != null) return _userAgent!;
    var version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    final platform =
        Platform.isAndroid ? 'Android' : Platform.operatingSystem;
    _userAgent =
        'dellevin/mooknote${version.isNotEmpty ? '/$version' : ''} ($platform) (https://github.com/DelLevin-Home/mooknote)';
    return _userAgent!;
  }

  // ── 认证 ──────────────────────────────────────────────

  /// 测试 Token：GET /v0/me，200=有效，401=无效
  static Future<BangumiTestStatus> testToken(String token,
      {String proxy = ''}) async {
    final client = buildProxyClient(proxy);
    try {
      final resp = await client.get(Uri.parse('$_base/v0/me'), headers: {
        'Authorization': 'Bearer $token',
        'User-Agent': await instance.userAgent(),
        'accept': 'application/json',
      }).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return BangumiTestStatus.ok;
      if (resp.statusCode == 401) return BangumiTestStatus.invalidToken;
      return BangumiTestStatus.networkError;
    } catch (_) {
      return BangumiTestStatus.networkError;
    } finally {
      client.close();
    }
  }

  // ── 请求 ──────────────────────────────────────────────

  Future<Map<String, String>> _headers() async => {
        'Authorization': 'Bearer $_token',
        'User-Agent': await userAgent(),
        'accept': 'application/json',
      };

  Future<Object?> _send(String method, String path,
      {Map<String, dynamic>? body, Map<String, String> query = const {}}) async {
    http.Response resp;
    try {
      final uri = Uri.parse('$_base$path').replace(queryParameters: query);
      final headers = await _headers();
      if (method == 'POST') {
        resp = await _client
            .post(uri,
                headers: {...headers, 'Content-Type': 'application/json'},
                body: json.encode(body))
            .timeout(const Duration(seconds: 15));
      } else {
        resp = await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      }
    } on TimeoutException {
      throw BangumiNetworkException();
    } on SocketException {
      throw BangumiNetworkException();
    } on http.ClientException {
      throw BangumiNetworkException();
    }
    if (resp.statusCode == 401) throw BangumiAuthException();
    if (resp.statusCode != 200) throw BangumiNetworkException();
    return json.decode(utf8.decode(resp.bodyBytes));
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, dynamic>? body, Map<String, String> query = const {}}) async {
    return await _send(method, path, body: body, query: query)
        as Map<String, dynamic>;
  }

  Future<List<dynamic>> _requestList(String method, String path,
      {Map<String, dynamic>? body, Map<String, String> query = const {}}) async {
    return await _send(method, path, body: body, query: query) as List<dynamic>;
  }

  // ── 搜索 / 详情 ──────────────────────────────────────────────

  /// 综合搜索（书籍/动画/游戏/三次元），返回原始分页结构 {total, limit, offset, data}
  Future<Map<String, dynamic>> searchSubjects(String query, int offset) =>
      _request('POST', '/v0/search/subjects', body: {
        'keyword': query,
        'filter': {'type': subjectTypes},
      }, query: {
        'limit': '$pageSize',
        'offset': '$offset',
      });

  /// 条目详情
  Future<Map<String, dynamic>> subjectDetail(int id) =>
      _request('GET', '/v0/subjects/$id');

  /// 条目关联人物（制作人员），元素含 id/name/relation/images/career
  Future<List<dynamic>> subjectPersons(int id) =>
      _requestList('GET', '/v0/subjects/$id/persons');

  /// 条目关联角色，元素含 id/name/relation/images/summary/actors（声优列表）
  Future<List<dynamic>> subjectCharacters(int id) =>
      _requestList('GET', '/v0/subjects/$id/characters');

  /// 人物详情（含 gender/birth_*/infobox/summary）
  Future<Map<String, dynamic>> personDetail(int id) =>
      _request('GET', '/v0/persons/$id');

  /// 角色详情（infobox 含简体中文名）
  Future<Map<String, dynamic>> characterDetail(int id) =>
      _request('GET', '/v0/characters/$id');

  /// 条目本篇分集（type=0），自动翻页拉全；元素含 ep/name/name_cn/airdate 等
  Future<List<dynamic>> subjectEpisodes(int id) async {
    final out = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = await _request('GET', '/v0/episodes', query: {
        'subject_id': '$id',
        'type': '0',
        'limit': '100',
        'offset': '$offset',
      });
      final data = (page['data'] as List? ?? []);
      out.addAll(data);
      final total = (page['total'] as num?)?.toInt() ?? out.length;
      offset += data.length;
      if (data.isEmpty || offset >= total) break;
    }
    return out;
  }
}
