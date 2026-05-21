import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/data_models.dart';
import 'database_helper.dart';
import 'storage_helper.dart';

/// 数据迁移帮助类：将旧版文件系统数据迁移到 SQLite 数据库
class DataMigration {
  final StorageHelper _storage = StorageHelper.instance;
  final DatabaseHelper _db = DatabaseHelper.instance;

  static bool _hasMigrated = false;

  /// 执行数据迁移（幂等，只会执行一次）
  Future<void> migrateIfNeeded() async {
    if (_hasMigrated) return;
    _hasMigrated = true;

    try {
      await _migrateMovies();
      await _migrateBooks();
      await _migrateNotes();
      debugPrint('数据迁移完成');
    } catch (e, stack) {
      debugPrint('数据迁移失败: $e');
      debugPrint('堆栈: $stack');
    }
  }

  /// 迁移影视数据
  Future<void> _migrateMovies() async {
    final moviesDirPath = await _storage.moviesDir;
    final movieDirs = await _listSubdirNames(moviesDirPath);
    if (movieDirs.isEmpty) return;

    debugPrint('发现 ${movieDirs.length} 个影视目录，开始迁移...');
    final db = await _db.database;

    for (final dirName in movieDirs) {
      try {
        final dirPath = p.join(moviesDirPath, dirName);
        final dataPath = '$dirPath/data.json';
        final data = await _readJsonFile(dataPath);
        if (data == null) continue;

        final movie = Movie.fromJson(data);
        await db.insert(
          'movies',
          _movieToMap(movie),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 迁移影评
        await _migrateMovieReviews(dirPath, movie.id);
        // 迁移海报
        await _migrateMoviePosters(dirPath, movie.id);
      } catch (e) {
        debugPrint('迁移影视 $dirName 失败: $e');
      }
    }
  }

  /// 迁移影评
  Future<void> _migrateMovieReviews(String movieDirPath, String movieId) async {
    final reviewsDir = p.join(movieDirPath, 'reviews');
    if (!await Directory(reviewsDir).exists()) return;

    final files = await _listJsonFiles(reviewsDir);
    final db = await _db.database;

    for (final data in files) {
      try {
        final review = MovieReview.fromJson(data);
        await db.insert(
          'movie_reviews',
          _movieReviewToMap(review),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (e) {
        debugPrint('迁移影评失败: $e');
      }
    }
  }

  /// 迁移海报
  Future<void> _migrateMoviePosters(String movieDirPath, String movieId) async {
    final postersDir = p.join(movieDirPath, 'posters');
    if (!await Directory(postersDir).exists()) return;

    final files = await _listJsonFiles(postersDir);
    final db = await _db.database;

    for (final data in files) {
      try {
        final poster = MoviePoster.fromJson(data);
        await db.insert(
          'movie_posters',
          _moviePosterToMap(poster),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (e) {
        debugPrint('迁移海报失败: $e');
      }
    }
  }

  /// 迁移书籍数据
  Future<void> _migrateBooks() async {
    final booksDirPath = await _storage.booksDir;
    final bookDirs = await _listSubdirNames(booksDirPath);
    if (bookDirs.isEmpty) return;

    debugPrint('发现 ${bookDirs.length} 个书籍目录，开始迁移...');
    final db = await _db.database;

    for (final dirName in bookDirs) {
      try {
        final dirPath = p.join(booksDirPath, dirName);
        final dataPath = '$dirPath/data.json';
        final data = await _readJsonFile(dataPath);
        if (data == null) continue;

        final book = Book.fromJson(data);
        await db.insert(
          'books',
          _bookToMap(book),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // 迁移书评
        await _migrateBookReviews(dirPath, book.id);
        // 迁移摘抄
        await _migrateBookExcerpts(dirPath, book.id);
      } catch (e) {
        debugPrint('迁移书籍 $dirName 失败: $e');
      }
    }
  }

  /// 迁移书评
  Future<void> _migrateBookReviews(String bookDirPath, String bookId) async {
    final reviewsDir = p.join(bookDirPath, 'reviews');
    if (!await Directory(reviewsDir).exists()) return;

    final files = await _listJsonFiles(reviewsDir);
    final db = await _db.database;

    for (final data in files) {
      try {
        final review = BookReview.fromJson(data);
        await db.insert(
          'book_reviews',
          _bookReviewToMap(review),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (e) {
        debugPrint('迁移书评失败: $e');
      }
    }
  }

  /// 迁移摘抄
  Future<void> _migrateBookExcerpts(String bookDirPath, String bookId) async {
    final excerptsDir = p.join(bookDirPath, 'excerpts');
    if (!await Directory(excerptsDir).exists()) return;

    final files = await _listJsonFiles(excerptsDir);
    final db = await _db.database;

    for (final data in files) {
      try {
        final excerpt = BookExcerpt.fromJson(data);
        await db.insert(
          'book_excerpts',
          _bookExcerptToMap(excerpt),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (e) {
        debugPrint('迁移摘抄失败: $e');
      }
    }
  }

  /// 迁移笔记数据
  Future<void> _migrateNotes() async {
    final notesDirPath = await _storage.notesDir;
    final noteDirs = await _listSubdirNames(notesDirPath);
    if (noteDirs.isEmpty) return;

    debugPrint('发现 ${noteDirs.length} 个笔记目录，开始迁移...');
    final db = await _db.database;

    for (final dirName in noteDirs) {
      try {
        final dirPath = p.join(notesDirPath, dirName);
        final dataPath = '$dirPath/data.json';
        final data = await _readJsonFile(dataPath);
        if (data == null) continue;

        final note = Note.fromJson(data);
        await db.insert(
          'notes',
          _noteToMap(note),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } catch (e) {
        debugPrint('迁移笔记 $dirName 失败: $e');
      }
    }
  }

  // ========== 转换方法 ==========

  Map<String, dynamic> _movieToMap(Movie movie) {
    return {
      'id': movie.id,
      'title': movie.title,
      'poster_path': movie.posterPath,
      'release_date': movie.releaseDate?.toIso8601String(),
      'directors': jsonEncode(movie.directors),
      'writers': jsonEncode(movie.writers),
      'actors': jsonEncode(movie.actors),
      'genres': jsonEncode(movie.genres),
      'alternate_titles': jsonEncode(movie.alternateTitles),
      'summary': movie.summary,
      'rating': movie.rating,
      'status': movie.status,
      'watch_date': movie.watchDate?.toIso8601String(),
      'created_at': movie.createdAt.toIso8601String(),
      'updated_at': movie.updatedAt.toIso8601String(),
      'is_deleted': movie.isDeleted ? 1 : 0,
    };
  }

  Map<String, dynamic> _bookToMap(Book book) {
    return {
      'id': book.id,
      'title': book.title,
      'cover_path': book.coverPath,
      'authors': jsonEncode(book.authors),
      'alternate_titles': jsonEncode(book.alternateTitles),
      'publisher': book.publisher,
      'genres': jsonEncode(book.genres),
      'summary': book.summary,
      'rating': book.rating,
      'status': book.status,
      'isbn': book.isbn,
      'publish_date': book.publishDate?.toIso8601String(),
      'created_at': book.createdAt.toIso8601String(),
      'updated_at': book.updatedAt.toIso8601String(),
      'is_deleted': book.isDeleted ? 1 : 0,
    };
  }

  Map<String, dynamic> _noteToMap(Note note) {
    return {
      'id': note.id,
      'content': note.content,
      'content_type': note.contentType,
      'tags': jsonEncode(note.tags),
      'images': jsonEncode(note.images),
      'created_at': note.createdAt.toIso8601String(),
      'updated_at': note.updatedAt.toIso8601String(),
      'is_deleted': note.isDeleted ? 1 : 0,
    };
  }

  Map<String, dynamic> _movieReviewToMap(MovieReview review) {
    return {
      'id': review.id,
      'movie_id': review.movieId,
      'content': review.content,
      'reviewer': review.reviewer,
      'source': review.source,
      'review_type': review.reviewType,
      'is_deleted': review.isDeleted ? 1 : 0,
      'created_at': review.createdAt.toIso8601String(),
      'updated_at': review.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _moviePosterToMap(MoviePoster poster) {
    return {
      'id': poster.id,
      'movie_id': poster.movieId,
      'poster_path': poster.posterPath,
      'is_deleted': poster.isDeleted ? 1 : 0,
      'created_at': poster.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _bookReviewToMap(BookReview review) {
    return {
      'id': review.id,
      'book_id': review.bookId,
      'content': review.content,
      'reviewer': review.reviewer,
      'source': review.source,
      'review_type': review.reviewType,
      'is_deleted': review.isDeleted ? 1 : 0,
      'created_at': review.createdAt.toIso8601String(),
      'updated_at': review.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _bookExcerptToMap(BookExcerpt excerpt) {
    return {
      'id': excerpt.id,
      'book_id': excerpt.bookId,
      'chapter': excerpt.chapter,
      'content': excerpt.content,
      'comment': excerpt.comment,
      'is_deleted': excerpt.isDeleted ? 1 : 0,
      'created_at': excerpt.createdAt.toIso8601String(),
      'updated_at': excerpt.updatedAt.toIso8601String(),
    };
  }

  // ========== 辅助方法 ==========

  /// 列出子目录名
  Future<List<String>> _listSubdirNames(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];
      final entities = await dir.list().toList();
      return entities
          .whereType<Directory>()
          .map((e) => p.basename(e.path))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 读取 JSON 文件
  Future<Map<String, dynamic>?> _readJsonFile(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// 列出目录中的 JSON 文件并解析
  Future<List<Map<String, dynamic>>> _listJsonFiles(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) return [];

      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.json'))
          .toList();

      final results = <Map<String, dynamic>>[];
      for (final file in files) {
        final data = await _readJsonFile(file.path);
        if (data != null) results.add(data);
      }
      return results;
    } catch (e) {
      return [];
    }
  }
}
