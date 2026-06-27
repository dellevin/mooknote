import 'package:sqflite/sqflite.dart';
import '../../models/book_annotation.dart';
import '../database_helper.dart';

/// 书籍批注数据访问对象
class BookAnnotationDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Database> get _db async => await _dbHelper.database;

  /// 插入批注，返回插入的 id
  Future<int> insert(BookAnnotation annotation) async {
    final db = await _db;
    return await db.insert('book_annotations', annotation.toMap()..remove('id'));
  }

  /// 更新批注
  Future<void> update(BookAnnotation annotation) async {
    final db = await _db;
    await db.update(
      'book_annotations',
      annotation.toMap(),
      where: 'id = ?',
      whereArgs: [annotation.id],
    );
  }

  /// 保存（有 id 则更新，无 id 则插入）
  Future<BookAnnotation> save(BookAnnotation annotation) async {
    if (annotation.id != null) {
      await update(annotation);
      return annotation;
    }
    final id = await insert(annotation);
    return annotation.copyWith(id: id);
  }

  /// 根据 id 删除
  Future<void> deleteById(int id) async {
    final db = await _db;
    await db.delete('book_annotations', where: 'id = ?', whereArgs: [id]);
  }

  /// 根据 CFI 删除（用于删除高亮/下划线）
  Future<void> deleteByCfi(String bookId, String cfi) async {
    final db = await _db;
    await db.delete(
      'book_annotations',
      where: 'book_id = ? AND cfi = ?',
      whereArgs: [bookId, cfi],
    );
  }

  /// 查询某本书的所有批注
  Future<List<BookAnnotation>> getByBookId(String bookId) async {
    final db = await _db;
    final maps = await db.query(
      'book_annotations',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => BookAnnotation.fromMap(m)).toList();
  }

  /// 查询某本书的某种类型批注
  Future<List<BookAnnotation>> getByBookIdAndType(String bookId, String type) async {
    final db = await _db;
    final maps = await db.query(
      'book_annotations',
      where: 'book_id = ? AND type = ?',
      whereArgs: [bookId, type],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => BookAnnotation.fromMap(m)).toList();
  }

  /// 查询某本书的所有书签
  Future<List<BookAnnotation>> getBookmarks(String bookId) async {
    return getByBookIdAndType(bookId, 'bookmark');
  }

  /// 查询某本书的所有高亮/下划线
  Future<List<BookAnnotation>> getAnnotations(String bookId) async {
    final db = await _db;
    final maps = await db.query(
      'book_annotations',
      where: "book_id = ? AND type IN ('highlight', 'underline')",
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => BookAnnotation.fromMap(m)).toList();
  }

  /// 根据 id 查询
  Future<BookAnnotation?> getById(int id) async {
    final db = await _db;
    final maps = await db.query(
      'book_annotations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return BookAnnotation.fromMap(maps.first);
  }

  /// 获取某本书的批注数量
  Future<int> getCount(String bookId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM book_annotations WHERE book_id = ?',
      [bookId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
