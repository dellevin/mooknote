import 'package:flutter/foundation.dart';
import '../../models/note_plus_models.dart';
import '../database_helper.dart';

/// Note Plus 块文档数据访问对象
class NotePlusDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[NotePlusDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有未删除的文档
  Future<List<NotePlusDocument>> getAll() => _wrap('getAll', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_plus',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'sort_index ASC, updated_at DESC',
    );
    return List.generate(maps.length, (i) => NotePlusDocument.fromJson(maps[i]));
  });

  // 分页查询
  Future<List<NotePlusDocument>> getPaged({int limit = 20, int offset = 0}) =>
      _wrap('getPaged', () async {
    final db = await _dbHelper.database;
    final maps = await db.query('note_plus', where: 'is_deleted = 0',
        orderBy: 'sort_index ASC, updated_at DESC', limit: limit, offset: offset);
    return List.generate(maps.length, (i) => NotePlusDocument.fromJson(maps[i]));
  });

  // 根据ID获取
  Future<NotePlusDocument?> getById(String id) => _wrap('getById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_plus',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return NotePlusDocument.fromJson(maps.first);
  });

  // 插入
  Future<int> insert(NotePlusDocument doc) => _wrap('insert', () async {
    final db = await _dbHelper.database;
    return await db.insert('note_plus', doc.toJson());
  });

  // 更新
  Future<int> update(NotePlusDocument doc) => _wrap('update', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'note_plus',
      doc.toJson(),
      where: 'id = ?',
      whereArgs: [doc.id],
    );
  });

  // 软删除
  Future<int> delete(String id) => _wrap('delete', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'note_plus',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // ========== 回收站 ==========

  Future<List<NotePlusDocument>> getDeleted() => _wrap('getDeleted', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_plus',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'sort_index ASC, updated_at DESC',
    );
    return List.generate(maps.length, (i) => NotePlusDocument.fromJson(maps[i]));
  });

  Future<int> restore(String id) => _wrap('restore', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'note_plus',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  Future<int> permanentDelete(String id) => _wrap('permanentDelete', () async {
    final db = await _dbHelper.database;
    return await db.delete(
      'note_plus',
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 搜索
  Future<List<NotePlusDocument>> search(String query) => _wrap('search', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_plus',
      where: '(title LIKE ? OR blocks_json LIKE ? OR tags LIKE ?) AND is_deleted = ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', 0],
      orderBy: 'sort_index ASC, updated_at DESC',
    );
    return List.generate(maps.length, (i) => NotePlusDocument.fromJson(maps[i]));
  });

  // 根据标签筛选
  Future<List<NotePlusDocument>> getByTag(String tag) => _wrap('getByTag', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'note_plus',
      where: 'tags LIKE ? AND is_deleted = ?',
      whereArgs: ['%$tag%', 0],
      orderBy: 'sort_index ASC, updated_at DESC',
    );
    return List.generate(maps.length, (i) => NotePlusDocument.fromJson(maps[i]));
  });
}
