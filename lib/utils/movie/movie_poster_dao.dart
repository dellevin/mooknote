import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 影视海报墙数据访问对象
class MoviePosterDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 获取影视的所有海报
  Future<List<MoviePoster>> getPostersByMovieId(String movieId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_posters',
      where: 'movie_id = ? AND is_deleted = 0',
      whereArgs: [movieId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => MoviePoster.fromJson(maps[i]));
  }

  /// 根据ID获取海报
  Future<MoviePoster?> getPosterById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_posters',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return MoviePoster.fromJson(maps.first);
  }

  /// 添加海报
  Future<int> insertPoster(MoviePoster poster) async {
    final db = await _dbHelper.database;
    return await db.insert('movie_posters', poster.toJson());
  }

  /// 软删除海报
  Future<int> deletePoster(String id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'movie_posters',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取影视的海报数量
  Future<int> getPosterCount(String movieId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM movie_posters WHERE movie_id = ? AND is_deleted = 0',
      [movieId],
    );
    return result.first['count'] as int;
  }
}
