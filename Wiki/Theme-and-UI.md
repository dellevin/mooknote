# 主题与 UI

## AppTheme

`lib/utils/theme/app_theme.dart` — 极简主义黑白灰主题配置。

### 颜色体系

#### 中性色板

| 颜色 | 值 | 用途 |
|------|------|------|
| `_black` | `#1A1A1A` | 主要文字、主色 |
| `_darkGray` | `#333333` | 次要文字 |
| `_gray` | `#666666` | 辅助文字 |
| `_lightGray` | `#999999` | 占位文字 |
| `_lighterGray` | `#E5E5E5` | 分割线、边框 |
| `_offWhite` | `#F5F5F5` | 背景色 |
| `_white` | `#FFFFFF` | 主背景 |

#### 强调色

| 颜色 | 值 | 用途 |
|------|------|------|
| `accent` | `#0066FF` | 关键操作高亮 |
| `error` | `#DC2626` | 错误状态 |

#### 状态颜色

| 状态 | 颜色 | 说明 |
|------|------|------|
| `watched` / `readColor` | `#1A1A1A` | 已看/已读（纯黑）|
| `watching` / `readingColor` | `#666666` | 在看/在读（中灰）|
| `wantToWatch` / `wantToReadColor` | `#999999` | 想看/想读（浅灰）|

### Material 3 配置

```dart
ThemeData(
  useMaterial3: true,
  brightness: Brightness.light/dark,
  scaffoldBackgroundColor: _white/_black,
  colorScheme: ColorScheme.light/dark(...),
  fontFamily: 'Inter',
)
```

提供 `lightTheme` 和 `darkTheme` 两套主题。

### 字体

- 字体族：`Inter`
- 字重：`w400`（Regular）、`w500`（Medium）、`w600`（Semibold）

## 共享 Widget

| Widget | 文件 | 说明 |
|--------|------|------|
| `MovieListItem` | `widgets/movie_list_item.dart` | 影视列表项 |
| `BookListItem` | `widgets/book_list_item.dart` | 书籍列表项 |
| `NoteListItem` | `widgets/note_list_item.dart` | 笔记列表项 |
| `MovieStatusBar` | `widgets/movie_status_bar.dart` | 影视状态筛选栏 |
| `BookStatusBar` | `widgets/book_status_bar.dart` | 书籍状态筛选栏 |
| `AnimatedStarRating` | `widgets/animated_star_rating.dart` | 动画星级评分 |
| `BottomNavBar` | `widgets/bottom_nav_bar.dart` | 底部导航栏 |
| `CustomDrawer` | `widgets/custom_drawer.dart` | 侧边抽屉菜单 |
| `FadeInLocalImage` | `widgets/fade_in_local_image.dart` | 本地图片渐入显示 |
| `AppRefreshIndicator` | `widgets/app_refresh_indicator.dart` | 自定义下拉刷新 |
| `ShimmerSkeleton` | `widgets/shimmer_skeleton.dart` | 骨架屏加载效果 |

## 系统 UI

`MyApp` 在 `main.dart` 中通过 `SystemChrome.setSystemUIOverlayStyle` 控制状态栏和导航栏样式，随主题模式自动切换亮/暗色。

[返回首页](Home.md)
