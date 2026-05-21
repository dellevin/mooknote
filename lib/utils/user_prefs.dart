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

  // ========== 应用图标设置 ==========

  /// 当前选中的应用图标名称（对应 assets/icon/ 下的文件名，不含扩展名）
  String get appIconName => prefs.getString('appIconName') ?? 'app_icon';
  Future<bool> setAppIconName(String value) => prefs.setString('appIconName', value);
}
