import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 游戏↔人物关联数据访问对象
class GamePersonDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GamePersonDao] $op error: $e');
      rethrow;
    }
  }

  // 获取某游戏的所有关联人物
  Future<List<GamePerson>> getByGameId(String gameId) => _wrap('getByGameId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'game_people',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'sort_order',
    );
    return maps.map((m) => GamePerson.fromJson(m)).toList();
  });

  // 获取某个人物参与的所有游戏关联
  Future<List<GamePerson>> getByPersonId(String personId) => _wrap('getByPersonId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'game_people',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'sort_order',
    );
    return maps.map((m) => GamePerson.fromJson(m)).toList();
  });

  // 添加关联
  Future<int> insert(GamePerson gamePerson) => _wrap('insert', () async {
    final db = await _dbHelper.database;
    return await db.insert('game_people', gamePerson.toJson());
  });

  // 批量添加关联
  Future<void> insertAll(List<GamePerson> items) => _wrap('insertAll', () async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('game_people', item.toJson());
    }
    await batch.commit(noResult: true);
  });

  // 删除某游戏的所有关联
  Future<int> deleteByGameId(String gameId) => _wrap('deleteByGameId', () async {
    final db = await _dbHelper.database;
    return await db.delete('game_people', where: 'game_id = ?', whereArgs: [gameId]);
  });

  // 删除某个人物的所有游戏关联
  Future<int> deleteByPersonId(String personId) => _wrap('deleteByPersonId', () async {
    final db = await _dbHelper.database;
    return await db.delete('game_people', where: 'person_id = ?', whereArgs: [personId]);
  });

  // 删除单条关联
  Future<int> deleteById(String id) => _wrap('deleteById', () async {
    final db = await _dbHelper.database;
    return await db.delete('game_people', where: 'id = ?', whereArgs: [id]);
  });

  // 检查关联是否已存在（避免重复插入）
  Future<bool> existsRelation(String gameId, String personId, String roleType) => _wrap('existsRelation', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'game_people',
      where: 'game_id = ? AND person_id = ? AND role_type = ?',
      whereArgs: [gameId, personId, roleType],
      limit: 1,
    );
    return maps.isNotEmpty;
  });
}
