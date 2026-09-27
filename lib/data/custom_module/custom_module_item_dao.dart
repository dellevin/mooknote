import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 自定义模块条目数据访问对象
class CustomModuleItemDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[CustomModuleItemDao] $op error: $e');
      rethrow;
    }
  }

  /// 某模块的全部条目（未删除，按创建时间倒序）
  Future<List<CustomModuleItem>> getItemsForModule(String moduleId) => _wrap('getItemsForModule', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'module_id = ? AND is_deleted = ?',
      whereArgs: [moduleId, 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => CustomModuleItem.fromJson(m)).toList();
  });

  Future<CustomModuleItem?> getItemById(String id) => _wrap('getItemById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return CustomModuleItem.fromJson(maps.first);
  });

  /// 某模块条目数（管理页展示用）
  Future<int> getItemCount(String moduleId) => _wrap('getItemCount', () async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM custom_module_items WHERE module_id = ? AND is_deleted = 0',
      [moduleId],
    );
    return (result.first['c'] as int?) ?? 0;
  });

  /// 按标题搜索
  Future<List<CustomModuleItem>> searchItems(String moduleId, String keyword) => _wrap('searchItems', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'module_id = ? AND title LIKE ? AND is_deleted = ?',
      whereArgs: [moduleId, '%$keyword%', 0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => CustomModuleItem.fromJson(m)).toList();
  });

  Future<int> insertItem(CustomModuleItem item) => _wrap('insertItem', () async {
    final db = await _dbHelper.database;
    return await db.insert('custom_module_items', item.toJson());
  });

  Future<int> updateItem(CustomModuleItem item) => _wrap('updateItem', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'custom_module_items',
      item.toJson(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  });

  /// 软删除
  Future<int> deleteItem(String id) => _wrap('deleteItem', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'custom_module_items',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
