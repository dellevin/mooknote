import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../../models/data_models.dart';

/// 游戏评价数据访问对象
class GameReviewDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GameReviewDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取游戏的所有评价
  Future<List<GameReview>> getReviewsByGameId(String gameId) => _wrap('getReviewsByGameId', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_reviews',
      where: 'game_id = ? AND is_deleted = 0',
      whereArgs: [gameId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => GameReview.fromJson(maps[i]));
  });

  /// 根据ID获取评价
  Future<GameReview?> getReviewById(String id) => _wrap('getReviewById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_reviews',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return GameReview.fromJson(maps.first);
  });

  /// 添加评价
  Future<int> insertReview(GameReview review) => _wrap('insertReview', () async {
    final db = await _dbHelper.database;
    return await db.insert('game_reviews', review.toJson());
  });

  /// 更新评价
  Future<int> updateReview(GameReview review) => _wrap('updateReview', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_reviews',
      review.toJson(),
      where: 'id = ?',
      whereArgs: [review.id],
    );
  });

  /// 软删除评价
  Future<int> deleteReview(String id) => _wrap('deleteReview', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_reviews',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 获取游戏评价数量
  Future<int> getReviewCount(String gameId) => _wrap('getReviewCount', () async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM game_reviews WHERE game_id = ? AND is_deleted = 0',
      [gameId],
    );
    return result.first['count'] as int? ?? 0;
  });

  /// 获取短评列表
  Future<List<GameReview>> getShortReviews(String gameId) => _wrap('getShortReviews', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_reviews',
      where: 'game_id = ? AND review_type = 1 AND is_deleted = 0',
      whereArgs: [gameId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => GameReview.fromJson(maps[i]));
  });

  /// 获取长评列表
  Future<List<GameReview>> getLongReviews(String gameId) => _wrap('getLongReviews', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_reviews',
      where: 'game_id = ? AND review_type = 2 AND is_deleted = 0',
      whereArgs: [gameId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => GameReview.fromJson(maps[i]));
  });

  /// 获取已删除的评价
  Future<List<GameReview>> getDeletedReviews() => _wrap('getDeletedReviews', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_reviews',
      where: 'is_deleted = 1',
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => GameReview.fromJson(maps[i]));
  });

  /// 恢复已删除的评价
  Future<int> restoreReview(String id) => _wrap('restoreReview', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_reviews',
      {'is_deleted': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 永久删除评价
  Future<int> permanentDeleteReview(String id) => _wrap('permanentDeleteReview', () async {
    final db = await _dbHelper.database;
    return await db.delete('game_reviews', where: 'id = ?', whereArgs: [id]);
  });
}
