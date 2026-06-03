# 数据访问层

## DAO 模式

每个实体有独立的 DAO 类，封装 SQLite CRUD 操作：

| DAO | 文件 | 实体 |
|-----|------|------|
| `MovieDao` | `lib/utils/movie/movie_dao.dart` | Movie |
| `BookDao` | `lib/utils/book/book_dao.dart` | Book |
| `NoteDao` | `lib/utils/note/note_dao.dart` | Note |
| `MovieReviewDao` | `lib/utils/movie/movie_review_dao.dart` | MovieReview |
| `MoviePosterDao` | `lib/utils/movie/movie_poster_dao.dart` | MoviePoster |
| `BookReviewDao` | `lib/utils/book/book_review_dao.dart` | BookReview |
| `BookExcerptDao` | `lib/utils/book/book_excerpt_dao.dart` | BookExcerpt |
| `TagDao` | `lib/utils/tag/tag_dao.dart` | Tag |

## DatabaseHelper

`lib/utils/database_helper.dart` — SQLite 数据库单例管理器。

```dart
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  Future<Database> get database;        // 获取数据库实例（懒初始化）
  Future<void> reopenDatabase();        // 关闭并重新打开（WebDAV 同步后调用）
  Future<void> close();                 // 关闭数据库
}
```

- 数据库文件名：`mooknote.db`
- 当前版本：13
- 初始化时执行 `_createDB`，版本不匹配时执行 `_onUpgrade` 迁移链

## DAO 通用方法

以 `MovieDao` 为例：

```dart
getAllMovies()                                    // 获取所有未删除记录
getMoviesPaged({status, limit, offset})           // 分页查询
getMoviesByStatus(status)                         // 按状态筛选
getMoviesByDirector(director)                     // 按导演筛选
getMoviesByActor(actor)                           // 按演员筛选
insertMovie(movie)                                // 插入
updateMovie(movie)                                // 更新
deleteMovie(id)                                   // 软删除
getDeletedMovies()                                // 获取已删除记录
restoreMovie(id)                                  // 恢复
permanentDeleteMovie(id)                          // 彻底删除
```

## 软删除机制

所有实体使用 `is_deleted` 字段实现软删除：

```
删除操作 → UPDATE SET is_deleted = 1 WHERE id = ?
查询操作 → WHERE is_deleted = 0
恢复操作 → UPDATE SET is_deleted = 0 WHERE id = ?
彻底删除 → DELETE FROM table WHERE id = ?
```

回收站页面（`lib/pages/recycle_bin_page.dart`）展示所有 `is_deleted = 1` 的记录，支持恢复和彻底删除。

## TagDao

标签 DAO 管理 `tags` 表，支持：

- `getTagsByType(type)` — 获取某类型所有标签
- `addTag(name, type)` — 添加标签（UNIQUE 约束防重复）
- `renameTag(tagId, newName)` — 重命名标签并级联更新关联条目
- `deleteTag(tagId, {replacementName})` — 删除标签，可选替换关联条目中的标签名
- `deleteTagOnly(tagId)` — 仅删除标签记录，不修改关联条目
- `getTagById(tagId)` — 获取单个标签

标签级联逻辑：重命名或删除标签时，会遍历关联实体表（movies.genres / books.genres / notes.tags），将旧标签名替换为新名称或移除。

[返回首页](Home.md)
