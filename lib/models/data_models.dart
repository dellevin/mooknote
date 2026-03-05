import 'dart:io';
import 'dart:convert';

/// 影视条目模型
class Movie {
  final String id;
  final String title; // 影视名称
  final String? posterPath; // 本地海报路径
  final DateTime? releaseDate; // 上映时间
  final List<String> directors; // 导演列表
  final List<String> writers; // 编剧列表
  final List<String> actors; // 主演列表
  final List<String> genres; // 类型
  final List<String> alternateTitles; // 别名
  final String? summary; // 剧情简介
  final double? rating; // 评分 1-10
  final String status; // watched/want_to_watch/watching
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Movie({
    required this.id,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.directors = const [],
    this.writers = const [],
    this.actors = const [],
    this.genres = const [],
    this.alternateTitles = const [],
    this.summary,
    this.rating,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      posterPath: json['poster_path'],
      releaseDate: json['release_date'] != null 
          ? DateTime.parse(json['release_date']) 
          : null,
      directors: _parseStringList(json['directors']),
      writers: _parseStringList(json['writers']),
      actors: _parseStringList(json['actors']),
      genres: _parseStringList(json['genres']),
      alternateTitles: _parseStringList(json['alternate_titles']),
      summary: json['summary'],
      rating: json['rating']?.toDouble(),
      status: json['status'] ?? 'want_to_watch',
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
      'poster_path': posterPath,
      'release_date': releaseDate?.toIso8601String(),
      'directors': jsonEncode(directors),
      'writers': jsonEncode(writers),
      'actors': jsonEncode(actors),
      'genres': jsonEncode(genres),
      'alternate_titles': jsonEncode(alternateTitles),
      'summary': summary,
      'rating': rating,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
  
  /// 获取封面文件
  File? get posterFile {
    if (posterPath == null || posterPath!.isEmpty) return null;
    return File(posterPath!);
  }

  /// 解析字符串列表
  static List<String> _parseStringList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    if (data is String) {
      try {
        // 尝试解析JSON字符串
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // 如果解析失败，按逗号分割
        return data.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }
    return [];
  }

  /// 复制并修改
  Movie copyWith({
    String? id,
    String? title,
    String? posterPath,
    DateTime? releaseDate,
    List<String>? directors,
    List<String>? writers,
    List<String>? actors,
    List<String>? genres,
    List<String>? alternateTitles,
    String? summary,
    double? rating,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      releaseDate: releaseDate ?? this.releaseDate,
      directors: directors ?? this.directors,
      writers: writers ?? this.writers,
      actors: actors ?? this.actors,
      genres: genres ?? this.genres,
      alternateTitles: alternateTitles ?? this.alternateTitles,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
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

