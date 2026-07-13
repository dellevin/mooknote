# MookNote

极简风格的观影 · 阅读 · 笔记 记录应用，基于 Flutter 开发。

软件官网：[https://mooknote.iletter.top](https://mooknote.iletter.top/)

开发记录：[http://docmost.iletter.top/share/ropwljpyvn/p/mook-note-lHmPTswdDC](http://docmost.iletter.top/share/ropwljpyvn/p/mook-note-lHmPTswdDC)

## 应用预览

|                  影视列表                  |                  书籍列表                  |                  笔记界面                  |
| :-----------------------------------------: | :-----------------------------------------: | :-----------------------------------------: |
| ![影视列表](image/README/1782484732881.png) | ![书籍列表](image/README/1782484753882.png) | ![笔记界面](image/README/1782484769014.png) |

|                  数据统计                  |                  侧边栏                  |                  我的界面                  |
| :-----------------------------------------: | :---------------------------------------: | :-----------------------------------------: |
| ![数据统计](image/README/1782484806542.png) | ![侧边栏](image/README/1782484815573.png) | ![我的界面](image/README/1782484824223.png) |

|                  详情界面1                  |                  详情界面2                  |                  编辑笔记                  |
| :------------------------------------------: | :------------------------------------------: | :-----------------------------------------: |
| ![详情界面1](image/README/1782484832641.png) | ![详情界面2](image/README/1782484836809.png) | ![编辑笔记](image/README/1782484844066.png) |

|                  分享界面1                  |                  分享界面2                  |                  预览笔记                  |
| :------------------------------------------: | :------------------------------------------: | :-----------------------------------------: |
| ![分享界面1](image/README/1782484860728.png) | ![分享界面2](image/README/1782484855884.png) | ![预览笔记](image/README/1782484849659.png) |

## 功能特性

### 影视管理

- 影视增删改查，支持海报、导演、演员、类型等信息录入
- 影视分类：电影 / 电视剧 / 动漫 / 综艺 / 纪录片 / 短片
- 影评撰写与管理，支持短评与长评，星级评分
- 影视海报墙浏览（瀑布流布局），支持多张海报管理与全屏浏览
- 影视分享（生成海报名场面风格分享卡片）
- 豆瓣链接爬取，自动填充影视信息
- 影视状态筛选（想看 / 在看 / 已看）
- 多种排序方式（更新时间 / 创建时间 / 评分）
- 多种列表布局（海报网格 / 列表 / 大图卡片）
- 在线搜索影视资源（服务端代理，支持分页）

### 书籍管理

- 书籍增删改查，支持封面、作者、出版社、ISBN 等信息
- 书评撰写与管理，支持短评与长评
- 书摘 / 摘录记录（按章节管理，支持批注）
- 书籍分享卡片
- 书籍状态筛选（想读 / 在读 / 已读）
- 多种排序方式（更新时间 / 创建时间 / 评分）
- 多种列表布局（封面网格 / 列表）
- Epub 阅读功能（详见下方）
- 在线搜索书籍资源

### 笔记管理

- 笔记增删改查，支持 Markdown 编辑与实时渲染
- 笔记置顶功能
- 多种列表布局：列表 / 瀑布流 / 时间线
- 多种排序方式（更新时间 / 创建时间 / 标题）
- 笔记分享卡片
- Markdown 阅读器支持暗色模式与字体大小调节

### Note Plus（块级编辑器）

- 类 Notion 的块级富文本编辑器，基于 flutter_quill
- 支持 10 种块类型：段落、标题（H1-H3）、无序列表、有序列表、待办清单、引用、代码块、分隔线
- 行内格式：粗体、斜体、下划线、删除线、行内代码
- 斜杠命令菜单（输入 `/` 唤出）
- 树形文档结构，支持嵌套层级与拖拽排序
- 撤销 / 重做（最多 50 步）
- 独立标签页管理（可在设置中开关）

### Epub 阅读器

- 基于 WebView 的 Epub 渲染引擎
- 目录导航抽屉（支持嵌套章节结构）
- 阅读进度追踪与记录
- 脚注弹窗、图片全屏查看
- 音量键翻页
- 多种阅读样式：字体大小、字号、行高、边距自定义
- 多套阅读主题（浅色 / 深色 / 护眼 / 纸张等）
- 亮度调节
- 书架管理（网格展示，文件选择器导入 Epub）
- 书籍元数据编辑

### Markdown 阅读器

- 本地文件系统浏览与目录过滤
- Markdown 文件渲染查看
- 支持筛选目录（空目录 / 纯图片目录）

### 通用功能

- 全局搜索（影视 / 书籍 / 笔记）+ 在线搜索
- 标签管理与分类（影视类型 / 书籍类型 / 笔记标签统一管理，支持重命名 / 删除 / 隐藏）
- 数据统计与可视化图表（总览、状态分布、类型偏好、导演 / 作者 Top 5、月度活动日历、星期分布、累计增长曲线）
- 媒体日历（按日期查看影视 / 书籍添加记录，展示封面缩略图）
- 人物列表（汇总所有导演、编剧、演员、作者，关联其作品）
- 随机漫步（随机回顾影视 / 书籍 / 笔记内容）
- 与你相遇（使用天数、总记录数、字数、图片数统计）
- 回收站（软删除，支持恢复和彻底删除影视、书籍、笔记、影评、书评、书摘、Note Plus 文档）
- WebDAV 云同步（支持上传 / 下载 / 双向同步 / 定时自动同步）
- 本地备份与恢复（zip 归档，支持手动导出 / 导入）
- 定时自动备份（本地备份，可配置开关，保留最近 5 个）
- 暗色 / 亮色 / 跟随系统主题切换
- 6 套配色方案 + Android 12+ Monet 动态取色
- 4 款内置中文字体（霞鹜文楷、OPPO Sans、思源宋体、得意黑）
- Material 3 极简主义设计风格
- 自定义应用图标（3 款可选）
- 版本更新检查与通知
- 匿名使用统计（可选）
- 中英双语支持

## 技术栈

| 类别       | 技术                                   |
| ---------- | -------------------------------------- |
| 框架       | Flutter 3.5+（Dart 3.5+）              |
| 语言       | Dart                                   |
| 状态管理   | Provider（ChangeNotifier）             |
| 本地数据库 | SQLite（sqflite）                      |
| 图表       | fl_chart                               |
| 富文本     | flutter_quill（Note Plus）             |
| Markdown   | flutter_markdown_plus                  |
| WebView    | webview_flutter / flutter_inappwebview |
| 本地存储   | shared_preferences                     |
| 后端       | Python Flask + Waitress                |

## 项目结构

```
lib/
├── main.dart                      # 应用入口，初始化与后台任务
├── models/
│   ├── data_models.dart           # 数据模型（Movie, Book, Note, Review, Poster, Excerpt）
│   └── note_plus_models.dart      # Note Plus 模型（Block, Document）
├── providers/
│   ├── app_provider.dart          # 全局状态管理（Provider）
│   └── note_plus_provider.dart    # Note Plus 文档状态
├── pages/
│   ├── home_page.dart             # 首页（PageView 切换主内容 / 个人中心）
│   ├── main_content_page.dart     # 主内容页（影视/书籍/笔记/Note Plus 标签页）
│   ├── profile_page.dart          # 个人中心与设置
│   ├── statistics_page.dart       # 数据统计与图表
│   ├── recycle_bin_page.dart      # 回收站
│   ├── tag_management_page.dart   # 标签管理
│   ├── encounter_page.dart        # 与你相遇（使用统计）
│   ├── stroll_page.dart           # 随机漫步
│   ├── media_calendar_page.dart   # 媒体日历
│   ├── person_list_page.dart      # 人物列表
│   ├── changelog_page.dart        # 更新日志
│   ├── legal_page.dart            # 法律信息与开源许可
│   ├── app_icon_picker_page.dart  # 应用图标选择
│   ├── movies/                    # 影视相关页面（列表、表单、详情、影评、海报、分享、豆瓣导入）
│   ├── book/                      # 书籍相关页面（列表、表单、详情、书评、书摘、分享）
│   ├── note/                      # 笔记相关页面（列表、表单、详情、分享）
│   ├── note_plus/                 # Note Plus 块级编辑器页面
│   ├── epub_reader/               # Epub 阅读器（渲染、目录、控制面板、脚注、图片查看、书架）
│   ├── markdown_reader/           # Markdown 文件浏览与查看
│   ├── online_search/             # 在线搜索影视书籍
│   └── sync/                      # 同步与备份页面（云同步、WebDAV、本地备份）
├── utils/
│   ├── database_helper.dart       # SQLite 数据库管理（版本 26，含迁移链）
│   ├── app_router.dart            # 路由生成器（SlideUpPageRoute 过渡动画）
│   ├── slide_up_page_route.dart   # 底部滑入页面路由
│   ├── user_prefs.dart            # 用户偏好设置（SharedPreferences 封装）
│   ├── server_config.dart         # 服务端地址配置
│   ├── image_path_helper.dart     # 图片路径管理
│   ├── color_converter.dart       # 颜色值转换
│   ├── toast_util.dart            # Toast/SnackBar 工具
│   ├── app_icon_channel.dart      # 应用图标切换平台通道
│   ├── changelog_service.dart     # 版本更新检查
│   ├── usage_stats_service.dart   # 匿名使用统计服务
│   ├── movie/                     # 影视 DAO（CRUD + 分页 + 搜索 + 回收站）
│   ├── book/                      # 书籍 DAO（CRUD + 分页 + 搜索 + 回收站）
│   ├── note/                      # 笔记 DAO（CRUD + 分页 + 搜索 + 回收站 + 置顶）
│   ├── note_plus/                 # Note Plus DAO（文档 + 块管理 + 回收站）
│   ├── tag/                       # 标签 DAO（CRUD + 隐藏 + 合并 + 级联重命名/删除）
│   ├── epub/                      # Epub 解析、渲染、阅读设置、WebView 桥接
│   ├── sync/                      # 同步服务（WebDAV/本地备份/自动备份）
│   └── theme/                     # 主题配置（6 套配色 + Monet + 暗色/亮色 + Material 3）
└── widgets/                       # 通用组件
    ├── bottom_nav_bar.dart        # 底部导航栏（Dock 悬浮设计）
    ├── custom_drawer.dart         # 侧边抽屉导航
    ├── animated_star_rating.dart  # 星级评分动画
    ├── movie_list_item.dart       # 影视列表项
    ├── book_list_item.dart        # 书籍列表项
    ├── note_list_item.dart        # 笔记列表项
    ├── note_plus_list_item.dart   # Note Plus 列表项
    ├── movie_status_bar.dart      # 影视状态标签
    ├── book_status_bar.dart       # 书籍状态标签
    ├── fade_in_local_image.dart   # 本地图片淡入加载
    ├── shimmer_skeleton.dart     # 骨架屏加载占位
    ├── tag_side_panel.dart        # 标签筛选侧面板
    ├── text_input_panel.dart      # 文本输入面板
    ├── genre_selector_page.dart   # 类型选择器
    ├── app_refresh_indicator.dart # 下拉刷新封装
    └── note_plus/                 # Note Plus 编辑器组件（编辑器、块渲染、工具栏、斜杠菜单）

server/                            # Python Flask 后端
├── app.py                         # 服务入口（Waitress 启动，端口 27047）
├── config.py                      # 配置常量（JWT、SQLite）
├── database.py                    # 数据库初始化
├── auth.py                        # JWT 认证模块
├── admin_api.py                   # 管理 API（设备、更新日志、页面管理）
├── sync_api.py                    # 同步心跳 API
├── web_ui.py                      # Web 管理后台（Vditor + Chart.js）
├── requirements.txt               # Python 依赖
└── static/                        # 静态资源
```

## 数据存储

- **数据库位置**：`<应用文档目录>/mooknote.db`
- **图片存储位置**：`<应用文档目录>/images/<类别>/<条目ID>/<文件名>`
  - 类别：`movies` / `books` / `notes`
- **Epub 书籍位置**：`<应用文档目录>/epub_books/<条目ID>/`
- **备份文件位置**：`<下载目录>/mooknote/`（可配置）

## 环境要求

- Flutter SDK 3.5+
- Dart SDK 3.5+
- Android SDK API 21+
- Python 3.8+（服务端）

## 快速开始

```bash
# 克隆项目
git clone https://github.com/dellevin/mooknote.git
cd mooknote

# 安装依赖
flutter pub get

# 运行
flutter run
```

如果 `pub get` 失败，可尝试设置国内镜像：

```powershell
# PowerShell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get
```

或使用代理：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
flutter pub get
```

## 构建

```bash
# 构建 Release APK
flutter build apk --release
# 构建windows版本
flutter build windows --release
# 只构建 arm64-v8a
flutter build apk --release --target-platform android-arm64
# 构建 App Bundle（Google Play）
flutter build appbundle --release
```

## 服务端运行

```bash
cd server
pip install -r requirements.txt
python app.py
# 服务端默认运行在 http://127.0.0.1:27047
```

## 影视书籍资源数据对接

数据已对接 6w+ 影视基础数据，以及 300w+ 书籍基础信息，如需对接接口或技术交流请联系作者。所有影视书籍来源皆为网络资源收集，部分数据可能会有偏差，如数据有问题，也请联系开发者及时修复。

## 开源协议

本项目采用 [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) 开源协议。

## 致谢

- **[lumina](https://github.com/MilkFeng/lumina)**
- **[NLCISBNPlugin](https://github.com/DoiiarX/NLCISBNPlugin)**
