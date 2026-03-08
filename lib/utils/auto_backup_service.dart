import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';

/// 自动备份服务 - 定时自动备份到下载目录
class AutoBackupService {
  static final AutoBackupService instance = AutoBackupService._init();
  
  AutoBackupService._init();
  
  Timer? _timer;
  bool _isRunning = false;
  
  static const String _prefsKey = 'auto_backup_enabled';
  static const String _backupDirName = 'mooknote';
  static const int _maxBackups = 10;
  static const Duration _backupInterval = Duration(minutes: 2);
  
  /// 是否正在运行
  bool get isRunning => _isRunning;
  
  /// 获取自动备份状态
  Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }
  
  /// 设置自动备份状态
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    
    if (enabled) {
      await start();
    } else {
      await stop();
    }
  }
  
  /// 启动自动备份
  Future<void> start() async {
    if (_isRunning) return;
    
    // 立即执行一次备份
    await _performBackup();
    
    // 启动定时器
    _timer = Timer.periodic(_backupInterval, (_) async {
      await _performBackup();
    });
    
    _isRunning = true;
  }
  
  /// 停止自动备份
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }
  
  /// 执行备份
  Future<void> _performBackup() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (backupDir == null) {
        print('AutoBackup: 无法获取备份目录');
        return;
      }
      
      // 确保备份目录存在
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      // 导出数据
      final result = await BackupService.instance.exportDataForAutoBackup();
      
      if (!result.success) {
        print('AutoBackup: 导出失败 - ${result.errorMessage}');
        return;
      }
      
      // 生成备份文件名
      final fileName = 'auto_backup_${_formatDateTime(DateTime.now())}.zip';
      final backupFile = File(path.join(backupDir.path, fileName));
      
      // 写入备份文件
      await backupFile.writeAsBytes(result.zipBytes!);
      
      print('AutoBackup: 备份成功 - ${backupFile.path}');
      
      // 清理旧备份，只保留最新的10个
      await _cleanupOldBackups(backupDir);
      
    } catch (e) {
      print('AutoBackup: 备份失败 - $e');
    }
  }
  
  /// 获取备份目录（下载目录/mooknote）
  Future<Directory?> _getBackupDirectory() async {
    try {
      // 尝试获取下载目录
      Directory? downloadDir;
      
      if (Platform.isAndroid) {
        // Android: 使用外部存储的下载目录
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // 通常路径是 /storage/emulated/0/Android/data/.../files
          // 我们需要找到真正的下载目录
          final path = externalDir.path;
          final downloadPath = path.replaceAll(
            '/Android/data/${externalDir.uri.pathSegments[externalDir.uri.pathSegments.length - 3]}/files',
            '/Download',
          );
          downloadDir = Directory('$downloadPath/$_backupDirName');
        }
      } else if (Platform.isIOS) {
        // iOS: 使用文档目录
        final docDir = await getApplicationDocumentsDirectory();
        downloadDir = Directory('${docDir.path}/$_backupDirName');
      } else {
        // 桌面端: 使用下载目录
        final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
        if (home != null) {
          downloadDir = Directory('$home/Downloads/$_backupDirName');
        }
      }
      
      return downloadDir;
    } catch (e) {
      print('AutoBackup: 获取备份目录失败 - $e');
      return null;
    }
  }
  
  /// 清理旧备份，只保留最新的10个
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .cast<File>()
          .toList();
      
      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      
      // 删除超过10个的旧备份
      if (files.length > _maxBackups) {
        for (var i = _maxBackups; i < files.length; i++) {
          try {
            await files[i].delete();
            print('AutoBackup: 删除旧备份 - ${files[i].path}');
          } catch (e) {
            print('AutoBackup: 删除旧备份失败 - $e');
          }
        }
      }
    } catch (e) {
      print('AutoBackup: 清理旧备份失败 - $e');
    }
  }
  
  /// 获取备份文件列表
  Future<List<File>> getBackupFiles() async {
    try {
      final backupDir = await _getBackupDirectory();
      if (backupDir == null || !await backupDir.exists()) {
        return [];
      }
      
      final files = await backupDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .cast<File>()
          .toList();
      
      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      
      return files;
    } catch (e) {
      print('AutoBackup: 获取备份列表失败 - $e');
      return [];
    }
  }
  
  /// 获取备份目录路径
  Future<String?> getBackupDirectoryPath() async {
    final dir = await _getBackupDirectory();
    return dir?.path;
  }
  
  /// 格式化日期时间用于文件名
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}${_pad(dateTime.month)}${_pad(dateTime.day)}_${_pad(dateTime.hour)}${_pad(dateTime.minute)}${_pad(dateTime.second)}';
  }
  
  String _pad(int number) {
    return number.toString().padLeft(2, '0');
  }
}
