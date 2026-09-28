import 'dart:async';
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
import 'package:permission_handler/permission_handler.dart';
import '../../data/database_helper.dart';
import '../../l10n/app_strings.dart';
import '../../utils/user_prefs.dart';
import '../../utils/image_path_helper.dart';
import 'incremental/sync_meta_store.dart';

/// 数据备份服务 - 支持导出和导入数据（包含图片）
class BackupService {
  static final BackupService instance = BackupService._init();

  BackupService._init();

  /// 获取应用数据根目录（统一路径）
  Future<String> _getAppDir() async {
    return await ImagePathHelper.getAppDir();
  }

  /// 请求存储权限，返回是否已获取
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    status = await Permission.storage.status;
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 获取 Android Download 目录下的 mooknote 备份路径
  Future<String> _getDownloadBackupPath(String fileName) async {
    if (Platform.isAndroid) {
      final downloadDir = Directory('/sdcard/Download/mooknote');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return path.join(downloadDir.path, fileName);
    }
    // 非 Android 平台使用临时目录
    final tempDir = await getTemporaryDirectory();
    return path.join(tempDir.path, fileName);
  }

  // ─── 共享导出逻辑 ─────────────────────────────────────

  /// 导出互斥锁：手动导出 / 自动备份 / WebDAV 上传共用同一批固定临时文件，
  /// 并发执行会互踩，这里把导出阶段串行化
  Future<void> _exportLock = Future.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final prev = _exportLock;
    final completer = Completer<void>();
    _exportLock = completer.future;
    return prev.then((_) => action()).whenComplete(completer.complete);
  }

  /// 收集所有表数据和图片，构建 ZIP 文件
  Future<_ExportData> _buildExportData() => _serialized(_buildExportDataUnlocked);

  Future<_ExportData> _buildExportDataUnlocked() async {
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
    final games = await db.query('games');
    final gameReviews = await db.query('game_reviews');
    final gameScreenshots = await db.query('game_screenshots');
    final people = await db.query('people');
    final moviePeople = await db.query('movie_people');
    final bookPeople = await db.query('book_people');
    final gamePeople = await db.query('game_people');
    final playlists = await db.query('playlists');
    final playlistItems = await db.query('playlist_items');
    final movieCharacters = await db.query('movie_characters');
    final bookCharacters = await db.query('book_characters');
    final gameCharacters = await db.query('game_characters');
    final customModules = await db.query('custom_modules');
    final customModuleDesigns = await db.query('custom_module_designs');
    final customModuleItems = await db.query('custom_module_items');

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
    for (final g in games) {      final p = g['cover_path'] as String?;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
    }
    for (final s in gameScreenshots) {
      final p = s['screenshot_path'] as String?;
      if (p != null && p.isNotEmpty) imagePaths.add(p);
    }
    for (final p in people) {
      final pp = p['photo_path'] as String?;
      if (pp != null && pp.isNotEmpty) imagePaths.add(pp);
    }
    for (final c in [...movieCharacters, ...bookCharacters, ...gameCharacters]) {
      final ip = c['image_path'] as String?;
      if (ip != null && ip.isNotEmpty) imagePaths.add(ip);
    }
    // 自定义模块条目：cover_path + data_json 中的图片路径（海报字符串、多图列表）
    for (final it in customModuleItems) {
      final cp = it['cover_path'] as String?;
      if (cp != null && cp.isNotEmpty) imagePaths.add(cp);
      collectCustomModuleDataImagePaths(it['data_json'] as String?, imagePaths);
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
        'games': games,
        'game_reviews': gameReviews,
        'game_screenshots': gameScreenshots,
        'people': people,
        'movie_people': moviePeople,
        'book_people': bookPeople,
        'game_people': gamePeople,
        'playlists': playlists,
        'playlist_items': playlistItems,
        'movie_characters': movieCharacters,
        'book_characters': bookCharacters,
        'game_characters': gameCharacters,
        'custom_modules': customModules,
        'custom_module_designs': customModuleDesigns,
        'custom_module_items': customModuleItems,
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
    ));

    return _ExportData(
      zipPath: result.zipPath,
      movieCount: movies.length,
      bookCount: books.length,
      noteCount: notes.length,
      imageCount: result.imageCount,
    );
  }

  // ─── 手动导出 ─────────────────────────────────────────

  /// 导出所有数据和图片为 ZIP 文件，并选择保存路径
  Future<ExportResult> exportDataWithImages() async {
    try {
      // Android: 先检查存储权限，没有则请求
      if (Platform.isAndroid) {
        final hasPermission = await requestStoragePermission();
        if (!hasPermission) {
          return ExportResult.error('需要存储权限才能导出备份文件，请在设置中授予"所有文件访问权限"'.tr);
        }
      }

      final data = await _buildExportData();
      final zipFile = File(data.zipPath!);
      final fileName = 'mooknote_backup_${_formatDateTime(DateTime.now())}.zip';

      String? finalPath;
      try {
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存备份文件'.tr,
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
        // FilePicker 不可用时，复制到 /sdcard/Download/mooknote/
        final downloadPath = await _getDownloadBackupPath(fileName);
        await zipFile.copy(downloadPath);
        finalPath = downloadPath;
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
      return ExportResult.error('导出失败: {e}'.trf({'e': e}));
    }
  }

  /// 分享备份文件
  Future<void> shareBackup(String filePath) async {
    final file = XFile(filePath);
    await Share.shareXFiles([file], subject: 'MookNote 数据备份'.tr, text: '这是我的 MookNote 数据备份文件'.tr);
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
      );
    } catch (e) {
      return AutoBackupExportResult.error('导出失败: {e}'.trf({'e': e}));
    }
  }

  /// 执行本地自动备份：导出到 /sdcard/Download/mooknote/autoBackUp/，保留最新 maxKeep 个
  Future<AutoBackupExportResult> performLocalAutoBackup({int maxKeep = 5}) async {
    try {
      if (Platform.isAndroid) {
        final hasPermission = await requestStoragePermission();
        if (!hasPermission) {
          return AutoBackupExportResult.error('需要存储权限才能自动备份'.tr);
        }
      }

      final data = await _buildExportData();
      final zipFile = File(data.zipPath!);
      final fileName = 'mooknote_backup_${_formatDateTime(DateTime.now())}.zip';

      // 目标目录
      final backupDir = Directory('/sdcard/Download/mooknote/autoBackUp');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 复制到目标路径（同秒重名时追加序号，避免并发备份互相覆盖）
      var destPath = path.join(backupDir.path, fileName);
      var suffix = 1;
      while (await File(destPath).exists()) {
        destPath = path.join(
          backupDir.path,
          fileName.replaceFirst('.zip', '_${suffix++}.zip'),
        );
      }
      await zipFile.copy(destPath);

      // 清理原始临时 zip
      try { await zipFile.delete(); } catch (_) {}

      // 清理旧备份，保留最新 maxKeep 个
      await _cleanOldBackups(backupDir, maxKeep);

      // 记录备份时间
      final userPrefs = UserPrefs();
      await userPrefs.setLastLocalAutoBackupTime(DateTime.now().toIso8601String());

      return AutoBackupExportResult.success(
        zipPath: destPath,
        movieCount: data.movieCount,
        bookCount: data.bookCount,
        noteCount: data.noteCount,
        imageCount: data.imageCount,
      );
    } catch (e) {
      return AutoBackupExportResult.error('自动备份失败: {e}'.trf({'e': e}));
    }
  }

  /// 清理旧备份文件，只保留最新的 maxKeep 个
  Future<void> _cleanOldBackups(Directory backupDir, int maxKeep) async {
    final files = <File>[];
    await for (final entity in backupDir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        files.add(entity);
      }
    }
    if (files.length <= maxKeep) return;
    // 按修改时间排序，旧的在前
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    final toDelete = files.sublist(0, files.length - maxKeep);
    for (final f in toDelete) {
      try { await f.delete(); } catch (_) {}
    }
  }

  /// 获取本地自动备份目录下的备份文件列表（按时间倒序）
  Future<List<FileSystemEntity>> listLocalAutoBackups() async {
    final backupDir = Directory('/sdcard/Download/mooknote/autoBackUp');
    if (!await backupDir.exists()) return [];
    final files = <FileSystemEntity>[];
    await for (final entity in backupDir.list()) {
      if (entity is File && entity.path.endsWith('.zip')) {
        files.add(entity);
      }
    }
    files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
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
      if (filePath == null) return ImportResult.error('无法读取文件路径'.tr);

      final file = File(filePath);
      final extension = path.extension(filePath).toLowerCase();

      Map<String, dynamic> backupData;
      int imageCount = 0;
      // 完整相对路径 → 新绝对路径 的映射（避免同名文件碰撞）
      final imagePathMap = <String, String>{};

      if (extension == '.zip') {
        final unzipped = await _unzipBackup(filePath);
        if (unzipped == null) return ImportResult.error('备份文件中没有找到数据文件'.tr);
        backupData = unzipped.backupData;
        imageCount = unzipped.imageCount;
        imagePathMap.addAll(unzipped.imagePathMap);
        return await _restoreBackupData(
          backupData, imagePathMap, imageCount,
          stagingDirPath: unzipped.stagingDirPath,
        );
      } else {
        // 旧版 JSON
        backupData = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }

      return await _restoreBackupData(backupData, imagePathMap, imageCount);
    } catch (e) {
      return ImportResult.error('导入失败: {e}'.trf({'e': e}));
    }
  }

  /// 从 ZIP 文件恢复（流式解压，供 WebDAV 同步等场景使用）
  Future<ImportResult> restoreFromZipFile(String zipPath) async {
    try {
      final unzipped = await _unzipBackup(zipPath);
      if (unzipped == null) return ImportResult.error('备份文件中没有找到数据文件'.tr);
      // 恢复的行保留原时间戳（远早于 pushAfter），增量同步对账会把它们
      // 误判为"远程已删"而清掉。清空 pushAfter：既保护恢复数据，
      // 也让下次上传把它们全量推送到云端。
      return await _restoreBackupData(
        unzipped.backupData, unzipped.imagePathMap, unzipped.imageCount,
        clearPushAfter: true,
        stagingDirPath: unzipped.stagingDirPath,
      );
    } catch (e) {
      return ImportResult.error('恢复失败: {e}'.trf({'e': e}));
    }
  }

  /// 流式解压备份 zip：解析 data.json 并把图片逐个写盘，
  /// 任何时刻只持有单个条目的字节，避免大备份全量驻留内存。
  /// 返回 null 表示包内缺少 data.json。
  ///
  /// 图片先写入临时暂存目录而非正式目录：DB 事务成功后才搬入正式位置，
  /// 恢复失败时本地原有图片不被覆盖。imagePathMap 的值是最终正式路径。
  Future<_UnzipResult?> _unzipBackup(String zipPath) async {
    final input = InputFileStream(zipPath);
    String? stagingDirPath;
    try {
      final archive = ZipDecoder().decodeBuffer(input);
      final dataFile = archive.findFile('data.json');
      if (dataFile == null) return null;

      final backupData = jsonDecode(utf8.decode(dataFile.content as List<int>)) as Map<String, dynamic>;
      dataFile.clear(); // 释放 data.json 字节

      final imagePathMap = <String, String>{};
      var imageCount = 0;

      final appDirPath = await _getAppDir();
      final imagesDir = Directory(path.join(appDirPath, 'images'));

      final tempDir = await getTemporaryDirectory();
      stagingDirPath = path.join(
        tempDir.path,
        'mooknote_restore_${DateTime.now().microsecondsSinceEpoch}',
      );
      final stagingImagesDir = Directory(path.join(stagingDirPath, 'images'));
      await stagingImagesDir.create(recursive: true);

      try {
        for (final archiveFile in archive.files) {
          if (!archiveFile.isFile) continue;
          if (!archiveFile.name.startsWith('images/')) continue;
          var relativePath = archiveFile.name.substring('images/'.length);
          while (relativePath.startsWith('/') || relativePath.startsWith('\\')) {
            relativePath = relativePath.substring(1);
          }
          if (relativePath.isEmpty) continue;
          final stagedFile = File(path.join(stagingImagesDir.path, relativePath));
          if (!await stagedFile.parent.exists()) await stagedFile.parent.create(recursive: true);
          final out = OutputFileStream(stagedFile.path);
          try {
            archiveFile.writeContent(out); // 仅解压当前条目，写完即释放
          } finally {
            await out.close();
          }
          // 用完整相对路径做 key，避免不同目录下同名文件碰撞；value 为最终正式路径
          imagePathMap[relativePath] = path.join(imagesDir.path, relativePath);
          imageCount++;
        }
      } catch (_) {
        // 解压失败：清掉暂存目录，避免半成品残留
        try { await Directory(stagingDirPath).delete(recursive: true); } catch (_) {}
        rethrow;
      }
      return _UnzipResult(backupData, imagePathMap, imageCount, stagingDirPath);
    } finally {
      await input.close();
    }
  }

  /// DB 恢复成功后，把暂存图片搬入正式目录（覆盖同名文件）
  Future<void> _moveStagedImages(String stagingDirPath, Map<String, String> imagePathMap) async {
    final stagingImagesDir = Directory(path.join(stagingDirPath, 'images'));
    for (final entry in imagePathMap.entries) {
      final staged = File(path.join(stagingImagesDir.path, entry.key));
      if (!await staged.exists()) continue;
      final target = File(entry.value);
      if (!await target.parent.exists()) await target.parent.create(recursive: true);
      try {
        await staged.rename(target.path);
      } catch (_) {
        // 跨设备等 rename 失败场景退化为复制
        await staged.copy(target.path);
      }
    }
  }

  /// 共享的库表恢复逻辑：清表 → 单事务插回 → 恢复用户信息。
  /// [stagingDirPath] 为解压暂存目录：DB 事务成功后图片才搬入正式位置，
  /// 无论成败最后都会清理暂存目录。
  Future<ImportResult> _restoreBackupData(
    Map<String, dynamic> backupData,
    Map<String, String> imagePathMap,
    int imageCount, {
    bool clearPushAfter = false,
    String? stagingDirPath,
  }) async {
    try {
      return await _restoreBackupDataInner(
        backupData, imagePathMap, imageCount,
        clearPushAfter: clearPushAfter,
        stagingDirPath: stagingDirPath,
      );
    } finally {
      if (stagingDirPath != null) {
        try { await Directory(stagingDirPath).delete(recursive: true); } catch (_) {}
      }
    }
  }

  Future<ImportResult> _restoreBackupDataInner(
    Map<String, dynamic> backupData,
    Map<String, String> imagePathMap,
    int imageCount, {
    bool clearPushAfter = false,
    String? stagingDirPath,
  }) async {
    if (!backupData.containsKey('data')) return ImportResult.error('无效的备份文件格式'.tr);

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
    final gamesCols = await _getTableColumns(db, 'games');
    final gameReviewsCols = await _getTableColumns(db, 'game_reviews');
    final gameScreenshotsCols = await _getTableColumns(db, 'game_screenshots');
    final peopleCols = await _getTableColumns(db, 'people');
    final moviePeopleCols = await _getTableColumns(db, 'movie_people');
    final bookPeopleCols = await _getTableColumns(db, 'book_people');
    final gamePeopleCols = await _getTableColumns(db, 'game_people');
    final playlistsCols = await _getTableColumns(db, 'playlists');
    final playlistItemsCols = await _getTableColumns(db, 'playlist_items');
    final movieCharactersCols = await _getTableColumns(db, 'movie_characters');
    final bookCharactersCols = await _getTableColumns(db, 'book_characters');
    final gameCharactersCols = await _getTableColumns(db, 'game_characters');
    final customModulesCols = await _getTableColumns(db, 'custom_modules');
    final customModuleDesignsCols = await _getTableColumns(db, 'custom_module_designs');
    final customModuleItemsCols = await _getTableColumns(db, 'custom_module_items');

    await db.transaction((txn) async {
      await txn.delete('movie_reviews');
      await txn.delete('movie_posters');
      await txn.delete('book_reviews');
      await txn.delete('book_excerpts');
      await txn.delete('game_reviews');
      await txn.delete('game_screenshots');
      await txn.delete('movie_people');
      await txn.delete('book_people');
      await txn.delete('game_people');
      await txn.delete('people');
      await txn.delete('playlist_items');
      await txn.delete('playlists');
      await txn.delete('movie_characters');
      await txn.delete('book_characters');
      await txn.delete('game_characters');
      await txn.delete('custom_module_items');
      await txn.delete('custom_module_designs');
      await txn.delete('custom_modules');
      await txn.delete('movies');
      await txn.delete('books');
      await txn.delete('notes');
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
      if (data.containsKey('people')) {
        for (final p in data['people'] as List) {
          await txn.insert('people', _updateImagePath(_convertToDbMapSafe(p, peopleCols), 'photo_path', imagePathMap));
        }
      }
      if (data.containsKey('movie_people')) {
        for (final mp in data['movie_people'] as List) {
          await txn.insert('movie_people', _convertToDbMapSafe(mp, moviePeopleCols));
        }
      }
      if (data.containsKey('book_people')) {
        for (final bp in data['book_people'] as List) {
          await txn.insert('book_people', _convertToDbMapSafe(bp, bookPeopleCols));
        }
      }
      if (data.containsKey('game_people')) {
        for (final gp in data['game_people'] as List) {
          await txn.insert('game_people', _convertToDbMapSafe(gp, gamePeopleCols));
        }
      }
      if (data.containsKey('playlists')) {
        for (final pl in data['playlists'] as List) {
          await txn.insert('playlists', _updateImagePath(_convertToDbMapSafe(pl, playlistsCols), 'cover_path', imagePathMap));
        }
      }
      if (data.containsKey('playlist_items')) {
        for (final pi in data['playlist_items'] as List) {
          await txn.insert('playlist_items', _convertToDbMapSafe(pi, playlistItemsCols));
        }
      }
      if (data.containsKey('movie_characters')) {
        for (final c in data['movie_characters'] as List) {
          await txn.insert('movie_characters', _updateImagePath(_convertToDbMapSafe(c, movieCharactersCols), 'image_path', imagePathMap));
        }
      }
      if (data.containsKey('book_characters')) {
        for (final c in data['book_characters'] as List) {
          await txn.insert('book_characters', _updateImagePath(_convertToDbMapSafe(c, bookCharactersCols), 'image_path', imagePathMap));
        }
      }
      if (data.containsKey('game_characters')) {
        for (final c in data['game_characters'] as List) {
          await txn.insert('game_characters', _updateImagePath(_convertToDbMapSafe(c, gameCharactersCols), 'image_path', imagePathMap));
        }
      }
      if (data.containsKey('custom_modules')) {
        for (final m in data['custom_modules'] as List) {
          await txn.insert('custom_modules', _convertToDbMapSafe(m, customModulesCols));
        }
      }
      if (data.containsKey('custom_module_designs')) {
        for (final d in data['custom_module_designs'] as List) {
          await txn.insert('custom_module_designs', _convertToDbMapSafe(d, customModuleDesignsCols));
        }
      }
      if (data.containsKey('custom_module_items')) {
        for (final it in data['custom_module_items'] as List) {
          final map = _updateImagePath(_convertToDbMapSafe(it, customModuleItemsCols), 'cover_path', imagePathMap);
          await txn.insert('custom_module_items', _updateDataJsonImagePaths(map, imagePathMap));
        }
      }
    });

    if (clearPushAfter) {
      await SyncMetaStore.delete(SyncMetaStore.pushAfter);
    }

    // DB 事务已成功：暂存图片搬入正式目录
    if (stagingDirPath != null) {
      await _moveStagedImages(stagingDirPath, imagePathMap);
    }

    // 恢复用户信息
    await _restoreUserInfo(backupData, imagePathMap);
    return ImportResult.success(_buildStats(data, imageCount));
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
      // 敏感信息不随备份导出（备份文件会被用户分享）
      if (_sensitivePrefsKeys.contains(key)) continue;
      map[key] = prefs.get(key);
    }
    return map;
  }

  /// 含密码/令牌/设备身份的 prefs 键，导出与恢复两端都须排除
  static const Set<String> _sensitivePrefsKeys = {
    'webdav_config',
    'movieSearchToken',
    'bookSearchToken',
    'sync_client_id',
  };

  /// 恢复 SharedPreferences（保留当前设备的同步和路径配置）
  Future<void> _restoreSharedPrefs(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    // 这些键是设备特定或敏感的，不应从备份恢复
    const skipKeys = {
      'avatarPath',
      'webdav_config',
      'webdav_last_sync',
      'movieSearchToken',
      'bookSearchToken',
      'sync_client_id',
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
    if (data.containsKey('games')) stats['游戏'] = (data['games'] as List).length;
    if (data.containsKey('game_reviews')) stats['游戏评价'] = (data['game_reviews'] as List).length;
    if (data.containsKey('game_screenshots')) stats['游戏截图'] = (data['game_screenshots'] as List).length;
    if (data.containsKey('people')) stats['人物'] = (data['people'] as List).length;
    if (data.containsKey('playlists')) stats['片单'] = (data['playlists'] as List).length;
    int charCount = 0;
    for (final key in ['movie_characters', 'book_characters', 'game_characters']) {
      if (data.containsKey(key)) charCount += (data[key] as List).length;
    }
    if (charCount > 0) stats['角色'] = charCount;
    if (data.containsKey('custom_modules')) stats['自定义模块'] = (data['custom_modules'] as List).length;
    if (data.containsKey('custom_module_items')) stats['自定义条目'] = (data['custom_module_items'] as List).length;
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

  /// 更新自定义模块条目 data_json 内的图片路径（字符串值与字符串列表值）
  Map<String, dynamic> _updateDataJsonImagePaths(Map<String, dynamic> item, Map<String, String> imagePathMap) {
    final newItem = Map<String, dynamic>.from(item);
    final dj = item['data_json'] as String?;
    if (dj == null || dj.isEmpty) return newItem;

    String remap(String v) => imagePathMap[_toRelativePath(v)] ?? v;

    try {
      final map = jsonDecode(dj) as Map<String, dynamic>;
      final updated = Map<String, dynamic>.from(map);
      var changed = false;
      map.forEach((k, v) {
        if (v is String && v.replaceAll('\\', '/').contains('/images/')) {
          updated[k] = remap(v);
          changed = true;
        } else if (v is List) {
          updated[k] = [
            for (final e in v)
              e is String && e.replaceAll('\\', '/').contains('/images/') ? remap(e) : e,
          ];
          changed = true;
        }
      });
      if (changed) newItem['data_json'] = jsonEncode(updated);
    } catch (e) {
      debugPrint('[BackupService] 自定义模块 data_json 图片路径更新失败: $e');
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

  _ExportData({
    this.zipPath,
    required this.movieCount,
    required this.bookCount,
    required this.noteCount,
    required this.imageCount,
  });
}

/// 流式解压备份 zip 的中间结果
class _UnzipResult {
  final Map<String, dynamic> backupData;
  final Map<String, String> imagePathMap;
  final int imageCount;
  final String? stagingDirPath;

  _UnzipResult(this.backupData, this.imagePathMap, this.imageCount, [this.stagingDirPath]);
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

  AutoBackupExportResult._({
    required this.success,
    this.errorMessage,
    this.zipPath,
    this.movieCount = 0,
    this.bookCount = 0,
    this.noteCount = 0,
    this.imageCount = 0,
  });

  factory AutoBackupExportResult.success({
    required String zipPath,
    required int movieCount,
    required int bookCount,
    required int noteCount,
    required int imageCount,
  }) {
    return AutoBackupExportResult._(
      success: true, zipPath: zipPath,
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
    if (stats == null || stats!.isEmpty) return '没有导入任何数据'.tr;
    return stats!.entries.map((e) => '${e.key.tr}: ${e.value}').join(AppStrings.isEnglish ? ', ' : '，');
  }
}

// ─── compute isolate 参数和函数 ──────────────────────────

class _ZipComputeParams {
  final Map<String, dynamic> backupData;
  final List<String> imagePaths;
  final String tempDirPath;

  _ZipComputeParams({
    required this.backupData,
    required this.imagePaths,
    required this.tempDirPath,
  });
}

class _ZipComputeResult {
  final String? zipPath;
  final int imageCount;

  _ZipComputeResult({this.zipPath, required this.imageCount});
}

/// 在后台 isolate 中执行 JSON 编码 + ZIP 压缩，避免阻塞主线程
_ZipComputeResult _buildZipInIsolate(_ZipComputeParams params) {
  // 文件名带微秒时间戳：即使外层锁失效，并发 isolate 也不会操作同一文件
  final unique = DateTime.now().microsecondsSinceEpoch;
  final tempZipPath = path.join(params.tempDirPath, 'mooknote_backup_temp_$unique.zip');
  final encoder = ZipFileEncoder();
  encoder.create(tempZipPath);

  try {
    // data.json
    final jsonString = const JsonEncoder.withIndent('  ').convert(params.backupData);
    final jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
    final dataFile = File(path.join(params.tempDirPath, 'mooknote_data_$unique.json'));
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

    encoder.close();

    return _ZipComputeResult(zipPath: tempZipPath, imageCount: imageCount);
  } catch (e) {
    encoder.close();
    try { File(tempZipPath).deleteSync(); } catch (_) {}
    rethrow;
  }
}
