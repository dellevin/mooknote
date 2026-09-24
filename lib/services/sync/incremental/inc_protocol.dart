/// 增量同步单条操作
class DeltaOp {
  final String table;
  final String id;
  final String ts;

  /// 是否为删除（墓碑）op
  final bool deleted;

  /// upsert 的完整行（deleted 时为 null）
  final Map<String, dynamic>? row;

  /// 随父行整组替换的子表行：组名（子表名）→ 行列表
  final Map<String, List<Map<String, dynamic>>>? groups;

  DeltaOp({
    required this.table,
    required this.id,
    required this.ts,
    required this.deleted,
    this.row,
    this.groups,
  });

  Map<String, dynamic> toJson() => {
        't': table,
        'id': id,
        'ts': ts,
        if (deleted) 'd': 1,
        if (!deleted && row != null) 'row': row,
        if (!deleted && groups != null && groups!.isNotEmpty) 'g': groups,
      };

  factory DeltaOp.fromJson(Map<String, dynamic> j) => DeltaOp(
        table: j['t'] as String,
        id: j['id'] as String,
        ts: j['ts'] as String,
        deleted: j['d'] == 1,
        row: (j['row'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v),
        ),
        groups: (j['g'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(
            k,
            (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          ),
        ),
      );
}

/// 增量包：一次本地变更的快照。
/// v2：不再需要 seq/baseVersion——LWW 合并幂等且可交换，
/// 应用顺序与重复应用均不影响结果，文件用 UUID 命名即可。
class DeltaFile {
  final String clientId;
  final String createdAt;

  /// 本包新增/变更记录
  final List<DeltaOp> ops;

  /// 图片映射更新：逻辑路径 → blob hash
  final Map<String, String> images;

  DeltaFile({
    required this.clientId,
    required this.createdAt,
    required this.ops,
    required this.images,
  });

  Map<String, dynamic> toJson() => {
        'c': clientId,
        'at': createdAt,
        'ops': ops.map((e) => e.toJson()).toList(),
        if (images.isNotEmpty) 'img': images,
      };

  factory DeltaFile.fromJson(Map<String, dynamic> j) => DeltaFile(
        clientId: j['c'] as String,
        createdAt: j['at'] as String,
        ops: (j['ops'] as List)
            .map((e) => DeltaOp.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        images: ((j['img'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as String)),
      );
}

/// 记录分块索引项
class ChunkIndex {
  final String hash;
  final List<String> ids;

  const ChunkIndex({required this.hash, required this.ids});

  Map<String, dynamic> toJson() => {'h': hash, 'ids': ids};

  factory ChunkIndex.fromJson(Map<String, dynamic> j) => ChunkIndex(
        hash: j['h'] as String,
        ids: (j['ids'] as List).map((e) => e as String).toList(),
      );
}

/// 随 manifest 携带的墓碑：压实折叠 delta 后，删除信息仍能传播到其他客户端
class TombstoneEntry {
  final String table;
  final String id;
  final String ts;
  final String clientId;

  const TombstoneEntry({
    required this.table,
    required this.id,
    required this.ts,
    required this.clientId,
  });

  Map<String, dynamic> toJson() => {'t': table, 'id': id, 'ts': ts, 'c': clientId};

  factory TombstoneEntry.fromJson(Map<String, dynamic> j) => TombstoneEntry(
        table: j['t'] as String,
        id: j['id'] as String,
        ts: j['ts'] as String,
        clientId: j['c'] as String? ?? '',
      );
}

/// 全局快照清单：压实后包含全量记录的分块索引
class Manifest {
  final int version;
  final String createdAt;
  final String clientId;

  /// 已折叠进本 manifest 的 delta 文件名列表（相对 delta/ 目录）。
  /// 其他客户端见到后可从本地 appliedDeltas 中清理这些条目，
  /// 也可以放心跳过这些远程 delta（内容已在 chunks 中）。
  final List<String> foldedDeltas;

  /// 记录分块索引：表 → 块列表
  final Map<String, List<ChunkIndex>> chunks;

  /// 图片映射：逻辑路径 → blob hash
  final Map<String, String> images;

  /// 已折叠 delta 中的删除墓碑（跨压实传递，直到所有客户端都越过）
  final List<TombstoneEntry> tombstones;

  Manifest({
    required this.version,
    required this.createdAt,
    required this.clientId,
    required this.foldedDeltas,
    required this.chunks,
    required this.images,
    this.tombstones = const [],
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'at': createdAt,
        'c': clientId,
        'folded': foldedDeltas,
        'chunks': chunks.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'img': images,
        if (tombstones.isNotEmpty)
          'tombs': tombstones.map((e) => e.toJson()).toList(),
      };

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        version: j['v'] as int,
        createdAt: j['at'] as String,
        clientId: j['c'] as String,
        foldedDeltas: ((j['folded'] as List?) ?? [])
            .map((e) => e as String)
            .toList(),
        chunks: ((j['chunks'] as Map<String, dynamic>?) ?? {}).map(
          (k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => ChunkIndex.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList(),
          ),
        ),
        images: ((j['img'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as String)),
        tombstones: ((j['tombs'] as List?) ?? [])
            .map((e) => TombstoneEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
