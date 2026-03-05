import 'package:sqflite/sqflite.dart';
import '../models/data_models.dart';
import 'database_helper.dart';

/// 影视数据访问对象
class MovieDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 获取所有影视记录
  Future<List<Movie>> getAllMovies() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('movies');

    return List.generate(maps.length, (i) {
      return Movie(
        id: maps[i]['id'].toString(),
        title: maps[i]['title'],
        poster: maps[i]['poster'],
        rating: maps[i]['rating']?.toDouble(),
        year: maps[i]['year'],
        status: maps[i]['status'],
        watchDate: maps[i]['watch_date'] != null 
            ? DateTime.parse(maps[i]['watch_date']) 
            : null,
        note: maps[i]['note'],
      );
    });
  }

  // 根据状态筛选影视记录
  Future<List<Movie>> getMoviesByStatus(String status) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movies',
      where: 'status = ?',
      whereArgs: [status],
    );

    return List.generate(maps.length, (i) {
      return Movie(
        id: maps[i]['id'].toString(),
        title: maps[i]['title'],
        poster: maps[i]['poster'],
        rating: maps[i]['rating']?.toDouble(),
        year: maps[i]['year'],
        status: maps[i]['status'],
        watchDate: maps[i]['watch_date'] != null 
            ? DateTime.parse(maps[i]['watch_date']) 
            : null,
        note: maps[i]['note'],
      );
    });
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

  // 删除影视记录
  Future<int> deleteMovie(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'movies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
