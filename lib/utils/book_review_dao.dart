import 'package:sqflite/sqflite.dart';
import '../models/data_models.dart';
import 'database_helper.dart';

/// 书评数据访问对象
class BookReviewDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 获取书籍的所有书评
  Future<List<BookReview>> getReviewsByBookId(String bookId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_reviews',
      where: 'book_id = ? AND is_deleted = 0',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => BookReview.fromJson(map)).toList();
  }

  /// 根据ID获取书评
  Future<BookReview?> getReviewById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_reviews',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return BookReview.fromJson(maps.first);
    }
    return null;
  }

  /// 插入书评
  Future<String> insertReview(BookReview review) async {
    final db = await _dbHelper.database;
    await db.insert(
      'book_reviews',
      review.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return review.id;
  }

  /// 更新书评
  Future<void> updateReview(BookReview review) async {
    final db = await _dbHelper.database;
    await db.update(
      'book_reviews',
      review.toJson(),
      where: 'id = ?',
      whereArgs: [review.id],
    );
  }

  /// 删除书评（软删除）
  Future<void> deleteReview(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'book_reviews',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 彻底删除书评
  Future<void> permanentDeleteReview(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'book_reviews',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取书评数量
  Future<int> getReviewCount(String bookId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM book_reviews WHERE book_id = ? AND is_deleted = 0',
      [bookId],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// 获取所有已删除的书评
  Future<List<BookReview>> getDeletedReviews() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_reviews',
      where: 'is_deleted = 1',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => BookReview.fromJson(map)).toList();
  }

  /// 恢复已删除的书评
  Future<void> restoreReview(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'book_reviews',
      {'is_deleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
