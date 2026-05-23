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
  }
  
  /// 获取实例
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('UserPrefs not initialized. Call UserPrefs.init() first.');
    }
    return _prefs!;
  }
  
  // ========== 用户信息 ==========
  
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
  
  /// 是否暗黑模式
  bool get isDarkMode => prefs.getBool('isDarkMode') ?? false;
  Future<bool> setDarkMode(bool value) => prefs.setBool('isDarkMode', value);
  
  /// 是否首次启动
  bool get isFirstLaunch => prefs.getBool('isFirstLaunch') ?? true;
  Future<bool> setFirstLaunch(bool value) => prefs.setBool('isFirstLaunch', value);

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

  /// 默认启动标签 (0: 影视, 1: 阅读, 2: 笔记)
  int get defaultMainTabIndex => prefs.getInt('defaultMainTabIndex') ?? 0;
  Future<bool> setDefaultMainTabIndex(int value) => prefs.setInt('defaultMainTabIndex', value);

  /// 笔记布局样式 (0: 列表, 1: 瀑布流, 2: 时间线)
  int get noteLayoutStyle => prefs.getInt('noteLayoutStyle') ?? 0;
  Future<bool> setNoteLayoutStyle(int value) => prefs.setInt('noteLayoutStyle', value);

  /// 影视布局样式 (0: 海报网格, 1: 列表)
  int get movieLayoutStyle => prefs.getInt('movieLayoutStyle') ?? 0;
  Future<bool> setMovieLayoutStyle(int value) => prefs.setInt('movieLayoutStyle', value);

  /// 阅读布局样式 (0: 封面网格, 1: 列表)
  int get bookLayoutStyle => prefs.getInt('bookLayoutStyle') ?? 0;
  Future<bool> setBookLayoutStyle(int value) => prefs.setInt('bookLayoutStyle', value);

  // ========== 应用图标设置 ==========

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
}
