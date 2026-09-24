import 'package:sqflite/sqflite.dart';
import '../../../data/database_helper.dart';
import 'sync_identity.dart';

/// 增量同步墓碑：记录本客户端的彻底删除操作，供推送时生成删除 op
class SyncTombstones {
  /// 记录一次彻底删除
  static Future<void> record(String entityType, String entityId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final clientId = await SyncIdentity.clientId();
      await db.insert(
        'sync_tombstones',
        {
          'entity_id': entityId,
          'entity_type': entityType,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'client_id': clientId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // 墓碑写入失败不应阻塞删除本身
    }
  }

  /// 拉取待推送的墓碑（仅未推送过的）
  static Future<List<Map<String, dynamic>>> takePending() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('sync_tombstones', where: 'pushed = 0');
  }

  /// 推送成功后标记为已推送。记录保留，待压实嵌入 manifest 后才可清除，
  /// 否则压实删除 folded delta 时删除信息会丢失
  static Future<void> markPushed(List<Map<String, dynamic>> rows) async {
    final db = await DatabaseHelper.instance.database;
    for (final row in rows) {
      await db.update(
        'sync_tombstones',
        {'pushed': 1},
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [row['entity_id'], row['entity_type']],
      );
    }
  }

  /// 全部墓碑（含已推送），构建/压实 manifest 时嵌入用
  static Future<List<Map<String, dynamic>>> all() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('sync_tombstones');
  }

  /// 墓碑已嵌入 manifest 后清除对应记录（只清快照内的，避免误清压实期间新产生的）
  static Future<void> clearEmbedded(List<Map<String, dynamic>> rows) async {
    final db = await DatabaseHelper.instance.database;
    for (final row in rows) {
      await db.delete(
        'sync_tombstones',
        where: 'entity_id = ? AND entity_type = ?',
        whereArgs: [row['entity_id'], row['entity_type']],
      );
    }
  }

  /// 应用远程删除时本地落墓碑，防止被旧快照/旧 delta 复活
  static Future<void> putIfAbsent(
    String entityType,
    String entityId,
    String deletedAt,
    String clientId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query(
      'sync_tombstones',
      where: 'entity_id = ? AND entity_type = ?',
      whereArgs: [entityId, entityType],
    );
    if (existing.isNotEmpty) return;
    await db.insert('sync_tombstones', {
      'entity_id': entityId,
      'entity_type': entityType,
      'deleted_at': deletedAt,
      'client_id': clientId,
    });
  }

  static Future<bool> isDeleted(String entityType, String entityId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'sync_tombstones',
      where: 'entity_id = ? AND entity_type = ?',
      whereArgs: [entityId, entityType],
    );
    return rows.isNotEmpty;
  }
}
