# 快速开始

## 环境要求

- **Flutter SDK** 3.5.0+
- **Android Studio**（含 Android SDK Platform API 33+）
- **Android SDK Build-Tools**
- Android 真机（USB 调试）或模拟器

## 安装步骤

### 1. 克隆项目

```bash
cd mooknote
```

### 2. 安装依赖

```bash
flutter pub get
```

如果网络问题导致失败，使用国内镜像：

```powershell
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get
```

或设置代理：

```powershell
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
flutter pub get
```

### 3. 连接设备

- 连接 Android 真机（需开启 USB 调试）
- 或启动 Android 模拟器

### 4. 运行应用

```bash
flutter run
```

## 常用命令

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建 release APK
flutter build apk --release

# 构建 App Bundle（推荐用于 Google Play）
flutter build appbundle --release

# 清理构建缓存
flutter clean

# 静态分析
flutter analyze
```

## 服务端部署（可选）

服务端用于用户统计和数据同步，位于 `server/` 目录。

```bash
cd server
pip install -r requirements.txt
python app.py
```

默认监听 `0.0.0.0:27047`，可通过环境变量 `PORT` 修改端口。

生产环境推荐 gunicorn：

```bash
pip install gunicorn
gunicorn -w 2 -b 0.0.0.0:27047 app:app
```

## 用户统计服务器配置

在 `lib/utils/usage_stats_service.dart` 中配置统计服务器地址：

```dart
static String serverUrl = 'http://192.168.31.48:5000';
```

置空则禁用用户统计功能。

[返回首页](Home.md)
