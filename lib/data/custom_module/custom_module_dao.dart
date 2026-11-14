import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../../services/cloud/cloud_domain_data_service.dart';
import '../../utils/user_prefs.dart';
import '../database_helper.dart';

/// 自定义分类模块数据访问对象
///
/// 片单/自定义模块不绑定单一媒体域，[UserPrefs.cloudAnyMediaMode] 为 true 时
/// 整体走云端 domain-entities 通用路由，方法签名与本地模式保持一致。
class CustomModuleDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CloudDomainDataService _cloud = CloudDomainDataService.instance;

  bool get _cloudMode => UserPrefs().cloudAnyMediaMode;

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
    if (_cloudMode) {
      final rows = await _cloud.listEntities('custom_modules', CustomModule.fromJson);
      rows.sort((a, b) {
        if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
        return a.createdAt.compareTo(b.createdAt);
      });
      return rows;
    }
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
    if (_cloudMode) {
      final map = await _cloud.getEntity('custom_modules', id);
      if (map == null) return null;
      final module = CustomModule.fromJson(map);
      return module.isDeleted ? null : module;
    }
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
    if (_cloudMode) {
      await _cloud.createEntity('custom_modules', module.toJson());
      return 1;
    }
    final db = await _dbHelper.database;
    return await db.insert('custom_modules', module.toJson());
  });

  Future<int> updateModule(CustomModule module) => _wrap('updateModule', () async {
    if (_cloudMode) {
      await _cloud.updateEntity('custom_modules', module.id, module.toJson());
      return 1;
    }
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
    if (_cloudMode) {
      await _cloud.updateEntity('custom_modules', id, {
        'is_enabled': enabled ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return;
    }
    final db = await _dbHelper.database;
    await db.update(
      'custom_modules',
      {'is_enabled': enabled ? 1 : 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 软删除模块，级联软删其设计与条目
  Future<void> deleteModule(String id) => _wrap('deleteModule', () async {
    if (_cloudMode) {
      final now = DateTime.now().toUtc().toIso8601String();
      await _cloud.deleteEntity('custom_modules', id);
      final designs = await _cloud.listEntities(
          'custom_module_designs', CustomModuleDesign.fromJson);
      for (final d in designs.where((d) => d.moduleId == id)) {
        await _cloud.updateEntity('custom_module_designs', d.id,
            {'is_deleted': 1, 'is_active': 0, 'updated_at': now});
      }
      final items = await _cloud.listEntities(
          'custom_module_items', CustomModuleItem.fromJson);
      for (final item in items.where((i) => i.moduleId == id)) {
        await _cloud.updateEntity(
            'custom_module_items', item.id, {'is_deleted': 1, 'updated_at': now});
      }
      return;
    }
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.update('custom_modules', {'is_deleted': 1, 'updated_at': now}, where: 'id = ?', whereArgs: [id]);
      await txn.update('custom_module_designs', {'is_deleted': 1, 'updated_at': now}, where: 'module_id = ?', whereArgs: [id]);
      await txn.update('custom_module_items', {'is_deleted': 1, 'updated_at': now}, where: 'module_id = ?', whereArgs: [id]);
    });
  });
}
