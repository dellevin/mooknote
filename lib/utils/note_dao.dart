import 'package:sqflite/sqflite.dart';
import '../models/data_models.dart';
import 'database_helper.dart';

/// 笔记数据访问对象
class NoteDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 获取所有笔记
  Future<List<Note>> getAllNotes() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  }

  // 根据ID获取笔记
  Future<Note?> getNoteById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Note.fromJson(maps.first);
  }

  // 添加笔记
  Future<int> insertNote(Note note) async {
    final db = await _dbHelper.database;
    return await db.insert('notes', note.toJson());
  }

  // 更新笔记
  Future<int> updateNote(Note note) async {
    final db = await _dbHelper.database;
    return await db.update(
      'notes',
      note.toJson(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  // 删除笔记
  Future<int> deleteNote(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 搜索笔记
  Future<List<Note>> searchNotes(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  }

  // 根据标签筛选
  Future<List<Note>> getNotesByTag(String tag) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'tags LIKE ?',
      whereArgs: ['%$tag%'],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Note.fromJson(maps[i]));
  }
}
