import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 片单数据访问对象
class PlaylistDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[PlaylistDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有片单（未删除）
  Future<List<Playlist>> getAllPlaylists() => _wrap('getAllPlaylists', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'playlists',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'sort_order ASC, updated_at DESC',
    );
    return maps.map((m) => Playlist.fromJson(m)).toList();
  });

  // 获取单个片单（排除软删除；唯一调用方为 provider 状态回读，回收站走 restore 直接改标志位）
  Future<Playlist?> getPlaylistById(String id) => _wrap('getPlaylistById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'playlists',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Playlist.fromJson(maps.first);
  });

  // 创建片单
  Future<int> insertPlaylist(Playlist playlist) => _wrap('insertPlaylist', () async {
    final db = await _dbHelper.database;
    return await db.insert('playlists', playlist.toJson());
  });

  // 更新片单
  Future<int> updatePlaylist(Playlist playlist) => _wrap('updatePlaylist', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'playlists',
      playlist.toJson(),
      where: 'id = ?',
      whereArgs: [playlist.id],
    );
  });

  // 软删除片单
  Future<int> deletePlaylist(String id) => _wrap('deletePlaylist', () async {
    final db = await _dbHelper.database;
    // 事务：条目删除与片单软删必须同成同败，避免留下"可见的空片单"
    return await db.transaction((txn) async {
      await txn.delete('playlist_items', where: 'playlist_id = ?', whereArgs: [id]);
      return await txn.update(
        'playlists',
        {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  });

  // 获取片单内条目
  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) => _wrap('getPlaylistItems', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'playlist_items',
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'sort_order ASC, added_at DESC',
    );
    return maps.map((m) => PlaylistItem.fromJson(m)).toList();
  });

  // 添加条目到片单
  Future<int> addItem(PlaylistItem item) => _wrap('addItem', () async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final result = await txn.insert('playlist_items', item.toJson());
      await _refreshItemCount(txn, item.playlistId);
      return result;
    });
  });

  // 从片单移除条目
  Future<int> removeItem(String itemId, String playlistId) => _wrap('removeItem', () async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final result = await txn.delete(
        'playlist_items',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      await _refreshItemCount(txn, playlistId);
      return result;
    });
  });

  // 检查条目是否已在片单中
  Future<bool> isItemInPlaylist(String playlistId, String itemId) => _wrap('isItemInPlaylist', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'playlist_items',
      where: 'playlist_id = ? AND item_id = ?',
      whereArgs: [playlistId, itemId],
    );
    return maps.isNotEmpty;
  });

  // 获取片单内所有条目ID
  Future<List<String>> getPlaylistItemIds(String playlistId) => _wrap('getPlaylistItemIds', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'playlist_items',
      columns: ['item_id'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    return maps.map((m) => m['item_id'].toString()).toList();
  });

  /// 片单类型对应的媒体表（内部常量，可安全拼入 SQL）
  static const Map<String, String> _typeTables = {
    'movie': 'movies',
    'book': 'books',
    'game': 'games',
  };

  /// 重算 item_count：只统计媒体未被软删除的条目。
  /// 软删除的媒体仍保留条目引用，回收站恢复后计数自动回升。
  static Future<void> _refreshItemCount(DatabaseExecutor db, String playlistId) async {
    final rows = await db.query(
      'playlists',
      columns: ['type'],
      where: 'id = ?',
      whereArgs: [playlistId],
    );
    if (rows.isEmpty) return;
    final type = rows.first['type'] as String;
    final int count;
    if (type == 'all') {
      // 所有类型：条目在任一媒体表存在且未软删除即计数
      count = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM playlist_items pi WHERE pi.playlist_id = ? AND ('
        'EXISTS(SELECT 1 FROM movies m WHERE m.id = pi.item_id AND m.is_deleted = 0) OR '
        'EXISTS(SELECT 1 FROM books b WHERE b.id = pi.item_id AND b.is_deleted = 0) OR '
        'EXISTS(SELECT 1 FROM games g WHERE g.id = pi.item_id AND g.is_deleted = 0))',
        [playlistId],
      )) ?? 0;
    } else {
      final table = _typeTables[type];
      if (table == null) {
        count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM playlist_items WHERE playlist_id = ?',
          [playlistId],
        )) ?? 0;
      } else {
        count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM playlist_items pi '
          'JOIN $table m ON m.id = pi.item_id AND m.is_deleted = 0 '
          'WHERE pi.playlist_id = ?',
          [playlistId],
        )) ?? 0;
      }
    }
    await db.update(
      'playlists',
      {'item_count': count, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  /// 媒体软删除/恢复后调用：刷新包含该媒体的片单 item_count。
  /// 条目引用保留，回收站恢复后片单成员关系不丢。
  static Future<void> refreshItemCountsForMedia(DatabaseExecutor db, String itemId, String type) async {
    final affected = await db.rawQuery(
      'SELECT DISTINCT playlist_id FROM playlist_items WHERE item_id = ? '
      'AND playlist_id IN (SELECT id FROM playlists WHERE type = ? OR type = \'all\')',
      [itemId, type],
    );
    for (final row in affected) {
      await _refreshItemCount(db, row['playlist_id'] as String);
    }
  }

  // 批量更新片单条目排序
  Future<void> updatePlaylistItemOrder(String playlistId, List<String> itemIds) => _wrap('updatePlaylistItemOrder', () async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      var i = 0;
      for (final id in itemIds) {
        await txn.update(
          'playlist_items',
          {'sort_order': i++},
          where: 'id = ? AND playlist_id = ?',
          whereArgs: [id, playlistId],
        );
      }
      if (itemIds.isEmpty) return;
      // 未提交的条目（如媒体已软删除被详情页隐藏的）排到可见条目之后，
      // 避免与新编号的 sort_order 撞值导致恢复后顺序错乱
      final placeholders = List.filled(itemIds.length, '?').join(',');
      final rest = await txn.query(
        'playlist_items',
        columns: ['id'],
        where: 'playlist_id = ? AND id NOT IN ($placeholders)',
        whereArgs: [playlistId, ...itemIds],
        orderBy: 'sort_order ASC, added_at DESC',
      );
      for (final row in rest) {
        await txn.update(
          'playlist_items',
          {'sort_order': i++},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    });
  });

  // 批量更新片单排序
  Future<void> updatePlaylistOrder(List<String> playlistIds) => _wrap('updatePlaylistOrder', () async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (int i = 0; i < playlistIds.length; i++) {
        await txn.update(
          'playlists',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [playlistIds[i]],
        );
      }
    });
  });

  /// 从所有指定类型的片单中移除某个条目并同步 item_count。
  /// 供各媒体 DAO 在彻底删除的事务内调用（db 可传 Transaction）。
  static Future<void> removeMediaFromPlaylists(DatabaseExecutor db, String itemId, String type) async {
    final affected = await db.rawQuery(
      'SELECT DISTINCT playlist_id FROM playlist_items WHERE item_id = ? '
      'AND playlist_id IN (SELECT id FROM playlists WHERE type = ? OR type = \'all\')',
      [itemId, type],
    );
    if (affected.isEmpty) return;
    await db.rawDelete(
      'DELETE FROM playlist_items WHERE item_id = ? '
      'AND playlist_id IN (SELECT id FROM playlists WHERE type = ? OR type = \'all\')',
      [itemId, type],
    );
    final now = DateTime.now().toIso8601String();
    for (final row in affected) {
      final pid = row['playlist_id'] as String;
      await db.rawUpdate(
        'UPDATE playlists SET item_count = '
        '(SELECT COUNT(*) FROM playlist_items WHERE playlist_id = ?), '
        'updated_at = ? WHERE id = ?',
        [pid, now, pid],
      );
      // 物理删除后按"有效条目"口径再校准一次（排除其他已软删除媒体）
      await _refreshItemCount(db, pid);
    }
  }
}
