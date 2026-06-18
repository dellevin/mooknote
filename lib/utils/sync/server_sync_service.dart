import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../user_prefs.dart';
import '../database_helper.dart';
import '../../models/data_models.dart';
import '../movie/movie_dao.dart';
import '../book/book_dao.dart';
import '../note/note_dao.dart';
import 'server_data_service.dart';

/// 服务端实时同步服务
/// - 开启时：智能合并本地与服务端数据
/// - 关闭时：从服务器下载数据到本地
class ServerSyncService {
  static final ServerSyncService instance = ServerSyncService._();
  ServerSyncService._();

  final UserPrefs _prefs = UserPrefs();
  bool _isSyncing = false;

  bool get isConfigured {
    return _prefs.syncServerUrl.isNotEmpty && _prefs.syncActivationCode.isNotEmpty;
  }

  Future<Map<String, dynamic>?> checkActivation() async {
    final url = _prefs.syncServerUrl;
    final code = _prefs.syncActivationCode;
    final deviceId = _prefs.deviceId;
    if (url.isEmpty || code.isEmpty || deviceId.isEmpty) return null;
    try {
      final resp = await http.post(
        Uri.parse('$url/api/activate'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code","device_id":"$deviceId"}',
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200
          ? _jsonDecode(resp.body)
          : {'valid': false, 'error': '激活码无效'};
    } catch (_) {
      return {'valid': false, 'error': '无法连接服务器'};
    }
  }

  Map<String, dynamic>? _jsonDecode(String s) {
    try { final d = jsonDecode(s); return d is Map<String, dynamic> ? d : null; } catch (_) { return null; }
  }

  /// 开启同步：智能合并本地与服务端数据
  Future<bool> syncWithServer() async {
    if (!isConfigured || _isSyncing) {
      debugPrint('[Sync] 跳过: configured=$isConfigured syncing=$_isSyncing');
      return false;
    }
    _isSyncing = true;
    try {
      debugPrint('[Sync] ========== 开始同步 ==========');
      final server = ServerDataService.instance;

      // 读取本地数据
      final localMovies = await MovieDao().getAllMovies();
      final localBooks = await BookDao().getAllBooks();
      final localNotes = await NoteDao().getAllNotes();
      final db = await DatabaseHelper.instance.database;
      final localMovieReviews = await db.query('movie_reviews');
      final localMoviePosters = await db.query('movie_posters');
      final localBookReviews = await db.query('book_reviews');
      final localBookExcerpts = await db.query('book_excerpts');

      debugPrint('[Sync] 本地: 影视${localMovies.length} 书籍${localBooks.length} 笔记${localNotes.length} '
          '影评${localMovieReviews.length} 海报${localMoviePosters.length} '
          '书评${localBookReviews.length} 书摘${localBookExcerpts.length}');

      // 读取服务端数据
      final remoteMovies = await server.getMovies();
      final remoteBooks = await server.getBooks();
      final remoteNotes = await server.getNotes();

      debugPrint('[Sync] 服务端: 影视${remoteMovies.length} 书籍${remoteBooks.length} 笔记${remoteNotes.length}');

      // 需要 push 到服务端的数据
      final pushMovies = <Movie>[];
      final pushBooks = <Book>[];
      final pushNotes = <Note>[];
      final pushMovieReviews = <Map<String, dynamic>>[];
      final pushMoviePosters = <Map<String, dynamic>>[];
      final pushBookReviews = <Map<String, dynamic>>[];
      final pushBookExcerpts = <Map<String, dynamic>>[];

      // 服务端无数据 → 全量 push
      if (remoteMovies.isEmpty && remoteBooks.isEmpty && remoteNotes.isEmpty) {
        pushMovies.addAll(localMovies);
        pushBooks.addAll(localBooks);
        pushNotes.addAll(localNotes);
        pushMovieReviews.addAll(localMovieReviews);
        pushMoviePosters.addAll(localMoviePosters);
        pushBookReviews.addAll(localBookReviews);
        pushBookExcerpts.addAll(localBookExcerpts);
      } else {
        // 按 updated_at 合并
        final remoteMovieMap = {for (final m in remoteMovies) m.id: m};
        for (final m in localMovies) {
          final r = remoteMovieMap.remove(m.id);
          if (r == null || m.updatedAt.isAfter(r.updatedAt)) {
            pushMovies.add(m);
          } else {
            await _upsertLocalMovie(m: r);
          }
        }
        for (final r in remoteMovieMap.values) {
          await _upsertLocalMovie(m: r);
        }

        final remoteBookMap = {for (final b in remoteBooks) b.id: b};
        for (final b in localBooks) {
          final r = remoteBookMap.remove(b.id);
          if (r == null || b.updatedAt.isAfter(r.updatedAt)) {
            pushBooks.add(b);
          } else {
            await _upsertLocalBook(b: r);
          }
        }
        for (final r in remoteBookMap.values) {
          await _upsertLocalBook(b: r);
        }

        final remoteNoteMap = {for (final n in remoteNotes) n.id: n};
        for (final n in localNotes) {
          final r = remoteNoteMap.remove(n.id);
          if (r == null || n.updatedAt.isAfter(r.updatedAt)) {
            pushNotes.add(n);
          } else {
            await _upsertLocalNote(n: r);
          }
        }
        for (final r in remoteNoteMap.values) {
          await _upsertLocalNote(n: r);
        }

        // 子表合并：movie_reviews / movie_posters / book_reviews / book_excerpts
        await _mergeSubTable(db, server, 'movie_reviews', localMovieReviews, pushMovieReviews);
        await _mergeSubTable(db, server, 'movie_posters', localMoviePosters, pushMoviePosters);
        await _mergeSubTable(db, server, 'book_reviews', localBookReviews, pushBookReviews);
        await _mergeSubTable(db, server, 'book_excerpts', localBookExcerpts, pushBookExcerpts);
      }

      // 收集所有本地图片路径
      final allImagePaths = _collectAllLocalImages(
        localMovies, localBooks, localNotes, localMoviePosters);
      debugPrint('[Sync] 全部图片: ${allImagePaths.length} 张');

      // 先下载本地缺失的图片
      final missingImages = <String>[];
      final existingImages = <String>[];
      for (final p in allImagePaths) {
        if (await File(p).exists()) {
          existingImages.add(p);
        } else {
          missingImages.add(p);
        }
      }
      debugPrint('[Sync] 缺失${missingImages.length}张 现有${existingImages.length}张');

      if (missingImages.isNotEmpty) {
        debugPrint('[Sync] 下载缺失图片...');
        final appDir = (await getApplicationDocumentsDirectory()).path;
        for (final path in missingImages) {
          try {
            final relPath = p.relative(path, from: appDir).replaceAll('\\', '/');
            final url = '${_prefs.syncServerUrl}/api/data/image/${_prefs.syncActivationCode}/$relPath';
            final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
            if (resp.statusCode == 200) {
              final dest = File(path);
              await dest.parent.create(recursive: true);
              await dest.writeAsBytes(resp.bodyBytes);
            }
          } catch (_) {}
        }
        debugPrint('[Sync] 缺失图片下载完成');
      }

      // 上传本地已有图片
      if (existingImages.isNotEmpty) {
        debugPrint('[Sync] 上传 ${existingImages.length} 张现有图片...');
        await ServerDataService.uploadLocalImages(existingImages);
      }

      // 批量 push 数据到服务端
      final hasPush = pushMovies.isNotEmpty || pushBooks.isNotEmpty || pushNotes.isNotEmpty ||
          pushMovieReviews.isNotEmpty || pushMoviePosters.isNotEmpty ||
          pushBookReviews.isNotEmpty || pushBookExcerpts.isNotEmpty;
      debugPrint('[Sync] hasPush=$hasPush');
      if (hasPush) {
        final localTags = await db.query('tags');
        final result = await server.batchSync(
          movies: pushMovies.isEmpty ? null : pushMovies,
          books: pushBooks.isEmpty ? null : pushBooks,
          notes: pushNotes.isEmpty ? null : pushNotes,
          tags: localTags.isEmpty ? null : localTags.cast<Map<String, dynamic>>(),
          movieReviews: pushMovieReviews.isEmpty ? null : pushMovieReviews,
          moviePosters: pushMoviePosters.isEmpty ? null : pushMoviePosters,
          bookReviews: pushBookReviews.isEmpty ? null : pushBookReviews,
          bookExcerpts: pushBookExcerpts.isEmpty ? null : pushBookExcerpts,
        );
        debugPrint('[Sync] batchSync 结果: $result');
      }

      debugPrint('[Sync] 合并完成');
      return true;
    } catch (e) {
      debugPrint('[Sync] 合并异常: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // ─── 合并辅助方法 ────────────────────────────────────────────

  Future<void> _upsertLocalMovie({required Movie m}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('movies', m.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertLocalBook({required Book b}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('books', b.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _upsertLocalNote({required Note n}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('notes', n.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 收集所有实际存在的本地图片路径
  List<String> _collectAllLocalImages(List<Movie> movies, List<Book> books,
      List<Note> notes, List<Map<String, dynamic>> posters) {
    final paths = <String>[];
    for (final m in movies) {
      if (m.posterPath != null && m.posterPath!.isNotEmpty) paths.add(m.posterPath!);
    }
    for (final b in books) {
      if (b.coverPath != null && b.coverPath!.isNotEmpty) paths.add(b.coverPath!);
    }
    for (final n in notes) {
      paths.addAll(n.images.where((i) => i.isNotEmpty));
    }
    for (final p in posters) {
      final pp = p['poster_path'] as String?;
      if (pp != null && pp.isNotEmpty) paths.add(pp);
    }
    return paths;
  }

  /// 合并子表（reviews/posters/excerpts）：本地优先 push，服务端补充
  Future<void> _mergeSubTable(Database db, ServerDataService server, String table,
      List<Map<String, dynamic>> local, List<Map<String, dynamic>> pushList) async {
    // 尝试获取服务端数据
    List<Map<String, dynamic>> remote = [];
    bool serverOk = false;
    try {
      switch (table) {
        case 'movie_reviews':
          remote = (await server.getAllMovieReviews()).map((r) => r.toJson()).toList();
        case 'movie_posters':
          remote = (await server.getAllMoviePosters()).map((p) => p.toJson()).toList();
        case 'book_reviews':
          remote = (await server.getAllBookReviews()).map((r) => r.toJson()).toList();
        case 'book_excerpts':
          remote = (await server.getAllBookExcerpts()).map((e) => e.toJson()).toList();
      }
      serverOk = true;
    } catch (_) {}

    if (!serverOk) {
      // 服务端不可用 → 全量 push 本地数据
      pushList.addAll(local);
      return;
    }

    final remoteMap = {for (final r in remote) r['id'] as String: r};
    for (final l in local) {
      final r = remoteMap.remove(l['id'] as String);
      if (r == null) {
        pushList.add(l);
      } else {
        final lTime = l['updated_at'] as String? ?? '';
        final rTime = r['updated_at'] as String? ?? '';
        if (lTime.compareTo(rTime) > 0) pushList.add(l);
      }
    }
    // 服务端有、本地无 → 写入本地
    for (final r in remoteMap.values) {
      await db.insert(table, r, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// 关闭同步：上传完整备份到服务器后切回本地
  Future<bool> uploadBackupAndDisconnect() async {
    if (!isConfigured || _isSyncing) return false;
    _isSyncing = true;
    try {
      debugPrint('[Sync] ========== 关闭同步：上传备份 ==========');
      final url = _prefs.syncServerUrl;
      final code = _prefs.syncActivationCode;
      final deviceId = _prefs.deviceId;
      final appDir = (await getApplicationDocumentsDirectory()).path;

      // 上传数据库
      final dbPath = await DatabaseHelper.instance.databasePath;
      final request = http.MultipartRequest('POST', Uri.parse('$url/api/sync/upload'));
      request.fields['code'] = code;
      request.fields['device_id'] = deviceId;
      if (dbPath != null && File(dbPath).existsSync()) {
        request.files.add(await http.MultipartFile(
          'database', File(dbPath).readAsBytes().asStream(), await File(dbPath).length(),
          filename: 'mooknote.db',
        ));
        debugPrint('[Sync] 上传数据库: ${await File(dbPath).length()} bytes');
      }

      // 收集并上传所有图片
      final imagePaths = _collectAllImageFiles(appDir);
      debugPrint('[Sync] 上传 ${imagePaths.length} 张图片...');
      for (final path in imagePaths) {
        final relPath = p.relative(path, from: appDir).replaceAll('\\', '/');
        if (await File(path).exists()) {
          request.files.add(await http.MultipartFile(
            'images', File(path).readAsBytes().asStream(), await File(path).length(),
            filename: relPath,
          ));
        }
      }

      final resp = await request.send().timeout(const Duration(seconds: 300));
      final body = await resp.stream.bytesToString();
      debugPrint('[Sync] 上传备份响应: ${resp.statusCode} $body');

      if (resp.statusCode == 200) {
        debugPrint('[Sync] 备份上传成功，关闭同步');
      }
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('[Sync] 上传备份异常: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 收集所有图片文件（递归扫描 images 目录）
  List<String> _collectAllImageFiles(String appDir) {
    final paths = <String>[];
    final imagesDir = Directory(p.join(appDir, 'images'));
    if (!imagesDir.existsSync()) return paths;
    for (final entity in imagesDir.listSync(recursive: true)) {
      if (entity is File) {
        paths.add(entity.path);
      }
    }
    return paths;
  }
  Future<bool> downloadToLocal() async {
    if (!isConfigured || _isSyncing) {
      debugPrint('[Sync] downloadToLocal 跳过: configured=$isConfigured syncing=$_isSyncing');
      return false;
    }
    _isSyncing = true;
    try {
      debugPrint('[Sync] ========== 关闭同步：从服务器下载 ==========');
      final url = _prefs.syncServerUrl;
      final code = _prefs.syncActivationCode;
      final deviceId = _prefs.deviceId;

      debugPrint('[Sync] 查询备份信息...');
      final infoResp = await http.post(
        Uri.parse('$url/api/sync/info'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code","device_id":"$deviceId"}',
      ).timeout(const Duration(seconds: 15));
      debugPrint('[Sync] /api/sync/info 响应: ${infoResp.statusCode}');
      if (infoResp.statusCode != 200) return false;

      final info = _jsonDecode(infoResp.body);
      debugPrint('[Sync] info: $info');
      if (info == null || info['has_backup'] != true) {
        debugPrint('[Sync] 服务器无备份，跳过下载');
        return false;
      }

      debugPrint('[Sync] 下载数据库...');
      final dbResp = await http.post(
        Uri.parse('$url/api/sync/download/database'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code"}',
      ).timeout(const Duration(seconds: 120));
      debugPrint('[Sync] 数据库下载响应: ${dbResp.statusCode} size=${dbResp.bodyBytes.length}');
      if (dbResp.statusCode != 200) return false;

      await DatabaseHelper.instance.reopenDatabaseFromBytes(dbResp.bodyBytes);
      debugPrint('[Sync] 数据库已重写并重新打开');

      final images = (info['images'] as List<dynamic>?)
          ?.map((e) => e is Map ? {'name': e['name'] as String, 'rel_path': e['rel_path'] as String} : null)
          .where((e) => e != null).cast<Map<String, String>>().toList() ?? [];

      debugPrint('[Sync] 下载 ${images.length} 张图片...');
      final appDir = await getApplicationDocumentsDirectory();
      int downloaded = 0;
      for (final img in images) {
        try {
          final relPath = img['rel_path']!.replaceAll('\\', '/');
          final imgResp = await http.get(
            Uri.parse('$url/api/sync/download/image/$code/$relPath'),
          ).timeout(const Duration(seconds: 30));
          if (imgResp.statusCode == 200) {
            final dest = File(p.join(appDir.path, relPath));
            await dest.parent.create(recursive: true);
            await dest.writeAsBytes(imgResp.bodyBytes);
            downloaded++;
          }
        } catch (_) {}
      }
      debugPrint('[Sync] 下载完成: 数据库 + $downloaded/${images.length} 张图片');

      debugPrint('[Sync] 下载到本地完成');
      return true;
    } catch (e) {
      debugPrint('[Sync] 下载到本地异常: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }
}
