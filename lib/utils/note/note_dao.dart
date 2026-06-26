import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 笔记数据访问对象
class NoteDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[NoteDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有未删除的笔记
  Future<List<Note>> getAllNotes({int sortMode = 0}) => _wrap('getAllNotes', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: _buildOrderBy(sortMode),
    );
    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  });

  // 分页查询笔记
  Future<List<Note>> getNotesPaged({int limit = 20, int offset = 0, int sortMode = 0}) => _wrap('getNotesPaged', () async {
    final db = await _dbHelper.database;
    final maps = await db.query('notes', where: 'is_deleted = 0',
        orderBy: _buildOrderBy(sortMode), limit: limit, offset: offset);
    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  });

  /// 根据排序模式生成 ORDER BY 子句，置顶始终排最前
  static String _buildOrderBy(int sortMode) {
    switch (sortMode) {
      case 1: return 'is_pinned DESC, created_at DESC';
      case 2: return 'is_pinned DESC, title COLLATE NOCASE ASC';
      default: return 'is_pinned DESC, updated_at DESC';
    }
  }

  // 根据ID获取笔记
  Future<Note?> getNoteById(String id) => _wrap('getNoteById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Note.fromJson(maps.first);
  });

  // 添加笔记
  Future<int> insertNote(Note note) => _wrap('insertNote', () async {
    final db = await _dbHelper.database;
    return await db.insert('notes', note.toJson());
  });

  // 更新笔记
  Future<int> updateNote(Note note) => _wrap('updateNote', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'notes',
      note.toJson(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  });

  // 软删除笔记
  Future<int> deleteNote(String id) => _wrap('deleteNote', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'notes',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 切换笔记置顶状态
  Future<int> togglePin(String id, bool isPinned) => _wrap('togglePin', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'notes',
      {'is_pinned': isPinned ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // ========== 回收站相关方法 ==========

  // 获取已删除的笔记
  Future<List<Note>> getDeletedNotes() => _wrap('getDeletedNotes', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  });

  // 恢复已删除的笔记
  Future<int> restoreNote(String id) => _wrap('restoreNote', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'notes',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 彻底删除笔记
  Future<int> permanentDeleteNote(String id) => _wrap('permanentDeleteNote', () async {
    final db = await _dbHelper.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 搜索笔记
  Future<List<Note>> searchNotes(String query) => _wrap('searchNotes', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: '(title LIKE ? OR content LIKE ? OR tags LIKE ?) AND is_deleted = ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  });

  // 根据标签筛选
  Future<List<Note>> getNotesByTag(String tag) => _wrap('getNotesByTag', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'tags LIKE ? AND is_deleted = ?',
      whereArgs: ['%$tag%', 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  });
}
