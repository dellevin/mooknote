import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 影视海报墙数据访问对象
class MoviePosterDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[MoviePosterDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取影视的所有海报
  Future<List<MoviePoster>> getPostersByMovieId(String movieId) => _wrap('getPostersByMovieId', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_posters',
      where: 'movie_id = ? AND is_deleted = 0',
      whereArgs: [movieId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MoviePoster.fromJson(maps[i]));
  });

  /// 根据ID获取海报
  Future<MoviePoster?> getPosterById(String id) => _wrap('getPosterById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_posters',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return MoviePoster.fromJson(maps.first);
  });

  /// 添加海报
  Future<int> insertPoster(MoviePoster poster) => _wrap('insertPoster', () async {
    final db = await _dbHelper.database;
    return await db.insert('movie_posters', poster.toJson());
  });

  /// 软删除海报
  Future<int> deletePoster(String id) => _wrap('deletePoster', () async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final rows = await txn.query(
        'movie_posters',
        columns: ['movie_id'],
        where: 'id = ?',
        whereArgs: [id],
      );
      final now = DateTime.now().toUtc().toIso8601String();
      final count = await txn.update(
        'movie_posters',
        {'is_deleted': 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      // 海报表无 updated_at 且软删行不进同步管道，
      // 须 bump 父影视时间戳触发整组重推，他端才会移除该海报
      if (rows.isNotEmpty) {
        await txn.update(
          'movies',
          {'updated_at': now},
          where: 'id = ?',
          whereArgs: [rows.first['movie_id']],
        );
      }
      return count;
    });
  });

  /// 获取影视的海报数量
  Future<int> getPosterCount(String movieId) => _wrap('getPosterCount', () async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM movie_posters WHERE movie_id = ? AND is_deleted = 0',
      [movieId],
    );
    return result.first['count'] as int? ?? 0;
  });
}
