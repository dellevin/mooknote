import 'dart:convert';
import 'package:uuid/uuid.dart';

/// 块类型枚举
enum NoteBlockType {
  paragraph,
  heading1,
  heading2,
  heading3,
  bulletList,
  numberedList,
  checklist,
  quote,
  codeBlock,
  divider;

  String toJson() => name;

  static NoteBlockType fromString(String value) {
    return NoteBlockType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NoteBlockType.paragraph,
    );
  }

  /// 中文标签
  String get label {
    switch (this) {
      case NoteBlockType.paragraph:
        return '正文';
      case NoteBlockType.heading1:
        return '标题1';
      case NoteBlockType.heading2:
        return '标题2';
      case NoteBlockType.heading3:
        return '标题3';
      case NoteBlockType.bulletList:
        return '无序列表';
      case NoteBlockType.numberedList:
        return '有序列表';
      case NoteBlockType.checklist:
        return '待办';
      case NoteBlockType.quote:
        return '引用';
      case NoteBlockType.codeBlock:
        return '代码块';
      case NoteBlockType.divider:
        return '分割线';
    }
  }
}

/// 内联格式类型
enum InlineFormatType {
  bold,
  italic,
  underline,
  strikethrough,
  inlineCode;

  String toJson() => name;

  static InlineFormatType fromString(String value) {
    return InlineFormatType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => InlineFormatType.bold,
    );
  }
}

/// 内联格式区间
class InlineFormatSpan {
  final int start;
  final int end;
  final Set<InlineFormatType> formats;

  const InlineFormatSpan({
    required this.start,
    required this.end,
    required this.formats,
  });

  Map<String, dynamic> toJson() => {
        's': start,
        'e': end,
        'f': formats.map((f) => f.toJson()).toList(),
      };

  factory InlineFormatSpan.fromJson(Map<String, dynamic> json) {
    return InlineFormatSpan(
      start: json['s'] as int? ?? 0,
      end: json['e'] as int? ?? 0,
      formats: (json['f'] as List<dynamic>?)
              ?.map((f) => InlineFormatType.fromString(f as String))
              .toSet() ??
          {},
    );
  }

  InlineFormatSpan copyWith(
      {int? start, int? end, Set<InlineFormatType>? formats}) {
    return InlineFormatSpan(
      start: start ?? this.start,
      end: end ?? this.end,
      formats: formats ?? Set.from(this.formats),
    );
  }
}

/// 单个内容块
class NoteBlock {
  final String id;
  final NoteBlockType type;
  final String text;
  final Map<String, dynamic> metadata;
  final List<InlineFormatSpan> formatting;

  NoteBlock({
    String? id,
    this.type = NoteBlockType.paragraph,
    this.text = '',
    Map<String, dynamic>? metadata,
    List<InlineFormatSpan>? formatting,
  })  : id = id ?? const Uuid().v4(),
        metadata = metadata ?? {},
        formatting = formatting ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.toJson(),
        'text': text,
        'metadata': metadata,
        'formatting': formatting.map((f) => f.toJson()).toList(),
      };

  factory NoteBlock.fromJson(Map<String, dynamic> json) {
    return NoteBlock(
      id: json['id'] as String?,
      type: NoteBlockType.fromString(json['type'] as String? ?? 'paragraph'),
      text: json['text'] as String? ?? '',
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      formatting: (json['formatting'] as List<dynamic>?)
              ?.map(
                  (f) => InlineFormatSpan.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  NoteBlock copyWith({
    NoteBlockType? type,
    String? text,
    Map<String, dynamic>? metadata,
    List<InlineFormatSpan>? formatting,
  }) {
    return NoteBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      metadata: metadata ?? Map.from(this.metadata),
      formatting: formatting ?? List.from(this.formatting),
    );
  }

  /// 深拷贝
  NoteBlock deepCopy() {
    return NoteBlock(
      id: id,
      type: type,
      text: text,
      metadata: Map.from(metadata),
      formatting: formatting
          .map((f) => InlineFormatSpan(
                start: f.start,
                end: f.end,
                formats: Set.from(f.formats),
              ))
          .toList(),
    );
  }
}

/// Note Plus 文档
///
/// 仿 AppFlowy 的 View 模型：
/// - parentId 指向父文档 ID（空字符串 = 根级文档）
/// - 每个文档既是页面也是容器，支持无限嵌套
class NotePlusDocument {
  final String id;
  final String title;
  final String parentId; // 父文档 ID，空字符串 = 根级
  final int sortIndex; // 同级排序序号
  final List<NoteBlock> blocks;
  final String? blocksJson; // 原始 Delta JSON（flutter_quill 模式优先使用）
  final List<String> tags;
  final List<String> images;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  NotePlusDocument({
    String? id,
    this.title = '',
    this.parentId = '',
    this.sortIndex = 0,
    List<NoteBlock>? blocks,
    this.blocksJson,
    List<String>? tags,
    List<String>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        blocks = blocks ?? [NoteBlock()],
        tags = tags ?? [],
        images = images ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 从 JSON（DB 行）创建
  factory NotePlusDocument.fromJson(Map<String, dynamic> json) {
    final blocksJson = json['blocks_json'] as String? ?? '[]';
    final blocksList = (jsonDecode(blocksJson) as List<dynamic>)
        .map((b) => NoteBlock.fromJson(b as Map<String, dynamic>))
        .toList();

    return NotePlusDocument(
      id: json['id'] as String?,
      title: json['title'] as String? ?? '',
      parentId: json['parent_id'] as String? ?? '',
      sortIndex: json['sort_index'] as int? ?? 0,
      blocks: blocksList.isEmpty ? [NoteBlock()] : blocksList,
      blocksJson: json['blocks_json'] as String?,
      tags: _parseStringList(json['tags'] as String?),
      images: _parseStringList(json['images'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: (json['is_deleted'] as int?) == 1,
    );
  }

  /// 序列化为 DB 行
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'parent_id': parentId,
        'sort_index': sortIndex,
        'blocks_json': blocksJson ?? jsonEncode(blocks.map((b) => b.toJson()).toList()),
        'tags': tags.isEmpty ? null : jsonEncode(tags),
        'images': images.isEmpty ? null : jsonEncode(images),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  NotePlusDocument copyWith({
    String? title,
    String? parentId,
    int? sortIndex,
    List<NoteBlock>? blocks,
    String? blocksJson,
    List<String>? tags,
    List<String>? images,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return NotePlusDocument(
      id: id,
      title: title ?? this.title,
      parentId: parentId ?? this.parentId,
      sortIndex: sortIndex ?? this.sortIndex,
      blocks: blocks ?? List.from(this.blocks),
      blocksJson: blocksJson ?? this.blocksJson,
      tags: tags ?? List.from(this.tags),
      images: images ?? List.from(this.images),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// 深拷贝
  NotePlusDocument deepCopy() {
    return NotePlusDocument(
      id: id,
      title: title,
      parentId: parentId,
      sortIndex: sortIndex,
      blocks: blocks.map((b) => b.deepCopy()).toList(),
      tags: List.from(tags),
      images: List.from(images),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  static List<String> _parseStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
