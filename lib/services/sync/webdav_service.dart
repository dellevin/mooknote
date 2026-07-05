import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'backup_service.dart';

/// WebDAV 同步结果
class SyncResult {
  final bool success;
  final String message;
  final DateTime? lastSyncTime;
  final int uploadedFiles;
  final int downloadedFiles;
  final int uploadedImages;
  final int downloadedImages;
  final bool needReload;

  SyncResult({
    required this.success,
    required this.message,
    this.lastSyncTime,
    this.uploadedFiles = 0,
    this.downloadedFiles = 0,
    this.uploadedImages = 0,
    this.downloadedImages = 0,
    this.needReload = false,
  });
}

/// 同步方向
enum SyncDirection {
  upload,    // 仅上传
  download,  // 仅下载
  bidirectional, // 双向同步
}

/// WebDAV 服务类 - 完整备份 zip 同步
class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  static WebDAVService get instance => _instance;

  WebDAVService._internal();

  static const String _configKey = 'webdav_config';
  static const String _lastSyncKey = 'webdav_last_sync';
  static const String _autoSyncKey = 'webdav_auto_sync';
  static const String _autoSyncIntervalKey = 'webdav_auto_sync_interval';

  // 默认自动同步间隔（分钟）
  static const int _defaultAutoSyncInterval = 5;

  Map<String, String>? _cachedConfig;
  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = false;
  int _autoSyncIntervalMinutes = _defaultAutoSyncInterval;
  bool _isSyncing = false;

  /// 获取配置
  Future<Map<String, String>?> getConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig;
    }

    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString(_configKey);
    if (configJson != null) {
      try {
        final config = Map<String, String>.from(jsonDecode(configJson));
        _cachedConfig = config;
        return config;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 保存配置
  Future<void> saveConfig({
    required String url,
    required String username,
    required String password,
    required String path,
  }) async {
    final config = {
      'url': url,
      'username': username,
      'password': password,
      'path': path,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config));
    _cachedConfig = config;
  }

  /// 清除配置
  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_autoSyncKey);
    await prefs.remove(_autoSyncIntervalKey);
    _cachedConfig = null;
    stopAutoSync();
  }

  /// 测试连接
  Future<Map<String, dynamic>> testConnection({
    required String url,
    required String username,
    required String password,
    required String path,
  }) async {
    try {
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      var davUrl = '$baseUrl$path';

      final client = http.Client();
      try {
        var propfindRequest = http.Request('PROPFIND', Uri.parse(davUrl));
        propfindRequest.headers['Authorization'] = _basicAuth(username, password);
        propfindRequest.headers['Depth'] = '0';
        propfindRequest.body = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:resourcetype/>
  </D:prop>
</D:propfind>''';

        var propfindResponse = await client.send(propfindRequest);

        if (propfindResponse.statusCode == 301 ||
            propfindResponse.statusCode == 302 ||
            propfindResponse.statusCode == 307 ||
            propfindResponse.statusCode == 308) {
          final location = propfindResponse.headers['location'];
          if (location != null) {
            davUrl = location;
            propfindRequest = http.Request('PROPFIND', Uri.parse(davUrl));
            propfindRequest.headers['Authorization'] = _basicAuth(username, password);
            propfindRequest.headers['Depth'] = '0';
            propfindRequest.body = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:resourcetype/>
  </D:prop>
</D:propfind>''';
            propfindResponse = await client.send(propfindRequest);
          }
        }

        if (propfindResponse.statusCode == 207) {
          return {'success': true, 'message': '连接成功'};
        } else if (propfindResponse.statusCode == 401) {
          return {'success': false, 'message': '认证失败，请检查用户名和密码'};
        } else if (propfindResponse.statusCode == 404) {
          // 目录不存在，尝试创建
        } else {
          return {'success': false, 'message': '服务器返回错误: ${propfindResponse.statusCode}'};
        }
      } catch (e) {
        // ignore
      }

      try {
        final mkcolRequest = http.Request('MKCOL', Uri.parse(davUrl));
        mkcolRequest.headers['Authorization'] = _basicAuth(username, password);

        final mkcolResponse = await client.send(mkcolRequest);

        if (mkcolResponse.statusCode == 201) {
          return {'success': true, 'message': '连接成功，已创建目录'};
        } else if (mkcolResponse.statusCode == 405) {
          return {'success': true, 'message': '连接成功，目录已存在'};
        } else if (mkcolResponse.statusCode == 401) {
          return {'success': false, 'message': '认证失败，请检查用户名和密码'};
        } else if (mkcolResponse.statusCode == 409) {
          return {'success': false, 'message': '父目录不存在，请检查路径'};
        } else {
          return {'success': false, 'message': '创建目录失败: ${mkcolResponse.statusCode}'};
        }
      } catch (e) {
        return {'success': false, 'message': '连接失败: $e'};
      } finally {
        client.close();
      }
    } catch (e) {
      return {'success': false, 'message': '连接失败: $e'};
    }
  }

  /// 同步数据 — 完整备份 zip 格式，与本地备份完全一致
  Future<SyncResult> syncData({SyncDirection direction = SyncDirection.bidirectional}) async {
    // 防止并发同步
    if (_isSyncing) {
      return SyncResult(success: false, message: '同步正在进行中，请稍后再试');
    }
    _isSyncing = true;

    final config = await getConfig();
    if (config == null) {
      _isSyncing = false;
      return SyncResult(success: false, message: '未配置 WebDAV');
    }

    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final path = config['path']!;

      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final zipUrl = '$baseUrl$path/mooknote_backup.zip';

      final client = http.Client();
      int uploadedFiles = 0;
      int downloadedFiles = 0;
      int uploadedImages = 0;
      int downloadedImages = 0;
      bool needReload = false;

      try {
        if (direction == SyncDirection.upload) {
          final exportResult = await BackupService.instance.exportDataForAutoBackup();
          if (!exportResult.success || exportResult.zipBytes == null) {
            return SyncResult(success: false, message: exportResult.errorMessage ?? '创建备份失败');
          }

          final success = await _uploadBytes(client, zipUrl, username, password, exportResult.zipBytes!);
          if (success) {
            uploadedFiles = 1;
            uploadedImages = exportResult.imageCount;
            debugPrint('[WebDAV] 备份上传成功 (影视${exportResult.movieCount} 书籍${exportResult.bookCount} 笔记${exportResult.noteCount} 图片${exportResult.imageCount})');
          } else {
            return SyncResult(success: false, message: '上传备份文件失败');
          }

        } else if (direction == SyncDirection.download) {
          final tempDir = await getTemporaryDirectory();
          final tempZip = File(p.join(tempDir.path, 'mooknote_download.zip'));
          final success = await _downloadFile(client, zipUrl, username, password, tempZip);

          if (success && await tempZip.exists()) {
            final bytes = await tempZip.readAsBytes();
            final importResult = await BackupService.instance.restoreFromZipBytes(bytes);
            await tempZip.delete();

            if (importResult.success) {
              downloadedFiles = 1;
              downloadedImages = importResult.stats?['图片'] ?? 0;
              needReload = true;
              debugPrint('[WebDAV] 备份恢复成功: ${importResult.statsText}');
            } else {
              return SyncResult(success: false, message: importResult.errorMessage ?? '恢复备份失败');
            }
          } else {
            return SyncResult(success: false, message: '服务器上没有备份文件，请先从其他设备上传');
          }

        } else if (direction == SyncDirection.bidirectional) {
          // 获取远程备份的修改时间
          final remoteModTime = await _getRemoteFileModifiedTime(client, zipUrl, username, password);

          // 获取上次同步时间
          final syncPrefs = await SharedPreferences.getInstance();
          final lastSyncStr = syncPrefs.getString(_lastSyncKey);
          final lastSyncTime = lastSyncStr != null ? DateTime.tryParse(lastSyncStr) : null;

          final bool remoteIsNewer = remoteModTime != null &&
              (lastSyncTime == null || remoteModTime.isAfter(lastSyncTime));

          if (remoteIsNewer) {
            // 远程更新，下载并恢复
            final tempDir = await getTemporaryDirectory();
            final tempZip = File(p.join(tempDir.path, 'mooknote_bidir.zip'));

            final downloadSuccess = await _downloadFile(client, zipUrl, username, password, tempZip);
            if (downloadSuccess && await tempZip.exists()) {
              final bytes = await tempZip.readAsBytes();
              final importResult = await BackupService.instance.restoreFromZipBytes(bytes);
              await tempZip.delete();

              if (importResult.success) {
                downloadedFiles = 1;
                downloadedImages = importResult.stats?['图片'] ?? 0;
                needReload = true;
                debugPrint('[WebDAV] 远程备份较新，已恢复: ${importResult.statsText}');
              }
            } else {
              try { await tempZip.delete(); } catch (_) {}
            }
          } else {
            debugPrint('[WebDAV] 本地数据已是最新或远程无更新，跳过下载');
          }

          // 上传本地备份（无论是否下载，确保远程有最新数据）
          final exportResult = await BackupService.instance.exportDataForAutoBackup();
          if (exportResult.success && exportResult.zipBytes != null) {
            final uploadSuccess = await _uploadBytes(client, zipUrl, username, password, exportResult.zipBytes!);
            if (uploadSuccess) {
              uploadedFiles = 1;
              uploadedImages = exportResult.imageCount;
              debugPrint('[WebDAV] 本地备份已上传 (影视${exportResult.movieCount} 书籍${exportResult.bookCount} 笔记${exportResult.noteCount} 图片${exportResult.imageCount})');
            }
          }
        }

        final prefs = await SharedPreferences.getInstance();

        // 仅在上传成功或下载成功时记录同步时间
        final bool anySuccess = uploadedFiles > 0 || downloadedFiles > 0;
        if (anySuccess) {
          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        }

        return SyncResult(
          success: anySuccess,
          message: anySuccess ? '同步完成' : '同步未完成，未传输任何数据',
          lastSyncTime: DateTime.now(),
          uploadedFiles: uploadedFiles,
          downloadedFiles: downloadedFiles,
          uploadedImages: uploadedImages,
          downloadedImages: downloadedImages,
          needReload: needReload,
        );
      } finally {
        client.close();
      }
    } catch (e) {
      return SyncResult(success: false, message: '同步失败: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// 获取自动同步间隔（分钟）
  Future<int> getAutoSyncInterval() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoSyncIntervalKey) ?? _defaultAutoSyncInterval;
  }

  /// 设置自动同步间隔（分钟）
  Future<void> setAutoSyncInterval(int minutes) async {
    if (minutes < 1) minutes = 1;
    if (minutes > 60) minutes = 60;

    _autoSyncIntervalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoSyncIntervalKey, minutes);

    if (_isAutoSyncEnabled) {
      await startAutoSync();
    }
  }

  /// 启动自动同步
  Future<void> startAutoSync() async {
    await stopAutoSync();

    final prefs = await SharedPreferences.getInstance();
    _isAutoSyncEnabled = true;
    _autoSyncIntervalMinutes = await getAutoSyncInterval();
    await prefs.setBool(_autoSyncKey, true);

    // 立即执行一次同步
    debugPrint('[WebDAV] 自动同步已启动，间隔 $_autoSyncIntervalMinutes 分钟');
    await syncData(direction: SyncDirection.bidirectional);

    // 设置定时器
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncIntervalMinutes),
      (timer) async {
        if (_isAutoSyncEnabled) {
          try {
            await syncData(direction: SyncDirection.bidirectional);
          } catch (e) {
            debugPrint('[WebDAV] 自动同步异常: $e');
          }
        }
      },
    );
  }

  /// 停止自动同步
  Future<void> stopAutoSync() async {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _isAutoSyncEnabled = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, false);
  }

  /// 检查自动同步状态
  Future<bool> isAutoSyncEnabled() async {
    if (_autoSyncTimer != null) {
      return _isAutoSyncEnabled;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? false;
  }

  /// 获取上次同步时间
  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  /// 上传字节数据到 WebDAV
  Future<bool> _uploadBytes(
    http.Client client,
    String url,
    String username,
    String password,
    Uint8List bytes,
  ) async {
    try {
      var request = http.Request('PUT', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);
      request.headers['Content-Type'] = 'application/zip';
      request.bodyBytes = bytes;

      var response = await client.send(request);

      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('PUT', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          request.headers['Content-Type'] = 'application/zip';
          request.bodyBytes = bytes;
          response = await client.send(request);
        }
      }

      debugPrint('[WebDAV] PUT $url -> ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      debugPrint('[WebDAV] _uploadBytes error: $e');
      return false;
    }
  }

  /// 下载文件到本地
  Future<bool> _downloadFile(
    http.Client client,
    String url,
    String username,
    String password,
    File localFile,
  ) async {
    try {
      var request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);

      var response = await client.send(request);

      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('GET', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          response = await client.send(request);
        }
      }

      debugPrint('[WebDAV] GET $url -> ${response.statusCode}');

      if (response.statusCode == 200) {
        await localFile.parent.create(recursive: true);
        final bytes = await response.stream.toBytes();
        await localFile.writeAsBytes(bytes);
        debugPrint('[WebDAV] Downloaded ${bytes.length} bytes');
        return true;
      }
      return false;
    } catch (e) {
      // ignore
      return false;
    }
  }

  /// 获取远程备份文件信息（修改时间和大小）
  Future<Map<String, dynamic>?> getRemoteBackupInfo() async {
    final config = await getConfig();
    if (config == null) return null;

    final url = config['url']!;
    final username = config['username']!;
    final password = config['password']!;
    final path = config['path']!;

    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final zipUrl = '$baseUrl$path/mooknote_backup.zip';

    final client = http.Client();
    try {
      var request = http.Request('HEAD', Uri.parse(zipUrl));
      request.headers['Authorization'] = _basicAuth(username, password);

      var response = await client.send(request);

      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('HEAD', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          response = await client.send(request);
        }
      }

      if (response.statusCode == 200) {
        final lastModified = response.headers['last-modified'];
        final contentLength = response.headers['content-length'];
        DateTime? modifiedTime;
        if (lastModified != null) {
          modifiedTime = HttpDate.parse(lastModified).toLocal();
        }
        return {
          'modifiedTime': modifiedTime,
          'size': contentLength != null ? int.tryParse(contentLength) : null,
        };
      }
      return null;
    } catch (e) {
      debugPrint('[WebDAV] 获取远程备份信息失败: $e');
      return null;
    } finally {
      client.close();
    }
  }
  Future<DateTime?> _getRemoteFileModifiedTime(
    http.Client client,
    String url,
    String username,
    String password,
  ) async {
    try {
      var request = http.Request('HEAD', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);

      var response = await client.send(request);

      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('HEAD', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          response = await client.send(request);
        }
      }

      if (response.statusCode == 200) {
        final lastModified = response.headers['last-modified'];
        if (lastModified != null) {
          return HttpDate.parse(lastModified);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WebDAV] 获取远程文件时间失败: $e');
      return null;
    }
  }

  /// Basic Auth 编码
  String _basicAuth(String username, String password) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }
}
