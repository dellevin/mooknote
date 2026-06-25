import 'package:flutter/foundation.dart';
import '../models/reader_book.dart';
import 'database_helper.dart';

/// 阅读器书籍 DAO
class ReaderBookDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[ReaderBookDao] $op error: $e');
      rethrow;
    }
  }

  Future<List<ReaderBook>> getAllReaderBooks() => _wrap('getAllReaderBooks', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reader_books',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => ReaderBook.fromJson(maps[i]));
  });

  Future<ReaderBook?> getReaderBookById(String id) => _wrap('getReaderBookById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reader_books',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return ReaderBook.fromJson(maps.first);
  });

  Future<void> insertReaderBook(ReaderBook book) => _wrap('insertReaderBook', () async {
    final db = await _dbHelper.database;
    await db.insert('reader_books', book.toJson());
  });

  Future<void> updateReaderBook(ReaderBook book) => _wrap('updateReaderBook', () async {
    final db = await _dbHelper.database;
    await db.update(
      'reader_books',
      book.toJson(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  });

  Future<void> deleteReaderBook(String id) => _wrap('deleteReaderBook', () async {
    final db = await _dbHelper.database;
    await db.update(
      'reader_books',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  Future<void> permanentDeleteReaderBook(String id) => _wrap('permanentDeleteReaderBook', () async {
    final db = await _dbHelper.database;
    await db.delete('reader_books', where: 'id = ?', whereArgs: [id]);
  });
}
