/// 阅读器书籍模型
class ReaderBook {
  final String id;
  final String title;
  final String author;
  final String? coverPath;
  final String filePath; // 相对路径
  final String fileName;
  final String fileExtension;
  final String lastReadCfi;
  final double readingPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  ReaderBook({
    required this.id,
    required this.title,
    this.author = '',
    this.coverPath,
    required this.filePath,
    required this.fileName,
    required this.fileExtension,
    this.lastReadCfi = '',
    this.readingPercentage = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory ReaderBook.fromJson(Map<String, dynamic> json) {
    return ReaderBook(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      coverPath: json['cover_path'],
      filePath: json['file_path'] ?? '',
      fileName: json['file_name'] ?? '',
      fileExtension: json['file_extension'] ?? 'epub',
      lastReadCfi: json['last_read_cfi'] ?? '',
      readingPercentage: (json['reading_percentage'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover_path': coverPath,
      'file_path': filePath,
      'file_name': fileName,
      'file_extension': fileExtension,
      'last_read_cfi': lastReadCfi,
      'reading_percentage': readingPercentage,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  ReaderBook copyWith({
    String? id,
    String? title,
    String? author,
    Object? coverPath = _readerBookCopyWithNull,
    String? filePath,
    String? fileName,
    String? fileExtension,
    String? lastReadCfi,
    double? readingPercentage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ReaderBook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath is _ReaderBookCopyWithNullSentinel ? this.coverPath : (coverPath as String?),
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      lastReadCfi: lastReadCfi ?? this.lastReadCfi,
      readingPercentage: readingPercentage ?? this.readingPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class _ReaderBookCopyWithNullSentinel {
  const _ReaderBookCopyWithNullSentinel();
}

const _readerBookCopyWithNull = _ReaderBookCopyWithNullSentinel();
