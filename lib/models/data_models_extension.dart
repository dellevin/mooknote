/// 数据模型扩展 - 添加 copyWith 方法以便更新数据
library;

import 'data_models.dart';

/// Movie 扩展 - 添加 copyWith 方法
extension MovieExtension on Movie {
  /// 创建副本并允许修改部分属性
  Movie copyWith({
    String? id,
    String? title,
    String? poster,
    double? rating,
    int? year,
    String? status,
    DateTime? watchDate,
    String? note,
  }) {
    return Movie(
      id: id ?? this.id,
      title: title ?? this.title,
      poster: poster ?? this.poster,
      rating: rating ?? this.rating,
      year: year ?? this.year,
      status: status ?? this.status,
      watchDate: watchDate ?? this.watchDate,
      note: note ?? this.note,
    );
  }
}

/// Book 扩展 - 添加 copyWith 方法
extension BookExtension on Book {
  /// 创建副本并允许修改部分属性
  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? cover,
    double? rating,
    String? status,
    DateTime? readDate,
    String? note,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      readDate: readDate ?? this.readDate,
      note: note ?? this.note,
    );
  }
}

/// Note 扩展 - 添加 copyWith 方法
extension NoteExtension on Note {
  /// 创建副本并允许修改部分属性
  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
