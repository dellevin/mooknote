import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// WebDAV 同步结果
class SyncResult {
  final bool success;
  final String message;
  final DateTime? lastSyncTime;
  final int uploadedFiles;
  final int downloadedFiles;
  final int uploadedImages;
  final int downloadedImages;
  final bool needReload; // 是否需要重新加载数据
  
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

/// 图片同步结果
class _ImageSyncResult {
  final int uploaded;
  final int downloaded;
  _ImageSyncResult({required this.uploaded, required this.downloaded});
}

/// WebDAV 服务类
class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  static WebDAVService get instance => _instance;
  
  WebDAVService._internal();
  
  static const String _configKey = 'webdav_config';
  static const String _lastSyncKey = 'webdav_last_sync';
  
  Map<String, String>? _cachedConfig;
  
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
      // 构建 WebDAV URL
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      var davUrl = '$baseUrl$path';
      
      print('WebDAV: Testing connection to $davUrl');
      
      // 先尝试 PROPFIND 请求（更通用的测试方式）
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
        print('WebDAV: PROPFIND status ${propfindResponse.statusCode}');
        
        // 处理重定向 (301, 302, 307, 308)
        if (propfindResponse.statusCode == 301 || 
            propfindResponse.statusCode == 302 ||
            propfindResponse.statusCode == 307 ||
            propfindResponse.statusCode == 308) {
          final location = propfindResponse.headers['location'];
          if (location != null) {
            print('WebDAV: Redirecting to $location');
            // 使用重定向后的 URL 重新请求
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
            print('WebDAV: PROPFIND after redirect status ${propfindResponse.statusCode}');
          }
        }
        
        if (propfindResponse.statusCode == 207) {
          return {'success': true, 'message': '连接成功'};
        } else if (propfindResponse.statusCode == 401) {
          return {'success': false, 'message': '认证失败，请检查用户名和密码'};
        } else if (propfindResponse.statusCode == 404) {
          // 目录不存在，尝试创建
          print('WebDAV: Directory not found, trying to create...');
        } else if (propfindResponse.statusCode == 301 || 
                   propfindResponse.statusCode == 302 ||
                   propfindResponse.statusCode == 307 ||
                   propfindResponse.statusCode == 308) {
          return {'success': false, 'message': '服务器重定向，请尝试使用 ${propfindResponse.headers["location"] ?? "其他地址"}'};
        } else {
          return {'success': false, 'message': '服务器返回错误: ${propfindResponse.statusCode}'};
        }
      } catch (e) {
        print('WebDAV: PROPFIND error: $e');
      }
      
      // 尝试创建目录
      try {
        final mkcolRequest = http.Request('MKCOL', Uri.parse(davUrl));
        mkcolRequest.headers['Authorization'] = _basicAuth(username, password);
        
        final mkcolResponse = await client.send(mkcolRequest);
        print('WebDAV: MKCOL status ${mkcolResponse.statusCode}');
        
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
        print('WebDAV: MKCOL error: $e');
        return {'success': false, 'message': '连接失败: $e'};
      } finally {
        client.close();
      }
    } catch (e) {
      print('WebDAV test connection error: $e');
      return {'success': false, 'message': '连接失败: $e'};
    }
  }
  
  /// 同步数据（双向同步）
  Future<SyncResult> syncData({SyncDirection direction = SyncDirection.bidirectional}) async {
    final config = await getConfig();
    if (config == null) {
      return SyncResult(success: false, message: '未配置 WebDAV');
    }
    
    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final path = config['path']!;
      
      // 获取本地数据库文件路径
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'mooknote.db'));
      
      print('WebDAV: Looking for database at ${dbFile.path}');
      
      if (!await dbFile.exists()) {
        return SyncResult(success: false, message: '本地数据库不存在');
      }
      
      // 构建 WebDAV URL
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      var davUrl = '$baseUrl$path/mooknote.db';
      final davImagesUrl = '$baseUrl$path/images';
      
      final client = http.Client();
      int uploadedFiles = 0;
      int downloadedFiles = 0;
      int uploadedImages = 0;
      int downloadedImages = 0;
      
      try {
        // 1. 检查远程数据库是否存在
        final remoteDbInfo = await _getRemoteFileInfo(client, davUrl, username, password);
        
        if (direction == SyncDirection.upload) {
          // 仅上传模式
          print('WebDAV: Upload only mode');
          final result = await _uploadFile(client, davUrl, username, password, dbFile);
          if (result) {
            uploadedFiles++;
            // 同步图片
            final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.upload);
            uploadedImages = imageResult.uploaded;
            downloadedImages = imageResult.downloaded;
          }
        } else if (direction == SyncDirection.download) {
          // 仅下载模式
          print('WebDAV: Download only mode');
          if (remoteDbInfo != null) {
            final result = await _downloadFile(client, davUrl, username, password, dbFile);
            if (result) {
              downloadedFiles++;
              // 同步图片
              final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.download);
              uploadedImages = imageResult.uploaded;
              downloadedImages = imageResult.downloaded;
            }
          } else {
            return SyncResult(success: false, message: '远程数据库不存在');
          }
        } else {
          // 双向同步模式
          print('WebDAV: Bidirectional sync mode');
          
          if (remoteDbInfo == null) {
            // 远程不存在，直接上传
            print('WebDAV: Remote DB not found, uploading...');
            final result = await _uploadFile(client, davUrl, username, password, dbFile);
            if (result) {
              uploadedFiles++;
              // 上传所有图片
              final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.upload);
              uploadedImages = imageResult.uploaded;
            }
          } else {
            // 远程存在，比较修改时间
            final localModified = await dbFile.lastModified();
            final remoteModified = remoteDbInfo['modified'] as DateTime;
            
            print('WebDAV: Local modified: $localModified');
            print('WebDAV: Remote modified: $remoteModified');
            
            final timeDiff = localModified.difference(remoteModified).inSeconds;
            
            if (timeDiff > 10) {
              // 本地较新，上传
              print('WebDAV: Local is newer, uploading...');
              final result = await _uploadFile(client, davUrl, username, password, dbFile);
              if (result) {
                uploadedFiles++;
                // 同步图片
                final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.bidirectional);
                uploadedImages = imageResult.uploaded;
                downloadedImages = imageResult.downloaded;
              }
            } else if (timeDiff < -10) {
              // 远程较新，下载
              print('WebDAV: Remote is newer, downloading...');
              final result = await _downloadFile(client, davUrl, username, password, dbFile);
              if (result) {
                downloadedFiles++;
                // 同步图片
                final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.bidirectional);
                uploadedImages = imageResult.uploaded;
                downloadedImages = imageResult.downloaded;
              }
            } else {
              // 时间相近，视为相同
              print('WebDAV: Local and remote are similar, syncing images only...');
              final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.bidirectional);
              uploadedImages = imageResult.uploaded;
              downloadedImages = imageResult.downloaded;
            }
          }
        }
        
        // 保存同步时间
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
        // 如果下载了数据库文件，需要重新加载
        final needReload = downloadedFiles > 0;
        
        return SyncResult(
          success: true,
          message: '同步完成',
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
      print('WebDAV sync error: $e');
      return SyncResult(success: false, message: '同步失败: $e');
    }
  }
  
  /// 获取远程文件信息
  Future<Map<String, dynamic>?> _getRemoteFileInfo(
    http.Client client,
    String url,
    String username,
    String password,
  ) async {
    try {
      var request = http.Request('PROPFIND', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);
      request.headers['Depth'] = '0';
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          url = location;
          request = http.Request('PROPFIND', Uri.parse(url));
          request.headers['Authorization'] = _basicAuth(username, password);
          request.headers['Depth'] = '0';
          response = await client.send(request);
        }
      }
      
      if (response.statusCode == 207) {
        // 解析 PROPFIND 响应获取修改时间
        final body = await response.stream.bytesToString();
        // 简单解析，提取 getlastmodified
        final modifiedMatch = RegExp(r'<d:getlastmodified>([^<]+)</d:getlastmodified>', caseSensitive: false)
            .firstMatch(body);
        if (modifiedMatch != null) {
          final modifiedStr = modifiedMatch.group(1)!;
          final modified = HttpDate.parse(modifiedStr);
          return {'modified': modified, 'url': url};
        }
        return {'modified': DateTime.now(), 'url': url};
      }
      return null;
    } catch (e) {
      print('WebDAV: Get remote file info error: $e');
      return null;
    }
  }
  
  /// 上传文件
  Future<bool> _uploadFile(
    http.Client client,
    String url,
    String username,
    String password,
    File file,
  ) async {
    try {
      final fileBytes = await file.readAsBytes();
      
      var request = http.Request('PUT', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);
      request.headers['Content-Type'] = 'application/octet-stream';
      request.bodyBytes = fileBytes;
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('PUT', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          request.headers['Content-Type'] = 'application/octet-stream';
          request.bodyBytes = fileBytes;
          response = await client.send(request);
        }
      }
      
      return response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      print('WebDAV: Upload error: $e');
      return false;
    }
  }
  
  /// 下载文件
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
      
      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        await localFile.writeAsBytes(bytes);
        return true;
      }
      return false;
    } catch (e) {
      print('WebDAV: Download error: $e');
      return false;
    }
  }
  
  /// 同步图片
  Future<_ImageSyncResult> _syncImages(
    http.Client client,
    String imagesUrl,
    String username,
    String password,
    SyncDirection direction,
  ) async {
    int uploaded = 0;
    int downloaded = 0;
    
    try {
      // 获取本地图片目录
      final appDir = await getApplicationDocumentsDirectory();
      final localImagesDir = Directory('${appDir.path}/images');
      
      if (!await localImagesDir.exists()) {
        await localImagesDir.create(recursive: true);
      }
      
      // 获取本地图片列表
      final localImages = <String, File>{};
      if (await localImagesDir.exists()) {
        await for (final entity in localImagesDir.list()) {
          if (entity is File) {
            final name = p.basename(entity.path);
            localImages[name] = entity;
          }
        }
      }
      
      print('WebDAV: Local images: ${localImages.length}');
      
      // 获取远程图片列表
      final remoteImages = await _listRemoteImages(client, imagesUrl, username, password);
      print('WebDAV: Remote images: ${remoteImages.length}');
      
      if (direction == SyncDirection.upload) {
        // 仅上传：上传所有本地图片
        for (final entry in localImages.entries) {
          final remoteUrl = '$imagesUrl/${entry.key}';
          final success = await _uploadFile(client, remoteUrl, username, password, entry.value);
          if (success) uploaded++;
        }
      } else if (direction == SyncDirection.download) {
        // 仅下载：下载所有远程图片
        for (final name in remoteImages) {
          final remoteUrl = '$imagesUrl/$name';
          final localFile = File('${localImagesDir.path}/$name');
          final success = await _downloadFile(client, remoteUrl, username, password, localFile);
          if (success) downloaded++;
        }
      } else {
        // 双向同步：比较时间戳
        // 上传本地有但远程没有的
        for (final entry in localImages.entries) {
          if (!remoteImages.contains(entry.key)) {
            final remoteUrl = '$imagesUrl/${entry.key}';
            final success = await _uploadFile(client, remoteUrl, username, password, entry.value);
            if (success) uploaded++;
          }
        }
        
        // 下载远程有但本地没有的
        for (final name in remoteImages) {
          if (!localImages.containsKey(name)) {
            final remoteUrl = '$imagesUrl/$name';
            final localFile = File('${localImagesDir.path}/$name');
            final success = await _downloadFile(client, remoteUrl, username, password, localFile);
            if (success) downloaded++;
          }
        }
      }
    } catch (e) {
      print('WebDAV: Sync images error: $e');
    }
    
    return _ImageSyncResult(uploaded: uploaded, downloaded: downloaded);
  }
  
  /// 获取远程图片列表
  Future<List<String>> _listRemoteImages(
    http.Client client,
    String imagesUrl,
    String username,
    String password,
  ) async {
    final images = <String>[];
    
    try {
      // 创建图片目录（如果不存在）
      final mkcolRequest = http.Request('MKCOL', Uri.parse(imagesUrl));
      mkcolRequest.headers['Authorization'] = _basicAuth(username, password);
      await client.send(mkcolRequest);
      
      // 列出目录内容
      var request = http.Request('PROPFIND', Uri.parse(imagesUrl));
      request.headers['Authorization'] = _basicAuth(username, password);
      request.headers['Depth'] = '1';
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          imagesUrl = location;
          request = http.Request('PROPFIND', Uri.parse(imagesUrl));
          request.headers['Authorization'] = _basicAuth(username, password);
          request.headers['Depth'] = '1';
          response = await client.send(request);
        }
      }
      
      if (response.statusCode == 207) {
        final body = await response.stream.bytesToString();
        // 解析响应，提取文件名
        final hrefMatches = RegExp(r'<d:href>([^<]+)</d:href>', caseSensitive: false)
            .allMatches(body);
        for (final match in hrefMatches) {
          final href = match.group(1)!;
          final name = p.basename(href);
          if (name.isNotEmpty && name != 'images') {
            images.add(name);
          }
        }
      }
    } catch (e) {
      print('WebDAV: List remote images error: $e');
    }
    
    return images;
  }
  
  /// 获取上次同步时间
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastSyncKey);
    if (timeStr != null) {
      try {
        return DateTime.parse(timeStr);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Basic Auth 编码
  String _basicAuth(String username, String password) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }
}
