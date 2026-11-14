import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/database_helper.dart';
import '../../l10n/app_strings.dart';
import '../../utils/server_config.dart';
import '../../utils/user_prefs.dart';
import '../sync/incremental/sync_identity.dart';
import 'cloud_auth_service.dart';

/// 影视云端操作结果
class CloudMovieResult {
  final bool success;
  final String message;
  final int count;

  const CloudMovieResult({
    required this.success,
    this.message = '',
    this.count = 0,
  });
}

/// 进度回调：stage 为已本地化的阶段文案，done/total 为 null 时表示不确定进度
typedef CloudMovieProgressCallback = void Function(String stage, int? done, int? total);

/// 服务器云模式 - 第一期：影视 8 表
///
/// 不是持续同步，而是「本地浏览 / 云端浏览」两种模式的整库迁移：
/// - 本地 → 云端：图片上传 MinIO 后行内路径替换为网络 URL，整包替换推送
/// - 云端 → 本地：清空本地 8 表后整包落库，图片列直接存云端 URL，不下载图片文件
/// 云端模式下 FadeInLocalImage 识别 http 路径自动走网络图片。
class CloudMovieSyncService {
  CloudMovieSyncService._();
  static final CloudMovieSyncService instance = CloudMovieSyncService._();

  static const _pushBatch = 200;

  /// 一期 8 表的本地列（与 database_helper DDL 一致）
  static const Map<String, List<String>> _columns = {
    'movies': [
      'id', 'title', 'poster_path', 'release_date', 'directors', 'writers', 'actors',
      'genres', 'alternate_titles', 'summary', 'rating', 'status', 'category',
      'cover_offset', 'watch_count', 'duration', 'watch_date',
      'is_deleted', 'created_at', 'updated_at',
    ],
    'movie_reviews': [
      'id', 'movie_id', 'content', 'reviewer', 'source', 'review_type', 'review_date',
      'images', 'is_deleted', 'created_at', 'updated_at',
    ],
    'movie_posters': ['id', 'movie_id', 'poster_path', 'sort_order', 'is_deleted', 'created_at'],
    'movie_episodes': [
      'id', 'movie_id', 'episode_no', 'title', 'duration', 'watched', 'watch_date',
      'rating', 'review', 'images', 'is_deleted', 'created_at', 'updated_at',
    ],
    'movie_people': ['id', 'movie_id', 'person_id', 'role_type', 'character_name', 'sort_order'],
    'movie_characters': [
      'id', 'movie_id', 'name', 'role', 'aliases', 'tags', 'description',
      'image_path', 'sort_order', 'is_deleted', 'created_at', 'updated_at',
    ],
    'people': [
      'id', 'name', 'gender', 'birth_date', 'birth_place', 'alternate_names', 'occupation',
      'summary', 'photo_path', 'cover_offset', 'is_deleted', 'created_at', 'updated_at',
    ],
    'tags': ['id', 'name', 'type', 'is_hidden', 'parent_id', 'sort_order', 'created_at'],
  };

  /// 独立行级表（子组表随 movies 的 g 上行）
  static const _rowTables = [
    'movies', 'movie_reviews', 'movie_characters', 'people', 'tags',
  ];
  static const _groupTables = ['movie_people', 'movie_posters', 'movie_episodes'];
  static const _tsColumn = {
    'movies': 'updated_at',
    'movie_reviews': 'updated_at',
    'movie_characters': 'updated_at',
    'people': 'updated_at',
    'tags': 'created_at',
  };

  /// 本地 8 表（整库覆盖本地时的删除顺序，无外键约束但保持父后子先）
  static const _allTables = [
    'movie_people', 'movie_posters', 'movie_episodes', 'movie_reviews',
    'movie_characters', 'movies', 'people', 'tags',
  ];

  String get _base => '${ServerConfig.cloudApiBase}/app';
  String get _token => CloudAuthService.instance.token;

  /// 逻辑路径 -> 已上传云端 URL 的去重缓存
  final Map<String, String> _uploaded = {};

  /// 单次上传任务内每完成一张图片的计数回调（由 uploadLocalToCloud 注入）
  void Function()? _onImageUploaded;

  bool get isCloudMode => UserPrefs().cloudMovieMode;

  /// 云端影视各表行数；movies 为 0 即视为云端空库
  Future<Map<String, int>?> fetchCloudStatus() async {
    try {
      final resp = await http
          .post(Uri.parse('$_base/sync/movie/status'),
              headers: {'Content-Type': 'application/json', 'token': _token})
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) return null;
      return ((data['data'] as Map).map((k, v) => MapEntry(k as String, (v as num).toInt())));
    } catch (_) {
      return null;
    }
  }

  /// 本地整库上传到云端（replace=true 服务端先清空该用户影视数据再插入）
  Future<CloudMovieResult> uploadLocalToCloud({
    CloudMovieProgressCallback? onProgress,
  }) async {
    if (!CloudAuthService.instance.isLoggedIn) {
      return CloudMovieResult(success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
    }
    try {
      _uploaded.clear();
      final db = await DatabaseHelper.instance.database;
      final clientId = await SyncIdentity.clientId();

      // 预扫描：统计待上传图片总数与待推送记录总数，用于确定进度
      final imagePaths = <String>{};
      // 逻辑路径 → 本地绝对路径，供批量探测与并发上传使用
      final absByLogical = <String, String>{};
      var dataTotal = 0;
      for (final t in [..._rowTables, ..._groupTables]) {
        final rows = await db.query(t);
        if (_rowTables.contains(t)) dataTotal += rows.length;
        for (final r in rows) {
          _collectImageRefs(t, r, imagePaths, absByLogical);
        }
      }

      var doneImages = 0;
      void reportImageProgress() {
        onProgress?.call(
          '正在处理图片（{done}/{total}）'.trf({'done': doneImages, 'total': imagePaths.length}),
          doneImages,
          imagePaths.length,
        );
      }

      // 本地文件存在的图片才需要探测/上传；丢失的直接计为已处理
      final validLogical = <String>[];
      for (final logical in imagePaths) {
        final abs = absByLogical[logical];
        if (abs != null && await File(abs).exists()) {
          validLogical.add(logical);
        } else {
          doneImages++;
        }
      }

      // 一次批量查询云端已存在的同名图片，命中直接复用 URL
      final existingMap = await _checkImagesExistBatch(validLogical);
      final pending = <String>[];
      for (final logical in validLogical) {
        final url = existingMap[logical];
        if (url != null && url.isNotEmpty) {
          _uploaded[logical] = url;
          doneImages++;
        } else {
          pending.add(logical);
        }
      }
      debugPrint('[CloudMovie] 图片探测：本地有效 ${validLogical.length} 张，'
          '命中 ${validLogical.length - pending.length} 张，待上传 ${pending.length} 张');
      if (pending.isNotEmpty) {
        debugPrint('[CloudMovie] 待上传样例路径: ${pending.take(3).join(' | ')}');
      }
      reportImageProgress();

      // 缺失图片 4 路并发上传；单张失败即中止任务（错误冒泡到外层 toast），
      // 已成功的图下次重试会被批量探测命中，不会重复上传
      const concurrency = 4;
      for (var i = 0; i < pending.length; i += concurrency) {
        final slice = pending.sublist(i, (i + concurrency).clamp(0, pending.length));
        await Future.wait(slice.map((logical) async {
          final url = await _uploadOne(logical, absByLogical[logical]!);
          _uploaded[logical] = url;
        }));
        doneImages += slice.length;
        reportImageProgress();
      }
      // 构行阶段边缘情况（布局不符等）的兜底计数
      _onImageUploaded = reportImageProgress;

      final groupBuckets = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final t in _groupTables) {
        final rows = await db.query(t);
        for (final r in rows) {
          final movieId = r['movie_id'] as String;
          (groupBuckets.putIfAbsent(movieId, () => {}))
              .putIfAbsent(t, () => [])
              .add(await _toCloudRow(t, r, keepId: true));
        }
      }

      final ops = <Map<String, dynamic>>[];
      for (final t in _rowTables) {
        final rows = await db.query(t);
        for (final r in rows) {
          final op = <String, dynamic>{
            't': t,
            'id': r['id'] as String,
            'ts': r[_tsColumn[t]] as String,
            'row': await _toCloudRow(t, r),
          };
          if (t == 'movies' && groupBuckets.containsKey(r['id'])) {
            op['g'] = groupBuckets[r['id']];
          }
          ops.add(op);
        }
      }

      var firstBatch = true;
      for (var i = 0; i < ops.length; i += _pushBatch) {
        final slice = ops.sublist(i, (i + _pushBatch).clamp(0, ops.length));
        onProgress?.call(
          '正在上传数据（{done}/{total}）'.trf({'done': i, 'total': dataTotal}),
          i,
          dataTotal,
        );
        final resp = await http
            .post(
              Uri.parse('$_base/sync/push'),
              headers: {'Content-Type': 'application/json', 'token': _token},
              body: jsonEncode({
                'c': clientId,
                'at': DateTime.now().toIso8601String(),
                // 仅首批携带 replace，避免后续批次重复清库
                if (firstBatch) 'replace': true,
                'ops': slice,
                'img': <String, String>{},
              }),
            )
            .timeout(const Duration(seconds: 60));
        firstBatch = false;
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        if (data['code'] == 401) {
          await UserPrefs().clearCloudAccount();
          return CloudMovieResult(
              success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
        }
        if (data['code'] != 0) {
          return CloudMovieResult(
              success: false, message: data['msg']?.toString() ?? '上传失败'.tr);
        }
      }
      onProgress?.call(
        '正在上传数据（{done}/{total}）'.trf({'done': dataTotal, 'total': dataTotal}),
        dataTotal,
        dataTotal,
      );
      return CloudMovieResult(success: true, count: ops.length);
    } catch (e) {
      return CloudMovieResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    } finally {
      _onImageUploaded = null;
    }
  }

  /// 云端整库覆盖本地：清空本地 8 表后落库，图片列保留云端 URL（不下载图片文件）
  Future<CloudMovieResult> downloadCloudToLocal({
    CloudMovieProgressCallback? onProgress,
  }) async {
    if (!CloudAuthService.instance.isLoggedIn) {
      return CloudMovieResult(success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
    }
    try {
      final clientId = await SyncIdentity.clientId();
      onProgress?.call('正在拉取云端数据…'.tr, null, null);
      final resp = await http
          .post(
            Uri.parse('$_base/sync/pull'),
            headers: {'Content-Type': 'application/json', 'token': _token},
            body: jsonEncode({'since': '', 'clientId': clientId}),
          )
          .timeout(const Duration(seconds: 60));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] == 401) {
        await UserPrefs().clearCloudAccount();
        return CloudMovieResult(
            success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
      }
      if (data['code'] != 0) {
        return CloudMovieResult(
            success: false, message: data['msg']?.toString() ?? '拉取失败'.tr);
      }

      final ops = ((data['data'] as Map)['ops'] as List?) ?? const [];
      final db = await DatabaseHelper.instance.database;
      await db.transaction((txn) async {
        for (final t in _allTables) {
          await txn.delete(t);
        }
        var done = 0;
        for (final o in ops) {
          final op = Map<String, dynamic>.from(o as Map);
          final table = op['t'] as String;
          final row = Map<String, dynamic>.from(op['row'] as Map);
          await txn.insert(table, _toLocalRow(table, op['id'] as String, row),
              conflictAlgorithm: ConflictAlgorithm.replace);
          if (table == 'movies' && op['g'] != null) {
            final groups = Map<String, dynamic>.from(op['g'] as Map);
            for (final t in _groupTables) {
              for (final r in ((groups[t] as List?) ?? const [])) {
                final grow = Map<String, dynamic>.from(r as Map);
                await txn.insert(t, _toLocalRow(t, grow['id'] as String, grow),
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          }
          done++;
          onProgress?.call(
            '正在写入本地数据（{done}/{total}）'.trf({'done': done, 'total': ops.length}),
            done,
            ops.length,
          );
        }
      });
      return CloudMovieResult(success: true, count: ops.length);
    } catch (e) {
      return CloudMovieResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  // ------------------------------------------------------------------
  // 行转换 / 图片上传
  // ------------------------------------------------------------------

  /// [keepId] 子组行需要保留 id（服务端 replaceGroups 从行内取 id）；
  /// 主表行的 id 在 op 顶层，row 内不带
  Future<Map<String, dynamic>> _toCloudRow(
    String table,
    Map<String, dynamic> local, {
    bool keepId = false,
  }) async {
    final out = <String, dynamic>{};
    for (final col in _columns[table]!) {
      if (col == 'id' && !keepId) continue;
      out[col] = local[col];
    }
    await _rewriteImageColumns(table, out);
    return out;
  }

  Future<void> _rewriteImageColumns(String table, Map<String, dynamic> row) async {
    if (table == 'movies' || table == 'movie_posters') {
      row['poster_path'] = await _uploadIfLocal(row['poster_path'] as String?);
    } else if (table == 'movie_reviews' || table == 'movie_episodes') {
      row['images'] = await _uploadJsonList(row['images'] as String?);
    } else if (table == 'movie_characters') {
      row['image_path'] = await _uploadIfLocal(row['image_path'] as String?);
    } else if (table == 'people') {
      row['photo_path'] = await _uploadIfLocal(row['photo_path'] as String?);
    }
  }

  /// 构行阶段取图片 URL：正常图片已在任务开始时批量探测/并发上传完成，命中缓存直接返回；
  /// 仅边缘情况（路径布局不符等）会走到这里，不上传、计入进度、原样返回
  Future<String?> _uploadIfLocal(String? value) async {
    if (value == null || value.isEmpty || value.startsWith('http')) return value;
    final logical = _toLogical(value);
    final cached = _uploaded[logical];
    if (cached != null) return cached;
    _onImageUploaded?.call();
    return value;
  }

  /// 批量探测云端同名图片，返回 logicalPath → lite URL（不存在/失败的 key 缺省）。
  /// 网络或解析失败时返回空 Map，调用方按"全部缺失"处理，交由上传兜底，不阻断任务。
  Future<Map<String, String>> _checkImagesExistBatch(List<String> logicalPaths) async {
    if (logicalPaths.isEmpty) return {};
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/oss/images-exists'),
            headers: {'Content-Type': 'application/json', 'token': _token},
            body: jsonEncode({'paths': logicalPaths}),
          )
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        debugPrint('[CloudMovie] 图片探测 HTTP ${resp.statusCode}：'
            '${utf8.decode(resp.bodyBytes).substring(0, resp.bodyBytes.length.clamp(0, 300))}');
        return {};
      }
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) {
        debugPrint('[CloudMovie] 图片探测业务失败 code=${data['code']} msg=${data['msg']}');
        return {};
      }
      return ((data['data'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v?.toString() ?? ''));
    } catch (e) {
      debugPrint('[CloudMovie] 图片探测异常（将按全部缺失重传）: $e');
      return {};
    }
  }

  /// 单张图片上传，成功返回 lite URL（由并发池调度，不做缓存与进度计数）
  Future<String> _uploadOne(String logical, String absPath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/oss/image'))
      ..headers['token'] = _token
      ..fields['path'] = logical
      ..files.add(await http.MultipartFile.fromPath('file', absPath));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final data =
        jsonDecode(utf8.decode(await streamed.stream.toBytes())) as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw Exception(data['msg']?.toString() ?? '图片上传失败'.tr);
    }
    final url = data['data'].toString();
    debugPrint('[CloudMovie] 实际上传: $logical -> $url');
    return url;
  }

  /// 收集一行中引用的本地图片逻辑路径（http URL 跳过），用于上传前统计总数；
  /// 同时记录逻辑路径 → 本地绝对路径映射
  void _collectImageRefs(
    String table,
    Map<String, dynamic> row,
    Set<String> out,
    Map<String, String> absByLogical,
  ) {
    void addSingle(String? value) {
      if (value != null && value.isNotEmpty && !value.startsWith('http')) {
        final logical = _toLogical(value);
        out.add(logical);
        absByLogical[logical] = value;
      }
    }

    void addJsonList(String? json) {
      if (json == null || json.isEmpty) return;
      try {
        for (final e in jsonDecode(json) as List) {
          if (e is String && e.isNotEmpty && !e.startsWith('http')) {
            final logical = _toLogical(e);
            out.add(logical);
            absByLogical[logical] = e;
          }
        }
      } catch (_) {}
    }

    if (table == 'movies' || table == 'movie_posters') {
      addSingle(row['poster_path'] as String?);
    } else if (table == 'movie_reviews' || table == 'movie_episodes') {
      addJsonList(row['images'] as String?);
    } else if (table == 'movie_characters') {
      addSingle(row['image_path'] as String?);
    } else if (table == 'people') {
      addSingle(row['photo_path'] as String?);
    }
  }

  Future<String?> _uploadJsonList(String? json) async {
    if (json == null || json.isEmpty) return json;
    try {
      final list = jsonDecode(json) as List;
      final result = <String>[];
      for (final e in list) {
        if (e is String && e.isNotEmpty) {
          result.add((await _uploadIfLocal(e)) ?? e);
        }
      }
      return jsonEncode(result);
    } catch (_) {
      return json;
    }
  }

  String _toLogical(String absPath) {
    final normalized = absPath.replaceAll('\\', '/');
    final idx = normalized.indexOf('/images/');
    if (idx >= 0) return normalized.substring(idx + 8);
    return p.basename(absPath);
  }

  Map<String, dynamic> _toLocalRow(String table, String id, Map<String, dynamic> cloudRow) {
    final out = <String, dynamic>{'id': id};
    for (final col in _columns[table]!) {
      if (col == 'id') continue;
      out[col] = cloudRow[col];
    }
    return out;
  }
}
