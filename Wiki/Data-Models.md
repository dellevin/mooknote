# 数据模型

所有数据模型定义在 `lib/models/data_models.dart` 中。

## 模型总览

| 模型 | 说明 | 关键字段 |
|------|------|---------|
| `Movie` | 影视条目 | title, posterPath, directors, actors, genres, rating, status |
| `Book` | 书籍条目 | title, coverPath, authors, publisher, genres, rating, status, isbn |
| `Note` | 笔记 | title, content, contentType, tags, images |
| `MovieReview` | 影评 | movieId, content, reviewer, source, reviewType (1=短评, 2=长评) |
| `BookReview` | 书评 | bookId, content, reviewer, source, reviewType |
| `MoviePoster` | 影视海报 | movieId, posterPath |
| `BookExcerpt` | 书籍摘抄 | bookId, chapter, content, comment |

## 公共字段

所有实体模型都包含：
- `id` — UUID 字符串（创建时生成）
- `isDeleted` — 软删除标记（0/1）
- `createdAt` / `updatedAt` — ISO 8601 时间戳（UTC）

## copyWith 模式

模型使用 `_CopyWithNullSentinel` 区分"未传参"和"传了 null"：

```dart
class _CopyWithNullSentinel {
  const _CopyWithNullSentinel();
}
const _copyWithNull = _CopyWithNullSentinel();

// 用法示例
Movie copyWith({
  Object? posterPath = _copyWithNull,  // 未传参时保留原值
  Object? summary = _copyWithNull,     // 传 null 时清除值
}) { ... }
```

这样 `movie.copyWith(title: '新标题')` 不会意外清空 `posterPath`。

## JSON 编码列表字段

`directors`、`actors`、`genres`、`tags` 等列表字段在 SQLite 中存储为 JSON 字符串：

```dart
// 序列化
'genres': jsonEncode(['科幻', '动作'])

// 反序列化
static List<String> parseStringList(dynamic data) {
  if (data == null) return [];
  if (data is List) return data.map((e) => e.toString()).toList();
  if (data is String) {
    final decoded = jsonDecode(data);
    if (decoded is List) return decoded.map((e) => e.toString()).toList();
  }
  return [];
}
```

## 状态值

### 影视状态 (Movie.status)
| 值 | 含义 |
|----|------|
| `want_to_watch` | 想看 |
| `watching` | 在看 |
| `watched` | 已看 |

### 书籍状态 (Book.status)
| 值 | 含义 |
|----|------|
| `want_to_read` | 想读 |
| `reading` | 在读 |
| `read` | 已读 |

## SQLite 表结构

数据库文件：`mooknote.db`，当前版本：13

### movies 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| title | TEXT NOT NULL | 标题 |
| poster_path | TEXT | 海报本地路径 |
| release_date | TEXT | 上映日期 |
| directors | TEXT | JSON 数组 |
| writers | TEXT | JSON 数组 |
| actors | TEXT | JSON 数组 |
| genres | TEXT | JSON 数组 |
| alternate_titles | TEXT | JSON 数组 |
| summary | TEXT | 剧情简介 |
| rating | REAL | 评分 1-10 |
| status | TEXT NOT NULL | 状态 |
| watch_date | TEXT | 观看日期 |
| created_at | TEXT NOT NULL | 创建时间 |
| updated_at | TEXT NOT NULL | 更新时间 |
| is_deleted | INTEGER DEFAULT 0 | 软删除 |

### books 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| title | TEXT NOT NULL | 标题 |
| cover_path | TEXT | 封面本地路径 |
| authors | TEXT | JSON 数组 |
| alternate_titles | TEXT | JSON 数组 |
| publisher | TEXT | 出版社 |
| genres | TEXT | JSON 数组 |
| summary | TEXT | 简介 |
| rating | REAL | 评分 1-10 |
| status | TEXT NOT NULL | 状态 |
| isbn | TEXT | ISBN |
| publish_date | TEXT | 出版日期 |
| created_at | TEXT NOT NULL | 创建时间 |
| updated_at | TEXT NOT NULL | 更新时间 |
| is_deleted | INTEGER DEFAULT 0 | 软删除 |

### notes 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| title | TEXT DEFAULT '' | 标题 |
| content | TEXT NOT NULL | 内容 |
| content_type | TEXT DEFAULT 'markdown' | 内容类型 |
| tags | TEXT | JSON 数组 |
| images | TEXT | JSON 数组（图片路径列表）|
| created_at | TEXT NOT NULL | 创建时间 |
| updated_at | TEXT NOT NULL | 更新时间 |
| is_deleted | INTEGER DEFAULT 0 | 软删除 |

### movie_reviews 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| movie_id | TEXT NOT NULL FK | 关联影视 ID |
| content | TEXT NOT NULL | 评论内容 |
| reviewer | TEXT | 评论者 |
| source | TEXT | 来源 |
| review_type | INTEGER DEFAULT 1 | 1=短评, 2=长评 |
| is_deleted | INTEGER DEFAULT 0 | 软删除 |
| created_at / updated_at | TEXT | 时间戳 |

### book_reviews 表（结构同 movie_reviews，外键为 book_id）

### movie_posters 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| movie_id | TEXT NOT NULL FK | 关联影视 ID |
| poster_path | TEXT NOT NULL | 海报本地路径 |
| is_deleted | INTEGER DEFAULT 0 | 软删除 |
| created_at | TEXT | 创建时间 |

### book_excerpts 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| book_id | TEXT NOT NULL FK | 关联书籍 ID |
| chapter | TEXT | 章节 |
| content | TEXT NOT NULL | 摘抄内容 |
| comment | TEXT | 感悟评论 |
| is_deleted | INTEGER DEFAULT 0 | 软删除 |
| created_at / updated_at | TEXT | 时间戳 |

### tags 表

| 列名 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | 标签名 |
| type | TEXT NOT NULL | movie_genre / book_genre / note_tag |
| created_at | TEXT NOT NULL | 创建时间 |
| UNIQUE | (name, type) | 同类型标签名唯一 |

## 数据库迁移链

| 版本 | 变更 |
|------|------|
| v1 | 初始版本 |
| v2 | 升级 movies 表结构（添加 directors, writers, actors, genres 等字段）|
| v3 | 升级 books 表结构（拆分 author → authors, 添加 alternateTitles, publisher, genres）|
| v4 | 重建 notes 表（添加 content_type 字段）|
| v5 | 创建 movie_reviews 和 movie_posters 表 |
| v6 | 为 notes 表添加 is_deleted 字段 |
| v7 | 创建 book_reviews 和 book_excerpts 表 |
| v8 | 确保 book_reviews/book_excerpts 存在（兼容修复）|
| v9 | 为 notes 表添加 images 字段 |
| v10 | 为 movies 表添加 watch_date 字段 |
| v11 | 为 books 表添加 isbn 和 publish_date 字段 |
| v12 | 确保 notes 表有 title 列 |
| v13 | 创建 tags 表并回填已有数据 |

[返回首页](Home.md)
