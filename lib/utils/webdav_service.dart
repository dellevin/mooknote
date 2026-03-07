import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'database_helper.dart';

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

/// WebDAV 服务类 - 支持自动定时备份
class WebDAVService {
  static final WebDAVService _instance = WebDAVService._internal();
  static WebDAVService get instance => _instance;
  
  WebDAVService._internal();
  
  static const String _configKey = 'webdav_config';
  static const String _lastSyncKey = 'webdav_last_sync';
  static const String _autoSyncKey = 'webdav_auto_sync';
  static const String _backupListKey = 'webdav_backup_list';
  
  static const int _maxBackupCount = 10; // 保留最近10条备份
  static const Duration _autoSyncInterval = Duration(minutes: 5); // 每5分钟自动备份
  
  Map<String, String>? _cachedConfig;
  Timer? _autoSyncTimer;
  bool _isAutoSyncEnabled = false;
  
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
    await prefs.remove(_backupListKey);
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
  
  /// 同步数据（使用 ZIP 格式，类似自动备份）
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
      final zipUrl = '$baseUrl$path/mooknote_backup.zip';
      
      final client = http.Client();
      int uploadedFiles = 0;
      int downloadedFiles = 0;
      int uploadedImages = 0;
      int downloadedImages = 0;
      
      try {
        if (direction == SyncDirection.upload) {
          // print('WebDAV: Upload ZIP mode');
          // 创建 ZIP 备份
          final zipBytes = await _createFullBackupZip(dbFile);
          if (zipBytes == null) {
            return SyncResult(success: false, message: '创建备份 ZIP 失败');
          }
          
          // 上传 ZIP 文件
          final result = await _uploadBytes(client, zipUrl, username, password, zipBytes);
          if (result) {
            uploadedFiles = 1;
            // 统计图片数量
            final appDir = await getApplicationDocumentsDirectory();
            final imagesDir = Directory('${appDir.path}/images');
            if (await imagesDir.exists()) {
              uploadedImages = await _countImagesInDir(imagesDir);
            }
            // print('WebDAV: ZIP uploaded successfully, images: $uploadedImages');
          } else {
            return SyncResult(success: false, message: '上传 ZIP 失败');
          }
        } else if (direction == SyncDirection.download) {
          // print('WebDAV: Download ZIP mode');
          // 下载 ZIP 文件
          final zipFile = File('${dbFile.parent.path}/mooknote_backup_download.zip');
          final result = await _downloadFile(client, zipUrl, username, password, zipFile);
          
          if (result && await zipFile.exists()) {
            downloadedFiles = 1;
            // 解压 ZIP 文件
            final extractResult = await _extractBackupZip(zipFile, dbFile);
            if (extractResult) {
              // 重新打开数据库
              await DatabaseHelper.instance.reopenDatabase();
              // 统计下载的图片数量
              final appDir = await getApplicationDocumentsDirectory();
              final imagesDir = Directory('${appDir.path}/images');
              if (await imagesDir.exists()) {
                downloadedImages = await _countImagesInDir(imagesDir);
              }
              // print('WebDAV: ZIP downloaded and extracted successfully, images: $downloadedImages');
            } else {
              return SyncResult(success: false, message: '解压 ZIP 失败');
            }
            // 删除临时 ZIP 文件
            await zipFile.delete();
          } else {
            return SyncResult(success: false, message: '远程备份不存在或下载失败');
          }
        } else if (direction == SyncDirection.bidirectional) {
          // 双向同步：比较时间戳决定上传还是下载
          // print('WebDAV: Bidirectional sync mode (ZIP)');
          final remoteZipInfo = await _getRemoteFileInfo(client, zipUrl, username, password);
          
          if (remoteZipInfo == null) {
            // 远程不存在，直接上传
            // print('WebDAV: Remote ZIP not found, uploading...');
            return await syncData(direction: SyncDirection.upload);
          } else {
            // 远程存在，比较修改时间
            final localModified = await dbFile.lastModified();
            final remoteModified = remoteZipInfo['modified'] as DateTime;
            
            // print('WebDAV: Local modified: $localModified');
            // print('WebDAV: Remote modified: $remoteModified');
            
            final timeDiff = localModified.difference(remoteModified).inSeconds;
            
            if (timeDiff > 10) {
              // 本地较新，上传
              // print('WebDAV: Local is newer, uploading...');
              return await syncData(direction: SyncDirection.upload);
            } else if (timeDiff < -10) {
              // 远程较新，下载
              // print('WebDAV: Remote is newer, downloading...');
              return await syncData(direction: SyncDirection.download);
            } else {
              // 时间相近，无需同步
              // print('WebDAV: Local and remote are similar, no sync needed');
              return SyncResult(
                success: true,
                message: '本地和远程数据相同，无需同步',
                lastSyncTime: DateTime.now(),
              );
            }
          }
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
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
      // print('WebDAV sync error: $e');
      return SyncResult(success: false, message: '同步失败: $e');
    }
  }
  
  /// 统计目录中的图片数量
  Future<int> _countImagesInDir(Directory dir) async {
    int count = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        count++;
      }
    }
    return count;
  }
  
  /// 解压备份 ZIP 文件
  Future<bool> _extractBackupZip(File zipFile, File dbFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      
      // 解压数据库文件
      final dbArchiveFile = archive.findFile('mooknote.db');
      if (dbArchiveFile != null) {
        await dbFile.writeAsBytes(dbArchiveFile.content as List<int>);
        // print('WebDAV: Extracted database file');
      }
      
      // 解压图片文件
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      
      int imageCount = 0;
      for (final archiveFile in archive) {
        if (archiveFile.name.startsWith('images/')) {
          final relativePath = archiveFile.name.substring(7); // 去掉 'images/' 前缀
          final localFile = File('${imagesDir.path}/$relativePath');
          
          // 确保父目录存在
          await localFile.parent.create(recursive: true);
          
          // 写入文件
          await localFile.writeAsBytes(archiveFile.content as List<int>);
          imageCount++;
        }
      }
      // print('WebDAV: Extracted $imageCount images');
      
      return true;
    } catch (e) {
      // print('WebDAV: Extract ZIP error: $e');
      return false;
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
  
  /// 启动自动同步
  Future<void> startAutoSync() async {
    if (_autoSyncTimer != null) {
      _autoSyncTimer!.cancel();
    }
    
    final prefs = await SharedPreferences.getInstance();
    _isAutoSyncEnabled = true;
    await prefs.setBool(_autoSyncKey, true);
    
    // 立即执行一次备份
    await performTimedBackup();
    
    // 设置定时器，每5分钟执行一次
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) async {
      if (_isAutoSyncEnabled) {
        await performTimedBackup();
      }
    });
    
    // print('WebDAV: 自动备份已启动，每5分钟执行一次');
  }
  
  /// 停止自动同步
  Future<void> stopAutoSync() async {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    _isAutoSyncEnabled = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, false);
    
    // print('WebDAV: 自动备份已停止');
  }
  
  /// 检查自动同步状态
  Future<bool> isAutoSyncEnabled() async {
    if (_autoSyncTimer != null) {
      return _isAutoSyncEnabled;
    }
    
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? false;
  }
  
  /// 执行定时备份（按时间命名，保留最近10条）
  Future<SyncResult> performTimedBackup() async {
    final config = await getConfig();
    if (config == null) {
      return SyncResult(success: false, message: '未配置 WebDAV');
    }
    
    try {
      final url = config['url']!;
      final username = config['username']!;
      final password = config['password']!;
      final basePath = config['path']!;
      
      // 获取本地数据库文件路径
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'mooknote.db'));
      
      if (!await dbFile.exists()) {
        return SyncResult(success: false, message: '本地数据库不存在');
      }
      
      // 构建 WebDAV URL（使用时间戳命名）
      final baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final timestamp = _formatTimestamp(DateTime.now());
      final backupFileName = 'mooknote_$timestamp.zip';
      final davUrl = '$baseUrl$basePath/$backupFileName';
      final davImagesUrl = '$baseUrl$basePath/images';
      
      // print('WebDAV: 开始定时备份到 $davUrl');
      
      final client = http.Client();
      int uploadedImages = 0;
      
      try {
        // 1. 创建完整的备份 ZIP（包含数据库和图片）
        final zipBytes = await _createFullBackupZip(dbFile);
        if (zipBytes == null) {
          return SyncResult(success: false, message: '创建备份文件失败');
        }
        
        // 2. 上传备份文件
        final success = await _uploadBytes(client, davUrl, username, password, zipBytes);
        if (!success) {
          return SyncResult(success: false, message: '上传备份文件失败');
        }
        
        // 3. 同步图片到 images 目录
        final imageResult = await _syncImages(client, davImagesUrl, username, password, SyncDirection.upload);
        uploadedImages = imageResult.uploaded;
        
        // 4. 更新备份列表并清理旧备份
        await _updateBackupListAndCleanup(client, baseUrl, basePath, username, password, backupFileName);
        
        // 5. 保存同步时间
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        
        // print('WebDAV: 定时备份完成 - $backupFileName');
        
        return SyncResult(
          success: true,
          message: '备份完成: $backupFileName',
          lastSyncTime: DateTime.now(),
          uploadedFiles: 1,
          uploadedImages: uploadedImages,
          needReload: false,
        );
      } finally {
        client.close();
      }
    } catch (e) {
      // print('WebDAV: 定时备份错误: $e');
      return SyncResult(success: false, message: '备份失败: $e');
    }
  }
  
  /// 创建完整的备份 ZIP（包含数据库和所有图片）
  /// 支持新的图片存储结构：images/movies/{id}/、images/books/{id}/、images/notes/{id}/
  Future<List<int>?> _createFullBackupZip(File dbFile) async {
    try {
      final archive = Archive();
      
      // 添加数据库文件
      final dbBytes = await dbFile.readAsBytes();
      archive.addFile(ArchiveFile('mooknote.db', dbBytes.length, dbBytes));
      
      // 添加所有图片（递归遍历子目录）
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      
      if (await imagesDir.exists()) {
        await _addImagesToArchive(archive, imagesDir, 'images');
      }
      
      // 添加备份信息
      final backupInfo = {
        'version': 2,
        'backupTime': DateTime.now().toIso8601String(),
        'appName': 'MookNote',
        'type': 'timed_backup',
        'structure': 'hierarchical', // 标记为分层结构
      };
      final infoJson = jsonEncode(backupInfo);
      final infoBytes = utf8.encode(infoJson);
      archive.addFile(ArchiveFile('backup_info.json', infoBytes.length, infoBytes));
      
      // 压缩
      final zipEncoder = ZipEncoder();
      return zipEncoder.encode(archive);
    } catch (e) {
      // print('WebDAV: 创建备份 ZIP 失败: $e');
      return null;
    }
  }
  
  /// 递归添加图片到归档
  Future<void> _addImagesToArchive(Archive archive, Directory dir, String relativePath) async {
    await for (final entity in dir.list()) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        final bytes = await entity.readAsBytes();
        final archivePath = '$relativePath/$fileName';
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
        // print('WebDAV: 添加文件到备份 - $archivePath');
      } else if (entity is Directory) {
        final dirName = p.basename(entity.path);
        await _addImagesToArchive(archive, entity, '$relativePath/$dirName');
      }
    }
  }
  
  /// 更新备份列表并清理旧备份
  Future<void> _updateBackupListAndCleanup(
    http.Client client,
    String baseUrl,
    String basePath,
    String username,
    String password,
    String newBackupName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 获取现有备份列表
      List<String> backupList = [];
      final listJson = prefs.getString(_backupListKey);
      if (listJson != null) {
        backupList = List<String>.from(jsonDecode(listJson));
      }
      
      // 添加新备份
      backupList.add(newBackupName);
      
      // 如果超过10条，删除最旧的备份
      while (backupList.length > _maxBackupCount) {
        final oldBackup = backupList.removeAt(0);
        final deleteUrl = '$baseUrl$basePath/$oldBackup';
        await _deleteFile(client, deleteUrl, username, password);
        // print('WebDAV: 删除旧备份 $oldBackup');
      }
      
      // 保存更新后的列表
      await prefs.setString(_backupListKey, jsonEncode(backupList));
      
      // print('WebDAV: 备份列表已更新，当前 ${backupList.length} 个备份');
    } catch (e) {
      // print('WebDAV: 更新备份列表失败: $e');
    }
  }
  
  /// 删除远程文件
  Future<void> _deleteFile(
    http.Client client,
    String url,
    String username,
    String password,
  ) async {
    try {
      var request = http.Request('DELETE', Uri.parse(url));
      request.headers['Authorization'] = _basicAuth(username, password);
      
      var response = await client.send(request);
      
      // 处理重定向
      if (response.statusCode == 301 || response.statusCode == 302 ||
          response.statusCode == 307 || response.statusCode == 308) {
        final location = response.headers['location'];
        if (location != null) {
          request = http.Request('DELETE', Uri.parse(location));
          request.headers['Authorization'] = _basicAuth(username, password);
          response = await client.send(request);
        }
      }
    } catch (e) {
      // print('WebDAV: 删除文件失败: $e');
    }
  }
  
  /// 上传字节数据
  Future<bool> _uploadBytes(
    http.Client client,
    String url,
    String username,
    String password,
    List<int> bytes,
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
      
      return response.statusCode == 201 || response.statusCode == 204;
    } catch (e) {
      // print('WebDAV: 上传失败: $e');
      return false;
    }
  }
  
  /// 格式化时间戳用于文件名
  String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.year}${_pad(dateTime.month)}${_pad(dateTime.day)}_${_pad(dateTime.hour)}${_pad(dateTime.minute)}${_pad(dateTime.second)}';
  }
  
  String _pad(int number) {
    return number.toString().padLeft(2, '0');
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
          
          // 跳过当前目录自身
          if (name.isEmpty) continue;
          if (relativePath.isEmpty && name == 'images') continue;
          
          // 检查是文件还是目录 - 查找这个 href 对应的 <D:response> 部分（Apache 使用大写 D）
          final responseStart = body.lastIndexOf('<D:response>', match.start);
          final responseEnd = body.indexOf('</D:response>', match.start);
          bool isDirectory = false;
          
          if (responseStart != -1 && responseEnd != -1 && responseStart < responseEnd) {
            final responseSection = body.substring(responseStart, responseEnd);
            // print('WebDAV: Checking $name in section: ${responseSection.substring(0, responseSection.length > 300 ? 300 : responseSection.length)}');
            // 检查是否包含 <D:collection/> 或 <d:collection/> 标签（Apache WebDAV 使用大写 D）
            isDirectory = responseSection.contains('<D:collection/>') || 
                         responseSection.contains('<d:collection/>') ||
                         responseSection.contains('<D:collection />') ||
                         responseSection.contains('<d:collection />');
            // print('WebDAV: $name contains <D:collection/>: ${responseSection.contains('<D:collection/>')}');
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
