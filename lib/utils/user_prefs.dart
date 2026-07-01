import 'package:shared_preferences/shared_preferences.dart';

/// 用户偏好设置管理
class UserPrefs {
  static final UserPrefs _instance = UserPrefs._internal();
  static SharedPreferences? _prefs;
  
  factory UserPrefs() => _instance;
  UserPrefs._internal();
  
  /// 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // 迁移旧版 isDarkMode 布尔值到新版 themeMode 三态值
    if (_prefs!.containsKey('isDarkMode') && !_prefs!.containsKey('themeMode')) {
      final oldValue = _prefs!.getBool('isDarkMode') ?? false;
      await _prefs!.setInt('themeMode', oldValue ? 2 : 0);
    }
    // 记录首次使用日期
    if (!_prefs!.containsKey('firstUseDate')) {
      await _prefs!.setString('firstUseDate', DateTime.now().toIso8601String());
    }
  }
  
  /// 获取实例
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('UserPrefs not initialized. Call UserPrefs.init() first.');
    }
    return _prefs!;
  }
  
  // ========== 用户信息 ==========

  /// 首次使用日期
  DateTime get firstUseDate {
    final str = prefs.getString('firstUseDate');
    if (str != null) return DateTime.tryParse(str)?.toLocal() ?? DateTime.now();
    return DateTime.now();
  }

  /// 昵称
  String get nickname => prefs.getString('nickname') ?? 'Mook';
  Future<bool> setNickname(String value) => prefs.setString('nickname', value);
  
  /// 座右铭
  String get motto => prefs.getString('motto') ?? '好运不会眷顾一无所有之人。';
  Future<bool> setMotto(String value) => prefs.setString('motto', value);
  
  /// 头像路径
  String? get avatarPath => prefs.getString('avatarPath');
  Future<bool> setAvatarPath(String value) => prefs.setString('avatarPath', value);
  Future<bool> clearAvatarPath() => prefs.remove('avatarPath');
  
  // ========== 应用设置 ==========
  
  /// 主题模式: 0=跟随系统, 1=浅色, 2=深色
  int get themeMode => prefs.getInt('themeMode') ?? 0;
  Future<bool> setThemeMode(int value) => prefs.setInt('themeMode', value);

  /// 配色方案: 0=经典, 1=靛蓝, 2=薄荷, 3=琥珀, 4=玫瑰, 5=紫罗兰
  int get colorSchemeIndex => prefs.getInt('colorSchemeIndex') ?? 0;
  Future<bool> setColorSchemeIndex(int value) => prefs.setInt('colorSchemeIndex', value);

  /// 字体: 空字符串=系统默认
  String get fontFamily => prefs.getString('fontFamily') ?? '';
  Future<bool> setFontFamily(String value) => prefs.setString('fontFamily', value);

  /// 上映日期：显示到日（true）/ 显示到月（false）
  bool get showExactReleaseDate => prefs.getBool('showExactReleaseDate') ?? true;
  Future<bool> setShowExactReleaseDate(bool value) => prefs.setBool('showExactReleaseDate', value);
  
  /// 是否首次启动
  bool get isFirstLaunch => prefs.getBool('isFirstLaunch') ?? true;
  Future<bool> setFirstLaunch(bool value) => prefs.setBool('isFirstLaunch', value);

  // ========== 详情页样式 ==========

  /// 详情页展示样式: 0=标准(封面顶部), 1=叠层(封面+毛玻璃卡片)
  int get detailPageStyle => prefs.getInt('detailPageStyle') ?? 0;
  Future<bool> setDetailPageStyle(int value) => prefs.setInt('detailPageStyle', value);

  // ========== 封面位置 ==========

  /// 获取封面偏移量（-1.0 到 1.0，0 = 居中）
  double getCoverOffset(String itemId) => prefs.getDouble('coverOffset_$itemId') ?? 0.0;
  Future<bool> setCoverOffset(String itemId, double value) => prefs.setDouble('coverOffset_$itemId', value);

  // ========== 主界面显示设置 ==========

  /// 是否启用底部导航栏滚动隐藏（默认开启）
  bool get hideBottomNavOnScroll => prefs.getBool('hideBottomNavOnScroll') ?? true;
  Future<bool> setHideBottomNavOnScroll(bool value) => prefs.setBool('hideBottomNavOnScroll', value);

  /// 是否显示观影标签
  bool get showMovieTab => prefs.getBool('showMovieTab') ?? true;
  Future<bool> setShowMovieTab(bool value) => prefs.setBool('showMovieTab', value);

  /// 是否显示阅读标签
  bool get showBookTab => prefs.getBool('showBookTab') ?? true;
  Future<bool> setShowBookTab(bool value) => prefs.setBool('showBookTab', value);

  /// 是否显示笔记标签
  bool get showNoteTab => prefs.getBool('showNoteTab') ?? true;
  Future<bool> setShowNoteTab(bool value) => prefs.setBool('showNoteTab', value);

  /// 是否显示 Note Plus 标签（默认关闭）
  bool get showNotePlusTab => prefs.getBool('showNotePlusTab') ?? false;
  Future<bool> setShowNotePlusTab(bool value) => prefs.setBool('showNotePlusTab', value);

  /// 默认启动标签 (0: 影视, 1: 阅读, 2: 笔记)
  int get defaultMainTabIndex => prefs.getInt('defaultMainTabIndex') ?? 0;
  Future<bool> setDefaultMainTabIndex(int value) => prefs.setInt('defaultMainTabIndex', value);

  // ─── 侧边栏功能开关 ───

  bool get showSidebarHeatmap => prefs.getBool('showSidebarHeatmap') ?? true;
  Future<bool> setShowSidebarHeatmap(bool value) => prefs.setBool('showSidebarHeatmap', value);

  bool get showSidebarRecent => prefs.getBool('showSidebarRecent') ?? true;
  Future<bool> setShowSidebarRecent(bool value) => prefs.setBool('showSidebarRecent', value);

  bool get showSidebarEncounter => prefs.getBool('showSidebarEncounter') ?? true;
  Future<bool> setShowSidebarEncounter(bool value) => prefs.setBool('showSidebarEncounter', value);

  bool get showSidebarStroll => prefs.getBool('showSidebarStroll') ?? true;
  Future<bool> setShowSidebarStroll(bool value) => prefs.setBool('showSidebarStroll', value);

  bool get showSidebarCalendar => prefs.getBool('showSidebarCalendar') ?? true;
  Future<bool> setShowSidebarCalendar(bool value) => prefs.setBool('showSidebarCalendar', value);

  bool get showSidebarPerson => prefs.getBool('showSidebarPerson') ?? true;
  Future<bool> setShowSidebarPerson(bool value) => prefs.setBool('showSidebarPerson', value);

  bool get showSidebarTags => prefs.getBool('showSidebarTags') ?? true;
  Future<bool> setShowSidebarTags(bool value) => prefs.setBool('showSidebarTags', value);

  bool get showSidebarMdReader => prefs.getBool('showSidebarMdReader') ?? false;
  Future<bool> setShowSidebarMdReader(bool value) => prefs.setBool('showSidebarMdReader', value);

  bool get showSidebarEpub => prefs.getBool('showSidebarEpub') ?? true;
  Future<bool> setShowSidebarEpub(bool value) => prefs.setBool('showSidebarEpub', value);

  /// 笔记布局样式 (0: 列表, 1: 瀑布流, 2: 时间线)
  int get noteLayoutStyle => prefs.getInt('noteLayoutStyle') ?? 0;
  Future<bool> setNoteLayoutStyle(int value) => prefs.setInt('noteLayoutStyle', value);

  /// 笔记排序方式 (0: 更新时间, 1: 创建时间)
  int get noteSortMode => prefs.getInt('noteSortMode') ?? 0;
  Future<bool> setNoteSortMode(int value) => prefs.setInt('noteSortMode', value);

  /// 影视排序方式 (0: 更新时间, 1: 创建时间, 2: 评分)
  int get movieSortMode => prefs.getInt('movieSortMode') ?? 0;
  Future<bool> setMovieSortMode(int value) => prefs.setInt('movieSortMode', value);

  /// 书籍排序方式 (0: 更新时间, 1: 创建时间, 2: 评分)
  int get bookSortMode => prefs.getInt('bookSortMode') ?? 0;
  Future<bool> setBookSortMode(int value) => prefs.setInt('bookSortMode', value);

  /// 影视布局样式 (0: 海报网格, 1: 列表)
  int get movieLayoutStyle => prefs.getInt('movieLayoutStyle') ?? 0;
  Future<bool> setMovieLayoutStyle(int value) => prefs.setInt('movieLayoutStyle', value);

  /// 阅读布局样式 (0: 封面网格, 1: 列表)
  int get bookLayoutStyle => prefs.getInt('bookLayoutStyle') ?? 0;
  Future<bool> setBookLayoutStyle(int value) => prefs.setInt('bookLayoutStyle', value);

  // ========== 应用图标设置 ==========

  // ========== Markdown 阅读器 ==========

  /// Markdown 阅读器最近选择的目录
  String? get lastMdFolder => prefs.getString('lastMdFolder');
  Future<bool> setLastMdFolder(String value) => prefs.setString('lastMdFolder', value);

  /// 是否显示空目录（无 Markdown 文件的目录）
  bool get showEmptyDirs => prefs.getBool('showEmptyDirs') ?? true;
  Future<bool> setShowEmptyDirs(bool value) => prefs.setBool('showEmptyDirs', value);

  /// 是否显示纯图片目录（只有图片、无 Markdown 文件的目录）
  bool get showImageOnlyDirs => prefs.getBool('showImageOnlyDirs') ?? true;
  Future<bool> setShowImageOnlyDirs(bool value) => prefs.setBool('showImageOnlyDirs', value);

  // ========== 应用图标设置 ==========

  /// 当前选中的应用图标名称（对应 assets/icon/ 下的文件名，不含扩展名）
  String get appIconName => prefs.getString('appIconName') ?? 'app_icon';
  Future<bool> setAppIconName(String value) => prefs.setString('appIconName', value);

  // ========== 用户统计设置 ==========

  /// 匿名设备标识（首次启动自动生成）
  String get deviceId => prefs.getString('deviceId') ?? '';
  Future<bool> setDeviceId(String value) => prefs.setString('deviceId', value);

  // ========== 搜索历史 ==========

  /// 搜索历史记录
  List<String> get searchHistory => prefs.getStringList('searchHistory') ?? [];
  Future<bool> setSearchHistory(List<String> value) => prefs.setStringList('searchHistory', value);

  /// 添加搜索记录（最多 50 条）
  Future<void> addSearchHistory(String keyword) async {
    final list = searchHistory;
    list.remove(keyword);
    list.insert(0, keyword);
    if (list.length > 50) { list.removeRange(50, list.length); }
    await setSearchHistory(list);
  }

  /// 删除单条搜索记录
  Future<void> removeSearchHistory(String keyword) async {
    final list = searchHistory;
    list.remove(keyword);
    await setSearchHistory(list);
  }

  /// 清空搜索历史
  Future<void> clearSearchHistory() => setSearchHistory([]);

  // ========== 增强搜索 ==========

  /// 是否开启增强搜索
  bool get enhancedSearchEnabled => prefs.getBool('enhancedSearchEnabled') ?? false;
  Future<bool> setEnhancedSearchEnabled(bool value) => prefs.setBool('enhancedSearchEnabled', value);

  /// 影视增强搜索 Token
  String get movieSearchToken => prefs.getString('movieSearchToken') ?? '';
  Future<bool> setMovieSearchToken(String value) => prefs.setString('movieSearchToken', value);

  /// 书籍增强搜索 Token
  String get bookSearchToken => prefs.getString('bookSearchToken') ?? '';
  Future<bool> setBookSearchToken(String value) => prefs.setString('bookSearchToken', value);

  /// 上次搜索的 Tab: 0=影视, 1=书籍
  int get lastSearchTab => prefs.getInt('lastSearchTab') ?? 0;
  Future<bool> setLastSearchTab(int value) => prefs.setInt('lastSearchTab', value);

  // ========== 版本更新 ==========

  /// 已忽略的版本号（不再提示更新）
  String get dismissedVersion => prefs.getString('dismissedVersion') ?? '';
  Future<bool> setDismissedVersion(String value) => prefs.setString('dismissedVersion', value);

  /// 更新提醒 snooze 到指定时间戳（ms），24 小时内不弹
  int get dismissedUpdateUntil => prefs.getInt('dismissedUpdateUntil') ?? 0;
  Future<bool> setDismissedUpdateUntil(int value) => prefs.setInt('dismissedUpdateUntil', value);

  // ========== EPUB 阅读器 ==========

  /// EPUB 阅读器字体大小
  double get epubFontSize => prefs.getDouble('epubFontSize') ?? 18.0;
  Future<bool> setEpubFontSize(double value) => prefs.setDouble('epubFontSize', value);

  /// EPUB 书架视图模式: 0=宽松, 1=紧凑
  int get epubViewMode => prefs.getInt('epubViewMode') ?? 0;
  Future<bool> setEpubViewMode(int value) => prefs.setInt('epubViewMode', value);

  /// EPUB 句读列表视图模式: 0=瀑布流, 1=列表
  int get highlightsViewMode => prefs.getInt('highlightsViewMode') ?? 0;
  Future<bool> setHighlightsViewMode(int value) => prefs.setInt('highlightsViewMode', value);
}
