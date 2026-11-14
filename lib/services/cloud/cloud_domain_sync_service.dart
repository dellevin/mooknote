import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../data/database_helper.dart';
import '../../l10n/app_strings.dart';
import '../../utils/server_config.dart';
import '../../utils/user_prefs.dart';
import '../sync/incremental/sync_identity.dart';
import 'cloud_auth_service.dart';

/// 书籍/游戏/笔记整库迁移结果
class CloudDomainResult {
  final bool success;
  final String message;
  final int count;

  const CloudDomainResult({
    required this.success,
    this.message = '',
    this.count = 0,
  });
}

/// 进度回调：stage 为已本地化的阶段文案，done/total 为 null 时表示不确定进度
typedef CloudDomainProgressCallback = void Function(String stage, int? done, int? total);

/// 服务器云模式 - 第二期：书籍 / 游戏 / 笔记整库迁移。
///
/// 与 [CloudMovieSyncService] 同构，但走 sync/domain/status 状态查询，
/// push 时携带 domain 参数让服务端只清空对应媒体域；子组随父行 groups 上行。
/// 本地 → 云端：图片先传 MinIO，行内路径替换为网络 URL，整包 replace 推送。
class CloudDomainSyncService {
  CloudDomainSyncService._();
  static final CloudDomainSyncService instance = CloudDomainSyncService._();

  static const _pushBatch = 200;

  /// 域配置：本地表名集合与列白名单（与服务端 SyncTableRegistry 对齐）
  static const Map<String, _DomainConfig> _configs = {
    'books': _DomainConfig(
      mainTable: 'books',
      parentColumn: 'book_id',
      rowTables: ['books', 'book_reviews', 'book_excerpts', 'book_characters'],
      groupTables: ['book_people', 'book_chapters'],
      tsColumn: {
        'books': 'updated_at',
        'book_reviews': 'updated_at',
        'book_excerpts': 'updated_at',
        'book_characters': 'updated_at',
      },
      columns: {
        'books': [
          'title', 'cover_path', 'authors', 'translators', 'alternate_titles', 'publisher',
          'genres', 'summary', 'rating', 'status', 'category', 'isbn', 'publish_date',
          'start_date', 'finish_date', 'read_count', 'read_duration', 'cover_offset',
          'is_deleted', 'created_at', 'updated_at',
        ],
        'book_reviews': [
          'book_id', 'content', 'reviewer', 'source', 'review_type', 'review_date',
          'images', 'is_deleted', 'created_at', 'updated_at',
        ],
        'book_excerpts': [
          'book_id', 'chapter', 'content', 'comment',
          'is_deleted', 'created_at', 'updated_at',
        ],
        'book_chapters': [
          'book_id', 'chapter_no', 'title', 'read', 'read_date', 'rating', 'review',
          'images', 'is_deleted', 'created_at', 'updated_at',
        ],
        'book_people': ['book_id', 'person_id', 'role_type', 'sort_order'],
        'book_characters': [
          'book_id', 'name', 'role', 'aliases', 'tags', 'description',
          'image_path', 'sort_order', 'is_deleted', 'created_at', 'updated_at',
        ],
      },
    ),
    'games': _DomainConfig(
      mainTable: 'games',
      parentColumn: 'game_id',
      rowTables: ['games', 'game_reviews', 'game_completions', 'game_characters'],
      groupTables: ['game_people', 'game_screenshots', 'game_levels'],
      tsColumn: {
        'games': 'updated_at',
        'game_reviews': 'updated_at',
        'game_completions': 'updated_at',
        'game_characters': 'updated_at',
      },
      columns: {
        'games': [
          'title', 'cover_path', 'rating', 'status', 'category', 'platforms', 'versions',
          'genres', 'play_time_hours', 'play_time_minutes', 'play_count', 'developer',
          'release_date', 'purchase_platforms', 'purchase_date', 'purchase_price',
          'summary', 'cover_offset', 'is_deleted', 'created_at', 'updated_at',
        ],
        'game_reviews': [
          'game_id', 'content', 'reviewer', 'source', 'review_type', 'review_date',
          'images', 'is_deleted', 'created_at', 'updated_at',
        ],
        'game_screenshots': [
          'game_id', 'screenshot_path', 'sort_order', 'is_deleted', 'created_at',
        ],
        'game_completions': [
          'game_id', 'completion_date', 'note',
          'is_deleted', 'created_at', 'updated_at',
        ],
        'game_levels': [
          'game_id', 'level_no', 'title', 'cleared', 'clear_date', 'rating', 'review',
          'images', 'is_deleted', 'created_at', 'updated_at',
        ],
        'game_people': ['game_id', 'person_id', 'role_type', 'sort_order'],
        'game_characters': [
          'game_id', 'name', 'role', 'aliases', 'tags', 'description',
          'image_path', 'sort_order', 'is_deleted', 'created_at', 'updated_at',
        ],
      },
    ),
    'notes': _DomainConfig(
      mainTable: 'notes',
      parentColumn: null,
      rowTables: ['notes'],
      groupTables: [],
      tsColumn: {'notes': 'updated_at'},
      columns: {
        'notes': [
          'title', 'content', 'content_type', 'tags', 'images', 'is_pinned',
          'is_deleted', 'created_at', 'updated_at',
        ],
      },
    ),
  };

  String get _base => '${ServerConfig.cloudApiBase}/app';
  String get _token => CloudAuthService.instance.token;

  /// 逻辑路径 -> 已上传云端 URL 的去重缓存
  final Map<String, String> _uploaded = {};

  /// 单个媒体域云端各表行数；主表为 0 即视为云端空库
  Future<Map<String, int>?> fetchCloudStatus(String domain) async {
    try {
      final resp = await http
          .post(Uri.parse('$_base/sync/domain/status'),
              headers: {'Content-Type': 'application/json', 'token': _token},
              body: jsonEncode({'domain': domain}))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) return null;
      return ((data['data'] as Map).map(
          (k, v) => MapEntry(k as String, (v as num?)?.toInt() ?? 0)));
    } catch (_) {
      return null;
    }
  }

  /// 本地整库上传到云端（domain 维度 replace：服务端先清空该域数据再插入）
  Future<CloudDomainResult> uploadLocalToCloud(
    String domain, {
    CloudDomainProgressCallback? onProgress,
  }) async {
    final config = _configs[domain];
    if (config == null) {
      return CloudDomainResult(success: false, message: '上传失败'.tr);
    }
    if (!CloudAuthService.instance.isLoggedIn) {
      return CloudDomainResult(success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
    }
    try {
      _uploaded.clear();
      final db = await DatabaseHelper.instance.database;
      final clientId = await SyncIdentity.clientId();

      // 预扫描：统计待上传图片与待推送记录总数
      final imagePaths = <String>{};
      final absByLogical = <String, String>{};
      var dataTotal = 0;
      for (final t in [...config.rowTables, ...config.groupTables]) {
        final rows = await db.query(t);
        if (config.rowTables.contains(t)) dataTotal += rows.length;
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

      final validLogical = <String>[];
      for (final logical in imagePaths) {
        final abs = absByLogical[logical];
        if (abs != null && await File(abs).exists()) {
          validLogical.add(logical);
        } else {
          doneImages++;
        }
      }

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
      debugPrint('[CloudDomain:$domain] 图片探测：本地有效 ${validLogical.length} 张，'
          '命中 ${validLogical.length - pending.length} 张，待上传 ${pending.length} 张');
      reportImageProgress();

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

      // 子组按父行 id 分桶，随主行 groups 上行
      final groupBuckets = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final t in config.groupTables) {
        final rows = await db.query(t);
        for (final r in rows) {
          final parentId = r[config.parentColumn!] as String;
          (groupBuckets.putIfAbsent(parentId, () => {}))
              .putIfAbsent(t, () => [])
              .add(await _toCloudRow(config, t, r, keepId: true));
        }
      }

      final ops = <Map<String, dynamic>>[];
      for (final t in config.rowTables) {
        final rows = await db.query(t);
        for (final r in rows) {
          final op = <String, dynamic>{
            't': t,
            'id': r['id'] as String,
            'ts': r[config.tsColumn[t]] as String,
            'row': await _toCloudRow(config, t, r),
          };
          if (t == config.mainTable && groupBuckets.containsKey(r['id'])) {
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
        final payload = () => jsonEncode({
              'c': clientId,
              'at': DateTime.now().toIso8601String(),
              'domain': domain,
              // 仅首批携带 replace，避免后续批次重复清库
              if (firstBatch) 'replace': true,
              'ops': slice,
              'img': <String, String>{},
            });
        Object? lastError;
        var accepted = false;
        // 单批失败重试 2 次：LWW 幂等 upsert 可安全重放，降低 replace 后半途失败造成残库的概率
        for (var attempt = 0; attempt < 3 && !accepted; attempt++) {
          try {
            final resp = await http
                .post(
                  Uri.parse('$_base/sync/push'),
                  headers: {'Content-Type': 'application/json', 'token': _token},
                  body: payload(),
                )
                .timeout(const Duration(seconds: 120));
            final data =
                jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
            if (data['code'] == 401) {
              await UserPrefs().clearCloudAccount();
              return CloudDomainResult(
                  success: false,
                  message: '登录失效，已切换成本地数据，请重新登录'.tr);
            }
            if (data['code'] != 0) {
              lastError = data['msg']?.toString() ?? '上传失败'.tr;
              continue;
            }
            accepted = true;
          } catch (e) {
            lastError = e;
          }
        }
        firstBatch = false;
        if (!accepted) {
          // 首批携带 replace，失败时服务端可能已清库或只写入部分，打标记待下次提示重传
          await UserPrefs().markCloudMigrationIncomplete(domain);
          return CloudDomainResult(
              success: false, message: lastError?.toString() ?? '上传失败'.tr);
        }
      }
      await UserPrefs().clearCloudMigrationIncomplete(domain);
      onProgress?.call(
        '正在上传数据（{done}/{total}）'.trf({'done': dataTotal, 'total': dataTotal}),
        dataTotal,
        dataTotal,
      );
      return CloudDomainResult(success: true, count: ops.length);
    } catch (e) {
      return CloudDomainResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  // ------------------------------------------------------------------
  // 行转换 / 图片上传
  // ------------------------------------------------------------------

  Future<Map<String, dynamic>> _toCloudRow(
    _DomainConfig config,
    String table,
    Map<String, dynamic> local, {
    bool keepId = false,
  }) async {
    final out = <String, dynamic>{};
    for (final col in config.columns[table]!) {
      if (col == 'id' && !keepId) continue;
      out[col] = local[col];
    }
    await _rewriteImageColumns(table, out);
    return out;
  }

  Future<void> _rewriteImageColumns(String table, Map<String, dynamic> row) async {
    if (table == 'books' || table == 'games') {
      row['cover_path'] = await _uploadIfLocal(row['cover_path'] as String?);
    } else if (table == 'book_reviews' ||
        table == 'book_chapters' ||
        table == 'game_reviews' ||
        table == 'game_levels' ||
        table == 'notes') {
      row['images'] = await _uploadJsonList(row['images'] as String?);
    } else if (table == 'game_screenshots') {
      row['screenshot_path'] = await _uploadIfLocal(row['screenshot_path'] as String?);
    } else if (table == 'book_characters' || table == 'game_characters') {
      row['image_path'] = await _uploadIfLocal(row['image_path'] as String?);
    }
  }

  Future<String?> _uploadIfLocal(String? value) async {
    if (value == null || value.isEmpty || value.startsWith('http')) return value;
    final logical = _toLogical(value);
    final cached = _uploaded[logical];
    if (cached != null) return cached;
    // 预扫描漏网（路径布局不符等）：文件还在就补传，避免本地路径写进云端行
    if (await File(value).exists()) {
      final url = await _uploadOne(logical, value);
      _uploaded[logical] = url;
      return url;
    }
    debugPrint('[CloudDomain] 本地图片丢失，云端行将保留不可访问的本地路径: $value');
    return value;
  }

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
      if (resp.statusCode != 200) return {};
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) return {};
      return ((data['data'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v?.toString() ?? ''));
    } catch (e) {
      return {};
    }
  }

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
    debugPrint('[CloudDomain] 实际上传: $logical -> $url');
    return url;
  }

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

    if (table == 'books' || table == 'games') {
      addSingle(row['cover_path'] as String?);
    } else if (table == 'book_reviews' ||
        table == 'book_chapters' ||
        table == 'game_reviews' ||
        table == 'game_levels' ||
        table == 'notes') {
      addJsonList(row['images'] as String?);
    } else if (table == 'game_screenshots') {
      addSingle(row['screenshot_path'] as String?);
    } else if (table == 'book_characters' || table == 'game_characters') {
      addSingle(row['image_path'] as String?);
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
    // 不符合标准布局时用完整路径哈希命名，避免不同目录同名文件映射到同一 OSS 对象
    final digest = sha1.convert(utf8.encode(normalized)).toString();
    return 'misc/$digest${p.extension(normalized)}';
  }
}

/// 单个媒体域的表结构配置
class _DomainConfig {
  final String mainTable;
  final String? parentColumn;
  final List<String> rowTables;
  final List<String> groupTables;
  final Map<String, String> tsColumn;
  final Map<String, List<String>> columns;

  const _DomainConfig({
    required this.mainTable,
    required this.parentColumn,
    required this.rowTables,
    required this.groupTables,
    required this.tsColumn,
    required this.columns,
  });
}
