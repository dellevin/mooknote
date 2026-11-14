import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../../services/cloud/cloud_domain_data_service.dart';
import '../../utils/user_prefs.dart';
import '../database_helper.dart';
import '../like_util.dart';

/// 自定义模块条目数据访问对象
///
/// [UserPrefs.cloudAnyMediaMode] 为 true 时走云端 domain-entities 通用路由，
/// 方法签名与本地模式保持一致；云端不支持事务参数，txn 在云分支被忽略。
class CustomModuleItemDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final CloudDomainDataService _cloud = CloudDomainDataService.instance;

  bool get _cloudMode => UserPrefs().cloudAnyMediaMode;

  /// 云端全量条目缓存：服务端无按模块过滤接口，一次拉全量复用，任何写操作后失效
  List<CustomModuleItem>? _cloudCache;
  void _invalidateCloudCache() => _cloudCache = null;

  /// 下拉刷新等手动重载场景：强制下次读取重新拉取云端全量
  void invalidateCloudCache() => _invalidateCloudCache();

  Future<List<CustomModuleItem>> _cloudAllItems() async =>
      _cloudCache ??= await _cloud.listEntities('custom_module_items', CustomModuleItem.fromJson);

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
    if (_cloudMode) {
      final rows = await _cloudAllItems();
      final list = rows.where((i) => i.moduleId == moduleId).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'module_id = ? AND is_deleted = ?',
      whereArgs: [moduleId, 0],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => CustomModuleItem.fromJson(m)).toList();
  });

  /// 全部模块的未删除条目（本地搜索一次性载入用，按更新时间倒序）
  Future<List<CustomModuleItem>> getAllActiveItems() => _wrap('getAllActiveItems', () async {
    if (_cloudMode) {
      final rows = List<CustomModuleItem>.from(await _cloudAllItems());
      rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rows;
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => CustomModuleItem.fromJson(m)).toList();
  });

  Future<CustomModuleItem?> getItemById(String id) => _wrap('getItemById', () async {
    if (_cloudMode) {
      final map = await _cloud.getEntity('custom_module_items', id);
      if (map == null) return null;
      final item = CustomModuleItem.fromJson(map);
      return item.isDeleted ? null : item;
    }
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
    if (_cloudMode) {
      final rows = await _cloudAllItems();
      return rows.where((i) => i.moduleId == moduleId).length;
    }
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM custom_module_items WHERE module_id = ? AND is_deleted = 0',
      [moduleId],
    );
    return (result.first['c'] as int?) ?? 0;
  });

  /// 按标题搜索
  Future<List<CustomModuleItem>> searchItems(String moduleId, String keyword) => _wrap('searchItems', () async {
    if (_cloudMode) {
      final rows = await _cloudAllItems();
      final kw = keyword.toLowerCase();
      final list = rows
          .where((i) => i.moduleId == moduleId && i.title.toLowerCase().contains(kw))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: "module_id = ? AND title LIKE ? ESCAPE '\\' AND is_deleted = ?",
      whereArgs: [moduleId, likePattern(keyword), 0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => CustomModuleItem.fromJson(m)).toList();
  });

  Future<int> insertItem(CustomModuleItem item) => _wrap('insertItem', () async {
    if (_cloudMode) {
      await _cloud.createEntity('custom_module_items', item.toJson());
      _invalidateCloudCache();
      return 1;
    }
    final db = await _dbHelper.database;
    return await db.insert('custom_module_items', item.toJson());
  });

  Future<int> updateItem(CustomModuleItem item) => _wrap('updateItem', () async {
    if (_cloudMode) {
      await _cloud.updateEntity('custom_module_items', item.id, item.toJson());
      _invalidateCloudCache();
      return 1;
    }
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
    if (_cloudMode) {
      await _cloud.deleteEntity('custom_module_items', id);
      _invalidateCloudCache();
      return 1;
    }
    final db = await _dbHelper.database;
    return await db.update(
      'custom_module_items',
      {'is_deleted': 1, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 回收站：全部已删除条目（按删除时间倒序）
  Future<List<CustomModuleItem>> getDeletedItems() => _wrap('getDeletedItems', () async {
    if (_cloudMode) {
      final rows = await _cloud.deletedEntities('custom_module_items', CustomModuleItem.fromJson);
      rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rows;
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => CustomModuleItem.fromJson(m)).toList();
  });

  /// 含已删除的按 id 查询（彻底删除前取 moduleId 清理图片用）
  Future<CustomModuleItem?> getItemRaw(String id) => _wrap('getItemRaw', () async {
    if (_cloudMode) {
      final map = await _cloud.getEntity('custom_module_items', id);
      return map == null ? null : CustomModuleItem.fromJson(map);
    }
    final db = await _dbHelper.database;
    final maps = await db.query(
      'custom_module_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CustomModuleItem.fromJson(maps.first);
  });

  /// 恢复
  Future<int> restoreItem(String id) => _wrap('restoreItem', () async {
    if (_cloudMode) {
      await _cloud.restoreEntity('custom_module_items', id);
      _invalidateCloudCache();
      return 1;
    }
    final db = await _dbHelper.database;
    return await db.update(
      'custom_module_items',
      {'is_deleted': 0, 'updated_at': DateTime.now().toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 彻底删除。txn 可传入外部事务复用（事务内禁止用 db 句柄，会死锁）；
  /// 云端无本地事务概念，txn 在云分支忽略。
  Future<int> permanentDeleteItem(String id, {DatabaseExecutor? txn}) =>
      _wrap('permanentDeleteItem', () async {
    if (_cloudMode) {
      await _cloud.permanentDeleteEntity('custom_module_items', id);
      _invalidateCloudCache();
      return 1;
    }
    final db = txn ?? await _dbHelper.database;
    return await db.delete(
      'custom_module_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
