# MookNote

极简风格的观影 · 阅读 · 游戏 · 笔记 记录应用，基于 Flutter 开发。

软件官网：[https://mooknote.iletter.top](https://mooknote.iletter.top/)

开发记录：[http://docmost.iletter.top/share/ropwljvn/p/mook-note-lHmPTswdDC](http://docmost.iletter.top/share/ropwljvn/p/mook-note-lHmPTswdDC)

## 应用预览

|                  主界面                 |                  我的界面                  |                  侧边栏                  |
| :-----------------------------------------: | :-----------------------------------------: | :-----------------------------------------: |
| ![影视列表](image/README/主界面.png) | ![书籍列表](image/README/我的界面.png) | ![笔记界面](image/README/侧边栏.png) |




## 功能特性

### 影视管理

- 影视增删改查，支持海报、导演、演员、类型等信息录入
- 影视分类：电影 / 电视剧 / 动漫 / 综艺 / 纪录片 / 短片
- 影评撰写与管理，支持短评与长评，星级评分
- 影视海报墙浏览（瀑布流布局），支持多张海报管理与全屏浏览
- 影视分享（生成海报名场面风格分享卡片）
- 豆瓣网页抓取，自动填充影视信息
- 影视状态筛选（想看 / 在看 / 已看）
- 多种排序方式（更新时间 / 创建时间 / 评分）
- 多种列表布局（海报网格 / 列表 / 大图卡片）
- 在线搜索影视资源（服务端代理，支持分页，详情页可播放预告片）

### 书籍管理

- 书籍增删改查，支持封面、作者、出版社、ISBN 等信息
- 书评撰写与管理，支持短评与长评
- 书摘 / 摘录记录（按章节管理，支持批注）
- 书籍分享卡片
- 书籍状态筛选（想读 / 在读 / 已读）
- 多种排序方式（更新时间 / 创建时间 / 评分）
- 多种列表布局（封面网格 / 列表）
- 在线搜索书籍资源

### 游戏管理

- 游戏增删改查，支持封面、平台、版本、类型、购入价格等信息录入
- 游戏分类：数字版 / 实体版 / 订阅制
- 游戏评测撰写与管理，支持截图上传与展示
- 游戏截图画廊浏览
- 游戏分享卡片
- 游戏状态筛选（想玩 / 在玩 / 已通关 / 弃坑）
- 多种排序方式（更新时间 / 创建时间 / 评分）
- 游玩时长记录

### 笔记管理

- 笔记增删改查，支持 Markdown 编辑与实时渲染
- 笔记置顶功能
- 多种列表布局：列表 / 瀑布流 / 时间线
- 多种排序方式（更新时间 / 创建时间 / 标题）
- 笔记分享卡片

### 收藏单

- 跨媒体收藏单（影视 / 书籍 / 游戏），条目自由编组
- 收藏单创建、排序与封面自动聚合
- 收藏单内条目管理

### 通用功能

- 全局搜索（影视 / 书籍 / 笔记 / 游戏）+ 在线搜索
- 快速记录（悬浮入口，一键添加各类媒体）
- 标签管理与分类（影视类型 / 书籍类型 / 游戏类型 / 笔记标签统一管理，支持重命名 / 删除 / 隐藏）
- 数据统计与可视化图表（总览、状态分布、类型偏好、导演 / 作者 Top 5、月度活动日历、星期分布、累计增长曲线）
- 媒体日历（按日期查看影视 / 书籍添加记录，展示封面缩略图）
- 图片画廊（全应用图片 / 海报 / 截图统一浏览）
- 人物列表（汇总所有导演、编剧、演员、作者，关联其作品）
- 角色档案（影视 / 书籍 / 游戏角色统一管理，含人物关系与作品关联）
- 想看清单（汇总所有标记为「想看 / 想读 / 想玩」的条目）
- 随机漫步（随机回顾影视 / 书籍 / 笔记内容）
- 与你相遇（使用天数、总记录数、字数、图片数统计）
- 回收站（软删除，支持恢复和彻底删除影视、书籍、笔记、游戏、影评、书评、书摘、游戏评测）
- WebDAV 云同步（支持上传 / 下载 / 双向同步 / 定时自动同步）
- 本地备份与恢复（zip 归档，支持手动导出 / 导入，支持 Excel 导出）
- 定时自动备份（本地备份，可配置开关，保留最近 5 个）
- 暗色 / 亮色 / 跟随系统主题切换
- 6 套配色方案 + Android 12+ Monet 动态取色
- Material 3 极简主义设计风格
- 中英双语切换（英文资源缺失时自动回退中文）
- 自定义应用图标
- 字体与排版自定义
- 版本更新检查与通知
- 四个主标签（影视 / 阅读 / 游戏 / 笔记）均可在功能设置中独立显隐

## 多平台支持

- **Android** — 主要支持平台
- **Windows** — 桌面端完整支持：隐藏原生标题栏、FFI 本地数据库、宽屏主从布局适配

## 技术栈

| 层级 | 技术 |
| :--- | :--- |
| 框架 | Flutter 3.5+ / Dart 3.5+ |
| 状态管理 | Provider（单一 `AppProvider` ChangeNotifier） |
| 本地存储 | sqflite（`mooknote.db`，已迭代至 v42 迁移链；Windows 端走 sqflite_common_ffi） |
| 远程同步 | 自建 Flask 服务端 + WebDAV |
| 图表 | fl_chart |
| Markdown | flutter_markdown_plus |
| WebView | flutter_inappwebview（豆瓣网页抓取） |
| 视频播放 | media_kit（预告片播放） |
| 数据导出 | excel / archive（Excel 与 zip 备份） |
| 桌面适配 | window_manager |
| 动态取色 | dynamic_color（Android 12+ Monet） |
| 国际化 | 轻量自建 i18n（中文为 key，中英双语） |

## 项目结构

```
lib/
├── main.dart                # 入口：初始化、主题、桌面端配置
├── models/                  # 数据模型（data_models.dart，~21 个类）
├── providers/               # AppProvider（全局状态）
├── data/                    # DAO 层（按实体分目录）+ SQLite
├── pages/                   # 页面（影视/书籍/游戏/笔记/人物/角色/
│                            #   收藏单/探索统计/在线搜索/同步设置等）
├── services/                # 服务（同步、备份、WebDAV、更新检查等）
├── widgets/                 # 共享组件（列表项、编辑器、导航、抽屉等）
├── utils/                   # 工具（路由、主题、偏好、Excel 导出等）
└── l10n/                    # 英文文案资源
server/                      # Python Flask 服务端（认证 / 同步 / 管理 API）
```

## 数据存储

- **数据库位置**：`<应用目录>/mooknote.db`
- **图片存储位置**：`<应用目录>/images/<类别>/<条目ID>/<文件名>`
  - 类别：`movies` / `books` / `notes` / `games`
- **备份文件位置**：`<下载目录>/mooknote/`（可配置）

## 环境要求

- Flutter SDK 3.5+
- Dart SDK 3.5+
- Android minSdk 21+（Android 端）
- Python 3.8+（服务端）

## 快速开始

```bash
# 克隆项目
git clone https://github.com/dellevin/mooknote.git
cd mooknote

# 安装依赖
flutter pub get

flutter devices
# 运行
flutter run -d emulator-5554

flutter run -d  windows
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
# 构建 Windows 版本
flutter build windows --release
# 只构建 arm64-v8a
flutter build apk --release --target-platform android-arm64
# 构建 App Bundle（Google Play）
flutter build appbundle --release
```


## 影视书籍资源数据对接

数据已对接 6w+ 影视基础数据，以及 300w+ 书籍基础信息，如需对接接口或技术交流请联系作者。所有影视书籍来源皆为网络资源收集，部分数据可能会有偏差，如数据有问题，也请联系开发者及时修复。

## 开源协议

本项目采用 [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) 开源协议。

## 致谢

- **[lumina](https://github.com/MilkFeng/lumina)**
- **[NLCISBNPlugin](https://github.com/DoiiarX/NLCISBNPlugin)**
