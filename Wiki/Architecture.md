# 整体架构

## 分层架构

```
┌─────────────────────────────────────────────┐
│                  Pages (UI)                  │  lib/pages/
│  home_page, movie_tab_page, book_tab_page,   │
│  note_tab_page, detail/form/share pages...   │
├─────────────────────────────────────────────┤
│               Widgets (共享组件)              │  lib/widgets/
│  list_items, star_rating, drawer, bottom_nav │
├─────────────────────────────────────────────┤
│            Providers (状态管理)               │  lib/providers/
│              AppProvider                     │
├─────────────────────────────────────────────┤
│              Utils (业务逻辑)                 │  lib/utils/
│  DAO层 │ 同步服务 │ 图片管理 │ 主题 │ 偏好设置 │
├─────────────────────────────────────────────┤
│             Models (数据模型)                 │  lib/models/
│  Movie │ Book │ Note │ Reviews │ Posters...  │
├─────────────────────────────────────────────┤
│           Database (SQLite)                  │  lib/utils/database_helper.dart
│              sqflite                         │
└─────────────────────────────────────────────┘
```

## 目录职责

### lib/models/
数据模型定义，所有模型集中在 `data_models.dart` 中：`Movie`、`Book`、`Note`、`MovieReview`、`BookReview`、`MoviePoster`、`BookExcerpt`。每个模型提供 `fromJson` / `toJson` / `copyWith` 方法。

### lib/providers/
全局状态管理，仅 `AppProvider`（ChangeNotifier）一个文件。管理所有数据列表、UI 状态、CRUD 操作。

### lib/utils/
业务逻辑层：
- `database_helper.dart` — SQLite 数据库单例（版本 13）
- `movie/`、`book/`、`note/` — 各实体 DAO
- `tag/tag_dao.dart` — 标签管理
- `sync/` — 同步服务（ServerSyncService、ServerDataService、WebDAV、AutoBackup）
- `theme/app_theme.dart` — 主题定义
- `user_prefs.dart` — SharedPreferences 包装
- `image_path_helper.dart` — 图片路径管理
- `app_router.dart` — 路由生成器

### lib/pages/
UI 页面，按功能域组织：
- `movies/` — 影视相关（列表、详情、表单、影评、海报墙、分享、豆瓣 WebView）
- `book/` — 书籍相关（列表、详情、表单、书评、摘抄、分享）
- `note/` — 笔记相关（列表、详情、表单、分享）
- `sync/` — 同步页面（备份、云同步、服务端同步、WebDAV）
- `markdown_reader/` — Markdown 阅读器

### lib/widgets/
共享可复用 Widget：列表项、星级评分、抽屉菜单、底部导航、骨架屏等。

## 启动流程

`main.dart` 中的初始化顺序：

```
1. WidgetsFlutterBinding.ensureInitialized()
2. UserPrefs.init()                      ← SharedPreferences 初始化
3. AppProvider()                         ← 创建全局状态
4. runApp(MyApp)                         ← 启动 UI
5. (异步) _validateSyncOnStartup()       ← 校验同步激活码
6. (异步) appProvider.initDatabase()     ← 加载数据（本地或远程）
7. (异步) appProvider.initMainTabIndex() ← 恢复用户默认标签
8. (异步) _initAutoBackup()              ← 启动自动备份（如已启用）
9. (异步) _initUsageStats()              ← 启动用户统计上报
```

步骤 5-9 均为 `unawaited`，不阻塞 UI 渲染。

## 本地/远程双模式

`AppProvider._useRemote` 决定数据来源：

```dart
bool get _useRemote {
  final prefs = UserPrefs();
  return prefs.syncEnabled &&
      prefs.syncServerUrl.isNotEmpty &&
      prefs.syncActivationCode.isNotEmpty &&
      ServerDataService.instance.isAvailable;
}
```

所有 DAO 方法（增删改查）在 `AppProvider` 中都有双路径：
- `_useRemote == true` → 调用 `ServerDataService`（HTTP API）
- `_useRemote == false` → 调用本地 DAO（SQLite）

[返回首页](Home.md)
