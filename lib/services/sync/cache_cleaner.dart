import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../data/database_helper.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/user_prefs.dart';

/// 缓存清理服务
class CacheCleaner {
  CacheCleaner._();
  static final CacheCleaner instance = CacheCleaner._();

  /// 执行完整缓存清理，返回各分类删除数量
  Future<CacheCleanResult> clean() async {
    final dbImagePaths = await _getAllDbImagePaths();
    final deletedImages = await _cleanImageDirectory(dbImagePaths);
    final deletedEpubs = await _cleanOrphanedEpubBooks();
    final deletedTemp = await _cleanTempDirectory();
    final deletedEmptyDirs = await _cleanEmptyDirectories();
    return CacheCleanResult(
      images: deletedImages,
      epubs: deletedEpubs,
      temp: deletedTemp,
      emptyDirs: deletedEmptyDirs,
    );
  }

  /// 直接查 DB 收集所有图片路径（含软删除记录，与 BackupService 保持一致）
  Future<Set<String>> _getAllDbImagePaths() async {
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

    // 用户头像
    final userPrefs = UserPrefs();
    final avatarPath = userPrefs.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) paths.add(avatarPath);

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

  Future<int> _cleanOrphanedEpubBooks() async {
    int deletedCount = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('reader_books', columns: ['id', 'file_path', 'cover_path', 'is_deleted']);
      final usedDirs = <String>{};
      for (final r in rows) {
        final isDeleted = r['is_deleted'] == 1 || r['is_deleted'] == true;
        if (isDeleted) continue;
        final id = r['id'] as String?;
        if (id != null && id.isNotEmpty) usedDirs.add(id);
        _collectEpubDirName(r['file_path'] as String?, usedDirs);
        _collectEpubDirName(r['cover_path'] as String?, usedDirs);
      }

      final appDirPath = await ImagePathHelper.getAppDir();
      final possiblePaths = [
        path.join(appDirPath, 'epub_books'),
        // Android 旧版绝对路径（path.join 在 Windows 上不会破坏它）
        '/data/user/0/top.iletter.mooknote/app_flutter/epub_books',
      ];

      for (final epubPath in possiblePaths) {
        final epubDir = Directory(epubPath);
        if (!await epubDir.exists()) continue;
        await for (final entity in epubDir.list(followLinks: false)) {
          if (entity is Directory) {
            final dirName = path.basename(entity.path);
            if (!usedDirs.contains(dirName)) {
              try {
                await entity.delete(recursive: true);
                deletedCount++;
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('清理 epub_books 目录失败: $e');
    }
    return deletedCount;
  }

  /// 从路径中提取 epub_books/{bookId} 的 bookId 部分
  /// 兼容 Windows(\) 和 Unix(/) 分隔符
  void _collectEpubDirName(String? pathStr, Set<String> dirs) {
    if (pathStr == null || pathStr.isEmpty) return;
    // 统一为正斜杠便于查找 marker
    final unified = pathStr.replaceAll('\\', '/');
    final marker = '/epub_books/';
    final idx = unified.indexOf(marker);
    if (idx < 0) return;
    final rest = unified.substring(idx + marker.length);
    final slashIdx = rest.indexOf('/');
    dirs.add(slashIdx >= 0 ? rest.substring(0, slashIdx) : rest);
  }

  /// mooknote 自己产生的临时文件名前缀
  static const _tempPrefixes = [
    'book_poster_',
    'movie_poster_',
    'note_share_',
    'mooknote_download',
    'mooknote_bidir',
  ];

  bool _isMooknoteTempFile(String name) {
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
            if (_isMooknoteTempFile(name)) {
              try {
                final stat = await entity.stat();
                if (now.difference(stat.modified).inHours >= 1) {
                  await entity.delete();
                  deletedCount++;
                }
              } catch (_) {}
            }
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
            if (_isMooknoteTempFile(name)) {
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
        Directory(path.join(appDirPath, 'epub_books')),
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
  final int epubs;
  final int temp;
  final int emptyDirs;

  const CacheCleanResult({
    required this.images,
    required this.epubs,
    required this.temp,
    required this.emptyDirs,
  });

  int get total => images + epubs + temp + emptyDirs;

  String get description =>
      '已清理 $images 个孤立图片，$epubs 个孤立电子书，$temp 个临时文件，$emptyDirs 个空文件夹';
}
