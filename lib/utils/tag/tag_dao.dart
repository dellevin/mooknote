import 'dart:convert';
import '../database_helper.dart';

class TagDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// 获取指定类型的所有标签，按名称排序
  Future<List<Map<String, dynamic>>> getTagsByType(String type) async {
    final db = await _dbHelper.database;
    return await db.query('tags',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'name ASC');
  }

  /// 根据ID获取标签
  Future<Map<String, dynamic>?> getTagById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  /// 添加标签，返回新标签ID
  Future<String> addTag(String name, String type) async {
    final db = await _dbHelper.database;
    final id = 'tag_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('tags', {
      'id': id,
      'name': name,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  /// 重命名标签，同时级联更新所有关联条目
  Future<bool> renameTag(String tagId, String newName) async {
    final db = await _dbHelper.database;

    final tag = await getTagById(tagId);
    if (tag == null) return false;

    final oldName = tag['name'] as String;
    final type = tag['type'] as String;
    if (oldName == newName) return true;

    // 检查新名称是否已存在同类型标签
    final existing = await db.query('tags',
        where: 'name = ? AND type = ? AND id != ?',
        whereArgs: [newName, type, tagId]);
    if (existing.isNotEmpty) return false;

    await db.update('tags', {'name': newName},
        where: 'id = ?', whereArgs: [tagId]);

    // 级联更新
    switch (type) {
      case 'movie_genre':
        await _cascadeRenameInMovies(oldName, newName);
      case 'book_genre':
        await _cascadeRenameInBooks(oldName, newName);
      case 'note_tag':
        await _cascadeRenameInNotes(oldName, newName);
    }

    return true;
  }

  /// 删除标签
  /// [replacementName] 不为 null 时，先将所有条目中的旧标签替换为新标签，再删除
  /// [replacementName] 为 null 时，从所有条目中移除该标签
  Future<void> deleteTag(String tagId, {String? replacementName}) async {
    final db = await _dbHelper.database;

    final tag = await getTagById(tagId);
    if (tag == null) return;

    final name = tag['name'] as String;
    final type = tag['type'] as String;

    if (replacementName != null && replacementName != name) {
      await _ensureTagExists(replacementName, type);
      switch (type) {
        case 'movie_genre':
          await _cascadeRenameInMovies(name, replacementName);
        case 'book_genre':
          await _cascadeRenameInBooks(name, replacementName);
        case 'note_tag':
          await _cascadeRenameInNotes(name, replacementName);
      }
    } else if (replacementName == null) {
      switch (type) {
        case 'movie_genre':
          await _cascadeDeleteFromMovies(name);
        case 'book_genre':
          await _cascadeDeleteFromBooks(name);
        case 'note_tag':
          await _cascadeDeleteFromNotes(name);
      }
    }

    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  /// 确保标签存在（用于替换操作）
  Future<void> _ensureTagExists(String name, String type) async {
    final db = await _dbHelper.database;
    final existing = await db.query('tags',
        where: 'name = ? AND type = ?', whereArgs: [name, type]);
    if (existing.isEmpty) {
      await addTag(name, type);
    }
  }

  // ====== 级联重命名 ======

  Future<void> _cascadeRenameInMovies(String oldName, String newName) async {
    final db = await _dbHelper.database;
    final movies = await db.query('movies');
    for (final row in movies) {
      final genres = _parseList(row['genres']);
      if (genres.contains(oldName) && !genres.contains(newName)) {
        final updated = genres.map((g) => g == oldName ? newName : g).toList();
        await db.update('movies', {
          'genres': jsonEncode(updated),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Future<void> _cascadeRenameInBooks(String oldName, String newName) async {
    final db = await _dbHelper.database;
    final books = await db.query('books');
    for (final row in books) {
      final genres = _parseList(row['genres']);
      if (genres.contains(oldName) && !genres.contains(newName)) {
        final updated = genres.map((g) => g == oldName ? newName : g).toList();
        await db.update('books', {
          'genres': jsonEncode(updated),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Future<void> _cascadeRenameInNotes(String oldName, String newName) async {
    final db = await _dbHelper.database;
    final notes = await db.query('notes');
    for (final row in notes) {
      final tags = _parseList(row['tags']);
      if (tags.contains(oldName) && !tags.contains(newName)) {
        final updated = tags.map((t) => t == oldName ? newName : t).toList();
        await db.update('notes', {
          'tags': jsonEncode(updated),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  // ====== 级联删除 ======

  Future<void> _cascadeDeleteFromMovies(String tagName) async {
    final db = await _dbHelper.database;
    final movies = await db.query('movies');
    for (final row in movies) {
      final genres = _parseList(row['genres']);
      if (genres.contains(tagName)) {
        genres.removeWhere((g) => g == tagName);
        await db.update('movies', {
          'genres': jsonEncode(genres),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Future<void> _cascadeDeleteFromBooks(String tagName) async {
    final db = await _dbHelper.database;
    final books = await db.query('books');
    for (final row in books) {
      final genres = _parseList(row['genres']);
      if (genres.contains(tagName)) {
        genres.removeWhere((g) => g == tagName);
        await db.update('books', {
          'genres': jsonEncode(genres),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  Future<void> _cascadeDeleteFromNotes(String tagName) async {
    final db = await _dbHelper.database;
    final notes = await db.query('notes');
    for (final row in notes) {
      final tags = _parseList(row['tags']);
      if (tags.contains(tagName)) {
        tags.removeWhere((t) => t == tagName);
        await db.update('notes', {
          'tags': jsonEncode(tags),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  /// 解析 JSON 字符串列表
  List<String> _parseList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data.map((e) => e.toString()).toList();
    if (data is String) {
      if (data.isEmpty || data == '[]') return [];
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return data.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }
    return [];
  }
}
