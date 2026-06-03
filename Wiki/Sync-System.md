# 同步系统

MookNote 支持三种数据同步方式。

## 1. 服务端实时同步

通过激活码连接远程服务器，数据实时双向同步。

### 核心服务

#### ServerDataService (`lib/utils/sync/server_data_service.dart`)

远程 API 数据操作层，所有方法通过 HTTP POST 调用服务端接口：

```dart
// 影视
getMovies({status, limit, offset})  → POST /api/data/movies
saveMovie(movie)                    → POST /api/data/movie/save
deleteMovie(id)                     → POST /api/data/movie/delete

// 书籍、笔记、影评、海报、书评、摘抄、标签同理
```

每个请求都附带 `code`（激活码）进行身份验证。

#### ServerSyncService (`lib/utils/sync/server_sync_service.dart`)

同步协调服务：

- `checkActivation()` — 校验激活码有效性
- `syncWithServer()` — 智能合并本地与服务端数据
- `downloadToLocal()` — 从服务端下载数据到本地（关闭同步时调用）

### 启动时校验流程

```
1. 检查 syncEnabled、syncServerUrl、syncActivationCode 是否已配置
2. 调用 /api/activate 校验激活码
3. 有效 → 更新有效期信息，继续同步模式
4. 无效/过期 → 调用 downloadToLocal() 下载数据 → 关闭同步开关
```

### 双模式切换

`AppProvider._useRemote` 控制：

```dart
bool get _useRemote {
  return prefs.syncEnabled &&
      prefs.syncServerUrl.isNotEmpty &&
      prefs.syncActivationCode.isNotEmpty &&
      ServerDataService.instance.isAvailable;
}
```

## 2. WebDAV 同步

通过 WebDAV 协议同步数据库文件和图片。

相关页面：`lib/pages/sync/webdav_sync_page.dart`
服务类：`lib/utils/sync/webdav_service.dart`

## 3. 自动本地备份

### AutoBackupService (`lib/utils/sync/auto_backup_service.dart`)

定时自动备份到设备下载目录：

- **间隔**：5 分钟
- **保留数量**：最近 5 个备份文件
- **备份目录**：`Download/mooknote/`（Android）或 `Documents/mooknote/`（iOS）
- **文件格式**：`auto_backup_{yyyyMMdd_HHmmss}.zip`

### BackupService (`lib/utils/sync/backup_service.dart`)

手动备份与恢复服务，导出数据为 ZIP 文件（包含数据库和图片）。

相关页面：`lib/pages/sync/backup_page.dart`

## 同步相关配置

在 `UserPrefs` 中：

| 键 | 说明 |
|----|------|
| `syncServerUrl` | 服务器地址 |
| `syncActivationCode` | 激活码 |
| `syncExpiresAt` | 激活码有效期 |
| `syncIsPermanent` | 是否永久有效 |
| `syncEnabled` | 同步开关 |
| `syncLastEntryId` | 上次同步的 entry ID |

[返回首页](Home.md)
