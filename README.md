# MookNote - Flutter 观影阅读笔记应用

## 项目简介
MookNote 是一款用于记录观影、阅读和笔记的 Android 应用，使用 Flutter 框架开发。

## 功能特性

### 主界面
- **顶部导航栏**: 左侧菜单按钮 + 标题 + 搜索按钮
- **三个标签页**: 观影、阅读、笔记
- **底部导航栏**: 主页、新增、我的

### 观影模块
- 三个状态筛选：已看、想看、在看
- 显示影片标题、年份、评分、观看日期、笔记
- 支持添加和管理观影记录

### 阅读模块
- 三个状态筛选：读完、在读、准备读
- 显示书籍标题、作者、评分、阅读日期、笔记
- 支持添加和管理书籍记录

### 笔记模块
- 显示所有笔记列表
- 支持标签分类
- 显示笔记内容和更新时间

### 侧边菜单
- GitHub 风格热力图（年度记录可视化）
- 统计功能入口
- 回收站入口
- 设置入口

## 环境要求

### 必需软件
1. **Flutter SDK** (建议 3.5.0+)
   - 下载地址：https://docs.flutter.dev/get-started/install
   
2. **Android Studio**
   - 下载地址：https://developer.android.com/studio
   
3. **Android SDK** (通过 Android Studio 安装)

### 环境配置步骤

#### Windows 系统

1. **下载并安装 Flutter SDK**
   ```
   - 下载 Flutter SDK zip 文件
   - 解压到 C:\src\flutter（或其他非系统目录）
   - 将 C:\src\flutter\bin 添加到系统环境变量 Path
   ```

2. **验证 Flutter 安装**
   ```bash
   flutter --version
   flutter doctor
   ```

3. **安装 Android Studio**
   ```
   - 下载并安装 Android Studio
   - 打开 Android Studio → Settings → Appearance & Behavior → System Settings → Android SDK
   - 安装 Android SDK Platform（建议 API 33+）
   - 安装 Android SDK Build-Tools
   - 安装 Android Emulator（可选，用于模拟器测试）
   ```

4. **接受 Android 许可证**
   
   ```bash
   flutter doctor --android-licenses
   ```



```bash
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
flutter create --platforms android .
```





## 运行项目

### 1. 克隆/复制项目后，进入项目目录
```bash
cd mooknote
```

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 连接设备或启动模拟器
- 连接 Android 真机（需开启 USB 调试）
- 或启动 Android 模拟器

### 4. 运行应用
```bash
flutter run
```

或使用 Android Studio:
- 打开项目
- 点击运行按钮 (Run)

## 项目结构

```
mooknote/
├── android/                    # Android 平台配置
│   └── app/
│       └── src/main/
│           ├── AndroidManifest.xml
│           └── ...
├── lib/                        # Dart 源代码
│   ├── main.dart               # 应用入口
│   ├── pages/                  # 页面组件
│   │   ├── home_page.dart      # 主页面
│   │   ├── movie_tab_page.dart # 观影标签页
│   │   ├── book_tab_page.dart  # 阅读标签页
│   │   └── note_tab_page.dart  # 笔记标签页
│   ├── widgets/                # 可复用组件
│   │   ├── custom_drawer.dart      # 侧边菜单
│   │   ├── bottom_nav_bar.dart     # 底部导航
│   │   ├── movie_status_bar.dart   # 观影状态栏
│   │   ├── movie_list_item.dart    # 观影列表项
│   │   ├── book_status_bar.dart    # 书籍状态栏
│   │   ├── book_list_item.dart     # 书籍列表项
│   │   └── note_list_item.dart     # 笔记列表项
│   ├── models/                 # 数据模型
│   │   └── data_models.dart    # Movie, Book, Note 模型
│   ├── providers/              # 状态管理
│   │   └── app_provider.dart   # 全局状态管理
│   └── utils/                  # 工具类
│       └── app_theme.dart      # 主题配置
├── assets/                     # 资源文件
│   └── images/                 # 图片资源
├── fonts/                      # 字体文件
├── pubspec.yaml                # 项目配置文件
└── README.md                   # 本文件
```

## 技术栈

- **Flutter**: 跨平台移动应用框架
- **Dart**: 编程语言
- **Provider**: 状态管理
- **Material Design 3**: UI 设计规范

## 后续开发计划

### 数据存储

- [x] 集成 SQLite 数据库（sqflite 包）
- [x] 实现本地数据持久化
- [ ] 数据备份与恢复

### 功能增强

- [x] 添加/编辑表单页面
- [ ] 详情页完整实现
- [ ] 搜索功能
- [ ] 统计图表页面
- [ ] 回收站功能
- [ ] 设置页面

### 用户体验
- [ ] 加载动画
- [ ] 下拉刷新
- [ ] 无限滚动加载
- [ ] 深色模式优化

### 高级功能

- [ ] 导出功能（JSON/CSV）
- [ ] 云同步
- [ ] 桌面小组件

## 常见问题

### Q: flutter doctor 显示 Android license status unknown
A: 运行 `flutter doctor --android-licenses` 接受许可证

### Q: 模拟器无法启动
A: 确保在 BIOS 中启用了虚拟化技术（VT-x/AMD-V）

### Q: 热重载不生效
A: 某些代码更改需要完全重启应用（如 main() 函数修改）

## 开发建议

### 对于有 Vue 经验的你
Flutter 的很多概念与 Vue 相似：
- **Widget** ≈ Vue 组件
- **StatefulWidget** ≈ 带数据的 Vue 组件
- **setState()** ≈ this.$forceUpdate() + 数据更新
- **Provider** ≈ Vuex/Pinia
- **pubspec.yaml** ≈ package.json

### 学习资源
- [Flutter 官方文档](https://docs.flutter.dev/)
- [Dart 语言指南](https://dart.dev/guides)
- [Flutter 中文社区](https://flutterchina.club/)

## 许可证
MIT License

---
**作者**: 你的昵称  
**创建时间**: 2024-03-04
