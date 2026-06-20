import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class TagDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[TagDao] $op error: $e');
      rethrow;
    }
  }

  /// 获取指定类型的所有标签，按名称排序
  /// [excludeHidden] 为 true 时，过滤掉隐藏标签
  Future<List<Map<String, dynamic>>> getTagsByType(String type, {bool excludeHidden = false}) => _wrap('getTagsByType', () async {
    final db = await _dbHelper.database;
    final where = excludeHidden ? 'type = ? AND is_hidden = 0' : 'type = ?';
    return await db.query('tags',
        where: where,
        whereArgs: [type],
        orderBy: 'name ASC');
  });

  /// 根据ID获取标签
  Future<Map<String, dynamic>?> getTagById(String id) => _wrap('getTagById', () async {
    final db = await _dbHelper.database;
    final results = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  });

  /// 添加标签，返回新标签ID
  Future<String> addTag(String name, String type) => _wrap('addTag', () async {
    final db = await _dbHelper.database;
    final id = 'tag_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('tags', {
      'id': id,
      'name': name,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  });

  /// 重命名标签，同时级联更新所有关联条目（事务保护）
  Future<bool> renameTag(String tagId, String newName) => _wrap('renameTag', () async {
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

    await db.transaction((txn) async {
      await txn.update('tags', {'name': newName},
          where: 'id = ?', whereArgs: [tagId]);

      switch (type) {
        case 'movie_genre':
          await _cascadeRenameInMovies(txn, oldName, newName);
        case 'book_genre':
          await _cascadeRenameInBooks(txn, oldName, newName);
        case 'note_tag':
          await _cascadeRenameInNotes(txn, oldName, newName);
      }
    });

    return true;
  });

  /// 删除标签（事务保护）
  /// [replacementName] 不为 null 时，先将所有条目中的旧标签替换为新标签，再删除
  /// [replacementName] 为 null 时，从所有条目中移除该标签
  Future<void> deleteTag(String tagId, {String? replacementName}) => _wrap('deleteTag', () async {
    final db = await _dbHelper.database;

    final tag = await getTagById(tagId);
    if (tag == null) return;

    final name = tag['name'] as String;
    final type = tag['type'] as String;

    await db.transaction((txn) async {
      if (replacementName != null && replacementName != name) {
        await _ensureTagExists(txn, replacementName, type);
        switch (type) {
          case 'movie_genre':
            await _cascadeRenameInMovies(txn, name, replacementName);
          case 'book_genre':
            await _cascadeRenameInBooks(txn, name, replacementName);
          case 'note_tag':
            await _cascadeRenameInNotes(txn, name, replacementName);
        }
      } else if (replacementName == null) {
        switch (type) {
          case 'movie_genre':
            await _cascadeDeleteFromMovies(txn, name);
          case 'book_genre':
            await _cascadeDeleteFromBooks(txn, name);
          case 'note_tag':
            await _cascadeDeleteFromNotes(txn, name);
        }
      }

      await txn.delete('tags', where: 'id = ?', whereArgs: [tagId]);
    });
  });

  /// 仅删除标签本身，不级联影响已有条目（标签名保留在条目上）
  Future<void> deleteTagOnly(String tagId) => _wrap('deleteTagOnly', () async {
    final db = await _dbHelper.database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  });

  /// 切换标签的隐藏状态
  Future<void> toggleHidden(String tagId) => _wrap('toggleHidden', () async {
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE tags SET is_hidden = 1 - is_hidden WHERE id = ?', [tagId]);
  });

  /// 确保标签存在（用于替换操作）
  Future<void> _ensureTagExists(Transaction txn, String name, String type) async {
    final existing = await txn.query('tags',
        where: 'name = ? AND type = ?', whereArgs: [name, type]);
    if (existing.isEmpty) {
      final id = 'tag_${DateTime.now().millisecondsSinceEpoch}';
      await txn.insert('tags', {
        'id': id,
        'name': name,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ====== 级联重命名 ======

  Future<void> _cascadeRenameInMovies(Transaction txn, String oldName, String newName) async {
    final movies = await txn.query('movies',
        where: "genres LIKE ?", whereArgs: ['%$oldName%']);
    final now = DateTime.now().toIso8601String();
    for (final row in movies) {
      final genres = _parseList(row['genres']);
      if (!genres.contains(oldName)) continue;
      final updated = genres.map((g) => g == oldName ? newName : g).toList();
      await txn.update('movies', {
        'genres': jsonEncode(updated),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  Future<void> _cascadeRenameInBooks(Transaction txn, String oldName, String newName) async {
    final books = await txn.query('books',
        where: "genres LIKE ?", whereArgs: ['%$oldName%']);
    final now = DateTime.now().toIso8601String();
    for (final row in books) {
      final genres = _parseList(row['genres']);
      if (!genres.contains(oldName)) continue;
      final updated = genres.map((g) => g == oldName ? newName : g).toList();
      await txn.update('books', {
        'genres': jsonEncode(updated),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  Future<void> _cascadeRenameInNotes(Transaction txn, String oldName, String newName) async {
    final notes = await txn.query('notes',
        where: "tags LIKE ?", whereArgs: ['%$oldName%']);
    final now = DateTime.now().toIso8601String();
    for (final row in notes) {
      final tags = _parseList(row['tags']);
      if (!tags.contains(oldName)) continue;
      final updated = tags.map((t) => t == oldName ? newName : t).toList();
      await txn.update('notes', {
        'tags': jsonEncode(updated),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  // ====== 级联删除 ======

  Future<void> _cascadeDeleteFromMovies(Transaction txn, String tagName) async {
    final movies = await txn.query('movies',
        where: "genres LIKE ?", whereArgs: ['%$tagName%']);
    final now = DateTime.now().toIso8601String();
    for (final row in movies) {
      final genres = _parseList(row['genres']);
      if (!genres.contains(tagName)) continue;
      genres.removeWhere((g) => g == tagName);
      await txn.update('movies', {
        'genres': jsonEncode(genres),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  Future<void> _cascadeDeleteFromBooks(Transaction txn, String tagName) async {
    final books = await txn.query('books',
        where: "genres LIKE ?", whereArgs: ['%$tagName%']);
    final now = DateTime.now().toIso8601String();
    for (final row in books) {
      final genres = _parseList(row['genres']);
      if (!genres.contains(tagName)) continue;
      genres.removeWhere((g) => g == tagName);
      await txn.update('books', {
        'genres': jsonEncode(genres),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  Future<void> _cascadeDeleteFromNotes(Transaction txn, String tagName) async {
    final notes = await txn.query('notes',
        where: "tags LIKE ?", whereArgs: ['%$tagName%']);
    final now = DateTime.now().toIso8601String();
    for (final row in notes) {
      final tags = _parseList(row['tags']);
      if (!tags.contains(tagName)) continue;
      tags.removeWhere((t) => t == tagName);
      await txn.update('notes', {
        'tags': jsonEncode(tags),
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [row['id']]);
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
