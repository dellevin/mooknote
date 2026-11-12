import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../../models/data_models.dart';

/// 游戏通关记录数据访问对象
class GameCompletionDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GameCompletionDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取游戏的所有通关记录（按通关时间倒序）
  Future<List<GameCompletion>> getCompletionsByGameId(String gameId) => _wrap('getCompletionsByGameId', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_completions',
      where: 'game_id = ? AND is_deleted = 0',
      whereArgs: [gameId],
      orderBy: 'completion_date DESC',
    );
    return List.generate(maps.length, (i) => GameCompletion.fromJson(maps[i]));
  });

  /// 根据ID获取通关记录
  Future<GameCompletion?> getCompletionById(String id) => _wrap('getCompletionById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_completions',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return GameCompletion.fromJson(maps.first);
  });

  /// 获取全部游戏的通关记录（供批量导出）
  Future<List<GameCompletion>> getAllCompletions() => _wrap('getAllCompletions', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_completions',
      where: 'is_deleted = 0',
      orderBy: 'completion_date DESC',
    );
    return List.generate(maps.length, (i) => GameCompletion.fromJson(maps[i]));
  });

  /// 添加通关记录
  Future<int> insertCompletion(GameCompletion completion) => _wrap('insertCompletion', () async {
    final db = await _dbHelper.database;
    return await db.insert('game_completions', completion.toJson());
  });

  /// 更新通关记录
  Future<int> updateCompletion(GameCompletion completion) => _wrap('updateCompletion', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_completions',
      completion.toJson(),
      where: 'id = ?',
      whereArgs: [completion.id],
    );
  });

  /// 软删除通关记录
  Future<int> deleteCompletion(String id) => _wrap('deleteCompletion', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_completions',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
