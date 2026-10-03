import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'backup_service.dart';
import '../../l10n/app_strings.dart';

/// 带认证请求的完整响应
class AuthedHttpResponse {
  final int statusCode;
  final Map<String, String> headers;
  final Uint8List body;

  AuthedHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });
}

/// WebDAV 同步结果
class SyncResult {  final bool success;
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
}

/// 远程备份条目：目录型（分片备份）或旧版单 zip 文件
class _RemoteBackupEntry {
  final String name;
  final bool isDir;

  _RemoteBackupEntry(this.name, this.isDir);
}

/// WebDAV 服务类 - 完整备份 zip 同步
class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  static WebDAVService get instance => _instance;

  WebDAVService._internal();

  static const String _configKey = 'webdav_config';
  static const String _lastSyncKey = 'webdav_last_sync';
  static const String _backupPrefix = 'mooknote_backup_';
  static const int _maxBackupCount = 5;

  // HTTP 请求超时
  static const Duration _httpTimeout = Duration(seconds: 120);
  static const Duration _shortTimeout = Duration(seconds: 30);

  Map<String, String>? _cachedConfig;
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
    _cachedConfig = null;
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
      var davUrl = '$baseUrl${_normalizePath(path)}';

      final client = http.Client();
      try {
        const propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:resourcetype/>
  </D:prop>
</D:propfind>''';

        final propfindResponse = await _sendAuthed(
          client, 'PROPFIND', davUrl, username, password,
          headers: {'Depth': '0'},
          body: propfindBody,
          onRedirect: (newUrl) => davUrl = newUrl,
        );

        if (propfindResponse.statusCode == 207) {
          return {'success': true, 'message': '连接成功'.tr};
        } else if (propfindResponse.statusCode == 401) {
          return {'success': false, 'message': '认证失败，请检查用户名和密码'.tr};
        } else if (propfindResponse.statusCode == 404) {
          // 目录不存在，尝试创建
        } else {
          await propfindResponse.stream.drain();
          return {'success': false, 'message': '服务器返回错误: {code}'.trf({'code': propfindResponse.statusCode})};
        }
      } catch (e) {
        // ignore
      }

      try {
        final mkcolResponse = await _sendAuthed(
          client, 'MKCOL', davUrl, username, password,
        );

        if (mkcolResponse.statusCode == 201) {
          return {'success': true, 'message': '连接成功，已创建目录'.tr};
        } else if (mkcolResponse.statusCode == 405) {
          return {'success': true, 'message': '连接成功，目录已存在'.tr};
        } else if (mkcolResponse.statusCode == 401) {
          return {'success': false, 'message': '认证失败，请检查用户名和密码'.tr};
        } else if (mkcolResponse.statusCode == 409) {
          return {'success': false, 'message': '父目录不存在，请检查路径'.tr};
        } else {
          return {'success': false, 'message': '创建目录失败: {code}'.trf({'code': mkcolResponse.statusCode})};
        }
      } catch (e) {
        return {'success': false, 'message': '连接失败: {e}'.trf({'e': e})};
      } finally {
        client.close();
      }
    } catch (e) {
      return {'success': false, 'message': '连接失败: {e}'.trf({'e': e})};
    }
  }

  /// 打包本地数据（第一步，用于上传前单独调用以显示进度）
  Future<AutoBackupExportResult> exportLocalData() async {
    return BackupService.instance.exportDataForWebDAVShards();
  }

  /// 上传已打包的分片数据（第二步）
  /// 注意：本方法不参与 _isSyncing 锁——锁由 syncData 持有，
  /// 这里若误清标志会把在途同步的并发防护解除
  Future<SyncResult> uploadExportedData(AutoBackupExportResult exportResult) async {
    if (!exportResult.success || exportResult.shardDirPath == null) {
      return SyncResult(success: false, message: exportResult.errorMessage ?? '创建备份失败'.tr);
    }

    final config = await getConfig();
    if (config == null) {
      return SyncResult(success: false, message: '未配置 WebDAV'.tr);
    }

    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final path = config['path']!;

      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final dirUrl = '$baseUrl${_normalizePath(path)}';

      final client = http.Client();
      try {
        final backupName = _generateBackupDirName();
        final success = await _uploadShardDir(client, dirUrl, backupName, username, password, exportResult);
        try { await Directory(exportResult.shardDirPath!).delete(recursive: true); } catch (_) {}
        if (success) {
          debugPrint('[WebDAV] 备份上传成功: $backupName (影视${exportResult.movieCount} 书籍${exportResult.bookCount} 笔记${exportResult.noteCount} 图片${exportResult.imageCount})');
          await _cleanupOldBackups(client, dirUrl, username, password);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
          return SyncResult(
            success: true, message: '同步完成'.tr,
            uploadedFiles: exportResult.shardFileNames.length, uploadedImages: exportResult.imageCount,
          );
        } else {
          return SyncResult(success: false, message: '上传备份文件失败'.tr);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      return SyncResult(success: false, message: '上传失败: {e}'.trf({'e': e}));
    }
  }

  /// 同步数据 — 完整备份 zip 格式，与本地备份完全一致
  Future<SyncResult> syncData({SyncDirection direction = SyncDirection.upload}) async {
    // 防止并发同步
    if (_isSyncing) {
      return SyncResult(success: false, message: '同步正在进行中，请稍后再试'.tr);
    }
    _isSyncing = true;

    final config = await getConfig();
    if (config == null) {
      _isSyncing = false;
      return SyncResult(success: false, message: '未配置 WebDAV'.tr);
    }

    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final path = config['path']!;

      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final dirUrl = '$baseUrl${_normalizePath(path)}';

      final client = http.Client();
      int uploadedFiles = 0;
      int downloadedFiles = 0;
      int uploadedImages = 0;
      int downloadedImages = 0;
      bool needReload = false;

      try {
        if (direction == SyncDirection.upload) {
          final exportResult = await BackupService.instance.exportDataForWebDAVShards();
          if (!exportResult.success || exportResult.shardDirPath == null) {
            return SyncResult(success: false, message: exportResult.errorMessage ?? '创建备份失败'.tr);
          }

          final backupName = _generateBackupDirName();
          final success = await _uploadShardDir(client, dirUrl, backupName, username, password, exportResult);
          // 清理临时分片目录
          try { await Directory(exportResult.shardDirPath!).delete(recursive: true); } catch (_) {}
          if (success) {
            uploadedFiles = exportResult.shardFileNames.length;
            uploadedImages = exportResult.imageCount;
            debugPrint('[WebDAV] 备份上传成功: $backupName (影视${exportResult.movieCount} 书籍${exportResult.bookCount} 笔记${exportResult.noteCount} 图片${exportResult.imageCount})');
            // 清理旧备份
            await _cleanupOldBackups(client, dirUrl, username, password);
          } else {
            return SyncResult(success: false, message: '上传备份文件失败'.tr);
          }

        } else if (direction == SyncDirection.download) {
          // 找到最新的备份（目录型或旧版单 zip）
          final backups = await _listRemoteBackups(client, dirUrl, username, password);
          if (backups.isEmpty) {
            return SyncResult(success: false, message: '服务器上没有备份文件，请先从其他设备上传'.tr);
          }
          final latest = backups.last;

          final tempDir = await getTemporaryDirectory();

          if (latest.isDir) {
            final localDirPath = await _downloadShardDir(client, dirUrl, latest.name, username, password, tempDir.path);
            if (localDirPath != null) {
              final importResult = await BackupService.instance.restoreFromShardDir(localDirPath);
              try { await Directory(localDirPath).delete(recursive: true); } catch (_) {}

              if (importResult.success) {
                downloadedFiles = 1;
                downloadedImages = importResult.stats?['图片'] ?? 0;
                needReload = true;
                debugPrint('[WebDAV] 备份恢复成功 (${latest.name}): ${importResult.statsText}');
              } else {
                return SyncResult(success: false, message: importResult.errorMessage ?? '恢复备份失败'.tr);
              }
            } else {
              return SyncResult(success: false, message: '下载备份文件失败'.tr);
            }
          } else {
            final zipUrl = '$dirUrl/${latest.name}';
            final tempZip = File(p.join(tempDir.path, 'mooknote_download.zip'));
            final success = await _downloadFile(client, zipUrl, username, password, tempZip);

            if (success && await tempZip.exists()) {
              // 流式解压恢复（restoreFromZipFile 内部已捕获异常，不会抛出）
              final importResult = await BackupService.instance.restoreFromZipFile(tempZip.path);
              try { await tempZip.delete(); } catch (_) {}

              if (importResult.success) {
                downloadedFiles = 1;
                downloadedImages = importResult.stats?['图片'] ?? 0;
                needReload = true;
                debugPrint('[WebDAV] 备份恢复成功 (${latest.name}): ${importResult.statsText}');
              } else {
                return SyncResult(success: false, message: importResult.errorMessage ?? '恢复备份失败'.tr);
              }
            } else {
              try { await tempZip.delete(); } catch (_) {}
              return SyncResult(success: false, message: '下载备份文件失败'.tr);
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
          message: anySuccess ? '同步完成'.tr : '同步未完成，未传输任何数据'.tr,
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
      return SyncResult(success: false, message: '同步失败: {e}'.trf({'e': e}));
    } finally {
      _isSyncing = false;
    }
  }

  /// 获取上次同步时间
  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  /// 获取配置的同步根目录完整 URL（无尾斜杠）
  Future<String> getBaseDirUrl() async {
    final config = await getConfig();
    if (config == null) throw StateError('未配置 WebDAV'.tr);
    final url = config['url']!;
    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return '$baseUrl${_normalizePath(config['path']!)}';
  }

  /// 带认证的通用请求（已读取完整响应体）
  Future<AuthedHttpResponse> requestBytes({
    required String method,
    required String url,
    Map<String, String>? headers,
    List<int>? bodyBytes,
    Duration? timeout,
  }) async {
    final config = await getConfig();
    if (config == null) throw StateError('未配置 WebDAV'.tr);

    final client = http.Client();
    try {
      final response = await _sendAuthed(
        client, method, url, config['username']!, config['password']!,
        headers: headers, bodyBytes: bodyBytes, timeout: timeout,
      );
      final body = await response.stream.toBytes();
      return AuthedHttpResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: body,
      );
    } finally {
      client.close();
    }
  }

  /// PUT 上传字节并做 HEAD 存在性 + 大小校验（防止假成功）
  Future<bool> putVerified(
    String url,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    final config = await getConfig();
    if (config == null) return false;
    final username = config['username']!;
    final password = config['password']!;

    final client = http.Client();
    try {
      final response = await _sendAuthed(
        client, 'PUT', url, username, password,
        headers: {'Content-Type': contentType},
        bodyBytes: bytes,
        timeout: _httpTimeout,
      );
      await response.stream.drain();

      debugPrint('[WebDAV] PUT $url -> ${response.statusCode}');
      final putOk = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      if (!putOk) return false;

      final verify = await _sendAuthed(
        client, 'HEAD', url, username, password,
        timeout: _shortTimeout,
      );
      await verify.stream.drain();

      if (verify.statusCode != 200) {
        debugPrint('[WebDAV] PUT 返回成功但 HEAD 校验为 ${verify.statusCode}，文件实际未保存: $url');
        return false;
      }

      final remoteLength = int.tryParse(verify.headers['content-length'] ?? '');
      if (remoteLength != null && remoteLength != bytes.length) {
        debugPrint('[WebDAV] 文件大小不一致: 本地 ${bytes.length} 远程 $remoteLength');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[WebDAV] putVerified error: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// 上传文件到 WebDAV（流式读取，避免大备份全量读入内存）
  Future<bool> _uploadFile(
    http.Client client,
    String url,
    String username,
    String password,
    String filePath, {
    String contentType = 'application/zip',
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[WebDAV] _uploadFile: 文件不存在 $filePath');
        return false;
      }
      final length = await file.length();
      // 预探测认证方案：若服务器要求 Digest，首包即带正确 Authorization，
      // 避免整个文件以 Basic 发出后被 401 拒绝、再整体重传一遍
      final preemptAuth = await _probeAuthScheme(client, 'PUT', url, username, password);
      final sw = Stopwatch()..start();
      final response = await _sendAuthedStream(
        client, 'PUT', url, username, password,
        headers: {'Content-Type': contentType},
        contentLength: length,
        bodyStreamFactory: () => file.openRead(),
        timeout: _httpTimeout,
        initialAuth: preemptAuth,
      );
      final sentMs = sw.elapsedMilliseconds;
      await response.stream.drain();

      debugPrint('[WebDAV] PUT $url -> ${response.statusCode} '
          '(${length ~/ 1024}KB, 发送等待 ${sentMs}ms, 总耗时 ${sw.elapsedMilliseconds}ms, '
          '约 ${(length / 1024 / max(sw.elapsedMilliseconds / 1000, 0.001)).toStringAsFixed(0)}KB/s)');
      final putOk = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      if (!putOk) return false;

      // 部分 WebDAV 服务器在写入失败（配额满、超过单文件上限等）时仍返回 200，
      // 必须 HEAD 校验文件确实存在且大小一致，否则会得到假成功
      final verify = await _sendAuthed(
        client, 'HEAD', url, username, password,
        timeout: _shortTimeout,
      );
      await verify.stream.drain();

      if (verify.statusCode != 200) {
        debugPrint('[WebDAV] PUT 返回成功但 HEAD 校验为 ${verify.statusCode}，文件实际未保存: $url');
        return false;
      }

      final remoteLength = int.tryParse(verify.headers['content-length'] ?? '');
      if (remoteLength != null && remoteLength != length) {
        debugPrint('[WebDAV] 文件大小不一致: 本地 $length 远程 $remoteLength');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[WebDAV] _uploadFile error: $e');
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
      final response = await _sendAuthed(
        client, 'GET', url, username, password,
        timeout: _httpTimeout,
      );

      debugPrint('[WebDAV] GET $url -> ${response.statusCode}');

      if (response.statusCode == 200) {
        await localFile.parent.create(recursive: true);
        // 流式写盘，避免大备份全量读入内存；
        // 每个分块都套用空闲超时，防止服务器发完头后挂起导致同步永久卡死
        final sink = localFile.openWrite();
        var total = 0;
        try {
          await for (final chunk in response.stream.timeout(_httpTimeout)) {
            sink.add(chunk);
            total += chunk.length;
          }
        } finally {
          await sink.close();
        }
        // 校验实际下载字节数，截断的响应不能当成功
        final expected = response.contentLength;
        if (expected != null && expected >= 0 && total != expected) {
          debugPrint('[WebDAV] 下载不完整: $total/$expected bytes');
          try { await localFile.delete(); } catch (_) {}
          return false;
        }
        debugPrint('[WebDAV] Downloaded $total bytes');
        return true;
      }
      return false;
    } catch (e) {
      // ignore
      return false;
    }
  }

  /// 获取远程最新备份文件信息（修改时间和大小）
  Future<Map<String, dynamic>?> getRemoteBackupInfo() async {
    final config = await getConfig();
    if (config == null) return null;

    final url = config['url']!;
    final username = config['username']!;
    final password = config['password']!;
    final path = config['path']!;

    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final dirUrl = '$baseUrl${_normalizePath(path)}';

    final client = http.Client();
    try {
      // 列出备份，找到最新的（目录型则 HEAD 其 manifest.json）
      final backups = await _listRemoteBackups(client, dirUrl, username, password);
      if (backups.isEmpty) return null;

      final latest = backups.last;
      final targetUrl = latest.isDir
          ? '$dirUrl/${latest.name}/manifest.json'
          : '$dirUrl/${latest.name}';

      final response = await _sendAuthed(
        client, 'HEAD', targetUrl, username, password,
        timeout: _shortTimeout,
      );
      await response.stream.drain();

      if (response.statusCode == 200) {
        final lastModified = response.headers['last-modified'];
        // 目录型备份的总大小需累积分片，HEAD manifest 拿不到，返回 null
        final contentLength = latest.isDir ? null : response.headers['content-length'];
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

  /// 生成带毫秒时间戳的备份目录名（分片型备份是一个目录而非单个 zip）
  String _generateBackupDirName() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$_backupPrefix$ts';
  }

  /// 并行上传分片目录：MKCOL 建目录 → 并发 4 路上传分片 → 最后传 manifest.json。
  /// manifest 是"提交点"：只有它存在，下载方才认为该备份完整。
  Future<bool> _uploadShardDir(
    http.Client client,
    String dirUrl,
    String backupName,
    String username,
    String password,
    AutoBackupExportResult exportResult,
  ) async {
    final backupUrl = '$dirUrl/$backupName';
    final shardDir = Directory(exportResult.shardDirPath!);

    final mkcol = await _sendAuthed(client, 'MKCOL', backupUrl, username, password);
    await mkcol.stream.drain();
    // 405 = 目录已存在，视为成功（时间戳命名正常不会撞）
    if (mkcol.statusCode != 201 && mkcol.statusCode != 405) {
      debugPrint('[WebDAV] MKCOL $backupUrl -> ${mkcol.statusCode}');
      return false;
    }

    const concurrency = 4;
    final names = exportResult.shardFileNames;
    var failed = false;
    var next = 0;
    Future<void> worker() async {
      while (!failed) {
        final i = next++;
        if (i >= names.length) return;
        final ok = await _uploadFile(
          client, '$backupUrl/${names[i]}', username, password,
          p.join(shardDir.path, names[i]),
        );
        if (!ok) failed = true;
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));

    // 提交点：最后上传 manifest
    if (!failed) {
      failed = !await _uploadFile(
        client, '$backupUrl/manifest.json', username, password,
        p.join(shardDir.path, 'manifest.json'),
        contentType: 'application/json',
      );
    }

    if (failed) {
      // 清理半成品目录，避免占用备份名额、干扰"最新备份"判断
      await _deleteRemoteFile(client, backupUrl, username, password);
      return false;
    }
    return true;
  }

  /// 下载分片型备份：先取 manifest.json 校验完整性，再并发 4 路下载全部分片。
  /// 成功返回本地分片目录路径，失败返回 null。
  Future<String?> _downloadShardDir(
    http.Client client,
    String dirUrl,
    String backupName,
    String username,
    String password,
    String tempDirPath,
  ) async {
    final backupUrl = '$dirUrl/$backupName';
    final localDir = Directory(p.join(tempDirPath, 'mooknote_dl_${DateTime.now().microsecondsSinceEpoch}'));
    await localDir.create(recursive: true);

    Future<String?> fail() async {
      try { await localDir.delete(recursive: true); } catch (_) {}
      return null;
    }

    final manifestFile = File(p.join(localDir.path, 'manifest.json'));
    if (!await _downloadFile(client, '$backupUrl/manifest.json', username, password, manifestFile)) {
      debugPrint('[WebDAV] 分片备份缺少 manifest.json，视为不完整: $backupName');
      return fail();
    }

    late final List<String> shards;
    try {
      final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      shards = (manifest['shards'] as List).cast<String>();
    } catch (e) {
      debugPrint('[WebDAV] manifest 解析失败: $e');
      return fail();
    }
    // 清单来自服务器，防止路径穿越写出本地目录
    if (shards.any((s) => s.contains('/') || s.contains('\\') || s == '..' || s.isEmpty)) {
      debugPrint('[WebDAV] manifest 含非法分片名');
      return fail();
    }

    const concurrency = 4;
    var failed = false;
    var next = 0;
    Future<void> worker() async {
      while (!failed) {
        final i = next++;
        if (i >= shards.length) return;
        final ok = await _downloadFile(
          client, '$backupUrl/${shards[i]}', username, password,
          File(p.join(localDir.path, shards[i])),
        );
        if (!ok) failed = true;
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));

    if (failed) return fail();
    return localDir.path;
  }

  /// 获取远程目录中的备份列表（按时间戳升序；含目录型分片备份与旧版单 zip）
  Future<List<_RemoteBackupEntry>> _listRemoteBackups(
    http.Client client,
    String dirUrl,
    String username,
    String password,
  ) async {
    try {
      final response = await _sendAuthed(
        client, 'PROPFIND', dirUrl, username, password,
        headers: {'Depth': '1', 'Cache-Control': 'no-cache'},
      );

      if (response.statusCode != 207) {
        await response.stream.drain();
        debugPrint('[WebDAV] PROPFIND 返回 ${response.statusCode}，无法列出文件');
        return [];
      }

      final body = await response.stream.bytesToString();

      // 解析 XML 提取 href 中的文件名
      // 兼容不同命名空间: <D:href>, <d:href>, <href>
      final hrefRegExp = RegExp(r'<(?:\w+:)?href[^>]*>([^<]+)</(?:\w+:)?href>', caseSensitive: false);
      final matches = hrefRegExp.allMatches(body);
      final backups = <_RemoteBackupEntry>[];
      for (final match in matches) {
        var href = match.group(1) ?? '';
        // URL decode
        href = Uri.decodeFull(href);
        final isDir = href.endsWith('/');
        // 提取文件名部分
        final fileName = href.split('/').where((s) => s.isNotEmpty).lastOrNull;
        if (fileName == null || !fileName.startsWith(_backupPrefix)) continue;
        if (isDir) {
          backups.add(_RemoteBackupEntry(fileName, true));
        } else if (fileName.endsWith('.zip')) {
          backups.add(_RemoteBackupEntry(fileName, false));
        }
      }
      // 按名称中的时间戳升序排列
      backups.sort((a, b) => a.name.compareTo(b.name));
      debugPrint('[WebDAV] 找到 ${backups.length} 个备份: ${backups.map((e) => e.name).toList()}');
      return backups;
    } catch (e) {
      debugPrint('[WebDAV] 列出备份文件失败: $e');
      return [];
    }
  }

  /// 删除远程文件
  Future<bool> _deleteRemoteFile(
    http.Client client,
    String fileUrl,
    String username,
    String password,
  ) async {
    try {
      final response = await _sendAuthed(
        client, 'DELETE', fileUrl, username, password,
      );
      await response.stream.drain();

      debugPrint('[WebDAV] DELETE $fileUrl -> ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404;
    } catch (e) {
      debugPrint('[WebDAV] 删除远程文件失败: $e');
      return false;
    }
  }

  /// 清理旧备份，保留最新的 _maxBackupCount 个
  Future<void> _cleanupOldBackups(
    http.Client client,
    String dirUrl,
    String username,
    String password,
  ) async {
    final backups = await _listRemoteBackups(client, dirUrl, username, password);
    debugPrint('[WebDAV] 清理检查: 共 ${backups.length} 个备份，保留 $_maxBackupCount 个');
    if (backups.length <= _maxBackupCount) return;

    final toDelete = backups.sublist(0, backups.length - _maxBackupCount);
    for (final entry in toDelete) {
      // DELETE 对目录型备份会递归删除整个集合
      final fileUrl = '$dirUrl/${entry.name}';
      final deleted = await _deleteRemoteFile(client, fileUrl, username, password);
      debugPrint('[WebDAV] 删除旧备份 ${entry.name}: ${deleted ? '成功' : '失败'}');
    }
  }

  /// 规范化路径：保证以 '/' 开头、不以 '/' 结尾；空或根路径返回空串，
  /// 避免拼接出 '//'（部分服务器如 CloudMe 会返回 400）
  String _normalizePath(String path) {
    var p = path.trim();
    if (p.isEmpty || p == '/') return '';
    if (!p.startsWith('/')) p = '/$p';
    while (p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  /// Basic Auth 编码
  String _basicAuth(String username, String password) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }

  /// 发送带认证的请求：先发 Basic，若服务器返回 401 且要求 Digest，则按
  /// RFC 7616 (MD5, qop=auth) 计算 Digest 头重试；同时处理重定向。
  /// [onRedirect] 在最终 URL 发生变化时回调（用于调用方更新基准 URL）。
  Future<http.StreamedResponse> _sendAuthed(
    http.Client client,
    String method,
    String url,
    String username,
    String password, {
    Map<String, String>? headers,
    String? body,
    List<int>? bodyBytes,
    Duration? timeout,
    void Function(String newUrl)? onRedirect,
  }) async {
    final uri = Uri.parse(url);

    http.Request buildRequest(String? authorization) {
      final req = http.Request(method, uri);
      if (headers != null) req.headers.addAll(headers);
      req.headers['Authorization'] = authorization ?? _basicAuth(username, password);
      if (bodyBytes != null) {
        req.bodyBytes = bodyBytes;
      } else if (body != null) {
        req.body = body;
      }
      return req;
    }

    var response = await client.send(buildRequest(null)).timeout(timeout ?? _shortTimeout);

    // Digest 认证重试
    if (response.statusCode == 401) {
      final challenge = response.headers['www-authenticate'];
      await response.stream.drain();
      if (challenge != null && challenge.toLowerCase().startsWith('digest')) {
        final digest = _buildDigestHeader(challenge, method, uri, username, password);
        if (digest != null) {
          response = await client.send(buildRequest(digest)).timeout(timeout ?? _shortTimeout);
        }
      }
    }

    // 重定向处理
    if (response.statusCode == 301 || response.statusCode == 302 ||
        response.statusCode == 307 || response.statusCode == 308) {
      final location = response.headers['location'];
      await response.stream.drain();
      if (location != null) {
        final newUrl = uri.resolve(location).toString();
        onRedirect?.call(newUrl);
        return _sendAuthed(
          client, method, newUrl, username, password,
          headers: headers, body: body, bodyBytes: bodyBytes,
          timeout: timeout, onRedirect: onRedirect,
        );
      }
    }

    return response;
  }

  /// 探测目标 URL 的认证方案：先发一个无实体的 HEAD。
  /// 若服务器要求 Digest，基于挑战直接算出 [method] 对应的 Authorization 返回，
  /// 供后续带大实体的请求首包使用；Basic 可用或探测失败时返回 null，
  /// 走原有的 Basic → 401 → Digest 重试逻辑。
  Future<String?> _probeAuthScheme(
    http.Client client,
    String method,
    String url,
    String username,
    String password,
  ) async {
    try {
      final uri = Uri.parse(url);
      final probe = http.Request('HEAD', uri);
      probe.headers['Authorization'] = _basicAuth(username, password);
      final resp = await client.send(probe).timeout(_shortTimeout);
      await resp.stream.drain();
      if (resp.statusCode == 401) {
        final challenge = resp.headers['www-authenticate'];
        if (challenge != null && challenge.toLowerCase().startsWith('digest')) {
          return _buildDigestHeader(challenge, method, uri, username, password);
        }
      }
    } catch (_) {
      // 探测失败不阻塞主流程
    }
    return null;
  }

  /// [_sendAuthed] 的流式上传变体：请求体由 [bodyStreamFactory] 按需打开
  /// （Digest 重试与重定向时会重新调用以获取新流），用于大文件上传。
  /// [initialAuth] 为首包直接使用的 Authorization（如预探测得到的 Digest 头），
  /// 避免带大实体的请求先以 Basic 发出再 401 重传。
  Future<http.StreamedResponse> _sendAuthedStream(
    http.Client client,
    String method,
    String url,
    String username,
    String password, {
    Map<String, String>? headers,
    required int contentLength,
    required Stream<List<int>> Function() bodyStreamFactory,
    Duration? timeout,
    String? initialAuth,
    void Function(String newUrl)? onRedirect,
  }) async {
    final uri = Uri.parse(url);

    http.StreamedRequest buildRequest(String? authorization) {
      final req = http.StreamedRequest(method, uri);
      if (headers != null) req.headers.addAll(headers);
      req.headers['Authorization'] = authorization ?? initialAuth ?? _basicAuth(username, password);
      req.contentLength = contentLength;
      // 服务器提前关闭连接（如 Digest 挑战）时 sink 会拒绝写入，捕获后取消泵送
      StreamSubscription<List<int>>? sub;
      sub = bodyStreamFactory().listen(
        (chunk) {
          try {
            req.sink.add(chunk);
          } catch (_) {
            sub?.cancel();
          }
        },
        onError: (_) {
          try { req.sink.close(); } catch (_) {}
        },
        onDone: () {
          try { req.sink.close(); } catch (_) {}
        },
      );
      return req;
    }

    var response = await client.send(buildRequest(null)).timeout(timeout ?? _shortTimeout);

    // Digest 认证重试
    if (response.statusCode == 401) {
      final challenge = response.headers['www-authenticate'];
      await response.stream.drain();
      if (challenge != null && challenge.toLowerCase().startsWith('digest')) {
        final digest = _buildDigestHeader(challenge, method, uri, username, password);
        if (digest != null) {
          response = await client.send(buildRequest(digest)).timeout(timeout ?? _shortTimeout);
        }
      }
    }

    // 重定向处理
    if (response.statusCode == 301 || response.statusCode == 302 ||
        response.statusCode == 307 || response.statusCode == 308) {
      final location = response.headers['location'];
      await response.stream.drain();
      if (location != null) {
        final newUrl = uri.resolve(location).toString();
        onRedirect?.call(newUrl);
        return _sendAuthedStream(
          client, method, newUrl, username, password,
          headers: headers, contentLength: contentLength,
          bodyStreamFactory: bodyStreamFactory,
          timeout: timeout, onRedirect: onRedirect,
        );
      }
    }

    return response;
  }

  /// 解析 WWW-Authenticate: Digest 挑战并生成 Authorization 头（MD5 / MD5-sess, qop=auth）
  String? _buildDigestHeader(
    String challenge,
    String method,
    Uri uri,
    String username,
    String password,
  ) {
    final params = <String, String>{};
    final paramReg = RegExp(r'(\w+)=(?:"([^"]*)"|([^,\s"]+))');
    for (final m in paramReg.allMatches(challenge)) {
      params[m.group(1)!.toLowerCase()] = m.group(2) ?? m.group(3) ?? '';
    }

    final realm = params['realm'];
    final nonce = params['nonce'];
    if (realm == null || nonce == null) return null;

    final algorithm = (params['algorithm'] ?? 'MD5').toUpperCase();
    if (algorithm != 'MD5' && algorithm != 'MD5-SESS') return null;

    // qop 可能是 "auth,auth-int" 列表，只支持 auth
    String? qop;
    final qopRaw = params['qop'];
    if (qopRaw != null) {
      final qops = qopRaw.split(',').map((e) => e.trim().toLowerCase());
      if (qops.contains('auth')) {
        qop = 'auth';
      }
    }

    String md5Hex(String s) => md5.convert(utf8.encode(s)).toString();

    final cnonce = List.generate(
      16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    var ha1 = md5Hex('$username:$realm:$password');
    if (algorithm == 'MD5-SESS') {
      ha1 = md5Hex('$ha1:$nonce:$cnonce');
    }

    final path = uri.path.isEmpty ? '/' : uri.path;
    final digestUri = uri.hasQuery ? '$path?${uri.query}' : path;
    final ha2 = md5Hex('$method:$digestUri');

    final buffer = StringBuffer()
      ..write('Digest username="$username"')
      ..write(', realm="$realm"')
      ..write(', nonce="$nonce"')
      ..write(', uri="$digestUri"')
      ..write(', algorithm=$algorithm');

    if (qop != null) {
      const nc = '00000001';
      final response = md5Hex('$ha1:$nonce:$nc:$cnonce:$qop:$ha2');
      buffer
        ..write(', response="$response"')
        ..write(', qop=$qop')
        ..write(', nc=$nc')
        ..write(', cnonce="$cnonce"');
    } else {
      final response = md5Hex('$ha1:$nonce:$ha2');
      buffer.write(', response="$response"');
    }

    final opaque = params['opaque'];
    if (opaque != null) {
      buffer.write(', opaque="$opaque"');
    }

    return buffer.toString();
  }
}
