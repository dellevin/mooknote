import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../../data/database_helper.dart';
import 'inc_entities.dart';
import 'inc_protocol.dart';
import 'inc_remote.dart';
import 'inc_row_codec.dart';

/// manifest 构建：首次基线与 compaction 共用
class IncManifestBuilder {
  static const int _chunkSize = 250;

  /// 从本地全量数据构建 manifest。
  /// [imageMap] 为已知图片映射：首建为空（现场扫描+上传），压实时传入合并后的映射。
  static Future<Manifest> buildFromLocal({
    required IncRemote remote,
    required IncRowCodec codec,
    required int version,
    required String clientId,
    required Map<String, int> folded,
    required Map<String, String> imageMap,
  }) async {
    final chunks = <String, List<ChunkIndex>>{};
    final images = Map<String, String>.from(imageMap);

    for (final spec in IncEntities.entities) {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(spec.table);
      final index = <ChunkIndex>[];

      // 预取该实体全部子组行，按父 id 分桶
      final groupsByParent = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final groupKey in spec.groups.keys) {
        final gspec = IncEntities.groupSpecOf(groupKey)!;
        final groupRows = await db.query(groupKey);
        for (final gr in groupRows) {
          groupsByParent
              .putIfAbsent(gr[gspec.parentColumn] as String, () => {})
              .putIfAbsent(groupKey, () => [])
              .add(gr);
        }
      }

      for (var i = 0; i < rows.length; i += _chunkSize) {
        final slice = rows.sublist(
          i,
          i + _chunkSize > rows.length ? rows.length : i + _chunkSize,
        );
        // 仅携带本分片父行的子组
        final sliceGroups = <String, List<Map<String, dynamic>>>{};
        for (final r in slice) {
          final g = groupsByParent[r['id'] as String];
          if (g == null) continue;
          g.forEach((k, v) {
            sliceGroups.putIfAbsent(k, () => []).addAll(v);
          });
        }
        final blobBytes = utf8.encode(jsonEncode({
          't': spec.table,
          'rows': slice,
          if (sliceGroups.isNotEmpty) 'g': sliceGroups,
        }));
        final hash = sha256.convert(blobBytes).toString();
        if (await remote.putBlob(hash, Uint8List.fromList(blobBytes))) {
          index.add(ChunkIndex(hash: hash, ids: slice.map((r) => r['id'] as String).toList()));
        }
      }
      chunks[spec.table] = index;

      // 现场扫描图片（首建基线）
      for (final row in rows) {
        for (final logical in codec.referencedLogical(row, spec)) {
          if (images.containsKey(logical)) continue;
          final file = File(codec.localPathOf(logical));
          if (!await file.exists()) continue;
          final bytes = await file.readAsBytes();
          final hash = sha256.convert(bytes).toString();
          if (await remote.putBlob(hash, bytes)) {
            images[logical] = hash;
          }
        }
      }
    }

    return Manifest(
      version: version,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      clientId: clientId,
      folded: folded,
      chunks: chunks,
      images: images,
    );
  }
}
