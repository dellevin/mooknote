/// 书籍批注数据模型 — 高亮、下划线、书签
class BookAnnotation {
  final int? id;
  final String bookId;
  final String content;    // 选中的文字内容
  final String cfi;        // EPUB CFI 位置
  final String chapter;    // 章节标题
  final String type;       // 'highlight' | 'underline' | 'bookmark'
  final String color;      // 颜色 hex，如 'FFEB3B'
  final String? readerNote; // 用户附注
  final DateTime createdAt;
  final DateTime updatedAt;

  BookAnnotation({
    this.id,
    required this.bookId,
    required this.content,
    required this.cfi,
    this.chapter = '',
    required this.type,
    required this.color,
    this.readerNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'content': content,
      'cfi': cfi,
      'chapter': chapter,
      'type': type,
      'color': color,
      'reader_note': readerNote ?? '',
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BookAnnotation.fromMap(Map<String, dynamic> map) {
    return BookAnnotation(
      id: map['id'] as int?,
      bookId: map['book_id'] as String,
      content: map['content'] as String? ?? '',
      cfi: map['cfi'] as String? ?? '',
      chapter: map['chapter'] as String? ?? '',
      type: map['type'] as String? ?? 'highlight',
      color: map['color'] as String? ?? 'FFEB3B',
      readerNote: map['reader_note'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// 用于 JS bridge 的 JSON（传给 foliate-js renderAnnotations）
  Map<String, dynamic> toJson() {
    return {
      'id': id ?? 0,
      'type': type,
      'value': cfi,
      'color': '#$color',
      'note': content,
    };
  }

  BookAnnotation copyWith({
    int? id,
    String? bookId,
    String? content,
    String? cfi,
    String? chapter,
    String? type,
    String? color,
    String? readerNote,
  }) {
    return BookAnnotation(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      cfi: cfi ?? this.cfi,
      chapter: chapter ?? this.chapter,
      type: type ?? this.type,
      color: color ?? this.color,
      readerNote: readerNote ?? this.readerNote,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
