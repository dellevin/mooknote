import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../user_prefs.dart';
import '../database_helper.dart';

/// 服务端实时同步服务
/// - 开启时：上传一次本地数据到服务器，后续 CRUD 走 API
/// - 关闭时：从服务器下载数据到本地，切换本地数据库
class ServerSyncService {
  static final ServerSyncService instance = ServerSyncService._();
  ServerSyncService._();

  final UserPrefs _prefs = UserPrefs();
  bool _isSyncing = false;

  bool get isConfigured {
    return _prefs.syncServerUrl.isNotEmpty && _prefs.syncActivationCode.isNotEmpty;
  }

  Future<Map<String, dynamic>?> checkActivation() async {
    final url = _prefs.syncServerUrl;
    final code = _prefs.syncActivationCode;
    final deviceId = _prefs.deviceId;
    if (url.isEmpty || code.isEmpty || deviceId.isEmpty) return null;
    try {
      final resp = await http.post(
        Uri.parse('$url/api/activate'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code","device_id":"$deviceId"}',
      ).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200
          ? _jsonDecode(resp.body)
          : {'valid': false, 'error': '激活码无效'};
    } catch (_) {
      return {'valid': false, 'error': '无法连接服务器'};
    }
  }

  Map<String, dynamic>? _jsonDecode(String s) {
    try { final d = jsonDecode(s); return d is Map<String, dynamic> ? d : null; } catch (_) { return null; }
  }

  /// 开启同步：上传本地数据到服务器
  Future<bool> uploadToServer() async {
    if (!isConfigured || _isSyncing) return false;
    _isSyncing = true;
    try {
      final url = _prefs.syncServerUrl;
      final code = _prefs.syncActivationCode;
      final deviceId = _prefs.deviceId;

      final dbPath = await DatabaseHelper.instance.databasePath;
      if (dbPath == null || !File(dbPath).existsSync()) {
        debugPrint('[Sync] 数据库文件不存在');
        return false;
      }

      final request = http.MultipartRequest('POST', Uri.parse('$url/api/sync/upload'));
      request.fields['code'] = code;
      request.fields['device_id'] = deviceId;
      request.files.add(await http.MultipartFile.fromPath('database', dbPath));

      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(appDir.path, 'images'));
      if (await imgDir.exists()) {
        await for (final entity in imgDir.list(recursive: true)) {
          if (entity is File) {
            final relPath = p.relative(entity.path, from: appDir.path).replaceAll('\\', '/');
            request.files.add(await http.MultipartFile('images', entity.readAsBytes().asStream(), await entity.length(), filename: relPath));
          }
        }
      }

      final avatarsDir = Directory(p.join(appDir.path, 'avatars'));
      if (await avatarsDir.exists()) {
        await for (final entity in avatarsDir.list()) {
          if (entity is File) {
            final relPath = p.relative(entity.path, from: appDir.path).replaceAll('\\', '/');
            request.files.add(await http.MultipartFile('images', entity.readAsBytes().asStream(), await entity.length(), filename: relPath));
          }
        }
      }

      final resp = await request.send().timeout(const Duration(seconds: 300));
      if (resp.statusCode == 200) {
        debugPrint('[Sync] 上传成功');
        return true;
      }
      debugPrint('[Sync] 上传失败 HTTP ${resp.statusCode}');
    } catch (e) {
      debugPrint('[Sync] 上传异常: $e');
    } finally {
      _isSyncing = false;
    }
    return false;
  }

  /// 关闭同步：从服务器下载数据到本地
  Future<bool> downloadToLocal() async {
    if (!isConfigured || _isSyncing) return false;
    _isSyncing = true;
    try {
      final url = _prefs.syncServerUrl;
      final code = _prefs.syncActivationCode;
      final deviceId = _prefs.deviceId;

      final infoResp = await http.post(
        Uri.parse('$url/api/sync/info'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code","device_id":"$deviceId"}',
      ).timeout(const Duration(seconds: 15));
      if (infoResp.statusCode != 200) return false;

      final info = _jsonDecode(infoResp.body);
      if (info == null || info['has_backup'] != true) return false;

      final dbResp = await http.post(
        Uri.parse('$url/api/sync/download/database'),
        headers: {'Content-Type': 'application/json'},
        body: '{"code":"$code"}',
      ).timeout(const Duration(seconds: 120));
      if (dbResp.statusCode != 200) return false;

      final dbPath = await DatabaseHelper.instance.databasePath;
      if (dbPath != null) {
        await DatabaseHelper.instance.close();
        await File(dbPath).writeAsBytes(dbResp.bodyBytes);
        await DatabaseHelper.instance.reopen();
      }

      final images = (info['images'] as List<dynamic>?)
          ?.map((e) => e is Map ? {'name': e['name'] as String, 'rel_path': e['rel_path'] as String} : null)
          .where((e) => e != null).cast<Map<String, String>>().toList() ?? [];

      final appDir = await getApplicationDocumentsDirectory();
      for (final img in images) {
        try {
          final relPath = img['rel_path']!;
          final imgResp = await http.get(
            Uri.parse('$url/api/sync/download/image/$code/$relPath'),
          ).timeout(const Duration(seconds: 30));
          if (imgResp.statusCode == 200) {
            final dest = File(p.join(appDir.path, relPath));
            await dest.parent.create(recursive: true);
            await dest.writeAsBytes(imgResp.bodyBytes);
          }
        } catch (_) {}
      }

      debugPrint('[Sync] 下载到本地完成');
      return true;
    } catch (e) {
      debugPrint('[Sync] 下载到本地异常: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }
}
