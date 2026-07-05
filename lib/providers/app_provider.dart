import 'dart:collection';
import 'package:flutter/material.dart';
import '../models/data_models.dart';
import '../data/movie/movie_dao.dart';
import '../data/book/book_dao.dart';
import '../data/note/note_dao.dart';
import '../data/movie/movie_review_dao.dart';
import '../data/movie/movie_poster_dao.dart';
import '../data/book/book_review_dao.dart';
import '../data/book/book_excerpt_dao.dart';
import '../data/game/game_dao.dart';
import '../data/game/game_review_dao.dart';
import '../data/game/game_screenshot_dao.dart';
import '../data/tag/tag_dao.dart';
import '../data/database_helper.dart';
import '../utils/image_path_helper.dart';
import '../utils/user_prefs.dart';
import '../utils/theme/app_theme.dart';
import '../services/font_download_manager.dart';

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
  final GameDao _gameDao = GameDao();
  final GameReviewDao _gameReviewDao = GameReviewDao();
  final GameScreenshotDao _gameScreenshotDao = GameScreenshotDao();
  final TagDao _tagDao = TagDao();
  // 数据列表
  List<Movie> _movies = [];
  List<Book> _books = [];
  List<Note> _notes = [];
  List<Game> _games = [];

  // 当前主界面选中的标签 (0: 观影，1: 阅读，2: 笔记)
  int _mainTabIndex = 0;

  // 当前底部导航选中的索引 (0: 主页，1: 新增，2: 我的)
  int _bottomNavIndex = 0;

  // 底部导航栏是否可见
  bool _bottomNavVisible = true;

  // 平板 Master-Detail 选中项
  Movie? _selectedMovie;
  Book? _selectedBook;
  Note? _selectedNote;
  Game? _selectedGame;

  // 主题模式
  ThemeMode _themeMode = ThemeMode.system;

  // 配色方案索引
  int _colorSchemeIndex = 0;

  // 字体
  String _fontFamily = '';

  // 观影选中的状态 (0: 已看，1: 想看，2: 在看)
  int _movieStatusIndex = 0;

  // 影视列表布局样式 (0: 网格, 1: 列表, 2: 大图卡片)
  int _movieLayoutStyle = 0;

  // 影视墙模式（不显示分类，按创建时间排序）
  bool _movieWallMode = false;

  // 阅读选中的状态 (0: 读完，1: 在读，2: 准备读)
  int _bookStatusIndex = 0;

  // 书架模式（不显示分类，按创建时间排序）
  bool _bookshelfMode = false;

  // 游戏选中的状态 (0: 已通关，1: 在玩，2: 想玩，3: 弃游)
  int _gameStatusIndex = 0;

  // 游戏列表布局样式 (0: 网格, 1: 列表, 2: 大图卡片)
  int _gameLayoutStyle = 0;

  // 游戏墙模式
  bool _gameWallMode = false;
  
  // 侧边菜单是否打开
  bool _drawerOpen = false;

  // 回到顶部信号（点击首页图标时递增）
  int _scrollToTopSignal = 0;
  int get scrollToTopSignal => _scrollToTopSignal;

  // 编辑后刷新信号（影视/书籍编辑返回时递增）
  int _editRefreshCounter = 0;
  int get editRefreshCounter => _editRefreshCounter;

  // 最近编辑的条目 ID（用于就地更新，避免重置分页）
  String? _lastEditedItemId;
  String? get lastEditedItemId => _lastEditedItemId;

  // 初始化数据库
  Future<void> initDatabase() async {
    debugPrint('[AppProvider] initDatabase');
    final results = await Future.wait([
      _movieDao.getAllMovies(),
      _bookDao.getAllBooks(),
      _noteDao.getAllNotes(),
      _gameDao.getAllGames(),
    ]);
    _movies = results[0] as List<Movie>;
    _books = results[1] as List<Book>;
    _notes = results[2] as List<Note>;
    _games = results[3] as List<Game>;
    debugPrint('[AppProvider] 本地数据: movies=${_movies.length}, books=${_books.length}, notes=${_notes.length}, games=${_games.length}');
    notifyListeners();
  }

  // 从用户偏好恢复默认启动标签
  void initMainTabIndex() {
    final userPrefs = UserPrefs();
    _movieLayoutStyle = userPrefs.movieLayoutStyle;
    _movieWallMode = userPrefs.movieWallMode;
    _bookshelfMode = userPrefs.bookshelfMode;
    _gameLayoutStyle = userPrefs.gameLayoutStyle;
    _gameWallMode = userPrefs.gameWallMode;
    final defaultIndex = userPrefs.defaultMainTabIndex;
    // 确保选中的标签是启用的
    final showMovie = userPrefs.showMovieTab;
    final showBook = userPrefs.showBookTab;
    final showNote = userPrefs.showNoteTab;
    final showGame = userPrefs.showGameTab;
    final enabled = [showMovie, showBook, showNote, showGame];
    if (defaultIndex >= 0 && defaultIndex < enabled.length && enabled[defaultIndex]) {
      _mainTabIndex = defaultIndex;
    } else {
      // 回退到第一个启用的标签
      if (showMovie) {
        _mainTabIndex = 0;
      } else if (showBook) {
        _mainTabIndex = 1;
      } else if (showNote) {
        _mainTabIndex = 2;
      } else if (showGame) {
        _mainTabIndex = 3;
      }
    }
    notifyListeners();
  }
  
  // 加载影视数据
  Future<void> loadMovies() async {
    _movies = await _movieDao.getAllMovies();
    notifyListeners();
  }

  // 加载书籍数据
  Future<void> loadBooks() async {
    _books = await _bookDao.getAllBooks();
    notifyListeners();
  }

  // 加载笔记数据
  Future<void> loadNotes({int sortMode = 0}) async {
    _notes = await _noteDao.getAllNotes(sortMode: sortMode);
    notifyListeners();
  }

  // 加载游戏数据
  Future<void> loadGames() async {
    _games = await _gameDao.getAllGames();
    notifyListeners();
  }

  /// 编辑返回后触发列表页重载
  /// [itemId] 被编辑条目的 ID，用于就地更新而非重置分页
  void setEditRefresh([String? itemId]) {
    _editRefreshCounter++;
    _lastEditedItemId = itemId;
    notifyListeners();
  }


  // ─── 分页加载（供列表页触底加载使用）────────────────────────
  static const int _pageSize = 20;

  Future<List<Movie>> loadMoviesPaged({String? status, required int offset, int sortMode = 0}) async {
    return _movieDao.getMoviesPaged(status: status, limit: _pageSize, offset: offset, sortMode: sortMode);
  }

  Future<List<Book>> loadBooksPaged({String? status, required int offset, int sortMode = 0}) async {
    return _bookDao.getBooksPaged(status: status, limit: _pageSize, offset: offset, sortMode: sortMode);
  }

  Future<List<Note>> loadNotesPaged({required int offset, int sortMode = 0}) async {
    return _noteDao.getNotesPaged(limit: _pageSize, offset: offset, sortMode: sortMode);
  }

  Future<List<Game>> loadGamesPaged({String? status, required int offset, int sortMode = 0}) async {
    return _gameDao.getGamesPaged(status: status, limit: _pageSize, offset: offset, sortMode: sortMode);
  }

  // Getters
  int get mainTabIndex => _mainTabIndex;
  int get bottomNavIndex => _bottomNavIndex;
  Movie? get selectedMovie => _selectedMovie;
  Book? get selectedBook => _selectedBook;
  Note? get selectedNote => _selectedNote;
  Game? get selectedGame => _selectedGame;
  int get movieStatusIndex => _movieStatusIndex;
  int get movieLayoutStyle => _movieLayoutStyle;
  bool get movieWallMode => _movieWallMode;
  int get bookStatusIndex => _bookStatusIndex;
  bool get bookshelfMode => _bookshelfMode;
  int get gameStatusIndex => _gameStatusIndex;
  int get gameLayoutStyle => _gameLayoutStyle;
  bool get gameWallMode => _gameWallMode;
  bool get drawerOpen => _drawerOpen;
  bool get bottomNavVisible => _bottomNavVisible;
  ThemeMode get themeMode => _themeMode;
  int get colorSchemeIndex => _colorSchemeIndex;
  String get fontFamily => _fontFamily;
  List<Movie> get movies => UnmodifiableListView(_movies);
  List<Book> get books => UnmodifiableListView(_books);
  List<Note> get notes => UnmodifiableListView(_notes);
  List<Game> get games => UnmodifiableListView(_games);

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
    if (index == 0 && _bottomNavIndex == 0) {
      // 已在首页，再次点击 → 回到顶部
      _scrollToTopSignal++;
      notifyListeners();
      return;
    }
    _bottomNavIndex = index;
    _bottomNavVisible = true;
    notifyListeners();
  }

  void selectMovie(Movie? movie) {
    _selectedMovie = movie;
    notifyListeners();
  }

  void selectBook(Book? book) {
    _selectedBook = book;
    notifyListeners();
  }

  void selectNote(Note? note) {
    _selectedNote = note;
    notifyListeners();
  }

  void selectGame(Game? game) {
    _selectedGame = game;
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
      UserPrefs().setThemeMode(mode.index); // 0=system, 1=light, 2=dark
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
    _colorSchemeIndex = prefs.colorSchemeIndex;
    _fontFamily = prefs.fontFamily;
    AppTheme.setFontFamily(_fontFamily);
    // 异步预加载已缓存的字体（不阻塞 UI）
    if (_fontFamily.isNotEmpty) {
      FontDownloadManager().preloadCachedFont(_fontFamily);
    }
    notifyListeners();
  }

  void setColorScheme(int index) {
    if (_colorSchemeIndex != index) {
      _colorSchemeIndex = index;
      UserPrefs().setColorSchemeIndex(index);
      notifyListeners();
    }
  }

  void setFontFamily(String family) {
    if (_fontFamily != family) {
      _fontFamily = family;
      UserPrefs().setFontFamily(family);
      AppTheme.setFontFamily(family);
      notifyListeners();
    }
  }

  void setMovieStatusIndex(int index) {
    _movieStatusIndex = index;
    notifyListeners();
  }

  void setMovieLayoutStyle(int style) {
    _movieLayoutStyle = style;
    UserPrefs().setMovieLayoutStyle(style);
    notifyListeners();
  }

  void setMovieWallMode(bool enabled) {
    _movieWallMode = enabled;
    UserPrefs().setMovieWallMode(enabled);
    notifyListeners();
  }

  void setBookStatusIndex(int index) {
    _bookStatusIndex = index;
    notifyListeners();
  }

  void setBookshelfMode(bool enabled) {
    _bookshelfMode = enabled;
    UserPrefs().setBookshelfMode(enabled);
    notifyListeners();
  }

  void setGameStatusIndex(int index) {
    _gameStatusIndex = index;
    notifyListeners();
  }

  void setGameLayoutStyle(int style) {
    _gameLayoutStyle = style;
    UserPrefs().setGameLayoutStyle(style);
    notifyListeners();
  }

  void setGameWallMode(bool enabled) {
    _gameWallMode = enabled;
    UserPrefs().setGameWallMode(enabled);
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

  // 添加影视记录
  Future<void> addMovie(Movie movie) async {
    await _movieDao.insertMovie(movie);
    await loadMovies();
  }

  Future<void> updateMovie(Movie movie) async {
    await _movieDao.updateMovie(movie);
    await loadMovies();
  }

  /// 仅更新封面偏移量（不触发全量刷新）
  Future<void> updateMovieCoverOffset(String movieId, double offset) async {
    await _movieDao.updateCoverOffset(movieId, offset);
    final idx = _movies.indexWhere((m) => m.id == movieId);
    if (idx != -1) {
      _movies[idx] = _movies[idx].copyWith(coverOffset: offset);
      notifyListeners();
    }
  }

  /// 仅更新封面偏移量（不触发全量刷新）
  Future<void> updateBookCoverOffset(String bookId, double offset) async {
    await _bookDao.updateCoverOffset(bookId, offset);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      _books[idx] = _books[idx].copyWith(coverOffset: offset);
      notifyListeners();
    }
  }

  Future<void> removeMovie(String id) async {
    await _movieDao.deleteMovie(id);
    await loadMovies();
  }

  Future<void> addBook(Book book) async {
    await _bookDao.insertBook(book);
    await loadBooks();
  }

  Future<void> updateBook(Book book) async {
    await _bookDao.updateBook(book);
    await loadBooks();
  }

  Future<void> removeBook(String id) async {
    await _bookDao.deleteBook(id);
    await loadBooks();
  }

  Future<void> addNote(Note note) async {
    await _noteDao.insertNote(note);
    await loadNotes();
  }

  Future<void> updateNote(Note note) async {
    await _noteDao.updateNote(note);
    await loadNotes();
  }

  Future<void> removeNote(String id) async {
    await _noteDao.deleteNote(id);
    await loadNotes();
  }

  Future<void> addGame(Game game) async {
    await _gameDao.insertGame(game);
    await loadGames();
  }

  Future<void> updateGame(Game game) async {
    await _gameDao.updateGame(game);
    await loadGames();
  }

  Future<void> removeGame(String id) async {
    await _gameDao.deleteGame(id);
    await loadGames();
  }

  /// 仅更新游戏封面偏移量（不触发全量刷新）
  Future<void> updateGameCoverOffset(String gameId, double offset) async {
    await _gameDao.updateCoverOffset(gameId, offset);
    final idx = _games.indexWhere((g) => g.id == gameId);
    if (idx != -1) {
      _games[idx] = _games[idx].copyWith(coverOffset: offset);
      notifyListeners();
    }
  }

  Future<void> toggleNotePin(String id, bool isPinned) async {
    await _noteDao.togglePin(id, isPinned);
    await loadNotes();
    notifyListeners();
  }
  
  // ========== 影评相关方法 ==========

  /// 获取影视的所有影评
  Future<List<MovieReview>> getMovieReviews(String movieId) async {
    return await _reviewDao.getReviewsByMovieId(movieId);
  }

  /// 添加影评
  Future<void> addMovieReview(MovieReview review) async {
    await _reviewDao.insertReview(review);
  }

  /// 更新影评
  Future<void> updateMovieReview(MovieReview review) async {
    await _reviewDao.updateReview(review);
  }

  /// 删除影评
  Future<void> removeMovieReview(String id) async {
    await _reviewDao.deleteReview(id);
  }

  /// 获取影视的影评数量
  Future<int> getMovieReviewCount(String movieId) async {
    return await _reviewDao.getReviewCount(movieId);
  }

  // ========== 海报墙相关方法 ==========

  /// 获取影视的所有海报
  Future<List<MoviePoster>> getMoviePosters(String movieId) async {
    return await _posterDao.getPostersByMovieId(movieId);
  }

  /// 添加海报
  Future<void> addMoviePoster(MoviePoster poster) async {
    await _posterDao.insertPoster(poster);
  }

  /// 删除海报
  Future<void> removeMoviePoster(String id) async {
    final poster = await _posterDao.getPosterById(id);
    if (poster != null) {
      await ImagePathHelper.instance.deleteFile(poster.posterPath);
    }
    await _posterDao.deletePoster(id);
  }

  /// 获取影视的海报数量
  Future<int> getMoviePosterCount(String movieId) async {
    return await _posterDao.getPosterCount(movieId);
  }

  // ========== 游戏评价相关方法 ==========

  /// 获取游戏的所有评价
  Future<List<GameReview>> getGameReviews(String gameId) async {
    return await _gameReviewDao.getReviewsByGameId(gameId);
  }

  /// 添加游戏评价
  Future<void> addGameReview(GameReview review) async {
    await _gameReviewDao.insertReview(review);
  }

  /// 更新游戏评价
  Future<void> updateGameReview(GameReview review) async {
    await _gameReviewDao.updateReview(review);
  }

  /// 删除游戏评价
  Future<void> removeGameReview(String id) async {
    await _gameReviewDao.deleteReview(id);
  }

  /// 获取游戏的评价数量
  Future<int> getGameReviewCount(String gameId) async {
    return await _gameReviewDao.getReviewCount(gameId);
  }

  // ========== 游戏截图相关方法 ==========

  /// 获取游戏的所有截图
  Future<List<GameScreenshot>> getGameScreenshots(String gameId) async {
    return await _gameScreenshotDao.getScreenshotsByGameId(gameId);
  }

  /// 添加游戏截图
  Future<void> addGameScreenshot(GameScreenshot screenshot) async {
    await _gameScreenshotDao.insertScreenshot(screenshot);
  }

  /// 删除游戏截图
  Future<void> removeGameScreenshot(String id) async {
    final screenshot = await _gameScreenshotDao.getScreenshotById(id);
    if (screenshot != null) {
      await ImagePathHelper.instance.deleteFile(screenshot.screenshotPath);
    }
    await _gameScreenshotDao.deleteScreenshot(id);
  }

  /// 获取游戏的截图数量
  Future<int> getGameScreenshotCount(String gameId) async {
    return await _gameScreenshotDao.getScreenshotCount(gameId);
  }

  // ========== 书评相关方法 ==========

  /// 获取书籍的所有书评
  Future<List<BookReview>> getBookReviews(String bookId) async {
    return await _bookReviewDao.getReviewsByBookId(bookId);
  }

  /// 添加书评
  Future<void> addBookReview(BookReview review) async {
    await _bookReviewDao.insertReview(review);
  }

  /// 更新书评
  Future<void> updateBookReview(BookReview review) async {
    await _bookReviewDao.updateReview(review);
  }

  /// 删除书评
  Future<void> removeBookReview(String id) async {
    await _bookReviewDao.deleteReview(id);
  }

  /// 获取书籍的书评数量
  Future<int> getBookReviewCount(String bookId) async {
    return await _bookReviewDao.getReviewCount(bookId);
  }

  // ========== 摘抄相关方法 ==========

  /// 获取书籍的所有摘抄
  Future<List<BookExcerpt>> getBookExcerpts(String bookId) async {
    return await _bookExcerptDao.getExcerptsByBookId(bookId);
  }

  /// 添加摘抄
  Future<void> addBookExcerpt(BookExcerpt excerpt) async {
    await _bookExcerptDao.insertExcerpt(excerpt);
  }

  /// 更新摘抄
  Future<void> updateBookExcerpt(BookExcerpt excerpt) async {
    await _bookExcerptDao.updateExcerpt(excerpt);
  }

  /// 删除摘抄
  Future<void> removeBookExcerpt(String id) async {
    await _bookExcerptDao.deleteExcerpt(id);
  }

  /// 获取书籍的摘抄数量
  Future<int> getBookExcerptCount(String bookId) async {
    return await _bookExcerptDao.getExcerptCount(bookId);
  }

  // ========== 回收站相关方法 ==========
  
  /// 获取已删除的影视
  Future<List<Movie>> getDeletedMovies() async {
    return await _movieDao.getDeletedMovies();
  }

  /// 恢复影视
  Future<void> restoreMovie(String id) async {
    await _movieDao.restoreMovie(id);
    await loadMovies();
  }

  /// 彻底删除影视
  Future<void> permanentDeleteMovie(String id) async {
    await ImagePathHelper.instance.deleteMovieImages(id);
    await _movieDao.permanentDeleteMovie(id);
  }

  /// 获取已删除的书籍
  Future<List<Book>> getDeletedBooks() async {
    return await _bookDao.getDeletedBooks();
  }

  /// 恢复书籍
  Future<void> restoreBook(String id) async {
    await _bookDao.restoreBook(id);
    await loadBooks();
  }

  /// 彻底删除书籍
  Future<void> permanentDeleteBook(String id) async {
    await ImagePathHelper.instance.deleteBookImages(id);
    await _bookDao.permanentDeleteBook(id);
  }

  /// 获取已删除的笔记
  Future<List<Note>> getDeletedNotes() async {
    return await _noteDao.getDeletedNotes();
  }

  /// 恢复笔记
  Future<void> restoreNote(String id) async {
    await _noteDao.restoreNote(id);
    await loadNotes();
  }

  /// 彻底删除笔记
  Future<void> permanentDeleteNote(String id) async {
    await ImagePathHelper.instance.deleteNoteImages(id);
    await _noteDao.permanentDeleteNote(id);
  }

  /// 获取已删除的游戏
  Future<List<Game>> getDeletedGames() async {
    return await _gameDao.getDeletedGames();
  }

  /// 恢复游戏
  Future<void> restoreGame(String id) async {
    await _gameDao.restoreGame(id);
    await loadGames();
  }

  /// 彻底删除游戏
  Future<void> permanentDeleteGame(String id) async {
    await ImagePathHelper.instance.deleteGameImages(id);
    await _gameDao.permanentDeleteGame(id);
  }
  
  /// 清空回收站
  Future<void> clearRecycleBin() async {
    final deletedMovies = await getDeletedMovies();
    final deletedBooks = await getDeletedBooks();
    final deletedNotes = await getDeletedNotes();
    final deletedGames = await getDeletedGames();
    final deletedMovieReviews = await getDeletedMovieReviews();
    final deletedBookReviews = await getDeletedBookReviews();
    final deletedBookExcerpts = await getDeletedBookExcerpts();
    final deletedGameReviews = await getDeletedGameReviews();

    for (final movie in deletedMovies) {
      await permanentDeleteMovie(movie.id);
    }
    for (final book in deletedBooks) {
      await permanentDeleteBook(book.id);
    }
    for (final note in deletedNotes) {
      await permanentDeleteNote(note.id);
    }
    for (final game in deletedGames) {
      await permanentDeleteGame(game.id);
    }
    for (final review in deletedMovieReviews) {
      await _reviewDao.permanentDeleteReview(review.id);
    }
    for (final review in deletedBookReviews) {
      await _bookReviewDao.permanentDeleteReview(review.id);
    }
    for (final excerpt in deletedBookExcerpts) {
      await _bookExcerptDao.permanentDeleteExcerpt(excerpt.id);
    }
    for (final review in deletedGameReviews) {
      await _gameReviewDao.permanentDeleteReview(review.id);
    }

    await loadMovies();
    await loadBooks();
    await loadNotes();
    await loadGames();
  }

  // ========== 影评书评回收站 ==========

  Future<List<MovieReview>> getDeletedMovieReviews() async {
    return await _reviewDao.getDeletedReviews();
  }

  Future<void> restoreMovieReview(String id) async {
    await _reviewDao.restoreReview(id);
  }

  Future<void> permanentDeleteMovieReview(String id) async {
    await _reviewDao.permanentDeleteReview(id);
  }

  Future<List<BookReview>> getDeletedBookReviews() async {
    return await _bookReviewDao.getDeletedReviews();
  }

  Future<void> restoreBookReview(String id) async {
    await _bookReviewDao.restoreReview(id);
  }

  Future<void> permanentDeleteBookReview(String id) async {
    await _bookReviewDao.permanentDeleteReview(id);
  }

  // ========== 游戏评价回收站 ==========

  Future<List<GameReview>> getDeletedGameReviews() async {
    return await _gameReviewDao.getDeletedReviews();
  }

  Future<void> restoreGameReview(String id) async {
    await _gameReviewDao.restoreReview(id);
  }

  Future<void> permanentDeleteGameReview(String id) async {
    await _gameReviewDao.permanentDeleteReview(id);
  }

  // ========== 摘抄回收站方法 ==========

  Future<List<BookExcerpt>> getDeletedBookExcerpts() async {
    return await _bookExcerptDao.getDeletedExcerpts();
  }

  Future<void> restoreBookExcerpt(String id) async {
    await _bookExcerptDao.restoreExcerpt(id);
  }

  Future<void> permanentDeleteBookExcerpt(String id) async {
    await _bookExcerptDao.permanentDeleteExcerpt(id);
  }


  // ========== 标签管理方法 ==========

  Future<List<Map<String, dynamic>>> getTags(String type, {bool excludeHidden = false}) async {
    return await _tagDao.getTagsByType(type, excludeHidden: excludeHidden);
  }

  Future<void> toggleTagHidden(String tagId) async {
    await _tagDao.toggleHidden(tagId);
    notifyListeners();
  }

  Future<String> addTag(String name, String type) async {
    final id = await _tagDao.addTag(name, type);
    await _reloadByTagType(type);
    return id;
  }

  Future<bool> renameTag(String tagId, String newName, String type) async {
    final result = await _tagDao.renameTag(tagId, newName);
    if (result) {
      await _reloadByTagType(type);
    }
    return result;
  }

  Future<void> deleteTag(String tagId, String type,
      {String? replacementName}) async {
    await _tagDao.deleteTag(tagId, replacementName: replacementName);
    await _reloadByTagType(type);
  }

  /// 仅删除标签本身，不级联影响已有条目
  Future<void> deleteTagOnly(String tagId, String type) async {
    await _tagDao.deleteTagOnly(tagId);
    await _reloadByTagType(type);
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
      for (final genre in parseStringListGeneric(row['genres'])) {
        await insertTag(genre, 'movie_genre');
      }
    }

    // 书籍类型
    final books = await db.query('books',
        where: 'genres IS NOT NULL AND genres != ?', whereArgs: ['[]']);
    for (final row in books) {
      for (final genre in parseStringListGeneric(row['genres'])) {
        await insertTag(genre, 'book_genre');
      }
    }

    // 笔记标签
    final notes = await db.query('notes',
        where: 'tags IS NOT NULL AND tags != ? AND tags != ?',
        whereArgs: ['[]', '']);
    for (final row in notes) {
      for (final tag in parseStringListGeneric(row['tags'])) {
        await insertTag(tag, 'note_tag');
      }
    }

    // 游戏类型
    final games = await db.query('games',
        where: 'genres IS NOT NULL AND genres != ?', whereArgs: ['[]']);
    for (final row in games) {
      for (final genre in parseStringListGeneric(row['genres'])) {
        await insertTag(genre, 'game_genre');
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
      case 'game_genre':
        await loadGames();
    }
  }
}
