/// 数据模型扩展 - 添加 copyWith 方法以便更新数据
library;

import 'data_models.dart';

/// Movie 扩展 - 添加 copyWith 方法
extension MovieExtension on Movie {
  /// 创建副本并允许修改部分属性
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

/// Book 扩展 - 添加 copyWith 方法
extension BookExtension on Book {
  /// 创建副本并允许修改部分属性
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

/// Note 扩展 - 添加 copyWith 方法
extension NoteExtension on Note {
  /// 创建副本并允许修改部分属性
  Note copyWith({
    String? id,
    String? content,
    String? contentType,
    List<String>? tags,
    List<String>? images,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Note(
      id: id ?? this.id,
      content: content ?? this.content,
      contentType: contentType ?? this.contentType,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
