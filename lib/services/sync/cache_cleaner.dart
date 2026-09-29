import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../data/database_helper.dart';
import '../../data/gallery/image_asset_dao.dart';
import '../../l10n/app_strings.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/user_prefs.dart';

/// 缓存清理服务
class CacheCleaner {
  CacheCleaner._();
  static final CacheCleaner instance = CacheCleaner._();

  /// 执行完整缓存清理，返回各分类删除数量
  Future<CacheCleanResult> clean() async {
    final dbImagePaths = await getAllDbImagePaths();
    final deletedImages = await _cleanImageDirectory(dbImagePaths);
    final deletedTemp = await _cleanTempDirectory();
    final deletedSystem = await _cleanSystemCache();
    final deletedEmptyDirs = await _cleanEmptyDirectories();
    // 顺带清理图片改名孤儿记录（图片已不存在时的残留）
    final validLogical = dbImagePaths.map(ImageAssetDao.toLogicalPath).toSet();
    await ImageAssetDao().deleteOrphans(validLogical);
    return CacheCleanResult(
      images: deletedImages,
      temp: deletedTemp,
      systemCache: deletedSystem,
      emptyDirs: deletedEmptyDirs,
    );
  }

  /// 扫描分析（只统计不删除），供清理页展示
  Future<CacheScanResult> analyze() async {
    final dbImagePaths = await getAllDbImagePaths();
    final normalizedDbPaths = dbImagePaths.map(_normalize).toSet();

    // 孤立图片
    int imageCount = 0, imageSize = 0;
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final imagesDir = Directory(path.join(appDirPath, 'images'));
      if (await imagesDir.exists()) {
        await for (final entity in imagesDir.list(recursive: true, followLinks: false)) {
          if (entity is File &&
              !normalizedDbPaths.contains(_normalize(entity.path)) &&
              !path.basename(entity.path).startsWith('avatar')) {
            try {
              imageSize += await entity.length();
              imageCount++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // 临时文件（与清理口径一致：仅 mooknote 前缀、tempDir 需超 1 小时）
    int tempCount = 0, tempSize = 0;
    final now = DateTime.now();
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is File && isMooknoteTempFile(path.basename(entity.path))) {
            try {
              final stat = await entity.stat();
              if (now.difference(stat.modified).inHours >= 1) {
                tempSize += await entity.length();
                tempCount++;
              }
            } catch (_) {}
          } else if (entity is Directory &&
              path.basename(entity.path).startsWith(_restoreStagingPrefix)) {
            try {
              final stat = await entity.stat();
              if (now.difference(stat.modified).inHours >= 1) {
                tempCount++;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File && isMooknoteTempFile(path.basename(entity.path))) {
            try {
              tempSize += await entity.length();
              tempCount++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // 空文件夹
    int emptyDirCount = 0;
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final cacheDir = await getApplicationCacheDirectory();
      for (final dir in [Directory(path.join(appDirPath, 'images')), cacheDir]) {
        if (!await dir.exists()) continue;
        emptyDirCount += await _countEmptyDirsRecursive(dir);
      }
    } catch (_) {}

    // 系统缓存（WebView / code_cache / cache 目录其余内容）
    final system = await _scanSystemCache();

    return CacheScanResult(
      images: imageCount,
      imagesSize: imageSize,
      temp: tempCount,
      tempSize: tempSize,
      systemCache: system.$1,
      systemCacheSize: system.$2,
      emptyDirs: emptyDirCount,
    );
  }

  /// 系统缓存目录：app_webview、code_cache、cache（cache 中排除 mooknote
  /// 前缀临时文件——那些归「临时文件」类，避免重复计数）
  Future<List<Directory>> _systemCacheDirs() async {
    final cacheDir = await getApplicationCacheDirectory();
    final appDataDir = cacheDir.parent;
    return [
      Directory(path.join(appDataDir.path, 'app_webview')),
      Directory(path.join(appDataDir.path, 'code_cache')),
      cacheDir,
    ];
  }

  /// 返回 (文件数, 总字节数)
  Future<(int, int)> _scanSystemCache() async {
    int count = 0, size = 0;
    try {
      for (final dir in await _systemCacheDirs()) {
        if (!await dir.exists()) continue;
        final isCacheRoot = path.basename(dir.path) == 'cache';
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          if (isCacheRoot && isMooknoteTempFile(path.basename(entity.path))) {
            continue; // 归「临时文件」类
          }
          try {
            size += await entity.length();
            count++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return (count, size);
  }

  /// 清空系统缓存目录内容（保留目录本身），返回删除的文件数
  Future<int> _cleanSystemCache() async {
    int deleted = 0;
    for (final dir in await _systemCacheDirs()) {
      if (!await dir.exists()) continue;
      final isCacheRoot = path.basename(dir.path) == 'cache';
      try {
        await for (final entity in dir.list(followLinks: false)) {
          if (isCacheRoot &&
              entity is File &&
              isMooknoteTempFile(path.basename(entity.path))) {
            continue; // 由临时文件清理负责
          }
          try {
            if (entity is File) {
              await entity.delete();
              deleted++;
            } else if (entity is Directory) {
              deleted += await _countFilesRecursive(entity);
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('清理系统缓存失败: $e');
      }
    }
    return deleted;
  }

  Future<int> _countFilesRecursive(Directory dir) async {
    int count = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          count++;
        } else if (entity is Directory) {
          count += await _countFilesRecursive(entity);
        }
      }
    } catch (_) {}
    return count;
  }

  Future<int> _countEmptyDirsRecursive(Directory dir) async {
    int count = 0;
    try {
      final children = await dir.list(followLinks: false).toList();
      for (final child in children) {
        if (child is Directory) {
          count += await _countEmptyDirsRecursive(child);
          final remaining = await child.list(followLinks: false).toList();
          if (remaining.isEmpty) count++;
        }
      }
    } catch (_) {}
    return count;
  }

  /// 直接查 DB 收集所有图片路径（含软删除记录，与 BackupService 保持一致）
  /// 设置页的缓存扫描也走这里，保证"扫描到的"和"实际清的"判定口径一致
  Future<Set<String>> getAllDbImagePaths() async {
    final db = await DatabaseHelper.instance.database;
    final paths = <String>{};

    // 影视海报
    final movies = await db.query('movies', columns: ['poster_path']);
    for (final m in movies) {
      final p = m['poster_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    // 书籍封面
    final books = await db.query('books', columns: ['cover_path']);
    for (final b in books) {
      final p = b['cover_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    // 笔记图片
    final notes = await db.query('notes', columns: ['images']);
    for (final n in notes) {
      final imagesJson = n['images'] as String?;
      if (imagesJson != null && imagesJson.isNotEmpty) {
        try {
          for (final ip in jsonDecode(imagesJson) as List<dynamic>) {
            if (ip is String && ip.isNotEmpty) paths.add(ip);
          }
        } catch (_) {}
      }
    }

    // 评价图片（影评/书评/游戏评价）
    for (final table in const ['movie_reviews', 'book_reviews', 'game_reviews']) {
      final rows = await db.query(table, columns: ['images']);
      for (final r in rows) {
        final imagesJson = r['images'] as String?;
        if (imagesJson != null && imagesJson.isNotEmpty) {
          try {
            for (final ip in jsonDecode(imagesJson) as List<dynamic>) {
              if (ip is String && ip.isNotEmpty) paths.add(ip);
            }
          } catch (_) {}
        }
      }
    }

    // 影视海报墙图片
    final moviePosters = await db.query('movie_posters', columns: ['poster_path']);
    for (final p in moviePosters) {
      final pp = p['poster_path'] as String?;
      if (pp != null && pp.isNotEmpty) paths.add(pp);
    }

    // 游戏封面
    final games = await db.query('games', columns: ['cover_path']);
    for (final g in games) {
      final p = g['cover_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    // 游戏截图
    final gameScreenshots = await db.query('game_screenshots', columns: ['screenshot_path']);
    for (final s in gameScreenshots) {
      final p = s['screenshot_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    // 人物照片
    final people = await db.query('people', columns: ['photo_path']);
    for (final p in people) {
      final pp = p['photo_path'] as String?;
      if (pp != null && pp.isNotEmpty) paths.add(pp);
    }

    // 角色图片（影视/书籍/游戏）
    for (final table in const ['movie_characters', 'book_characters', 'game_characters']) {
      final rows = await db.query(table, columns: ['image_path']);
      for (final r in rows) {
        final p = r['image_path'] as String?;
        if (p != null && p.isNotEmpty) paths.add(p);
      }
    }

    // 用户头像
    final userPrefs = UserPrefs();
    final avatarPath = userPrefs.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) paths.add(avatarPath);

    // 自定义模块条目：封面 + data_json 中的图片路径（海报字符串、多图列表）
    final customItems = await db.query('custom_module_items', columns: ['cover_path', 'data_json']);
    for (final c in customItems) {
      final p = c['cover_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
      collectCustomModuleDataImagePaths(c['data_json'] as String?, paths);
    }

    return paths;
  }

  /// 规范化路径用于跨平台比较（统一分隔符、去掉末尾分隔符）
  /// Windows 上 DB 存的路径和文件系统遍历得到的路径分隔符可能不一致，
  /// 直接字符串比较会漏匹配导致图片被误删。
  String _normalize(String p) {
    // 统一为正斜杠后再用 path.normalize 处理 .. 和 . 等
    final unified = p.replaceAll('\\', '/');
    return path.normalize(unified);
  }

  Future<int> _cleanImageDirectory(Set<String> dbImagePaths) async {
    int deletedCount = 0;
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final imagesDir = Directory(path.join(appDirPath, 'images'));
      if (!await imagesDir.exists()) return 0;
      // 预先规范化 DB 路径，避免每个文件都做转换
      final normalizedDbPaths = dbImagePaths.map(_normalize).toSet();
      await for (final entity in imagesDir.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            !normalizedDbPaths.contains(_normalize(entity.path)) &&
            !path.basename(entity.path).startsWith('avatar')) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('清理图片目录失败: $e');
    }
    return deletedCount;
  }

  /// mooknote 自己产生的临时文件名前缀
  static const _tempPrefixes = [
    'book_poster_',
    'movie_poster_',
    'note_share_',
    'mooknote_download',
    'mooknote_bidir',
    'mooknote_backup_temp_',
    'mooknote_data_',
  ];

  /// 恢复备份的图片暂存目录前缀（崩溃残留，正常流程 finally 会删）
  static const _restoreStagingPrefix = 'mooknote_restore_';

  /// 判断是否为 mooknote 自己产生的临时文件（设置页扫描也调用，避免口径漂移）
  static bool isMooknoteTempFile(String name) {
    for (final prefix in _tempPrefixes) {
      if (name.startsWith(prefix)) return true;
    }
    return false;
  }

  Future<int> _cleanTempDirectory() async {
    int deletedCount = 0;
    final now = DateTime.now();

    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is File) {
            final name = path.basename(entity.path);
            if (isMooknoteTempFile(name)) {
              try {
                final stat = await entity.stat();
                if (now.difference(stat.modified).inHours >= 1) {
                  await entity.delete();
                  deletedCount++;
                }
              } catch (_) {}
            }
          } else if (entity is Directory &&
              path.basename(entity.path).startsWith(_restoreStagingPrefix)) {
            // 恢复暂存目录崩溃残留，超过 1 小时未动则整体删除
            try {
              final stat = await entity.stat();
              if (now.difference(stat.modified).inHours >= 1) {
                await entity.delete(recursive: true);
                deletedCount++;
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('清理临时目录失败: $e');
    }

    // cacheDir 只删 mooknote 自己产生的临时文件，不再无差别全清
    // （Windows/Flutter 引擎也在该目录放缓存文件，全清可能误伤）
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final name = path.basename(entity.path);
            if (isMooknoteTempFile(name)) {
              try {
                await entity.delete();
                deletedCount++;
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('清理缓存目录失败: $e');
    }

    return deletedCount;
  }

  Future<int> _cleanEmptyDirectories() async {
    int deletedCount = 0;
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final cacheDir = await getApplicationCacheDirectory();
      final dirs = [
        Directory(path.join(appDirPath, 'images')),
        cacheDir,
      ];
      for (final dir in dirs) {
        if (!await dir.exists()) continue;
        deletedCount += await _removeEmptyDirsRecursive(dir);
      }
    } catch (e) {
      debugPrint('清理空文件夹失败: $e');
    }
    return deletedCount;
  }

  Future<int> _removeEmptyDirsRecursive(Directory dir) async {
    int count = 0;
    try {
      final children = await dir.list(followLinks: false).toList();
      for (final child in children) {
        if (child is Directory) {
          count += await _removeEmptyDirsRecursive(child);
          final remaining = await child.list(followLinks: false).toList();
          if (remaining.isEmpty) {
            try {
              await child.delete();
              count++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return count;
  }
}

class CacheCleanResult {
  final int images;
  final int temp;
  final int systemCache;
  final int emptyDirs;

  const CacheCleanResult({
    required this.images,
    required this.temp,
    required this.systemCache,
    required this.emptyDirs,
  });

  int get total => images + temp + systemCache + emptyDirs;

  String get description =>
      '已清理 {images} 个孤立图片，{temp} 个临时文件，{system} 个系统缓存，{emptyDirs} 个空文件夹'
          .trf({
        'images': images,
        'temp': temp,
        'system': systemCache,
        'emptyDirs': emptyDirs,
      });
}

/// 缓存扫描分析结果（只统计不删除）
class CacheScanResult {
  final int images;
  final int imagesSize;
  final int temp;
  final int tempSize;
  final int systemCache;
  final int systemCacheSize;
  final int emptyDirs;

  const CacheScanResult({
    required this.images,
    required this.imagesSize,
    required this.temp,
    required this.tempSize,
    required this.systemCache,
    required this.systemCacheSize,
    required this.emptyDirs,
  });

  int get total => images + temp + systemCache + emptyDirs;
  int get totalSize => imagesSize + tempSize + systemCacheSize;

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
