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

## 运行项目

### 1. 克隆/复制项目后，进入项目目录
```bash
cd mooknote
```

### 2. 安装依赖

```bash
flutter pub get
# 如果失败可以先添加代理再进行get
$env:HTTP_PROXY="http://127.0.0.1:10808"
$env:HTTPS_PROXY="http://127.0.0.1:10808"
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
- **Material Design 3**: UI 设计规范

## 后续开发计划

### 数据存储

- [x] 集成 SQLite 数据库（sqflite 包）
- [x] 实现本地数据持久化
- [x] 数据备份与恢复

### 功能增强

- [x] 添加/编辑表单页面
- [x] 详情页完整实现
- [x] 搜索功能
- [x] 统计图表页面
- [x] 回收站功能

### 高级功能

- [x] 导出功能（JSON）
- [ ] 云同步

## 双向同步规则

双向同步的规则如下：

**1. 数据库文件同步规则：**

| 情况              | 操作                     |
| :---------------- | :----------------------- |
| 远程数据库不存在  | 上传本地数据库           |
| 本地较新（>10秒） | 上传本地数据库           |
| 远程较新（>10秒） | 下载远程数据库           |
| 时间相近（±10秒） | 不传输数据库，仅同步图片 |

**2. 图片同步规则：**

| 情况             | 操作                                   |
| :--------------- | :------------------------------------- |
| 本地有，远程没有 | 上传到远程                             |
| 远程有，本地没有 | 下载到本地                             |
| 两边都有         | 不处理（暂不支持基于时间戳的图片同步） |

**3. 同步方向选项：**

- **双向同步** - 按上述规则自动判断上传/下载
- **仅上传** - 只上传本地数据库和所有本地图片
- **仅下载** - 只下载远程数据库和所有远程图片

**4. 时间戳比较：**

```dart
// 10秒误差范围内视为相同 
if (timeDiff > 10) {  
    // 本地较新，上传 
} else if (timeDiff < -10) 
{  
    // 远程较新，下载 
} else 
{  
    // 时间相近，仅同步图片 
}
```

**5. 文件路径：**

- 数据库：`/mooknote/mooknote.db`
- 图片：`/mooknote/images/图片文件名`

**注意：**

- 目前图片同步是基于文件存在性判断，不是基于修改时间
- 下载新数据库后，应用会自动重新加载数据（调用 Provider 的 load 方法）
- 首次同步会创建远程目录结构
