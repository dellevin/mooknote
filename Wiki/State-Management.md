# 状态管理

## AppProvider

`AppProvider`（`lib/providers/app_provider.dart`）是应用唯一的 ChangeNotifier，通过 `MultiProvider` 在根节点注入，所有页面通过 `context.watch<AppProvider>()` 或 `context.read<AppProvider>()` 访问。

## 管理的状态

### 数据列表

| 字段 | 类型 | 说明 |
|------|------|------|
| `_movies` | `List<Movie>` | 影视数据 |
| `_books` | `List<Book>` | 书籍数据 |
| `_notes` | `List<Note>` | 笔记数据 |

### UI 状态

| 字段 | 类型 | 说明 |
|------|------|------|
| `_mainTabIndex` | `int` | 主标签页（0=观影, 1=阅读, 2=笔记）|
| `_bottomNavIndex` | `int` | 底部导航（0=主页, 1=新增, 2=我的）|
| `_bottomNavVisible` | `bool` | 底部导航栏可见性 |
| `_themeMode` | `ThemeMode` | 主题模式 |
| `_movieStatusIndex` | `int` | 影视状态筛选（0=已看, 1=想看, 2=在看）|
| `_bookStatusIndex` | `int` | 书籍状态筛选（0=读完, 1=在读, 2=准备读）|
| `_drawerOpen` | `bool` | 侧边菜单状态 |

### DAO 实例

```dart
final MovieDao _movieDao = MovieDao();
final BookDao _bookDao = BookDao();
final NoteDao _noteDao = NoteDao();
final MovieReviewDao _reviewDao = MovieReviewDao();
final MoviePosterDao _posterDao = MoviePosterDao();
final BookReviewDao _bookReviewDao = BookReviewDao();
final BookExcerptDao _bookExcerptDao = BookExcerptDao();
final TagDao _tagDao = TagDao();
```

## 数据加载

### 全量加载

```dart
initDatabase() → loadMovies() + loadBooks() + loadNotes()
```

根据 `_useRemote` 决定从本地 SQLite 或远程 API 加载。

### 分页加载

分页大小：`_pageSize = 20`

```dart
loadMoviesPaged({String? status, required int offset})
loadBooksPaged({String? status, required int offset})
loadNotesPaged({required int offset})
```

供列表页触底加载使用。

## CRUD 操作

所有 CRUD 方法都走双路径（本地/远程），并自动重新加载数据：

```dart
addMovie(Movie movie)    → 本地: _movieDao.insertMovie / 远程: ServerDataService.saveMovie → loadMovies()
updateMovie(Movie movie) → 本地: _movieDao.updateMovie / 远程: ServerDataService.saveMovie → loadMovies()
removeMovie(String id)   → 本地: _movieDao.deleteMovie  / 远程: ServerDataService.deleteMovie → loadMovies()
```

Book、Note 同理。远程模式下还会自动上传关联图片。

## 子实体操作

影评、海报、书评、摘抄的 CRUD 方法不直接修改内存列表，而是按需查询：

```dart
getMovieReviews(movieId) / addMovieReview(review) / updateMovieReview(review) / removeMovieReview(id)
getMoviePosters(movieId)  / addMoviePoster(poster) / removeMoviePoster(id)
getBookReviews(bookId)    / addBookReview(review)  / updateBookReview(review) / removeBookReview(id)
getBookExcerpts(bookId)   / addBookExcerpt(excerpt) / updateBookExcerpt(excerpt) / removeBookExcerpt(id)
```

## 回收站

```dart
getDeletedMovies() / restoreMovie(id) / permanentDeleteMovie(id)
getDeletedBooks()  / restoreBook(id)  / permanentDeleteBook(id)
getDeletedNotes()  / restoreNote(id)  / permanentDeleteNote(id)
clearRecycleBin()  // 清空所有已删除条目
```

永久删除时会同时清理关联图片目录。

## 标签管理

```dart
getTags(type)                                    // 获取某类型标签
addTag(name, type)                               // 添加标签
renameTag(tagId, newName, type)                  // 重命名（级联更新关联条目）
deleteTag(tagId, type, {replacementName})        // 删除（可替换关联条目的标签名）
deleteTagOnly(tagId, type)                       // 仅删除标签本身，不影响条目
syncTagsFromData()                               // 从现有数据回填标签表
```

标签类型：`movie_genre`、`book_genre`、`note_tag`。

[返回首页](Home.md)
