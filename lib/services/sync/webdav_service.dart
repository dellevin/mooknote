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
    return BackupService.instance.exportDataForAutoBackup();
  }

  /// 上传已打包的数据（第二步）
  Future<SyncResult> uploadExportedData(AutoBackupExportResult exportResult) async {
    if (!exportResult.success || exportResult.zipPath == null) {
      _isSyncing = false;
      return SyncResult(success: false, message: exportResult.errorMessage ?? '创建备份失败'.tr);
    }

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
      try {
        final fileName = _generateBackupFileName();
        final zipUrl = '$dirUrl/$fileName';
        final success = await _uploadFile(client, zipUrl, username, password, exportResult.zipPath!);
        try { await File(exportResult.zipPath!).delete(); } catch (_) {}
        if (success) {
          debugPrint('[WebDAV] 备份上传成功: $fileName (影视${exportResult.movieCount} 书籍${exportResult.bookCount} 笔记${exportResult.noteCount} 图片${exportResult.imageCount})');
          await _cleanupOldBackups(client, dirUrl, username, password);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
          return SyncResult(
            success: true, message: '同步完成'.tr,
            uploadedFiles: 1, uploadedImages: exportResult.imageCount,
          );
        } else {
          return SyncResult(success: false, message: '上传备份文件失败'.tr);
        }
      } finally {
        client.close();
      }
    } catch (e) {
      return SyncResult(success: false, message: '上传失败: {e}'.trf({'e': e}));
    } finally {
      _isSyncing = false;
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
          final exportResult = await BackupService.instance.exportDataForAutoBackup();
          if (!exportResult.success || exportResult.zipPath == null) {
            return SyncResult(success: false, message: exportResult.errorMessage ?? '创建备份失败'.tr);
          }

          final fileName = _generateBackupFileName();
          final zipUrl = '$dirUrl/$fileName';
          final success = await _uploadFile(client, zipUrl, username, password, exportResult.zipPath!);
          // 清理临时 zip 文件
          try { await File(exportResult.zipPath!).delete(); } catch (_) {}
          if (success) {
            uploadedFiles = 1;
            uploadedImages = exportResult.imageCount;
            debugPrint('[WebDAV] 备份上传成功: $fileName (影视${exportResult.movieCount} 书籍${exportResult.bookCount} 笔记${exportResult.noteCount} 图片${exportResult.imageCount})');
            // 清理旧备份
            await _cleanupOldBackups(client, dirUrl, username, password);
          } else {
            return SyncResult(success: false, message: '上传备份文件失败'.tr);
          }

        } else if (direction == SyncDirection.download) {
          // 找到最新的备份文件
          final backups = await _listRemoteBackups(client, dirUrl, username, password);
          if (backups.isEmpty) {
            return SyncResult(success: false, message: '服务器上没有备份文件，请先从其他设备上传'.tr);
          }
          final latestFile = backups.last;
          final zipUrl = '$dirUrl/$latestFile';

          final tempDir = await getTemporaryDirectory();
          final tempZip = File(p.join(tempDir.path, 'mooknote_download.zip'));
          final success = await _downloadFile(client, zipUrl, username, password, tempZip);

          if (success && await tempZip.exists()) {
            final bytes = await tempZip.readAsBytes();
            try { await tempZip.delete(); } catch (_) {}
            final importResult = await BackupService.instance.restoreFromZipBytes(bytes);

            if (importResult.success) {
              downloadedFiles = 1;
              downloadedImages = importResult.stats?['图片'] ?? 0;
              needReload = true;
              debugPrint('[WebDAV] 备份恢复成功 ($latestFile): ${importResult.statsText}');
            } else {
              return SyncResult(success: false, message: importResult.errorMessage ?? '恢复备份失败'.tr);
            }
          } else {
            try { await tempZip.delete(); } catch (_) {}
            return SyncResult(success: false, message: '下载备份文件失败'.tr);
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

  /// 上传文件到 WebDAV（从文件路径读取，避免备份服务端重复占用内存）
  Future<bool> _uploadFile(
    http.Client client,
    String url,
    String username,
    String password,
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[WebDAV] _uploadFile: 文件不存在 $filePath');
        return false;
      }
      final bytes = await file.readAsBytes();

      final response = await _sendAuthed(
        client, 'PUT', url, username, password,
        headers: {'Content-Type': 'application/zip'},
        bodyBytes: bytes,
        timeout: _httpTimeout,
      );
      await response.stream.drain();

      debugPrint('[WebDAV] PUT $url -> ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204;
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

  /// 获取远程最新备份文件信息（修改时间和大小）
  Future<Map<String, dynamic>?> getRemoteBackupInfo() async {
    final config = await getConfig();
    if (config == null) return null;

    final url = config['url']!;
    final username = config['username']!;
    final password = config['password']!;
    final path = config['path']!;

    final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final dirUrl = '$baseUrl$path';

    final client = http.Client();
    try {
      // 列出备份文件，找到最新的
      final backups = await _listRemoteBackups(client, dirUrl, username, password);
      if (backups.isEmpty) return null;

      final latestFile = backups.last;
      final zipUrl = '$dirUrl/$latestFile';

      final response = await _sendAuthed(
        client, 'HEAD', zipUrl, username, password,
        timeout: _shortTimeout,
      );
      await response.stream.drain();

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

  /// 生成带毫秒时间戳的备份文件名
  String _generateBackupFileName() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$_backupPrefix$ts.zip';
  }

  /// 获取远程目录中的备份文件列表（按时间戳升序）
  Future<List<String>> _listRemoteBackups(
    http.Client client,
    String dirUrl,
    String username,
    String password,
  ) async {
    try {
      final response = await _sendAuthed(
        client, 'PROPFIND', dirUrl, username, password,
        headers: {'Depth': '1'},
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
      final backupFiles = <String>[];
      for (final match in matches) {
        var href = match.group(1) ?? '';
        // URL decode
        href = Uri.decodeFull(href);
        // 提取文件名部分
        final fileName = href.split('/').where((s) => s.isNotEmpty).lastOrNull;
        if (fileName != null && fileName.startsWith(_backupPrefix) && fileName.endsWith('.zip')) {
          backupFiles.add(fileName);
        }
      }
      // 按文件名中的时间戳升序排列
      backupFiles.sort();
      debugPrint('[WebDAV] 找到 ${backupFiles.length} 个备份文件: $backupFiles');
      return backupFiles;
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
    for (final fileName in toDelete) {
      final fileUrl = '$dirUrl/$fileName';
      final deleted = await _deleteRemoteFile(client, fileUrl, username, password);
      debugPrint('[WebDAV] 删除旧备份 $fileName: ${deleted ? '成功' : '失败'}');
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
