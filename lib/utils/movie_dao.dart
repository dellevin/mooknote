import 'package:sqflite/sqflite.dart';
import '../models/data_models.dart';
import 'database_helper.dart';

/// 影视数据访问对象
class MovieDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 获取所有影视记录（未删除的）
  Future<List<Movie>> getAllMovies() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  }

  // 根据状态筛选影视记录
  Future<List<Movie>> getMoviesByStatus(String status) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'status = ? AND is_deleted = ?',
      whereArgs: [status, 0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  }

  // 根据导演筛选
  Future<List<Movie>> getMoviesByDirector(String director) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]))
        .where((movie) => movie.directors.contains(director))
        .toList();
  }

  // 根据编剧筛选
  Future<List<Movie>> getMoviesByWriter(String writer) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]))
        .where((movie) => movie.writers.contains(writer))
        .toList();
  }

  // 根据演员筛选
  Future<List<Movie>> getMoviesByActor(String actor) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]))
        .where((movie) => movie.actors.contains(actor))
        .toList();
  }

  // 根据类型筛选
  Future<List<Movie>> getMoviesByGenre(String genre) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]))
        .where((movie) => movie.genres.contains(genre))
        .toList();
  }

  // 搜索影视（标题或别名）
  Future<List<Movie>> searchMovies(String keyword) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    
    final lowerKeyword = keyword.toLowerCase();
    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]))
        .where((movie) => 
            movie.title.toLowerCase().contains(lowerKeyword) ||
            movie.alternateTitles.any((t) => t.toLowerCase().contains(lowerKeyword)))
        .toList();
  }

  // 添加影视记录
  Future<int> insertMovie(Movie movie) async {
    final db = await _dbHelper.database;
    return await db.insert('movies', movie.toJson());
  }

  // 更新影视记录
  Future<int> updateMovie(Movie movie) async {
    final db = await _dbHelper.database;
    return await db.update(
      'movies',
      movie.toJson(),
      where: 'id = ?',
      whereArgs: [movie.id],
    );
  }

  // 删除影视记录（软删除）
  Future<int> deleteMovie(String id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'movies',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 获取所有导演（去重）
  Future<List<String>> getAllDirectors() async {
    final movies = await getAllMovies();
    final directors = <String>{};
    for (final movie in movies) {
      directors.addAll(movie.directors);
    }
    return directors.toList()..sort();
  }

  // 获取所有编剧（去重）
  Future<List<String>> getAllWriters() async {
    final movies = await getAllMovies();
    final writers = <String>{};
    for (final movie in movies) {
      writers.addAll(movie.writers);
    }
    return writers.toList()..sort();
  }

  // 获取所有演员（去重）
  Future<List<String>> getAllActors() async {
    final movies = await getAllMovies();
    final actors = <String>{};
    for (final movie in movies) {
      actors.addAll(movie.actors);
    }
    return actors.toList()..sort();
  }

  // 获取所有类型（去重）
  Future<List<String>> getAllGenres() async {
    final movies = await getAllMovies();
    final genres = <String>{};
    for (final movie in movies) {
      genres.addAll(movie.genres);
    }
    return genres.toList()..sort();
  }

  // ========== 回收站相关方法 ==========

  // 获取已删除的影视
  Future<List<Movie>> getDeletedMovies() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Movie.fromJson(maps[i]));
  }

  // 恢复已删除的影视
  Future<int> restoreMovie(String id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'movies',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 彻底删除影视
  Future<int> permanentDeleteMovie(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'movies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
