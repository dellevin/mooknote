import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 影视↔人物关联数据访问对象
class MoviePersonDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[MoviePersonDao] $op error: $e');
      rethrow;
    }
  }

  // 获取某部影视的所有关联人物
  Future<List<MoviePerson>> getByMovieId(String movieId) => _wrap('getByMovieId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'movie_people',
      where: 'movie_id = ?',
      whereArgs: [movieId],
      orderBy: 'role_type, sort_order',
    );
    return maps.map((m) => MoviePerson.fromJson(m)).toList();
  });

  // 获取某个人物参与的所有影视关联
  Future<List<MoviePerson>> getByPersonId(String personId) => _wrap('getByPersonId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'movie_people',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'sort_order',
    );
    return maps.map((m) => MoviePerson.fromJson(m)).toList();
  });

  // 按影视+角色类型获取人物
  Future<List<MoviePerson>> getByMovieAndRole(String movieId, String roleType) => _wrap('getByMovieAndRole', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'movie_people',
      where: 'movie_id = ? AND role_type = ?',
      whereArgs: [movieId, roleType],
      orderBy: 'sort_order',
    );
    return maps.map((m) => MoviePerson.fromJson(m)).toList();
  });

  // 添加关联
  Future<int> insert(MoviePerson moviePerson) => _wrap('insert', () async {
    final db = await _dbHelper.database;
    return await db.insert('movie_people', moviePerson.toJson());
  });

  // 批量添加关联
  Future<void> insertAll(List<MoviePerson> items) => _wrap('insertAll', () async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('movie_people', item.toJson());
    }
    await batch.commit(noResult: true);
  });

  // 更新关联（如修改角色名）
  Future<int> update(MoviePerson moviePerson) => _wrap('update', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'movie_people',
      moviePerson.toJson(),
      where: 'id = ?',
      whereArgs: [moviePerson.id],
    );
  });

  // 删除某部影视的所有关联
  Future<int> deleteByMovieId(String movieId) => _wrap('deleteByMovieId', () async {
    final db = await _dbHelper.database;
    return await db.delete('movie_people', where: 'movie_id = ?', whereArgs: [movieId]);
  });

  // 删除某个人物的所有影视关联
  Future<int> deleteByPersonId(String personId) => _wrap('deleteByPersonId', () async {
    final db = await _dbHelper.database;
    return await db.delete('movie_people', where: 'person_id = ?', whereArgs: [personId]);
  });

  // 删除单条关联
  Future<int> deleteById(String id) => _wrap('deleteById', () async {
    final db = await _dbHelper.database;
    return await db.delete('movie_people', where: 'id = ?', whereArgs: [id]);
  });

  // 检查关联是否已存在（避免重复插入）
  Future<bool> existsRelation(String movieId, String personId, String roleType) => _wrap('existsRelation', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'movie_people',
      where: 'movie_id = ? AND person_id = ? AND role_type = ?',
      whereArgs: [movieId, personId, roleType],
      limit: 1,
    );
    return maps.isNotEmpty;
  });
}
