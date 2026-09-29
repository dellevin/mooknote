import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../utils/excel_exporter.dart';
import '../utils/server_config.dart';
import '../utils/user_prefs.dart';
import 'sync/cache_cleaner.dart';

/// 在线带图导出各阶段（UI 据此展示进度文案）
enum ServerExportStage { packing, uploading, queued, processing, downloading }

typedef ServerExportProgress = void Function(
  ServerExportStage stage, {
  int percent,
  int position,
});

class ServerExportException implements Exception {
  final String message;
  ServerExportException(this.message);
  @override
  String toString() => message;
}

/// 在线带图 Excel 导出：
/// 本地打"数据库 + 该类型图片"精简包 → 上传 → 服务器双 Token 鉴权排队生成 → 轮询 → 下载结果
class ServerExportService {
  /// 导出类型 → 服务端/图片目录标识
  static const typeDirs = {
    'movies': 'movies',
    'books': 'books',
    'games': 'games',
    'notes': 'notes',
  };

  static const _uploadTimeout = Duration(minutes: 10);
  static const _responseTimeout = Duration(seconds: 60);
  static const _pollTimeout = Duration(minutes: 8);
  static const _pollInterval = Duration(seconds: 2);
  static const _downloadTimeout = Duration(minutes: 5);

  /// 执行完整流程，成功返回下载好的 xlsx 文件
  static Future<File> export({
    required String type,
    bool withReviews = false,
    required ServerExportProgress onProgress,
  }) async {
    final prefs = UserPrefs();
    final movieToken = prefs.movieSearchToken.trim();
    final bookToken = prefs.bookSearchToken.trim();
    final deviceId = prefs.deviceId.trim();
    if (movieToken.isEmpty || bookToken.isEmpty) {
      throw ServerExportException('需要先在增强搜索设置中填写影视和书籍 Token'.tr);
    }
    if (deviceId.isEmpty) {
      throw ServerExportException('设备信息未就绪，请稍后重试'.tr);
    }
    final typeDir = typeDirs[type];
    if (typeDir == null) {
      throw ServerExportException('不支持的导出类型'.tr);
    }

    // ① 打包（先把 WAL 合并进主库文件，保证 zip 里的 db 是完整数据）
    onProgress(ServerExportStage.packing);
    final db = await DatabaseHelper.instance.database;
    await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final dbPath = await DatabaseHelper.instance.databasePath;
    if (dbPath == null || !File(dbPath).existsSync()) {
      throw ServerExportException('数据库文件不存在'.tr);
    }
    // 只带该类型在 DB 中有记录的图片（口径与缓存清理一致，避免打包孤儿图片）
    final allDbImages = await CacheCleaner.instance.getAllDbImagePaths();
    final marker = '/images/$typeDir/';
    final imagePaths = allDbImages
        .where((path) => path.replaceAll('\\', '/').contains(marker))
        .toList();

    final tempDir = await getTemporaryDirectory();
    final zipPath = await compute(
      _packZip,
      _PackParams(
        dbPath: dbPath,
        imagePaths: imagePaths,
        tempDirPath: tempDir.path,
      ),
    );

    final client = http.Client();
    try {
      // ② 上传（带进度）
      final taskId = await _upload(
        client: client,
        zipPath: zipPath,
        deviceId: deviceId,
        movieToken: movieToken,
        bookToken: bookToken,
        type: type,
        withReviews: withReviews,
        onProgress: onProgress,
      );

      // ③ 轮询任务状态
      await _waitDone(
        client: client,
        taskId: taskId,
        deviceId: deviceId,
        onProgress: onProgress,
      );

      // ④ 下载结果
      onProgress(ServerExportStage.downloading);
      return await _download(client: client, taskId: taskId, deviceId: deviceId, type: type);
    } finally {
      client.close();
      try {
        File(zipPath).deleteSync();
      } catch (_) {}
    }
  }

  static Future<String> _upload({
    required http.Client client,
    required String zipPath,
    required String deviceId,
    required String movieToken,
    required String bookToken,
    required String type,
    required bool withReviews,
    required ServerExportProgress onProgress,
  }) async {
    final uri = Uri.parse('${ServerConfig.apiBase}/export/excel');
    final request = http.MultipartRequest('POST', uri)
      ..fields['device_hash'] = deviceId
      ..fields['movie_token'] = movieToken
      ..fields['book_token'] = bookToken
      ..fields['type'] = type
      ..fields['lang'] = AppStrings.isEnglish ? 'en' : 'zh'
      ..fields['with_reviews'] = withReviews ? '1' : '0'
      ..files.add(await http.MultipartFile.fromPath('file', zipPath));

    // MultipartRequest.finalize() 是字节流，包一层 StreamedRequest 统计已发字节得到上传进度。
    // 注意：必须先 finalize()——http 1.x 在 finalize() 里才把带 boundary 的
    // content-type 写进 request.headers，提前复制 headers 会丢 content-type，
    // 服务端解析不到任何表单字段。
    final bodyStream = request.finalize();
    final streamed = http.StreamedRequest('POST', uri);
    streamed.headers.addAll(request.headers);
    final total = request.contentLength;
    streamed.contentLength = total;
    var sent = 0;
    Timer? responseTimer;
    var responseTimedOut = false;
    bodyStream.listen(
      (chunk) {
        sent += chunk.length;
        streamed.sink.add(chunk);
        if (total > 0) {
          onProgress(ServerExportStage.uploading, percent: (sent * 100) ~/ total);
        }
      },
      onDone: () {
        streamed.sink.close();
        // 请求体发完后若服务器迟迟不回响应头，说明后端异常——
        // 主动断开，避免界面一直卡在"正在上传100%"
        responseTimer = Timer(_responseTimeout, () {
          responseTimedOut = true;
          client.close();
        });
      },
      onError: streamed.sink.addError,
    );

    final http.StreamedResponse response;
    try {
      response = await client.send(streamed).timeout(_uploadTimeout);
    } on TimeoutException {
      throw ServerExportException('上传超时，请检查网络后重试'.tr);
    } catch (_) {
      throw ServerExportException(
        responseTimedOut ? '服务器无响应，请稍后重试'.tr : '网络连接失败，请检查网络后重试'.tr,
      );
    } finally {
      responseTimer?.cancel();
    }
    final body = await http.Response.fromStream(response);
    final json = _parseJson(body.body);
    if (json['code'] == 0 && json['data'] is Map) {
      final taskId = (json['data']['task_id'] ?? '').toString();
      if (taskId.isNotEmpty) return taskId;
    }
    throw ServerExportException(
      (json['message'] ?? '上传失败（HTTP ${response.statusCode}）').toString(),
    );
  }

  static Future<void> _waitDone({
    required http.Client client,
    required String taskId,
    required String deviceId,
    required ServerExportProgress onProgress,
  }) async {
    final deadline = DateTime.now().add(_pollTimeout);
    final uri = Uri.parse('${ServerConfig.apiBase}/export/excel/status').replace(
      queryParameters: {'task_id': taskId, 'device_hash': deviceId},
    );
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(_pollInterval);
      try {
        final resp = await client.get(uri).timeout(const Duration(seconds: 15));
        final json = _parseJson(resp.body);
        if (json['code'] == 0 && json['data'] is Map) {
          final data = json['data'];
          final status = (data['status'] ?? '').toString();
          switch (status) {
            case 'done':
              return;
            case 'failed':
              throw ServerExportException(
                (data['error'] ?? '服务器处理失败'.tr).toString(),
              );
            case 'queued':
              onProgress(ServerExportStage.queued, position: (data['position'] ?? 0) as int);
            default:
              onProgress(ServerExportStage.processing);
          }
        }
      } on ServerExportException {
        rethrow;
      } catch (_) {
        // 网络抖动：截止时间前继续轮询
      }
    }
    throw ServerExportException('服务器处理超时，请稍后重试'.tr);
  }

  static Future<File> _download({
    required http.Client client,
    required String taskId,
    required String deviceId,
    required String type,
  }) async {
    final uri = Uri.parse('${ServerConfig.apiBase}/export/excel/download').replace(
      queryParameters: {'task_id': taskId, 'device_hash': deviceId},
    );
    final resp = await client.get(uri).timeout(_downloadTimeout);
    if (resp.statusCode != 200) {
      String message = '下载失败（HTTP ${resp.statusCode}）';
      try {
        final json = jsonDecode(resp.body);
        if (json is Map && json['message'] != null) message = json['message'].toString();
      } catch (_) {}
      throw ServerExportException(message);
    }
    final dir = await ExcelExporter.exportDirectory();
    final file = File(p.join(dir.path, 'mooknote_${type}_export_${_timestamp()}.xlsx'));
    await file.writeAsBytes(resp.bodyBytes);
    return file;
  }

  static Map<String, dynamic> _parseJson(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    return {'code': -1, 'message': '服务器响应异常'};
  }

  static String _timestamp() {
    final d = DateTime.now();
    return '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}_'
        '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
  }
}

class _PackParams {
  final String dbPath;
  final List<String> imagePaths;
  final String tempDirPath;
  _PackParams({required this.dbPath, required this.imagePaths, required this.tempDirPath});
}

/// isolate 内执行：db + 图片打成 zip
/// 布局与服务端解包约定一致：mooknote.db + images/<相对路径>
String _packZip(_PackParams params) {
  final unique = DateTime.now().microsecondsSinceEpoch;
  final zipPath = p.join(params.tempDirPath, 'mooknote_backup_temp_export_$unique.zip');
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  try {
    encoder.addFile(File(params.dbPath), 'mooknote.db');
    for (final imagePath in params.imagePaths) {
      final file = File(imagePath);
      if (!file.existsSync()) continue;
      final normalized = imagePath.replaceAll('\\', '/');
      final idx = normalized.indexOf('/images/');
      final relative = idx >= 0 ? normalized.substring(idx + 8) : p.basename(imagePath);
      encoder.addFile(file, 'images/$relative');
    }
    encoder.close();
    return zipPath;
  } catch (e) {
    encoder.close();
    try {
      File(zipPath).deleteSync();
    } catch (_) {}
    rethrow;
  }
}
