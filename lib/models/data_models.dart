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

  /// 解析字符串列表（公共静态方法，供Book使用）
  static List<String> parseStringList(dynamic data) {
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
  
  /// 解析字符串列表（私有别名，保持兼容性）
  static List<String> _parseStringList(dynamic data) => parseStringList(data);

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
  final String title; // 书籍名称
  final String? coverPath; // 本地封面路径
  final List<String> authors; // 作者列表
  final List<String> alternateTitles; // 别名
  final String? publisher; // 出版社
  final List<String> genres; // 类型
  final String? summary; // 书籍简介
  final double? rating; // 评分 1-10
  final String status; // read/reading/want_to_read
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Book({
    required this.id,
    required this.title,
    this.coverPath,
    this.authors = const [],
    this.alternateTitles = const [],
    this.publisher,
    this.genres = const [],
    this.summary,
    this.rating,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverPath: json['cover_path'],
      authors: Movie.parseStringList(json['authors']),
      alternateTitles: Movie.parseStringList(json['alternate_titles']),
      publisher: json['publisher'],
      genres: Movie.parseStringList(json['genres']),
      summary: json['summary'],
      rating: json['rating']?.toDouble(),
      status: json['status'] ?? 'want_to_read',
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
      'cover_path': coverPath,
      'authors': jsonEncode(authors),
      'alternate_titles': jsonEncode(alternateTitles),
      'publisher': publisher,
      'genres': jsonEncode(genres),
      'summary': summary,
      'rating': rating,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
  
  /// 获取封面文件
  File? get coverFile {
    if (coverPath == null || coverPath!.isEmpty) return null;
    return File(coverPath!);
  }

  /// 复制并修改
  Book copyWith({
    String? id,
    String? title,
    String? coverPath,
    List<String>? authors,
    List<String>? alternateTitles,
    String? publisher,
    List<String>? genres,
    String? summary,
    double? rating,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      coverPath: coverPath ?? this.coverPath,
      authors: authors ?? this.authors,
      alternateTitles: alternateTitles ?? this.alternateTitles,
      publisher: publisher ?? this.publisher,
      genres: genres ?? this.genres,
      summary: summary ?? this.summary,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

/// 笔记模型
class Note {
  final String id;
  final String content;
  final String contentType; // markdown / rich_text
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.content,
    this.contentType = 'markdown',
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      contentType: json['content_type'] ?? 'markdown',
      tags: Movie.parseStringList(json['tags']),
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
      'content': content,
      'content_type': contentType,
      'tags': jsonEncode(tags),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  /// 复制并修改
  Note copyWith({
    String? id,
    String? content,
    String? contentType,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// 获取内容摘要（前100字）
  String get summary {
    if (content.length <= 100) return content;
    return '${content.substring(0, 100)}...';
  }
}

/// 影评模型
class MovieReview {
  final String id;
  final String movieId;
  final String content;
  final String reviewer;
  final String source;
  final int reviewType; // 1: 短评, 2: 长评
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  MovieReview({
    required this.id,
    required this.movieId,
    required this.content,
    this.reviewer = '',
    this.source = '',
    this.reviewType = 1,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MovieReview.fromJson(Map<String, dynamic> json) {
    return MovieReview(
      id: json['id']?.toString() ?? '',
      movieId: json['movie_id']?.toString() ?? '',
      content: json['content'] ?? '',
      reviewer: json['reviewer'] ?? '',
      source: json['source'] ?? '',
      reviewType: json['review_type'] ?? 1,
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
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
      'movie_id': movieId,
      'content': content,
      'reviewer': reviewer,
      'source': source,
      'review_type': reviewType,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  /// 复制并修改
  MovieReview copyWith({
    String? id,
    String? movieId,
    String? content,
    String? reviewer,
    String? source,
    int? reviewType,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MovieReview(
      id: id ?? this.id,
      movieId: movieId ?? this.movieId,
      content: content ?? this.content,
      reviewer: reviewer ?? this.reviewer,
      source: source ?? this.source,
      reviewType: reviewType ?? this.reviewType,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  
  /// 获取评论摘要
  String get summary {
    if (content.length <= 50) return content;
    return '${content.substring(0, 50)}...';
  }
  
  /// 评论类型文本
  String get typeText => reviewType == 1 ? '短评' : '长评';
}

/// 影视海报墙模型
class MoviePoster {
  final String id;
  final String movieId;
  final String posterPath;
  final bool isDeleted;
  final DateTime createdAt;

  MoviePoster({
    required this.id,
    required this.movieId,
    required this.posterPath,
    this.isDeleted = false,
    required this.createdAt,
  });

  factory MoviePoster.fromJson(Map<String, dynamic> json) {
    return MoviePoster(
      id: json['id']?.toString() ?? '',
      movieId: json['movie_id']?.toString() ?? '',
      posterPath: json['poster_path'] ?? '',
      isDeleted: json['is_deleted'] == 1 || json['is_deleted'] == true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'movie_id': movieId,
      'poster_path': posterPath,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  /// 获取海报文件
  File? get posterFile {
    if (posterPath.isEmpty) return null;
    return File(posterPath);
  }
}

