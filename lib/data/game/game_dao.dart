import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';
import '../like_util.dart';
import '../playlist/playlist_dao.dart';

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
  Future<List<Game>> getAllGames({int sortMode = 0}) => _wrap('getAllGames', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: _buildGameOrderBy(sortMode),
    );
    return List.generate(maps.length, (i) => Game.fromJson(maps[i]));
  });

  // 根据ID获取游戏记录
  Future<Game?> getGameById(String id) => _wrap('getGameById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Game.fromJson(maps.first);
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
    // 不用 NULLS LAST（SQLite 3.30+ 才支持），改用 "col IS NULL, col DESC" 兼容写法
    switch (sortMode) {
      case 1: return 'created_at DESC';
      case 2: return 'rating IS NULL, rating DESC, updated_at DESC';
      case 3: return 'release_date IS NULL, release_date DESC, created_at DESC';
      case 4:
        // 最近一次通关时间；无通关记录的排最后
        return '(SELECT MAX(gc.completion_date) FROM game_completions gc WHERE gc.game_id = games.id AND gc.is_deleted = 0) IS NULL, '
            '(SELECT MAX(gc.completion_date) FROM game_completions gc WHERE gc.game_id = games.id AND gc.is_deleted = 0) DESC, updated_at DESC';
      default: return 'updated_at DESC';
    }
  }

  // 搜索游戏（标题）
  Future<List<Game>> searchGames(String keyword) => _wrap('searchGames', () async {
    final db = await _dbHelper.database;
    final likeKeyword = likePattern(keyword);
    final List<Map<String, dynamic>> maps = await db.query(
      'games',
      where: "title LIKE ? ESCAPE '\\' AND is_deleted = ?",
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
    return await db.transaction((txn) async {
      final result = await txn.update(
        'games',
        {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      // 片单保留条目引用（可恢复），仅刷新计数排除已删媒体
      await PlaylistDao.refreshItemCountsForMedia(txn, id, 'game');
      return result;
    });
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
    return await db.transaction((txn) async {
      final result = await txn.update(
        'games',
        {'is_deleted': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
      await PlaylistDao.refreshItemCountsForMedia(txn, id, 'game');
      return result;
    });
  });

  // 彻底删除游戏。txn 可传入外部事务复用（禁止在外层事务内再开事务，会死锁）
  Future<int> permanentDeleteGame(String id, {DatabaseExecutor? txn}) =>
      _wrap('permanentDeleteGame', () async {
    Future<int> run(DatabaseExecutor db) async {
      await db.delete('game_reviews', where: 'game_id = ?', whereArgs: [id]);
      await db.delete('game_screenshots', where: 'game_id = ?', whereArgs: [id]);
      await db.delete('game_completions', where: 'game_id = ?', whereArgs: [id]);
      await db.delete('game_levels', where: 'game_id = ?', whereArgs: [id]);
      await db.delete('game_people', where: 'game_id = ?', whereArgs: [id]);
      await db.delete('game_characters', where: 'game_id = ?', whereArgs: [id]);
      await PlaylistDao.removeMediaFromPlaylists(db, id, 'game');
      return await db.delete(
        'games',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    if (txn != null) return run(txn);
    final db = await _dbHelper.database;
    // 事务内清理全部子记录与片单引用，防止孤儿数据
    return await db.transaction(run);
  });
}
