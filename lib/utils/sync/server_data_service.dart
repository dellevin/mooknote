import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/data_models.dart';
import '../user_prefs.dart';

/// 服务端数据服务 - 所有数据操作通过远程 API
class ServerDataService {
  static final ServerDataService instance = ServerDataService._();
  ServerDataService._();

  final UserPrefs _prefs = UserPrefs();

  String get _baseUrl => _prefs.syncServerUrl;
  String get _code => _prefs.syncActivationCode;

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Map<String, dynamic> _body([Map<String, dynamic>? extra]) {
    return {'code': _code, ...?extra};
  }

  bool get isAvailable => _baseUrl.isNotEmpty && _code.isNotEmpty;

  Future<dynamic> _post(String path, [Map<String, dynamic>? extra]) async {
    try {
      final url = '$_baseUrl$path';
      debugPrint('[ServerData] POST $url');
      final resp = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(_body(extra)),
      ).timeout(const Duration(seconds: 30));
      debugPrint('[ServerData] ${resp.statusCode} $path');
      if (resp.statusCode != 200) return null;
      return jsonDecode(resp.body);
    } catch (e) {
      debugPrint('[ServerData] ERROR $path: $e');
      return null;
    }
  }

  // ─── 影视 ────────────────────────────────────────────────────

  Future<List<Movie>> getMovies({String? status, int? limit, int? offset}) async {
    final body = <String, dynamic>{};
    if (status != null && status.isNotEmpty) body['status'] = status;
    if (limit != null) body['limit'] = limit;
    if (offset != null) body['offset'] = offset;
    final data = await _post('/api/data/movies', body.isEmpty ? null : body);
    if (data == null || data['movies'] == null) return [];
    return (data['movies'] as List).map((m) => Movie.fromJson(m as Map<String, dynamic>)).toList();
  }

  Future<bool> saveMovie(Movie movie) async {
    final data = await _post('/api/data/movie/save', {'movie': movie.toJson()});
    return data != null;
  }

  Future<bool> deleteMovie(String id) async {
    final data = await _post('/api/data/movie/delete', {'id': id});
    return data != null;
  }

  // ─── 书籍 ────────────────────────────────────────────────────

  Future<List<Book>> getBooks({String? status, int? limit, int? offset}) async {
    final body = <String, dynamic>{};
    if (status != null && status.isNotEmpty) body['status'] = status;
    if (limit != null) body['limit'] = limit;
    if (offset != null) body['offset'] = offset;
    final data = await _post('/api/data/books', body.isEmpty ? null : body);
    if (data == null || data['books'] == null) return [];
    return (data['books'] as List).map((b) => Book.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<bool> saveBook(Book book) async {
    final data = await _post('/api/data/book/save', {'book': book.toJson()});
    return data != null;
  }

  Future<bool> deleteBook(String id) async {
    final data = await _post('/api/data/book/delete', {'id': id});
    return data != null;
  }

  // ─── 笔记 ────────────────────────────────────────────────────

  Future<List<Note>> getNotes({int? limit, int? offset}) async {
    final body = <String, dynamic>{};
    if (limit != null) body['limit'] = limit;
    if (offset != null) body['offset'] = offset;
    final data = await _post('/api/data/notes', body.isEmpty ? null : body);
    if (data == null || data['notes'] == null) return [];
    return (data['notes'] as List).map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
  }

  Future<bool> saveNote(Note note) async {
    final data = await _post('/api/data/note/save', {'note': note.toJson()});
    return data != null;
  }

  Future<bool> deleteNote(String id) async {
    final data = await _post('/api/data/note/delete', {'id': id});
    return data != null;
  }

  // ─── 批量同步 ────────────────────────────────────────────────

  Future<Map<String, int>> batchSync({
    List<Movie>? movies,
    List<Book>? books,
    List<Note>? notes,
    List<Map<String, dynamic>>? tags,
  }) async {
    final data = await _post('/api/data/batch_sync', {
      if (movies != null) 'movies': movies.map((m) => m.toJson()).toList(),
      if (books != null) 'books': books.map((b) => b.toJson()).toList(),
      if (notes != null) 'notes': notes.map((n) => n.toJson()).toList(),
      if (tags != null) 'tags': tags,
    });
    if (data == null) return {};
    return {
      'movies': (data['movies'] as int?) ?? 0,
      'books': (data['books'] as int?) ?? 0,
      'notes': (data['notes'] as int?) ?? 0,
      'tags': (data['tags'] as int?) ?? 0,
    };
  }

  // ─── 标签 ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTags(String? type) async {
    final data = await _post('/api/data/tags', type != null ? {'type': type} : null);
    if (data == null || data['tags'] == null) return [];
    return (data['tags'] as List).map((t) => Map<String, dynamic>.from(t as Map)).toList();
  }

  Future<bool> saveTag(String name, String type) async {
    final data = await _post('/api/data/tag/save', {'tag': {'name': name, 'type': type}});
    return data != null;
  }

  Future<bool> deleteTag(String id) async {
    final data = await _post('/api/data/tag/delete', {'id': id});
    return data != null;
  }

  // ─── 图片 ────────────────────────────────────────────────────

  /// 是否激活（AppProvider 也会用这个检查）
  static bool get isActive {
    final p = UserPrefs();
    return p.syncEnabled && p.syncServerUrl.isNotEmpty && p.syncActivationCode.isNotEmpty;
  }

  /// 将本地路径转为服务端图片 URL
  static Future<String> toImageUrl(String localPath) async {
    if (!isActive) return localPath;
    final appDir = (await getApplicationDocumentsDirectory()).path;
    final relPath = p.relative(localPath, from: appDir).replaceAll('\\', '/');
    final prefs = UserPrefs();
    return '${prefs.syncServerUrl}/api/data/image/${prefs.syncActivationCode}/$relPath';
  }

  /// 批量上传图片到服务端（自动计算相对路径）
  static Future<void> uploadLocalImages(List<String> filePaths) async {
    if (!isActive || filePaths.isEmpty) return;
    final result = await instance.uploadImages(filePaths);
    debugPrint('[Sync] 上传 ${result.length}/${filePaths.length} 张图片');
  }

  /// 上传单张图片到服务端
  static Future<void> uploadLocalImage(String filePath) async {
    if (!isActive || filePath.isEmpty) return;
    final result = await instance.uploadImage(filePath);
    debugPrint('[Sync] 上传图片: ${result ?? "失败"}');
  }

  String imageUrl(String relPath) {
    return '$_baseUrl/api/data/image/$_code/$relPath';
  }

  Future<List<String>> uploadImages(List<String> filePaths) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/data/image/upload'));
    request.fields['code'] = _code;
    final appDir = (await getApplicationDocumentsDirectory()).path;
    for (final path in filePaths) {
      final relPath = p.relative(path, from: appDir).replaceAll('\\', '/');
      final file = File(path);
      request.files.add(await http.MultipartFile(
        'images', file.readAsBytes().asStream(), await file.length(),
        filename: relPath,
      ));
    }
    final resp = await request.send().timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) return [];
    final body = await resp.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    return (data['files'] as List?)?.cast<String>() ?? [];
  }

  Future<String?> uploadImage(String filePath) async {
    final files = await uploadImages([filePath]);
    return files.isNotEmpty ? files.first : null;
  }
}
