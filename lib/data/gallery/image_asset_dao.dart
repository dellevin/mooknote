import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../services/sync/incremental/sync_tombstones.dart';
import '../database_helper.dart';

/// 图片元数据 DAO —— 图库自定义重命名
/// 存储 key 为「逻辑路径」（images/ 目录下的相对路径，统一 / 分隔），
/// 保证重命名记录可随同步/备份跨设备生效。
class ImageAssetDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 任意设备的绝对路径 → images/ 下逻辑路径
  static String toLogicalPath(String absPath) {
    final normalized = absPath.replaceAll('\\', '/');
    final idx = normalized.indexOf('/images/');
    if (idx >= 0) return normalized.substring(idx + 8); // skip '/images/'
    return normalized;
  }

  /// 获取全部自定义名称映射：逻辑路径 → 显示名（仅非空名称）
  Future<Map<String, String>> getTitleMap() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query('image_assets',
          columns: ['path', 'title'], where: "title != ''");
      return {
        for (final r in rows)
          r['path'] as String: (r['title'] as String?) ?? '',
      };
    } catch (e) {
      debugPrint('[ImageAssetDao] getTitleMap error: $e');
      return {};
    }
  }

  /// 获取单个图片的自定义名称（无则 null）
  Future<String?> getTitle(String logicalPath) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query('image_assets',
          columns: ['title'], where: 'path = ?', whereArgs: [logicalPath]);
      if (rows.isEmpty) return null;
      final title = (rows.first['title'] as String?) ?? '';
      return title.isEmpty ? null : title;
    } catch (e) {
      debugPrint('[ImageAssetDao] getTitle error: $e');
      return null;
    }
  }

  /// 重命名（upsert）。传入空名称则删除记录，恢复默认显示。
  Future<void> rename(String logicalPath, String title) async {
    try {
      final db = await _dbHelper.database;
      final trimmed = title.trim();
      final now = DateTime.now().toIso8601String();
      final existing = await db.query('image_assets',
          columns: ['id'], where: 'path = ?', whereArgs: [logicalPath]);
      if (trimmed.isEmpty) {
        // 清除名称：删除记录并留同步墓碑，保证其他设备同步删除
        await db.delete('image_assets', where: 'path = ?', whereArgs: [logicalPath]);
        if (existing.isNotEmpty) {
          await SyncTombstones.record('image_assets', existing.first['id'] as String);
        }
        return;
      }
      if (existing.isEmpty) {
        await db.insert('image_assets', {
          'id': const Uuid().v4(),
          'path': logicalPath,
          'title': trimmed,
          'created_at': now,
          'updated_at': now,
        });
      } else {
        await db.update(
          'image_assets',
          {'title': trimmed, 'updated_at': now},
          where: 'path = ?',
          whereArgs: [logicalPath],
        );
      }
    } catch (e) {
      debugPrint('[ImageAssetDao] rename error: $e');
    }
  }

  /// 文件迁移目录时同步更新记录的路径（如未保存实体的临时目录 → 正式目录）
  Future<void> onFileMoved(String oldAbsPath, String newAbsPath) async {
    final oldLogical = toLogicalPath(oldAbsPath);
    final newLogical = toLogicalPath(newAbsPath);
    if (oldLogical == newLogical) return;
    try {
      final db = await _dbHelper.database;
      await db.update(
        'image_assets',
        {'path': newLogical, 'updated_at': DateTime.now().toIso8601String()},
        where: 'path = ?',
        whereArgs: [oldLogical],
      );
    } catch (e) {
      debugPrint('[ImageAssetDao] onFileMoved error: $e');
    }
  }
}
