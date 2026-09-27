import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 自定义模块设计表数据访问对象
class CustomModuleDesignDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[CustomModuleDesignDao] $op error: $e');
      rethrow;
    }
  }

  /// 某模块的全部设计（未删除，按创建时间）
  Future<List<CustomModuleDesign>> getDesignsForModule(String moduleId) => _wrap('getDesignsForModule', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_designs',
      where: 'module_id = ? AND is_deleted = ?',
      whereArgs: [moduleId, 0],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => CustomModuleDesign.fromJson(m)).toList();
  });

  Future<CustomModuleDesign?> getDesignById(String id) => _wrap('getDesignById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_designs',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return CustomModuleDesign.fromJson(maps.first);
  });

  /// 模块当前激活的设计（无激活时返回 null）
  Future<CustomModuleDesign?> getActiveDesign(String moduleId) => _wrap('getActiveDesign', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_designs',
      where: 'module_id = ? AND is_active = 1 AND is_deleted = ?',
      whereArgs: [moduleId, 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CustomModuleDesign.fromJson(maps.first);
  });

  Future<int> insertDesign(CustomModuleDesign design) => _wrap('insertDesign', () async {
    final db = await _dbHelper.database;
    return await db.insert('custom_module_designs', design.toJson());
  });

  Future<int> updateDesign(CustomModuleDesign design) => _wrap('updateDesign', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'custom_module_designs',
      design.toJson(),
      where: 'id = ?',
      whereArgs: [design.id],
    );
  });

  /// 切换激活设计：清掉同模块其他设计的激活标记，并同步模块表 active_design_id
  Future<void> setActiveDesign(String moduleId, String designId) => _wrap('setActiveDesign', () async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('custom_module_designs', {'is_active': 0, 'updated_at': now},
          where: 'module_id = ?', whereArgs: [moduleId]);
      await txn.update('custom_module_designs', {'is_active': 1, 'updated_at': now},
          where: 'id = ?', whereArgs: [designId]);
      await txn.update('custom_modules', {'active_design_id': designId, 'updated_at': now},
          where: 'id = ?', whereArgs: [moduleId]);
    });
  });

  /// 软删除设计；若删的是激活设计，清除模块表 active_design_id
  Future<void> deleteDesign(String moduleId, String designId) => _wrap('deleteDesign', () async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('custom_module_designs', {'is_deleted': 1, 'is_active': 0, 'updated_at': now},
          where: 'id = ?', whereArgs: [designId]);
      await txn.update('custom_modules', {'active_design_id': null, 'updated_at': now},
          where: 'id = ? AND active_design_id = ?', whereArgs: [moduleId, designId]);
    });
  });
}
