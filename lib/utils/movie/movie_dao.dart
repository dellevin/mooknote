import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 影视数据访问对象
class MovieDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[MovieDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有影视记录（未删除的）
  Future<List<Movie>> getAllMovies() => _wrap('getAllMovies', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  });

  // 分页查询影视记录
  Future<List<Movie>> getMoviesPaged({String? status, int limit = 20, int offset = 0}) => _wrap('getMoviesPaged', () async {
    final db = await _dbHelper.database;
    String where = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    if (status != null && status.isNotEmpty) {
      where += ' AND status = ?';
      whereArgs.add(status);
    }
    final maps = await db.query('movies', where: where, whereArgs: whereArgs,
        orderBy: 'created_at DESC', limit: limit, offset: offset);
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  });

  // 根据状态筛选影视记录
  Future<List<Movie>> getMoviesByStatus(String status) => _wrap('getMoviesByStatus', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'status = ? AND is_deleted = ?',
      whereArgs: [status, 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  });

  // 根据导演筛选
  Future<List<Movie>> getMoviesByDirector(String director) => _wrap('getMoviesByDirector', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'directors LIKE ? AND is_deleted = ?',
      whereArgs: ['%$director%', 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Movie.fromJson(m))
        .where((movie) => movie.directors.contains(director))
        .toList();
  });

  // 根据编剧筛选
  Future<List<Movie>> getMoviesByWriter(String writer) => _wrap('getMoviesByWriter', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'writers LIKE ? AND is_deleted = ?',
      whereArgs: ['%$writer%', 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Movie.fromJson(m))
        .where((movie) => movie.writers.contains(writer))
        .toList();
  });

  // 根据演员筛选
  Future<List<Movie>> getMoviesByActor(String actor) => _wrap('getMoviesByActor', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'actors LIKE ? AND is_deleted = ?',
      whereArgs: ['%$actor%', 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Movie.fromJson(m))
        .where((movie) => movie.actors.contains(actor))
        .toList();
  });

  // 根据类型筛选
  Future<List<Movie>> getMoviesByGenre(String genre) => _wrap('getMoviesByGenre', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'genres LIKE ? AND is_deleted = ?',
      whereArgs: ['%$genre%', 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Movie.fromJson(m))
        .where((movie) => movie.genres.contains(genre))
        .toList();
  });

  // 搜索影视（标题或别名）
  Future<List<Movie>> searchMovies(String keyword) => _wrap('searchMovies', () async {
    final db = await _dbHelper.database;
    final likeKeyword = '%$keyword%';
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: '(title LIKE ? OR alternate_titles LIKE ?) AND is_deleted = ?',
      whereArgs: [likeKeyword, likeKeyword, 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Movie.fromJson(m)).toList();
  });

  // 添加影视记录
  Future<int> insertMovie(Movie movie) => _wrap('insertMovie', () async {
    final db = await _dbHelper.database;
    return await db.insert('movies', movie.toJson());
  });

  // 更新影视记录
  Future<int> updateMovie(Movie movie) => _wrap('updateMovie', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'movies',
      movie.toJson(),
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  });

  // 删除影视记录（软删除）
  Future<int> deleteMovie(String id) => _wrap('deleteMovie', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'movies',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 获取所有导演（去重）
  Future<List<String>> getAllDirectors() => _wrap('getAllDirectors', () async {
    final movies = await getAllMovies();
    final directors = <String>{};
    for (final movie in movies) {
      directors.addAll(movie.directors);
    }
    return directors.toList()..sort();
  });

  // 获取所有编剧（去重）
  Future<List<String>> getAllWriters() => _wrap('getAllWriters', () async {
    final movies = await getAllMovies();
    final writers = <String>{};
    for (final movie in movies) {
      writers.addAll(movie.writers);
    }
    return writers.toList()..sort();
  });

  // 获取所有演员（去重）
  Future<List<String>> getAllActors() => _wrap('getAllActors', () async {
    final movies = await getAllMovies();
    final actors = <String>{};
    for (final movie in movies) {
      actors.addAll(movie.actors);
    }
    return actors.toList()..sort();
  });

  // 获取所有类型（去重）
  Future<List<String>> getAllGenres() => _wrap('getAllGenres', () async {
    final movies = await getAllMovies();
    final genres = <String>{};
    for (final movie in movies) {
      genres.addAll(movie.genres);
    }
    return genres.toList()..sort();
  });

  // 一次性获取所有元数据（导演、编剧、演员、类型）
  Future<Map<String, List<String>>> getAllMetadata() => _wrap('getAllMetadata', () async {
    final movies = await getAllMovies();
    final directors = <String>{};
    final writers = <String>{};
    final actors = <String>{};
    final genres = <String>{};
    for (final movie in movies) {
      directors.addAll(movie.directors);
      writers.addAll(movie.writers);
      actors.addAll(movie.actors);
      genres.addAll(movie.genres);
    }
    return {
      'directors': directors.toList()..sort(),
      'writers': writers.toList()..sort(),
      'actors': actors.toList()..sort(),
      'genres': genres.toList()..sort(),
    };
  });

  // ========== 回收站相关方法 ==========

  // 获取已删除的影视
  Future<List<Movie>> getDeletedMovies() => _wrap('getDeletedMovies', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  });

  // 恢复已删除的影视
  Future<int> restoreMovie(String id) => _wrap('restoreMovie', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'movies',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 彻底删除影视
  Future<int> permanentDeleteMovie(String id) => _wrap('permanentDeleteMovie', () async {
    final db = await _dbHelper.database;
    return await db.delete(
      'movies',
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
