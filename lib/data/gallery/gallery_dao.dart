import 'package:flutter/foundation.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 图库数据访问对象 —— 聚合所有实体的图片
class GalleryDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[GalleryDao] $op error: $e');
      rethrow;
    }
  }

  DateTime _parseDate(String? str) {
    if (str == null || str.isEmpty) return DateTime.now();
    return DateTime.tryParse(str)?.toLocal() ?? DateTime.now();
  }

  /// 获取所有图片（过滤软删除与空路径），按创建时间倒序
  Future<List<GalleryItem>> getAllImages() => _wrap('getAllImages', () async {
    final db = await _dbHelper.database;
    final items = <GalleryItem>[];

    // 1. 影视海报（movies.poster_path）
    final movieMaps = await db.query(
      'movies',
      columns: ['id', 'title', 'poster_path', 'created_at'],
      where: 'is_deleted = ? AND poster_path IS NOT NULL AND poster_path != ?',
      whereArgs: [0, ''],
    );
    for (final m in movieMaps) {
      items.add(GalleryItem(
        path: m['poster_path'] as String,
        category: 'movie_poster',
        entityType: 'movie',
        entityId: m['id'] as String,
        entityTitle: (m['title'] as String?) ?? '',
        createdAt: _parseDate(m['created_at'] as String?),
      ));
    }

    // 2. 影视海报墙（movie_posters JOIN movies）
    final posterMaps = await db.rawQuery(
      "SELECT p.poster_path, p.created_at, p.movie_id, m.title AS parent_title "
      "FROM movie_posters p INNER JOIN movies m ON p.movie_id = m.id "
      "WHERE p.is_deleted = ? AND m.is_deleted = ? "
      "AND p.poster_path IS NOT NULL AND p.poster_path != ?",
      [0, 0, ''],
    );
    for (final p in posterMaps) {
      items.add(GalleryItem(
        path: p['poster_path'] as String,
        category: 'movie_posters',
        entityType: 'movie',
        entityId: p['movie_id'] as String,
        entityTitle: (p['parent_title'] as String?) ?? '',
        createdAt: _parseDate(p['created_at'] as String?),
      ));
    }

    // 3. 书籍封面（books.cover_path）
    final bookMaps = await db.query(
      'books',
      columns: ['id', 'title', 'cover_path', 'created_at'],
      where: 'is_deleted = ? AND cover_path IS NOT NULL AND cover_path != ?',
      whereArgs: [0, ''],
    );
    for (final b in bookMaps) {
      items.add(GalleryItem(
        path: b['cover_path'] as String,
        category: 'book_cover',
        entityType: 'book',
        entityId: b['id'] as String,
        entityTitle: (b['title'] as String?) ?? '',
        createdAt: _parseDate(b['created_at'] as String?),
      ));
    }

    // 4. 笔记图片（notes.images JSON 数组）
    final noteMaps = await db.query(
      'notes',
      columns: ['id', 'title', 'images', 'created_at'],
      where: 'is_deleted = ? AND images IS NOT NULL AND images != ?',
      whereArgs: [0, ''],
    );
    for (final n in noteMaps) {
      final paths = parseStringListGeneric(n['images']);
      final title = (n['title'] as String?) ?? '';
      final created = _parseDate(n['created_at'] as String?);
      for (final imgPath in paths) {
        if (imgPath.isEmpty) continue;
        items.add(GalleryItem(
          path: imgPath,
          category: 'note_image',
          entityType: 'note',
          entityId: n['id'] as String,
          entityTitle: title,
          createdAt: created,
        ));
      }
    }

    // 5. 游戏封面（games.cover_path）
    final gameMaps = await db.query(
      'games',
      columns: ['id', 'title', 'cover_path', 'created_at'],
      where: 'is_deleted = ? AND cover_path IS NOT NULL AND cover_path != ?',
      whereArgs: [0, ''],
    );
    for (final g in gameMaps) {
      items.add(GalleryItem(
        path: g['cover_path'] as String,
        category: 'game_cover',
        entityType: 'game',
        entityId: g['id'] as String,
        entityTitle: (g['title'] as String?) ?? '',
        createdAt: _parseDate(g['created_at'] as String?),
      ));
    }

    // 6. 游戏截图（game_screenshots JOIN games）
    final shotMaps = await db.rawQuery(
      "SELECT s.screenshot_path, s.created_at, s.game_id, g.title AS parent_title "
      "FROM game_screenshots s INNER JOIN games g ON s.game_id = g.id "
      "WHERE s.is_deleted = ? AND g.is_deleted = ? "
      "AND s.screenshot_path IS NOT NULL AND s.screenshot_path != ?",
      [0, 0, ''],
    );
    for (final s in shotMaps) {
      items.add(GalleryItem(
        path: s['screenshot_path'] as String,
        category: 'game_screenshot',
        entityType: 'game',
        entityId: s['game_id'] as String,
        entityTitle: (s['parent_title'] as String?) ?? '',
        createdAt: _parseDate(s['created_at'] as String?),
      ));
    }

    // 7. 人物照片（people.photo_path）
    final personMaps = await db.query(
      'people',
      columns: ['id', 'name', 'photo_path', 'created_at'],
      where: 'is_deleted = ? AND photo_path IS NOT NULL AND photo_path != ?',
      whereArgs: [0, ''],
    );
    for (final p in personMaps) {
      items.add(GalleryItem(
        path: p['photo_path'] as String,
        category: 'person_photo',
        entityType: 'person',
        entityId: p['id'] as String,
        entityTitle: (p['name'] as String?) ?? '',
        createdAt: _parseDate(p['created_at'] as String?),
      ));
    }

    // 8. 角色图片（movie/book/game_characters JOIN 父表）
    final charMovieMaps = await db.rawQuery(
      "SELECT c.image_path, c.name, c.movie_id, c.created_at, m.title AS parent_title "
      "FROM movie_characters c INNER JOIN movies m ON c.movie_id = m.id "
      "WHERE c.is_deleted = ? AND m.is_deleted = ? "
      "AND c.image_path IS NOT NULL AND c.image_path != ?",
      [0, 0, ''],
    );
    for (final c in charMovieMaps) {
      items.add(GalleryItem(
        path: c['image_path'] as String,
        category: 'movie_character',
        entityType: 'movie',
        entityId: c['movie_id'] as String,
        entityTitle: (c['name'] as String?) ?? '',
        parentTitle: (c['parent_title'] as String?) ?? '',
        createdAt: _parseDate(c['created_at'] as String?),
      ));
    }

    final charBookMaps = await db.rawQuery(
      "SELECT c.image_path, c.name, c.book_id, c.created_at, b.title AS parent_title "
      "FROM book_characters c INNER JOIN books b ON c.book_id = b.id "
      "WHERE c.is_deleted = ? AND b.is_deleted = ? "
      "AND c.image_path IS NOT NULL AND c.image_path != ?",
      [0, 0, ''],
    );
    for (final c in charBookMaps) {
      items.add(GalleryItem(
        path: c['image_path'] as String,
        category: 'book_character',
        entityType: 'book',
        entityId: c['book_id'] as String,
        entityTitle: (c['name'] as String?) ?? '',
        parentTitle: (c['parent_title'] as String?) ?? '',
        createdAt: _parseDate(c['created_at'] as String?),
      ));
    }

    final charGameMaps = await db.rawQuery(
      "SELECT c.image_path, c.name, c.game_id, c.created_at, g.title AS parent_title "
      "FROM game_characters c INNER JOIN games g ON c.game_id = g.id "
      "WHERE c.is_deleted = ? AND g.is_deleted = ? "
      "AND c.image_path IS NOT NULL AND c.image_path != ?",
      [0, 0, ''],
    );
    for (final c in charGameMaps) {
      items.add(GalleryItem(
        path: c['image_path'] as String,
        category: 'game_character',
        entityType: 'game',
        entityId: c['game_id'] as String,
        entityTitle: (c['name'] as String?) ?? '',
        parentTitle: (c['parent_title'] as String?) ?? '',
        createdAt: _parseDate(c['created_at'] as String?),
      ));
    }

    // 按创建时间倒序
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  });
}
