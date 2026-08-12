# MookNote

极简风格的观影 · 阅读 · 游戏 · 笔记 记录应用，基于 Flutter 开发。

软件官网：[https://mooknote.iletter.top](https://mooknote.iletter.top/)

开发记录：[http://docmost.iletter.top/share/ropwljpyvn/p/mook-note-lHmPTswdDC](http://docmost.iletter.top/share/ropwljpyvn/p/mook-note-lHmPTswdDC)

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
- Markdown 阅读器支持暗色模式与字体大小调节

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

- 全局搜索（影视 / 书籍 / 笔记 / 游戏）+ 在线搜索
- 标签管理与分类（影视类型 / 书籍类型 / 游戏类型 / 笔记标签统一管理，支持重命名 / 删除 / 隐藏）
- 数据统计与可视化图表（总览、状态分布、类型偏好、导演 / 作者 Top 5、月度活动日历、星期分布、累计增长曲线）
- 媒体日历（按日期查看影视 / 书籍添加记录，展示封面缩略图）
- 人物列表（汇总所有导演、编剧、演员、作者，关联其作品）
- 角色档案（影视 / 书籍 / 游戏角色统一管理，含人物关系与作品关联）
- 随机漫步（随机回顾影视 / 书籍 / 笔记内容）
- 与你相遇（使用天数、总记录数、字数、图片数统计）
- 回收站（软删除，支持恢复和彻底删除影视、书籍、笔记、游戏、影评、书评、书摘、游戏评测）
- WebDAV 云同步（支持上传 / 下载 / 双向同步 / 定时自动同步）
- 本地备份与恢复（zip 归档，支持手动导出 / 导入）
- 定时自动备份（本地备份，可配置开关，保留最近 5 个）
- 暗色 / 亮色 / 跟随系统主题切换
- 6 套配色方案 + Android 12+ Monet 动态取色
- Material 3 极简主义设计风格
- 自定义应用图标（3 款可选）
- 版本更新检查与通知

## 多平台支持

- **Android** — 主要支持平台
- **Windows** — 桌面端支持，笔记编辑器使用 Vditor 富文本编辑器

## 技术栈

| 层级 | 技术 |
| :--- | :--- |
| 框架 | Flutter 3.5+ / Dart 3.5+ |
| 状态管理 | Provider（单一 `AppProvider` ChangeNotifier） |
| 本地存储 | sqflite（`mooknote.db`，已迭代至 v13 迁移链） |
| 远程同步 | 自建 Flask 服务端 + WebDAV |
| 图表 | fl_chart |
| Markdown | flutter_markdown_plus（移动端）/ Vditor（桌面端） |
| Epub 渲染 | flutter_inappwebview + WebView |
| 媒体播放 | media_kit |
| 桌面适配 | window_manager |
| 动态取色 | dynamic_color（Android 12+ Monet） |

## 数据存储

- **数据库位置**：`<应用目录>/mooknote.db`
- **图片存储位置**：`<应用目录>/images/<类别>/<条目ID>/<文件名>`
  - 类别：`movies` / `books` / `notes` / `games`
- **Epub 书籍位置**：`<应用目录>/epub_books/<条目ID>/`
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
- **[viditor](https://github.com/Vanessa219/vditor)**
