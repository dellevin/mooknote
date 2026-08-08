import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 游戏角色数据访问对象
class GameCharacterDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GameCharacterDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取游戏的所有角色
  Future<List<GameCharacter>> getByGameId(String gameId) => _wrap('getByGameId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'game_characters',
      where: 'game_id = ? AND is_deleted = 0',
      whereArgs: [gameId],
      orderBy: 'sort_order, created_at',
    );
    return maps.map((m) => GameCharacter.fromJson(m)).toList();
  });

  /// 根据ID获取角色
  Future<GameCharacter?> getById(String id) => _wrap('getById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'game_characters',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return GameCharacter.fromJson(maps.first);
  });

  /// 添加角色
  Future<int> insert(GameCharacter character) => _wrap('insert', () async {
    final db = await _dbHelper.database;
    return await db.insert('game_characters', character.toJson());
  });

  /// 更新角色
  Future<int> update(GameCharacter character) => _wrap('update', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_characters',
      character.toJson(),
      where: 'id = ?',
      whereArgs: [character.id],
    );
  });

  /// 软删除角色
  Future<int> delete(String id) => _wrap('delete', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_characters',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 恢复已删除的角色
  Future<int> restore(String id) => _wrap('restore', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'game_characters',
      {'is_deleted': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 获取已删除的角色
  Future<List<GameCharacter>> getDeleted() => _wrap('getDeleted', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'game_characters',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => GameCharacter.fromJson(m)).toList();
  });

  /// 获取游戏的角色数量
  Future<int> getCount(String gameId) => _wrap('getCount', () async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM game_characters WHERE game_id = ? AND is_deleted = 0',
      [gameId],
    );
    return result.first['count'] as int? ?? 0;
  });

  /// 彻底删除角色
  Future<void> permanentDelete(String id) => _wrap('permanentDelete', () async {
    final db = await _dbHelper.database;
    await db.delete('game_characters', where: 'id = ?', whereArgs: [id]);
  });
}
