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

## 布局设置界面

`lib/pages/profile_page.dart` 中的 `LayoutSettingsPage` — 设置中的布局配置页面。

### 界面结构

- **分类分组**：影视、阅读、笔记三个模块分别用图标+标题分组
- **开关卡片**：影视墙模式、书架模式用带图标的卡片+Switch展示
- **布局选择器**：自定义卡片式选择器，替代原生的 `SegmentedButton`

### 布局选择器样式

```dart
_buildLayoutSelector(
  selected: _movieLayout,
  options: [
    (0, Icons.grid_view_outlined, '海报网格'),
    (1, Icons.view_list_outlined, '列表'),
    (2, Icons.crop_landscape_outlined, '大图卡片'),
  ],
  onChanged: (v) => _setLayout('movie', v),
)
```

特点：
- **卡片式布局**：每个选项是圆角卡片（圆角12px）
- **选中状态**：主色填充 + 白色图标文字
- **未选中状态**：浅灰背景 + 灰色图标文字
- **动画效果**：`AnimatedContainer` 实现150ms平滑过渡
- **图标+文字垂直排列**：22px图标 + 12px文字
- **等宽分布**：`Expanded` 让选项等宽排列

### 影视墙/书架模式开关

```dart
_buildWallSwitch(
  icon: Icons.wallpaper_outlined,
  title: '影视墙模式',
  subtitle: '显示全部影片，不区分状态',
  value: _movieWallMode,
  onChanged: (v) => _setWallMode('movie', v),
)
```

开关卡片样式：
- 左侧：36px圆角图标容器（主色8%透明度背景）
- 中间：标题+副标题文字
- 右侧：Switch开关

## 共享 Widget

| Widget | 文件 | 说明 |
|--------|------|------|
| `MovieListItem` | `widgets/movie_list_item.dart` | 影视列表项 |
| `BookListItem` | `widgets/book_list_item.dart` | 书籍列表项 |
| `NoteListItem` | `widgets/note_list_item.dart` | 笔记列表项 |
| `MovieStatusBar` | `widgets/movie_status_bar.dart` | 影视状态筛选栏（已看/在看/想看）|
| `BookStatusBar` | `widgets/book_status_bar.dart` | 书籍状态筛选栏（已读/在读/想读）|
| `AnimatedStarRating` | `widgets/animated_star_rating.dart` | 动画星级评分 |
| `BottomNavBar` | `widgets/bottom_nav_bar.dart` | 底部导航栏 |
| `CustomDrawer` | `widgets/custom_drawer.dart` | 侧边抽屉菜单 |
| `FadeInLocalImage` | `widgets/fade_in_local_image.dart` | 本地图片渐入显示 |
| `AppRefreshIndicator` | `widgets/app_refresh_indicator.dart` | 自定义下拉刷新 |
| `ShimmerSkeleton` | `widgets/shimmer_skeleton.dart` | 骨架屏加载效果 |
| `TagSidePanel` | `widgets/tag_side_panel.dart` | 标签选择侧边面板 |
| `MasterDetailScaffold` | `widgets/master_detail_scaffold.dart` | 平板双栏布局 |

## 标签选择面板

`TagSidePanel` — 从右侧滑入的标签选择面板。

### 特点

- **滑入动画**：从右侧250ms滑入，带遮罩层
- **已选标签**：主色填充的圆角标签，点击移除
- **全部标签**：可选中/取消选中，选中状态带主色边框
- **新建标签**：顶部输入框，回车或点击+号添加
- **保存按钮**：右上角圆角主色按钮，替代原来的关闭图标

### 布局对齐

已选标签和全部标签均使用 `Wrap` 组件，配置：
```dart
Wrap(
  alignment: WrapAlignment.start,
  crossAxisAlignment: WrapCrossAlignment.start,
)
```
确保标签严格左对齐。

## 系统 UI

`MyApp` 在 `main.dart` 中通过 `SystemChrome.setSystemUIOverlayStyle` 控制状态栏和导航栏样式，随主题模式自动切换亮/暗色。

[返回首页](Home.md)
