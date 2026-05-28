import 'dart:io';
import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../utils/movie/movie_dao.dart';
import '../utils/book/book_dao.dart';
import '../utils/note/note_dao.dart';
import '../utils/movie/movie_review_dao.dart';
import '../utils/movie/movie_poster_dao.dart';
import '../utils/book/book_review_dao.dart';
import '../utils/book/book_excerpt_dao.dart';
import '../utils/tag/tag_dao.dart';
import '../utils/database_helper.dart';
import '../utils/image_path_helper.dart';
import '../utils/user_prefs.dart';
import '../utils/sync/server_data_service.dart';

/// 应用全局状态管理
class AppProvider extends ChangeNotifier {
  // 数据库访问对象
  final MovieDao _movieDao = MovieDao();
  final BookDao _bookDao = BookDao();
  final NoteDao _noteDao = NoteDao();
  final MovieReviewDao _reviewDao = MovieReviewDao();
  final MoviePosterDao _posterDao = MoviePosterDao();
  final BookReviewDao _bookReviewDao = BookReviewDao();
  final BookExcerptDao _bookExcerptDao = BookExcerptDao();
  final TagDao _tagDao = TagDao();
  
  // 数据列表
  List<Movie> _movies = [];
  List<Book> _books = [];
  List<Note> _notes = [];
  
  // 当前主界面选中的标签 (0: 观影，1: 阅读，2: 笔记)
  int _mainTabIndex = 0;

  // 当前底部导航选中的索引 (0: 主页，1: 新增，2: 我的)
  int _bottomNavIndex = 0;

  // 底部导航栏是否可见
  bool _bottomNavVisible = true;

  // 主题模式
  ThemeMode _themeMode = ThemeMode.system;

  /// 是否使用远程服务端（同步开关 + 已激活）
  bool get _useRemote {
    final prefs = UserPrefs();
    return prefs.syncEnabled &&
        prefs.syncServerUrl.isNotEmpty &&
        prefs.syncActivationCode.isNotEmpty &&
        ServerDataService.instance.isAvailable;
  }
  
  // 观影选中的状态 (0: 已看，1: 想看，2: 在看)
  int _movieStatusIndex = 0;
  
  // 阅读选中的状态 (0: 读完，1: 在读，2: 准备读)
  int _bookStatusIndex = 0;
  
  // 侧边菜单是否打开
  bool _drawerOpen = false;
  
  // 初始化数据库
  Future<void> initDatabase() async {
    debugPrint('[AppProvider] initDatabase, _useRemote=$_useRemote');
    if (_useRemote) {
      // 同步模式：从服务端拉取数据
      await Future.wait([loadMovies(), loadBooks(), loadNotes()]);
      return;
    }
    final results = await Future.wait([
      _movieDao.getAllMovies(),
      _bookDao.getAllBooks(),
      _noteDao.getAllNotes(),
    ]);
    _movies = results[0] as List<Movie>;
    _books = results[1] as List<Book>;
    _notes = results[2] as List<Note>;
    debugPrint('[AppProvider] 本地数据: movies=${_movies.length}, books=${_books.length}, notes=${_notes.length}');
    notifyListeners();
  }

  // 从用户偏好恢复默认启动标签
  void initMainTabIndex() {
    final userPrefs = UserPrefs();
    final defaultIndex = userPrefs.defaultMainTabIndex;
    // 确保选中的标签是启用的
    final showMovie = userPrefs.showMovieTab;
    final showBook = userPrefs.showBookTab;
    final showNote = userPrefs.showNoteTab;
    final enabled = [showMovie, showBook, showNote];
    if (enabled[defaultIndex]) {
      _mainTabIndex = defaultIndex;
    } else {
      // 回退到第一个启用的标签
      if (showMovie) {
        _mainTabIndex = 0;
      } else if (showBook) {
        _mainTabIndex = 1;
      } else {
        _mainTabIndex = 2;
      }
    }
    notifyListeners();
  }
  
  // 加载影视数据
  Future<void> loadMovies() async {
    if (_useRemote) {
      debugPrint('[AppProvider] loadMovies from server');
      _movies = await ServerDataService.instance.getMovies();
      debugPrint('[AppProvider] server movies: ${_movies.length}');
      notifyListeners();
      return;
    }
    _movies = await _movieDao.getAllMovies();
    notifyListeners();
  }
  
  // 加载书籍数据
  Future<void> loadBooks() async {
    if (_useRemote) {
      debugPrint('[AppProvider] loadBooks from server');
      _books = await ServerDataService.instance.getBooks();
      debugPrint('[AppProvider] server books: ${_books.length}');
      notifyListeners();
      return;
    }
    _books = await _bookDao.getAllBooks();
    notifyListeners();
  }

  // 加载笔记数据
  Future<void> loadNotes() async {
    if (_useRemote) {
      debugPrint('[AppProvider] loadNotes from server');
      _notes = await ServerDataService.instance.getNotes();
      debugPrint('[AppProvider] server notes: ${_notes.length}');
      notifyListeners();
      return;
    }
    _notes = await _noteDao.getAllNotes();
    notifyListeners();
  }

  // ─── 分页加载（供列表页触底加载使用）────────────────────────
  static const int _pageSize = 20;

  Future<List<Movie>> loadMoviesPaged({String? status, required int offset}) async {
    if (_useRemote) {
      return ServerDataService.instance.getMovies(status: status, limit: _pageSize, offset: offset);
    }
    return _movieDao.getMoviesPaged(status: status, limit: _pageSize, offset: offset);
  }

  Future<List<Book>> loadBooksPaged({String? status, required int offset}) async {
    if (_useRemote) {
      return ServerDataService.instance.getBooks(status: status, limit: _pageSize, offset: offset);
    }
    return _bookDao.getBooksPaged(status: status, limit: _pageSize, offset: offset);
  }

  Future<List<Note>> loadNotesPaged({required int offset}) async {
    if (_useRemote) {
      return ServerDataService.instance.getNotes(limit: _pageSize, offset: offset);
    }
    return _noteDao.getNotesPaged(limit: _pageSize, offset: offset);
  }

  // Getters
  int get mainTabIndex => _mainTabIndex;
  int get bottomNavIndex => _bottomNavIndex;
  int get movieStatusIndex => _movieStatusIndex;
  int get bookStatusIndex => _bookStatusIndex;
  bool get drawerOpen => _drawerOpen;
  bool get bottomNavVisible => _bottomNavVisible;
  ThemeMode get themeMode => _themeMode;
  List<Movie> get movies => _movies;
  List<Book> get books => _books;
  List<Note> get notes => _notes;
  
  // 根据状态获取影视列表
  List<Movie> getMoviesByStatus(String status) {
    return _movies.where((movie) => movie.status == status).toList();
  }
  
  // 根据状态获取书籍列表
  List<Book> getBooksByStatus(String status) {
    return _books.where((book) => book.status == status).toList();
  }

  // Setters
  void setMainTabIndex(int index) {
    _mainTabIndex = index;
    notifyListeners();
  }

  void setBottomNavIndex(int index) {
    _bottomNavIndex = index;
    _bottomNavVisible = true; // 切换页面时自动显示导航栏
    notifyListeners();
  }

  void setBottomNavVisible(bool visible) {
    if (_bottomNavVisible != visible) {
      _bottomNavVisible = visible;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void loadThemeMode() {
    final prefs = UserPrefs();
    switch (prefs.themeMode) {
      case 1:
        _themeMode = ThemeMode.light;
      case 2:
        _themeMode = ThemeMode.dark;
      default:
        _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setMovieStatusIndex(int index) {
    _movieStatusIndex = index;
    notifyListeners();
  }

  void setBookStatusIndex(int index) {
    _bookStatusIndex = index;
    notifyListeners();
  }

  void toggleDrawer() {
    _drawerOpen = !_drawerOpen;
    notifyListeners();
  }

  void closeDrawer() {
    _drawerOpen = false;
    notifyListeners();
  }
  
  // ─── 图片上传辅助 ────────────────────────────────────────────────

  Future<void> _uploadImagesIfRemote(List<String?> paths) async {
    if (!_useRemote) return;
    final valid = paths.where((p) => p != null && p!.isNotEmpty).cast<String>().toList();
    if (valid.isEmpty) return;
    final exist = <String>[];
    for (final p in valid) {
      if (File(p).existsSync()) exist.add(p);
    }
    if (exist.isNotEmpty) {
      await ServerDataService.uploadLocalImages(exist);
    }
  }

  // 添加影视记录
  Future<void> addMovie(Movie movie) async {
    if (_useRemote) {
      await ServerDataService.instance.saveMovie(movie);
    } else {
      await _movieDao.insertMovie(movie);
    }
    await _uploadImagesIfRemote([movie.posterPath]);
    await loadMovies();
  }

  Future<void> updateMovie(Movie movie) async {
    if (_useRemote) {
      await ServerDataService.instance.saveMovie(movie);
    } else {
      await _movieDao.updateMovie(movie);
    }
    await _uploadImagesIfRemote([movie.posterPath]);
    await loadMovies();
  }

  Future<void> removeMovie(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.deleteMovie(id);
    } else {
      await _movieDao.deleteMovie(id);
    }
    await loadMovies();
  }

  Future<void> addBook(Book book) async {
    if (_useRemote) {
      await ServerDataService.instance.saveBook(book);
    } else {
      await _bookDao.insertBook(book);
    }
    await _uploadImagesIfRemote([book.coverPath]);
    await loadBooks();
  }

  Future<void> updateBook(Book book) async {
    if (_useRemote) {
      await ServerDataService.instance.saveBook(book);
    } else {
      await _bookDao.updateBook(book);
    }
    await _uploadImagesIfRemote([book.coverPath]);
    await loadBooks();
  }

  Future<void> removeBook(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.deleteBook(id);
    } else {
      await _bookDao.deleteBook(id);
    }
    await loadBooks();
  }

  Future<void> addNote(Note note) async {
    if (_useRemote) {
      await ServerDataService.instance.saveNote(note);
    } else {
      await _noteDao.insertNote(note);
    }
    await _uploadImagesIfRemote(note.images);
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    if (_useRemote) {
      await ServerDataService.instance.saveNote(note);
    } else {
      await _noteDao.updateNote(note);
    }
    await _uploadImagesIfRemote(note.images);
    await loadNotes();
  }

  Future<void> removeNote(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.deleteNote(id);
    } else {
      await _noteDao.deleteNote(id);
    }
    await loadNotes();
  }
  
  // ========== 影评相关方法 ==========

  /// 获取影视的所有影评
  Future<List<MovieReview>> getMovieReviews(String movieId) async {
    if (_useRemote) return await ServerDataService.instance.getMovieReviews(movieId);
    return await _reviewDao.getReviewsByMovieId(movieId);
  }

  /// 添加影评
  Future<void> addMovieReview(MovieReview review) async {
    if (_useRemote) await ServerDataService.instance.saveMovieReview(review);
    else await _reviewDao.insertReview(review);
  }

  /// 更新影评
  Future<void> updateMovieReview(MovieReview review) async {
    if (_useRemote) await ServerDataService.instance.saveMovieReview(review);
    else await _reviewDao.updateReview(review);
  }

  /// 删除影评
  Future<void> removeMovieReview(String id) async {
    if (_useRemote) await ServerDataService.instance.deleteMovieReview(id);
    else await _reviewDao.deleteReview(id);
  }

  /// 获取影视的影评数量
  Future<int> getMovieReviewCount(String movieId) async {
    if (_useRemote) {
      final reviews = await ServerDataService.instance.getMovieReviews(movieId);
      return reviews.length;
    }
    return await _reviewDao.getReviewCount(movieId);
  }

  // ========== 海报墙相关方法 ==========

  /// 获取影视的所有海报
  Future<List<MoviePoster>> getMoviePosters(String movieId) async {
    if (_useRemote) return await ServerDataService.instance.getMoviePosters(movieId);
    return await _posterDao.getPostersByMovieId(movieId);
  }

  /// 添加海报
  Future<void> addMoviePoster(MoviePoster poster) async {
    if (_useRemote) await ServerDataService.instance.saveMoviePoster(poster);
    else await _posterDao.insertPoster(poster);
  }

  /// 删除海报
  Future<void> removeMoviePoster(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.deleteMoviePoster(id);
      return;
    }
    final poster = await _posterDao.getPosterById(id);
    if (poster != null) {
      await ImagePathHelper.instance.deleteFile(poster.posterPath);
    }
    await _posterDao.deletePoster(id);
  }

  /// 获取影视的海报数量
  Future<int> getMoviePosterCount(String movieId) async {
    if (_useRemote) {
      final posters = await ServerDataService.instance.getMoviePosters(movieId);
      return posters.length;
    }
    return await _posterDao.getPosterCount(movieId);
  }

  // ========== 书评相关方法 ==========

  /// 获取书籍的所有书评
  Future<List<BookReview>> getBookReviews(String bookId) async {
    if (_useRemote) return await ServerDataService.instance.getBookReviews(bookId);
    return await _bookReviewDao.getReviewsByBookId(bookId);
  }

  /// 添加书评
  Future<void> addBookReview(BookReview review) async {
    if (_useRemote) await ServerDataService.instance.saveBookReview(review);
    else await _bookReviewDao.insertReview(review);
  }

  /// 更新书评
  Future<void> updateBookReview(BookReview review) async {
    if (_useRemote) await ServerDataService.instance.saveBookReview(review);
    else await _bookReviewDao.updateReview(review);
  }

  /// 删除书评
  Future<void> removeBookReview(String id) async {
    if (_useRemote) await ServerDataService.instance.deleteBookReview(id);
    else await _bookReviewDao.deleteReview(id);
  }

  /// 获取书籍的书评数量
  Future<int> getBookReviewCount(String bookId) async {
    if (_useRemote) {
      final reviews = await ServerDataService.instance.getBookReviews(bookId);
      return reviews.length;
    }
    return await _bookReviewDao.getReviewCount(bookId);
  }

  // ========== 摘抄相关方法 ==========

  /// 获取书籍的所有摘抄
  Future<List<BookExcerpt>> getBookExcerpts(String bookId) async {
    if (_useRemote) return await ServerDataService.instance.getBookExcerpts(bookId);
    return await _bookExcerptDao.getExcerptsByBookId(bookId);
  }

  /// 添加摘抄
  Future<void> addBookExcerpt(BookExcerpt excerpt) async {
    if (_useRemote) await ServerDataService.instance.saveBookExcerpt(excerpt);
    else await _bookExcerptDao.insertExcerpt(excerpt);
  }

  /// 更新摘抄
  Future<void> updateBookExcerpt(BookExcerpt excerpt) async {
    if (_useRemote) await ServerDataService.instance.saveBookExcerpt(excerpt);
    else await _bookExcerptDao.updateExcerpt(excerpt);
  }

  /// 删除摘抄
  Future<void> removeBookExcerpt(String id) async {
    if (_useRemote) await ServerDataService.instance.deleteBookExcerpt(id);
    else await _bookExcerptDao.deleteExcerpt(id);
  }

  /// 获取书籍的摘抄数量
  Future<int> getBookExcerptCount(String bookId) async {
    if (_useRemote) {
      final excerpts = await ServerDataService.instance.getBookExcerpts(bookId);
      return excerpts.length;
    }
    return await _bookExcerptDao.getExcerptCount(bookId);
  }

  // ========== 回收站相关方法 ==========
  
  /// 获取已删除的影视
  Future<List<Movie>> getDeletedMovies() async {
    if (_useRemote) return ServerDataService.instance.getDeletedMovies();
    return await _movieDao.getDeletedMovies();
  }

  /// 恢复影视
  Future<void> restoreMovie(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.restoreMovie(id);
    } else {
      await _movieDao.restoreMovie(id);
    }
    await loadMovies();
  }

  /// 彻底删除影视
  Future<void> permanentDeleteMovie(String id) async {
    await ImagePathHelper.instance.deleteMovieImages(id);
    if (_useRemote) {
      await ServerDataService.instance.permanentDeleteMovie(id);
    } else {
      await _movieDao.permanentDeleteMovie(id);
    }
  }

  /// 获取已删除的书籍
  Future<List<Book>> getDeletedBooks() async {
    if (_useRemote) return ServerDataService.instance.getDeletedBooks();
    return await _bookDao.getDeletedBooks();
  }

  /// 恢复书籍
  Future<void> restoreBook(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.restoreBook(id);
    } else {
      await _bookDao.restoreBook(id);
    }
    await loadBooks();
  }

  /// 彻底删除书籍
  Future<void> permanentDeleteBook(String id) async {
    await ImagePathHelper.instance.deleteBookImages(id);
    if (_useRemote) {
      await ServerDataService.instance.permanentDeleteBook(id);
    } else {
      await _bookDao.permanentDeleteBook(id);
    }
  }

  /// 获取已删除的笔记
  Future<List<Note>> getDeletedNotes() async {
    if (_useRemote) return ServerDataService.instance.getDeletedNotes();
    return await _noteDao.getDeletedNotes();
  }

  /// 恢复笔记
  Future<void> restoreNote(String id) async {
    if (_useRemote) {
      await ServerDataService.instance.restoreNote(id);
    } else {
      await _noteDao.restoreNote(id);
    }
    await loadNotes();
  }

  /// 彻底删除笔记
  Future<void> permanentDeleteNote(String id) async {
    await ImagePathHelper.instance.deleteNoteImages(id);
    if (_useRemote) {
      await ServerDataService.instance.permanentDeleteNote(id);
    } else {
      await _noteDao.permanentDeleteNote(id);
    }
  }
  
  /// 清空回收站
  Future<void> clearRecycleBin() async {
    final deletedMovies = await getDeletedMovies();
    final deletedBooks = await getDeletedBooks();
    final deletedNotes = await getDeletedNotes();

    for (final movie in deletedMovies) {
      await permanentDeleteMovie(movie.id);
    }
    for (final book in deletedBooks) {
      await permanentDeleteBook(book.id);
    }
    for (final note in deletedNotes) {
      await permanentDeleteNote(note.id);
    }
    
    await loadMovies();
    await loadBooks();
    await loadNotes();
  }

  // ========== 标签管理方法 ==========

  Future<List<Map<String, dynamic>>> getTags(String type) async {
    if (_useRemote) {
      return await ServerDataService.instance.getTags(type.isEmpty ? null : type);
    }
    return await _tagDao.getTagsByType(type);
  }

  Future<String> addTag(String name, String type) async {
    final id = await _tagDao.addTag(name, type);
    if (_useRemote) {
      await ServerDataService.instance.saveTag(name, type);
    }
    await _reloadByTagType(type);
    return id;
  }

  Future<bool> renameTag(String tagId, String newName, String type) async {
    final tag = await _tagDao.getTagById(tagId);
    final oldName = tag?['name'] as String?;
    final result = await _tagDao.renameTag(tagId, newName);
    if (result) {
      if (_useRemote) {
        if (oldName != null) {
          await ServerDataService.instance.deleteTagByName(oldName, type);
        }
        await ServerDataService.instance.saveTag(newName, type);
        await _pushAffectedByType(type); // 先推到服务端
      }
      await _reloadByTagType(type); // 再从服务端拉最新
    }
    return result;
  }

  Future<void> deleteTag(String tagId, String type,
      {String? replacementName}) async {
    await _tagDao.deleteTag(tagId, replacementName: replacementName);
    if (_useRemote) {
      await ServerDataService.instance.deleteTag(tagId);
      if (replacementName != null) {
        await ServerDataService.instance.saveTag(replacementName, type);
      }
      await _pushAffectedByType(type); // 先推到服务端
    }
    await _reloadByTagType(type); // 再从服务端拉最新
  }

  /// 仅删除标签本身，不级联影响已有条目
  Future<void> deleteTagOnly(String tagId, String type) async {
    await _tagDao.deleteTagOnly(tagId);
    if (_useRemote) {
      await ServerDataService.instance.deleteTag(tagId);
    }
    await _reloadByTagType(type);
  }

  /// 把某类型的所有条目推送到服务端（标签级联后调用）
  Future<void> _pushAffectedByType(String type) async {
    final server = ServerDataService.instance;
    switch (type) {
      case 'movie_genre':
        for (final m in _movies) { await server.saveMovie(m); }
      case 'book_genre':
        for (final b in _books) { await server.saveBook(b); }
      case 'note_tag':
        for (final n in _notes) { await server.saveNote(n); }
    }
  }

  /// 从影视/书籍/笔记数据中解析标签，同步到 tags 表
  Future<int> syncTagsFromData() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    int counter = 0;
    int added = 0;

    Future<void> insertTag(String name, String type) async {
      try {
        await db.insert('tags', {
          'id': 'tag_${DateTime.now().millisecondsSinceEpoch}_${counter++}',
          'name': name,
          'type': type,
          'created_at': now,
        });
        added++;
      } catch (_) {
        // 忽略 UNIQUE 约束冲突（标签已存在）
      }
    }

    // 影视类型
    final movies = await db.query('movies',
        where: 'genres IS NOT NULL AND genres != ?', whereArgs: ['[]']);
    for (final row in movies) {
      for (final genre in Movie.parseStringList(row['genres'])) {
        await insertTag(genre, 'movie_genre');
      }
    }

    // 书籍类型
    final books = await db.query('books',
        where: 'genres IS NOT NULL AND genres != ?', whereArgs: ['[]']);
    for (final row in books) {
      for (final genre in Movie.parseStringList(row['genres'])) {
        await insertTag(genre, 'book_genre');
      }
    }

    // 笔记标签
    final notes = await db.query('notes',
        where: 'tags IS NOT NULL AND tags != ? AND tags != ?',
        whereArgs: ['[]', '']);
    for (final row in notes) {
      for (final tag in Movie.parseStringList(row['tags'])) {
        await insertTag(tag, 'note_tag');
      }
    }

    return added;
  }

  Future<void> _reloadByTagType(String type) async {
    switch (type) {
      case 'movie_genre':
        await loadMovies();
      case 'book_genre':
        await loadBooks();
      case 'note_tag':
        await loadNotes();
    }
  }
}
