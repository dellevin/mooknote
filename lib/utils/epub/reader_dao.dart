import '../database_helper.dart';

/// EPUB 阅读器数据访问层
class ReaderDao {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ─── reader_books ─────────────────────────────────────────────────

  /// 获取所有未删除的阅读记录
  Future<List<Map<String, dynamic>>> getAllReaderBooks() async {
    final db = await _db.database;
    return db.query(
      'reader_books',
      where: 'is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
  }

  /// 根据 ID 获取阅读记录
  Future<Map<String, dynamic>?> getReaderBookById(String id) async {
    final db = await _db.database;
    final results = await db.query(
      'reader_books',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// 插入阅读记录
  Future<int> insertReaderBook(Map<String, dynamic> book) async {
    final db = await _db.database;
    return db.insert('reader_books', book);
  }

  /// 更新阅读记录字段
  Future<int> updateReaderBook(String id, Map<String, dynamic> fields) async {
    final db = await _db.database;
    return db.update(
      'reader_books',
      fields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新阅读进度
  Future<int> updateReadingProgress(
      String id, String cfi, double percentage) async {
    final db = await _db.database;
    return db.update(
      'reader_books',
      {
        'last_read_cfi': cfi,
        'reading_percentage': percentage,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 软删除
  Future<int> deleteReaderBook(String id) async {
    final db = await _db.database;
    return db.update(
      'reader_books',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── 关联 books 表 ─────────────────────────────────────────────

  /// 关联 EPUB 到 books 表中的书籍
  Future<int> linkToBook(String readerBookId, String bookId) async {
    final db = await _db.database;
    return db.update(
      'reader_books',
      {'book_id': bookId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [readerBookId],
    );
  }

  /// 取消关联
  Future<int> unlinkBook(String readerBookId) async {
    final db = await _db.database;
    return db.update(
      'reader_books',
      {'book_id': '', 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [readerBookId],
    );
  }

  /// 通过 books.id 查找关联的 reader_book
  Future<Map<String, dynamic>?> getReaderBookByBookId(String bookId) async {
    final db = await _db.database;
    final results = await db.query(
      'reader_books',
      where: 'book_id = ? AND is_deleted = 0',
      whereArgs: [bookId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ─── book_annotations ─────────────────────────────────────────────

  /// 获取某本书的所有批注
  Future<List<Map<String, dynamic>>> getAnnotationsByBookId(
      String bookId) async {
    final db = await _db.database;
    return db.query(
      'book_annotations',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
  }

  /// 插入批注
  Future<int> insertAnnotation(Map<String, dynamic> annotation) async {
    final db = await _db.database;
    return db.insert('book_annotations', annotation);
  }

  /// 删除批注
  Future<int> deleteAnnotation(int id) async {
    final db = await _db.database;
    return db.delete('book_annotations', where: 'id = ?', whereArgs: [id]);
  }

  /// 更新批注感悟
  Future<int> updateAnnotationNote(int id, String note) async {
    final db = await _db.database;
    return db.update(
      'book_annotations',
      {'reader_note': note, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── highlights / annotations (epub) ──────────────────────

  /// 保存 EPUB 高亮批注
  Future<int> saveHighlight(Map<String, dynamic> annotation) async {
    final db = await _db.database;
    return db.insert('book_annotations', {
      ...annotation,
      'type': 'highlight',
    });
  }

  /// 获取某 book_id（books.id）的所有 EPUB 高亮
  Future<List<Map<String, dynamic>>> getHighlightsByBookId(
      String bookId) async {
    final db = await _db.database;
    return db.query(
      'book_annotations',
      where: 'book_id = ? AND type = ?',
      whereArgs: [bookId, 'highlight'],
      orderBy: 'created_at DESC',
    );
  }

  /// 删除高亮
  Future<int> deleteHighlight(int id) async {
    final db = await _db.database;
    return db.delete(
      'book_annotations',
      where: 'id = ? AND type = ?',
      whereArgs: [id, 'highlight'],
    );
  }

  /// 删除摘抄对应的蓝色高亮标注（通过内容匹配）
  Future<void> deleteExcerptHighlightByContent(String readerBookId, String content) async {
    final db = await _db.database;
    await db.delete(
      'book_annotations',
      where: 'book_id = ? AND content = ? AND color = ?',
      whereArgs: [readerBookId, content, 'excerpt'],
    );
  }

  // ─── bookmarks ──────────────────────────────────────────────────

  /// 获取某本书的所有书签
  Future<List<Map<String, dynamic>>> getBookmarksByBookId(String bookId) async {
    final db = await _db.database;
    return db.query(
      'book_annotations',
      where: 'book_id = ? AND type = ?',
      whereArgs: [bookId, 'bookmark'],
      orderBy: 'created_at DESC',
    );
  }

  /// 插入书签
  Future<int> insertBookmark(Map<String, dynamic> bookmark) async {
    final db = await _db.database;
    return db.insert('book_annotations', {
      ...bookmark,
      'type': 'bookmark',
    });
  }

  /// 删除书签
  Future<int> deleteBookmark(int id) async {
    final db = await _db.database;
    return db.delete('book_annotations', where: 'id = ?', whereArgs: [id]);
  }
}
