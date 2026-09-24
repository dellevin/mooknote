import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../data/database_helper.dart';

/// sync_meta 表 KV 存取（v2 增量同步）
class SyncMetaStore {
  static const String manifestVersion = 'inc2_manifest_v';
  static const String seenChunks = 'inc2_seen_chunks';
  static const String imageMap = 'inc2_image_map';
  static const String pushAfter = 'inc2_push_after';

  /// 已应用过的 delta 文件名集合（替代 v1 的水位/序号机制）
  static const String appliedDeltas = 'inc2_applied_deltas';

  static const String lastSync = 'inc_last_sync';

  static Future<String?> get(String key) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  static Future<void> set(String key, String value) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'sync_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> delete(String key) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sync_meta', where: 'key = ?', whereArgs: [key]);
  }

  static Future<int?> getInt(String key) async {
    final v = await get(key);
    return v == null ? null : int.tryParse(v);
  }

  static Future<Set<String>> getSeenChunks() async {
    final v = await get(seenChunks);
    if (v == null) return {};
    return (jsonDecode(v) as List).map((e) => e as String).toSet();
  }

  static Future<void> setSeenChunks(Set<String> hashes) async {
    await set(seenChunks, jsonEncode(hashes.toList()));
  }

  static Future<Map<String, String>> getImageMap() async {
    final v = await get(imageMap);
    if (v == null) return {};
    return (jsonDecode(v) as Map<String, dynamic>).map((k, e) => MapEntry(k, e as String));
  }

  static Future<void> setImageMap(Map<String, String> map) async {
    await set(imageMap, jsonEncode(map));
  }

  static Future<Set<String>> getAppliedDeltas() async {
    final v = await get(appliedDeltas);
    if (v == null) return {};
    return (jsonDecode(v) as List).map((e) => e as String).toSet();
  }

  static Future<void> setAppliedDeltas(Set<String> names) async {
    await set(appliedDeltas, jsonEncode(names.toList()));
  }
}
