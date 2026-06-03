# 用户偏好

## UserPrefs

`lib/utils/user_prefs.dart` — SharedPreferences 单例包装器。

```dart
class UserPrefs {
  static final UserPrefs _instance = UserPrefs._internal();
  factory UserPrefs() => _instance;
}
```

使用前必须调用 `UserPrefs.init()`（在 `main.dart` 中完成）。

## 配置项列表

### 用户信息

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `nickname` | String | `'Mook'` | 昵称 |
| `motto` | String | `'好运不会眷顾一无所有之人。'` | 座右铭 |
| `avatarPath` | String? | `null` | 头像本地路径 |

### 应用设置

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `themeMode` | int | `0` | 0=跟随系统, 1=浅色, 2=深色 |
| `showExactReleaseDate` | bool | `true` | 上映日期显示到日/月 |
| `isFirstLaunch` | bool | `true` | 是否首次启动 |

### 主界面显示

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `hideBottomNavOnScroll` | bool | `true` | 滚动时隐藏底部导航 |
| `showMovieTab` | bool | `true` | 是否显示观影标签 |
| `showBookTab` | bool | `true` | 是否显示阅读标签 |
| `showNoteTab` | bool | `true` | 是否显示笔记标签 |
| `defaultMainTabIndex` | int | `0` | 默认启动标签（0=影视, 1=阅读, 2=笔记）|

### 布局样式

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `noteLayoutStyle` | int | `0` | 笔记布局（0=列表, 1=瀑布流, 2=时间线）|
| `movieLayoutStyle` | int | `0` | 影视布局（0=海报网格, 1=列表）|
| `bookLayoutStyle` | int | `0` | 阅读布局（0=封面网格, 1=列表）|

### Markdown 阅读器

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `lastMdFolder` | String? | `null` | 最近选择的目录 |
| `showEmptyDirs` | bool | `true` | 是否显示空目录 |
| `showImageOnlyDirs` | bool | `true` | 是否显示纯图片目录 |

### 应用图标

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `appIconName` | String | `'app_icon'` | 当前应用图标名称 |

### 用户统计

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `deviceId` | String | `''` | 匿名设备标识（首次启动自动生成）|

### 服务端同步

| 键 | 类型 | 默认值 | 说明 |
|----|------|--------|------|
| `syncServerUrl` | String | `''` | 服务器地址 |
| `syncActivationCode` | String | `''` | 激活码 |
| `syncExpiresAt` | String | `''` | 激活码有效期 |
| `syncIsPermanent` | bool | `false` | 是否永久有效 |
| `syncEnabled` | bool | `true` | 实时同步开关 |
| `syncLastEntryId` | int | `0` | 上次同步的 entry ID |

## 主题模式迁移

`UserPrefs.init()` 中包含旧版 `isDarkMode`（布尔值）到新版 `themeMode`（三态值）的自动迁移：

```dart
if (_prefs!.containsKey('isDarkMode') && !_prefs!.containsKey('themeMode')) {
  final oldValue = _prefs!.getBool('isDarkMode') ?? false;
  await _prefs!.setInt('themeMode', oldValue ? 2 : 0);
}
```

[返回首页](Home.md)
