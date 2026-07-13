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
import '../../data/database_helper.dart';
import '../../utils/user_prefs.dart';
import '../../utils/image_path_helper.dart';

/// 数据备份服务 - 支持导出和导入数据（包含图片）
class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  /// 获取应用数据根目录（统一路径）
  Future<String> _getAppDir() async {
    return await ImagePathHelper.getAppDir();
  }

  // ─── 共享导出逻辑 ─────────────────────────────────────

  /// 收集所有表数据和图片，构建 ZIP 文件
  Future<_ExportData> _buildExportData() async {
    // 阶段1：主线程收集数据（DB 查询、SharedPreferences 需主线程）
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
    final games = await db.query('games');
    final gameReviews = await db.query('game_reviews');
    final gameScreenshots = await db.query('game_screenshots');

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

    for (final g in games) {
      final p = g['cover_path'] as String?;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
    }
    for (final s in gameScreenshots) {
      final p = s['screenshot_path'] as String?;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
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
        'games': games,
        'game_reviews': gameReviews,
        'game_screenshots': gameScreenshots,
      },
    };

    // 阶段2：后台 isolate 执行 JSON 编码 + ZIP 压缩（避免阻塞主线程动画）
    final tempDir = await getTemporaryDirectory();
    final appDirPath = await _getAppDir();

    // DEBUG: 诊断 Windows 导出图片缺失问题
    final imagesRootPath = path.join(appDirPath, 'images');
    debugPrint('[BackupService] DEBUG appDirPath=$appDirPath');
    debugPrint('[BackupService] DEBUG imagesRoot=$imagesRootPath');
    debugPrint('[BackupService] DEBUG imagePaths count=${imagePaths.length}');
    for (final ip in imagePaths) {
      final f = File(ip);
      final exists = f.existsSync();
      final match = ip.startsWith(imagesRootPath);
      debugPrint('[BackupService] DEBUG path=$ip exists=$exists startsWithImagesRoot=$match');
    }

    final result = await compute(_buildZipInIsolate, _ZipComputeParams(
      backupData: backupData,
      imagePaths: imagePaths.toList(),
      tempDirPath: tempDir.path,
      appDirPath: appDirPath,
    ));

    return _ExportData(
      zipPath: result.zipPath,
      movieCount: movies.length,
      bookCount: books.length,
      noteCount: notes.length,
      imageCount: result.imageCount,
      epubCount: result.epubCount,
    );
  }

  // ─── 手动导出 ─────────────────────────────────────────

  /// 导出所有数据和图片为 ZIP 文件，并选择保存路径
  Future<ExportResult> exportDataWithImages() async {
    try {
      final data = await _buildExportData();
      final zipFile = File(data.zipPath!);
      final tempDir = await getTemporaryDirectory();
      final fileName = 'mooknote_backup_${_formatDateTime(DateTime.now())}.zip';
      final tempFilePath = path.join(tempDir.path, fileName);

      String? finalPath;
      try {
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存备份文件',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
        if (outputPath == null) {
          await zipFile.delete();
          return ExportResult.cancelled();
        }
        await zipFile.copy(outputPath);
        finalPath = outputPath;
      } catch (e) {
        // FilePicker 不可用时，复制到临时目录
        await zipFile.copy(tempFilePath);
        finalPath = tempFilePath;
      }

      // 清理原始临时 zip
      try { await zipFile.delete(); } catch (_) {}

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

  /// 导出数据用于自动备份（返回临时 zip 文件路径，调用方负责删除）
  Future<AutoBackupExportResult> exportDataForAutoBackup() async {
    try {
      final data = await _buildExportData();
      return AutoBackupExportResult.success(
        zipPath: data.zipPath!,
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

        final appDirPath = await _getAppDir();
        final imagesDir = Directory(path.join(appDirPath, 'images'));
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
            final epubDir = Directory(path.join(appDirPath, 'epub_books'));
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
      final gamesCols = await _getTableColumns(db, 'games');
      final gameReviewsCols = await _getTableColumns(db, 'game_reviews');
      final gameScreenshotsCols = await _getTableColumns(db, 'game_screenshots');

      await db.transaction((txn) async {
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('book_reviews');
        await txn.delete('book_excerpts');
        await txn.delete('book_annotations');
        await txn.delete('game_reviews');
        await txn.delete('game_screenshots');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        await txn.delete('reader_books');
        await txn.delete('games');
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
        if (data.containsKey('games')) {
          for (final g in data['games'] as List) {
            await txn.insert('games', _updateImagePath(_convertToDbMapSafe(g, gamesCols), 'cover_path', imagePathMap));
          }
        }
        if (data.containsKey('game_reviews')) {
          for (final r in data['game_reviews'] as List) {
            await txn.insert('game_reviews', _convertToDbMapSafe(r, gameReviewsCols));
          }
        }
        if (data.containsKey('game_screenshots')) {
          for (final s in data['game_screenshots'] as List) {
            await txn.insert('game_screenshots', _updateImagePath(_convertToDbMapSafe(s, gameScreenshotsCols), 'screenshot_path', imagePathMap));
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

      final appDirPath = await _getAppDir();
      final imagesDir = Directory(path.join(appDirPath, 'images'));
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
          final epubDir = Directory(path.join(appDirPath, 'epub_books'));
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
      final gamesCols = await _getTableColumns(db, 'games');
      final gameReviewsCols = await _getTableColumns(db, 'game_reviews');
      final gameScreenshotsCols = await _getTableColumns(db, 'game_screenshots');

      await db.transaction((txn) async {
        await txn.delete('movie_reviews');
        await txn.delete('movie_posters');
        await txn.delete('book_reviews');
        await txn.delete('book_excerpts');
        await txn.delete('book_annotations');
        await txn.delete('game_reviews');
        await txn.delete('game_screenshots');
        await txn.delete('movies');
        await txn.delete('books');
        await txn.delete('notes');
        await txn.delete('reader_books');
        await txn.delete('games');
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
        if (data.containsKey('games')) {
          for (final g in data['games'] as List) {
            await txn.insert('games', _updateImagePath(_convertToDbMapSafe(g, gamesCols), 'cover_path', imagePathMap));
          }
        }
        if (data.containsKey('game_reviews')) {
          for (final r in data['game_reviews'] as List) {
            await txn.insert('game_reviews', _convertToDbMapSafe(r, gameReviewsCols));
          }
        }
        if (data.containsKey('game_screenshots')) {
          for (final s in data['game_screenshots'] as List) {
            await txn.insert('game_screenshots', _updateImagePath(_convertToDbMapSafe(s, gameScreenshotsCols), 'screenshot_path', imagePathMap));
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
    if (data.containsKey('games')) stats['游戏'] = (data['games'] as List).length;
    if (data.containsKey('game_reviews')) stats['游戏评价'] = (data['game_reviews'] as List).length;
    if (data.containsKey('game_screenshots')) stats['游戏截图'] = (data['game_screenshots'] as List).length;
    if (imageCount > 0) stats['图片'] = imageCount;
    return stats;
  }

  /// 将绝对路径转为 images/ 下的相对路径（用于 imagePathMap key）
  String _toRelativePath(String absolutePath) {
    // 统一为正斜杠，避免 Windows 反斜杠与 zip 内正斜杠不匹配
    final normalized = absolutePath.replaceAll('\\', '/');
    // 尝试提取 images/ 后面的部分
    final idx = normalized.indexOf('/images/');
    if (idx >= 0) return normalized.substring(idx + 8); // skip '/images/'
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
    final normalized = absolutePath.replaceAll('\\', '/');
    final idx = normalized.indexOf('/epub_books/');
    if (idx >= 0) return normalized.substring(idx + 13); // skip '/epub_books/'
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
  final String? zipPath; // 临时 zip 文件路径，调用方负责删除
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;
  final int epubCount;

  _ExportData({
    this.zipPath,
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
  final String? zipPath; // 临时 zip 文件路径，调用方负责删除
  final int movieCount;
  final int bookCount;
  final int noteCount;
  final int imageCount;
  final int epubCount;

  AutoBackupExportResult._({
    required this.success,
    this.errorMessage,
    this.zipPath,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
    this.epubCount = 0,
  });

  factory AutoBackupExportResult.success({
    required String zipPath,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
    int epubCount = 0,
  }) {
    return AutoBackupExportResult._(
      success: true, zipPath: zipPath,
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

// ─── compute isolate 参数和函数 ──────────────────────────

class _ZipComputeParams {
  final Map<String, dynamic> backupData;
  final List<String> imagePaths;
  final String tempDirPath;
  final String appDirPath;

  _ZipComputeParams({
    required this.backupData,
    required this.imagePaths,
    required this.tempDirPath,
    required this.appDirPath,
  });
}

class _ZipComputeResult {
  final String? zipPath;
  final int imageCount;
  final int epubCount;

  _ZipComputeResult({this.zipPath, required this.imageCount, required this.epubCount});
}

/// 在后台 isolate 中执行 JSON 编码 + ZIP 压缩，避免阻塞主线程
_ZipComputeResult _buildZipInIsolate(_ZipComputeParams params) {
  final tempZipPath = path.join(params.tempDirPath, 'mooknote_backup_temp.zip');
  final encoder = ZipFileEncoder();
  encoder.create(tempZipPath);

  try {
    // data.json
    final jsonString = const JsonEncoder.withIndent('  ').convert(params.backupData);
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
    final dataFile = File(path.join(params.tempDirPath, 'mooknote_data.json'));
    dataFile.writeAsBytesSync(jsonBytes);
    encoder.addFile(dataFile, 'data.json');
    dataFile.deleteSync();

    int imageCount = 0;

    for (final imagePath in params.imagePaths) {
      final file = File(imagePath);
      if (file.existsSync()) {
        // 统一用 /images/ 子串匹配提取相对路径，兼容旧路径（路径前缀可能不含 mooknote 子目录）
        final normalized = imagePath.replaceAll('\\', '/');
        final idx = normalized.indexOf('/images/');
        String relativePath;
        if (idx >= 0) {
          relativePath = normalized.substring(idx + 8); // skip '/images/'
        } else {
          relativePath = path.basename(imagePath);
        }
        encoder.addFile(file, 'images/$relativePath');
        imageCount++;
      }
    }

    // 收集 epub_books 目录下的 epub 文件
    int epubCount = 0;
    final epubRoot = path.join(params.appDirPath, 'epub_books');
    final epubDir = Directory(epubRoot);
    if (epubDir.existsSync()) {
      for (final entity in epubDir.listSync(recursive: true)) {
        if (entity is File) {
          final relativePath = entity.path.substring(epubRoot.length + 1);
          encoder.addFile(entity, 'epub_books/$relativePath');
          epubCount++;
        }
      }
    }

    encoder.close();

    return _ZipComputeResult(zipPath: tempZipPath, imageCount: imageCount, epubCount: epubCount);
  } catch (e) {
    encoder.close();
    try { File(tempZipPath).deleteSync(); } catch (_) {}
    rethrow;
  }
}
