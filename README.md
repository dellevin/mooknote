# MookNote

极简风格的观影 · 阅读 · 笔记 记录应用，基于 Flutter 开发。

**开发计划：**

http://docmost.iletter.top/share/ropwljpyvn/p/mook-note-lHmPTswdDC

## 应用预览

|                    影视列表                    |                    书籍列表                    |                    笔记界面                    |
| :--------------------------------------------: | :--------------------------------------------: | :--------------------------------------------: |
| ![1782484732881](image/README/1782484732881.png) | ![1782484753882](image/README/1782484753882.png) | ![1782484769014](image/README/1782484769014.png) |

更多预览图片请到**应用功能****详情预览**里面查看

## 功能特性

### 影视管理

- 影视增删改查，支持海报、导演、演员、类型等信息录入
- 影评撰写与管理，支持星级评分
- 影视海报墙浏览（瀑布流布局）
- 影视分享（生成海报名场面风格分享卡片）
- 豆瓣链接爬取，自动填充影视信息
- 影视状态筛选（想看 / 在看 / 已看）

### 书籍管理

- 书籍增删改查，支持封面、作者、出版社等信息
- 书评撰写与管理
- 书摘 / 摘录记录
- 书籍分享卡片
- 书籍状态筛选
- Epub阅读功能

### 笔记管理

- 笔记增删改查，支持 Markdown 编辑与实时渲染
- 笔记分享卡片
- Markdown 阅读器支持暗色模式与字体大小调节

### 通用功能

- 全局搜索（影视 / 书籍 / 笔记）
- 标签管理与分类
- 数据统计与可视化图表（月度趋势 / 类型分布）
- 回收站（软删除，可恢复）
- 服务器同步与 WebDAV 云同步
- 自动备份
- 暗色 / 亮色主题切换
- 自定义应用图标
- 更新日志查看
- 用户使用统计（可选）

## 技术栈

| 类别       | 技术              |
| ---------- | ----------------- |
| 框架       | Flutter 3.5+      |
| 语言       | Dart              |
| 状态管理   | Provider          |
| 本地数据库 | SQLite（sqflite） |

## 项目结构

```
lib/
├── main.dart                  # 应用入口，初始化与后台任务
├── models/
│   └── data_models.dart       # 数据模型（Movie, Book, Note 等）
├── providers/
│   └── app_provider.dart      # 全局状态管理（Provider）
├── pages/
│   ├── movies/                # 影视相关页面
│   ├── book/                  # 书籍相关页面
│   ├── note/                  # 笔记相关页面
│   ├── markdown_reader/       # Markdown 阅读器
│   ├── sync/                  # 同步与备份页面
│   ├── home_page.dart         # 首页
│   ├── search_page.dart       # 搜索页
│   ├── statistics_page.dart   # 数据统计页
│   ├── profile_page.dart      # 个人中心
│   └── recycle_bin_page.dart  # 回收站
├── utils/
│   ├── database_helper.dart   # SQLite 数据库管理
│   ├── movie/                 # 影视 DAO
│   ├── book/                  # 书籍 DAO
│   ├── note/                  # 笔记 DAO
│   ├── tag/                   # 标签 DAO
│   ├── sync/                  # 同步服务（Server / WebDAV / 备份）
│   ├── theme/                 # 主题配置
│   └── user_prefs.dart        # 用户偏好设置
└── widgets/                   # 通用组件
```

## 数据存储

- **数据存储位置**：`/mooknote/mooknote.db`
- **图片存储位置**：`/mooknote/images/<类别>/<条目ID>/<文件名>`
  - 类别：`movie` / `book` / `note`

## 环境要求

- Flutter SDK 3.5+
- Dart SDK 3.5+
- Android SDK（API 21+）

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

如果 `pub get` 失败，可尝试设置临时变量的国内镜像：

```bash
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get
```

或者使用代理方式：

```bash
# 如果失败可以先添加代理再进行get，ip和端口号自行更改
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
flutter pub get
```

## 构建

```bash
# 构建 Release APK
flutter build apk --release

# 构建 App Bundle（Google Play）
flutter build appbundle --release
```

## 应用功能详情预览

|                    数据统计                    |                     侧边栏                     |                    我的界面                    |
| :--------------------------------------------: | :--------------------------------------------: | :--------------------------------------------: |
| ![1782484806542](image/README/1782484806542.png) | ![1782484815573](image/README/1782484815573.png) | ![1782484824223](image/README/1782484824223.png) |

|                   详情界面1                   |                   详情界面2                   |                    编辑笔记                    |
| :--------------------------------------------: | :--------------------------------------------: | :--------------------------------------------: |
| ![1782484832641](image/README/1782484832641.png) | ![1782484836809](image/README/1782484836809.png) | ![1782484844066](image/README/1782484844066.png) |

|                   分享界面1                   |                   分享界面2                   |                    预览笔记                    |
| :--------------------------------------------: | :--------------------------------------------: | :--------------------------------------------: |
| ![1782484860728](image/README/1782484860728.png) | ![1782484855884](image/README/1782484855884.png) | ![1782484849659](image/README/1782484849659.png) |

## 影视书籍资源数据对接

数据已对接6w+影视基础数据，以及300w+书籍基础信息，如需对接接口，或技术交流请联系作者。所有影视书籍来源皆为网络资源收集，部分数据可能会有偏差，如数据有问题，也请联系开发者及时修复

## 开源协议

本项目采用 [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) 开源协议。

## 致谢

**[lumina](https://github.com/MilkFeng/lumina)**

**[NLCISBNPlugin](https://github.com/DoiiarX/NLCISBNPlugin)**
