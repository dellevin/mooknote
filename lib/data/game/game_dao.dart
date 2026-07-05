import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 游戏数据访问对象
class GameDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GameDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有游戏记录（未删除的）
  Future<List<Game>> getAllGames() => _wrap('getAllGames', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Game.fromJson(maps[i]));
  });

  // 分页查询游戏记录
  Future<List<Game>> getGamesPaged({String? status, int limit = 20, int offset = 0, int sortMode = 0}) => _wrap('getGamesPaged', () async {
    final db = await _dbHelper.database;
    String where = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    if (status != null && status.isNotEmpty) {
      where += ' AND status = ?';
      whereArgs.add(status);
    }
    final maps = await db.query('games', where: where, whereArgs: whereArgs,
        orderBy: _buildGameOrderBy(sortMode), limit: limit, offset: offset);
    return List.generate(maps.length, (i) => Game.fromJson(maps[i]));
  });

  static String _buildGameOrderBy(int sortMode) {
    switch (sortMode) {
      case 1: return 'created_at DESC';
      case 2: return 'rating DESC NULLS LAST, updated_at DESC';
      default: return 'updated_at DESC';
    }
  }

  // 搜索游戏（标题）
  Future<List<Game>> searchGames(String keyword) => _wrap('searchGames', () async {
    final db = await _dbHelper.database;
    final likeKeyword = '%$keyword%';
    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: 'title LIKE ? AND is_deleted = ?',
      whereArgs: [likeKeyword, 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Game.fromJson(m)).toList();
  });

  // 添加游戏记录
  Future<int> insertGame(Game game) => _wrap('insertGame', () async {
    final db = await _dbHelper.database;
    return await db.insert('games', game.toJson());
  });

  // 更新游戏记录
  Future<int> updateGame(Game game) => _wrap('updateGame', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'games',
      game.toJson(),
      where: 'id = ?',
      whereArgs: [game.id],
    );
  });

  // 仅更新封面偏移量
  Future<void> updateCoverOffset(String gameId, double offset) => _wrap('updateCoverOffset', () async {
    final db = await _dbHelper.database;
    await db.update('games', {'cover_offset': offset}, where: 'id = ?', whereArgs: [gameId]);
  });

  // 删除游戏记录（软删除）
  Future<int> deleteGame(String id) => _wrap('deleteGame', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'games',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 获取所有类型（去重）
  Future<List<String>> getAllGenres() => _wrap('getAllGenres', () async {
    final games = await getAllGames();
    final genres = <String>{};
    for (final game in games) {
      genres.addAll(game.genres);
    }
    return genres.toList()..sort();
  });

  // 获取所有平台（去重）
  Future<List<String>> getAllPlatforms() => _wrap('getAllPlatforms', () async {
    final games = await getAllGames();
    final platforms = <String>{};
    for (final game in games) {
      platforms.addAll(game.platforms);
    }
    return platforms.toList()..sort();
  });

  // ========== 回收站相关方法 ==========

  // 获取已删除的游戏
  Future<List<Game>> getDeletedGames() => _wrap('getDeletedGames', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Game.fromJson(maps[i]));
  });

  // 恢复已删除的游戏
  Future<int> restoreGame(String id) => _wrap('restoreGame', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'games',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 彻底删除游戏
  Future<int> permanentDeleteGame(String id) => _wrap('permanentDeleteGame', () async {
    final db = await _dbHelper.database;
    // 清理子记录，防止孤儿数据
    await db.delete('game_reviews', where: 'game_id = ?', whereArgs: [id]);
    await db.delete('game_screenshots', where: 'game_id = ?', whereArgs: [id]);
    return await db.delete(
      'games',
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
