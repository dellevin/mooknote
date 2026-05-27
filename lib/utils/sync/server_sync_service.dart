import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    if (!isConfigured || _isSyncing) return false;
    _isSyncing = true;
    try {
      final server = ServerDataService.instance;

      // 读取本地数据
      final localMovies = await MovieDao().getAllMovies();
      final localBooks = await BookDao().getAllBooks();
      final localNotes = await NoteDao().getAllNotes();

      // 读取服务端数据
      final remoteMovies = await server.getMovies();
      final remoteBooks = await server.getBooks();
      final remoteNotes = await server.getNotes();

      // 需要 push 到服务端的数据
      final pushMovies = <Movie>[];
      final pushBooks = <Book>[];
      final pushNotes = <Note>[];
      final imagePaths = <String>[];

      // 服务端无数据 → 全量 push
      if (remoteMovies.isEmpty && remoteBooks.isEmpty && remoteNotes.isEmpty) {
        pushMovies.addAll(localMovies);
        pushBooks.addAll(localBooks);
        pushNotes.addAll(localNotes);
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
      }

      // 批量 push 到服务端
      if (pushMovies.isNotEmpty || pushBooks.isNotEmpty || pushNotes.isNotEmpty) {
        final db = await DatabaseHelper.instance.database;
        final localTags = await db.query('tags');
        final result = await server.batchSync(
          movies: pushMovies.isEmpty ? null : pushMovies,
          books: pushBooks.isEmpty ? null : pushBooks,
          notes: pushNotes.isEmpty ? null : pushNotes,
          tags: localTags.isEmpty ? null : localTags.cast<Map<String, dynamic>>(),
        );
        debugPrint('[Sync] 批量推送: $result');

        // 收集需要上传的图片
        for (final m in pushMovies) {
          if (m.posterPath != null && m.posterPath!.isNotEmpty) imagePaths.add(m.posterPath!);
        }
        for (final b in pushBooks) {
          if (b.coverPath != null && b.coverPath!.isNotEmpty) imagePaths.add(b.coverPath!);
        }
        for (final n in pushNotes) {
          imagePaths.addAll(n.images.where((i) => i.isNotEmpty));
        }
      }

      // 上传图片
      if (imagePaths.isNotEmpty) {
        debugPrint('[Sync] 上传 ${imagePaths.length} 张图片');
        await ServerDataService.uploadLocalImages(imagePaths);
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

  /// 关闭同步：从服务器下载数据到本地
  Future<bool> downloadToLocal() async {
    if (!isConfigured || _isSyncing) return false;
    _isSyncing = true;
    try {
      final url = _prefs.syncServerUrl;
      final code = _prefs.syncActivationCode;
      final deviceId = _prefs.deviceId;

      final infoResp = await http.post(
        Uri.parse('$url/api/sync/info'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code","device_id":"$deviceId"}',
      ).timeout(const Duration(seconds: 15));
      if (infoResp.statusCode != 200) return false;

      final info = _jsonDecode(infoResp.body);
      if (info == null || info['has_backup'] != true) return false;

      final dbResp = await http.post(
        Uri.parse('$url/api/sync/download/database'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code"}',
      ).timeout(const Duration(seconds: 120));
      if (dbResp.statusCode != 200) return false;

      final dbPath = await DatabaseHelper.instance.databasePath;
      if (dbPath != null) {
        await DatabaseHelper.instance.close();
        await File(dbPath).writeAsBytes(dbResp.bodyBytes);
        await DatabaseHelper.instance.reopen();
      }

      final images = (info['images'] as List<dynamic>?)
          ?.map((e) => e is Map ? {'name': e['name'] as String, 'rel_path': e['rel_path'] as String} : null)
          .where((e) => e != null).cast<Map<String, String>>().toList() ?? [];

      final appDir = await getApplicationDocumentsDirectory();
      for (final img in images) {
        try {
          final relPath = img['rel_path']!;
          final imgResp = await http.get(
            Uri.parse('$url/api/sync/download/image/$code/$relPath'),
          ).timeout(const Duration(seconds: 30));
          if (imgResp.statusCode == 200) {
            final dest = File(p.join(appDir.path, relPath));
            await dest.parent.create(recursive: true);
            await dest.writeAsBytes(imgResp.bodyBytes);
          }
        } catch (_) {}
      }

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
