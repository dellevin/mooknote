import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/data_models.dart';
import '../database_helper.dart';

/// 人物数据访问对象
class PersonDao {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<T> _wrap<T>(String op, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      debugPrint('[PersonDao] $op error: $e');
      rethrow;
    }
  }

  // 获取所有人物（未删除的）
  Future<List<Person>> getAllPeople() => _wrap('getAllPeople', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'people',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Person.fromJson(m)).toList();
  });

  // 搜索人物（名称或别名）
  Future<List<Person>> searchPeople(String keyword) => _wrap('searchPeople', () async {
    final db = await _dbHelper.database;
    final like = '%$keyword%';
    final maps = await db.query(
      'people',
      where: '(name LIKE ? OR alternate_names LIKE ?) AND is_deleted = ?',
      whereArgs: [like, like, 0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Person.fromJson(m)).toList();
  });

  // 按职业筛选
  Future<List<Person>> getPeopleByOccupation(String occupation) => _wrap('getPeopleByOccupation', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'people',
      where: 'occupation LIKE ? AND is_deleted = ?',
      whereArgs: ['%$occupation%', 0],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Person.fromJson(m))
        .where((p) => p.occupation.contains(occupation))
        .toList();
  });

  // 根据名称精确查找人物（未删除）
  Future<Person?> getPersonByName(String name) => _wrap('getPersonByName', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'people',
      where: 'name = ? AND is_deleted = ?',
      whereArgs: [name, 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Person.fromJson(maps.first);
  });

  // 根据ID获取人物
  Future<Person?> getPersonById(String id) => _wrap('getPersonById', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'people',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Person.fromJson(maps.first);
  });

  // 添加人物
  Future<int> insertPerson(Person person) => _wrap('insertPerson', () async {
    final db = await _dbHelper.database;
    return await db.insert('people', person.toJson());
  });

  // 更新人物
  Future<int> updatePerson(Person person) => _wrap('updatePerson', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'people',
      person.toJson(),
      where: 'id = ?',
      whereArgs: [person.id],
    );
  });

  // 仅更新封面偏移量
  Future<void> updateCoverOffset(String personId, double offset) => _wrap('updateCoverOffset', () async {
    final db = await _dbHelper.database;
    await db.update('people', {'cover_offset': offset}, where: 'id = ?', whereArgs: [personId]);
  });

  // 软删除人物
  Future<int> deletePerson(String id) => _wrap('deletePerson', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'people',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 恢复已删除的人物
  Future<int> restorePerson(String id) => _wrap('restorePerson', () async {
    final db = await _dbHelper.database;
    return await db.update(
      'people',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  // 获取已删除的人物
  Future<List<Person>> getDeletedPeople() => _wrap('getDeletedPeople', () async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'people',
      where: 'is_deleted = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Person.fromJson(m)).toList();
  });

  // 彻底删除人物
  Future<int> permanentDeletePerson(String id) => _wrap('permanentDeletePerson', () async {
    final db = await _dbHelper.database;
    // 清理关联记录
    await db.delete('movie_people', where: 'person_id = ?', whereArgs: [id]);
    await db.delete('book_people', where: 'person_id = ?', whereArgs: [id]);
    await db.delete('game_people', where: 'person_id = ?', whereArgs: [id]);
    return await db.delete('people', where: 'id = ?', whereArgs: [id]);
  });

  /// 合并同名人物：每个名字组保留信息最全的一条，迁移关联并去重，删除冗余。
  /// 返回被删除的冗余人物数量。
  Future<int> mergeDuplicatePeople() => _wrap('mergeDuplicatePeople', () async {
    final db = await _dbHelper.database;
    // 取所有人物（含已删除），按 name 分组
    final maps = await db.query('people', orderBy: 'updated_at DESC');
    final byName = <String, List<Map<String, Object?>>>{};
    for (final m in maps) {
      final name = (m['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      byName.putIfAbsent(name, () => []).add(m);
    }

    int removed = 0;
    final now = DateTime.now().toUtc().toIso8601String();

    for (final entry in byName.entries) {
      final group = entry.value;
      if (group.length < 2) continue;

      // 选保留者：优先未删除的、updated_at 最新的；信息更全的优先
      group.sort((a, b) {
        final aDel = (a['is_deleted'] as int?) == 1;
        final bDel = (b['is_deleted'] as int?) == 1;
        if (aDel != bDel) return aDel ? 1 : -1; // 未删除的排前
        final aScore = _infoScore(a);
        final bScore = _infoScore(b);
        if (aScore != bScore) return bScore - aScore; // 信息多的排前
        return 0;
      });
      final keeperRow = group.first;
      final keeperId = keeperRow['id'] as String;
      final dupes = group.skip(1).toList();

      // 合并字段到 keeper
      final merged = Map<String, Object?>.from(keeperRow);
      for (final dupe in dupes) {
        _mergeFieldsInto(merged, dupe);
      }
      merged['updated_at'] = now;
      await db.update('people', merged, where: 'id = ?', whereArgs: [keeperId]);

      // 迁移关联并去重
      for (final dupe in dupes) {
        final dupeId = dupe['id'] as String;
        await _migrateRelations(db, dupeId, keeperId, 'movie_people', 'movie_id');
        await _migrateRelations(db, dupeId, keeperId, 'book_people', 'book_id');
        await _migrateRelations(db, dupeId, keeperId, 'game_people', 'game_id');
        // 删除冗余人物
        await db.delete('people', where: 'id = ?', whereArgs: [dupeId]);
        removed++;
      }
    }
    return removed;
  });

  // 信息完整度评分（非空字段越多分越高）
  int _infoScore(Map<String, Object?> row) {
    int score = 0;
    if ((row['photo_path'] as String?)?.isNotEmpty == true) score += 5;
    if ((row['summary'] as String?)?.isNotEmpty == true) score += 3;
    if ((row['gender'] as String?)?.isNotEmpty == true) score += 1;
    if ((row['birth_date'] as String?)?.isNotEmpty == true) score += 1;
    if ((row['birth_place'] as String?)?.isNotEmpty == true) score += 1;
    final alt = (row['alternate_names'] as String?) ?? '';
    if (alt.isNotEmpty && alt != '[]') score += 1;
    final occ = (row['occupation'] as String?) ?? '';
    if (occ.isNotEmpty && occ != '[]') score += 1;
    return score;
  }

  // 把 dupe 的非空字段并进 merged（merged 已有的非空值不覆盖）
  void _mergeFieldsInto(Map<String, Object?> merged, Map<String, Object?> dupe) {
    void mergeField(String key) {
      final cur = merged[key];
      final curEmpty = cur == null || (cur is String && cur.isEmpty);
      final dup = dupe[key];
      final dupEmpty = dup == null || (dup is String && dup.isEmpty);
      if (curEmpty && !dupEmpty) merged[key] = dup;
    }
    mergeField('photo_path');
    mergeField('summary');
    mergeField('gender');
    mergeField('birth_date');
    mergeField('birth_place');

    // 列表字段取并集
    merged['alternate_names'] = _unionListJson(merged['alternate_names'], dupe['alternate_names']);
    merged['occupation'] = _unionListJson(merged['occupation'], dupe['occupation']);
  }

  String _unionListJson(Object? a, Object? b) {
    final set = <String>{};
    for (final raw in [a, b]) {
      if (raw == null) continue;
      final s = raw.toString();
      if (s.isEmpty || s == '[]') continue;
      try {
        final list = jsonDecode(s);
        if (list is List) {
          for (final e in list) {
            if (e != null) set.add(e.toString());
          }
        }
      } catch (_) {}
    }
    return jsonEncode(set.toList());
  }

  // 把 fromPersonId 的关联迁移到 toPersonId，按 (work_id, role_type) 去重
  Future<void> _migrateRelations(
    Database db,
    String fromPersonId,
    String toPersonId,
    String table,
    String workIdCol,
  ) async {
    // 取 dupe 的所有关联
    final dupeRows = await db.query(
      table,
      columns: [workIdCol, 'role_type'],
      where: 'person_id = ?',
      whereArgs: [fromPersonId],
    );
    // 取 keeper 已有的关联键集合
    final keeperRows = await db.query(
      table,
      columns: [workIdCol, 'role_type'],
      where: 'person_id = ?',
      whereArgs: [toPersonId],
    );
    final keeperKeys = <String>{};
    for (final r in keeperRows) {
      keeperKeys.add('${r[workIdCol]}|${r['role_type']}');
    }
    // 把不与 keeper 冲突的关联改指向 keeper
    for (final r in dupeRows) {
      final key = '${r[workIdCol]}|${r['role_type']}';
      if (keeperKeys.contains(key)) continue;
      await db.update(
        table,
        {'person_id': toPersonId},
        where: 'person_id = ? AND $workIdCol = ? AND role_type = ?',
        whereArgs: [fromPersonId, r[workIdCol], r['role_type']],
      );
      keeperKeys.add(key);
    }
    // 删除剩余的（与 keeper 冲突的）关联
    await db.delete(table, where: 'person_id = ?', whereArgs: [fromPersonId]);
  }

  // 获取所有人物名称（去重，供选择器使用）
  Future<List<String>> getAllPersonNames() => _wrap('getAllPersonNames', () async {
    final people = await getAllPeople();
    final names = <String>{};
    for (final p in people) {
      names.add(p.name);
      names.addAll(p.alternateNames);
    }
    return names.toList()..sort();
  });
}
