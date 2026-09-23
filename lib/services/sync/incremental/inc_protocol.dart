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

/// 增量包：一个客户端对某个基线版本的一次追加
class DeltaFile {
  final String clientId;
  final int seq;

  /// 基于的 manifest 版本
  final int baseVersion;
  final String createdAt;

  /// 本包新增/变更记录
  final List<DeltaOp> ops;

  /// 图片映射更新：逻辑路径 → blob hash
  final Map<String, String> images;

  DeltaFile({
    required this.clientId,
    required this.seq,
    required this.baseVersion,
    required this.createdAt,
    required this.ops,
    required this.images,
  });

  Map<String, dynamic> toJson() => {
        'c': clientId,
        's': seq,
        'b': baseVersion,
        'at': createdAt,
        'ops': ops.map((e) => e.toJson()).toList(),
        if (images.isNotEmpty) 'img': images,
      };

  factory DeltaFile.fromJson(Map<String, dynamic> j) => DeltaFile(
        clientId: j['c'] as String,
        seq: j['s'] as int,
        baseVersion: j['b'] as int? ?? 0,
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

/// 全局快照清单：压实后包含全量记录的分块索引
class Manifest {
  final int version;
  final String createdAt;
  final String clientId;

  /// 已折叠 delta 的各客户端最高 seq：客户端 ID → seq
  final Map<String, int> folded;

  /// 记录分块索引：表 → 块列表
  final Map<String, List<ChunkIndex>> chunks;

  /// 图片映射：逻辑路径 → blob hash
  final Map<String, String> images;

  Manifest({
    required this.version,
    required this.createdAt,
    required this.clientId,
    required this.folded,
    required this.chunks,
    required this.images,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        'at': createdAt,
        'c': clientId,
        'folded': folded,
        'chunks': chunks.map(
          (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
        ),
        'img': images,
      };

  factory Manifest.fromJson(Map<String, dynamic> j) => Manifest(
        version: j['v'] as int,
        createdAt: j['at'] as String,
        clientId: j['c'] as String,
        folded: ((j['folded'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, v as int)),
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
      );
}
