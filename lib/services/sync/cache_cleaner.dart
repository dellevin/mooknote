import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../providers/app_provider.dart';
import '../../data/database_helper.dart';

/// 缓存清理服务
class CacheCleaner {
  CacheCleaner._();
  static final CacheCleaner instance = CacheCleaner._();

  /// 执行完整缓存清理，返回各分类删除数量
  Future<CacheCleanResult> clean(AppProvider provider) async {
    final dbImagePaths = await _getAllDbImagePaths(provider);
    final deletedImages = await _cleanImageDirectory(dbImagePaths);
    final deletedEpubs = await _cleanOrphanedEpubBooks(provider);
    final deletedTemp = await _cleanTempDirectory();
    final deletedEmptyDirs = await _cleanEmptyDirectories();
    return CacheCleanResult(
      images: deletedImages,
      epubs: deletedEpubs,
      temp: deletedTemp,
      emptyDirs: deletedEmptyDirs,
    );
  }

  Future<Set<String>> _getAllDbImagePaths(AppProvider provider) async {
    final paths = <String>{};
    for (final movie in provider.movies) {
      if (movie.posterPath?.isNotEmpty == true) paths.add(movie.posterPath!);
    }
    for (final book in provider.books) {
      if (book.coverPath?.isNotEmpty == true) paths.add(book.coverPath!);
    }
    for (final note in provider.notes) {
      for (final p in note.images) {
        if (p.isNotEmpty) paths.add(p);
      }
    }
    for (final movieId in provider.movies.map((m) => m.id)) {
      for (final poster in await provider.getMoviePosters(movieId)) {
        if (poster.posterPath.isNotEmpty) paths.add(poster.posterPath);
      }
    }
    for (final game in provider.games) {
      if (game.coverPath?.isNotEmpty == true) paths.add(game.coverPath!);
    }
    for (final gameId in provider.games.map((g) => g.id)) {
      for (final screenshot in await provider.getGameScreenshots(gameId)) {
        if (screenshot.screenshotPath.isNotEmpty) paths.add(screenshot.screenshotPath);
      }
    }
    return paths;
  }

  Future<int> _cleanImageDirectory(Set<String> dbImagePaths) async {
    int deletedCount = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) return 0;
      await for (final entity in imagesDir.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            !dbImagePaths.contains(entity.path) &&
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

  Future<int> _cleanOrphanedEpubBooks(AppProvider provider) async {
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

      final appDir = await getApplicationDocumentsDirectory();
      final possiblePaths = [
        '${appDir.path}/epub_books',
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

  void _collectEpubDirName(String? pathStr, Set<String> dirs) {
    if (pathStr == null || pathStr.isEmpty) return;
    final marker = '/epub_books/';
    final idx = pathStr.indexOf(marker);
    if (idx < 0) return;
    final rest = pathStr.substring(idx + marker.length);
    final slashIdx = rest.indexOf('/');
    dirs.add(slashIdx >= 0 ? rest.substring(0, slashIdx) : rest);
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
            if (name.startsWith('book_poster_') ||
                name.startsWith('movie_poster_') ||
                name.startsWith('note_share_') ||
                name.startsWith('mooknote_download') ||
                name.startsWith('mooknote_bidir')) {
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

    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (_) {}
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
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getApplicationCacheDirectory();
      final dirs = [
        Directory('${appDir.path}/images'),
        Directory('${appDir.path}/epub_books'),
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
