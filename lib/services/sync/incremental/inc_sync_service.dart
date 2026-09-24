import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
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

/// 增量同步服务 v2：内容寻址 blob + manifest + 平铺 UUID delta，多客户端 LWW
///
/// 核心原理：LWW 合并幂等且可交换——同一批变更无论按什么顺序应用、
/// 应用几遍，结果都一样。因此不需要序号与水位，本地只需记住
/// "哪些 delta 文件名已应用过"（appliedDeltas）。
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
    await SyncMetaStore.setAppliedDeltas({});
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
            debugPrint('[Inc2] 恢复: 分块拉取失败 ${chunk.hash}');
            continue;
          }
          try {
            final obj = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
            final groupsBucket = _bucketGroups(obj);
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
            debugPrint('[Inc2] 恢复: 分块应用失败: $e');
          }
        }
      }

      // 1.5) 应用 manifest 携带的墓碑（LWW：时间戳比删除更新的行保留）
      for (final t in manifest.tombstones) {
        if (IncEntities.specOf(t.table) == null) continue;
        await _mergeDelete(
          table: t.table,
          id: t.id,
          incomingTs: t.ts,
          origin: t.clientId,
          counters: counters,
          localWins: localWins,
        );
      }

      // 2) 对账：本地有而 manifest 没有的记录（且非待推送）视为远程已删
      await _reconcile(
        manifest: manifest,
        counters: counters,
      );

      // 3) 强制应用全部未折叠 delta（已折叠的内容在 manifest 分块里）
      final names = await remote.listDeltaNames();
      if (names == null) {
        return IncSyncResult(success: false, message: '无法读取远程增量列表，同步中止'.tr);
      }
      final folded = manifest.foldedDeltas.toSet();
      final applied = <String>{};
      for (final name in names) {
        if (folded.contains(name)) continue;
        final delta = await remote.getDelta(name);
        if (delta == null) {
          debugPrint('[Inc2] 恢复: delta 拉取失败 $name');
          continue;
        }
        imageMap.addAll(delta.images);
        for (final op in delta.ops) {
          final spec = IncEntities.specOf(op.table);
          if (spec == null) continue;
          if (op.deleted) {
            await _mergeDelete(
              table: op.table,
              id: op.id,
              incomingTs: op.ts,
              origin: delta.clientId,
              counters: counters,
              localWins: localWins,
              force: true,
            );
          } else if (op.row != null) {
            await _mergeUpsert(
              spec: spec,
              incomingRow: op.row!,
              origin: delta.clientId,
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
              origin: delta.clientId,
              counters: counters,
              localWins: localWins,
              codec: codec,
              remote: remote,
              imageMap: imageMap,
              force: true,
            );
          }
        }
        applied.add(name);
      }

      // 4) 收尾：本地状态对齐到刚恢复的云端状态
      await SyncMetaStore.set(SyncMetaStore.manifestVersion, '${manifest.version}');
      await SyncMetaStore.setSeenChunks(seen);
      await SyncMetaStore.setAppliedDeltas(applied);
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
      debugPrint('[Inc2] 恢复异常: $e');
      return IncSyncResult(success: false, message: '恢复失败: {e}'.trf({'e': e}));
    } finally {
      _isSyncing = false;
    }
  }

  /// 强制推送：先删除云端全部增量数据（delta + manifest），再以本地为准重建云端基线。
  /// 其他设备下次同步时按新基线合并（其他设备较新的修改仍按 LWW 保留）。
  /// 用于云端数据异常时以本机为准修复云端。
  Future<IncSyncResult> forcePush() async {
    if (_isSyncing) {
      return IncSyncResult(success: false, message: '同步正在进行中，请稍后再试'.tr);
    }
    _isSyncing = true;

    final syncStart = DateTime.now().toUtc().toIso8601String();

    try {
      final clientId = await SyncIdentity.clientId();
      final remote = await IncRemote.create();
      final appDir = await ImagePathHelper.getAppDir();
      final codec = IncRowCodec(path.join(appDir, 'images'));

      // 版本号取自旧 manifest（保持单调递增，其他设备才能识别为新基线）
      final prev = await remote.getManifest();
      final newVersion = (prev?.version ?? 0) + 1;

      // 先删除云端全部增量数据（delta + manifest），再推送本地数据，
      // 避免云端残留的旧 delta 在新基线之上被其他设备重复应用
      final names = await remote.listDeltaNames();
      if (names == null) {
        return IncSyncResult(success: false, message: '清理远程增量失败，请重试'.tr);
      }
      for (final name in names) {
        await remote.deleteDelta(name);
      }
      await remote.deleteManifest();

      // 全新基线只携带本地墓碑（云端旧墓碑已随 manifest 一并删除）
      final tombRows = await SyncTombstones.all();

      final built = await IncManifestBuilder.buildFromLocal(
        remote: remote,
        codec: codec,
        version: newVersion,
        clientId: clientId,
        foldedDeltas: const [],
        imageMap: {},
        tombstones: tombRows.map((r) => _tombEntryFromRow(r)).toList(),
      );
      if (!await remote.putManifest(built)) {
        return IncSyncResult(success: false, message: '上传基线失败'.tr);
      }

      // 本地状态对齐到新基线
      await SyncTombstones.clearEmbedded(tombRows);
      final imageCount = built.images.length;
      final recordCount = built.chunks.values
          .expand((list) => list)
          .fold<int>(0, (a, c) => a + c.ids.length);
      await SyncMetaStore.set(SyncMetaStore.manifestVersion, '$newVersion');
      final seen = await SyncMetaStore.getSeenChunks();
      for (final list in built.chunks.values) {
        for (final c in list) {
          seen.add(c.hash);
        }
      }
      await SyncMetaStore.setSeenChunks(seen);
      await SyncMetaStore.setAppliedDeltas({});
      await SyncMetaStore.setImageMap(built.images);
      await SyncMetaStore.set(SyncMetaStore.pushAfter, syncStart);
      await SyncMetaStore.set(SyncMetaStore.lastSync, syncStart);

      return IncSyncResult(
        success: true,
        message: '推送完成'.tr,
        uploadedRecords: recordCount,
        uploadedImages: imageCount,
        manifestVersion: newVersion,
      );
    } catch (e) {
      debugPrint('[Inc2] 强制推送异常: $e');
      return IncSyncResult(success: false, message: '推送失败: {e}'.trf({'e': e}));
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

  Future<IncSyncResult> _run({required bool push, bool pull = true}) async {
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
        final tombRows = await SyncTombstones.all();
        final built = await IncManifestBuilder.buildFromLocal(
          remote: remote,
          codec: codec,
          version: 1,
          clientId: clientId,
          foldedDeltas: const [],
          imageMap: {},
          tombstones: tombRows.map(_tombEntryFromRow).toList(),
        );
        final ok = await remote.putManifest(built);
        if (!ok) {
          return IncSyncResult(success: false, message: '上传基线失败'.tr);
        }
        // 墓碑已嵌入基线，本地记录可清除
        await SyncTombstones.clearEmbedded(tombRows);
        final imageCount = built.images.length;
        final recordCount = built.chunks.values
            .expand((list) => list)
            .fold<int>(0, (a, c) => a + c.ids.length);
        await SyncMetaStore.set(SyncMetaStore.manifestVersion, '1');
        await SyncMetaStore.setAppliedDeltas({});
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
      final isNewManifest = pull && localV < manifest.version;
      final localWins = <String>{};
      var imageMap = await SyncMetaStore.getImageMap();
      var appliedDeltas = await SyncMetaStore.getAppliedDeltas();
      var manifestApplied = true;

      if (isNewManifest) {
        // 先合并 manifest 自带的图片映射（分块内记录可能引用同包新图片）
        imageMap.addAll(manifest.images);

        // 0) 应用 manifest 携带的墓碑：被压实折叠的删除只能通过这里传播
        for (final t in manifest.tombstones) {
          if (IncEntities.specOf(t.table) == null) continue;
          await _mergeDelete(
            table: t.table,
            id: t.id,
            incomingTs: t.ts,
            origin: t.clientId,
            counters: counters,
            localWins: localWins,
          );
        }

        // 1) 应用新 manifest 的分块
        debugPrint('[Inc2] manifest v${manifest.version} 本地 v$localV，开始应用分块');
        final seen = await SyncMetaStore.getSeenChunks();
        var chunkTotal = 0;
        for (final spec in IncEntities.entities) {
          for (final chunk in manifest.chunks[spec.table] ?? []) {
            chunkTotal++;
            if (seen.contains(chunk.hash)) continue;
            final bytes = await remote.getBlob(chunk.hash);
            if (bytes == null) {
              debugPrint('[Inc2] 分块拉取失败: ${chunk.hash}');
              manifestApplied = false;
              continue;
            }
            try {
              final obj = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
              final groupsBucket = _bucketGroups(obj);
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
              debugPrint('[Inc2] chunk 应用失败: $e');
              manifestApplied = false;
            }
          }
        }
        await SyncMetaStore.setSeenChunks(seen);
        debugPrint('[Inc2] 分块应用结束: 共 $chunkTotal 块, 完整=$manifestApplied, 下载 ${counters.downRecords} 条');

        // 2) 对账：硬删除不会出现在任何 delta/墓碑里，只能靠
        //    "manifest 有全量 ID 列表" 这一事实反向推断
        if (manifestApplied) {
          await _reconcile(manifest: manifest, counters: counters);
        }

        // 3) 已折叠的 delta 内容在分块里，从待应用集合中剔除
        appliedDeltas.removeAll(manifest.foldedDeltas);
        imageMap.addAll(manifest.images);
      }

      // 拉取远程增量列表（拉取合并与压实检查共用）
      final names = await remote.listDeltaNames();
      if (names == null) {
        return IncSyncResult(success: false, message: '无法读取远程增量列表，同步中止'.tr);
      }

      var allDeltasClean = true;
      if (pull) {
        // 4) 应用未见过的 delta（LWW 幂等可交换，无需排序）
        final folded = manifest.foldedDeltas.toSet();
        final pending = names
            .where((n) => !appliedDeltas.contains(n) && !folded.contains(n))
            .toList();
        debugPrint('[Inc2] 待应用 delta: ${pending.length} 个');

        for (final name in pending) {
          final delta = await remote.getDelta(name);
          if (delta == null) {
            // 拉取失败：不记入已应用，下次同步重试
            allDeltasClean = false;
            continue;
          }
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
                origin: delta.clientId,
                counters: counters,
                localWins: localWins,
              );
            } else if (op.row != null) {
              await _mergeUpsert(
                spec: spec,
                incomingRow: op.row!,
                origin: delta.clientId,
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
                origin: delta.clientId,
                counters: counters,
                localWins: localWins,
                codec: codec,
                remote: remote,
                imageMap: imageMap,
              );
            }
          }
          appliedDeltas.add(name);
        }
        await SyncMetaStore.setAppliedDeltas(appliedDeltas);
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
      }

      // ── 推送本地变更 ──
      if (push) {
        await _push(
          remote: remote,
          codec: codec,
          clientId: clientId,
          localWins: localWins,
          counters: counters,
          appliedDeltas: appliedDeltas,
        );
      }

      await SyncMetaStore.set(SyncMetaStore.lastSync, syncStart);

      // ── 压实检查：本地已完全对齐 manifest（分块与 delta 全部应用成功）
      //    时才允许压实，否则会把未应用的变更从远程抹掉 ──
      if (pull &&
          manifestApplied &&
          allDeltasClean &&
          localV == manifest.version &&
          names.length > 50) {
        await _compact(
          remote: remote,
          codec: codec,
          clientId: clientId,
          deltaNames: names,
        );
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
      debugPrint('[Inc2] 同步异常: $e');
      return IncSyncResult(success: false, message: '同步失败: {e}'.trf({'e': e}));
    } finally {
      _isSyncing = false;
    }
  }

  // ── 对账 ────────────────────────────────────────────

  /// 应用新 manifest 后：本地存在但 manifest 中不存在的记录，
  /// 说明已在其他设备被硬删除（硬删除不进 delta/墓碑，只有这里能发现）。
  ///
  /// 保守保留策略（宁可不删，不可误删）：
  /// - 从未推送过（pushAfter == null）：无法区分"本地新增"与"远程已删"，整体跳过
  /// - 行时间戳 > pushAfter：本地待推送的变更，保留
  /// - 行时间戳 >= manifest.createdAt：manifest 快照之后才动的，保留
  /// - 时间戳无法解析：保留
  /// 对账删除不记墓碑（删除事实已在 manifest 中体现）。
  Future<void> _reconcile({
    required Manifest manifest,
    required _Counters counters,
  }) async {
    final pushAfter = await SyncMetaStore.get(SyncMetaStore.pushAfter);
    if (pushAfter == null) {
      debugPrint('[Inc2] 对账跳过：本设备尚未推送过');
      return;
    }
    final pa = DateTime.tryParse(pushAfter);
    final mc = DateTime.tryParse(manifest.createdAt);
    final db = await DatabaseHelper.instance.database;

    var removed = 0;
    for (final spec in IncEntities.entities) {
      final manifestIds = <String>{};
      for (final chunk in manifest.chunks[spec.table] ?? []) {
        manifestIds.addAll(chunk.ids);
      }
      final localRows = await db.query(spec.table);
      for (final row in localRows) {
        final id = row['id'] as String;
        if (manifestIds.contains(id)) continue;
        final tsStr = row[spec.tsColumn] as String?;
        final ts = tsStr == null ? null : DateTime.tryParse(tsStr);
        if (ts == null) continue; // 无法解析 → 保留
        if (pa == null || ts.isAfter(pa)) continue; // 待推送 → 保留
        if (mc == null || !ts.isBefore(mc)) continue; // 快照后才动 → 保留
        await db.delete(spec.table, where: 'id = ?', whereArgs: [id]);
        removed++;
        counters.downRecords++;
      }
    }
    if (removed > 0) debugPrint('[Inc2] 对账删除 $removed 条本地多余记录');
  }

  // ── 合并：upsert ────────────────────────────────────

  /// 分块 JSON 中的子组按父 id 分桶
  static Map<String, Map<String, List<Map<String, dynamic>>>> _bucketGroups(
    Map<String, dynamic> obj,
  ) {
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
    return groupsBucket;
  }

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
      localWins.add('${spec.table}|$parentId');
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
      counters.downRecords++;
    }
    await SyncTombstones.putIfAbsent(table, id, incomingTs, origin);
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
    required Set<String> localWins,
    required _Counters counters,
    required Set<String> appliedDeltas,
  }) async {
    final syncStart = DateTime.now().toUtc().toIso8601String();
    final after = await SyncMetaStore.get(SyncMetaStore.pushAfter);
    final afterTs = after == null ? null : DateTime.tryParse(after);

    // Dart 侧时间戳过滤：历史数据里本地时间与 UTC 两种格式混存，
    // SQL 字符串比较在非零时区下会误判，统一解析成 DateTime 再比
    bool changedAfter(String? tsStr) {
      if (afterTs == null) return true;
      final ts = tsStr == null ? null : DateTime.tryParse(tsStr);
      if (ts == null) return true; // 无法解析：宁可多推，不可漏推
      return ts.isAfter(afterTs);
    }

    // 1) 水位之后变更的行
    final selected = <String, Map<String, dynamic>>{};
    final db = await DatabaseHelper.instance.database;
    for (final spec in IncEntities.entities) {
      final rows = await db.query(spec.table);
      for (final r in rows) {
        if (changedAfter(r[spec.tsColumn] as String?)) {
          selected['${spec.table}|${r['id']}'] = r;
        }
      }
    }

    // 2) 拉取合并中本地胜出的行
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
    for (final gspec in IncEntities.groups) {
      final tsCol = gspec.tsColumn;
      if (tsCol == null) continue;
      final rows = await db.query(gspec.table);
      for (final r in rows) {
        if (changedAfter(r[tsCol] as String?)) {
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

    // 6) 分批写 delta（UUID 文件名，无序号）
    const batchSize = 200;
    final uploadedNames = <String>[];
    for (var i = 0; i < ops.length; i += batchSize) {
      final slice = ops.sublist(i, min(i + batchSize, ops.length));
      final name = '${const Uuid().v4()}.json';
      final delta = DeltaFile(
        clientId: clientId,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        ops: slice,
        // 图片映射只随第一个 delta 携带
        images: i == 0 ? newImageMap : {},
      );
      final ok = await remote.putDelta(name, delta);
      if (!ok) throw Exception('delta 上传失败'.tr);
      uploadedNames.add(name);
    }

    // 7) 收尾
    await SyncTombstones.markPushed(tombRows);
    await SyncMetaStore.set(SyncMetaStore.pushAfter, syncStart);
    final imageMap = await SyncMetaStore.getImageMap();
    imageMap.addAll(newImageMap);
    await SyncMetaStore.setImageMap(imageMap);
    // 自己的新 delta 直接记入已应用，避免下次拉取时重复下载
    appliedDeltas.addAll(uploadedNames);
    await SyncMetaStore.setAppliedDeltas(appliedDeltas);
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

  /// sync_tombstones 行 → manifest 墓碑条目
  static TombstoneEntry _tombEntryFromRow(Map<String, dynamic> r) =>
      TombstoneEntry(
        table: r['entity_type'] as String,
        id: r['entity_id'] as String,
        ts: r['deleted_at'] as String,
        clientId: r['client_id'] as String,
      );

  Future<void> _compact({
    required IncRemote remote,
    required IncRowCodec codec,
    required String clientId,
    required List<String> deltaNames,
  }) async {
    final imageMap = await SyncMetaStore.getImageMap();
    final currentVersion = await SyncMetaStore.getInt(SyncMetaStore.manifestVersion) ?? 1;
    final newVersion = currentVersion + 1;

    // 墓碑随 manifest 携带：合并上一版 manifest 与本地墓碑。
    // 被折叠的删除 delta 即将被删除，墓碑是删除信息唯一的载体
    final prev = await remote.getManifest();
    final tombRows = await SyncTombstones.all();
    final merged = <String, TombstoneEntry>{
      for (final t in prev?.tombstones ?? const <TombstoneEntry>[])
        '${t.table}|${t.id}': t,
    };
    for (final r in tombRows) {
      final e = _tombEntryFromRow(r);
      merged['${e.table}|${e.id}'] = e;
    }

    final manifest = await IncManifestBuilder.buildFromLocal(
      remote: remote,
      codec: codec,
      version: newVersion,
      clientId: clientId,
      foldedDeltas: deltaNames,
      imageMap: imageMap,
      tombstones: merged.values.toList(),
    );

    if (!await remote.putManifest(manifest)) return;

    // 校验：若版本已不是我们的版本，说明有其他客户端同时压实，放弃删除
    final back = await remote.getManifest();
    if (back == null || back.version != newVersion) {
      debugPrint('[Inc2] compaction 冲突，跳过 delta 删除');
      return;
    }

    // 墓碑已嵌入新 manifest，本地记录可清除
    await SyncTombstones.clearEmbedded(tombRows);

    for (final name in deltaNames) {
      await remote.deleteDelta(name);
    }

    await SyncMetaStore.set(SyncMetaStore.manifestVersion, '$newVersion');
    final seen = await SyncMetaStore.getSeenChunks();
    for (final list in manifest.chunks.values) {
      for (final c in list) {
        seen.add(c.hash);
      }
    }
    await SyncMetaStore.setSeenChunks(seen);
    // 被折叠的 delta 已从远程删除，本地已应用集合同步清理
    final applied = await SyncMetaStore.getAppliedDeltas();
    applied.removeAll(deltaNames);
    await SyncMetaStore.setAppliedDeltas(applied);
    debugPrint('[Inc2] compaction 完成 -> v$newVersion, 折叠 ${deltaNames.length} 个 delta');
  }
}
