import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final readerBooks = await db.query('reader_books');
    final bookAnnotations = await db.query('book_annotations');
    final notePlus = await db.query('note_plus');

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
    // reader_books 的封面在 epub_books/ 目录下，由 epub_books 归档处理
    // 不加入 imagePaths，避免 basename 碰撞导致所有封面变成同一个路径

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
      'sharedPrefs': await _exportSharedPrefs(),
      'data': {
        'movies': movies,
        'books': books,
        'notes': notes,
        'movie_reviews': movieReviews,
        'movie_posters': moviePosters,
        'book_reviews': bookReviews,
        'book_excerpts': bookExcerpts,
        'tags': tags,
        'reader_books': readerBooks,
        'book_annotations': bookAnnotations,
        'note_plus': notePlus,
      },
    };

    // 创建 ZIP（逐文件写入磁盘，避免全部加载到内存）
    final tempDir = await getTemporaryDirectory();
    final tempZipPath = path.join(tempDir.path, 'mooknote_backup_temp.zip');
    final encoder = ZipFileEncoder();
    encoder.create(tempZipPath);

    try {
      // data.json
      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      final dataFile = File(path.join(tempDir.path, 'mooknote_data.json'));
      await dataFile.writeAsBytes(jsonBytes);
      encoder.addFile(dataFile, 'data.json');
      await dataFile.delete();

      int imageCount = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final imagesRoot = path.join(appDir.path, 'images');

      for (final imagePath in imagePaths) {
        final file = File(imagePath);
        if (await file.exists()) {
          String relativePath;
          if (imagePath.startsWith(imagesRoot)) {
            relativePath = imagePath.substring(imagesRoot.length + 1);
          } else {
            relativePath = path.basename(imagePath);
          }
          encoder.addFile(file, 'images/$relativePath');
          imageCount++;
        }
      }

      // 收集 epub_books 目录下的 epub 文件
      int epubCount = 0;
      final epubRoot = path.join(appDir.path, 'epub_books');
      final epubDir = Directory(epubRoot);
      if (await epubDir.exists()) {
        await for (final entity in epubDir.list(recursive: true)) {
          if (entity is File) {
            final relativePath = entity.path.substring(epubRoot.length + 1);
            encoder.addFile(entity, 'epub_books/$relativePath');
            epubCount++;
          }
        }
      }

      encoder.close();

      // 读取最终 zip 文件
      final zipFile = File(tempZipPath);
      final zipBytes = await zipFile.readAsBytes();
      await zipFile.delete();

      return _ExportData(
        zipBytes: Uint8List.fromList(zipBytes),
        movieCount: movies.length,
        bookCount: books.length,
        noteCount: notes.length,
        imageCount: imageCount,
        epubCount: epubCount,
      );
    } catch (e) {
      encoder.close();
      try { await File(tempZipPath).delete(); } catch (_) {}
      rethrow;
    }
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
        epubCount: data.epubCount,
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
      // epub_books/ 内相对路径 → 新绝对路径 的映射
      final epubFileMap = <String, String>{};

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
          } else if (archiveFile.name.startsWith('epub_books/')) {
            final relativePath = archiveFile.name.substring(12);
            final epubDir = Directory(path.join(appDir.path, 'epub_books'));
            if (!await epubDir.exists()) await epubDir.create(recursive: true);
            final outputFile = File(path.join(epubDir.path, relativePath));
            if (!await outputFile.parent.exists()) await outputFile.parent.create(recursive: true);
            await outputFile.writeAsBytes(archiveFile.content as List<int>);
            epubFileMap[relativePath] = outputFile.path;
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
      final readerBooksCols = await _getTableColumns(db, 'reader_books');
      final bookAnnotationsCols = await _getTableColumns(db, 'book_annotations');
      final notePlusCols = await _getTableColumns(db, 'note_plus');

      await db.transaction((txn) async {
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('book_reviews');
        await txn.delete('book_excerpts');
        await txn.delete('book_annotations');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        await txn.delete('reader_books');
        await txn.delete('note_plus');
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
        if (data.containsKey('reader_books')) {
          for (final rb in data['reader_books'] as List) {
            var row = _updateImagePath(_convertToDbMapSafe(rb, readerBooksCols), 'cover_path', imagePathMap);
            row = _updateEpubPaths(row, epubFileMap);
            await txn.insert('reader_books', row);
          }
        }
        if (data.containsKey('book_annotations')) {
          for (final a in data['book_annotations'] as List) {
            await txn.insert('book_annotations', _convertToDbMapSafe(a, bookAnnotationsCols));
          }
        }
        if (data.containsKey('note_plus')) {
          for (final np in data['note_plus'] as List) {
            await txn.insert('note_plus', _convertToDbMapSafe(np, notePlusCols));
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
      final epubFileMap = <String, String>{};
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
        } else if (archiveFile.name.startsWith('epub_books/')) {
          final relativePath = archiveFile.name.substring(12);
          final epubDir = Directory(path.join(appDir.path, 'epub_books'));
          if (!await epubDir.exists()) await epubDir.create(recursive: true);
          final outputFile = File(path.join(epubDir.path, relativePath));
          if (!await outputFile.parent.exists()) await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(archiveFile.content as List<int>);
          epubFileMap[relativePath] = outputFile.path;
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
      final readerBooksCols = await _getTableColumns(db, 'reader_books');
      final bookAnnotationsCols = await _getTableColumns(db, 'book_annotations');
      final notePlusCols = await _getTableColumns(db, 'note_plus');

      await db.transaction((txn) async {
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('book_reviews');
        await txn.delete('book_excerpts');
        await txn.delete('book_annotations');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        await txn.delete('reader_books');
        await txn.delete('note_plus');
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
        if (data.containsKey('reader_books')) {
          for (final rb in data['reader_books'] as List) {
            var row = _updateImagePath(_convertToDbMapSafe(rb, readerBooksCols), 'cover_path', imagePathMap);
            row = _updateEpubPaths(row, epubFileMap);
            await txn.insert('reader_books', row);
          }
        }
        if (data.containsKey('book_annotations')) {
          for (final a in data['book_annotations'] as List) {
            await txn.insert('book_annotations', _convertToDbMapSafe(a, bookAnnotationsCols));
          }
        }
        if (data.containsKey('note_plus')) {
          for (final np in data['note_plus'] as List) {
            await txn.insert('note_plus', _convertToDbMapSafe(np, notePlusCols));
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

    // 恢复完整 SharedPreferences
    if (backupData.containsKey('sharedPrefs')) {
      await _restoreSharedPrefs(backupData['sharedPrefs'] as Map<String, dynamic>);
    }
  }

  /// 导出完整 SharedPreferences
  Future<Map<String, dynamic>> _exportSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final map = <String, dynamic>{};
    for (final key in keys) {
      map[key] = prefs.get(key);
    }
    return map;
  }

  /// 恢复 SharedPreferences（保留当前设备的同步和路径配置）
  Future<void> _restoreSharedPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    // 这些键是设备特定的，不应从备份恢复
    const skipKeys = {
      'avatarPath',
      'webdav_config',
      'webdav_last_sync',
      'webdav_auto_sync',
      'webdav_auto_sync_interval',
    };
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (skipKeys.contains(key)) continue;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.cast<String>());
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
    if (data.containsKey('reader_books')) stats['阅读'] = (data['reader_books'] as List).length;
    if (data.containsKey('book_annotations')) stats['批注'] = (data['book_annotations'] as List).length;
    if (data.containsKey('note_plus')) stats['高级笔记'] = (data['note_plus'] as List).length;
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

  /// 更新 epub 阅读器的 file_path 和 cover_path
  Map<String, dynamic> _updateEpubPaths(Map<String, dynamic> item, Map<String, String> epubFileMap) {
    if (epubFileMap.isEmpty) return item;
    final newItem = Map<String, dynamic>.from(item);

    final oldFilePath = item['file_path'] as String?;
    if (oldFilePath != null && oldFilePath.isNotEmpty) {
      final oldRel = _toEpubRelativePath(oldFilePath);
      if (oldRel != null && epubFileMap.containsKey(oldRel)) {
        newItem['file_path'] = epubFileMap[oldRel];
      }
    }

    final oldCoverPath = item['cover_path'] as String?;
    if (oldCoverPath != null && oldCoverPath.isNotEmpty) {
      final oldRel = _toEpubRelativePath(oldCoverPath);
      if (oldRel != null && epubFileMap.containsKey(oldRel)) {
        newItem['cover_path'] = epubFileMap[oldRel];
      }
    }

    return newItem;
  }

  /// 从绝对路径中提取 epub_books/ 下的相对路径
  String? _toEpubRelativePath(String absolutePath) {
    final idx = absolutePath.indexOf('/epub_books/');
    if (idx >= 0) return absolutePath.substring(idx + 13); // skip '/epub_books/'
    final winIdx = absolutePath.indexOf('\\epub_books\\');
    if (winIdx >= 0) return absolutePath.substring(winIdx + 13);
    return null;
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
  final int epubCount;

  _ExportData({
    required this.zipBytes,
    required this.movieCount,
    required this.bookCount,
    required this.noteCount,
    required this.imageCount,
    this.epubCount = 0,
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
  final int epubCount;

  AutoBackupExportResult._({
    required this.success,
    this.errorMessage,
    this.zipBytes,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
    this.epubCount = 0,
  });

  factory AutoBackupExportResult.success({
    required Uint8List zipBytes,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
    int epubCount = 0,
  }) {
    return AutoBackupExportResult._(
      success: true, zipBytes: zipBytes,
      movieCount: movieCount, bookCount: bookCount,
      noteCount: noteCount, imageCount: imageCount,
      epubCount: epubCount,
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
