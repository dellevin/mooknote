# 页面与路由

## 页面结构

### 主页框架

```
HomePage
├── CustomDrawer (侧边菜单)
├── PageView
│   ├── MainContentPage (主内容)
│   │   ├── MovieTabPage  (观影列表, mainTabIndex=0)
│   │   ├── BookTabPage   (阅读列表, mainTabIndex=1)
│   │   └── NoteTabPage   (笔记列表, mainTabIndex=2)
│   └── ProfilePage (我的, bottomNavIndex=2)
└── BottomNavBar (底部导航)
```

底部导航切换 `bottomNavIndex`：
- 0 → 主内容页（MainContentPage）
- 1 → 新增页（根据当前 mainTabIndex 跳转对应表单）
- 2 → 个人页（ProfilePage）

### 影视模块页面

| 页面 | 文件 | 说明 |
|------|------|------|
| MovieTabPage | `pages/movies/movie_tab_page.dart` | 影视列表（按状态筛选）|
| MovieFormPage | `pages/movies/movie_form_page.dart` | 新增/编辑影视 |
| MovieDetailPage | `pages/movies/movie_detail_page.dart` | 影视详情 |
| MovieReviewsPage | `pages/movies/movie_reviews_page.dart` | 影评列表 |
| MovieReviewFormPage | `pages/movies/movie_review_form_page.dart` | 新增/编辑影评 |
| MovieReviewDetailPage | `pages/movies/movie_review_detail_page.dart` | 影评详情 |
| MoviePostersPage | `pages/movies/movie_posters_page.dart` | 海报墙 |
| PosterGalleryPage | `pages/movies/poster_gallery_page.dart` | 海报画廊浏览 |
| MovieSharePage | `pages/movies/movie_share_page.dart` | 影视分享 |
| DoubanWebViewPage | `pages/movies/douban_webview_page.dart` | 豆瓣 WebView |

### 书籍模块页面

| 页面 | 文件 | 说明 |
|------|------|------|
| BookTabPage | `pages/book/book_tab_page.dart` | 书籍列表 |
| BookFormPage | `pages/book/book_form_page.dart` | 新增/编辑书籍 |
| BookDetailPage | `pages/book/book_detail_page.dart` | 书籍详情 |
| BookReviewsPage | `pages/book/book_reviews_page.dart` | 书评列表 |
| BookReviewFormPage | `pages/book/book_review_form_page.dart` | 新增/编辑书评 |
| BookReviewDetailPage | `pages/book/book_review_detail_page.dart` | 书评详情 |
| BookExcerptsPage | `pages/book/book_excerpts_page.dart` | 摘抄列表 |
| BookExcerptFormPage | `pages/book/book_excerpt_form_page.dart` | 新增/编辑摘抄 |
| BookSharePage | `pages/book/book_share_page.dart` | 书籍分享 |

### 笔记模块页面

| 页面 | 文件 | 说明 |
|------|------|------|
| NoteTabPage | `pages/note/note_tab_page.dart` | 笔记列表 |
| NoteFormPage | `pages/note/note_form_page.dart` | 新增/编辑笔记 |
| NoteDetailPage | `pages/note/note_detail_page.dart` | 笔记详情 |
| NoteSharePage | `pages/note/note_share_page.dart` | 笔记分享 |

### 其他页面

| 页面 | 文件 | 说明 |
|------|------|------|
| HomePage | `pages/home_page.dart` | 主页框架 |
| MainContentPage | `pages/main_content_page.dart` | 主内容区域 |
| ProfilePage | `pages/profile_page.dart` | 个人页 |
| SearchPage | `pages/search_page.dart` | 全局搜索 |
| StatisticsPage | `pages/statistics_page.dart` | 统计分析 |
| StrollPage | `pages/stroll_page.dart` | 浏览/发现 |
| RecycleBinPage | `pages/recycle_bin_page.dart` | 回收站 |
| TagManagementPage | `pages/tag_management_page.dart` | 标签管理 |
| AppIconPickerPage | `pages/app_icon_picker_page.dart` | 应用图标选择 |
| BackupPage | `pages/sync/backup_page.dart` | 本地备份 |
| CloudSyncPage | `pages/sync/cloud_sync_page.dart` | 云同步 |
| ServerSyncPage | `pages/sync/server_sync_page.dart` | 服务端同步配置 |
| WebDAVSyncPage | `pages/sync/webdav_sync_page.dart` | WebDAV 同步 |
| MdReaderTabPage | `pages/markdown_reader/md_reader_tab_page.dart` | Markdown 阅读器目录 |
| MdViewerPage | `pages/markdown_reader/md_viewer_page.dart` | Markdown 查看器 |

## 路由

`AppRouter`（`lib/utils/app_router.dart`）使用 `onGenerateRoute` 生成路由：

| 路由名 | 参数 | 目标页面 |
|--------|------|---------|
| `/movie-form` | `Movie?` 或 `{initialStatus}` | MovieFormPage |
| `/book-form` | `Book?` 或 `{initialStatus}` | BookFormPage |
| `/note-form` | `Note?` | NoteFormPage |
| `/movie-detail` | `Movie` | MovieDetailPage |
| `/book-detail` | `Book` | BookDetailPage |
| `/note-detail` | `Note` | NoteDetailPage |
| `/douban-webview` | `String` (URL) | DoubanWebViewPage |

## 过渡动画

所有路由使用 `SlideUpPageRoute`（`lib/utils/slide_up_page_route.dart`），实现从底部滑入的过渡效果。

[返回首页](Home.md)
