import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 自定义分类模块数据访问对象
class CustomModuleDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[CustomModuleDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取所有模块（未删除，按排序值+创建时间）
  Future<List<CustomModule>> getAllModules() => _wrap('getAllModules', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_modules',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return maps.map((m) => CustomModule.fromJson(m)).toList();
  });

  Future<CustomModule?> getModuleById(String id) => _wrap('getModuleById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_modules',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return CustomModule.fromJson(maps.first);
  });

  Future<int> insertModule(CustomModule module) => _wrap('insertModule', () async {
    final db = await _dbHelper.database;
    return await db.insert('custom_modules', module.toJson());
  });

  Future<int> updateModule(CustomModule module) => _wrap('updateModule', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'custom_modules',
      module.toJson(),
      where: 'id = ?',
      whereArgs: [module.id],
    );
  });

  /// 开关首页 tab 显示
  Future<void> setEnabled(String id, bool enabled) => _wrap('setEnabled', () async {
    final db = await _dbHelper.database;
    await db.update(
      'custom_modules',
      {'is_enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 软删除模块，级联软删其设计与条目
  Future<void> deleteModule(String id) => _wrap('deleteModule', () async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('custom_modules', {'is_deleted': 1, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
      await txn.update('custom_module_designs', {'is_deleted': 1, 'updated_at': now}, where: 'module_id = ?', whereArgs: [id]);
      await txn.update('custom_module_items', {'is_deleted': 1, 'updated_at': now}, where: 'module_id = ?', whereArgs: [id]);
    });
  });
}
