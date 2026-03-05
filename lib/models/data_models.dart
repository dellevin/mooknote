/// 影视条目模型
class Movie {
  final String id;
  final String title;
  final String? poster;
  final double? rating;
  final int? year;
  final String status; // 'watched', 'want_to_watch', 'watching'
  final DateTime? watchDate;
  final String? note;

  Movie({
    required this.id,
    required this.title,
    this.poster,
    this.rating,
    this.year,
    required this.status,
    this.watchDate,
    this.note,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      poster: json['poster'],
      rating: json['rating']?.toDouble(),
      year: json['year'],
      status: json['status'] ?? 'want_to_watch',
      watchDate: json['watch_date'] != null 
          ? DateTime.parse(json['watch_date']) 
          : null,
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster': poster,
      'rating': rating,
      'year': year,
      'status': status,
      'watch_date': watchDate?.toIso8601String(),
      'note': note,
    };
  }
}

/// 书籍条目模型
class Book {
  final String id;
  final String title;
  final String? author;
  final String? cover;
  final double? rating;
  final String status; // 'read', 'reading', 'want_to_read'
  final DateTime? readDate;
  final String? note;

  Book({
    required this.id,
    required this.title,
    this.author,
    this.cover,
    this.rating,
    required this.status,
    this.readDate,
    this.note,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'],
      cover: json['cover'],
      rating: json['rating']?.toDouble(),
      status: json['status'] ?? 'want_to_read',
      readDate: json['read_date'] != null 
          ? DateTime.parse(json['read_date']) 
          : null,
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'cover': cover,
      'rating': rating,
      'status': status,
      'read_date': readDate?.toIso8601String(),
      'note': note,
    };
  }
}

/// 笔记模型
class Note {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      tags: json['tags'] != null 
          ? List<String>.from(json['tags']) 
          : [],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
