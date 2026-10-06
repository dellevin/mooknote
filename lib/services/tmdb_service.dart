import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// TMDB Token 测试结果
enum TmdbTestStatus { ok, invalidToken, networkError }

class TmdbTestResult {
  final TmdbTestStatus status;
  final String authType; // 'bearer'(v4) / 'apikey'(v3)
  const TmdbTestResult(this.status, [this.authType = 'bearer']);
}

/// Token 认证失败（401）
class TmdbAuthException implements Exception {}

/// 网络不通 / 请求失败
class TmdbNetworkException implements Exception {}

/// TMDB API 服务
/// 文档：https://developer.themoviedb.org/reference/intro/getting-started
class TmdbService {
  TmdbService._();
  static final TmdbService instance = TmdbService._();

  static const String _base = 'https://api.themoviedb.org/3';
  static const String imageBase = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBase = 'https://image.tmdb.org/t/p/w780';
  static const String profileBase = 'https://image.tmdb.org/t/p/w185';

  String _token = '';
  String _authType = 'bearer';

  bool get isConfigured => _token.isNotEmpty;

  /// 用已保存的凭证配置服务
  void configure(String token, String authType) {
    _token = token;
    _authType = authType;
  }

  Map<int, String> _movieGenres = {};
  Map<int, String> _tvGenres = {};
  bool _genresLoaded = false;

  // ── 认证 ──────────────────────────────────────────────

  /// 测试 Token：先试 Bearer（v4 Read Access Token），401 再试 api_key（v3 Key）
  static Future<TmdbTestResult> testToken(String token) async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/authentication'), headers: {
            'Authorization': 'Bearer $token',
            'accept': 'application/json',
          })
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        return const TmdbTestResult(TmdbTestStatus.ok, 'bearer');
      }
      if (resp.statusCode == 401) {
        final resp2 = await http
            .get(Uri.parse('$_base/authentication?api_key=$token'),
                headers: {'accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (resp2.statusCode == 200) {
          return const TmdbTestResult(TmdbTestStatus.ok, 'apikey');
        }
        return const TmdbTestResult(TmdbTestStatus.invalidToken);
      }
      return const TmdbTestResult(TmdbTestStatus.networkError);
    } catch (_) {
      return const TmdbTestResult(TmdbTestStatus.networkError);
    }
  }

  // ── 请求 ──────────────────────────────────────────────

  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final params = {'language': 'zh-CN', ...query};
    if (_authType == 'apikey') params['api_key'] = _token;
    return Uri.parse('$_base$path').replace(queryParameters: params);
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String> query = const {}]) async {
    http.Response resp;
    try {
      resp = await http.get(_uri(path, query), headers: {
        if (_authType == 'bearer') 'Authorization': 'Bearer $_token',
        'accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw TmdbNetworkException();
    } on SocketException {
      throw TmdbNetworkException();
    } on http.ClientException {
      throw TmdbNetworkException();
    }
    if (resp.statusCode == 401) throw TmdbAuthException();
    if (resp.statusCode != 200) throw TmdbNetworkException();
    return json.decode(resp.body) as Map<String, dynamic>;
  }

  // ── 类型表 ──────────────────────────────────────────────

  /// 加载并缓存 电影/剧集 类型映射（id → 中文名）
  Future<void> ensureGenres() async {
    if (_genresLoaded) return;
    final mg = await _get('/genre/movie/list');
    final tg = await _get('/genre/tv/list');
    _movieGenres = {
      for (final g in (mg['genres'] as List? ?? []))
        g['id'] as int: g['name'] as String
    };
    _tvGenres = {
      for (final g in (tg['genres'] as List? ?? []))
        g['id'] as int: g['name'] as String
    };
    _genresLoaded = true;
  }

  List<String> genreNames(String mediaType, List<dynamic> ids) {
    final map = mediaType == 'tv' ? _tvGenres : _movieGenres;
    return ids.map((e) => map[e]).whereType<String>().toList();
  }

  // ── 搜索 / 详情 ──────────────────────────────────────────────

  /// 综合搜索（过滤后仅保留电影和剧集），返回原始分页结构
  Future<Map<String, dynamic>> searchMulti(String query, int page) async {
    final data = await _get('/search/multi', {
      'query': query,
      'page': '$page',
      'include_adult': 'false',
    });
    data['results'] = (data['results'] as List? ?? [])
        .where((e) => e['media_type'] == 'movie' || e['media_type'] == 'tv')
        .toList();
    return data;
  }

  /// 电影详情（含演职员）
  Future<Map<String, dynamic>> movieDetail(int id) =>
      _get('/movie/$id', {'append_to_response': 'credits'});

  /// 剧集详情（含演职员）
  Future<Map<String, dynamic>> tvDetail(int id) =>
      _get('/tv/$id', {'append_to_response': 'credits'});

  /// 人员详情（含电影/剧集作品表）
  Future<Map<String, dynamic>> personDetail(int id) =>
      _get('/person/$id', {'append_to_response': 'movie_credits,tv_credits'});
}
