import 'package:flutter/foundation.dart';
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

  // 获取单个片单
  Future<Playlist?> getPlaylistById(String id) => _wrap('getPlaylistById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'playlists',
      where: 'id = ?',
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
    // 同时删除片单内条目
    await db.delete('playlist_items', where: 'playlist_id = ?', whereArgs: [id]);
    return await db.update(
      'playlists',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final result = await db.insert('playlist_items', item.toJson());
    await _updateItemCount(item.playlistId);
    return result;
  });

  // 从片单移除条目
  Future<int> removeItem(String itemId, String playlistId) => _wrap('removeItem', () async {
    final db = await _dbHelper.database;
    final result = await db.delete(
      'playlist_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    await _updateItemCount(playlistId);
    return result;
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

  // 同步 item_count
  Future<void> _updateItemCount(String playlistId) async {
    final db = await _dbHelper.database;
    final count = (await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM playlist_items WHERE playlist_id = ?',
      [playlistId],
    )).first['cnt'] as int;
    await db.update(
      'playlists',
      {'item_count': count, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  // 批量更新片单条目排序
  Future<void> updatePlaylistItemOrder(String playlistId, List<String> itemIds) => _wrap('updatePlaylistItemOrder', () async {
    final db = await _dbHelper.database;
    for (int i = 0; i < itemIds.length; i++) {
      await db.update(
        'playlist_items',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [itemIds[i]],
      );
    }
  });

  // 批量更新片单排序
  Future<void> updatePlaylistOrder(List<String> playlistIds) => _wrap('updatePlaylistOrder', () async {
    final db = await _dbHelper.database;
    for (int i = 0; i < playlistIds.length; i++) {
      await db.update(
        'playlists',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [playlistIds[i]],
      );
    }
  });
}
