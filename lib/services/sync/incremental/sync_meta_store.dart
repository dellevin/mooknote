import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../data/database_helper.dart';

/// sync_meta 表 KV 存取
class SyncMetaStore {
  static const String manifestVersion = 'inc_manifest_v';
  static const String watermarks = 'inc_watermarks';
  static const String seenChunks = 'inc_seen_chunks';
  static const String imageMap = 'inc_image_map';
  static const String pushAfter = 'inc_push_after';
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

  static Future<int?> getInt(String key) async {
    final v = await get(key);
    return v == null ? null : int.tryParse(v);
  }

  static Future<Map<String, int>> getWatermarks() async {
    final v = await get(watermarks);
    if (v == null) return {};
    return (jsonDecode(v) as Map<String, dynamic>).map((k, e) => MapEntry(k, e as int));
  }

  static Future<void> setWatermarks(Map<String, int> marks) async {
    await set(watermarks, jsonEncode(marks));
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
}
