# MookNote

极简风格的观影 · 阅读 · 游戏 · 笔记 记录应用，基于 Flutter 开发。

软件官网：[https://mooknote.iletter.top](https://mooknote.iletter.top/)

## 应用预览

PS：软件界面已经经历了多版本更新，当前界面仅供参考，一切以最新版为准。

|                主界面                |                我的界面                |                侧边栏                |
| :----------------------------------: | :------------------------------------: | :----------------------------------: |
| ![影视列表](image/README/主界面.png) | ![书籍列表](image/README/我的界面.png) | ![笔记界面](image/README/侧边栏.png) |

## 功能特性

- **四大媒体记录**：影视、书籍、游戏、笔记统一管理，支持评分、评论/书评/评测、状态标记、多种列表布局与排序，条目可一键生成分享卡片。
- **在线数据源**：统一搜索入口，对接豆瓣、TMDB、Bangumi、Steam 及自建影视/书籍资源服务，搜索后自动填充条目信息；支持 Bangumi 人物收藏与作品关联，影视详情页可在线播放。
- **扩展体系**：跨媒体片单、自定义分类模块（表单设计器）、人物与角色档案、标签中心、想看清单。
- **回顾与洞察**：数据统计图表、已阅年度回顾、媒体日历、碎阅时间线（可生成海报分享）、图片画廊、随机漫步、使用历程（与你相遇）。
- **数据安全**：本地 SQLite 存储，支持 WebDAV 全量/增量双向同步与定时自动备份，本地 zip 备份恢复、Excel 导出、回收站软删除。
- **个性化**：Material 3 设计，多套配色与 Android 12+ Monet 动态取色、暗色模式、毛玻璃主题、多套详情页样式、自定义图标与字体，中英双语。

## 多平台支持

- **Android** — 主要支持平台，含平板自适应布局（常驻侧边栏 + 宽屏列表-详情并排）
- **Windows** — 桌面端支持（[github.com/dellevin/mooknote_windows](https://github.com/dellevin/mooknote_windows)）

## 技术栈

| 层级     | 技术                                                  |
| :------- | :---------------------------------------------------- |
| 框架     | Flutter 3.5+ / Dart 3.5+                              |
| 状态管理 | Provider（单一`AppProvider` ChangeNotifier）        |
| 本地存储 | sqflite（DAO 分层 + 版本迁移链）                      |
| 远程同步 | 自建 Flask 服务端 + WebDAV（全量 / LWW 增量双向同步） |
| 图表     | fl_chart                                              |
| Markdown | flutter_markdown_plus                                 |
| WebView  | flutter_inappwebview（网页抓取）                      |
| 视频播放 | media_kit                                             |
| 数据导出 | excel / archive（Excel 与 zip 备份）                  |
| 动态取色 | dynamic_color（Android 12+ Monet）                    |
| 国际化   | 轻量自建 i18n（中文为 key，中英双语）                 |

## 项目结构

```
lib/
├── main.dart          # 入口：初始化、主题、Monet 动态取色、媒体播放器
├── models/            # 数据模型
├── providers/         # AppProvider 全局状态
├── data/              # DAO 层 + SQLite 数据库
├── pages/             # 各功能页面
├── services/          # 同步、备份、WebDAV、数据源解析等服务
├── widgets/           # 共享组件
├── utils/             # 主题、路由、偏好、工具类
└── l10n/              # 英文文案资源
server/                # Python Flask 服务端（同步 / 管理 API，可选）
```

## 快速开始

```bash
git clone https://github.com/dellevin/mooknote.git
cd mooknote
flutter pub get
flutter run
```

如果 `pub get` 失败，可设置国内镜像：

```powershell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get
```

## 构建

```bash
flutter build apk --release                    # 通用 Release APK
flutter build apk --release --split-per-abi    # 多版本构建
flutter build appbundle --release              # Google Play App Bundle
```

环境要求：Flutter / Dart SDK 3.5+，Android minSdk 21+。

## 影视书籍资源数据对接

数据已对接 7w+ 影视基础数据，以及 300w+ 书籍基础信息（书葵网），如需对接接口或技术交流请联系作者。所有影视书籍来源皆为网络资源收集，部分数据可能会有偏差，如数据有问题，也请联系开发者及时修复。

## 开源协议

本项目采用 [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) 开源协议。

## 致谢

- **[lumina](https://github.com/MilkFeng/lumina)**
- **[NLCISBNPlugin](https://github.com/DoiiarX/NLCISBNPlugin)**
