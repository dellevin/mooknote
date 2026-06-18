import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 书籍摘抄数据访问对象
class BookExcerptDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[BookExcerptDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取书籍的所有摘抄
  Future<List<BookExcerpt>> getExcerptsByBookId(String bookId) => _wrap('getExcerptsByBookId', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_excerpts',
      where: 'book_id = ? AND is_deleted = 0',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => BookExcerpt.fromJson(map)).toList();
  });

  /// 根据ID获取摘抄
  Future<BookExcerpt?> getExcerptById(String id) => _wrap('getExcerptById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_excerpts',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return BookExcerpt.fromJson(maps.first);
    return null;
  });

  /// 插入摘抄
  Future<String> insertExcerpt(BookExcerpt excerpt) => _wrap('insertExcerpt', () async {
    final db = await _dbHelper.database;
    await db.insert(
      'book_excerpts',
      excerpt.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return excerpt.id;
  });

  /// 更新摘抄
  Future<void> updateExcerpt(BookExcerpt excerpt) => _wrap('updateExcerpt', () async {
    final db = await _dbHelper.database;
    await db.update(
      'book_excerpts',
      excerpt.toJson(),
      where: 'id = ?',
      whereArgs: [excerpt.id],
    );
  });

  /// 删除摘抄（软删除）
  Future<void> deleteExcerpt(String id) => _wrap('deleteExcerpt', () async {
    final db = await _dbHelper.database;
    await db.update(
      'book_excerpts',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 彻底删除摘抄
  Future<void> permanentDeleteExcerpt(String id) => _wrap('permanentDeleteExcerpt', () async {
    final db = await _dbHelper.database;
    await db.delete(
      'book_excerpts',
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  /// 获取摘抄数量
  Future<int> getExcerptCount(String bookId) => _wrap('getExcerptCount', () async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM book_excerpts WHERE book_id = ? AND is_deleted = 0',
      [bookId],
    );
    return result.first['count'] as int? ?? 0;
  });

  /// 获取所有已删除的摘抄
  Future<List<BookExcerpt>> getDeletedExcerpts() => _wrap('getDeletedExcerpts', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'book_excerpts',
      where: 'is_deleted = 1',
      orderBy: 'updated_at DESC',
    );
    return maps.map((map) => BookExcerpt.fromJson(map)).toList();
  });

  /// 恢复已删除的摘抄
  Future<void> restoreExcerpt(String id) => _wrap('restoreExcerpt', () async {
    final db = await _dbHelper.database;
    await db.update(
      'book_excerpts',
      {'is_deleted': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  });
}
