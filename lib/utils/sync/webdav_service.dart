import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../database_helper.dart';

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

/// 图片同步结果
class _ImageSyncResult {
  final int uploaded;
  final int downloaded;
  _ImageSyncResult({required this.uploaded, required this.downloaded});
}

/// WebDAV 服务类 - 支持实时同步（数据+图片分离存储）
class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  static WebDAVService get instance => _instance;
  
  WebDAVService._internal();
  
  static const String _configKey = 'webdav_config';
  static const String _lastSyncKey = 'webdav_last_sync';
  static const String _autoSyncKey = 'webdav_auto_sync';
  static const String _autoSyncIntervalKey = 'webdav_auto_sync_interval';
  static const String _lastDbModifiedKey = 'webdav_last_db_modified';
  
  // 默认自动同步间隔（分钟）
  static const int _defaultAutoSyncInterval = 5;
  
  Map<String, String>? _cachedConfig;
  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = false;
  int _autoSyncIntervalMinutes = _defaultAutoSyncInterval;
  
  // 文件系统监听
  StreamSubscription<FileSystemEvent>? _imagesDirWatcher;
  final Set<String> _pendingImageUploads = {};
  Timer? _debounceTimer;
  static const Duration _debounceDelay = Duration(seconds: 3);
  
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
    await prefs.remove(_lastDbModifiedKey);
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
      
      // print('WebDAV: Testing connection to $davUrl');
      
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
        // print('WebDAV: PROPFIND status ${propfindResponse.statusCode}');
        
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
          // print('WebDAV: Directory not found, trying to create...');
        } else {
          return {'success': false, 'message': '服务器返回错误: ${propfindResponse.statusCode}'};
        }
      } catch (e) {
        // print('WebDAV: PROPFIND error: $e');
      }
      
      try {
        final mkcolRequest = http.Request('MKCOL', Uri.parse(davUrl));
        mkcolRequest.headers['Authorization'] = _basicAuth(username, password);
        
        final mkcolResponse = await client.send(mkcolRequest);
        // print('WebDAV: MKCOL status ${mkcolResponse.statusCode}');
        
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
        // print('WebDAV: MKCOL error: $e');
        return {'success': false, 'message': '连接失败: $e'};
      } finally {
        client.close();
      }
    } catch (e) {
      // print('WebDAV test connection error: $e');
      return {'success': false, 'message': '连接失败: $e'};
    }
  }
  
  /// 同步数据（数据+图片分离存储，非压缩包方式）
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
      
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'mooknote.db'));
      
      if (!await dbFile.exists()) {
        return SyncResult(success: false, message: '本地数据库不存在');
      }
      
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final dbUrl = '$baseUrl$path/mooknote.db';
      final imagesUrl = '$baseUrl$path/images';
      
      final client = http.Client();
      int uploadedFiles = 0;
      int downloadedFiles = 0;
      int uploadedImages = 0;
      int downloadedImages = 0;
      bool needReload = false;
      
      try {
        if (direction == SyncDirection.upload) {
          // 上传数据库文件
          final dbSuccess = await _uploadFile(client, dbUrl, username, password, dbFile);
          if (dbSuccess) {
            uploadedFiles = 1;
          }
          
          // 上传所有图片
          final imageResult = await _syncImages(client, imagesUrl, username, password, SyncDirection.upload);
          uploadedImages = imageResult.uploaded;
          
        } else if (direction == SyncDirection.download) {
          // 下载数据库文件
          final tempDbFile = File('${dbFile.parent.path}/mooknote_download.db');
          final dbSuccess = await _downloadFile(client, dbUrl, username, password, tempDbFile);
          
          if (dbSuccess && await tempDbFile.exists()) {
            // 替换本地数据库
            await tempDbFile.copy(dbFile.path);
            await tempDbFile.delete();
            await DatabaseHelper.instance.reopenDatabase();
            downloadedFiles = 1;
            needReload = true;
          }
          
          // 下载所有图片
          final imageResult = await _syncImages(client, imagesUrl, username, password, SyncDirection.download);
          downloadedImages = imageResult.downloaded;
          
        } else if (direction == SyncDirection.bidirectional) {
          // 双向同步：分别同步数据库和图片
          final dbResult = await _syncDatabaseFile(client, dbUrl, username, password, dbFile);
          if (dbResult['uploaded'] == true) uploadedFiles = 1;
          if (dbResult['downloaded'] == true) {
            downloadedFiles = 1;
            needReload = true;
          }
          
          // 双向同步图片
          final imageResult = await _syncImagesBidirectional(client, imagesUrl, username, password);
          uploadedImages = imageResult.uploaded;
          downloadedImages = imageResult.downloaded;
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
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
      return SyncResult(success: false, message: '同步失败: $e');
    }
  }
  
  /// 同步数据库文件（双向）
  Future<Map<String, bool>> _syncDatabaseFile(
    http.Client client,
    String dbUrl,
    String username,
    String password,
    File localDbFile,
  ) async {
    final result = <String, bool>{};
    
    try {
      final remoteInfo = await _getRemoteFileInfo(client, dbUrl, username, password);
      final localModified = await localDbFile.lastModified();
      
      if (remoteInfo == null) {
        // 远程不存在，上传本地
        result['uploaded'] = await _uploadFile(client, dbUrl, username, password, localDbFile);
      } else {
        final remoteModified = remoteInfo['modified'] as DateTime;
        final timeDiff = localModified.difference(remoteModified).inSeconds;
        
        if (timeDiff > 10) {
          // 本地较新，上传
          result['uploaded'] = await _uploadFile(client, dbUrl, username, password, localDbFile);
        } else if (timeDiff < -10) {
          // 远程较新，下载
          final tempFile = File('${localDbFile.parent.path}/mooknote_temp.db');
          final success = await _downloadFile(client, dbUrl, username, password, tempFile);
          if (success) {
            await tempFile.copy(localDbFile.path);
            await tempFile.delete();
            await DatabaseHelper.instance.reopenDatabase();
            result['downloaded'] = true;
          }
        }
      }
    } catch (e) {
      // 忽略错误
    }
    
    return result;
  }
  
  /// 双向同步图片（基于文件存在性和修改时间）
  Future<_ImageSyncResult> _syncImagesBidirectional(
    http.Client client,
    String imagesUrl,
    String username,
    String password,
  ) async {
    int uploaded = 0;
    int downloaded = 0;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localImagesDir = Directory('${appDir.path}/images');
      
      if (!await localImagesDir.exists()) {
        await localImagesDir.create(recursive: true);
      }
      
      // 获取本地所有图片
      final localImages = <String, File>{};
      await _collectLocalImages(localImagesDir, localImages, '');
      
      // 获取远程所有图片
      final remoteImages = await _listRemoteImagesRecursive(client, imagesUrl, username, password, '');
      
      // 上传本地有但远程没有的
      for (final entry in localImages.entries) {
        final relativePath = entry.key;
        if (!remoteImages.contains(relativePath)) {
          final remoteUrl = '$imagesUrl/$relativePath';
          final parentPath = p.dirname(relativePath);
          if (parentPath != '.' && parentPath.isNotEmpty) {
            await _ensureRemoteDir(client, '$imagesUrl/$parentPath', username, password);
          }
          final success = await _uploadFile(client, remoteUrl, username, password, entry.value);
          if (success) uploaded++;
        }
      }
      
      // 下载远程有但本地没有的
      for (final relativePath in remoteImages) {
        if (!localImages.containsKey(relativePath)) {
          final remoteUrl = '$imagesUrl/$relativePath';
          final localFile = File('${localImagesDir.path}/$relativePath');
          await localFile.parent.create(recursive: true);
          final success = await _downloadFile(client, remoteUrl, username, password, localFile);
          if (success) downloaded++;
        }
      }
    } catch (e) {
      // 忽略错误
    }
    
    return _ImageSyncResult(uploaded: uploaded, downloaded: downloaded);
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
        final body = await response.stream.bytesToString();
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
      // print('WebDAV: Get remote file info error: $e');
      return null;
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
    
    // 如果正在自动同步，重启以应用新间隔
    if (_isAutoSyncEnabled) {
      await startAutoSync();
    }
  }
  
  /// 启动自动同步（带文件监听）
  Future<void> startAutoSync() async {
    // 停止现有的定时器和监听
    await stopAutoSync();
    
    final prefs = await SharedPreferences.getInstance();
    _isAutoSyncEnabled = true;
    _autoSyncIntervalMinutes = await getAutoSyncInterval();
    await prefs.setBool(_autoSyncKey, true);
    
    // 立即执行一次同步
    await _performIncrementalSync();
    
    // 设置定时器进行定期同步
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: _autoSyncIntervalMinutes),
      (timer) async {
        if (_isAutoSyncEnabled) {
          await _performIncrementalSync();
        }
      },
    );
    
    // 启动文件系统监听
    await _startFileWatcher();
  }
  
  /// 停止自动同步
  Future<void> stopAutoSync() async {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _isAutoSyncEnabled = false;
    
    // 停止文件监听
    await _imagesDirWatcher?.cancel();
    _imagesDirWatcher = null;
    _debounceTimer?.cancel();
    _pendingImageUploads.clear();
    
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
  
  /// 启动文件系统监听
  Future<void> _startFileWatcher() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // 监听图片目录的变化
      _imagesDirWatcher = imagesDir.watch(recursive: true).listen((event) {
        if (event is FileSystemCreateEvent || event is FileSystemModifyEvent) {
          final path = event.path;
          if (_isImageFile(path)) {
            _pendingImageUploads.add(path);
            _debounceUpload();
          }
        }
      });
    } catch (e) {
      // 文件监听可能不支持某些平台，忽略错误
    }
  }
  
  /// 检查是否是图片文件
  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }
  
  /// 防抖上传
  void _debounceUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () async {
      if (_pendingImageUploads.isNotEmpty && _isAutoSyncEnabled) {
        await _uploadPendingImages();
      }
    });
  }
  
  /// 上传待处理的图片
  Future<void> _uploadPendingImages() async {
    final config = await getConfig();
    if (config == null) return;
    
    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final path = config['path']!;
      
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final imagesUrl = '$baseUrl$path/images';
      
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      
      final client = http.Client();
      try {
        final uploads = _pendingImageUploads.toList();
        _pendingImageUploads.clear();
        
        for (final localPath in uploads) {
          final file = File(localPath);
          if (await file.exists()) {
            final relativePath = p.relative(localPath, from: imagesDir.path);
            final remoteUrl = '$imagesUrl/$relativePath';
            
            // 确保父目录存在
            final parentPath = p.dirname(relativePath);
            if (parentPath != '.' && parentPath.isNotEmpty) {
              await _ensureRemoteDir(client, '$imagesUrl/$parentPath', username, password);
            }
            
            await _uploadFile(client, remoteUrl, username, password, file);
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      // 忽略错误
    }
  }
  
  /// 执行增量同步（检查变更并上传）
  Future<SyncResult> _performIncrementalSync() async {
    final config = await getConfig();
    if (config == null) {
      return SyncResult(success: false, message: '未配置 WebDAV');
    }
    
    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final path = config['path']!;
      
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'mooknote.db'));
      
      if (!await dbFile.exists()) {
        return SyncResult(success: false, message: '本地数据库不存在');
      }
      
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final dbUrl = '$baseUrl$path/mooknote.db';
      final imagesUrl = '$baseUrl$path/images';
      
      final client = http.Client();
      int uploadedImages = 0;
      bool dbUploaded = false;
      
      try {
        // 检查数据库是否需要同步
        final prefs = await SharedPreferences.getInstance();
        final lastDbModifiedStr = prefs.getString(_lastDbModifiedKey);
        final currentDbModified = await dbFile.lastModified();
        
        bool needDbSync = true;
        if (lastDbModifiedStr != null) {
          final lastDbModified = DateTime.parse(lastDbModifiedStr);
          // 如果数据库修改时间在3秒内，认为没有变化
          if (currentDbModified.difference(lastDbModified).inSeconds.abs() < 3) {
            needDbSync = false;
          }
        }
        
        if (needDbSync) {
          // 上传数据库
          dbUploaded = await _uploadFile(client, dbUrl, username, password, dbFile);
          if (dbUploaded) {
            await prefs.setString(_lastDbModifiedKey, currentDbModified.toIso8601String());
          }
        }
        
        // 同步图片（双向）
        final imageResult = await _syncImagesBidirectional(client, imagesUrl, username, password);
        uploadedImages = imageResult.uploaded;
        
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
        return SyncResult(
          success: true,
          message: '自动同步完成',
          lastSyncTime: DateTime.now(),
          uploadedFiles: dbUploaded ? 1 : 0,
          uploadedImages: uploadedImages,
        );
      } finally {
        client.close();
      }
    } catch (e) {
      return SyncResult(success: false, message: '自动同步失败: $e');
    }
  }
  

  
  /// 同步图片（支持新的目录结构）
  /// 同步 images/movies/{id}/、images/books/{id}/、images/notes/{id}/ 下的所有图片
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
      
      // 递归获取本地所有图片文件（包含子目录）
      final localImages = <String, File>{}; // 相对路径 -> 文件
      await _collectLocalImages(localImagesDir, localImages, '');
      
      // print('WebDAV: Local images: ${localImages.length}');
      
      // 递归获取远程所有图片文件
      final remoteImages = await _listRemoteImagesRecursive(client, imagesUrl, username, password, '');
      // print('WebDAV: Remote images: ${remoteImages.length}');
      
      if (direction == SyncDirection.upload) {
        // 仅上传：上传所有本地图片
        // print('WebDAV: Starting upload of ${localImages.length} images...');
        for (final entry in localImages.entries) {
          final relativePath = entry.key;
          final remoteUrl = '$imagesUrl/$relativePath';
          
          // print('WebDAV: Uploading $relativePath...');
          
          // 确保远程父目录存在
          final parentPath = p.dirname(relativePath);
          if (parentPath != '.' && parentPath.isNotEmpty) {
            final parentUrl = '$imagesUrl/$parentPath';
            await _ensureRemoteDir(client, parentUrl, username, password);
          }
          
          final success = await _uploadFile(client, remoteUrl, username, password, entry.value);
          if (success) {
            uploaded++;
            // print('WebDAV: Uploaded $relativePath ($uploaded/${localImages.length})');
          }
        }
        // print('WebDAV: Upload complete - $uploaded/${localImages.length} images uploaded');
      } else if (direction == SyncDirection.download) {
        // 仅下载：下载所有远程图片
        // print('WebDAV: Starting download of ${remoteImages.length} images...');
        for (final relativePath in remoteImages) {
          final remoteUrl = '$imagesUrl/$relativePath';
          final localFile = File('${localImagesDir.path}/$relativePath');
          
          // print('WebDAV: Downloading $relativePath...');
          
          // 确保父目录存在
          await localFile.parent.create(recursive: true);
          final success = await _downloadFile(client, remoteUrl, username, password, localFile);
          if (success) {
            downloaded++;
            // print('WebDAV: Downloaded $relativePath ($downloaded/${remoteImages.length})');
          }
        }
        // print('WebDAV: Download complete - $downloaded/${remoteImages.length} images downloaded');
      }
    } catch (e) {
      // print('WebDAV: Sync images error: $e');
    }
    
    return _ImageSyncResult(uploaded: uploaded, downloaded: downloaded);
  }
  
  /// 递归收集本地图片文件
  Future<void> _collectLocalImages(Directory dir, Map<String, File> result, String relativePath) async {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        final path = relativePath.isEmpty ? fileName : '$relativePath/$fileName';
        result[path] = entity;
      } else if (entity is Directory) {
        final dirName = p.basename(entity.path);
        final newRelativePath = relativePath.isEmpty ? dirName : '$relativePath/$dirName';
        await _collectLocalImages(entity, result, newRelativePath);
      }
    }
  }
  
  /// 获取远程图片列表（递归获取所有子目录中的图片）
  Future<List<String>> _listRemoteImagesRecursive(
    http.Client client,
    String imagesUrl,
    String username,
    String password,
    String relativePath,
  ) async {
    final images = <String>[];
    final currentUrl = relativePath.isEmpty ? imagesUrl : '$imagesUrl/$relativePath';
    
    try {
      // 创建图片目录（如果不存在）
      final mkcolRequest = http.Request('MKCOL', Uri.parse(currentUrl));
      mkcolRequest.headers['Authorization'] = _basicAuth(username, password);
      await client.send(mkcolRequest);
      
      // 列出目录内容
      var request = http.Request('PROPFIND', Uri.parse(currentUrl));
      request.headers['Authorization'] = _basicAuth(username, password);
      request.headers['Depth'] = '1';
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          final newUrl = location;
          request = http.Request('PROPFIND', Uri.parse(newUrl));
          request.headers['Authorization'] = _basicAuth(username, password);
          request.headers['Depth'] = '1';
          response = await client.send(request);
        }
      }
      
      if (response.statusCode == 207) {
        final body = await response.stream.bytesToString();
        // print('WebDAV: PROPFIND response for $relativePath: ${body.length} bytes');
        // print('WebDAV: Response body: $body');
        
        // 解析响应，提取文件和目录
        final hrefMatches = RegExp(r'<d:href>([^<]+)</d:href>', caseSensitive: false)
            .allMatches(body);
        
        // print('WebDAV: Found ${hrefMatches.length} href entries');
        
        for (final match in hrefMatches) {
          final href = match.group(1)!;
          final name = p.basename(href);
          
          // 跳过当前目录自身（WebDAV PROPFIND 结果中第一个或某个 entry 是当前目录）
          if (name.isEmpty) continue;
          final currentUrlPath = Uri.parse(currentUrl).path;
          final currentDirName = p.basename(currentUrlPath);
          if (name == currentDirName) continue;
          
          // 检查是文件还是目录 - 查找这个 href 对应的 <D:response> 或 <d:response> 部分
          // 使用正则匹配，因为标签可能有属性（如 <D:response xmlns:D="DAV:">）
          int responseStart = -1;
          int responseEnd = -1;
          
          // 查找包含当前 href 的 response 块（向前找最近的 response 开始标签）
          final responseStartPattern = RegExp(r'<[Dd]:response\b', caseSensitive: false);
          final responseEndPattern = RegExp(r'</[Dd]:response>', caseSensitive: false);
          
          // 从 match.start 向前找最后一个 response 开始标签
          final allStarts = responseStartPattern.allMatches(body.substring(0, match.start)).toList();
          if (allStarts.isNotEmpty) {
            responseStart = allStarts.last.start;
          }
          
          // 从 match.start 向后找第一个 response 结束标签
          final endMatch = responseEndPattern.firstMatch(body.substring(match.start));
          if (endMatch != null) {
            responseEnd = match.start + endMatch.end;
          }
          
          bool isDirectory = false;
          
          if (responseStart != -1 && responseEnd != -1 && responseStart < responseEnd) {
            final responseSection = body.substring(responseStart, responseEnd);
            // 检查是否包含 <D:collection/> 或 <d:collection/> 标签
            isDirectory = responseSection.contains('<D:collection/>') || 
                         responseSection.contains('<d:collection/>') ||
                         responseSection.contains('<D:collection />') ||
                         responseSection.contains('<d:collection />');
          }
          
          // print('WebDAV: Found $name - isDirectory: $isDirectory');
          
          if (isDirectory) {
            // 递归获取子目录中的图片
            final newRelativePath = relativePath.isEmpty ? name : '$relativePath/$name';
            final subImages = await _listRemoteImagesRecursive(
              client, imagesUrl, username, password, newRelativePath,
            );
            images.addAll(subImages);
          } else {
            // 是文件，添加到列表
            final filePath = relativePath.isEmpty ? name : '$relativePath/$name';
            // print('WebDAV: Adding file to list: $filePath');
            images.add(filePath);
          }
        }
      } else {
        // print('WebDAV: PROPFIND failed with status ${response.statusCode} for $relativePath');
      }
    } catch (e) {
      // print('WebDAV: List remote images error: $e');
    }
    
    return images;
  }
  
  /// 确保远程目录存在
  Future<void> _ensureRemoteDir(
    http.Client client,
    String dirUrl,
    String username,
    String password,
  ) async {
    try {
      var request = http.Request('MKCOL', Uri.parse(dirUrl));
      request.headers['Authorization'] = _basicAuth(username, password);
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('MKCOL', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          response = await client.send(request);
        }
      }
      
      // 201 = 创建成功, 405 = 目录已存在, 409 = 父目录不存在需要先创建
      if (response.statusCode == 409) {
        // 需要创建父目录
        final parentPath = p.dirname(dirUrl);
        if (parentPath != dirUrl) {
          await _ensureRemoteDir(client, parentPath, username, password);
          // 再次尝试创建当前目录
          request = http.Request('MKCOL', Uri.parse(dirUrl));
          request.headers['Authorization'] = _basicAuth(username, password);
          await client.send(request);
        }
      }
    } catch (e) {
      // print('WebDAV: 创建目录失败: $e');
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
      // print('WebDAV: Upload error: $e');
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
      // print('WebDAV: Downloading from $url to ${localFile.path}');
      
      var request = http.Request('GET', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          // print('WebDAV: Following redirect to $location');
          request = http.Request('GET', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          response = await client.send(request);
        }
      }
      
      // print('WebDAV: Download response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        await localFile.writeAsBytes(bytes);
        // print('WebDAV: Downloaded ${bytes.length} bytes to ${localFile.path}');
        return true;
      } else {
        // print('WebDAV: Download failed with status ${response.statusCode}');
      }
      return false;
    } catch (e) {
      // print('WebDAV: Download error: $e');
      return false;
    }
  }
  
  /// Basic Auth 编码
  String _basicAuth(String username, String password) {
    final credentials = base64Encode(utf8.encode('$username:$password'));
    return 'Basic $credentials';
  }
}
