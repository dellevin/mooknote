import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../../../data/database_helper.dart';
import '../../../utils/image_path_helper.dart';
import '../../../l10n/app_strings.dart';
import 'inc_entities.dart';
import 'inc_manifest_builder.dart';
import 'inc_protocol.dart';
import 'inc_remote.dart';
import 'inc_row_codec.dart';
import 'sync_identity.dart';
import 'sync_meta_store.dart';
import 'sync_tombstones.dart';

/// 增量同步结果
class IncSyncResult {
  final bool success;
  final String message;
  final int uploadedRecords;
  final int downloadedRecords;
  final int uploadedImages;
  final int downloadedImages;
  final int dedupImages;
  final bool needReload;
  final int manifestVersion;

  IncSyncResult({
    required this.success,
    required this.message,
    this.uploadedRecords = 0,
    this.downloadedRecords = 0,
    this.uploadedImages = 0,
    this.downloadedImages = 0,
    this.dedupImages = 0,
    this.needReload = false,
    this.manifestVersion = 0,
  });
}

class _Counters {
  int upRecords = 0;
  int downRecords = 0;
  int upImages = 0;
  int downImages = 0;
  int dedupImages = 0;
}

/// 增量同步服务：内容寻址 blob + manifest + 追加式 delta，多客户端 LWW
class IncSyncService {
  static final IncSyncService instance = IncSyncService._internal();
  IncSyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  Future<IncSyncResult> upload() => _run(push: true);
  Future<IncSyncResult> download() => _run(push: false);

  /// 重置本地基线状态并重新拉取（用于修复历史卡死的同步状态）
  Future<IncSyncResult> reDownload() async {
    await SyncMetaStore.set(SyncMetaStore.manifestVersion, '0');
    return _run(push: false);
  }

  /// 恢复模式下载：以云端为准强制覆盖本地（本地新增未上传的数据保留）。
  /// 用于误删后拉回云端状态。
  Future<IncSyncResult> restoreDownload() async {
    if (_isSyncing) {
      return IncSyncResult(success: false, message: '同步正在进行中，请稍后再试'.tr);
    }
    _isSyncing = true;

    final counters = _Counters();
    final syncStart = DateTime.now().toUtc().toIso8601String();

    try {
      final remote = await IncRemote.create();
      final appDir = await ImagePathHelper.getAppDir();
      final codec = IncRowCodec(path.join(appDir, 'images'));

      final manifest = await remote.getManifest();
      if (manifest == null) {
        return IncSyncResult(success: false, message: '云端没有增量基线数据'.tr);
      }

      var imageMap = await SyncMetaStore.getImageMap();
      imageMap.addAll(manifest.images);
      final localWins = <String>{}; // force 模式下不使用，仅满足签名

      // 1) 强制应用全部 manifest 分块（无视 seen 与时间戳）
      final seen = <String>{};
      for (final spec in IncEntities.entities) {
        for (final chunk in manifest.chunks[spec.table] ?? []) {
          final bytes = await remote.getBlob(chunk.hash);
          if (bytes == null) {
            debugPrint('[Inc] 恢复: 分块拉取失败 ${chunk.hash}');
            continue;
          }
          try {
            final obj = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final groupsBucket = <String, Map<String, List<Map<String, dynamic>>>>{};
            final groupsObj = (obj['g'] as Map<String, dynamic>?) ?? {};
            groupsObj.forEach((gt, rows) {
              final gspec = IncEntities.groupSpecOf(gt);
              if (gspec == null) return;
              for (final r in rows as List) {
                final row = Map<String, dynamic>.from(r as Map);
                groupsBucket
                    .putIfAbsent(row[gspec.parentColumn] as String, () => {})
                    .putIfAbsent(gt, () => [])
                    .add(row);
              }
            });
            for (final r in obj['rows'] as List) {
              final row = Map<String, dynamic>.from(r as Map);
              await _mergeUpsert(
                spec: spec,
                incomingRow: row,
                origin: manifest.clientId,
                incomingTs: row[spec.tsColumn] as String?,
                groups: groupsBucket[row['id'] as String],
                counters: counters,
                localWins: localWins,
                codec: codec,
                remote: remote,
                imageMap: imageMap,
                force: true,
              );
            }
            seen.add(chunk.hash);
          } catch (e) {
            debugPrint('[Inc] 恢复: 分块应用失败: $e');
          }
        }
      }

      // 2) 强制应用全部 delta（基线之后的全部历史）
      final listing = await remote.listDeltas();
      if (listing == null) {
        return IncSyncResult(success: false, message: '无法读取远程增量列表，同步中止'.tr);
      }
      final pending = <(String, int)>[];
      listing.forEach((cid, seqs) {
        for (final seq in seqs) {
          pending.add((cid, seq));
        }
      });
      pending.sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });

      final marks = <String, int>{};
      for (final (cid, seq) in pending) {
        final delta = await remote.getDelta(cid, seq);
        if (delta == null) continue;
        imageMap.addAll(delta.images);
        for (final op in delta.ops) {
          final spec = IncEntities.specOf(op.table);
          if (spec == null) continue;
          if (op.deleted) {
            await _mergeDelete(
              table: op.table,
              id: op.id,
              incomingTs: op.ts,
              origin: cid,
              counters: counters,
              localWins: localWins,
              force: true,
            );
          } else if (op.row != null) {
            await _mergeUpsert(
              spec: spec,
              incomingRow: op.row!,
              origin: cid,
              incomingTs: op.ts,
              groups: op.groups,
              counters: counters,
              localWins: localWins,
              codec: codec,
              remote: remote,
              imageMap: imageMap,
              force: true,
            );
          } else if (op.groups != null) {
            await _mergeGroupsOnly(
              spec: spec,
              parentId: op.id,
              incomingTs: op.ts,
              groups: op.groups!,
              origin: cid,
              counters: counters,
              localWins: localWins,
              codec: codec,
              remote: remote,
              imageMap: imageMap,
              force: true,
            );
          }
        }
        marks[cid] = seq;
      }

      // 3) 收尾：本地状态对齐到刚恢复的云端状态
      await SyncMetaStore.set(SyncMetaStore.manifestVersion, '${manifest.version}');
      await SyncMetaStore.setSeenChunks(seen);
      await SyncMetaStore.setWatermarks(marks);
      await SyncMetaStore.setImageMap(imageMap);
      await SyncMetaStore.set(SyncMetaStore.lastSync, syncStart);
      if (await SyncMetaStore.get(SyncMetaStore.pushAfter) == null) {
        await SyncMetaStore.set(SyncMetaStore.pushAfter, syncStart);
      }

      return IncSyncResult(
        success: true,
        message: '恢复完成'.tr,
        downloadedRecords: counters.downRecords,
        downloadedImages: counters.downImages,
        needReload: counters.downRecords > 0,
        manifestVersion: manifest.version,
      );
    } catch (e) {
      debugPrint('[Inc] 恢复异常: $e');
      return IncSyncResult(success: false, message: '恢复失败: {e}'.trf({'e': e}));
    } finally {
      _isSyncing = false;
    }
  }

  /// 获取增量同步状态信息（供 UI 显示）
  Future<Map<String, dynamic>> getInfo() async {
    final lastSync = await SyncMetaStore.get(SyncMetaStore.lastSync);
    try {
      final remote = await IncRemote.create();
      final manifest = await remote.getManifest();
      return {
        'lastSync': lastSync,
        'manifestVersion': manifest?.version,
      };
    } catch (_) {
      return {'lastSync': lastSync, 'manifestVersion': null};
    }
  }

  Future<IncSyncResult> _run({required bool push}) async {
    if (_isSyncing) {
      return IncSyncResult(success: false, message: '同步正在进行中，请稍后再试'.tr);
    }
    _isSyncing = true;

    final counters = _Counters();
    final syncStart = DateTime.now().toUtc().toIso8601String();

    try {
      final clientId = await SyncIdentity.clientId();
      final remote = await IncRemote.create();
      final appDir = await ImagePathHelper.getAppDir();
      final codec = IncRowCodec(path.join(appDir, 'images'));

      final manifest = await remote.getManifest();

      // ── 情况1：远程尚无基线，本客户端成为首个客户端 ──
      if (manifest == null) {
        final built = await IncManifestBuilder.buildFromLocal(
          remote: remote,
          codec: codec,
          version: 1,
          clientId: clientId,
          folded: {clientId: 0},
          imageMap: {},
        );
        final ok = await remote.putManifest(built);
        if (!ok) {
          return IncSyncResult(success: false, message: '上传基线失败'.tr);
        }
        final imageCount = built.images.length;
        final recordCount = built.chunks.values
            .expand((list) => list)
            .fold<int>(0, (a, c) => a + c.ids.length);
        await SyncMetaStore.set(SyncMetaStore.manifestVersion, '1');
        await SyncMetaStore.setWatermarks({clientId: 0});
        await SyncMetaStore.setImageMap(built.images);
        await SyncMetaStore.set(SyncMetaStore.pushAfter, syncStart);
        await SyncMetaStore.set(SyncMetaStore.lastSync, syncStart);
        return IncSyncResult(
          success: true,
          message: '同步完成'.tr,
          uploadedRecords: recordCount,
          uploadedImages: imageCount,
          manifestVersion: 1,
        );
      }

      // ── 情况2：基线存在，拉取合并 ──
      final localV = await SyncMetaStore.getInt(SyncMetaStore.manifestVersion) ?? 0;
      final isNewManifest = localV < manifest.version;
      final localWins = <String>{};
      var imageMap = await SyncMetaStore.getImageMap();
      var manifestApplied = true;

      if (isNewManifest) {
        // 先合并 manifest 自带的图片映射（分块内记录可能引用同包新图片）
        imageMap.addAll(manifest.images);

        // 1) 应用新 manifest 的分块
        debugPrint('[Inc] manifest v${manifest.version} 本地 v$localV，开始应用分块');
        final seen = await SyncMetaStore.getSeenChunks();
        var chunkTotal = 0;
        for (final spec in IncEntities.entities) {
          for (final chunk in manifest.chunks[spec.table] ?? []) {
            chunkTotal++;
            if (seen.contains(chunk.hash)) continue;
            final bytes = await remote.getBlob(chunk.hash);
            if (bytes == null) {
              debugPrint('[Inc] 分块拉取失败: ${chunk.hash}');
              manifestApplied = false;
              continue;
            }
            try {
              final obj = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
              // 子组按父 id 分桶
              final groupsBucket = <String, Map<String, List<Map<String, dynamic>>>>{};
              final groupsObj = (obj['g'] as Map<String, dynamic>?) ?? {};
              groupsObj.forEach((gt, rows) {
                final gspec = IncEntities.groupSpecOf(gt);
                if (gspec == null) return;
                for (final r in rows as List) {
                  final row = Map<String, dynamic>.from(r as Map);
                  groupsBucket
                      .putIfAbsent(row[gspec.parentColumn] as String, () => {})
                      .putIfAbsent(gt, () => [])
                      .add(row);
                }
              });
              for (final r in obj['rows'] as List) {
                final row = Map<String, dynamic>.from(r as Map);
                await _mergeUpsert(
                  spec: spec,
                  incomingRow: row,
                  origin: manifest.clientId,
                  incomingTs: row[spec.tsColumn] as String?,
                  groups: groupsBucket[row['id'] as String],
                  counters: counters,
                  localWins: localWins,
                  codec: codec,
                  remote: remote,
                  imageMap: imageMap,
                );
              }
              seen.add(chunk.hash);
            } catch (e) {
              debugPrint('[Inc] chunk 应用失败: $e');
              manifestApplied = false;
            }
          }
        }
        await SyncMetaStore.setSeenChunks(seen);
        debugPrint('[Inc] 分块应用结束: 共 $chunkTotal 块, 完整=$manifestApplied, 下载 ${counters.downRecords} 条');

        // 2) 折叠水位 + 图片映射
        final marks = await SyncMetaStore.getWatermarks();
        for (final entry in manifest.folded.entries) {
          marks[entry.key] = max(marks[entry.key] ?? 0, entry.value);
        }
        await SyncMetaStore.setWatermarks(marks);
        imageMap.addAll(manifest.images);
      }

      // 3) 应用新 delta（按客户端、序号全局排序，保证确定性）
      var marks = await SyncMetaStore.getWatermarks();
      final listing = await remote.listDeltas();
      if (listing == null) {
        return IncSyncResult(success: false, message: '无法读取远程增量列表，同步中止'.tr);
      }
      final pending = <(String, int)>[];
      listing.forEach((cid, seqs) {
        for (final seq in seqs) {
          if (seq > (marks[cid] ?? 0)) pending.add((cid, seq));
        }
      });
      pending.sort((a, b) {
        final c = a.$1.compareTo(b.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
      debugPrint('[Inc] 待应用 delta: ${pending.length} 个');

      for (final (cid, seq) in pending) {
        final delta = await remote.getDelta(cid, seq);
        if (delta == null) continue;
        // 先合并本包图片映射，保证同包内新图片可下载
        imageMap.addAll(delta.images);
        for (final op in delta.ops) {
          final spec = IncEntities.specOf(op.table);
          if (spec == null) continue;
          if (op.deleted) {
            await _mergeDelete(
              table: op.table,
              id: op.id,
              incomingTs: op.ts,
              origin: cid,
              counters: counters,
              localWins: localWins,
            );
          } else if (op.row != null) {
            await _mergeUpsert(
              spec: spec,
              incomingRow: op.row!,
              origin: cid,
              incomingTs: op.ts,
              groups: op.groups,
              counters: counters,
              localWins: localWins,
              codec: codec,
              remote: remote,
              imageMap: imageMap,
            );
          } else if (op.groups != null) {
            // 仅子组变更：父行保持本地不变，只替换子组
            await _mergeGroupsOnly(
              spec: spec,
              parentId: op.id,
              incomingTs: op.ts,
              groups: op.groups!,
              origin: cid,
              counters: counters,
              localWins: localWins,
              codec: codec,
              remote: remote,
              imageMap: imageMap,
            );
          }
        }
        marks[cid] = seq;
      }
      await SyncMetaStore.setWatermarks(marks);
      await SyncMetaStore.setImageMap(imageMap);
      // 分块未完整应用时不推进版本，下次同步会重试缺失分块
      await SyncMetaStore.set(
        SyncMetaStore.manifestVersion,
        manifestApplied ? '${manifest.version}' : '$localV',
      );

      // 首次在本设备完成拉取：初始化推送水位，避免把远程刚应用的行回推
      if (await SyncMetaStore.get(SyncMetaStore.pushAfter) == null) {
        await SyncMetaStore.set(SyncMetaStore.pushAfter, syncStart);
      }

      // ── 推送本地变更 ──
      if (push) {
        await _push(
          remote: remote,
          codec: codec,
          clientId: clientId,
          baseVersion: manifest.version,
          localWins: localWins,
          counters: counters,
        );
      }

      await SyncMetaStore.set(SyncMetaStore.lastSync, syncStart);

      // ── 压实检查 ──
      if (push) {
        final totalDeltas = listing.values.fold<int>(0, (a, l) => a + l.length);
        if (totalDeltas > 50) {
          await _compact(remote: remote, codec: codec, clientId: clientId);
        }
      }

      final anyChange = counters.upRecords > 0 || counters.downRecords > 0;
      return IncSyncResult(
        success: true,
        message: anyChange ? '同步完成'.tr : '没有新的变更'.tr,
        uploadedRecords: counters.upRecords,
        downloadedRecords: counters.downRecords,
        uploadedImages: counters.upImages,
        downloadedImages: counters.downImages,
        dedupImages: counters.dedupImages,
        needReload: counters.downRecords > 0,
        manifestVersion: manifest.version,
      );
    } catch (e) {
      debugPrint('[Inc] 同步异常: $e');
      return IncSyncResult(success: false, message: '同步失败: {e}'.trf({'e': e}));
    } finally {
      _isSyncing = false;
    }
  }

  // ── 合并：upsert ────────────────────────────────────

  Future<void> _mergeUpsert({
    required IncEntitySpec spec,
    required Map<String, dynamic> incomingRow,
    required String origin,
    required String? incomingTs,
    required Map<String, List<Map<String, dynamic>>>? groups,
    required _Counters counters,
    required Set<String> localWins,
    required IncRowCodec codec,
    required IncRemote remote,
    required Map<String, String> imageMap,
    bool force = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final localRows = await db.query(spec.table, where: 'id = ?', whereArgs: [incomingRow['id']]);
    final local = localRows.isEmpty ? null : localRows.first;
    final ownId = SyncIdentity.cachedClientId;

    if (local != null && !force) {
      final wins = _remoteWins(
        local[spec.tsColumn] as String?,
        incomingTs,
        origin,
        ownId,
      );
      // 时间戳相同但行内容一致（父行未改），仍应应用随包携带的新子组
      if (!wins && !_rowsEqual(
        _normalizeForCompare(local, spec),
        _normalizeForCompare(incomingRow, spec),
      )) {
        localWins.add('${spec.table}|${incomingRow['id']}');
        return;
      }
      if (!wins && groups == null) {
        localWins.add('${spec.table}|${incomingRow['id']}');
        return;
      }
    }

    final localized = codec.localize(incomingRow, spec);
    await db.insert(
      spec.table,
      localized,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (groups != null) {
      await _replaceGroups(
        parentId: incomingRow['id'] as String,
        groups: groups,
        codec: codec,
      );
    }

    counters.downRecords++;

    // 下载缺失图片
    final imageLogical = <String>{
      ...codec.referencedLogical(localized, spec),
    };
    if (groups != null) {
      for (final entry in groups.entries) {
        final imgCol = entry.key == 'movie_posters'
            ? 'poster_path'
            : entry.key == 'game_screenshots'
                ? 'screenshot_path'
                : null;
        if (imgCol == null) continue;
        for (final r in entry.value) {
          final v = r[imgCol];
          if (v is String && v.isNotEmpty) {
            imageLogical.add(IncRowCodec.toLogical(v));
          }
        }
      }
    }
    for (final logical in imageLogical) {
      await _downloadImage(
        remote: remote,
        codec: codec,
        logical: logical,
        imageMap: imageMap,
        counters: counters,
      );
    }
  }

  // ── 合并：仅子组变更 ────────────────────────────────

  Future<void> _mergeGroupsOnly({
    required IncEntitySpec spec,
    required String parentId,
    required String incomingTs,
    required Map<String, List<Map<String, dynamic>>> groups,
    required String origin,
    required _Counters counters,
    required Set<String> localWins,
    required IncRowCodec codec,
    required IncRemote remote,
    required Map<String, String> imageMap,
    bool force = false,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final localRows = await db.query(spec.table, where: 'id = ?', whereArgs: [parentId]);
    if (localRows.isEmpty) return; // 本地无父实体，忽略
    final local = localRows.first;
    final ownId = SyncIdentity.cachedClientId;

    if (!force && !_remoteWins(
      local[spec.tsColumn] as String?,
      incomingTs,
      origin,
      ownId,
    )) {
      localWins.add('$spec.table|$parentId');
      return;
    }

    await _replaceGroups(
      parentId: parentId,
      groups: groups,
      codec: codec,
    );
    counters.downRecords++;

    for (final entry in groups.entries) {
      final imgCol = entry.key == 'movie_posters'
          ? 'poster_path'
          : entry.key == 'game_screenshots'
              ? 'screenshot_path'
              : null;
      if (imgCol == null) continue;
      for (final r in entry.value) {
        final v = r[imgCol];
        if (v is String && v.isNotEmpty) {
          await _downloadImage(
            remote: remote,
            codec: codec,
            logical: IncRowCodec.toLogical(v),
            imageMap: imageMap,
            counters: counters,
          );
        }
      }
    }
  }

  // ── 合并：删除 ──────────────────────────────────────

  Future<void> _mergeDelete({
    required String table,
    required String id,
    required String incomingTs,
    required String origin,
    required _Counters counters,
    required Set<String> localWins,
    bool force = false,
  }) async {
    final spec = IncEntities.specOf(table)!;
    final db = await DatabaseHelper.instance.database;
    final localRows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    final local = localRows.isEmpty ? null : localRows.first;
    final ownId = SyncIdentity.cachedClientId;

    if (local != null && !force && !_remoteWins(
      local[spec.tsColumn] as String?,
      incomingTs,
      origin,
      ownId,
    )) {
      localWins.add('$table|$id');
      return;
    }

    if (local != null) {
      await db.delete(table, where: 'id = ?', whereArgs: [id]);
    }
    await SyncTombstones.putIfAbsent(table, id, incomingTs, origin);
    counters.downRecords++;
  }

  /// 比较前将图片路径统一为逻辑路径（两设备绝对路径必然不同）
  Map<String, dynamic> _normalizeForCompare(Map<String, dynamic> row, IncEntitySpec spec) {
    final out = Map<String, dynamic>.from(row);
    for (final col in spec.imageColumns) {
      final v = out[col];
      if (v is String && v.isNotEmpty) out[col] = IncRowCodec.toLogical(v);
    }
    final jsonCol = spec.imageJsonColumn;
    if (jsonCol != null) {
      final v = out[jsonCol];
      if (v is String && v.isNotEmpty) {
        try {
          final list = (jsonDecode(v) as List).whereType<String>().map(IncRowCodec.toLogical).toList();
          out[jsonCol] = jsonEncode(list);
        } catch (_) {}
      }
    }
    return out;
  }

  bool _rowsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final av = a[key];
      final bv = b[key];
      if (av is Map || av is List || bv is Map || bv is List) {
        if (jsonEncode(av) != jsonEncode(bv)) return false;
      } else if (av != bv) {
        return false;
      }
    }
    return true;
  }

  /// LWW 判定：远程较新返回 true；时间戳相同用 clientId 字典序兜底
  bool _remoteWins(
    String? localTs,
    String? remoteTs,
    String remoteClient,
    String ownClient,
  ) {
    if (localTs == null) return true;
    if (remoteTs == null) return false;
    final lt = DateTime.tryParse(localTs);
    final rt = DateTime.tryParse(remoteTs);
    if (lt == null || rt == null) return true;
    final cmp = rt.compareTo(lt);
    if (cmp != 0) return cmp > 0;
    return remoteClient.compareTo(ownClient) > 0;
  }

  /// 整组替换子表（子表行内图片路径同步本地化）
  Future<void> _replaceGroups({
    required String parentId,
    required Map<String, List<Map<String, dynamic>>> groups,
    required IncRowCodec codec,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final entry in groups.entries) {
        final gspec = IncEntities.groupSpecOf(entry.key);
        if (gspec == null) continue;
        await txn.delete(
          entry.key,
          where: '${gspec.parentColumn} = ?',
          whereArgs: [parentId],
        );
        for (final r in codec.localizeGroupRows(entry.key, entry.value)) {
          await txn.insert(entry.key, r);
        }
      }
    });
  }

  /// 下载单张缺失图片
  Future<void> _downloadImage({
    required IncRemote remote,
    required IncRowCodec codec,
    required String logical,
    required Map<String, String> imageMap,
    required _Counters counters,
  }) async {
    final file = File(codec.localPathOf(logical));
    if (await file.exists()) return;
    final hash = imageMap[logical];
    if (hash == null) return;
    final bytes = await remote.getBlob(hash);
    if (bytes == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    counters.downImages++;
  }

  // ── 推送 ────────────────────────────────────────────

  Future<void> _push({
    required IncRemote remote,
    required IncRowCodec codec,
    required String clientId,
    required int baseVersion,
    required Set<String> localWins,
    required _Counters counters,
  }) async {
    final syncStart = DateTime.now().toUtc().toIso8601String();
    final after = await SyncMetaStore.get(SyncMetaStore.pushAfter);

    // 1) 水位之后变更的行
    final selected = <String, Map<String, dynamic>>{};
    final db = await DatabaseHelper.instance.database;
    for (final spec in IncEntities.entities) {
      final rows = await db.query(
        spec.table,
        where: after == null ? null : '${spec.tsColumn} > ?',
        whereArgs: after == null ? null : [after],
      );
      for (final r in rows) {
        selected['${spec.table}|${r['id']}'] = r;
      }
    }

    // 2) bootstrap 合并中本地胜出的行
    for (final key in localWins) {
      if (selected.containsKey(key)) continue;
      final parts = key.split('|');
      final rows = await db.query(parts[0], where: 'id = ?', whereArgs: [parts[1]]);
      if (rows.isNotEmpty) selected[key] = rows.first;
    }

    // 3) 待推送墓碑
    final tombRows = await SyncTombstones.takePending();

    // 4) 子组新增（父行本身未变）
    final groupOnly = <String, Set<String>>{}; // groupTable → parentIds
    if (after != null) {
      for (final gspec in IncEntities.groups) {
        final tsCol = gspec.tsColumn;
        if (tsCol == null) continue;
        final rows = await db.query(
          gspec.table,
          where: '$tsCol > ?',
          whereArgs: [after],
        );
        for (final r in rows) {
          groupOnly.putIfAbsent(gspec.table, () => {}).add(r[gspec.parentColumn] as String);
        }
      }
    }

    // 5) 构建 ops + 上传图片
    final ops = <DeltaOp>[];
    final newImageMap = <String, String>{};

    Future<Map<String, List<Map<String, dynamic>>>> loadGroups(String parentId, IncEntitySpec spec) async {
      final result = <String, List<Map<String, dynamic>>>{};
      for (final groupKey in spec.groups.keys) {
        final gspec = IncEntities.groupSpecOf(groupKey)!;
        final rows = await db.query(groupKey, where: '${gspec.parentColumn} = ?', whereArgs: [parentId]);
        result[groupKey] = rows;
        for (final r in rows) {
          final imgCol = groupKey == 'movie_posters'
              ? 'poster_path'
              : groupKey == 'game_screenshots'
                  ? 'screenshot_path'
                  : null;
          final abs = imgCol == null ? null : r[imgCol] as String?;
          if (abs != null && abs.isNotEmpty) {
            await _pushImage(
              remote: remote,
              codec: codec,
              logical: IncRowCodec.toLogical(abs),
              newImageMap: newImageMap,
              counters: counters,
            );
          }
        }
      }
      return result;
    }

    for (final entry in selected.entries) {
      final parts = entry.key.split('|');
      final spec = IncEntities.specOf(parts[0])!;
      final row = entry.value;
      final groups = await loadGroups(row['id'] as String, spec);
      for (final logical in codec.referencedLogical(row, spec)) {
        await _pushImage(
          remote: remote,
          codec: codec,
          logical: logical,
          newImageMap: newImageMap,
          counters: counters,
        );
      }
      ops.add(DeltaOp(
        table: spec.table,
        id: row['id'] as String,
        ts: row[spec.tsColumn] as String,
        deleted: false,
        row: row,
        groups: groups.isEmpty ? null : groups,
      ));
      counters.upRecords++;
    }

    // group-only ops
    for (final entry in groupOnly.entries) {
      final gspec = IncEntities.groupSpecOf(entry.key)!;
      for (final parentId in entry.value) {
        final key = '${gspec.parentTable}|$parentId';
        if (selected.containsKey(key)) continue;
        final groups = await loadGroups(parentId, IncEntities.specOf(gspec.parentTable)!);
        final parentRows = await db.query(gspec.parentTable, where: 'id = ?', whereArgs: [parentId]);
        if (parentRows.isEmpty) continue;
        // ts 取子组最新变更时间，避免与父行时间戳相同导致 LWW 漏更新
        var latestTs = parentRows.first[IncEntities.specOf(gspec.parentTable)!.tsColumn] as String;
        final tsCol = gspec.tsColumn;
        if (tsCol != null) {
          for (final list in groups.values) {
            for (final r in list) {
              final v = r[tsCol];
              if (v is String && v.compareTo(latestTs) > 0) latestTs = v;
            }
          }
        }
        ops.add(DeltaOp(
          table: gspec.parentTable,
          id: parentId,
          ts: latestTs,
          deleted: false,
          row: null,
          groups: groups,
        ));
      }
    }

    // 墓碑 ops
    for (final t in tombRows) {
      ops.add(DeltaOp(
        table: t['entity_type'] as String,
        id: t['entity_id'] as String,
        ts: t['deleted_at'] as String,
        deleted: true,
      ));
    }

    if (ops.isEmpty) return;

    // 6) 分批写 delta
    final listing = await remote.listDeltas();
    if (listing == null) throw Exception('无法读取远程增量列表'.tr);
    var seq = (listing[clientId]?.isNotEmpty == true ? listing[clientId]!.last : 0) + 1;
    const batchSize = 200;
    for (var i = 0; i < ops.length; i += batchSize) {
      final slice = ops.sublist(i, min(i + batchSize, ops.length));
      final delta = DeltaFile(
        clientId: clientId,
        seq: seq++,
        baseVersion: baseVersion,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        ops: slice,
        // 图片映射只随第一个 delta 携带
        images: i == 0 ? newImageMap : {},
      );
      final ok = await remote.putDelta(delta);
      if (!ok) throw Exception('delta 上传失败'.tr);
    }

    // 7) 收尾
    await SyncTombstones.clearPushed(tombRows);
    await SyncMetaStore.set(SyncMetaStore.pushAfter, syncStart);
    final imageMap = await SyncMetaStore.getImageMap();
    imageMap.addAll(newImageMap);
    await SyncMetaStore.setImageMap(imageMap);
    // 把自己的新 delta 记入水位，避免下次拉取时被当新变更重新应用
    final marks = await SyncMetaStore.getWatermarks();
    marks[clientId] = seq - 1;
    await SyncMetaStore.setWatermarks(marks);
  }

  /// 推送单张图片（blob 已存在计入去重）
  Future<void> _pushImage({
    required IncRemote remote,
    required IncRowCodec codec,
    required String logical,
    required Map<String, String> newImageMap,
    required _Counters counters,
  }) async {
    if (newImageMap.containsKey(logical)) return;
    final file = File(codec.localPathOf(logical));
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    if (await remote.blobExists(hash)) {
      counters.dedupImages++;
    } else {
      final ok = await remote.uploadBlob(hash, bytes);
      if (!ok) return;
      counters.upImages++;
    }
    newImageMap[logical] = hash;
  }

  // ── 压实 ────────────────────────────────────────────

  Future<void> _compact({
    required IncRemote remote,
    required IncRowCodec codec,
    required String clientId,
  }) async {
    final marks = await SyncMetaStore.getWatermarks();
    final imageMap = await SyncMetaStore.getImageMap();
    final currentVersion = await SyncMetaStore.getInt(SyncMetaStore.manifestVersion) ?? 1;
    final newVersion = currentVersion + 1;

    final manifest = await IncManifestBuilder.buildFromLocal(
      remote: remote,
      codec: codec,
      version: newVersion,
      clientId: clientId,
      folded: Map<String, int>.from(marks),
      imageMap: imageMap,
    );

    if (!await remote.putManifest(manifest)) return;

    // 校验：若版本已不是我们的版本，说明有其他客户端同时压实，放弃删除
    final back = await remote.getManifest();
    if (back == null || back.version != newVersion) {
      debugPrint('[Inc] compaction 冲突，跳过 delta 删除');
      return;
    }

    final listing = await remote.listDeltas();
    if (listing == null) return;
    for (final entry in marks.entries) {
      final limit = entry.value;
      for (final seq in listing[entry.key] ?? []) {
        if (seq <= limit) await remote.deleteDelta(entry.key, seq);
      }
    }

    await SyncMetaStore.set(SyncMetaStore.manifestVersion, '$newVersion');
    final seen = await SyncMetaStore.getSeenChunks();
    for (final list in manifest.chunks.values) {
      for (final c in list) {
        seen.add(c.hash);
      }
    }
    await SyncMetaStore.setSeenChunks(seen);
    debugPrint('[Inc] compaction 完成 -> v$newVersion');
  }
}
