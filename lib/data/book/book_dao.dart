import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 书籍数据访问对象
class BookDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[BookDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有未删除的书籍记录
  Future<List<Book>> getAllBooks() => _wrap('getAllBooks', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  // 分页查询书籍记录
  Future<List<Book>> getBooksPaged({String? status, int limit = 20, int offset = 0, int sortMode = 0}) => _wrap('getBooksPaged', () async {
    final db = await _dbHelper.database;
    String where = 'is_deleted = 0';
    List<dynamic> whereArgs = [];
    if (status != null && status.isNotEmpty) {
      where += ' AND status = ?';
      whereArgs.add(status);
    }
    final maps = await db.query('books', where: where, whereArgs: whereArgs,
        orderBy: _buildBookOrderBy(sortMode), limit: limit, offset: offset);
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  static String _buildBookOrderBy(int sortMode) {
    switch (sortMode) {
      case 1: return 'created_at DESC';
      case 2: return 'rating DESC NULLS LAST, updated_at DESC';
      default: return 'created_at DESC';
    }
  }

  // 根据状态筛选书籍记录
  Future<List<Book>> getBooksByStatus(String status) => _wrap('getBooksByStatus', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'status = ? AND is_deleted = ?',
      whereArgs: [status, 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  // 根据ID获取书籍
  Future<Book?> getBookById(String id) => _wrap('getBookById', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Book.fromJson(maps.first);
  });

  // 添加书籍记录
  Future<int> insertBook(Book book) => _wrap('insertBook', () async {
    final db = await _dbHelper.database;
    return await db.insert('books', book.toJson());
  });

  // 更新书籍记录
  Future<int> updateBook(Book book) => _wrap('updateBook', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      book.toJson(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  });

  // 仅更新封面偏移量（不触发全量刷新）
  Future<void> updateCoverOffset(String bookId, double offset) => _wrap('updateCoverOffset', () async {
    final db = await _dbHelper.database;
    await db.update('books', {'cover_offset': offset}, where: 'id = ?', whereArgs: [bookId]);
  });

  // 软删除书籍记录（移入回收站）
  Future<int> deleteBook(String id) => _wrap('deleteBook', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 搜索书籍（标题、别名）
  Future<List<Book>> searchBooks(String query) => _wrap('searchBooks', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: '(title LIKE ? OR alternate_titles LIKE ?) AND is_deleted = ?',
      whereArgs: ['%$query%', '%$query%', 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  // 根据作者筛选
  Future<List<Book>> getBooksByAuthor(String author) => _wrap('getBooksByAuthor', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'authors LIKE ? AND is_deleted = ?',
      whereArgs: ['%$author%', 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  // 根据类型筛选
  Future<List<Book>> getBooksByGenre(String genre) => _wrap('getBooksByGenre', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'genres LIKE ? AND is_deleted = ?',
      whereArgs: ['%$genre%', 0],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  // ========== 回收站相关方法 ==========

  // 获取已删除的书籍
  Future<List<Book>> getDeletedBooks() => _wrap('getDeletedBooks', () async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  });

  // 恢复已删除的书籍
  Future<int> restoreBook(String id) => _wrap('restoreBook', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 彻底删除书籍
  Future<int> permanentDeleteBook(String id) => _wrap('permanentDeleteBook', () async {
    final db = await _dbHelper.database;
    // 清理子记录，防止孤儿数据
    await db.delete('book_reviews', where: 'book_id = ?', whereArgs: [id]);
    await db.delete('book_excerpts', where: 'book_id = ?', whereArgs: [id]);
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
