import 'package:sqflite/sqflite.dart';
import '../models/data_models.dart';
import 'database_helper.dart';

/// 书籍数据访问对象
class BookDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // 获取所有书籍记录
  Future<List<Book>> getAllBooks() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('books');

    return List.generate(maps.length, (i) {
      return Book(
        id: maps[i]['id'].toString(),
        title: maps[i]['title'],
        author: maps[i]['author'],
        cover: maps[i]['cover'],
        rating: maps[i]['rating']?.toDouble(),
        status: maps[i]['status'],
        readDate: maps[i]['read_date'] != null 
            ? DateTime.parse(maps[i]['read_date']) 
            : null,
        note: maps[i]['note'],
      );
    });
  }

  // 根据状态筛选书籍记录
  Future<List<Book>> getBooksByStatus(String status) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'books',
      where: 'status = ?',
      whereArgs: [status],
    );

    return List.generate(maps.length, (i) {
      return Book(
        id: maps[i]['id'].toString(),
        title: maps[i]['title'],
        author: maps[i]['author'],
        cover: maps[i]['cover'],
        rating: maps[i]['rating']?.toDouble(),
        status: maps[i]['status'],
        readDate: maps[i]['read_date'] != null 
            ? DateTime.parse(maps[i]['read_date']) 
            : null,
        note: maps[i]['note'],
      );
    });
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

  // 删除书籍记录
  Future<int> deleteBook(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
