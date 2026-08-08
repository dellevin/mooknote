import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 书籍↔人物关联数据访问对象
class BookPersonDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[BookPersonDao] $op error: $e');
      rethrow;
    }
  }

  // 获取某本书的所有关联人物
  Future<List<BookPerson>> getByBookId(String bookId) => _wrap('getByBookId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_people',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'role_type, sort_order',
    );
    return maps.map((m) => BookPerson.fromJson(m)).toList();
  });

  // 获取某个人物参与的所有书籍关联
  Future<List<BookPerson>> getByPersonId(String personId) => _wrap('getByPersonId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_people',
      where: 'person_id = ?',
      whereArgs: [personId],
      orderBy: 'sort_order',
    );
    return maps.map((m) => BookPerson.fromJson(m)).toList();
  });

  // 添加关联
  Future<int> insert(BookPerson bookPerson) => _wrap('insert', () async {
    final db = await _dbHelper.database;
    return await db.insert('book_people', bookPerson.toJson());
  });

  // 批量添加关联
  Future<void> insertAll(List<BookPerson> items) => _wrap('insertAll', () async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    for (final item in items) {
      batch.insert('book_people', item.toJson());
    }
    await batch.commit(noResult: true);
  });

  // 删除某本书的所有关联
  Future<int> deleteByBookId(String bookId) => _wrap('deleteByBookId', () async {
    final db = await _dbHelper.database;
    return await db.delete('book_people', where: 'book_id = ?', whereArgs: [bookId]);
  });

  // 删除某个人物的所有书籍关联
  Future<int> deleteByPersonId(String personId) => _wrap('deleteByPersonId', () async {
    final db = await _dbHelper.database;
    return await db.delete('book_people', where: 'person_id = ?', whereArgs: [personId]);
  });

  // 删除单条关联
  Future<int> deleteById(String id) => _wrap('deleteById', () async {
    final db = await _dbHelper.database;
    return await db.delete('book_people', where: 'id = ?', whereArgs: [id]);
  });

  // 检查关联是否已存在（避免重复插入）
  Future<bool> existsRelation(String bookId, String personId, String roleType) => _wrap('existsRelation', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_people',
      where: 'book_id = ? AND person_id = ? AND role_type = ?',
      whereArgs: [bookId, personId, roleType],
      limit: 1,
    );
    return maps.isNotEmpty;
  });
}
