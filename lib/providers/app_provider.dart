import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
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
import '../data/game/game_completion_dao.dart';
import '../data/movie/movie_episode_dao.dart';
import '../data/book/book_chapter_dao.dart';
import '../data/game/game_level_dao.dart';
import '../data/playlist/playlist_dao.dart';
import '../data/tag/tag_dao.dart';
import '../data/person/person_dao.dart';
import '../data/person/movie_person_dao.dart';
import '../data/person/book_person_dao.dart';
import '../data/person/game_person_dao.dart';
import '../data/character/movie_character_dao.dart';
import '../data/character/book_character_dao.dart';
import '../data/character/game_character_dao.dart';
import '../data/custom_module/custom_module_dao.dart';
import '../data/custom_module/custom_module_item_dao.dart';
import '../services/sync/incremental/sync_tombstones.dart';
import '../services/cloud/cloud_movie_data_service.dart';
import '../services/cloud/cloud_domain_data_service.dart';
import '../data/database_helper.dart';
import '../utils/image_path_helper.dart';
import '../utils/user_prefs.dart';
import '../utils/theme/app_theme.dart';
import '../l10n/app_strings.dart';
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
  final GameCompletionDao _gameCompletionDao = GameCompletionDao();
  final MovieEpisodeDao _movieEpisodeDao = MovieEpisodeDao();
  final BookChapterDao _bookChapterDao = BookChapterDao();
  final GameLevelDao _gameLevelDao = GameLevelDao();
  final PlaylistDao _playlistDao = PlaylistDao();
  final TagDao _tagDao = TagDao();
  final PersonDao _personDao = PersonDao();
  final MoviePersonDao _moviePersonDao = MoviePersonDao();
  final BookPersonDao _bookPersonDao = BookPersonDao();
  final GamePersonDao _gamePersonDao = GamePersonDao();
  final MovieCharacterDao _movieCharacterDao = MovieCharacterDao();
  final BookCharacterDao _bookCharacterDao = BookCharacterDao();
  final GameCharacterDao _gameCharacterDao = GameCharacterDao();
  final CustomModuleDao _customModuleDao = CustomModuleDao();
  final CustomModuleItemDao _customModuleItemDao = CustomModuleItemDao();

  /// 云模式（纯实时）影视数据通道；仅在 UserPrefs.cloudMovieMode 下分流使用
  final CloudMovieDataService _cloudMovie = CloudMovieDataService.instance;
  bool get _cloudMovieMode => UserPrefs().cloudMovieMode;

  /// 云模式书籍/游戏/笔记数据通道（服务端 domains/domain-child/domain-entities 通用路由）
  final CloudDomainDataService _cloudDomain = CloudDomainDataService.instance;
  bool get _cloudBookMode => UserPrefs().cloudBookMode;
  bool get _cloudGameMode => UserPrefs().cloudGameMode;
  bool get _cloudNoteMode => UserPrefs().cloudNoteMode;
  bool get isCloudBookMode => _cloudBookMode;
  bool get isCloudGameMode => _cloudGameMode;
  bool get isCloudNoteMode => _cloudNoteMode;

  /// 片单跨影视/书籍/游戏三类，任一媒体域走云端即启用云端片单
  bool get _cloudPlaylistMode =>
      _cloudMovieMode || _cloudBookMode || _cloudGameMode;
  // 数据列表
  List<Movie> _movies = [];
  List<Book> _books = [];
  List<Note> _notes = [];
  List<Game> _games = [];
  List<Playlist> _playlists = [];
  List<Person> _people = [];
  List<CustomModule> _customModules = [];

  // 当前主界面选中的标签 (0: 观影，1: 阅读，2: 笔记)
  int _mainTabIndex = 0;

  // 主页模块显示方式 (0=底部tab切换, 1=顶部下拉切换)
  int _homeModuleSwitchMode = 0;

  // 模块标签模式下 AppBar 左上角显示 (0=日期印章, 1=菜单图标+分类名)
  int _homeLeadingStyle = 0;

  // 当前底部导航选中的索引 (0: 主页，1: 新增，2: 我的)
  int _bottomNavIndex = 0;

  // 底部导航栏是否可见
  bool _bottomNavVisible = true;

  // 平板 Master-Detail 选中项
  Movie? _selectedMovie;
  Book? _selectedBook;
  Note? _selectedNote;
  Game? _selectedGame;
  bool _isAdding = false;
  int? _addingType; // 0=影视, 1=阅读, 2=笔记, 3=游戏, null=未选择类型

  // 主题模式
  ThemeMode _themeMode = ThemeMode.system;

  // 毛玻璃主题（themeMode=3）：标志 + 随机封面
  bool _frostedActive = false;
  String? _frostedCoverPath;

  // 配色方案索引
  int _colorSchemeIndex = 0;

  // 字体
  String _fontFamily = '';
  int _languageMode = 0; // 0=跟随系统, 1=中文, 2=English

  // 观影选中的状态 (0: 已看，1: 想看，2: 在看)
  int _movieStatusIndex = 0;

  // 影视列表布局样式 (0: 网格, 1: 列表, 2: 大图卡片)
  int _movieLayoutStyle = 0;

  // 阅读列表布局样式 (0: 网格, 1: 列表, 2: 年份网格, 3: 大图卡片)
  int _bookLayoutStyle = 0;

  // 笔记详情正文对齐 (0: 左对齐, 1: 两侧对齐, 2: 右对齐)
  int _noteContentAlign = 0;

  // 影视墙模式（不显示分类，按创建时间排序）
  bool _movieWallMode = false;

  // 各模块海报右下角是否显示日期及日期来源
  bool _showMovieCardDate = false;
  bool _showBookCardDate = false;
  bool _showGameCardDate = false;
  int _movieCardDateType = 0;
  int _bookCardDateType = 0;
  int _gameCardDateType = 0;
  int _movieCardTitleAlign = 0;
  int _movieCardRatingAlign = 0;
  int _bookCardTitleAlign = 0;
  int _bookCardRatingAlign = 0;
  int _gameCardTitleAlign = 0;
  int _gameCardRatingAlign = 0;

  // 各模块列表是否显示标题 / 评分
  bool _showMovieTitle = true;
  bool _showMovieRating = true;
  bool _showBookTitle = true;
  bool _showBookRating = true;
  bool _showGameTitle = true;
  bool _showGameRating = true;

  // 影视显示模式 (0: 观看状态, 1: 分类状态)
  int _movieDisplayMode = 0;

  // 影视状态栏样式 (0: 胶囊滑块, 1: 下划线, 2: 芯片组, 3: 下拉)
  int _movieStatusBarStyle = 0;

  // 海报网格每行数量 (0: 自动按宽度, 3/4/5: 固定列数)
  int _movieGridCount = 0;
  int _bookGridCount = 0;
  int _gameGridCount = 0;

  // 影视分类索引
  int _movieCategoryIndex = 0;

  // 书籍显示模式 (0: 阅读状态, 1: 分类状态)
  int _bookDisplayMode = 0;

  // 阅读选中的状态 (0: 读完，1: 在读，2: 准备读)
  int _bookStatusIndex = 0;

  // 书籍分类索引
  int _bookCategoryIndex = 0;

  // 书籍状态栏样式 (0: 胶囊滑块, 1: 下划线, 2: 芯片组, 3: 下拉)
  int _bookStatusBarStyle = 0;

  // 书架模式（不显示分类，按创建时间排序）
  bool _bookshelfMode = false;

  // 游戏选中的状态 (0: 已通关，1: 在玩，2: 想玩，3: 弃游)
  int _gameStatusIndex = 0;

  // 游戏列表布局样式 (0: 网格, 1: 列表, 2: 大图卡片)
  int _gameLayoutStyle = 0;

  // 游戏状态栏样式 (0: 胶囊滑块, 1: 下划线, 2: 芯片组, 3: 下拉)
  int _gameStatusBarStyle = 0;

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

  // 数据库初始化失败标志
  bool _dbInitFailed = false;
  bool get dbInitFailed => _dbInitFailed;

  /// 标记数据库初始化失败（供 UI 提示重试）
  void markDbInitFailed() {
    _dbInitFailed = true;
    notifyListeners();
  }

  /// 头像 / 昵称 / 座右铭等用户信息变更后通知 UI 重建
  /// （这些数据存于 UserPrefs，侧边栏等 Consumer 靠此信号刷新）
  void notifyUserInfoChanged() {
    notifyListeners();
  }

  /// 主页模块状态自定义（命名/顺序）变更后通知 UI 重建（数据存于 UserPrefs）
  void notifyStatusLabelsChanged() {
    notifyListeners();
  }

  /// 重试数据库初始化（重入保护：连点重试不叠加多次全量加载）
  bool _retryingDb = false;
  Future<void> retryInitDatabase() async {
    if (_retryingDb) return;
    _retryingDb = true;
    try {
      _dbInitFailed = false;
      notifyListeners();
      await initDatabase();
    } finally {
      _retryingDb = false;
    }
  }

  // 初始化数据库
  Future<void> initDatabase() async {
    debugPrint('[AppProvider] initDatabase');
    // 独立加载每个 DAO，避免一个失败导致全部中断
    final failedTables = <String>[];
    try {
      _movies = await _movieDao.getAllMovies(
          sortMode: UserPrefs().effectiveMovieSortMode);
    } catch (e) {
      debugPrint('[AppProvider] 加载影视数据失败: $e');
      failedTables.add('movies');
    }
    try {
      _books = await _bookDao.getAllBooks(
          sortMode: UserPrefs().effectiveBookSortMode);
    } catch (e) {
      debugPrint('[AppProvider] 加载书籍数据失败: $e');
      failedTables.add('books');
    }
    try {
      _notes = await _noteDao.getAllNotes(sortMode: UserPrefs().noteSortMode);
    } catch (e) {
      debugPrint('[AppProvider] 加载笔记数据失败: $e');
      failedTables.add('notes');
    }
    try {
      _games = await _gameDao.getAllGames(
          sortMode: UserPrefs().effectiveGameSortMode);
    } catch (e) {
      debugPrint('[AppProvider] 加载游戏数据失败: $e');
      failedTables.add('games');
    }
    try {
      _people = await _personDao.getAllPeople();
    } catch (e) {
      debugPrint('[AppProvider] 加载人物数据失败: $e');
      failedTables.add('people');
    }
    try {
      _customModules = await _customModuleDao.getAllModules();
    } catch (e) {
      debugPrint('[AppProvider] 加载自定义模块失败: $e');
      failedTables.add('custom_modules');
    }
    // 加载失败的表若实际有数据，说明是初始化失败而非空库，标记以便 UI 提示重试
    for (final table in failedTables) {
      try {
        final db = await DatabaseHelper.instance.database;
        final count = (await db.rawQuery('SELECT COUNT(*) as cnt FROM $table'))
            .first['cnt'] as int;
        if (count > 0) {
          _dbInitFailed = true;
          break;
        }
      } catch (_) {
        _dbInitFailed = true;
        break;
      }
    }
    debugPrint(
        '[AppProvider] 本地数据: movies=${_movies.length}, books=${_books.length}, notes=${_notes.length}, games=${_games.length}, people=${_people.length}');
    notifyListeners();
  }

  // 从用户偏好恢复默认启动标签
  void initMainTabIndex() {
    final userPrefs = UserPrefs();
    _movieLayoutStyle = userPrefs.movieLayoutStyle;
    _bookLayoutStyle = userPrefs.bookLayoutStyle;
    _noteContentAlign = userPrefs.noteContentAlign;
    _movieWallMode = userPrefs.movieWallMode;
    _movieDisplayMode = userPrefs.movieDisplayMode;
    _movieStatusBarStyle = userPrefs.movieStatusBarStyle;
    _movieGridCount = userPrefs.movieGridCount;
    _bookGridCount = userPrefs.bookGridCount;
    _gameGridCount = userPrefs.gameGridCount;
    _bookStatusBarStyle = userPrefs.bookStatusBarStyle;
    _bookDisplayMode = userPrefs.bookDisplayMode;
    _bookshelfMode = userPrefs.bookshelfMode;
    _gameLayoutStyle = userPrefs.gameLayoutStyle;
    _gameWallMode = userPrefs.gameWallMode;
    _gameStatusBarStyle = userPrefs.gameStatusBarStyle;
    _homeModuleSwitchMode = userPrefs.homeModuleSwitchMode;
    _homeLeadingStyle = userPrefs.homeLeadingStyle;
    _showMovieCardDate = userPrefs.showMovieCardDate;
    _showBookCardDate = userPrefs.showBookCardDate;
    _showGameCardDate = userPrefs.showGameCardDate;
    _movieCardDateType = userPrefs.movieCardDateType;
    _bookCardDateType = userPrefs.bookCardDateType;
    _gameCardDateType = userPrefs.gameCardDateType;
    _movieCardTitleAlign = userPrefs.movieCardTitleAlign;
    _movieCardRatingAlign = userPrefs.movieCardRatingAlign;
    _bookCardTitleAlign = userPrefs.bookCardTitleAlign;
    _bookCardRatingAlign = userPrefs.bookCardRatingAlign;
    _gameCardTitleAlign = userPrefs.gameCardTitleAlign;
    _gameCardRatingAlign = userPrefs.gameCardRatingAlign;
    _showMovieTitle = userPrefs.showMovieTitle;
    _showMovieRating = userPrefs.showMovieRating;
    _showBookTitle = userPrefs.showBookTitle;
    _showBookRating = userPrefs.showBookRating;
    _showGameTitle = userPrefs.showGameTitle;
    _showGameRating = userPrefs.showGameRating;
    final defaultIndex = userPrefs.defaultMainTabIndex;
    {
      // 确保选中的标签是启用的
      final showMovie = userPrefs.showMovieTab;
      final showBook = userPrefs.showBookTab;
      final showNote = userPrefs.showNoteTab;
      final showGame = userPrefs.showGameTab;
      final enabled = [showMovie, showBook, showNote, showGame];
      if (defaultIndex >= customModuleTabBase) {
        // 自定义模块标签：校验仍在启用列表内
        final idx = defaultIndex - customModuleTabBase;
        if (idx >= 0 && idx < enabledCustomModules.length) {
          _mainTabIndex = defaultIndex;
        } else {
          _mainTabIndex = enabled.indexWhere((e) => e);
          if (_mainTabIndex == -1) {
            // 固定模块全关但有自定义模块时，落到第一个自定义模块
            _mainTabIndex =
                enabledCustomModules.isNotEmpty ? customModuleTabBase : 0;
          }
        }
      } else if (defaultIndex >= 0 &&
          defaultIndex < enabled.length &&
          enabled[defaultIndex]) {
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
        } else if (enabledCustomModules.isNotEmpty) {
          _mainTabIndex = customModuleTabBase;
        }
      }
    }
    notifyListeners();
  }

  // 加载影视数据
  Future<void> loadMovies() async {
    final sw = Stopwatch()..start();
    if (_cloudMovieMode) {
      // 云模式纯实时：仅取首页填充内存（毛玻璃封面等），列表翻页走 loadMoviesPaged
      final page = await _cloudMovie.pageMovies(
          sortMode: UserPrefs().effectiveMovieSortMode,
          offset: 0,
          limit: firstPageSize);
      _movies = page.list;
      _invalidateCloudMainCounts('movies');
      _cloudMainCountCache['movies'] = page.total;
      debugPrint(
          '[AppProvider] 云端影视加载完成: ${_movies.length} 条, ${sw.elapsedMilliseconds}ms');
      if (_frostedActive && _frostedCoverPath == null) refreshFrostedCover();
      notifyListeners();
      return;
    }
    _movies = await _movieDao.getAllMovies(
        sortMode: UserPrefs().effectiveMovieSortMode);
    debugPrint(
        '[AppProvider] 影视加载完成: ${_movies.length} 条, ${sw.elapsedMilliseconds}ms');
    if (_frostedActive && _frostedCoverPath == null) refreshFrostedCover();
    notifyListeners();
  }

  // 加载书籍数据
  Future<void> loadBooks() async {
    final sw = Stopwatch()..start();
    if (_cloudBookMode) {
      final page = await _cloudDomain.pageMain(
        'books',
        Book.fromJson,
        sortMode: UserPrefs().effectiveBookSortMode,
        offset: 0,
        limit: firstPageSize,
      );
      _books = page.list;
      _invalidateCloudMainCounts('books');
      _cloudMainCountCache['books'] = page.total;
      debugPrint(
          '[AppProvider] 云端书籍加载完成: ${_books.length} 条, ${sw.elapsedMilliseconds}ms');
      if (_frostedActive && _frostedCoverPath == null) refreshFrostedCover();
      notifyListeners();
      return;
    }
    _books =
        await _bookDao.getAllBooks(sortMode: UserPrefs().effectiveBookSortMode);
    debugPrint(
        '[AppProvider] 书籍加载完成: ${_books.length} 条, ${sw.elapsedMilliseconds}ms');
    if (_frostedActive && _frostedCoverPath == null) refreshFrostedCover();
    notifyListeners();
  }

  // 加载笔记数据
  Future<void> loadNotes({int? sortMode}) async {
    final sw = Stopwatch()..start();
    if (_cloudNoteMode) {
      _notes = await _cloudDomain.listEntities('notes', Note.fromJson);
      debugPrint(
          '[AppProvider] 云端笔记加载完成: ${_notes.length} 条, ${sw.elapsedMilliseconds}ms');
      notifyListeners();
      return;
    }
    _notes = await _noteDao.getAllNotes(
        sortMode: sortMode ?? UserPrefs().noteSortMode);
    debugPrint(
        '[AppProvider] 笔记加载完成: ${_notes.length} 条, ${sw.elapsedMilliseconds}ms');
    notifyListeners();
  }

  // 加载游戏数据
  Future<void> loadGames() async {
    final sw = Stopwatch()..start();
    if (_cloudGameMode) {
      final page = await _cloudDomain.pageMain(
        'games',
        Game.fromJson,
        sortMode: UserPrefs().effectiveGameSortMode,
        offset: 0,
        limit: firstPageSize,
      );
      _games = page.list;
      _invalidateCloudMainCounts('games');
      _cloudMainCountCache['games'] = page.total;
      debugPrint(
          '[AppProvider] 云端游戏加载完成: ${_games.length} 条, ${sw.elapsedMilliseconds}ms');
      if (_frostedActive && _frostedCoverPath == null) refreshFrostedCover();
      notifyListeners();
      return;
    }
    _games =
        await _gameDao.getAllGames(sortMode: UserPrefs().effectiveGameSortMode);
    debugPrint(
        '[AppProvider] 游戏加载完成: ${_games.length} 条, ${sw.elapsedMilliseconds}ms');
    if (_frostedActive && _frostedCoverPath == null) refreshFrostedCover();
    notifyListeners();
  }

  // 加载片单数据
  Future<void> loadPlaylists() async {
    final sw = Stopwatch()..start();
    if (_cloudPlaylistMode) {
      _playlists =
          await _cloudDomain.listEntities('playlists', Playlist.fromJson);
      debugPrint(
          '[AppProvider] 云端片单加载完成: ${_playlists.length} 条, ${sw.elapsedMilliseconds}ms');
      notifyListeners();
      return;
    }
    _playlists = await _playlistDao.getAllPlaylists();
    debugPrint(
        '[AppProvider] 片单加载完成: ${_playlists.length} 条, ${sw.elapsedMilliseconds}ms');
    notifyListeners();
  }

  // 加载人物数据
  Future<void> loadPeople() async {
    final sw = Stopwatch()..start();
    if (_cloudMovieMode) {
      _people = await _cloudMovie.listEntities('people', Person.fromJson);
      debugPrint(
          '[AppProvider] 云端人物加载完成: ${_people.length} 条, ${sw.elapsedMilliseconds}ms');
      notifyListeners();
      return;
    }
    _people = await _personDao.getAllPeople();
    debugPrint(
        '[AppProvider] 人物加载完成: ${_people.length} 条, ${sw.elapsedMilliseconds}ms');
    notifyListeners();
  }

  // ─── 云端主表计数（服务端独立 COUNT(*)，禁止用首屏 50 条分片的 length）────
  /// key：domain（总数）或 domain|status（状态分类数）
  final Map<String, int> _cloudMainCountCache = {};

  String _countCacheKey(String domain, String? status) =>
      status == null ? domain : '$domain|$status';

  void _invalidateCloudMainCounts(String domain) {
    _cloudMainCountCache
        .removeWhere((k, _) => k == domain || k.startsWith('$domain|'));
  }

  /// 同步读计数缓存，未命中返回 null（调用方回退本地 length 或调 fetch 后重建）
  int? cachedCloudMainCount(String domain, {String? status}) =>
      _cloudMainCountCache[_countCacheKey(domain, status)];

  /// 拉取云端主表计数：page 接口 limit=1，仅取服务端 total（COUNT(*)，与分页无关）
  Future<int> fetchCloudMainCount(String domain, {String? status}) async {
    final key = _countCacheKey(domain, status);
    final cached = _cloudMainCountCache[key];
    if (cached != null) return cached;
    final int total;
    if (domain == 'movies') {
      total =
          (await _cloudMovie.pageMovies(status: status, offset: 0, limit: 1))
              .total;
    } else if (domain == 'books') {
      total = (await _cloudDomain.pageMain('books', Book.fromJson,
              status: status, offset: 0, limit: 1))
          .total;
    } else {
      total = (await _cloudDomain.pageMain('games', Game.fromJson,
              status: status, offset: 0, limit: 1))
          .total;
    }
    _cloudMainCountCache[key] = total;
    return total;
  }

  /// 某域三个状态分类的计数（并发 limit=1 请求），供"我的"页状态分布使用
  Future<Map<String, int>> fetchCloudStatusCounts(
      String domain, List<String> statuses) async {
    final pairs = await Future.wait(statuses.map((s) async =>
        MapEntry(s, await fetchCloudMainCount(domain, status: s))));
    return Map<String, int>.fromEntries(pairs);
  }

  /// 片单页下拉刷新：云端先丢弃 playlist_items 全量缓存，再重拉片单，避免拿到旧条目
  Future<void> refreshPlaylists() async {
    _invalidateCloudPlaylistItems();
    await loadPlaylists();
  }

  /// 侧边栏/我的页 Hero 同步读总数；本地模式或缓存未命中时返回 null
  int? get cloudMovieTotal =>
      _cloudMovieMode ? cachedCloudMainCount('movies') : null;
  int? get cloudBookTotal =>
      _cloudBookMode ? cachedCloudMainCount('books') : null;
  int? get cloudGameTotal =>
      _cloudGameMode ? cachedCloudMainCount('games') : null;

  /// 编辑返回后触发列表页重载
  /// [itemId] 被编辑条目的 ID，用于就地更新而非重置分页
  void setEditRefresh([String? itemId]) {
    _editRefreshCounter++;
    _lastEditedItemId = itemId;
    notifyListeners();
  }

  // ─── 分页加载（供列表页触底加载使用）────────────────────────
  /// 触底加载每页条数
  static const int pageSize = 20;

  /// 首屏加载条数（一次多加载，减少首屏滚动触底次数）
  static const int firstPageSize = 50;

  Future<List<Movie>> loadMoviesPaged(
      {String? status,
      String? category,
      required int offset,
      int sortMode = 0,
      int? limit}) async {
    if (_cloudMovieMode) {
      final page = await _cloudMovie.pageMovies(
        status: status,
        category: category,
        keyword: _movieSearchKeyword,
        sortMode: sortMode,
        offset: offset,
        limit: limit ?? pageSize,
      );
      return page.list;
    }
    return _movieDao.getMoviesPaged(
        status: status,
        category: category,
        limit: limit ?? pageSize,
        offset: offset,
        sortMode: sortMode);
  }

  /// 云模式服务器搜索关键词（本地模式不用，本地走 SQLite LIKE）
  String? _movieSearchKeyword;
  set movieSearchKeyword(String? value) => _movieSearchKeyword = value;

  /// 供 UI 判断当前是否云模式（搜索页等需要区分数据通道的场景）
  bool get isCloudMovieMode => _cloudMovieMode;

  /// 云模式全局搜索：直接走服务端关键词分页（标题/别名 LIKE），一次取较多条供搜索页展示
  Future<List<Movie>> searchCloudMovies(String keyword) async {
    final page =
        await _cloudMovie.pageMovies(keyword: keyword, offset: 0, limit: 100);
    return page.list;
  }

  /// 云模式全局搜索：服务端关键词分页（书名/别名 LIKE），避免只搜内存 50 条分片
  Future<List<Book>> searchCloudBooks(String keyword) async {
    final page = await _cloudDomain.pageMain('books', Book.fromJson,
        keyword: keyword, offset: 0, limit: 100);
    return page.list;
  }

  /// 云模式全局搜索：服务端关键词分页（游戏名/别名 LIKE）
  Future<List<Game>> searchCloudGames(String keyword) async {
    final page = await _cloudDomain.pageMain('games', Game.fromJson,
        keyword: keyword, offset: 0, limit: 100);
    return page.list;
  }

  /// 云模式聚合页用：分页拉全量影视（可按状态过滤），绕过内存首页 50 条分片
  Future<List<Movie>> cloudAllMovies({String? status}) async {
    const pageSize = 100;
    final result = <Movie>[];
    var offset = 0;
    while (true) {
      final page = await _cloudMovie.pageMovies(
          status: status, offset: offset, limit: pageSize);
      result.addAll(page.list);
      if (page.list.isEmpty || result.length >= page.total) break;
      offset += page.list.length;
    }
    return result;
  }

  /// 云模式聚合页用：全量影评（独立实体接口，不依赖内存影视分片）
  Future<List<MovieReview>> cloudAllMovieReviews() async {
    return _cloudMovie.listEntities('movie_reviews', MovieReview.fromJson);
  }

  /// 云模式按 id 拉单部影视（内存首页分片不含时的兜底，如影评表单/详情）
  Future<Movie?> cloudMovieById(String id) async {
    final map = await _cloudMovie.getEntity('movies', id);
    return map == null ? null : Movie.fromJson(map);
  }

  /// 云模式全量分集（Excel 导出用，跨所有影视）
  Future<List<MovieEpisode>> cloudAllMovieEpisodes() async {
    return _cloudMovie.allChildren('movie_episodes', MovieEpisode.fromJson);
  }

  /// 云模式服务端搜索关键词（本地模式不用，本地走 SQLite LIKE）
  String? _bookSearchKeyword;
  String? _gameSearchKeyword;
  set bookSearchKeyword(String? value) => _bookSearchKeyword = value;
  set gameSearchKeyword(String? value) => _gameSearchKeyword = value;

  Future<List<Book>> loadBooksPaged(
      {String? status,
      String? category,
      required int offset,
      int sortMode = 0,
      int? limit}) async {
    if (_cloudBookMode) {
      final page = await _cloudDomain.pageMain(
        'books',
        Book.fromJson,
        status: status,
        category: category,
        keyword: _bookSearchKeyword,
        sortMode: sortMode,
        offset: offset,
        limit: limit ?? pageSize,
      );
      return page.list;
    }
    return _bookDao.getBooksPaged(
        status: status,
        category: category,
        limit: limit ?? pageSize,
        offset: offset,
        sortMode: sortMode);
  }

  Future<List<Note>> loadNotesPaged(
      {required int offset, int sortMode = 0, int? limit}) async {
    if (_cloudNoteMode) {
      // 笔记为独立实体，云端一次取全量后在内存做分页（对齐 listEntities 返回顺序）
      if (_notes.isEmpty) await loadNotes(sortMode: sortMode);
      return _notes.skip(offset).take(limit ?? pageSize).toList();
    }
    return _noteDao.getNotesPaged(
        limit: limit ?? pageSize, offset: offset, sortMode: sortMode);
  }

  Future<List<Game>> loadGamesPaged(
      {String? status,
      required int offset,
      int sortMode = 0,
      int? limit}) async {
    if (_cloudGameMode) {
      final page = await _cloudDomain.pageMain(
        'games',
        Game.fromJson,
        status: status,
        keyword: _gameSearchKeyword,
        sortMode: sortMode,
        offset: offset,
        limit: limit ?? pageSize,
      );
      return page.list;
    }
    return _gameDao.getGamesPaged(
        status: status,
        limit: limit ?? pageSize,
        offset: offset,
        sortMode: sortMode);
  }

  /// 云模式聚合页用：分页拉全量书籍/游戏（可按状态过滤），绕过内存首页分片
  Future<List<Book>> cloudAllBooks({String? status}) =>
      _cloudAllMain('books', Book.fromJson, status: status);
  Future<List<Game>> cloudAllGames({String? status}) =>
      _cloudAllMain('games', Game.fromJson, status: status);

  /// 云模式全量笔记（Excel 导出用，独立实体无分页接口，一次拉全量）
  Future<List<Note>> cloudAllNotes() =>
      _cloudDomain.listEntities('notes', Note.fromJson);

  Future<List<T>> _cloudAllMain<T>(
    String domain,
    T Function(Map<String, dynamic>) parser, {
    String? status,
  }) async {
    const size = 100;
    final result = <T>[];
    var offset = 0;
    while (true) {
      final page = await _cloudDomain.pageMain(domain, parser,
          status: status, offset: offset, limit: size);
      result.addAll(page.list);
      if (page.list.isEmpty || result.length >= page.total) break;
      offset += page.list.length;
    }
    return result;
  }

  /// 云模式按 id 拉单条主实体（内存分片不含时的兜底）
  Future<Book?> cloudBookById(String id) async {
    final map = await _cloudDomain.getEntity('books', id);
    return map == null ? null : Book.fromJson(map);
  }

  Future<Game?> cloudGameById(String id) async {
    final map = await _cloudDomain.getEntity('games', id);
    return map == null ? null : Game.fromJson(map);
  }

  Future<Note?> cloudNoteById(String id) async {
    final map = await _cloudDomain.getEntity('notes', id);
    return map == null ? null : Note.fromJson(map);
  }

  // Getters
  int get mainTabIndex => _mainTabIndex;
  int get homeModuleSwitchMode => _homeModuleSwitchMode;
  int get homeLeadingStyle => _homeLeadingStyle;
  int get bottomNavIndex => _bottomNavIndex;
  Movie? get selectedMovie => _selectedMovie;
  Book? get selectedBook => _selectedBook;
  Note? get selectedNote => _selectedNote;
  Game? get selectedGame => _selectedGame;
  int get movieStatusIndex => _movieStatusIndex;
  int get movieLayoutStyle => _movieLayoutStyle;
  int get bookLayoutStyle => _bookLayoutStyle;
  int get noteContentAlign => _noteContentAlign;
  bool get movieWallMode => _movieWallMode;
  bool get showMovieCardDate => _showMovieCardDate;
  bool get showBookCardDate => _showBookCardDate;
  bool get showGameCardDate => _showGameCardDate;
  int get movieCardDateType => _movieCardDateType;
  int get bookCardDateType => _bookCardDateType;
  int get gameCardDateType => _gameCardDateType;
  int get movieCardTitleAlign => _movieCardTitleAlign;
  int get movieCardRatingAlign => _movieCardRatingAlign;
  int get bookCardTitleAlign => _bookCardTitleAlign;
  int get bookCardRatingAlign => _bookCardRatingAlign;
  int get gameCardTitleAlign => _gameCardTitleAlign;
  int get gameCardRatingAlign => _gameCardRatingAlign;
  bool get showMovieTitle => _showMovieTitle;
  bool get showMovieRating => _showMovieRating;
  bool get showBookTitle => _showBookTitle;
  bool get showBookRating => _showBookRating;
  bool get showGameTitle => _showGameTitle;
  bool get showGameRating => _showGameRating;
  int get movieDisplayMode => _movieDisplayMode;
  int get movieStatusBarStyle => _movieStatusBarStyle;
  int get movieGridCount => _movieGridCount;
  int get bookGridCount => _bookGridCount;
  int get gameGridCount => _gameGridCount;
  int get movieCategoryIndex => _movieCategoryIndex;
  int get bookDisplayMode => _bookDisplayMode;
  int get bookCategoryIndex => _bookCategoryIndex;
  int get bookStatusIndex => _bookStatusIndex;
  int get bookStatusBarStyle => _bookStatusBarStyle;
  bool get bookshelfMode => _bookshelfMode;
  int get gameStatusIndex => _gameStatusIndex;
  int get gameLayoutStyle => _gameLayoutStyle;
  bool get gameWallMode => _gameWallMode;
  int get gameStatusBarStyle => _gameStatusBarStyle;
  bool get drawerOpen => _drawerOpen;
  bool get bottomNavVisible => _bottomNavVisible;
  ThemeMode get themeMode => _themeMode;
  int get colorSchemeIndex => _colorSchemeIndex;

  // 毛玻璃状态
  bool get frostedActive => _frostedActive;
  String? get frostedCoverPath => _frostedCoverPath;
  String get fontFamily => _fontFamily;

  int get languageMode => _languageMode;

  /// MaterialApp.locale：null 表示跟随系统
  Locale? get locale => switch (_languageMode) {
        1 => const Locale('zh', 'CN'),
        2 => const Locale('en', 'US'),
        _ => null,
      };

  void setLanguageMode(int mode) {
    if (_languageMode != mode) {
      _languageMode = mode;
      AppStrings.isEnglish = mode == 2;
      UserPrefs().setLanguageMode(mode);
      notifyListeners();
    }
  }

  List<Movie> get movies => UnmodifiableListView(_movies);
  List<Book> get books => UnmodifiableListView(_books);
  List<Note> get notes => UnmodifiableListView(_notes);
  List<Game> get games => UnmodifiableListView(_games);
  List<Playlist> get playlists => UnmodifiableListView(_playlists);
  List<Person> get people => UnmodifiableListView(_people);
  List<CustomModule> get customModules => UnmodifiableListView(_customModules);

  /// 启用中的自定义模块（首页 tab 用，顺序即 tab 顺序）
  List<CustomModule> get enabledCustomModules =>
      _customModules.where((m) => m.isEnabled).toList();

  CustomModule? getCustomModuleById(String id) {
    for (final m in _customModules) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// 自定义模块 tab 索引基数：mainTabIndex >= 100 时为自定义模块（100+i）
  static const int customModuleTabBase = 100;

  // ========== 自定义模块 CRUD ==========

  Future<void> loadCustomModules() async {
    final sw = Stopwatch()..start();
    _customModules = await _customModuleDao.getAllModules();
    debugPrint(
        '[AppProvider] 自定义模块加载完成: ${_customModules.length} 个, ${sw.elapsedMilliseconds}ms');
    notifyListeners();
  }

  Future<CustomModule> addCustomModule(String name, {String icon = ''}) async {
    final now = DateTime.now();
    final maxSort = _customModules.isEmpty
        ? 0
        : _customModules
                .map((m) => m.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;
    final module = CustomModule(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      sortOrder: maxSort,
      createdAt: now,
      updatedAt: now,
    );
    await _customModuleDao.insertModule(module);
    _customModules.add(module);
    notifyListeners();
    return module;
  }

  Future<void> updateCustomModule(CustomModule module) async {
    final updated = module.copyWith(updatedAt: DateTime.now());
    await _customModuleDao.updateModule(updated);
    final idx = _customModules.indexWhere((m) => m.id == module.id);
    if (idx != -1) _customModules[idx] = updated;
    notifyListeners();
  }

  Future<void> deleteCustomModule(String id) async {
    // 记录当前 tab 对应的模块，删除后按模块 id 重新定位，避免误伤其他模块 tab
    String? currentModuleId;
    if (_mainTabIndex >= customModuleTabBase) {
      final i = _mainTabIndex - customModuleTabBase;
      final mods = enabledCustomModules;
      if (i >= 0 && i < mods.length) currentModuleId = mods[i].id;
    }
    await _customModuleDao.deleteModule(id);
    _customModules.removeWhere((m) => m.id == id);
    if (currentModuleId != null) {
      if (currentModuleId == id) {
        // 当前 tab 正停在被删模块上，回退到第一个固定 tab
        _mainTabIndex = 0;
      } else {
        final newIdx =
            enabledCustomModules.indexWhere((m) => m.id == currentModuleId);
        _mainTabIndex = newIdx != -1 ? customModuleTabBase + newIdx : 0;
      }
    }
    notifyListeners();
  }

  Future<void> setCustomModuleEnabled(String id, bool enabled) async {
    // 记录当前 tab 对应的模块，仅当被停用的正是当前模块时才回退
    String? currentModuleId;
    if (_mainTabIndex >= customModuleTabBase) {
      final i = _mainTabIndex - customModuleTabBase;
      final mods = enabledCustomModules;
      if (i >= 0 && i < mods.length) currentModuleId = mods[i].id;
    }
    await _customModuleDao.setEnabled(id, enabled);
    final idx = _customModules.indexWhere((m) => m.id == id);
    if (idx != -1) {
      _customModules[idx] = _customModules[idx]
          .copyWith(isEnabled: enabled, updatedAt: DateTime.now());
    }
    if (currentModuleId != null) {
      if (!enabled && currentModuleId == id) {
        _mainTabIndex = 0;
      } else {
        final newIdx =
            enabledCustomModules.indexWhere((m) => m.id == currentModuleId);
        _mainTabIndex = newIdx != -1 ? customModuleTabBase + newIdx : 0;
      }
    }
    notifyListeners();
  }

  /// 自定义模块条目变更版本号：条目页各自用 DAO 读写，
  /// 通过底部 + 弹窗等外部入口新增后，借此通知 tab 页刷新列表
  int _customModuleItemsVersion = 0;
  int get customModuleItemsVersion => _customModuleItemsVersion;
  void bumpCustomModuleItemsVersion() {
    _customModuleItemsVersion++;
    _allCustomItemsCache = null;
    notifyListeners();
  }

  // 本地搜索用：全部模块未删除条目的一次性内存缓存，条目变动时随版本号失效
  List<CustomModuleItem>? _allCustomItemsCache;
  Future<List<CustomModuleItem>> ensureCustomItemsLoaded() async {
    return _allCustomItemsCache ??=
        await _customModuleItemDao.getAllActiveItems();
  }

  // ========== 自定义模块条目回收站 ==========

  Future<List<CustomModuleItem>> getDeletedCustomModuleItems() async {
    return await _customModuleItemDao.getDeletedItems();
  }

  Future<void> restoreCustomModuleItem(String id) async {
    await _customModuleItemDao.restoreItem(id);
    bumpCustomModuleItemsVersion();
  }

  Future<void> permanentDeleteCustomModuleItem(String id) async {
    final item = await _customModuleItemDao.getItemRaw(id);
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('custom_module_items', id, txn);
      await _customModuleItemDao.permanentDeleteItem(id, txn: txn);
    });
    if (item != null) {
      await ImagePathHelper.instance
          .deleteCustomModuleItemImages(item.moduleId, id);
    }
    // 失效全局搜索缓存并通知刷新，否则已彻底删除的条目仍残留在搜索结果中
    bumpCustomModuleItemsVersion();
  }

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
    if (index != _mainTabIndex) {
      debugPrint('[主页] 切换标签: ${_mainTabName(index)}');
    }
    _mainTabIndex = index;
    // 写穿到启动标签偏好：点击选择常驻，重启后恢复上次选择
    UserPrefs().setDefaultMainTabIndex(index);
    notifyListeners();
  }

  /// 日志用：主标签名称
  String _mainTabName(int index) {
    switch (index) {
      case -1:
        return '主页';
      case 0:
        return '影视';
      case 1:
        return '阅读';
      case 2:
        return '笔记';
      case 3:
        return '游戏';
      default:
        if (index >= customModuleTabBase) {
          final i = index - customModuleTabBase;
          final modules = enabledCustomModules;
          if (i >= 0 && i < modules.length) return modules[i].name;
          return '自定义模块';
        }
        return '未知($index)';
    }
  }

  void setHomeModuleSwitchMode(int mode) {
    _homeModuleSwitchMode = mode;
    UserPrefs().setHomeModuleSwitchMode(mode);
    notifyListeners();
  }

  void setHomeLeadingStyle(int style) {
    _homeLeadingStyle = style;
    UserPrefs().setHomeLeadingStyle(style);
    notifyListeners();
  }

  /// 模块开关等设置变更后调用，通知各页面重新读取 UserPrefs
  void refreshTabSettings() {
    // 当前标签被关闭时，回退到第一个启用的标签
    final userPrefs = UserPrefs();
    final enabled = [
      userPrefs.showMovieTab,
      userPrefs.showBookTab,
      userPrefs.showNoteTab,
      userPrefs.showGameTab
    ];
    if (_mainTabIndex >= customModuleTabBase) {
      // 自定义模块标签被停用/删除时回退
      final idx = _mainTabIndex - customModuleTabBase;
      if (idx >= enabledCustomModules.length) {
        _mainTabIndex = enabled.indexWhere((e) => e);
        if (_mainTabIndex == -1) _mainTabIndex = 0;
      }
    } else if (_mainTabIndex >= 0 &&
        _mainTabIndex < enabled.length &&
        !enabled[_mainTabIndex]) {
      _mainTabIndex = enabled.indexWhere((e) => e);
      if (_mainTabIndex == -1) {
        _mainTabIndex =
            enabledCustomModules.isNotEmpty ? customModuleTabBase : 0;
      }
    }
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

  bool get isAdding => _isAdding;
  int? get addingType => _addingType;

  void startAdding() {
    _isAdding = true;
    _addingType = null;
    // 清除选中项，避免同时显示详情和添加
    _selectedMovie = null;
    _selectedBook = null;
    _selectedNote = null;
    _selectedGame = null;
    notifyListeners();
  }

  void startAddingType(int type) {
    _isAdding = true;
    _addingType = type;
    _selectedMovie = null;
    _selectedBook = null;
    _selectedNote = null;
    _selectedGame = null;
    _mainTabIndex = type;
    notifyListeners();
  }

  void cancelAdding() {
    _isAdding = false;
    _addingType = null;
    notifyListeners();
  }

  void finishAdding() {
    _isAdding = false;
    _addingType = null;
    notifyListeners();
  }

  void setBottomNavVisible(bool visible) {
    if (_bottomNavVisible != visible) {
      _bottomNavVisible = visible;
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode mode) {
    final wasFrosted = _frostedActive;
    _frostedActive = false;
    UserPrefs()
        .setThemeMode(mode.index); // 0=system, 1=light, 2=dark, 3=frosted
    if (_themeMode != mode || wasFrosted) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  /// 启用毛玻璃主题（themeMode=3），随机取一张封面作为背景
  void enableFrosted() {
    _frostedActive = true;
    _themeMode = ThemeMode.dark;
    UserPrefs().setThemeMode(3);
    refreshFrostedCover();
  }

  /// 从影视/书籍/游戏封面中随机取一张作为毛玻璃背景
  void refreshFrostedCover() {
    if (!_frostedActive) return;
    final paths = <String>[
      ..._movies
          .where((m) => m.posterPath != null && m.posterPath!.isNotEmpty)
          .map((m) => m.posterPath!),
      ..._books
          .where((b) => b.coverPath != null && b.coverPath!.isNotEmpty)
          .map((b) => b.coverPath!),
      ..._games
          .where((g) => g.coverPath != null && g.coverPath!.isNotEmpty)
          .map((g) => g.coverPath!),
    ];
    _frostedCoverPath =
        paths.isEmpty ? null : paths[Random().nextInt(paths.length)];
    notifyListeners();
  }

  Future<void> loadThemeMode() async {
    final prefs = UserPrefs();
    switch (prefs.themeMode) {
      case 1:
        _themeMode = ThemeMode.light;
      case 2:
        _themeMode = ThemeMode.dark;
      case 3:
        // 毛玻璃主题已下线：旧用户存储的 3 回退为跟随系统，并覆写持久化值
        _themeMode = ThemeMode.system;
        UserPrefs().setThemeMode(0);
      default:
        _themeMode = ThemeMode.system;
    }
    _colorSchemeIndex =
        prefs.colorSchemeIndex.clamp(-1, AppTheme.seedColors.length - 1);
    _fontFamily = prefs.fontFamily;
    _languageMode = prefs.languageMode;
    AppStrings.isEnglish = _languageMode == 2;
    AppTheme.setFontFamily(_fontFamily);
    // 预加载已缓存的字体：必须先完成注册再 notifyListeners，
    // 否则 Selector 的重建发生在字体注册前（渲染成回退字体），
    // 注册完成后的二次通知又会因选中记录无变化被 Selector 吞掉
    if (_fontFamily.isNotEmpty) {
      debugPrint('[字体] 启动恢复字体: $_fontFamily');
      final ok = await FontDownloadManager().preloadCachedFont(_fontFamily);
      debugPrint('[字体] 预加载${ok ? '成功' : '失败'}: $_fontFamily');
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
      debugPrint(
          '[字体] 切换字体: ${_fontFamily.isEmpty ? '默认' : _fontFamily} → ${family.isEmpty ? '默认' : family}');
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
    final prefs = UserPrefs();
    final prevSort = prefs.effectiveMovieSortMode;
    _movieLayoutStyle = style;
    prefs.setMovieLayoutStyle(style);
    notifyListeners();
    // 布局会影响实际排序（年份网格强制按年份排），排序变化时重载列表
    if (prefs.effectiveMovieSortMode != prevSort) loadMovies();
  }

  void setBookLayoutStyle(int style) {
    final prefs = UserPrefs();
    final prevSort = prefs.effectiveBookSortMode;
    _bookLayoutStyle = style;
    prefs.setBookLayoutStyle(style);
    notifyListeners();
    if (prefs.effectiveBookSortMode != prevSort) loadBooks();
  }

  void setNoteContentAlign(int align) {
    _noteContentAlign = align;
    UserPrefs().setNoteContentAlign(align);
    notifyListeners();
  }

  void setMovieWallMode(bool enabled) {
    _movieWallMode = enabled;
    UserPrefs().setMovieWallMode(enabled);
    notifyListeners();
  }

  void setShowMovieCardDate(bool enabled) {
    _showMovieCardDate = enabled;
    UserPrefs().setShowMovieCardDate(enabled);
    notifyListeners();
  }

  void setShowBookCardDate(bool enabled) {
    _showBookCardDate = enabled;
    UserPrefs().setShowBookCardDate(enabled);
    notifyListeners();
  }

  void setShowGameCardDate(bool enabled) {
    _showGameCardDate = enabled;
    UserPrefs().setShowGameCardDate(enabled);
    notifyListeners();
  }

  void setMovieCardDateType(int type) {
    _movieCardDateType = type;
    UserPrefs().setMovieCardDateType(type);
    notifyListeners();
  }

  void setBookCardDateType(int type) {
    _bookCardDateType = type;
    UserPrefs().setBookCardDateType(type);
    notifyListeners();
  }

  void setGameCardDateType(int type) {
    _gameCardDateType = type;
    UserPrefs().setGameCardDateType(type);
    notifyListeners();
  }

  void setMovieCardTitleAlign(int align) {
    _movieCardTitleAlign = align;
    UserPrefs().setMovieCardTitleAlign(align);
    notifyListeners();
  }

  void setMovieCardRatingAlign(int align) {
    _movieCardRatingAlign = align;
    UserPrefs().setMovieCardRatingAlign(align);
    notifyListeners();
  }

  void setBookCardTitleAlign(int align) {
    _bookCardTitleAlign = align;
    UserPrefs().setBookCardTitleAlign(align);
    notifyListeners();
  }

  void setBookCardRatingAlign(int align) {
    _bookCardRatingAlign = align;
    UserPrefs().setBookCardRatingAlign(align);
    notifyListeners();
  }

  void setGameCardTitleAlign(int align) {
    _gameCardTitleAlign = align;
    UserPrefs().setGameCardTitleAlign(align);
    notifyListeners();
  }

  void setGameCardRatingAlign(int align) {
    _gameCardRatingAlign = align;
    UserPrefs().setGameCardRatingAlign(align);
    notifyListeners();
  }

  void setShowMovieTitle(bool enabled) {
    _showMovieTitle = enabled;
    UserPrefs().setShowMovieTitle(enabled);
    notifyListeners();
  }

  void setShowMovieRating(bool enabled) {
    _showMovieRating = enabled;
    UserPrefs().setShowMovieRating(enabled);
    notifyListeners();
  }

  void setShowBookTitle(bool enabled) {
    _showBookTitle = enabled;
    UserPrefs().setShowBookTitle(enabled);
    notifyListeners();
  }

  void setShowBookRating(bool enabled) {
    _showBookRating = enabled;
    UserPrefs().setShowBookRating(enabled);
    notifyListeners();
  }

  void setShowGameTitle(bool enabled) {
    _showGameTitle = enabled;
    UserPrefs().setShowGameTitle(enabled);
    notifyListeners();
  }

  void setShowGameRating(bool enabled) {
    _showGameRating = enabled;
    UserPrefs().setShowGameRating(enabled);
    notifyListeners();
  }

  void setMovieDisplayMode(int mode) {
    _movieDisplayMode = mode;
    UserPrefs().setMovieDisplayMode(mode);
    notifyListeners();
  }

  void setMovieStatusBarStyle(int style) {
    _movieStatusBarStyle = style;
    UserPrefs().setMovieStatusBarStyle(style);
    notifyListeners();
  }

  void setMovieGridCount(int count) {
    _movieGridCount = count;
    UserPrefs().setMovieGridCount(count);
    notifyListeners();
  }

  void setBookGridCount(int count) {
    _bookGridCount = count;
    UserPrefs().setBookGridCount(count);
    notifyListeners();
  }

  void setGameGridCount(int count) {
    _gameGridCount = count;
    UserPrefs().setGameGridCount(count);
    notifyListeners();
  }

  void setMovieCategoryIndex(int index) {
    _movieCategoryIndex = index;
    notifyListeners();
  }

  void setBookDisplayMode(int mode) {
    _bookDisplayMode = mode;
    UserPrefs().setBookDisplayMode(mode);
    notifyListeners();
  }

  void setBookCategoryIndex(int index) {
    _bookCategoryIndex = index;
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

  void setBookStatusBarStyle(int style) {
    _bookStatusBarStyle = style;
    UserPrefs().setBookStatusBarStyle(style);
    notifyListeners();
  }

  void setGameStatusIndex(int index) {
    _gameStatusIndex = index;
    notifyListeners();
  }

  void setGameLayoutStyle(int style) {
    final prefs = UserPrefs();
    final prevSort = prefs.effectiveGameSortMode;
    _gameLayoutStyle = style;
    prefs.setGameLayoutStyle(style);
    notifyListeners();
    if (prefs.effectiveGameSortMode != prevSort) loadGames();
  }

  void setGameWallMode(bool enabled) {
    _gameWallMode = enabled;
    UserPrefs().setGameWallMode(enabled);
    notifyListeners();
  }

  void setGameStatusBarStyle(int style) {
    _gameStatusBarStyle = style;
    UserPrefs().setGameStatusBarStyle(style);
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

  /// 日志用标题兜底：空标题/超长标题处理
  static String _logTitle(String title) {
    if (title.isEmpty) return '(无标题)';
    return title.length > 30 ? '${title.substring(0, 30)}…' : title;
  }

  /// 日志用：按 id 从列表查标题，查不到返回 '?'
  static String _titleById<T>(List<T> items, String id,
      String Function(T) getId, String Function(T) getTitle) {
    for (final e in items) {
      if (getId(e) == id) return _logTitle(getTitle(e));
    }
    return '?';
  }

  /// 日志用：正文摘要（去换行，截 20 字）
  static String _logSnippet(String text) {
    final t = text.replaceAll('\n', ' ').trim();
    return t.length > 20 ? '${t.substring(0, 20)}…' : t;
  }

  // 添加影视记录
  Future<void> addMovie(Movie movie) async {
    if (_cloudMovieMode) {
      await _cloudMovie.createMovie(movie);
      _invalidateCloudMainCounts('movies');
      _movies.add(movie);
      debugPrint('[云端] 新增影视《${_logTitle(movie.title)}》');
      notifyListeners();
      return;
    }
    await _movieDao.insertMovie(movie);
    _movies.add(movie);
    debugPrint('[数据] 新增影视《${_logTitle(movie.title)}》');
    notifyListeners();
  }

  Future<void> updateMovie(Movie movie) async {
    if (_cloudMovieMode) {
      await _cloudMovie.updateMovie(movie);
      _invalidateCloudMainCounts('movies');
      final idx = _movies.indexWhere((m) => m.id == movie.id);
      if (idx != -1) _movies[idx] = movie;
      debugPrint('[云端] 更新影视《${_logTitle(movie.title)}》');
      notifyListeners();
      return;
    }
    await _movieDao.updateMovie(movie);
    final idx = _movies.indexWhere((m) => m.id == movie.id);
    if (idx != -1) _movies[idx] = movie;
    debugPrint('[数据] 更新影视《${_logTitle(movie.title)}》');
    notifyListeners();
  }

  /// 仅更新封面偏移量（不触发全量刷新）
  Future<void> updateMovieCoverOffset(String movieId, double offset) async {
    if (_cloudMovieMode) {
      await _cloudMovie.updateCoverOffset(movieId, offset);
      final idx = _movies.indexWhere((m) => m.id == movieId);
      if (idx != -1) {
        _movies[idx] = _movies[idx].copyWith(coverOffset: offset);
        notifyListeners();
      }
      return;
    }
    await _movieDao.updateCoverOffset(movieId, offset);
    final idx = _movies.indexWhere((m) => m.id == movieId);
    if (idx != -1) {
      _movies[idx] = _movies[idx].copyWith(coverOffset: offset);
      notifyListeners();
    }
  }

  /// 仅更新封面偏移量（不触发全量刷新）
  Future<void> updateBookCoverOffset(String bookId, double offset) async {
    if (_cloudBookMode) {
      await _cloudDomain.updateCoverOffset('books', bookId, offset);
      final idx = _books.indexWhere((b) => b.id == bookId);
      if (idx != -1) {
        _books[idx] = _books[idx].copyWith(coverOffset: offset);
        notifyListeners();
      }
      return;
    }
    await _bookDao.updateCoverOffset(bookId, offset);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx != -1) {
      _books[idx] = _books[idx].copyWith(coverOffset: offset);
      notifyListeners();
    }
  }

  Future<void> removeMovie(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.softDeleteMovie(id);
      _invalidateCloudMainCounts('movies');
      final idx = _movies.indexWhere((m) => m.id == id);
      final title = idx != -1 ? _movies[idx].title : '';
      if (idx != -1) _movies.removeAt(idx);
      debugPrint('[云端] 删除影视《${_logTitle(title)}》');
      notifyListeners();
      return;
    }
    await _movieDao.deleteMovie(id);
    final idx = _movies.indexWhere((m) => m.id == id);
    final title = idx != -1 ? _movies[idx].title : '';
    if (idx != -1) _movies.removeAt(idx);
    debugPrint('[数据] 删除影视《${_logTitle(title)}》');
    notifyListeners();
  }

  Future<void> addBook(Book book) async {
    if (_cloudBookMode) {
      await _cloudDomain.createMain('books', book.toJson());
      _invalidateCloudMainCounts('books');
      _books.add(book);
      debugPrint('[云端] 新增书籍《${_logTitle(book.title)}》');
      notifyListeners();
      return;
    }
    await _bookDao.insertBook(book);
    _books.add(book);
    debugPrint('[数据] 新增书籍《${_logTitle(book.title)}》');
    notifyListeners();
  }

  Future<void> updateBook(Book book) async {
    if (_cloudBookMode) {
      await _cloudDomain.updateMain('books', book.id, book.toJson());
      _invalidateCloudMainCounts('books');
      final idx = _books.indexWhere((b) => b.id == book.id);
      if (idx != -1) _books[idx] = book;
      debugPrint('[云端] 更新书籍《${_logTitle(book.title)}》');
      notifyListeners();
      return;
    }
    await _bookDao.updateBook(book);
    final idx = _books.indexWhere((b) => b.id == book.id);
    if (idx != -1) _books[idx] = book;
    debugPrint('[数据] 更新书籍《${_logTitle(book.title)}》');
    notifyListeners();
  }

  Future<void> removeBook(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.softDeleteMain('books', id);
      _invalidateCloudMainCounts('books');
      final idx = _books.indexWhere((b) => b.id == id);
      final title = idx != -1 ? _books[idx].title : '';
      if (idx != -1) _books.removeAt(idx);
      debugPrint('[云端] 删除书籍《${_logTitle(title)}》');
      notifyListeners();
      return;
    }
    await _bookDao.deleteBook(id);
    final idx = _books.indexWhere((b) => b.id == id);
    final title = idx != -1 ? _books[idx].title : '';
    if (idx != -1) _books.removeAt(idx);
    debugPrint('[数据] 删除书籍《${_logTitle(title)}》');
    notifyListeners();
  }

  Future<void> addNote(Note note) async {
    if (_cloudNoteMode) {
      await _cloudDomain.createEntity('notes', note.toJson());
      _notes.add(note);
      debugPrint('[云端] 新增笔记《${_logTitle(note.title)}》');
      notifyListeners();
      return;
    }
    await _noteDao.insertNote(note);
    _notes.add(note);
    debugPrint('[数据] 新增笔记《${_logTitle(note.title)}》');
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    if (_cloudNoteMode) {
      await _cloudDomain.updateEntity('notes', note.id, note.toJson());
      final idx = _notes.indexWhere((n) => n.id == note.id);
      if (idx != -1) _notes[idx] = note;
      debugPrint('[云端] 更新笔记《${_logTitle(note.title)}》');
      notifyListeners();
      return;
    }
    await _noteDao.updateNote(note);
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx != -1) _notes[idx] = note;
    debugPrint('[数据] 更新笔记《${_logTitle(note.title)}》');
    notifyListeners();
  }

  Future<void> removeNote(String id) async {
    if (_cloudNoteMode) {
      await _cloudDomain.deleteEntity('notes', id);
      final idx = _notes.indexWhere((n) => n.id == id);
      final title = idx != -1 ? _notes[idx].title : '';
      if (idx != -1) _notes.removeAt(idx);
      debugPrint('[云端] 删除笔记《${_logTitle(title)}》');
      notifyListeners();
      return;
    }
    await _noteDao.deleteNote(id);
    final idx = _notes.indexWhere((n) => n.id == id);
    final title = idx != -1 ? _notes[idx].title : '';
    if (idx != -1) _notes.removeAt(idx);
    debugPrint('[数据] 删除笔记《${_logTitle(title)}》');
    notifyListeners();
  }

  Future<void> addGame(Game game) async {
    if (_cloudGameMode) {
      await _cloudDomain.createMain('games', game.toJson());
      _invalidateCloudMainCounts('games');
      _games.add(game);
      debugPrint('[云端] 新增游戏《${_logTitle(game.title)}》');
      notifyListeners();
      return;
    }
    await _gameDao.insertGame(game);
    _games.add(game);
    debugPrint('[数据] 新增游戏《${_logTitle(game.title)}》');
    notifyListeners();
  }

  Future<void> updateGame(Game game) async {
    if (_cloudGameMode) {
      await _cloudDomain.updateMain('games', game.id, game.toJson());
      _invalidateCloudMainCounts('games');
      final idx = _games.indexWhere((g) => g.id == game.id);
      if (idx != -1) _games[idx] = game;
      debugPrint('[云端] 更新游戏《${_logTitle(game.title)}》');
      notifyListeners();
      return;
    }
    await _gameDao.updateGame(game);
    final idx = _games.indexWhere((g) => g.id == game.id);
    if (idx != -1) _games[idx] = game;
    debugPrint('[数据] 更新游戏《${_logTitle(game.title)}》');
    notifyListeners();
  }

  Future<void> removeGame(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.softDeleteMain('games', id);
      _invalidateCloudMainCounts('games');
      final idx = _games.indexWhere((g) => g.id == id);
      final title = idx != -1 ? _games[idx].title : '';
      if (idx != -1) _games.removeAt(idx);
      debugPrint('[云端] 删除游戏《${_logTitle(title)}》');
      notifyListeners();
      return;
    }
    await _gameDao.deleteGame(id);
    final idx = _games.indexWhere((g) => g.id == id);
    final title = idx != -1 ? _games[idx].title : '';
    if (idx != -1) _games.removeAt(idx);
    debugPrint('[数据] 删除游戏《${_logTitle(title)}》');
    notifyListeners();
  }

  // ─── 片单操作 ─────────────────────────────────────────────────

  /// playlist_items 云端全量缓存：条目为独立实体，服务端无按片单过滤接口，
  /// 一次拉全量后复用，条目写操作（增/删/重排/硬删片单）时失效
  List<PlaylistItem>? _cloudPlaylistItemsCache;
  void _invalidateCloudPlaylistItems() => _cloudPlaylistItemsCache = null;

  /// 云端拉取某片单的全部条目（playlist_items 为独立实体，客户端按 playlist_id 过滤）
  Future<List<PlaylistItem>> _cloudPlaylistItems(String playlistId) async {
    final all = _cloudPlaylistItemsCache ??= await _cloudDomain.listEntities(
        'playlist_items', PlaylistItem.fromJson);
    final rows = all.where((i) => i.playlistId == playlistId).toList();
    rows.sort((a, b) {
      if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
      return a.addedAt.compareTo(b.addedAt);
    });
    return rows;
  }

  /// 云端按条目行数重算并回写 item_count
  Future<void> _syncCloudPlaylistCount(String playlistId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    final count = (await _cloudPlaylistItems(playlistId)).length;
    final updated = _playlists[idx].copyWith(itemCount: count);
    await _cloudDomain
        .updateEntity('playlists', playlistId, {'item_count': count});
    _playlists[idx] = updated;
  }

  Future<void> addPlaylist(Playlist playlist) async {
    if (_cloudPlaylistMode) {
      await _cloudDomain.createEntity('playlists', playlist.toJson());
      _playlists.add(playlist);
      debugPrint('[云端] 新增片单《${_logTitle(playlist.name)}》');
      notifyListeners();
      return;
    }
    await _playlistDao.insertPlaylist(playlist);
    _playlists.add(playlist);
    debugPrint('[数据] 新增片单《${_logTitle(playlist.name)}》');
    notifyListeners();
  }

  Future<void> removePlaylist(String id) async {
    if (_cloudPlaylistMode) {
      // mn_playlists 含 is_deleted，通用 deleteEntity 走软删；条目引用保留，恢复后内容完整
      await _cloudDomain.deleteEntity('playlists', id);
      final idx = _playlists.indexWhere((p) => p.id == id);
      final name = idx != -1 ? _playlists[idx].name : '';
      if (idx != -1) _playlists.removeAt(idx);
      debugPrint('[云端] 删除片单《${_logTitle(name)}》');
      notifyListeners();
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('playlists', id, txn);
      await _playlistDao.deletePlaylist(id, txn: txn);
    });
    final idx = _playlists.indexWhere((p) => p.id == id);
    final name = idx != -1 ? _playlists[idx].name : '';
    if (idx != -1) _playlists.removeAt(idx);
    debugPrint('[数据] 删除片单《${_logTitle(name)}》');
    notifyListeners();
  }

  /// 获取已删除的片单（回收站）
  Future<List<Playlist>> getDeletedPlaylists() async {
    if (_cloudPlaylistMode) {
      return _cloudDomain.deletedEntities('playlists', Playlist.fromJson);
    }
    return await _playlistDao.getDeletedPlaylists();
  }

  /// 恢复片单
  Future<void> restorePlaylist(String id) async {
    if (_cloudPlaylistMode) {
      await _cloudDomain.restoreEntity('playlists', id);
      await loadPlaylists();
      return;
    }
    await _playlistDao.restorePlaylist(id);
    await loadPlaylists();
  }

  /// 彻底删除片单
  Future<void> permanentDeletePlaylist(String id) async {
    if (_cloudPlaylistMode) {
      // playlist_items 无软删除列，逐条硬删，再硬删片单
      for (final item in await _cloudPlaylistItems(id)) {
        await _cloudDomain.deleteEntity('playlist_items', item.id);
      }
      _invalidateCloudPlaylistItems();
      await _cloudDomain.permanentDeleteEntity('playlists', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('playlists', id, txn);
      await _playlistDao.permanentDeletePlaylist(id, txn: txn);
    });
  }

  Future<void> updatePlaylist(Playlist playlist) async {
    if (_cloudPlaylistMode) {
      await _cloudDomain.updateEntity(
          'playlists', playlist.id, playlist.toJson());
      final idx = _playlists.indexWhere((p) => p.id == playlist.id);
      if (idx != -1) _playlists[idx] = playlist;
      debugPrint('[云端] 更新片单《${_logTitle(playlist.name)}》');
      notifyListeners();
      return;
    }
    await _playlistDao.updatePlaylist(playlist);
    final idx = _playlists.indexWhere((p) => p.id == playlist.id);
    if (idx != -1) _playlists[idx] = playlist;
    debugPrint('[数据] 更新片单《${_logTitle(playlist.name)}》');
    notifyListeners();
  }

  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    if (_cloudPlaylistMode) {
      return _cloudPlaylistItems(playlistId);
    }
    return _playlistDao.getPlaylistItems(playlistId);
  }

  Future<void> addPlaylistItem(PlaylistItem item) async {
    if (_cloudPlaylistMode) {
      await _cloudDomain.createEntity('playlist_items', item.toJson());
      _invalidateCloudPlaylistItems();
      await _syncCloudPlaylistCount(item.playlistId);
      notifyListeners();
      return;
    }
    await _playlistDao.addItem(item);
    // DAO 已按"排除软删除媒体"口径重算 item_count，从 DB 回读保持一致
    await _syncPlaylistFromDb(item.playlistId);
    notifyListeners();
  }

  Future<void> removePlaylistItem(String itemId, String playlistId) async {
    if (_cloudPlaylistMode) {
      await _cloudDomain.deleteEntity('playlist_items', itemId);
      _invalidateCloudPlaylistItems();
      await _syncCloudPlaylistCount(playlistId);
      notifyListeners();
      return;
    }
    await _playlistDao.removeItem(itemId, playlistId);
    await _syncPlaylistFromDb(playlistId);
    notifyListeners();
  }

  /// 从 DB 回读单个片单同步到内存列表。
  /// 内存列表尚未加载（启动窗口）时静默跳过，下次 loadPlaylists 会拿到正确值。
  Future<void> _syncPlaylistFromDb(String playlistId) async {
    final idx = _playlists.indexWhere((p) => p.id == playlistId);
    if (idx == -1) return;
    final fresh = await _playlistDao.getPlaylistById(playlistId);
    if (fresh != null) _playlists[idx] = fresh;
  }

  Future<List<String>> getPlaylistItemIds(String playlistId) async {
    if (_cloudPlaylistMode) {
      return (await _cloudPlaylistItems(playlistId))
          .map((i) => i.itemId)
          .toList();
    }
    return _playlistDao.getPlaylistItemIds(playlistId);
  }

  Future<void> reorderPlaylists(List<String> playlistIds) async {
    if (_cloudPlaylistMode) {
      // 并发提交，缩短多条目重排的耗时窗口；任一失败抛出让 UI 感知
      await Future.wait(List.generate(
        playlistIds.length,
        (i) => _cloudDomain
            .updateEntity('playlists', playlistIds[i], {'sort_order': i}),
      ));
      // 更新内存中的排序
      final orderMap = {
        for (int i = 0; i < playlistIds.length; i++) playlistIds[i]: i
      };
      _playlists
          .sort((a, b) => (orderMap[a.id] ?? 0).compareTo(orderMap[b.id] ?? 0));
      notifyListeners();
      return;
    }
    await _playlistDao.updatePlaylistOrder(playlistIds);
    // 更新内存中的排序
    final orderMap = {
      for (int i = 0; i < playlistIds.length; i++) playlistIds[i]: i
    };
    _playlists
        .sort((a, b) => (orderMap[a.id] ?? 0).compareTo(orderMap[b.id] ?? 0));
    notifyListeners();
  }

  Future<void> reorderPlaylistItems(
      String playlistId, List<String> itemIds) async {
    if (_cloudPlaylistMode) {
      await Future.wait(List.generate(
        itemIds.length,
        (i) => _cloudDomain
            .updateEntity('playlist_items', itemIds[i], {'sort_order': i}),
      ));
      _invalidateCloudPlaylistItems();
      return;
    }
    await _playlistDao.updatePlaylistItemOrder(playlistId, itemIds);
  }

  /// 仅更新游戏封面偏移量（不触发全量刷新）
  Future<void> updateGameCoverOffset(String gameId, double offset) async {
    if (_cloudGameMode) {
      await _cloudDomain.updateCoverOffset('games', gameId, offset);
      final idx = _games.indexWhere((g) => g.id == gameId);
      if (idx != -1) {
        _games[idx] = _games[idx].copyWith(coverOffset: offset);
        notifyListeners();
      }
      return;
    }
    await _gameDao.updateCoverOffset(gameId, offset);
    final idx = _games.indexWhere((g) => g.id == gameId);
    if (idx != -1) {
      _games[idx] = _games[idx].copyWith(coverOffset: offset);
      notifyListeners();
    }
  }

  Future<void> toggleNotePin(String id, bool isPinned) async {
    if (_cloudNoteMode) {
      await _cloudDomain
          .updateEntity('notes', id, {'id': id, 'is_pinned': isPinned ? 1 : 0});
      final idx = _notes.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notes[idx] = _notes[idx].copyWith(isPinned: isPinned);
      }
      notifyListeners();
      return;
    }
    await _noteDao.togglePin(id, isPinned);
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notes[idx] = _notes[idx].copyWith(isPinned: isPinned);
    }
    notifyListeners();
  }

  // ========== 影评相关方法 ==========

  /// 获取影视的所有影评
  Future<List<MovieReview>> getMovieReviews(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.listChildren(
          movieId, 'movie_reviews', MovieReview.fromJson);
    }
    return await _reviewDao.getReviewsByMovieId(movieId);
  }

  /// 添加影评
  Future<void> addMovieReview(MovieReview review) async {
    if (_cloudMovieMode) {
      await _cloudMovie.createChild(
          review.movieId, 'movie_reviews', review.toJson());
      debugPrint(
          '[云端] 新增影评《${_titleById(_movies, review.movieId, (m) => m.id, (m) => m.title)}》: ${_logSnippet(review.content)}');
      notifyListeners();
      return;
    }
    await _reviewDao.insertReview(review);
    debugPrint(
        '[数据] 新增影评《${_titleById(_movies, review.movieId, (m) => m.id, (m) => m.title)}》: ${_logSnippet(review.content)}');
    notifyListeners();
  }

  /// 更新影评
  Future<void> updateMovieReview(MovieReview review) async {
    if (_cloudMovieMode) {
      await _cloudMovie.updateChild(
          'movie_reviews', review.id, review.toJson());
      debugPrint(
          '[云端] 更新影评《${_titleById(_movies, review.movieId, (m) => m.id, (m) => m.title)}》: ${_logSnippet(review.content)}');
      notifyListeners();
      return;
    }
    await _reviewDao.updateReview(review);
    debugPrint(
        '[数据] 更新影评《${_titleById(_movies, review.movieId, (m) => m.id, (m) => m.title)}》: ${_logSnippet(review.content)}');
    notifyListeners();
  }

  /// 删除影评
  Future<void> removeMovieReview(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.deleteChild('movie_reviews', id);
      debugPrint('[云端] 删除影评 id=$id');
      notifyListeners();
      return;
    }
    final review = await _reviewDao.getReviewById(id);
    await _reviewDao.deleteReview(id);
    final parent = review != null
        ? _titleById(_movies, review.movieId, (m) => m.id, (m) => m.title)
        : '?';
    debugPrint('[数据] 删除影评《$parent》');
    notifyListeners();
  }

  /// 获取影视的影评数量
  Future<int> getMovieReviewCount(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.countChildren(movieId, 'movie_reviews');
    }
    return await _reviewDao.getReviewCount(movieId);
  }

  /// 获取全部影评（导出用）
  Future<List<MovieReview>> getAllMovieReviews() async {
    return await _reviewDao.getAllReviews();
  }

  /// 获取全部书评（导出用）
  Future<List<BookReview>> getAllBookReviews() async {
    if (_cloudBookMode) {
      return _cloudDomain.allChildren('book_reviews', BookReview.fromJson);
    }
    return await _bookReviewDao.getAllReviews();
  }

  /// 获取全部游戏评价（导出用）
  Future<List<GameReview>> getAllGameReviews() async {
    if (_cloudGameMode) {
      return _cloudDomain.allChildren('game_reviews', GameReview.fromJson);
    }
    return await _gameReviewDao.getAllReviews();
  }

  /// 获取全部书摘（书摘浏览页用）
  Future<List<BookExcerpt>> getAllBookExcerpts() async {
    if (_cloudBookMode) {
      return _cloudDomain.allChildren('book_excerpts', BookExcerpt.fromJson);
    }
    return await _bookExcerptDao.getAllExcerpts();
  }

  // ========== 海报墙相关方法 ==========

  /// 获取影视的所有海报
  Future<List<MoviePoster>> getMoviePosters(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.listChildren(
          movieId, 'movie_posters', MoviePoster.fromJson);
    }
    return await _posterDao.getPostersByMovieId(movieId);
  }

  /// 子组表（海报/截图等）无墓碑机制：删除子行后触碰父行 updated_at，
  /// 让增量同步把父行+整组（含删除结果）推送出去，对端整组替换后保持一致
  Future<void> _touchParentUpdatedAt(String table, String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      table,
      {'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 添加海报
  Future<void> addMoviePoster(MoviePoster poster) async {
    if (_cloudMovieMode) {
      await _cloudMovie.createChild(
          poster.movieId, 'movie_posters', poster.toJson());
      debugPrint(
          '[云端] 新增海报《${_titleById(_movies, poster.movieId, (m) => m.id, (m) => m.title)}》');
      notifyListeners();
      return;
    }
    await _posterDao.insertPoster(poster);
    debugPrint(
        '[数据] 新增海报《${_titleById(_movies, poster.movieId, (m) => m.id, (m) => m.title)}》');
    notifyListeners();
  }

  /// 删除海报
  Future<void> removeMoviePoster(String id) async {
    if (_cloudMovieMode) {
      // 云端图片是网络 URL，无本地文件可删；服务端软删并 bump 父行
      await _cloudMovie.deleteChild('movie_posters', id);
      debugPrint('[云端] 删除海报 id=$id');
      notifyListeners();
      return;
    }
    final poster = await _posterDao.getPosterById(id);
    if (poster != null) {
      await ImagePathHelper.instance.deleteFile(poster.posterPath);
      await _posterDao.deletePoster(id);
      // 子组行删除不记墓碑，触碰父行 updated_at 让增量同步整组推送
      await _touchParentUpdatedAt('movies', poster.movieId);
      debugPrint(
          '[数据] 删除海报《${_titleById(_movies, poster.movieId, (m) => m.id, (m) => m.title)}》');
    }
    notifyListeners();
  }

  /// 获取影视的海报数量
  Future<int> getMoviePosterCount(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.countChildren(movieId, 'movie_posters');
    }
    return await _posterDao.getPosterCount(movieId);
  }

  /// 拖动排序海报：持久化新顺序并触碰父行，让增量同步整组推送
  Future<void> reorderMoviePosters(
      String movieId, List<String> orderedIds) async {
    if (_cloudMovieMode) {
      await _cloudMovie.reorderPosters(movieId, orderedIds);
      notifyListeners();
      return;
    }
    await _posterDao.reorderPosters(orderedIds);
    await _touchParentUpdatedAt('movies', movieId);
    notifyListeners();
  }

  // ========== 游戏评价相关方法 ==========

  /// 获取游戏的所有评价
  Future<List<GameReview>> getGameReviews(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.listChildren(
          'games', gameId, 'game_reviews', GameReview.fromJson);
    }
    return await _gameReviewDao.getReviewsByGameId(gameId);
  }

  /// 添加游戏评价
  Future<void> addGameReview(GameReview review) async {
    if (_cloudGameMode) {
      await _cloudDomain.createChild(
          'games', review.gameId, 'game_reviews', review.toJson());
      debugPrint('[云端] 新增游戏评价: ${_logSnippet(review.content)}');
      notifyListeners();
      return;
    }
    await _gameReviewDao.insertReview(review);
    debugPrint(
        '[数据] 新增游戏评价《${_titleById(_games, review.gameId, (g) => g.id, (g) => g.title)}》: ${_logSnippet(review.content)}');
    notifyListeners();
  }

  /// 更新游戏评价
  Future<void> updateGameReview(GameReview review) async {
    if (_cloudGameMode) {
      await _cloudDomain.updateChild(
          'game_reviews', review.id, review.toJson());
      debugPrint('[云端] 更新游戏评价: ${_logSnippet(review.content)}');
      notifyListeners();
      return;
    }
    await _gameReviewDao.updateReview(review);
    debugPrint(
        '[数据] 更新游戏评价《${_titleById(_games, review.gameId, (g) => g.id, (g) => g.title)}》: ${_logSnippet(review.content)}');
    notifyListeners();
  }

  /// 删除游戏评价
  Future<void> removeGameReview(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.deleteChild('game_reviews', id);
      debugPrint('[云端] 删除游戏评价');
      notifyListeners();
      return;
    }
    final review = await _gameReviewDao.getReviewById(id);
    await _gameReviewDao.deleteReview(id);
    final parent = review != null
        ? _titleById(_games, review.gameId, (g) => g.id, (g) => g.title)
        : '?';
    debugPrint('[数据] 删除游戏评价《$parent》');
    notifyListeners();
  }

  /// 获取游戏的评价数量
  Future<int> getGameReviewCount(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.countChildren('games', gameId, 'game_reviews');
    }
    return await _gameReviewDao.getReviewCount(gameId);
  }

  // ========== 游戏截图相关方法 ==========

  /// 获取游戏的所有截图
  Future<List<GameScreenshot>> getGameScreenshots(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.listChildren(
          'games', gameId, 'game_screenshots', GameScreenshot.fromJson);
    }
    return await _gameScreenshotDao.getScreenshotsByGameId(gameId);
  }

  /// 添加游戏截图
  Future<void> addGameScreenshot(GameScreenshot screenshot) async {
    if (_cloudGameMode) {
      await _cloudDomain.createChild(
          'games', screenshot.gameId, 'game_screenshots', screenshot.toJson());
      debugPrint('[云端] 新增游戏截图');
      notifyListeners();
      return;
    }
    await _gameScreenshotDao.insertScreenshot(screenshot);
    debugPrint(
        '[数据] 新增游戏截图《${_titleById(_games, screenshot.gameId, (g) => g.id, (g) => g.title)}》');
    notifyListeners();
  }

  /// 删除游戏截图
  Future<void> removeGameScreenshot(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.deleteChild('game_screenshots', id);
      debugPrint('[云端] 删除游戏截图');
      notifyListeners();
      return;
    }
    final screenshot = await _gameScreenshotDao.getScreenshotById(id);
    if (screenshot != null) {
      await ImagePathHelper.instance.deleteFile(screenshot.screenshotPath);
      await _gameScreenshotDao.deleteScreenshot(id);
      // 子组行删除不记墓碑，触碰父行 updated_at 让增量同步整组推送
      await _touchParentUpdatedAt('games', screenshot.gameId);
      debugPrint(
          '[数据] 删除游戏截图《${_titleById(_games, screenshot.gameId, (g) => g.id, (g) => g.title)}》');
    }
    notifyListeners();
  }

  /// 获取游戏的截图数量
  Future<int> getGameScreenshotCount(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.countChildren('games', gameId, 'game_screenshots');
    }
    return await _gameScreenshotDao.getScreenshotCount(gameId);
  }

  /// 拖动排序截图：持久化新顺序并触碰父行，让增量同步整组推送
  Future<void> reorderGameScreenshots(
      String gameId, List<String> orderedIds) async {
    if (_cloudGameMode) {
      await _cloudDomain.reorderMedia('games', gameId, orderedIds);
      notifyListeners();
      return;
    }
    await _gameScreenshotDao.reorderScreenshots(orderedIds);
    await _touchParentUpdatedAt('games', gameId);
    notifyListeners();
  }

  // ========== 游戏通关记录相关方法 ==========

  /// 获取游戏的所有通关记录
  Future<List<GameCompletion>> getGameCompletions(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.listChildren(
          'games', gameId, 'game_completions', GameCompletion.fromJson);
    }
    return await _gameCompletionDao.getCompletionsByGameId(gameId);
  }

  /// 获取全部通关记录并按游戏 id 分组（供 Excel 导出）
  Future<Map<String, List<GameCompletion>>> getGameCompletionsMap() async {
    if (_cloudGameMode) {
      final all = await _cloudDomain.allChildren(
          'game_completions', GameCompletion.fromJson);
      final map = <String, List<GameCompletion>>{};
      for (final c in all) {
        map.putIfAbsent(c.gameId, () => []).add(c);
      }
      return map;
    }
    final all = await _gameCompletionDao.getAllCompletions();
    final map = <String, List<GameCompletion>>{};
    for (final c in all) {
      map.putIfAbsent(c.gameId, () => []).add(c);
    }
    return map;
  }

  /// 添加通关记录
  Future<void> addGameCompletion(GameCompletion completion) async {
    if (_cloudGameMode) {
      await _cloudDomain.createChild(
          'games', completion.gameId, 'game_completions', completion.toJson());
      debugPrint('[云端] 新增游戏通关记录');
      notifyListeners();
      return;
    }
    await _gameCompletionDao.insertCompletion(completion);
    await _touchParentUpdatedAt('games', completion.gameId);
    debugPrint(
        '[数据] 新增游戏通关记录《${_titleById(_games, completion.gameId, (g) => g.id, (g) => g.title)}》');
    notifyListeners();
  }

  /// 更新通关记录
  Future<void> updateGameCompletion(GameCompletion completion) async {
    if (_cloudGameMode) {
      await _cloudDomain.updateChild(
          'game_completions', completion.id, completion.toJson());
      notifyListeners();
      return;
    }
    await _gameCompletionDao.updateCompletion(completion);
    await _touchParentUpdatedAt('games', completion.gameId);
    notifyListeners();
  }

  /// 删除通关记录
  Future<void> removeGameCompletion(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.deleteChild('game_completions', id);
      debugPrint('[云端] 删除游戏通关记录');
      notifyListeners();
      return;
    }
    final completion = await _gameCompletionDao.getCompletionById(id);
    await _gameCompletionDao.deleteCompletion(id);
    if (completion != null) {
      // 子组行删除不记墓碑，触碰父行 updated_at 让增量同步整组推送
      await _touchParentUpdatedAt('games', completion.gameId);
      debugPrint(
          '[数据] 删除游戏通关记录《${_titleById(_games, completion.gameId, (g) => g.id, (g) => g.title)}》');
    }
    notifyListeners();
  }

  // ========== 影视分集相关方法 ==========

  Future<List<MovieEpisode>> getMovieEpisodes(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.listChildren(
          movieId, 'movie_episodes', MovieEpisode.fromJson);
    }
    return await _movieEpisodeDao.getEpisodesByMovieId(movieId);
  }

  Future<List<MovieEpisode>> getAllMovieEpisodes() =>
      _movieEpisodeDao.getAllEpisodes();

  Future<void> addMovieEpisode(MovieEpisode e) async {
    if (_cloudMovieMode) {
      await _cloudMovie.createChild(e.movieId, 'movie_episodes', e.toJson());
      notifyListeners();
      return;
    }
    await _movieEpisodeDao.insertEpisode(e);
    await _touchParentUpdatedAt('movies', e.movieId);
    notifyListeners();
  }

  /// 批量新增分集（批量生成用）：单事务写入，只触碰父行一次、通知一次
  Future<void> addMovieEpisodesBatch(List<MovieEpisode> list) async {
    if (list.isEmpty) return;
    if (_cloudMovieMode) {
      for (final e in list) {
        await _cloudMovie.createChild(e.movieId, 'movie_episodes', e.toJson());
      }
      notifyListeners();
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final e in list) {
        await txn.insert('movie_episodes', e.toJson());
      }
    });
    await _touchParentUpdatedAt('movies', list.first.movieId);
    notifyListeners();
  }

  Future<void> updateMovieEpisode(MovieEpisode e) async {
    if (_cloudMovieMode) {
      await _cloudMovie.updateChild('movie_episodes', e.id, e.toJson());
      notifyListeners();
      return;
    }
    await _movieEpisodeDao.updateEpisode(e);
    await _touchParentUpdatedAt('movies', e.movieId);
    notifyListeners();
  }

  Future<void> removeMovieEpisode(String id) async {
    if (_cloudMovieMode) {
      // 云端截图为网络 URL，无本地目录可删；服务端硬删并 bump 父行
      await _cloudMovie.deleteChild('movie_episodes', id);
      notifyListeners();
      return;
    }
    final e = await _movieEpisodeDao.getEpisodeById(id);
    await _movieEpisodeDao.deleteEpisode(id);
    if (e != null) {
      await ImagePathHelper.instance.deleteMovieEpisodeImages(e.movieId, e.id);
      await _touchParentUpdatedAt('movies', e.movieId);
    }
    notifyListeners();
  }

  // ========== 书籍章节相关方法 ==========

  Future<List<BookChapter>> getBookChapters(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.listChildren(
          'books', bookId, 'book_chapters', BookChapter.fromJson);
    }
    return await _bookChapterDao.getChaptersByBookId(bookId);
  }

  Future<List<BookChapter>> getAllBookChapters() async {
    if (_cloudBookMode) {
      return _cloudDomain.allChildren('book_chapters', BookChapter.fromJson);
    }
    return _bookChapterDao.getAllChapters();
  }

  Future<void> addBookChapter(BookChapter c) async {
    if (_cloudBookMode) {
      await _cloudDomain.createChild(
          'books', c.bookId, 'book_chapters', c.toJson());
      notifyListeners();
      return;
    }
    await _bookChapterDao.insertChapter(c);
    await _touchParentUpdatedAt('books', c.bookId);
    notifyListeners();
  }

  /// 批量新增章节（批量生成用）：单事务写入，只触碰父行一次、通知一次
  Future<void> addBookChaptersBatch(List<BookChapter> list) async {
    if (list.isEmpty) return;
    if (_cloudBookMode) {
      for (final c in list) {
        await _cloudDomain.createChild(
            'books', c.bookId, 'book_chapters', c.toJson());
      }
      notifyListeners();
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final c in list) {
        await txn.insert('book_chapters', c.toJson());
      }
    });
    await _touchParentUpdatedAt('books', list.first.bookId);
    notifyListeners();
  }

  Future<void> updateBookChapter(BookChapter c) async {
    if (_cloudBookMode) {
      await _cloudDomain.updateChild('book_chapters', c.id, c.toJson());
      notifyListeners();
      return;
    }
    await _bookChapterDao.updateChapter(c);
    await _touchParentUpdatedAt('books', c.bookId);
    notifyListeners();
  }

  Future<void> removeBookChapter(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.deleteChild('book_chapters', id);
      notifyListeners();
      return;
    }
    final c = await _bookChapterDao.getChapterById(id);
    await _bookChapterDao.deleteChapter(id);
    if (c != null) {
      await ImagePathHelper.instance.deleteBookChapterImages(c.bookId, c.id);
      await _touchParentUpdatedAt('books', c.bookId);
    }
    notifyListeners();
  }

  // ========== 游戏关卡相关方法 ==========

  Future<List<GameLevel>> getGameLevels(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.listChildren(
          'games', gameId, 'game_levels', GameLevel.fromJson);
    }
    return await _gameLevelDao.getLevelsByGameId(gameId);
  }

  Future<List<GameLevel>> getAllGameLevels() async {
    if (_cloudGameMode) {
      return _cloudDomain.allChildren('game_levels', GameLevel.fromJson);
    }
    return _gameLevelDao.getAllLevels();
  }

  Future<void> addGameLevel(GameLevel l) async {
    if (_cloudGameMode) {
      await _cloudDomain.createChild(
          'games', l.gameId, 'game_levels', l.toJson());
      notifyListeners();
      return;
    }
    await _gameLevelDao.insertLevel(l);
    await _touchParentUpdatedAt('games', l.gameId);
    notifyListeners();
  }

  /// 批量新增关卡（批量生成用）：单事务写入，只触碰父行一次、通知一次
  Future<void> addGameLevelsBatch(List<GameLevel> list) async {
    if (list.isEmpty) return;
    if (_cloudGameMode) {
      for (final l in list) {
        await _cloudDomain.createChild(
            'games', l.gameId, 'game_levels', l.toJson());
      }
      notifyListeners();
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final l in list) {
        await txn.insert('game_levels', l.toJson());
      }
    });
    await _touchParentUpdatedAt('games', list.first.gameId);
    notifyListeners();
  }

  Future<void> updateGameLevel(GameLevel l) async {
    if (_cloudGameMode) {
      await _cloudDomain.updateChild('game_levels', l.id, l.toJson());
      notifyListeners();
      return;
    }
    await _gameLevelDao.updateLevel(l);
    await _touchParentUpdatedAt('games', l.gameId);
    notifyListeners();
  }

  Future<void> removeGameLevel(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.deleteChild('game_levels', id);
      notifyListeners();
      return;
    }
    final l = await _gameLevelDao.getLevelById(id);
    await _gameLevelDao.deleteLevel(id);
    if (l != null) {
      await ImagePathHelper.instance.deleteGameLevelImages(l.gameId, l.id);
      await _touchParentUpdatedAt('games', l.gameId);
    }
    notifyListeners();
  }

  // ========== 书评相关方法 ==========

  /// 获取书籍的所有书评
  Future<List<BookReview>> getBookReviews(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.listChildren(
          'books', bookId, 'book_reviews', BookReview.fromJson);
    }
    return await _bookReviewDao.getReviewsByBookId(bookId);
  }

  /// 添加书评
  Future<void> addBookReview(BookReview review) async {
    if (_cloudBookMode) {
      await _cloudDomain.createChild(
          'books', review.bookId, 'book_reviews', review.toJson());
      debugPrint('[云端] 新增书评: ${_logSnippet(review.content)}');
      notifyListeners();
      return;
    }
    await _bookReviewDao.insertReview(review);
    debugPrint(
        '[数据] 新增书评《${_titleById(_books, review.bookId, (b) => b.id, (b) => b.title)}》: ${_logSnippet(review.content)}');
    notifyListeners();
  }

  /// 更新书评
  Future<void> updateBookReview(BookReview review) async {
    if (_cloudBookMode) {
      await _cloudDomain.updateChild(
          'book_reviews', review.id, review.toJson());
      debugPrint('[云端] 更新书评: ${_logSnippet(review.content)}');
      notifyListeners();
      return;
    }
    await _bookReviewDao.updateReview(review);
    debugPrint(
        '[数据] 更新书评《${_titleById(_books, review.bookId, (b) => b.id, (b) => b.title)}》: ${_logSnippet(review.content)}');
    notifyListeners();
  }

  /// 删除书评
  Future<void> removeBookReview(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.deleteChild('book_reviews', id);
      debugPrint('[云端] 删除书评');
      notifyListeners();
      return;
    }
    final review = await _bookReviewDao.getReviewById(id);
    await _bookReviewDao.deleteReview(id);
    final parent = review != null
        ? _titleById(_books, review.bookId, (b) => b.id, (b) => b.title)
        : '?';
    debugPrint('[数据] 删除书评《$parent》');
    notifyListeners();
  }

  /// 获取书籍的书评数量
  Future<int> getBookReviewCount(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.countChildren('books', bookId, 'book_reviews');
    }
    return await _bookReviewDao.getReviewCount(bookId);
  }

  // ========== 摘抄相关方法 ==========

  /// 获取书籍的所有摘抄
  Future<List<BookExcerpt>> getBookExcerpts(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.listChildren(
          'books', bookId, 'book_excerpts', BookExcerpt.fromJson);
    }
    return await _bookExcerptDao.getExcerptsByBookId(bookId);
  }

  /// 添加摘抄
  Future<void> addBookExcerpt(BookExcerpt excerpt) async {
    if (_cloudBookMode) {
      await _cloudDomain.createChild(
          'books', excerpt.bookId, 'book_excerpts', excerpt.toJson());
      debugPrint('[云端] 新增摘抄: ${_logSnippet(excerpt.content)}');
      notifyListeners();
      return;
    }
    await _bookExcerptDao.insertExcerpt(excerpt);
    debugPrint(
        '[数据] 新增摘抄《${_titleById(_books, excerpt.bookId, (b) => b.id, (b) => b.title)}》: ${_logSnippet(excerpt.content)}');
    notifyListeners();
  }

  /// 批量添加摘抄（导入用：单事务写入 + 只通知一次）
  Future<void> addBookExcerpts(List<BookExcerpt> excerpts) async {
    if (excerpts.isEmpty) return;
    if (_cloudBookMode) {
      for (final e in excerpts) {
        await _cloudDomain.createChild(
            'books', e.bookId, 'book_excerpts', e.toJson());
      }
      debugPrint('[云端] 批量新增摘抄 ×${excerpts.length}');
      notifyListeners();
      return;
    }
    await _bookExcerptDao.insertExcerpts(excerpts);
    debugPrint(
        '[数据] 批量新增摘抄《${_titleById(_books, excerpts.first.bookId, (b) => b.id, (b) => b.title)}》×${excerpts.length}');
    notifyListeners();
  }

  /// 更新摘抄
  Future<void> updateBookExcerpt(BookExcerpt excerpt) async {
    if (_cloudBookMode) {
      await _cloudDomain.updateChild(
          'book_excerpts', excerpt.id, excerpt.toJson());
      debugPrint('[云端] 更新摘抄: ${_logSnippet(excerpt.content)}');
      notifyListeners();
      return;
    }
    await _bookExcerptDao.updateExcerpt(excerpt);
    debugPrint(
        '[数据] 更新摘抄《${_titleById(_books, excerpt.bookId, (b) => b.id, (b) => b.title)}》: ${_logSnippet(excerpt.content)}');
    notifyListeners();
  }

  /// 删除摘抄
  Future<void> removeBookExcerpt(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.deleteChild('book_excerpts', id);
      debugPrint('[云端] 删除摘抄');
      notifyListeners();
      return;
    }
    final excerpt = await _bookExcerptDao.getExcerptById(id);
    await _bookExcerptDao.deleteExcerpt(id);
    final parent = excerpt != null
        ? _titleById(_books, excerpt.bookId, (b) => b.id, (b) => b.title)
        : '?';
    debugPrint('[数据] 删除摘抄《$parent》');
    notifyListeners();
  }

  /// 获取书籍的摘抄数量
  Future<int> getBookExcerptCount(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.countChildren('books', bookId, 'book_excerpts');
    }
    return await _bookExcerptDao.getExcerptCount(bookId);
  }

  // ========== 回收站相关方法 ==========

  /// 获取已删除的影视
  Future<List<Movie>> getDeletedMovies() async {
    if (_cloudMovieMode) {
      return _cloudMovie.deletedMovies();
    }
    return await _movieDao.getDeletedMovies();
  }

  /// 恢复影视
  Future<void> restoreMovie(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.restoreMovie(id);
      await loadMovies();
      return;
    }
    await _movieDao.restoreMovie(id);
    await loadMovies();
  }

  /// 彻底删除影视
  Future<void> permanentDeleteMovie(String id) async {
    if (_cloudMovieMode) {
      // 服务端级联清理子表；云端图片为网络 URL，无本地文件
      await _cloudMovie.permanentDeleteMovie(id);
      _invalidateCloudMainCounts('movies');
      return;
    }
    final db = await DatabaseHelper.instance.database;
    // 墓碑与 DB 删除同事务原子提交（DAO 内层事务复用当前事务），避免半途失败误删他端数据
    await db.transaction((txn) async {
      await SyncTombstones.record('movies', id, txn);
      // 分集等全部子表在 DAO 事务内与父行同删，避免中途失败产生孤儿
      await _movieDao.permanentDeleteMovie(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteMovieImages(id);
  }

  /// 获取已删除的书籍
  Future<List<Book>> getDeletedBooks() async {
    if (_cloudBookMode) {
      return _cloudDomain.deletedMain('books', Book.fromJson);
    }
    return await _bookDao.getDeletedBooks();
  }

  /// 恢复书籍
  Future<void> restoreBook(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.restoreMain('books', id);
      await loadBooks();
      return;
    }
    await _bookDao.restoreBook(id);
    await loadBooks();
  }

  /// 彻底删除书籍
  Future<void> permanentDeleteBook(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.permanentDeleteMain('books', id);
      _invalidateCloudMainCounts('books');
      return;
    }
    final db = await DatabaseHelper.instance.database;
    // 墓碑与 DB 删除同事务原子提交（DAO 内层事务复用当前事务）
    await db.transaction((txn) async {
      await SyncTombstones.record('books', id, txn);
      // 章节等全部子表在 DAO 事务内与父行同删，避免中途失败产生孤儿
      await _bookDao.permanentDeleteBook(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteBookImages(id);
  }

  /// 获取已删除的笔记
  Future<List<Note>> getDeletedNotes() async {
    if (_cloudNoteMode) {
      return _cloudDomain.deletedEntities('notes', Note.fromJson);
    }
    return await _noteDao.getDeletedNotes();
  }

  /// 恢复笔记
  Future<void> restoreNote(String id) async {
    if (_cloudNoteMode) {
      await _cloudDomain.restoreEntity('notes', id);
      await loadNotes();
      return;
    }
    await _noteDao.restoreNote(id);
    await loadNotes();
  }

  /// 彻底删除笔记
  Future<void> permanentDeleteNote(String id) async {
    if (_cloudNoteMode) {
      await _cloudDomain.permanentDeleteEntity('notes', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('notes', id, txn);
      await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
    });
    await ImagePathHelper.instance.deleteNoteImages(id);
  }

  /// 获取已删除的游戏
  Future<List<Game>> getDeletedGames() async {
    if (_cloudGameMode) {
      return _cloudDomain.deletedMain('games', Game.fromJson);
    }
    return await _gameDao.getDeletedGames();
  }

  /// 恢复游戏
  Future<void> restoreGame(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.restoreMain('games', id);
      await loadGames();
      return;
    }
    await _gameDao.restoreGame(id);
    await loadGames();
  }

  /// 彻底删除游戏
  Future<void> permanentDeleteGame(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.permanentDeleteMain('games', id);
      _invalidateCloudMainCounts('games');
      return;
    }
    final db = await DatabaseHelper.instance.database;
    // 墓碑与 DB 删除同事务原子提交（DAO 内层事务复用当前事务）
    await db.transaction((txn) async {
      await SyncTombstones.record('games', id, txn);
      // 关卡/通关记录等全部子表在 DAO 事务内与父行同删，避免中途失败产生孤儿
      await _gameDao.permanentDeleteGame(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteGameImages(id);
  }

  bool _isClearingRecycleBin = false;

  /// 清空回收站进行中：回收站页面据此禁用单条恢复/删除，避免与清空操作交叉
  bool get isClearingRecycleBin => _isClearingRecycleBin;

  /// 云模式回收站清空：各云域的已删条目逐条调永久删除接口（本地 SQLite 不参与）
  Future<void> _clearCloudRecycleBin() async {
    if (_cloudMovieMode) {
      for (final m in await _cloudMovie.deletedMovies()) {
        await _cloudMovie.permanentDeleteMovie(m.id);
      }
      for (final r in await _cloudMovie.deletedChildren(
          'movie_reviews', MovieReview.fromJson)) {
        await _cloudMovie.permanentDeleteChild('movie_reviews', r.id);
      }
      for (final c in await _cloudMovie.deletedChildren(
          'movie_characters', MovieCharacter.fromJson)) {
        await _cloudMovie.permanentDeleteChild('movie_characters', c.id);
      }
      for (final p
          in await _cloudMovie.deletedEntities('people', Person.fromJson)) {
        await _cloudMovie.permanentDeleteEntity('people', p.id);
      }
    }
    if (_cloudBookMode) {
      for (final b in await _cloudDomain.deletedMain('books', Book.fromJson)) {
        await _cloudDomain.permanentDeleteMain('books', b.id);
      }
      for (final r in await _cloudDomain.deletedChildren(
          'book_reviews', BookReview.fromJson)) {
        await _cloudDomain.permanentDeleteChild('book_reviews', r.id);
      }
      for (final e in await _cloudDomain.deletedChildren(
          'book_excerpts', BookExcerpt.fromJson)) {
        await _cloudDomain.permanentDeleteChild('book_excerpts', e.id);
      }
      for (final c in await _cloudDomain.deletedChildren(
          'book_characters', BookCharacter.fromJson)) {
        await _cloudDomain.permanentDeleteChild('book_characters', c.id);
      }
    }
    if (_cloudGameMode) {
      for (final g in await _cloudDomain.deletedMain('games', Game.fromJson)) {
        await _cloudDomain.permanentDeleteMain('games', g.id);
      }
      for (final r in await _cloudDomain.deletedChildren(
          'game_reviews', GameReview.fromJson)) {
        await _cloudDomain.permanentDeleteChild('game_reviews', r.id);
      }
      for (final c in await _cloudDomain.deletedChildren(
          'game_characters', GameCharacter.fromJson)) {
        await _cloudDomain.permanentDeleteChild('game_characters', c.id);
      }
    }
    if (_cloudNoteMode) {
      for (final n
          in await _cloudDomain.deletedEntities('notes', Note.fromJson)) {
        await _cloudDomain.permanentDeleteEntity('notes', n.id);
      }
    }
    if (_cloudPlaylistMode) {
      for (final p in await _cloudDomain.deletedEntities(
          'playlists', Playlist.fromJson)) {
        await permanentDeletePlaylist(p.id);
      }
    }
    if (UserPrefs().cloudAnyMediaMode) {
      for (final item in await _cloudDomain.deletedEntities(
          'custom_module_items', CustomModuleItem.fromJson)) {
        await _cloudDomain.permanentDeleteEntity(
            'custom_module_items', item.id);
      }
    }
  }

  /// 清空回收站
  Future<void> clearRecycleBin() async {
    if (_isClearingRecycleBin) return;
    _isClearingRecycleBin = true;
    notifyListeners();
    try {
      // 先清云端：云域的 getDeleted* 走的是云端列表，永久删除后下方本地流程拿到的列表自然为空
      await _clearCloudRecycleBin();
      final deletedMovies = await getDeletedMovies();
      final deletedBooks = await getDeletedBooks();
      final deletedNotes = await getDeletedNotes();
      final deletedGames = await getDeletedGames();
      final deletedMovieReviews = await getDeletedMovieReviews();
      final deletedBookReviews = await getDeletedBookReviews();
      final deletedBookExcerpts = await getDeletedBookExcerpts();
      final deletedGameReviews = await getDeletedGameReviews();
      final deletedPeople = await getDeletedPeople();
      final deletedMovieCharacters = await getDeletedMovieCharacters();
      final deletedBookCharacters = await getDeletedBookCharacters();
      final deletedGameCharacters = await getDeletedGameCharacters();
      final deletedCustomModuleItems = await getDeletedCustomModuleItems();
      final deletedPlaylists = await getDeletedPlaylists();

      // 先收集需要删除图片的 ID，再在事务中批量删除数据库记录
      final movieIds = deletedMovies.map((m) => m.id).toList();
      final bookIds = deletedBooks.map((b) => b.id).toList();
      final noteIds = deletedNotes.map((n) => n.id).toList();
      final gameIds = deletedGames.map((g) => g.id).toList();
      final personIds = deletedPeople.map((p) => p.id).toList();
      final movieCharacterIds =
          deletedMovieCharacters.map((c) => c.id).toList();
      final bookCharacterIds = deletedBookCharacters.map((c) => c.id).toList();
      final gameCharacterIds = deletedGameCharacters.map((c) => c.id).toList();

      // 事务内批量删除数据库记录，保证原子性
      final db = await DatabaseHelper.instance.database;

      // 收集将被级联删除的评价ID（评价图片在 reviews/{reviewId} 目录，需单独清理）
      final movieReviewIds = <String>{...deletedMovieReviews.map((r) => r.id)};
      final bookReviewIds = <String>{...deletedBookReviews.map((r) => r.id)};
      final gameReviewIds = <String>{...deletedGameReviews.map((r) => r.id)};
      for (final id in movieIds) {
        final rows = await db.query('movie_reviews',
            columns: ['id'], where: 'movie_id = ?', whereArgs: [id]);
        movieReviewIds.addAll(rows.map((r) => r['id'] as String));
      }
      for (final id in bookIds) {
        final rows = await db.query('book_reviews',
            columns: ['id'], where: 'book_id = ?', whereArgs: [id]);
        bookReviewIds.addAll(rows.map((r) => r['id'] as String));
      }
      for (final id in gameIds) {
        final rows = await db.query('game_reviews',
            columns: ['id'], where: 'game_id = ?', whereArgs: [id]);
        gameReviewIds.addAll(rows.map((r) => r['id'] as String));
      }
      final reviewIds = <String>{
        ...movieReviewIds,
        ...bookReviewIds,
        ...gameReviewIds
      };

      // 收集将被级联删除的摘抄ID（随书籍硬删一并清除，需记录墓碑）
      final excerptIds = <String>{...deletedBookExcerpts.map((e) => e.id)};
      for (final id in bookIds) {
        final rows = await db.query('book_excerpts',
            columns: ['id'], where: 'book_id = ?', whereArgs: [id]);
        excerptIds.addAll(rows.map((r) => r['id'] as String));
      }

      await db.transaction((txn) async {
        // 墓碑与删除在同一事务内原子提交：事务失败则墓碑一并回滚，
        // 不会出现本地数据还在、他端却收到删除的情况（组表随父实体墓碑覆盖，无需单独记录）
        for (final id in movieIds) {
          await SyncTombstones.record('movies', id, txn);
        }
        for (final id in bookIds) {
          await SyncTombstones.record('books', id, txn);
        }
        for (final id in noteIds) {
          await SyncTombstones.record('notes', id, txn);
        }
        for (final id in gameIds) {
          await SyncTombstones.record('games', id, txn);
        }
        for (final id in movieReviewIds) {
          await SyncTombstones.record('movie_reviews', id, txn);
        }
        for (final id in bookReviewIds) {
          await SyncTombstones.record('book_reviews', id, txn);
        }
        for (final id in gameReviewIds) {
          await SyncTombstones.record('game_reviews', id, txn);
        }
        for (final id in excerptIds) {
          await SyncTombstones.record('book_excerpts', id, txn);
        }
        for (final id in personIds) {
          await SyncTombstones.record('people', id, txn);
        }
        for (final id in movieCharacterIds) {
          await SyncTombstones.record('movie_characters', id, txn);
        }
        for (final id in bookCharacterIds) {
          await SyncTombstones.record('book_characters', id, txn);
        }
        for (final id in gameCharacterIds) {
          await SyncTombstones.record('game_characters', id, txn);
        }
        for (final item in deletedCustomModuleItems) {
          await SyncTombstones.record('custom_module_items', item.id, txn);
        }
        for (final playlist in deletedPlaylists) {
          await SyncTombstones.record('playlists', playlist.id, txn);
        }

        for (final id in movieIds) {
          await txn
              .delete('movie_reviews', where: 'movie_id = ?', whereArgs: [id]);
          await txn
              .delete('movie_posters', where: 'movie_id = ?', whereArgs: [id]);
          await txn
              .delete('movie_episodes', where: 'movie_id = ?', whereArgs: [id]);
          await txn
              .delete('movie_people', where: 'movie_id = ?', whereArgs: [id]);
          await txn.delete('movie_characters',
              where: 'movie_id = ?', whereArgs: [id]);
          await PlaylistDao.removeMediaFromPlaylists(txn, id, 'movie');
          await txn.delete('movies', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in bookIds) {
          await txn
              .delete('book_reviews', where: 'book_id = ?', whereArgs: [id]);
          await txn
              .delete('book_excerpts', where: 'book_id = ?', whereArgs: [id]);
          await txn
              .delete('book_chapters', where: 'book_id = ?', whereArgs: [id]);
          await txn
              .delete('book_people', where: 'book_id = ?', whereArgs: [id]);
          await txn
              .delete('book_characters', where: 'book_id = ?', whereArgs: [id]);
          await PlaylistDao.removeMediaFromPlaylists(txn, id, 'book');
          await txn.delete('books', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in noteIds) {
          await txn.delete('notes', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in gameIds) {
          await txn
              .delete('game_reviews', where: 'game_id = ?', whereArgs: [id]);
          await txn.delete('game_screenshots',
              where: 'game_id = ?', whereArgs: [id]);
          await txn.delete('game_completions',
              where: 'game_id = ?', whereArgs: [id]);
          await txn
              .delete('game_levels', where: 'game_id = ?', whereArgs: [id]);
          await txn
              .delete('game_people', where: 'game_id = ?', whereArgs: [id]);
          await txn
              .delete('game_characters', where: 'game_id = ?', whereArgs: [id]);
          await PlaylistDao.removeMediaFromPlaylists(txn, id, 'game');
          await txn.delete('games', where: 'id = ?', whereArgs: [id]);
        }
        for (final review in deletedMovieReviews) {
          await txn
              .delete('movie_reviews', where: 'id = ?', whereArgs: [review.id]);
        }
        for (final review in deletedBookReviews) {
          await txn
              .delete('book_reviews', where: 'id = ?', whereArgs: [review.id]);
        }
        for (final excerpt in deletedBookExcerpts) {
          await txn.delete('book_excerpts',
              where: 'id = ?', whereArgs: [excerpt.id]);
        }
        for (final review in deletedGameReviews) {
          await txn
              .delete('game_reviews', where: 'id = ?', whereArgs: [review.id]);
        }
        for (final id in personIds) {
          await txn
              .delete('movie_people', where: 'person_id = ?', whereArgs: [id]);
          await txn
              .delete('book_people', where: 'person_id = ?', whereArgs: [id]);
          await txn
              .delete('game_people', where: 'person_id = ?', whereArgs: [id]);
          await txn.delete('people', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in movieCharacterIds) {
          await txn
              .delete('movie_characters', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in bookCharacterIds) {
          await txn.delete('book_characters', where: 'id = ?', whereArgs: [id]);
        }
        for (final id in gameCharacterIds) {
          await txn.delete('game_characters', where: 'id = ?', whereArgs: [id]);
        }
        for (final item in deletedCustomModuleItems) {
          await txn.delete('custom_module_items',
              where: 'id = ?', whereArgs: [item.id]);
        }
        for (final playlist in deletedPlaylists) {
          await _playlistDao.permanentDeletePlaylist(playlist.id, txn: txn);
        }
      });

      // 事务成功后，清理关联的图片文件（文件删除失败不影响数据一致性）
      for (final id in movieIds) {
        await ImagePathHelper.instance.deleteMovieImages(id);
      }
      for (final id in bookIds) {
        await ImagePathHelper.instance.deleteBookImages(id);
      }
      for (final id in noteIds) {
        await ImagePathHelper.instance.deleteNoteImages(id);
      }
      for (final id in gameIds) {
        await ImagePathHelper.instance.deleteGameImages(id);
      }
      for (final id in personIds) {
        await ImagePathHelper.instance.deletePersonImages(id);
      }
      for (final id in movieCharacterIds) {
        await ImagePathHelper.instance.deleteCharacterImages(id);
      }
      for (final id in bookCharacterIds) {
        await ImagePathHelper.instance.deleteCharacterImages(id);
      }
      for (final id in gameCharacterIds) {
        await ImagePathHelper.instance.deleteCharacterImages(id);
      }
      for (final id in reviewIds) {
        await ImagePathHelper.instance.deleteReviewImages(id);
      }
      for (final item in deletedCustomModuleItems) {
        await ImagePathHelper.instance
            .deleteCustomModuleItemImages(item.moduleId, item.id);
      }

      await loadMovies();
      await loadBooks();
      await loadNotes();
      await loadGames();
      await loadPlaylists();
      await loadPeople();
      bumpCustomModuleItemsVersion();
    } finally {
      _isClearingRecycleBin = false;
      notifyListeners();
    }
  }

  // ========== 影评书评回收站 ==========

  Future<List<MovieReview>> getDeletedMovieReviews() async {
    if (_cloudMovieMode) {
      return _cloudMovie.deletedChildren('movie_reviews', MovieReview.fromJson);
    }
    return await _reviewDao.getDeletedReviews();
  }

  Future<void> restoreMovieReview(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.restoreChild('movie_reviews', id);
      return;
    }
    await _reviewDao.restoreReview(id);
  }

  Future<void> permanentDeleteMovieReview(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.permanentDeleteChild('movie_reviews', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('movie_reviews', id, txn);
      await _reviewDao.permanentDeleteReview(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteReviewImages(id);
  }

  Future<List<BookReview>> getDeletedBookReviews() async {
    if (_cloudBookMode) {
      return _cloudDomain.deletedChildren('book_reviews', BookReview.fromJson);
    }
    return await _bookReviewDao.getDeletedReviews();
  }

  Future<void> restoreBookReview(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.restoreChild('book_reviews', id);
      return;
    }
    await _bookReviewDao.restoreReview(id);
  }

  Future<void> permanentDeleteBookReview(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.permanentDeleteChild('book_reviews', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('book_reviews', id, txn);
      await _bookReviewDao.permanentDeleteReview(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteReviewImages(id);
  }

  // ========== 游戏评价回收站 ==========

  Future<List<GameReview>> getDeletedGameReviews() async {
    if (_cloudGameMode) {
      return _cloudDomain.deletedChildren('game_reviews', GameReview.fromJson);
    }
    return await _gameReviewDao.getDeletedReviews();
  }

  Future<void> restoreGameReview(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.restoreChild('game_reviews', id);
      return;
    }
    await _gameReviewDao.restoreReview(id);
  }

  Future<void> permanentDeleteGameReview(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.permanentDeleteChild('game_reviews', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('game_reviews', id, txn);
      await _gameReviewDao.permanentDeleteReview(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteReviewImages(id);
  }

  // ========== 摘抄回收站方法 ==========

  Future<List<BookExcerpt>> getDeletedBookExcerpts() async {
    if (_cloudBookMode) {
      return _cloudDomain.deletedChildren(
          'book_excerpts', BookExcerpt.fromJson);
    }
    return await _bookExcerptDao.getDeletedExcerpts();
  }

  Future<void> restoreBookExcerpt(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.restoreChild('book_excerpts', id);
      return;
    }
    await _bookExcerptDao.restoreExcerpt(id);
  }

  Future<void> permanentDeleteBookExcerpt(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.permanentDeleteChild('book_excerpts', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('book_excerpts', id, txn);
      await _bookExcerptDao.permanentDeleteExcerpt(id, txn: txn);
    });
  }

  // ========== 标签管理方法 ==========

  /// 标签类型 → 对应媒体域的云模式开关（混合模式下各类型标签各走各的存储）
  bool _isCloudTagType(String type) => switch (type) {
        'movie_genre' => _cloudMovieMode,
        'book_genre' => _cloudBookMode,
        'note_tag' => _cloudNoteMode,
        'game_genre' => _cloudGameMode,
        _ => false,
      };

  Future<List<Map<String, dynamic>>> _cloudTagsByType(String type,
      {bool excludeHidden = false}) async {
    final all = await _cloudDomain.listEntities(
        'tags', (m) => Map<String, dynamic>.from(m));
    final rows = all.where((m) => m['type'] == type).toList();
    if (excludeHidden) {
      rows.removeWhere((m) => (m['is_hidden'] as num?)?.toInt() == 1);
    }
    rows.sort((a, b) {
      final sa = (a['sort_order'] as num?)?.toInt() ?? 0;
      final sb = (b['sort_order'] as num?)?.toInt() ?? 0;
      if (sa != sb) return sa.compareTo(sb);
      return (a['name']?.toString() ?? '')
          .compareTo(b['name']?.toString() ?? '');
    });
    return rows;
  }

  Map<String, dynamic>? _findTag(List<Map<String, dynamic>> tags,
      bool Function(Map<String, dynamic>) test) {
    for (final t in tags) {
      if (test(t)) return t;
    }
    return null;
  }

  Set<String> _cloudTagDescendantIds(
      List<Map<String, dynamic>> tags, String tagId) {
    final result = <String>{};
    final queue = <String>[tagId];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final t in tags) {
        if (t['parent_id'] == parent && result.add(t['id'] as String)) {
          queue.add(t['id'] as String);
        }
      }
    }
    return result;
  }

  List<String> _replaceDedupTags(
      List<String> list, String oldName, String newName) {
    final result = <String>[];
    for (final item in list) {
      final v = item == oldName ? newName : item;
      if (!result.contains(v)) result.add(v);
    }
    return result;
  }

  /// 云端级联：[newName] 非空=重命名替换，null=从条目上移除
  Future<void> _cloudCascadeTag(
      String type, String oldName, String? newName) async {
    switch (type) {
      case 'movie_genre':
        for (final w in await cloudAllMovies()) {
          if (!w.genres.contains(oldName)) continue;
          final genres = newName == null
              ? (List<String>.from(w.genres)..removeWhere((g) => g == oldName))
              : _replaceDedupTags(w.genres, oldName, newName);
          await _cloudMovie.updateMovie(w.copyWith(genres: genres));
        }
      case 'book_genre':
        for (final w in await cloudAllBooks()) {
          if (!w.genres.contains(oldName)) continue;
          final genres = newName == null
              ? (List<String>.from(w.genres)..removeWhere((g) => g == oldName))
              : _replaceDedupTags(w.genres, oldName, newName);
          await _cloudDomain.updateMain(
              'books', w.id, w.copyWith(genres: genres).toJson());
        }
      case 'game_genre':
        for (final w in await cloudAllGames()) {
          if (!w.genres.contains(oldName)) continue;
          final genres = newName == null
              ? (List<String>.from(w.genres)..removeWhere((g) => g == oldName))
              : _replaceDedupTags(w.genres, oldName, newName);
          await _cloudDomain.updateMain(
              'games', w.id, w.copyWith(genres: genres).toJson());
        }
      case 'note_tag':
        final notes = await _cloudDomain.listEntities('notes', Note.fromJson);
        for (final n in notes) {
          if (!n.tags.contains(oldName)) continue;
          final tags = newName == null
              ? (List<String>.from(n.tags)..removeWhere((t) => t == oldName))
              : _replaceDedupTags(n.tags, oldName, newName);
          await _cloudDomain.updateEntity(
              'notes', n.id, n.copyWith(tags: tags).toJson());
        }
    }
  }

  Future<List<Map<String, dynamic>>> getTags(String type,
      {bool excludeHidden = false}) async {
    if (_isCloudTagType(type)) {
      return _cloudTagsByType(type, excludeHidden: excludeHidden);
    }
    return await _tagDao.getTagsByType(type, excludeHidden: excludeHidden);
  }

  Future<void> toggleTagHidden(String tagId) async {
    if (_cloudMovieMode || _cloudBookMode || _cloudGameMode || _cloudNoteMode) {
      final remote = await _cloudDomain.getEntity('tags', tagId);
      if (remote != null) {
        final hidden = (remote['is_hidden'] as num?)?.toInt() == 1;
        await _cloudDomain
            .updateEntity('tags', tagId, {'is_hidden': hidden ? 0 : 1});
        debugPrint('[云端] 切换标签显隐「${remote['name'] ?? '?'}」');
        notifyListeners();
        return;
      }
    }
    final tag = await _tagDao.getTagById(tagId);
    await _tagDao.toggleHidden(tagId);
    debugPrint('[数据] 切换标签显隐「${tag?['name'] ?? '?'}」');
    notifyListeners();
  }

  Future<String> addTag(String name, String type,
      {String parentId = ''}) async {
    if (_isCloudTagType(type)) {
      final id = 'tag_${const Uuid().v4()}';
      await _cloudDomain.createEntity('tags', {
        'id': id,
        'name': name,
        'type': type,
        'parent_id': parentId,
        'is_hidden': 0,
        'sort_order': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('[云端] 新增标签「$name」($type)');
      await _reloadByTagType(type);
      return id;
    }
    final id = await _tagDao.addTag(name, type, parentId: parentId);
    debugPrint('[数据] 新增标签「$name」($type)');
    await _reloadByTagType(type);
    return id;
  }

  /// 设置标签的父级分类ID（空串表示顶级）
  Future<bool> setTagParent(String tagId, String type, String parentId) async {
    if (_isCloudTagType(type)) {
      final tags = await _cloudTagsByType(type);
      final tag = _findTag(tags, (t) => t['id'] == tagId);
      if (tag == null) return false;
      if (parentId.isNotEmpty) {
        if (parentId == tagId) return false;
        if (_findTag(tags, (t) => t['id'] == parentId) == null) return false;
        if (_cloudTagDescendantIds(tags, tagId).contains(parentId))
          return false;
      }
      await _cloudDomain.updateEntity('tags', tagId, {'parent_id': parentId});
      await _reloadByTagType(type);
      return true;
    }
    final result = await _tagDao.setTagParent(tagId, parentId);
    await _reloadByTagType(type);
    return result;
  }

  /// 重排同级标签顺序（[movedTagId] 跨父级时会顺带改 parent_id）
  /// 只动 tags 表，不影响影视/书籍等数据，无需 _reloadByTagType
  Future<bool> reorderTags(String type, String parentId,
      List<String> orderedIds, String movedTagId) async {
    if (_isCloudTagType(type)) {
      final tags = await _cloudTagsByType(type);
      if (parentId.isNotEmpty) {
        if (parentId == movedTagId) return false;
        if (_findTag(tags, (t) => t['id'] == parentId) == null) return false;
        if (_cloudTagDescendantIds(tags, movedTagId).contains(parentId))
          return false;
      }
      await _cloudDomain
          .updateEntity('tags', movedTagId, {'parent_id': parentId});
      for (var i = 0; i < orderedIds.length; i++) {
        await _cloudDomain
            .updateEntity('tags', orderedIds[i], {'sort_order': i});
      }
      return true;
    }
    return _tagDao.reorderSiblings(type, parentId, orderedIds, movedTagId);
  }

  Future<bool> renameTag(String tagId, String newName, String type) async {
    if (_isCloudTagType(type)) {
      final tags = await _cloudTagsByType(type);
      final tag = _findTag(tags, (t) => t['id'] == tagId);
      if (tag == null) return false;
      final oldName = tag['name'] as String;
      if (oldName == newName) return true;
      if (_findTag(tags, (t) => t['id'] != tagId && t['name'] == newName) !=
          null) {
        return false;
      }
      await _cloudDomain.updateEntity('tags', tagId, {'name': newName});
      await _cloudCascadeTag(type, oldName, newName);
      debugPrint('[云端] 重命名标签为「$newName」($type)');
      await _reloadByTagType(type);
      return true;
    }
    final result = await _tagDao.renameTag(tagId, newName);
    if (result) {
      debugPrint('[数据] 重命名标签为「$newName」($type)');
      await _reloadByTagType(type);
    }
    return result;
  }

  Future<void> deleteTag(String tagId, String type,
      {String? replacementName}) async {
    if (_isCloudTagType(type)) {
      final tags = await _cloudTagsByType(type);
      final tag = _findTag(tags, (t) => t['id'] == tagId);
      if (tag == null) return;
      final name = tag['name'] as String;
      if (replacementName != null && replacementName != name) {
        if (_findTag(tags, (t) => t['name'] == replacementName) == null) {
          await addTag(replacementName, type);
        }
        await _cloudCascadeTag(type, name, replacementName);
      } else if (replacementName == null) {
        await _cloudCascadeTag(type, name, null);
      }
      for (final t in tags.where((t) => t['parent_id'] == tagId)) {
        await _cloudDomain
            .updateEntity('tags', t['id'] as String, {'parent_id': ''});
      }
      await _cloudDomain.deleteEntity('tags', tagId);
      debugPrint('[云端] 删除标签「$name」($type)'
          '${replacementName != null ? '，替换为「$replacementName」' : ''}');
      await _reloadByTagType(type);
      return;
    }
    final tag = await _tagDao.getTagById(tagId);
    await _tagDao.deleteTag(tagId, replacementName: replacementName);
    debugPrint('[数据] 删除标签「${tag?['name'] ?? '?'}」($type)'
        '${replacementName != null ? '，替换为「$replacementName」' : ''}');
    await _reloadByTagType(type);
  }

  /// 仅删除标签本身，不级联影响已有条目
  Future<void> deleteTagOnly(String tagId, String type) async {
    if (_isCloudTagType(type)) {
      final tags = await _cloudTagsByType(type);
      final tag = _findTag(tags, (t) => t['id'] == tagId);
      if (tag == null) return;
      for (final t in tags.where((t) => t['parent_id'] == tagId)) {
        await _cloudDomain
            .updateEntity('tags', t['id'] as String, {'parent_id': ''});
      }
      await _cloudDomain.deleteEntity('tags', tagId);
      debugPrint('[云端] 移除标签「${tag['name']}」($type，不级联)');
      await _reloadByTagType(type);
      return;
    }
    final tag = await _tagDao.getTagById(tagId);
    await _tagDao.deleteTagOnly(tagId);
    debugPrint('[数据] 移除标签「${tag?['name'] ?? '?'}」($type，不级联)');
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

    // 云端类型：从云端条目解析，缺失的标签写入云端字典
    Future<void> syncCloudType(String type, List<String> names) async {
      final existing =
          (await _cloudTagsByType(type)).map((t) => t['name']).toSet();
      for (final name in names) {
        if (existing.add(name)) {
          await addTag(name, type);
          added++;
        }
      }
    }

    if (_cloudMovieMode) {
      final names = <String>[
        for (final m in await cloudAllMovies()) ...m.genres
      ];
      await syncCloudType('movie_genre', names);
    } else {
      // 影视类型
      final movies = await db.query('movies',
          where: 'genres IS NOT NULL AND genres != ? AND is_deleted = 0',
          whereArgs: ['[]']);
      for (final row in movies) {
        for (final genre in parseStringListGeneric(row['genres'])) {
          await insertTag(genre, 'movie_genre');
        }
      }
    }

    if (_cloudBookMode) {
      final names = <String>[
        for (final b in await cloudAllBooks()) ...b.genres
      ];
      await syncCloudType('book_genre', names);
    } else {
      // 书籍类型
      final books = await db.query('books',
          where: 'genres IS NOT NULL AND genres != ? AND is_deleted = 0',
          whereArgs: ['[]']);
      for (final row in books) {
        for (final genre in parseStringListGeneric(row['genres'])) {
          await insertTag(genre, 'book_genre');
        }
      }
    }

    if (_cloudNoteMode) {
      final notes = await _cloudDomain.listEntities('notes', Note.fromJson);
      final names = <String>[for (final n in notes) ...n.tags];
      await syncCloudType('note_tag', names);
    } else {
      // 笔记标签
      final notes = await db.query('notes',
          where:
              'tags IS NOT NULL AND tags != ? AND tags != ? AND is_deleted = 0',
          whereArgs: ['[]', '']);
      for (final row in notes) {
        for (final tag in parseStringListGeneric(row['tags'])) {
          await insertTag(tag, 'note_tag');
        }
      }
    }

    if (_cloudGameMode) {
      final names = <String>[
        for (final g in await cloudAllGames()) ...g.genres
      ];
      await syncCloudType('game_genre', names);
    } else {
      // 游戏类型
      final games = await db.query('games',
          where: 'genres IS NOT NULL AND genres != ? AND is_deleted = 0',
          whereArgs: ['[]']);
      for (final row in games) {
        for (final genre in parseStringListGeneric(row['genres'])) {
          await insertTag(genre, 'game_genre');
        }
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

  // ========== 人物管理 ==========

  /// 添加人物
  Future<void> addPerson(Person person) async {
    if (_cloudMovieMode) {
      await _cloudMovie.createEntity('people', person.toJson());
      debugPrint('[数据] 云端新增人物《${_logTitle(person.name)}》');
      await loadPeople();
      return;
    }
    await _personDao.insertPerson(person);
    debugPrint('[数据] 新增人物《${_logTitle(person.name)}》');
    await loadPeople();
  }

  /// 更新人物
  Future<void> updatePerson(Person person) async {
    if (_cloudMovieMode) {
      await _cloudMovie.updateEntity('people', person.id, person.toJson());
      debugPrint('[数据] 云端更新人物《${_logTitle(person.name)}》');
      await loadPeople();
      return;
    }
    await _personDao.updatePerson(person);
    debugPrint('[数据] 更新人物《${_logTitle(person.name)}》');
    await loadPeople();
  }

  /// 更新人物封面偏移量
  Future<void> updatePersonCoverOffset(String personId, double offset) async {
    if (_cloudMovieMode) {
      await _cloudMovie
          .updateEntity('people', personId, {'cover_offset': offset});
      return;
    }
    await _personDao.updateCoverOffset(personId, offset);
  }

  /// 软删除人物
  Future<void> removePerson(String id) async {
    final idx = _people.indexWhere((p) => p.id == id);
    final name = idx != -1 ? _people[idx].name : '';
    if (_cloudMovieMode) {
      await _cloudMovie.deleteEntity('people', id);
      debugPrint('[数据] 云端删除人物《${_logTitle(name)}》');
      await loadPeople();
      return;
    }
    await _personDao.deletePerson(id);
    debugPrint('[数据] 删除人物《${_logTitle(name)}》');
    await loadPeople();
  }

  /// 恢复已删除的人物
  Future<void> restorePerson(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.restoreEntity('people', id);
      await loadPeople();
      return;
    }
    await _personDao.restorePerson(id);
    await loadPeople();
  }

  /// 彻底删除人物
  Future<void> permanentDeletePerson(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.permanentDeleteEntity('people', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('people', id, txn);
      await _personDao.permanentDeletePerson(id, txn: txn);
    });
    await ImagePathHelper.instance.deletePersonImages(id);
  }

  /// 获取已删除的人物
  Future<List<Person>> getDeletedPeople() async {
    if (_cloudMovieMode) {
      return _cloudMovie.deletedEntities('people', Person.fromJson);
    }
    return await _personDao.getDeletedPeople();
  }

  /// 搜索人物
  Future<List<Person>> searchPeople(String keyword) async {
    if (_cloudMovieMode) {
      final kw = keyword.toLowerCase();
      return _people
          .where((p) =>
              p.name.toLowerCase().contains(kw) ||
              p.alternateNames.any((n) => n.toLowerCase().contains(kw)))
          .toList();
    }
    return await _personDao.searchPeople(keyword);
  }

  /// 根据ID获取人物
  Future<Person?> getPersonById(String id) async {
    if (_cloudMovieMode) {
      return _people.where((p) => p.id == id).firstOrNull;
    }
    return await _personDao.getPersonById(id);
  }

  // ========== 人物关联查询 ==========

  /// 获取某部影视的关联人物
  Future<List<MoviePerson>> getMoviePeople(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.listChildren(
          movieId, 'movie_people', MoviePerson.fromJson);
    }
    return await _moviePersonDao.getByMovieId(movieId);
  }

  /// 获取某个人物参与的影视
  Future<List<MoviePerson>> getPersonMovies(String personId) async {
    if (_cloudMovieMode) {
      final works = await _cloudMovie.personMovieWorks(personId);
      return works.expand((w) => w.relations).toList();
    }
    return await _moviePersonDao.getByPersonId(personId);
  }

  /// 云模式人物详情：该人物参与的影视主行（内存首页分片不完整，不能用 provider.movies 反查）
  Future<List<Movie>> cloudPersonMovies(String personId) async {
    final works = await _cloudMovie.personMovieWorks(personId);
    return works.map((w) => w.movie).toList();
  }

  /// 获取某本书的关联人物
  Future<List<BookPerson>> getBookPeople(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.listChildren(
          'books', bookId, 'book_people', BookPerson.fromJson);
    }
    return await _bookPersonDao.getByBookId(bookId);
  }

  /// 获取某个人物参与的书籍
  Future<List<BookPerson>> getPersonBooks(String personId) async {
    if (_cloudBookMode) {
      final works = await _cloudDomain.personWorks('books', personId);
      return works.expand((w) => w.relations).map(BookPerson.fromJson).toList();
    }
    return await _bookPersonDao.getByPersonId(personId);
  }

  /// 云模式人物详情：该人物参与的书籍主行（内存首页分片不完整，不能用 provider.books 反查）
  Future<List<Book>> cloudPersonBooks(String personId) async {
    final works = await _cloudDomain.personWorks('books', personId);
    return works.map((w) => Book.fromJson(w.work)).toList();
  }

  /// 获取某游戏的关联人物
  Future<List<GamePerson>> getGamePeople(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.listChildren(
          'games', gameId, 'game_people', GamePerson.fromJson);
    }
    return await _gamePersonDao.getByGameId(gameId);
  }

  /// 获取某个人物参与的游戏
  Future<List<GamePerson>> getPersonGames(String personId) async {
    if (_cloudGameMode) {
      final works = await _cloudDomain.personWorks('games', personId);
      return works.expand((w) => w.relations).map(GamePerson.fromJson).toList();
    }
    return await _gamePersonDao.getByPersonId(personId);
  }

  /// 云模式人物详情：该人物参与的游戏主行
  Future<List<Game>> cloudPersonGames(String personId) async {
    final works = await _cloudDomain.personWorks('games', personId);
    return works.map((w) => Game.fromJson(w.work)).toList();
  }

  /// 保存影视的人物关联（事务内先删后插）
  Future<void> saveMoviePeople(String movieId, List<MoviePerson> people) async {
    if (_cloudMovieMode) {
      await _cloudMovie.replaceMoviePeople(movieId, people);
      return;
    }
    await _moviePersonDao.replaceForMovie(movieId, people);
  }

  /// 保存书籍的人物关联
  Future<void> saveBookPeople(String bookId, List<BookPerson> people) async {
    if (_cloudBookMode) {
      await _cloudDomain.replacePeople(
          'books', bookId, people.map((p) => p.toJson()).toList());
      return;
    }
    await _bookPersonDao.replaceForBook(bookId, people);
  }

  /// 保存游戏的人物关联
  Future<void> saveGamePeople(String gameId, List<GamePerson> people) async {
    if (_cloudGameMode) {
      await _cloudDomain.replacePeople(
          'games', gameId, people.map((p) => p.toJson()).toList());
      return;
    }
    await _gamePersonDao.replaceForGame(gameId, people);
  }

  /// 保存某个人物的所有影视关联（事务内先删后插，按 personId 维度）
  Future<void> savePersonMovieRelations(
      String personId, List<MoviePerson> relations) async {
    if (_cloudMovieMode) {
      // movie_people 是影视子组，没有按 person 维度的整组替换接口：
      // 对受影响的每部影视，取当前关联 → 剔除该人物旧行 → 并入新行 → 整组替换
      final oldWorks = await _cloudMovie.personMovieWorks(personId);
      final affectedMovieIds = <String>{
        ...oldWorks.map((w) => w.movie.id),
        ...relations.map((r) => r.movieId),
      };
      final newByMovie = <String, List<MoviePerson>>{};
      for (final r in relations) {
        newByMovie.putIfAbsent(r.movieId, () => []).add(r);
      }
      for (final movieId in affectedMovieIds) {
        final current = await _cloudMovie.listChildren(
            movieId, 'movie_people', MoviePerson.fromJson);
        final merged = current.where((p) => p.personId != personId).toList()
          ..addAll(newByMovie[movieId] ?? const []);
        await _cloudMovie.replaceMoviePeople(movieId, merged);
      }
      return;
    }
    await _moviePersonDao.replaceForPerson(personId, relations);
  }

  /// 保存某个人物的所有书籍关联
  Future<void> savePersonBookRelations(
      String personId, List<BookPerson> relations) async {
    if (_cloudBookMode) {
      // book_people 是书籍子组，没有按 person 维度的整组替换接口：
      // 对受影响的每本书，取当前关联 → 剔除该人物旧行 → 并入新行 → 整组替换
      final oldWorks = await _cloudDomain.personWorks('books', personId);
      final affectedIds = <String>{
        ...oldWorks.map((w) => Book.fromJson(w.work).id),
        ...relations.map((r) => r.bookId),
      };
      final newByBook = <String, List<BookPerson>>{};
      for (final r in relations) {
        newByBook.putIfAbsent(r.bookId, () => []).add(r);
      }
      for (final bookId in affectedIds) {
        final current = await _cloudDomain.listChildren(
            'books', bookId, 'book_people', BookPerson.fromJson);
        final merged = current.where((p) => p.personId != personId).toList()
          ..addAll(newByBook[bookId] ?? const []);
        await _cloudDomain.replacePeople(
            'books', bookId, merged.map((p) => p.toJson()).toList());
      }
      return;
    }
    await _bookPersonDao.replaceForPerson(personId, relations);
  }

  /// 保存某个人物的所有游戏关联
  Future<void> savePersonGameRelations(
      String personId, List<GamePerson> relations) async {
    if (_cloudGameMode) {
      final oldWorks = await _cloudDomain.personWorks('games', personId);
      final affectedIds = <String>{
        ...oldWorks.map((w) => Game.fromJson(w.work).id),
        ...relations.map((r) => r.gameId),
      };
      final newByGame = <String, List<GamePerson>>{};
      for (final r in relations) {
        newByGame.putIfAbsent(r.gameId, () => []).add(r);
      }
      for (final gameId in affectedIds) {
        final current = await _cloudDomain.listChildren(
            'games', gameId, 'game_people', GamePerson.fromJson);
        final merged = current.where((p) => p.personId != personId).toList()
          ..addAll(newByGame[gameId] ?? const []);
        await _cloudDomain.replacePeople(
            'games', gameId, merged.map((p) => p.toJson()).toList());
      }
      return;
    }
    await _gamePersonDao.replaceForPerson(personId, relations);
  }

  /// 扫描所有作品的人物字段，自动创建人物并建立关联
  /// 返回 (新增人物数, 新增关联数, 合并去重数)
  Future<({int newPersons, int newRelations, int merged})>
      refreshPersonRelations() async {
    // 先合并已有的同名重复人物
    final merged = await _personDao.mergeDuplicatePeople();
    if (merged > 0) {
      await loadPeople();
    }

    final nameIndex = <String, Person>{};
    for (final p in _people) {
      nameIndex[p.name] = p;
    }

    int newPersons = 0;
    int newRelations = 0;
    const uuid = Uuid();
    final now = DateTime.now();

    Future<Person> findOrCreate(String name, String occupationLabel) async {
      final existing = nameIndex[name];
      if (existing != null) return existing;
      // 内存索引未命中时回退查库，避免重复创建同名人物
      final dbExisting = await _personDao.getPersonByName(name);
      if (dbExisting != null) {
        nameIndex[name] = dbExisting;
        return dbExisting;
      }
      final person = Person(
        id: uuid.v4(),
        name: name,
        occupation: [occupationLabel],
        createdAt: now,
        updatedAt: now,
      );
      await _personDao.insertPerson(person);
      nameIndex[name] = person;
      newPersons++;
      return person;
    }

    // 影视：directors/writers/actors
    for (final movie in _movies) {
      if (movie.isDeleted) continue;
      final entries = <(List<String>, String, String)>[
        (movie.directors, 'director', '导演'),
        (movie.writers, 'writer', '编剧'),
        (movie.actors, 'actor', '演员'),
      ];
      for (final (names, roleType, occupationLabel) in entries) {
        final seen = <String>{};
        for (final name in names) {
          final trimmed = name.trim();
          if (trimmed.isEmpty || !seen.add(trimmed)) continue;
          final person = await findOrCreate(trimmed, occupationLabel);
          // 演员角色：若该影视已存在该人物的配音关联，则跳过添加演员关联
          if (roleType == 'actor' &&
              await _moviePersonDao.existsRelation(
                  movie.id, person.id, 'voiceActor')) {
            continue;
          }
          if (!await _moviePersonDao.existsRelation(
              movie.id, person.id, roleType)) {
            await _moviePersonDao.insert(MoviePerson(
              id: uuid.v4(),
              movieId: movie.id,
              personId: person.id,
              roleType: roleType,
              characterName: null,
              sortOrder: 0,
            ));
            newRelations++;
          }
        }
      }
    }

    // 书籍：authors/translators
    for (final book in _books) {
      if (book.isDeleted) continue;
      final entries = <(List<String>, String, String)>[
        (book.authors, 'author', '作者'),
        (book.translators, 'translator', '译者'),
      ];
      for (final (names, roleType, occupationLabel) in entries) {
        final seen = <String>{};
        for (final name in names) {
          final trimmed = name.trim();
          if (trimmed.isEmpty || !seen.add(trimmed)) continue;
          final person = await findOrCreate(trimmed, occupationLabel);
          if (!await _bookPersonDao.existsRelation(
              book.id, person.id, roleType)) {
            await _bookPersonDao.insert(BookPerson(
              id: uuid.v4(),
              bookId: book.id,
              personId: person.id,
              roleType: roleType,
              sortOrder: 0,
            ));
            newRelations++;
          }
        }
      }
    }

    // 游戏：developer
    for (final game in _games) {
      if (game.isDeleted) continue;
      final seen = <String>{};
      for (final name in game.developer) {
        final trimmed = name.trim();
        if (trimmed.isEmpty || !seen.add(trimmed)) continue;
        final person = await findOrCreate(trimmed, '开发者');
        if (!await _gamePersonDao.existsRelation(
            game.id, person.id, 'developer')) {
          await _gamePersonDao.insert(GamePerson(
            id: uuid.v4(),
            gameId: game.id,
            personId: person.id,
            roleType: 'developer',
            sortOrder: 0,
          ));
          newRelations++;
        }
      }
    }

    await loadPeople();
    return (newPersons: newPersons, newRelations: newRelations, merged: merged);
  }

  // ========== 角色相关方法 ==========

  // ─── 影视角色 ───
  Future<List<MovieCharacter>> getMovieCharacters(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.listChildren(
          movieId, 'movie_characters', MovieCharacter.fromJson);
    }
    return await _movieCharacterDao.getByMovieId(movieId);
  }

  Future<int> getMovieCharacterCount(String movieId) async {
    if (_cloudMovieMode) {
      return _cloudMovie.countChildren(movieId, 'movie_characters');
    }
    return await _movieCharacterDao.getCount(movieId);
  }

  Future<void> addMovieCharacter(MovieCharacter character) async {
    if (_cloudMovieMode) {
      await _cloudMovie.createChild(
          character.movieId, 'movie_characters', character.toJson());
      debugPrint('[云端] 新增影视角色「${_logTitle(character.name)}」');
      notifyListeners();
      return;
    }
    await _movieCharacterDao.insert(character);
    debugPrint(
        '[数据] 新增影视角色「${_logTitle(character.name)}」《${_titleById(_movies, character.movieId, (m) => m.id, (m) => m.title)}》');
    notifyListeners();
  }

  Future<void> updateMovieCharacter(MovieCharacter character) async {
    if (_cloudMovieMode) {
      await _cloudMovie.updateChild(
          'movie_characters', character.id, character.toJson());
      debugPrint('[云端] 更新影视角色「${_logTitle(character.name)}」');
      notifyListeners();
      return;
    }
    await _movieCharacterDao.update(character);
    debugPrint(
        '[数据] 更新影视角色「${_logTitle(character.name)}」《${_titleById(_movies, character.movieId, (m) => m.id, (m) => m.title)}》');
    notifyListeners();
  }

  Future<void> deleteMovieCharacter(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.deleteChild('movie_characters', id);
      debugPrint('[云端] 删除影视角色 id=$id');
      notifyListeners();
      return;
    }
    final character = await _movieCharacterDao.getById(id);
    await _movieCharacterDao.delete(id);
    debugPrint('[数据] 删除影视角色「${_logTitle(character?.name ?? '?')}」');
    notifyListeners();
  }

  /// 恢复已删除的影视角色
  Future<void> restoreMovieCharacter(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.restoreChild('movie_characters', id);
      notifyListeners();
      return;
    }
    await _movieCharacterDao.restore(id);
    final character = await _movieCharacterDao.getById(id);
    debugPrint('[数据] 恢复影视角色「${_logTitle(character?.name ?? '?')}」');
    notifyListeners();
  }

  /// 彻底删除影视角色
  Future<void> permanentDeleteMovieCharacter(String id) async {
    if (_cloudMovieMode) {
      await _cloudMovie.permanentDeleteChild('movie_characters', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('movie_characters', id, txn);
      await _movieCharacterDao.permanentDelete(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteCharacterImages(id);
  }

  /// 获取已删除的影视角色
  Future<List<MovieCharacter>> getDeletedMovieCharacters() async {
    if (_cloudMovieMode) {
      return _cloudMovie.deletedChildren(
          'movie_characters', MovieCharacter.fromJson);
    }
    return await _movieCharacterDao.getDeleted();
  }

  // ─── 书籍角色 ───
  Future<List<BookCharacter>> getBookCharacters(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.listChildren(
          'books', bookId, 'book_characters', BookCharacter.fromJson);
    }
    return await _bookCharacterDao.getByBookId(bookId);
  }

  Future<int> getBookCharacterCount(String bookId) async {
    if (_cloudBookMode) {
      return _cloudDomain.countChildren('books', bookId, 'book_characters');
    }
    return await _bookCharacterDao.getCount(bookId);
  }

  Future<void> addBookCharacter(BookCharacter character) async {
    if (_cloudBookMode) {
      await _cloudDomain.createChild(
          'books', character.bookId, 'book_characters', character.toJson());
      debugPrint('[云端] 新增书籍角色「${_logTitle(character.name)}」');
      notifyListeners();
      return;
    }
    await _bookCharacterDao.insert(character);
    debugPrint(
        '[数据] 新增书籍角色「${_logTitle(character.name)}」《${_titleById(_books, character.bookId, (b) => b.id, (b) => b.title)}》');
    notifyListeners();
  }

  Future<void> updateBookCharacter(BookCharacter character) async {
    if (_cloudBookMode) {
      await _cloudDomain.updateChild(
          'book_characters', character.id, character.toJson());
      debugPrint('[云端] 更新书籍角色「${_logTitle(character.name)}」');
      notifyListeners();
      return;
    }
    await _bookCharacterDao.update(character);
    debugPrint(
        '[数据] 更新书籍角色「${_logTitle(character.name)}」《${_titleById(_books, character.bookId, (b) => b.id, (b) => b.title)}》');
    notifyListeners();
  }

  Future<void> deleteBookCharacter(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.deleteChild('book_characters', id);
      debugPrint('[云端] 删除书籍角色');
      notifyListeners();
      return;
    }
    final character = await _bookCharacterDao.getById(id);
    await _bookCharacterDao.delete(id);
    debugPrint('[数据] 删除书籍角色「${_logTitle(character?.name ?? '?')}」');
    notifyListeners();
  }

  /// 恢复已删除的书籍角色
  Future<void> restoreBookCharacter(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.restoreChild('book_characters', id);
      notifyListeners();
      return;
    }
    await _bookCharacterDao.restore(id);
    final character = await _bookCharacterDao.getById(id);
    debugPrint('[数据] 恢复书籍角色「${_logTitle(character?.name ?? '?')}」');
    notifyListeners();
  }

  /// 彻底删除书籍角色
  Future<void> permanentDeleteBookCharacter(String id) async {
    if (_cloudBookMode) {
      await _cloudDomain.permanentDeleteChild('book_characters', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('book_characters', id, txn);
      await _bookCharacterDao.permanentDelete(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteCharacterImages(id);
  }

  /// 获取已删除的书籍角色
  Future<List<BookCharacter>> getDeletedBookCharacters() async {
    if (_cloudBookMode) {
      return _cloudDomain.deletedChildren(
          'book_characters', BookCharacter.fromJson);
    }
    return await _bookCharacterDao.getDeleted();
  }

  // ─── 游戏角色 ───
  Future<List<GameCharacter>> getGameCharacters(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.listChildren(
          'games', gameId, 'game_characters', GameCharacter.fromJson);
    }
    return await _gameCharacterDao.getByGameId(gameId);
  }

  Future<int> getGameCharacterCount(String gameId) async {
    if (_cloudGameMode) {
      return _cloudDomain.countChildren('games', gameId, 'game_characters');
    }
    return await _gameCharacterDao.getCount(gameId);
  }

  Future<void> addGameCharacter(GameCharacter character) async {
    if (_cloudGameMode) {
      await _cloudDomain.createChild(
          'games', character.gameId, 'game_characters', character.toJson());
      debugPrint('[云端] 新增游戏角色「${_logTitle(character.name)}」');
      notifyListeners();
      return;
    }
    await _gameCharacterDao.insert(character);
    debugPrint(
        '[数据] 新增游戏角色「${_logTitle(character.name)}」《${_titleById(_games, character.gameId, (g) => g.id, (g) => g.title)}》');
    notifyListeners();
  }

  Future<void> updateGameCharacter(GameCharacter character) async {
    if (_cloudGameMode) {
      await _cloudDomain.updateChild(
          'game_characters', character.id, character.toJson());
      debugPrint('[云端] 更新游戏角色「${_logTitle(character.name)}」');
      notifyListeners();
      return;
    }
    await _gameCharacterDao.update(character);
    debugPrint(
        '[数据] 更新游戏角色「${_logTitle(character.name)}」《${_titleById(_games, character.gameId, (g) => g.id, (g) => g.title)}》');
    notifyListeners();
  }

  Future<void> deleteGameCharacter(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.deleteChild('game_characters', id);
      debugPrint('[云端] 删除游戏角色');
      notifyListeners();
      return;
    }
    final character = await _gameCharacterDao.getById(id);
    await _gameCharacterDao.delete(id);
    debugPrint('[数据] 删除游戏角色「${_logTitle(character?.name ?? '?')}」');
    notifyListeners();
  }

  /// 恢复已删除的游戏角色
  Future<void> restoreGameCharacter(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.restoreChild('game_characters', id);
      notifyListeners();
      return;
    }
    await _gameCharacterDao.restore(id);
    final character = await _gameCharacterDao.getById(id);
    debugPrint('[数据] 恢复游戏角色「${_logTitle(character?.name ?? '?')}」');
    notifyListeners();
  }

  /// 彻底删除游戏角色
  Future<void> permanentDeleteGameCharacter(String id) async {
    if (_cloudGameMode) {
      await _cloudDomain.permanentDeleteChild('game_characters', id);
      return;
    }
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      await SyncTombstones.record('game_characters', id, txn);
      await _gameCharacterDao.permanentDelete(id, txn: txn);
    });
    await ImagePathHelper.instance.deleteCharacterImages(id);
  }

  /// 获取已删除的游戏角色
  Future<List<GameCharacter>> getDeletedGameCharacters() async {
    if (_cloudGameMode) {
      return _cloudDomain.deletedChildren(
          'game_characters', GameCharacter.fromJson);
    }
    return await _gameCharacterDao.getDeleted();
  }
}
