import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../user_prefs.dart';

/// 数据备份服务 - 支持导出和导入数据（包含图片）
class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  // ─── 共享导出逻辑 ─────────────────────────────────────

  /// 收集所有表数据和图片，构建 ZIP 字节
  Future<_ExportData> _buildExportData() async {
    final db = await DatabaseHelper.instance.database;

    final movies = await db.query('movies');
    final books = await db.query('books');
    final notes = await db.query('notes');
    final movieReviews = await db.query('movie_reviews');
    final moviePosters = await db.query('movie_posters');
    final bookReviews = await db.query('book_reviews');
    final bookExcerpts = await db.query('book_excerpts');
    final tags = await db.query('tags');

    // 收集图片路径
    final imagePaths = <String>{};
    for (final m in movies) {
      final p = m['poster_path'] as String?;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
    }
    for (final b in books) {
      final p = b['cover_path'] as String?;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
    }
    for (final p in moviePosters) {
      final pp = p['poster_path'] as String?;
      if (pp != null && pp.isNotEmpty) imagePaths.add(pp);
    }
    for (final n in notes) {
      final imagesJson = n['images'] as String?;
      if (imagesJson != null && imagesJson.isNotEmpty) {
        try {
          for (final ip in jsonDecode(imagesJson) as List<dynamic>) {
            if (ip is String && ip.isNotEmpty) imagePaths.add(ip);
          }
        } catch (e) {
          debugPrint('[BackupService] 笔记图片解析失败 (noteId=${n['id']}): $e');
        }
      }
    }

    final userPrefs = UserPrefs();
    final userInfo = {
      'nickname': userPrefs.nickname,
      'motto': userPrefs.motto,
      'avatarPath': userPrefs.avatarPath,
    };
    final avatarPath = userPrefs.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) imagePaths.add(avatarPath);

    // 构建备份数据
    final backupData = {
      'version': 2,
      'exportTime': DateTime.now().toIso8601String(),
      'appName': 'MookNote',
      'hasImages': true,
      'userInfo': userInfo,
      'data': {
        'movies': movies,
        'books': books,
        'notes': notes,
        'movie_reviews': movieReviews,
        'movie_posters': moviePosters,
        'book_reviews': bookReviews,
        'book_excerpts': bookExcerpts,
        'tags': tags,
      },
    };

    // 创建 ZIP
    final archive = Archive();
    final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    int imageCount = 0;
    final appDir = await getApplicationDocumentsDirectory();
    final imagesRoot = path.join(appDir.path, 'images');

    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        String relativePath;
        if (imagePath.startsWith(imagesRoot)) {
          relativePath = imagePath.substring(imagesRoot.length + 1);
        } else {
          relativePath = path.basename(imagePath);
        }
        archive.addFile(ArchiveFile('images/$relativePath', bytes.length, bytes));
        imageCount++;
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) throw Exception('压缩备份文件失败');

    return _ExportData(
      zipBytes: Uint8List.fromList(zipBytes),
      movieCount: movies.length,
      bookCount: books.length,
      noteCount: notes.length,
      imageCount: imageCount,
    );
  }

  // ─── 手动导出 ─────────────────────────────────────────

  /// 导出所有数据和图片为 ZIP 文件，并选择保存路径
  Future<ExportResult> exportDataWithImages() async {
    try {
      final data = await _buildExportData();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'mooknote_backup_${_formatDateTime(DateTime.now())}.zip';
      final tempFilePath = path.join(tempDir.path, fileName);
      await File(tempFilePath).writeAsBytes(data.zipBytes);

      String? finalPath;
      try {
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存备份文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: data.zipBytes,
        );
        if (outputPath == null) {
          return ExportResult.cancelled();
        }
        finalPath = outputPath;
        if (finalPath != tempFilePath) {
          await File(finalPath).writeAsBytes(data.zipBytes);
        }
      } catch (e) {
        finalPath = tempFilePath;
      }

      return ExportResult.success(
        filePath: finalPath,
        movieCount: data.movieCount,
        bookCount: data.bookCount,
        noteCount: data.noteCount,
        imageCount: data.imageCount,
      );
    } catch (e) {
      return ExportResult.error('导出失败: $e');
    }
  }

  /// 分享备份文件
  Future<void> shareBackup(String filePath) async {
    final file = XFile(filePath);
    await Share.shareXFiles([file], subject: 'MookNote 数据备份', text: '这是我的 MookNote 数据备份文件');
  }

  // ─── 自动备份导出 ─────────────────────────────────────

  /// 导出数据用于自动备份（返回字节数据）
  Future<AutoBackupExportResult> exportDataForAutoBackup() async {
    try {
      final data = await _buildExportData();
      return AutoBackupExportResult.success(
        zipBytes: data.zipBytes,
        movieCount: data.movieCount,
        bookCount: data.bookCount,
        noteCount: data.noteCount,
        imageCount: data.imageCount,
      );
    } catch (e) {
      return AutoBackupExportResult.error('导出失败: $e');
    }
  }

  // ─── 导入 ─────────────────────────────────────────────

  /// 选择并导入备份文件（支持 ZIP 和旧版 JSON）
  Future<ImportResult> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return ImportResult.cancelled();

      final filePath = result.files.first.path;
      if (filePath == null) return ImportResult.error('无法读取文件路径');

      final file = File(filePath);
      final extension = path.extension(filePath).toLowerCase();

      Map<String, dynamic> backupData;
      int imageCount = 0;
      // 完整相对路径 → 新绝对路径 的映射（避免同名文件碰撞）
      final imagePathMap = <String, String>{};

      if (extension == '.zip') {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);

        final dataFile = archive.findFile('data.json');
        if (dataFile == null) return ImportResult.error('备份文件中没有找到数据文件');

        backupData = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;

        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(path.join(appDir.path, 'images'));
        if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

        for (final archiveFile in archive) {
          if (archiveFile.name.startsWith('images/')) {
            final relativePath = archiveFile.name.substring(7);
            final outputFile = File(path.join(imagesDir.path, relativePath));
            if (!await outputFile.parent.exists()) await outputFile.parent.create(recursive: true);
            await outputFile.writeAsBytes(archiveFile.content as List<int>);
            // 用完整相对路径做 key，避免不同目录下同名文件碰撞
            imagePathMap[relativePath] = outputFile.path;
            imageCount++;
          }
        }
      } else {
        // 旧版 JSON
        backupData = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }

      if (!backupData.containsKey('data')) return ImportResult.error('无效的备份文件格式');

      // 验证版本
      final version = backupData['version'] as int? ?? 1;
      if (version > 2) {
        debugPrint('[BackupService] 警告: 备份版本 $version 高于当前支持的版本 2，部分数据可能丢失');
      }

      final data = backupData['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      final moviesCols = await _getTableColumns(db, 'movies');
      final booksCols = await _getTableColumns(db, 'books');
      final notesCols = await _getTableColumns(db, 'notes');
      final movieReviewsCols = await _getTableColumns(db, 'movie_reviews');
      final moviePostersCols = await _getTableColumns(db, 'movie_posters');
      final bookReviewsCols = await _getTableColumns(db, 'book_reviews');
      final bookExcerptsCols = await _getTableColumns(db, 'book_excerpts');
      final tagsCols = await _getTableColumns(db, 'tags');

      await db.transaction((txn) async {
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('book_reviews');
        await txn.delete('book_excerpts');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        await txn.delete('tags');

        if (data.containsKey('movies')) {
          for (final m in data['movies'] as List) {
            await txn.insert('movies', _updateImagePath(_convertToDbMapSafe(m, moviesCols), 'poster_path', imagePathMap));
          }
        }
        if (data.containsKey('books')) {
          for (final b in data['books'] as List) {
            await txn.insert('books', _updateImagePath(_convertToDbMapSafe(b, booksCols), 'cover_path', imagePathMap));
          }
        }
        if (data.containsKey('notes')) {
          for (final n in data['notes'] as List) {
            await txn.insert('notes', _updateNoteImagesPath(_convertToDbMapSafe(n, notesCols), imagePathMap));
          }
        }
        if (data.containsKey('movie_reviews')) {
          for (final r in data['movie_reviews'] as List) {
            await txn.insert('movie_reviews', _convertToDbMapSafe(r, movieReviewsCols));
          }
        }
        if (data.containsKey('movie_posters')) {
          for (final p in data['movie_posters'] as List) {
            await txn.insert('movie_posters', _updateImagePath(_convertToDbMapSafe(p, moviePostersCols), 'poster_path', imagePathMap));
          }
        }
        if (data.containsKey('book_reviews')) {
          for (final r in data['book_reviews'] as List) {
            await txn.insert('book_reviews', _convertToDbMapSafe(r, bookReviewsCols));
          }
        }
        if (data.containsKey('book_excerpts')) {
          for (final e in data['book_excerpts'] as List) {
            await txn.insert('book_excerpts', _convertToDbMapSafe(e, bookExcerptsCols));
          }
        }
        if (data.containsKey('tags')) {
          for (final t in data['tags'] as List) {
            final map = _convertToDbMapSafe(t, tagsCols);
            await txn.rawInsert(
              'INSERT OR IGNORE INTO tags (id, name, type, created_at) VALUES (?, ?, ?, ?)',
              [map['id'], map['name'], map['type'], map['created_at']],
            );
          }
        }
      });

      // 恢复用户信息
      await _restoreUserInfo(backupData, imagePathMap);

      return ImportResult.success(_buildStats(data, imageCount));
    } catch (e) {
      return ImportResult.error('导入失败: $e');
    }
  }

  /// 从 ZIP 字节数据恢复（供 WebDAV 同步等场景使用）
  Future<ImportResult> restoreFromZipBytes(Uint8List zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) return ImportResult.error('备份文件中没有找到数据文件');

      final backupData = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
      final imagePathMap = <String, String>{};
      int imageCount = 0;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      for (final archiveFile in archive) {
        if (archiveFile.name.startsWith('images/')) {
          final relativePath = archiveFile.name.substring(7);
          final outputFile = File(path.join(imagesDir.path, relativePath));
          if (!await outputFile.parent.exists()) await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(archiveFile.content as List<int>);
          imagePathMap[relativePath] = outputFile.path;
          imageCount++;
        }
      }

      if (!backupData.containsKey('data')) return ImportResult.error('无效的备份文件格式');

      final version = backupData['version'] as int? ?? 1;
      if (version > 2) {
        debugPrint('[BackupService] 警告: 备份版本 $version 高于当前支持的版本 2，部分数据可能丢失');
      }

      final data = backupData['data'] as Map<String, dynamic>;
      final db = await DatabaseHelper.instance.database;

      final moviesCols = await _getTableColumns(db, 'movies');
      final booksCols = await _getTableColumns(db, 'books');
      final notesCols = await _getTableColumns(db, 'notes');
      final movieReviewsCols = await _getTableColumns(db, 'movie_reviews');
      final moviePostersCols = await _getTableColumns(db, 'movie_posters');
      final bookReviewsCols = await _getTableColumns(db, 'book_reviews');
      final bookExcerptsCols = await _getTableColumns(db, 'book_excerpts');
      final tagsCols = await _getTableColumns(db, 'tags');

      await db.transaction((txn) async {
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('book_reviews');
        await txn.delete('book_excerpts');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        await txn.delete('tags'); // 修复: 之前漏删 tags 表

        if (data.containsKey('movies')) {
          for (final m in data['movies'] as List) {
            await txn.insert('movies', _updateImagePath(_convertToDbMapSafe(m, moviesCols), 'poster_path', imagePathMap));
          }
        }
        if (data.containsKey('books')) {
          for (final b in data['books'] as List) {
            await txn.insert('books', _updateImagePath(_convertToDbMapSafe(b, booksCols), 'cover_path', imagePathMap));
          }
        }
        if (data.containsKey('notes')) {
          for (final n in data['notes'] as List) {
            await txn.insert('notes', _updateNoteImagesPath(_convertToDbMapSafe(n, notesCols), imagePathMap));
          }
        }
        if (data.containsKey('movie_reviews')) {
          for (final r in data['movie_reviews'] as List) {
            await txn.insert('movie_reviews', _convertToDbMapSafe(r, movieReviewsCols));
          }
        }
        if (data.containsKey('movie_posters')) {
          for (final p in data['movie_posters'] as List) {
            await txn.insert('movie_posters', _updateImagePath(_convertToDbMapSafe(p, moviePostersCols), 'poster_path', imagePathMap));
          }
        }
        if (data.containsKey('book_reviews')) {
          for (final r in data['book_reviews'] as List) {
            await txn.insert('book_reviews', _convertToDbMapSafe(r, bookReviewsCols));
          }
        }
        if (data.containsKey('book_excerpts')) {
          for (final e in data['book_excerpts'] as List) {
            await txn.insert('book_excerpts', _convertToDbMapSafe(e, bookExcerptsCols));
          }
        }
        if (data.containsKey('tags')) {
          for (final t in data['tags'] as List) {
            final map = _convertToDbMapSafe(t, tagsCols);
            await txn.rawInsert(
              'INSERT OR IGNORE INTO tags (id, name, type, created_at) VALUES (?, ?, ?, ?)',
              [map['id'], map['name'], map['type'], map['created_at']],
            );
          }
        }
      });

      await _restoreUserInfo(backupData, imagePathMap);
      return ImportResult.success(_buildStats(data, imageCount));
    } catch (e) {
      return ImportResult.error('恢复失败: $e');
    }
  }

  // ─── 内部辅助方法 ─────────────────────────────────────

  Future<void> _restoreUserInfo(Map<String, dynamic> backupData, Map<String, String> imagePathMap) async {
    if (!backupData.containsKey('userInfo')) return;
    final userInfo = backupData['userInfo'] as Map<String, dynamic>;
    final userPrefs = UserPrefs();

    if (userInfo.containsKey('nickname')) await userPrefs.setNickname(userInfo['nickname'] as String);
    if (userInfo.containsKey('motto')) await userPrefs.setMotto(userInfo['motto'] as String);
    if (userInfo.containsKey('avatarPath')) {
      final avatarPath = userInfo['avatarPath'] as String?;
      if (avatarPath != null && avatarPath.isNotEmpty) {
        final relPath = _toRelativePath(avatarPath);
        if (imagePathMap.containsKey(relPath)) {
          await userPrefs.setAvatarPath(imagePathMap[relPath]!);
        }
      }
    }
  }

  Map<String, int> _buildStats(Map<String, dynamic> data, int imageCount) {
    final stats = <String, int>{};
    if (data.containsKey('movies')) stats['影视'] = (data['movies'] as List).length;
    if (data.containsKey('books')) stats['书籍'] = (data['books'] as List).length;
    if (data.containsKey('notes')) stats['笔记'] = (data['notes'] as List).length;
    if (data.containsKey('movie_reviews')) stats['影评'] = (data['movie_reviews'] as List).length;
    if (data.containsKey('movie_posters')) stats['海报'] = (data['movie_posters'] as List).length;
    if (data.containsKey('book_reviews')) stats['书评'] = (data['book_reviews'] as List).length;
    if (data.containsKey('book_excerpts')) stats['书摘'] = (data['book_excerpts'] as List).length;
    if (data.containsKey('tags')) stats['标签'] = (data['tags'] as List).length;
    if (imageCount > 0) stats['图片'] = imageCount;
    return stats;
  }

  /// 将绝对路径转为 images/ 下的相对路径（用于 imagePathMap key）
  String _toRelativePath(String absolutePath) {
    // 尝试提取 images/ 后面的部分
    final idx = absolutePath.indexOf('/images/');
    if (idx >= 0) return absolutePath.substring(idx + 8); // skip '/images/'
    // Windows 路径
    final winIdx = absolutePath.indexOf('\\images\\');
    if (winIdx >= 0) return absolutePath.substring(winIdx + 8);
    return path.basename(absolutePath);
  }

  Map<String, dynamic> _convertToDbMapSafe(dynamic item, Set<String> validColumns) {
    final raw = _convertToDbMap(item);
    if (raw.isEmpty) return raw;
    return Map.fromEntries(raw.entries.where((e) => validColumns.contains(e.key)));
  }

  Future<Set<String>> _getTableColumns(Database db, String table) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    return columns.map((c) => c['name'] as String).toSet();
  }

  Map<String, dynamic> _convertToDbMap(dynamic item) {
    if (item is Map<String, dynamic>) {
      return item.map((key, value) {
        if (value is bool) return MapEntry(key, value ? 1 : 0);
        return MapEntry(key, value);
      });
    }
    return {};
  }

  /// 更新单值图片路径（poster_path / cover_path）
  Map<String, dynamic> _updateImagePath(Map<String, dynamic> item, String pathField, Map<String, String> imagePathMap) {
    final newItem = Map<String, dynamic>.from(item);
    final oldPath = item[pathField] as String?;
    if (oldPath != null && oldPath.isNotEmpty) {
      final relPath = _toRelativePath(oldPath);
      if (imagePathMap.containsKey(relPath)) {
        newItem[pathField] = imagePathMap[relPath];
      }
    }
    return newItem;
  }

  /// 更新笔记多图路径（images JSON 列表）
  Map<String, dynamic> _updateNoteImagesPath(Map<String, dynamic> item, Map<String, String> imagePathMap) {
    final newItem = Map<String, dynamic>.from(item);
    final imagesJson = item['images'] as String?;
    if (imagesJson == null || imagesJson.isEmpty) return newItem;

    try {
      final images = jsonDecode(imagesJson) as List<dynamic>;
      final updatedImages = <String>[];
      for (final imagePath in images) {
        if (imagePath is String && imagePath.isNotEmpty) {
          final relPath = _toRelativePath(imagePath);
          updatedImages.add(imagePathMap[relPath] ?? imagePath);
        }
      }
      newItem['images'] = jsonEncode(updatedImages);
    } catch (e) {
      debugPrint('[BackupService] 笔记图片路径更新失败: $e');
    }
    return newItem;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}${_pad(dateTime.month)}${_pad(dateTime.day)}_${_pad(dateTime.hour)}${_pad(dateTime.minute)}${_pad(dateTime.second)}';
  }

  String _pad(int number) => number.toString().padLeft(2, '0');
}

/// 导出中间数据
class _ExportData {
  final Uint8List zipBytes;
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;

  _ExportData({
    required this.zipBytes,
    required this.movieCount,
    required this.bookCount,
    required this.noteCount,
    required this.imageCount,
  });
}

// ─── 结果类型 ──────────────────────────────────────────

class AutoBackupExportResult {
  final bool success;
  final String? errorMessage;
  final Uint8List? zipBytes;
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;

  AutoBackupExportResult._({
    required this.success,
    this.errorMessage,
    this.zipBytes,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
  });

  factory AutoBackupExportResult.success({
    required Uint8List zipBytes,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
  }) {
    return AutoBackupExportResult._(
      success: true, zipBytes: zipBytes,
      movieCount: movieCount, bookCount: bookCount,
      noteCount: noteCount, imageCount: imageCount,
    );
  }

  factory AutoBackupExportResult.error(String message) {
    return AutoBackupExportResult._(success: false, errorMessage: message);
  }
}

class ExportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final String? filePath;
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;

  ExportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.filePath,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
  });

  factory ExportResult.success({
    required String filePath,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
  }) {
    return ExportResult._(
      success: true, filePath: filePath,
      movieCount: movieCount, bookCount: bookCount,
      noteCount: noteCount, imageCount: imageCount,
    );
  }

  factory ExportResult.cancelled() {
    return ExportResult._(success: false, cancelled: true);
  }

  factory ExportResult.error(String message) {
    return ExportResult._(success: false, errorMessage: message);
  }
}

class ImportResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final Map<String, int>? stats;

  ImportResult._({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.stats,
  });

  factory ImportResult.success(Map<String, int> stats) {
    return ImportResult._(success: true, stats: stats);
  }

  factory ImportResult.cancelled() {
    return ImportResult._(success: false, cancelled: true);
  }

  factory ImportResult.error(String message) {
    return ImportResult._(success: false, errorMessage: message);
  }

  String get statsText {
    if (stats == null || stats!.isEmpty) return '没有导入任何数据';
    return stats!.entries.map((e) => '${e.key}: ${e.value}').join('，');
  }
}
