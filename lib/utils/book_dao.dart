import 'package:sqflite/sqflite.dart';
import '../models/data_models.dart';
import 'database_helper.dart';

/// 书籍数据访问对象
class BookDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 获取所有未删除的书籍记录
  Future<List<Book>> getAllBooks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  }

  // 根据状态筛选书籍记录
  Future<List<Book>> getBooksByStatus(String status) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'status = ? AND is_deleted = ?',
      whereArgs: [status, 0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  }

  // 根据ID获取书籍
  Future<Book?> getBookById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );

    if (maps.isEmpty) return null;
    return Book.fromJson(maps.first);
  }

  // 添加书籍记录
  Future<int> insertBook(Book book) async {
    final db = await _dbHelper.database;
    return await db.insert('books', book.toJson());
  }

  // 更新书籍记录
  Future<int> updateBook(Book book) async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      book.toJson(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  // 软删除书籍记录
  Future<int> softDeleteBook(String id) async {
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
  }

  // 彻底删除书籍记录
  Future<int> deleteBook(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 搜索书籍（标题、别名）
  Future<List<Book>> searchBooks(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: '(title LIKE ? OR alternate_titles LIKE ?) AND is_deleted = ?',
      whereArgs: ['%$query%', '%$query%', 0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  }

  // 根据作者筛选
  Future<List<Book>> getBooksByAuthor(String author) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'authors LIKE ? AND is_deleted = ?',
      whereArgs: ['%$author%', 0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  }

  // 根据类型筛选
  Future<List<Book>> getBooksByGenre(String genre) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'genres LIKE ? AND is_deleted = ?',
      whereArgs: ['%$genre%', 0],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  }

  // ========== 回收站相关方法 ==========

  // 获取已删除的书籍
  Future<List<Book>> getDeletedBooks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );

    return List.generate(maps.length, (i) => Book.fromJson(maps[i]));
  }

  // 恢复已删除的书籍
  Future<int> restoreBook(String id) async {
    final db = await _dbHelper.database;
    return await db.update(
      'books',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 彻底删除书籍
  Future<int> permanentDeleteBook(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
