import 'package:flutter/foundation.dart';
import '../database_helper.dart';
import '../../models/data_models.dart';

/// 游戏截图数据访问对象
class GameScreenshotDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GameScreenshotDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取游戏的所有截图
  Future<List<GameScreenshot>> getScreenshotsByGameId(String gameId) => _wrap('getScreenshotsByGameId', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_screenshots',
      where: 'game_id = ? AND is_deleted = 0',
      whereArgs: [gameId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => GameScreenshot.fromJson(maps[i]));
  });

  /// 根据ID获取截图
  Future<GameScreenshot?> getScreenshotById(String id) => _wrap('getScreenshotById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'game_screenshots',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return GameScreenshot.fromJson(maps.first);
  });

  /// 添加截图
  Future<int> insertScreenshot(GameScreenshot screenshot) => _wrap('insertScreenshot', () async {
    final db = await _dbHelper.database;
    return await db.insert('game_screenshots', screenshot.toJson());
  });

  /// 软删除截图
  Future<int> deleteScreenshot(String id) => _wrap('deleteScreenshot', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_screenshots',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 获取游戏截图数量
  Future<int> getScreenshotCount(String gameId) => _wrap('getScreenshotCount', () async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM game_screenshots WHERE game_id = ? AND is_deleted = 0',
      [gameId],
    );
    return result.first['count'] as int? ?? 0;
  });
}
