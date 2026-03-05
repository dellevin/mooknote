# MookNote 快速入门指南

## 第一步：安装 Flutter 开发环境

### Windows 系统详细步骤

#### 1. 下载 Flutter SDK
访问：https://docs.flutter.dev/get-started/install/windows
- 点击 "Download Flutter SDK"
- 下载完成后解压到 `C:\src\flutter`

#### 2. 添加环境变量
```
1. 右键"此电脑" → "属性" → "高级系统设置"
2. 点击"环境变量"
3. 在"系统变量"中找到 "Path"，点击"编辑"
4. 点击"新建"，添加：C:\src\flutter\bin
5. 确定保存
```

#### 3. 验证安装

打开命令提示符（cmd）或 PowerShell：
```bash
flutter --version
flutter doctor
```

#### 4. 安装 Android Studio

- 下载地址：https://developer.android.com/studio
- 安装完成后打开 Android Studio
- 配置 Android SDK：
  - File → Settings → Appearance & Behavior → System Settings → Android SDK
  - 选择 "SDK Platforms" 标签
  - 勾选 "Android 13.0 (API 33)" 或更高版本
  - 选择 "SDK Tools" 标签
  - 勾选 "Android SDK Build-Tools" 和 "Android Emulator"
  - 点击 Apply 开始安装

#### 5. 接受 Android 许可证
```bash
flutter doctor --android-licenses
```
按提示输入 `y` 接受所有许可证

#### 6. 再次运行 flutter doctor
```bash
flutter doctor
```
确保看到类似以下输出：
```
[✓] Flutter (Channel stable, 3.x.x, on Microsoft Windows)
[✓] Android toolchain - develop for Android devices
[✓] Android Studio
[✓] Connected device
```

## 第二步：运行 MookNote 项目

### 1. 进入项目目录
```bash
cd d:\UserData\Desktop\my_proj\mooknote
```

### 2. 安装依赖包
```bash
flutter pub get
```

### 3. 准备设备
**选项 A：使用真机**
```
1. 手机开启"开发者选项"
   - 设置 → 关于手机 → 连续点击"版本号"7 次
2. 开启"USB 调试"
   - 设置 → 开发者选项 → USB 调试
3. 用 USB 连接电脑
4. 手机上允许 USB 调试授权
```

**选项 B：使用模拟器**
```
1. Android Studio → Tools → Device Manager
2. Click "Create device"
3. 选择设备型号（如 Pixel 6）
4. 下载并选择系统镜像（推荐 API 33）
5. 完成创建后点击启动按钮
```

### 4. 运行应用
```bash
flutter run
```

或者在 Android Studio 中：
- File → Open → 选择 mooknote 文件夹
- 点击顶部工具栏的运行按钮（绿色三角形）

## 第三步：理解代码结构

### 核心文件说明

#### 1. 入口文件 - `lib/main.dart`
```dart
void main() {
  runApp(const MyApp());
}
```
应用的起点，配置主题和路由

#### 2. 主页面 - `lib/pages/home_page.dart`
包含：
- 顶部 AppBar（菜单按钮 + 标题）
- 三个标签页切换（观影/阅读/笔记）
- 主体内容区域

#### 3. 状态管理 - `lib/providers/app_provider.dart`
管理全局状态：
- 当前选中的标签页
- 当前选中的状态筛选
- 侧边菜单开关

#### 4. 数据模型 - `lib/models/data_models.dart`
定义数据结构：
- `Movie` - 电影数据
- `Book` - 书籍数据
- `Note` - 笔记数据

### Widget 组件层次
```
MyApp
└── HomePage (主页面)
    ├── CustomDrawer (侧边菜单)
    │   └── 热力图组件
    ├── AppBar (顶部栏)
    ├── TabBar (标签栏)
    │   ├── 观影
    │   ├── 阅读
    │   └── 笔记
    ├── TabContent (标签内容)
    │   ├── MovieTabPage
    │   │   ├── MovieStatusBar (状态栏)
    │   │   └── MovieListItem (列表项)
    │   ├── BookTabPage
    │   │   ├── BookStatusBar (状态栏)
    │   │   └── BookListItem (列表项)
    │   └── NoteTabPage
    │       └── NoteListItem (列表项)
    └── CustomBottomNavBar (底部导航)
```

## 第四步：修改和定制

### 修改应用名称
编辑 `pubspec.yaml`:
```yaml
name: mooknote  # 包名
```

编辑 `android/app/src/main/AndroidManifest.xml`:
```xml
android:label="MookNote"  <!-- 显示名称 -->
```

### 修改主题颜色
编辑 `lib/utils/app_theme.dart`:
```dart
static const Color primaryColor = Color(0xFF6200EE);  // 主色调
```

### 添加示例数据
编辑对应的 page 文件，例如 `lib/pages/movie_tab_page.dart`:
```dart
List<Movie> _getSampleMovies(int statusIndex) {
  // 在这里添加你的电影数据
}
```

## 第五步：构建 APK

### 开发版本
```bash
flutter build apk --debug
```

### 发布版本
```bash
flutter build apk --release
```

生成的 APK 位置：
```
build/app/outputs/flutter-apk/app-release.apk
```

## 常见问题解决

### Q1: flutter pub get 失败
```bash
# 清除缓存
flutter clean
flutter pub cache repair
flutter pub get
```

### Q2: 无法识别设备
```bash
# 查看设备列表
flutter devices

# 如果没有设备，检查：
# 1. USB 线是否连接好
# 2. 手机 USB 调试是否开启
# 3. 是否安装了手机驱动
```

### Q3: 热重载不工作
按 `R` 进行热重载，按 `r` 完全重启
如果都不行，停止应用重新运行

### Q4: 中文乱码
确保所有文件使用 UTF-8 编码

## 下一步学习建议

### 1. 学习 Dart 基础语法（1-2 天）
- 变量和类型
- 函数
- 类和对象
- 异步编程（async/await）

### 2. 学习 Flutter 基础（3-5 天）
- Widget 概念
- StatelessWidget vs StatefulWidget
- 布局组件（Row, Column, Container 等）
- 列表（ListView）

### 3. 实践项目功能
- 实现添加功能表单
- 集成 SQLite 数据库
- 实现搜索功能
- 完善详情页

### 4. 参考资源
- [Dart 语言中文文档](https://dart.cn/)
- [Flutter 实战电子书](https://book.flutterchina.club/)
- [B 站 Flutter 教程](https://search.bilibili.com/all?keyword=flutter 教程)

---
祝你开发顺利！有问题随时询问。
