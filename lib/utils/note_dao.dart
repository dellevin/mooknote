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

    return List.generate(maps.length, (i) {
      return Note(
        id: maps[i]['id'].toString(),
        title: maps[i]['title'],
        content: maps[i]['content'],
        tags: maps[i]['tags'] != null 
            ? List<String>.from(maps[i]['tags'].split(',')) 
            : [],
        createdAt: DateTime.parse(maps[i]['created_at']),
        updatedAt: DateTime.parse(maps[i]['updated_at']),
      );
    });
  }

  // 添加笔记
  Future<int> insertNote(Note note) async {
    final db = await _dbHelper.database;
    return await db.insert('notes', {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'tags': note.tags.join(','),
      'created_at': note.createdAt.toIso8601String(),
      'updated_at': note.updatedAt.toIso8601String(),
    });
  }

  // 更新笔记
  Future<int> updateNote(Note note) async {
    final db = await _dbHelper.database;
    return await db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        'tags': note.tags.join(','),
        'updated_at': note.updatedAt.toIso8601String(),
      },
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
}
