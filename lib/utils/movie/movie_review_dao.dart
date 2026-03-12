import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 影评数据访问对象
class MovieReviewDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 获取影视的所有影评
  Future<List<MovieReview>> getReviewsByMovieId(String movieId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_reviews',
      where: 'movie_id = ? AND is_deleted = 0',
      whereArgs: [movieId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => MovieReview.fromJson(maps[i]));
  }

  /// 根据ID获取影评
  Future<MovieReview?> getReviewById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_reviews',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return MovieReview.fromJson(maps.first);
  }

  /// 添加影评
  Future<int> insertReview(MovieReview review) async {
    final db = await _dbHelper.database;
    return await db.insert('movie_reviews', review.toJson());
  }

  /// 更新影评
  Future<int> updateReview(MovieReview review) async {
    final db = await _dbHelper.database;
    return await db.update(
      'movie_reviews',
      review.toJson(),
      where: 'id = ?',
      whereArgs: [review.id],
    );
  }

  /// 软删除影评
  Future<int> deleteReview(String id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'movie_reviews',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取影视的影评数量
  Future<int> getReviewCount(String movieId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM movie_reviews WHERE movie_id = ? AND is_deleted = 0',
      [movieId],
    );
    return result.first['count'] as int;
  }

  /// 获取短评列表
  Future<List<MovieReview>> getShortReviews(String movieId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_reviews',
      where: 'movie_id = ? AND review_type = 1 AND is_deleted = 0',
      whereArgs: [movieId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => MovieReview.fromJson(maps[i]));
  }

  /// 获取长评列表
  Future<List<MovieReview>> getLongReviews(String movieId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'movie_reviews',
      where: 'movie_id = ? AND review_type = 2 AND is_deleted = 0',
      whereArgs: [movieId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) => MovieReview.fromJson(maps[i]));
  }
}
