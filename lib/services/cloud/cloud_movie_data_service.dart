import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../utils/server_config.dart';
import '../../utils/user_prefs.dart';
import '../sync/incremental/sync_identity.dart';
import 'cloud_auth_service.dart';

/// 云端影视详情聚合（对应服务端 GET app/movies/{id}）
class CloudMovieDetail {
  final Movie movie;
  final List<MoviePerson> people;
  final List<MoviePoster> posters;
  final List<MovieEpisode> episodes;
  final List<MovieReview> reviews;
  final List<MovieCharacter> characters;

  const CloudMovieDetail({
    required this.movie,
    this.people = const [],
    this.posters = const [],
    this.episodes = const [],
    this.reviews = const [],
    this.characters = const [],
  });

  factory CloudMovieDetail.fromJson(Map<String, dynamic> json) {
    final groups = (json['groups'] as Map?) ?? const {};
    List<T> listOf<T>(dynamic data, T Function(Map<String, dynamic>) parse) =>
        ((data as List?) ?? const []).map((e) => parse(Map<String, dynamic>.from(e as Map))).toList();
    return CloudMovieDetail(
      movie: Movie.fromJson(Map<String, dynamic>.from(json['movie'] as Map)),
      people: listOf(groups['movie_people'], MoviePerson.fromJson),
      posters: listOf(groups['movie_posters'], MoviePoster.fromJson),
      episodes: listOf(groups['movie_episodes'], MovieEpisode.fromJson),
      reviews: listOf(json['reviews'], MovieReview.fromJson),
      characters: listOf(json['characters'], MovieCharacter.fromJson),
    );
  }
}

/// 分页结果
class CloudPage<T> {
  final List<T> list;
  final int total;
  const CloudPage(this.list, this.total);
}

/// 云模式（纯实时）影视数据 HTTP 客户端。
///
/// 云端 mn_ 表是唯一数据源，方法与 AppProvider 的影视写/读入口一一对应；
/// 模型 toJson/fromJson 的 snake_case 与云端行结构一致，列表列同样是 JSON 字符串，可直接互转。
/// 仅在 UserPrefs.cloudMovieMode 下由 AppProvider 分流调用。
class CloudMovieDataService {
  CloudMovieDataService._();
  static final CloudMovieDataService instance = CloudMovieDataService._();

  String get _base => '${ServerConfig.cloudApiBase}/app';
  String get _token => CloudAuthService.instance.token;

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'token': _token};

  // ------------------------------------------------------------------
  // 底层请求
  // ------------------------------------------------------------------

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

  Future<Map<String, dynamic>> _withClientId(Map<String, dynamic> body) async {
    return {'clientId': await SyncIdentity.clientId(), ...body};
  }

  // ------------------------------------------------------------------
  // 电影主表
  // ------------------------------------------------------------------

  Future<CloudPage<Movie>> pageMovies({
    String? status,
    String? category,
    String? keyword,
    int sortMode = 0,
    int offset = 0,
    int limit = 20,
  }) async {
    final data = await _get('movies/page', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (category != null && category.isNotEmpty) 'category': category,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'sortMode': '$sortMode',
      'offset': '$offset',
      'limit': '$limit',
    }) as Map<String, dynamic>;
    final list = ((data['list'] as List?) ?? const [])
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return CloudPage(list, (data['total'] as num?)?.toInt() ?? 0);
  }

  Future<List<Movie>> deletedMovies() async {
    final data = await _get('movies/deleted') as List?;
    return (data ?? const [])
        .map((e) => Movie.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CloudMovieDetail?> movieDetail(String id) async {
    final data = await _get('movies/$id');
    if (data == null) return null;
    return CloudMovieDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> createMovie(Movie movie, {Map<String, dynamic>? groups}) async {
    await _post('movies',
        await _withClientId({'row': movie.toJson(), if (groups != null) 'groups': groups}));
  }

  Future<void> updateMovie(Movie movie, {Map<String, dynamic>? groups}) async {
    await _put('movies/${movie.id}',
        await _withClientId({'row': movie.toJson(), if (groups != null) 'groups': groups}));
  }

  Future<void> updateCoverOffset(String movieId, double offset) =>
      _patch('movies/$movieId/cover', {'cover_offset': offset});

  Future<void> softDeleteMovie(String id) => _delete('movies/$id');

  Future<void> restoreMovie(String id) async =>
      _post('movies/$id/restore', await _withClientId({}));

  Future<void> permanentDeleteMovie(String id) => _delete('movies/$id/permanent');

  // ------------------------------------------------------------------
  // 电影子资源（泛型 CRUD，resource 为服务端注册的本地表名）
  // ------------------------------------------------------------------

  Future<List<T>> listChildren<T>(
    String movieId,
    String resource,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final data = await _get('movies/$movieId/$resource') as List?;
    return (data ?? const [])
        .map((e) => parser(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> countChildren(String movieId, String resource) async {
    final data = await _get('movies/$movieId/$resource/count');
    return (data as num?)?.toInt() ?? 0;
  }

  /// 跨全部影视的子资源全量列表（Excel 导出用）
  Future<List<T>> allChildren<T>(
    String resource,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final data = await _get('movie-child/$resource/all') as List?;
    return (data ?? const [])
        .map((e) => parser(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createChild(String movieId, String resource, Map<String, dynamic> row) async {
    await _post('movies/$movieId/$resource', await _withClientId({'row': row}));
  }

  Future<void> updateChild(String resource, String rowId, Map<String, dynamic> row) async {
    await _put('movie-child/$resource/$rowId', await _withClientId({'row': row}));
  }

  Future<void> deleteChild(String resource, String rowId) =>
      _delete('movie-child/$resource/$rowId');

  Future<void> restoreChild(String resource, String rowId) async =>
      _post('movie-child/$resource/$rowId/restore', await _withClientId({}));

  Future<void> permanentDeleteChild(String resource, String rowId) =>
      _delete('movie-child/$resource/$rowId/permanent');

  Future<List<T>> deletedChildren<T>(
    String resource,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final data = await _get('movie-child/$resource/deleted') as List?;
    return (data ?? const [])
        .map((e) => parser(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 人物关联整组替换
  Future<void> replaceMoviePeople(String movieId, List<MoviePerson> people) async {
    await _post('movies/$movieId/people/replace', await _withClientId({
      'rows': people.map((p) => p.toJson()).toList(),
    }));
  }

  /// 海报重排
  Future<void> reorderPosters(String movieId, List<String> orderedIds) async =>
      _post('movies/$movieId/posters/reorder',
          await _withClientId({'ids': orderedIds}));

  // ------------------------------------------------------------------
  // 独立实体 people / tags
  // ------------------------------------------------------------------

  Future<List<T>> listEntities<T>(
    String resource,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final data = await _get('entities/$resource') as List?;
    return (data ?? const [])
        .map((e) => parser(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// 人物分页：服务端关键字检索（姓名/别名），返回 total + 当前页，供人物 Tab 触底加载
  Future<CloudPage<Person>> pagePeople({
    String? keyword,
    int offset = 0,
    int limit = 50,
  }) async {
    final data = await _get('people/page', query: {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'offset': '$offset',
      'limit': '$limit',
    }) as Map<String, dynamic>;
    final list = ((data['list'] as List?) ?? const [])
        .map((e) => Person.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return CloudPage(list, (data['total'] as num?)?.toInt() ?? 0);
  }

  Future<Map<String, dynamic>?> getEntity(String resource, String id) async {
    final data = await _get('entities/$resource/$id');
    return data == null ? null : Map<String, dynamic>.from(data as Map);
  }

  Future<void> createEntity(String resource, Map<String, dynamic> row) async {
    await _post('entities/$resource', await _withClientId({'row': row}));
  }

  Future<void> updateEntity(String resource, String id, Map<String, dynamic> row) async {
    await _put('entities/$resource/$id', await _withClientId({'row': row}));
  }

  Future<void> deleteEntity(String resource, String id) =>
      _delete('entities/$resource/$id');

  Future<List<T>> deletedEntities<T>(
    String resource,
    T Function(Map<String, dynamic>) parser,
  ) async {
    final data = await _get('entities/$resource/deleted') as List?;
    return (data ?? const [])
        .map((e) => parser(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> restoreEntity(String resource, String id) async =>
      _post('entities/$resource/$id/restore', await _withClientId({}));

  Future<void> permanentDeleteEntity(String resource, String id) =>
      _delete('entities/$resource/$id/permanent');

  /// 人物参与的影视：返回 (影视行, 关联行列表) 集合
  Future<List<({Movie movie, List<MoviePerson> relations})>> personMovieWorks(
      String personId) async {
    final data = await _get('people/$personId/movies') as List?;
    return (data ?? const []).map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      final movie = Movie.fromJson(Map<String, dynamic>.from(map['movie'] as Map));
      final relations = ((map['relations'] as List?) ?? const [])
          .map((r) => MoviePerson.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
      return (movie: movie, relations: relations);
    }).toList();
  }

  // ------------------------------------------------------------------
  // 图片上传（云模式表单选图后先传 OSS 拿网络 URL）
  // ------------------------------------------------------------------

  /// 上传单张图片，[logicalPath] 为 images/ 下相对路径，返回 lite 公网 URL
  Future<String> uploadImage(String logicalPath, String localAbsPath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/oss/image'))
      ..headers['token'] = _token
      ..fields['path'] = logicalPath
      ..files.add(await http.MultipartFile.fromPath('file', localAbsPath));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
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
      throw StateError(data['msg']?.toString() ?? '图片上传失败'.tr);
    }
    return data['data'].toString();
  }
}
