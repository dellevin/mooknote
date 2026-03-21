# MookNote - 极简风格的观影阅读笔记应用

## 项目简介
MookNote 是一款用于记录观影、阅读和笔记的 Android 软件，基于 Flutter 框架开发。

## 功能
- 影视增删改查
- 书籍增删改查
- 笔记增删改查
- 影评增删改查
- 书评增删改


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

## 运行项目

### 1. 克隆/复制项目后，进入项目目录
```bash
cd mooknote
```

### 2. 安装依赖

```bash
flutter clean 
flutter pub get
# 如果失败可以先添加代理再进行get
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
flutter pub get
# 运行
flutter run
# 构建 APK
flutter build apk --release
# 或构建 App Bundle（推荐用于 Google Play）
flutter build appbundle --release

# 使用国内镜像构建运行
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get
flutter run
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

## 技术栈

- **Flutter**: 跨平台移动应用框架
- **Dart**: 编程语言
- **Provider**: 状态管理



**5. 图片文件存储路径：**

- 数据库：`/mooknote/mooknote.db`
- 图片：`/mooknote/images/图片文件名`

**注意：**

- 目前图片同步是基于文件存在性判断，不是基于修改时间
- 下载新数据库后，应用会自动重新加载数据（调用 Provider 的 load 方法）
- 首次同步会创建远程目录结构

## 开源协议

本项目采用 [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) 开源协议。
