import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../data/database_helper.dart';
import '../../l10n/app_strings.dart';
import '../../utils/server_config.dart';
import '../sync/incremental/sync_identity.dart';
import 'cloud_auth_service.dart';

/// 自定义模块（custom_modules / custom_module_designs / custom_module_items）
/// 整库推送到服务器云端。
///
/// 三表不属于任何单域迁移，故独立成服务（与 CloudPlaylistSyncService 同构）：
/// - 条目封面先传 MinIO，行内 cover_path 替换为网络 URL
/// - 含已软删行，靠 is_deleted=1 的 upsert 传播删除
/// - 走 sync/push 但【不带 replace】，仅 LWW 幂等 upsert，不清空其它表
class CloudCustomModuleSyncService {
  CloudCustomModuleSyncService._();
  static final CloudCustomModuleSyncService instance =
      CloudCustomModuleSyncService._();

  static const _pushBatch = 200;

  /// 业务列白名单（与 database_helper DDL 对齐，不含 id/user_id/client_id）
  static const _columns = {
    'custom_modules': [
      'name', 'icon', 'sort_order', 'active_design_id', 'is_enabled',
      'created_at', 'updated_at', 'is_deleted',
    ],
    'custom_module_designs': [
      'module_id', 'name', 'fields_json', 'is_active',
      'created_at', 'updated_at', 'is_deleted',
    ],
    'custom_module_items': [
      'module_id', 'title', 'cover_path', 'rating', 'status', 'data_json',
      'created_at', 'updated_at', 'is_deleted',
    ],
  };

  String get _base => '${ServerConfig.cloudApiBase}/app';
  String get _token => CloudAuthService.instance.token;

  /// 逻辑路径 -> 已上传云端 URL 的去重缓存
  final Map<String, String> _uploaded = {};

  /// 推送本地全部自定义模块三表（含已软删行）到云端。成功返回推送行数。
  Future<CloudCustomModuleResult> uploadLocalToCloud() async {
    if (!CloudAuthService.instance.isLoggedIn) {
      return CloudCustomModuleResult(
          success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
    }
    try {
      final db = await DatabaseHelper.instance.database;
      final clientId = await SyncIdentity.clientId();

      // 条目封面先批量探测，缺失的并发上传
      final imagePaths = <String>{};
      final absByLogical = <String, String>{};
      final itemRows = await db.query('custom_module_items');
      for (final r in itemRows) {
        final cover = r['cover_path'] as String?;
        if (cover != null && cover.isNotEmpty && !cover.startsWith('http')) {
          final logical = _toLogical(cover);
          imagePaths.add(logical);
          absByLogical[logical] = cover;
        }
      }
      final existingMap = await _checkImagesExistBatch(imagePaths.toList());
      final pending = <String>[];
      for (final logical in imagePaths) {
        final url = existingMap[logical];
        if (url != null && url.isNotEmpty) {
          _uploaded[logical] = url;
        } else {
          final abs = absByLogical[logical];
          if (abs != null && await File(abs).exists()) pending.add(logical);
        }
      }
      const concurrency = 4;
      for (var i = 0; i < pending.length; i += concurrency) {
        final slice = pending.sublist(i, (i + concurrency).clamp(0, pending.length));
        await Future.wait(slice.map((logical) async {
          final url = await _uploadOne(logical, absByLogical[logical]!);
          _uploaded[logical] = url;
        }));
      }

      final ops = <Map<String, dynamic>>[];
      for (final table in _columns.keys) {
        final rows = table == 'custom_module_items'
            ? itemRows
            : await db.query(table);
        for (final r in rows) {
          ops.add({
            't': table,
            'id': r['id'] as String,
            'ts': r['updated_at'] as String,
            'row': await _project(table, r),
          });
        }
      }
      if (ops.isEmpty) {
        return const CloudCustomModuleResult(success: true, count: 0);
      }

      for (var i = 0; i < ops.length; i += _pushBatch) {
        final slice = ops.sublist(i, (i + _pushBatch).clamp(0, ops.length));
        final resp = await http
            .post(
              Uri.parse('$_base/sync/push'),
              headers: {'Content-Type': 'application/json', 'token': _token},
              // 不带 replace：仅幂等 upsert 三表，不影响其它任何表
              body: jsonEncode({
                'c': clientId,
                'at': DateTime.now().toIso8601String(),
                'ops': slice,
                'img': <String, String>{},
              }),
            )
            .timeout(const Duration(seconds: 120));
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        if (data['code'] == 401) {
          return CloudCustomModuleResult(
              success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
        }
        if (data['code'] != 0) {
          return CloudCustomModuleResult(
              success: false, message: data['msg']?.toString() ?? '上传失败'.tr);
        }
      }
      return CloudCustomModuleResult(success: true, count: ops.length);
    } catch (_) {
      return CloudCustomModuleResult(
          success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  Future<Map<String, dynamic>> _project(String table, Map<String, dynamic> local) async {
    final out = <String, dynamic>{};
    for (final col in _columns[table]!) {
      out[col] = local[col];
    }
    if (table == 'custom_module_items') {
      out['cover_path'] = await _uploadIfLocal(local['cover_path'] as String?);
    }
    return out;
  }

  Future<String?> _uploadIfLocal(String? value) async {
    if (value == null || value.isEmpty || value.startsWith('http')) return value;
    final logical = _toLogical(value);
    final cached = _uploaded[logical];
    if (cached != null) return cached;
    if (await File(value).exists()) {
      final url = await _uploadOne(logical, value);
      _uploaded[logical] = url;
      return url;
    }
    debugPrint('[CloudCustomModule] 本地封面丢失，云端行将保留不可访问的本地路径: $value');
    return value;
  }

  Future<Map<String, String>> _checkImagesExistBatch(List<String> logicalPaths) async {
    if (logicalPaths.isEmpty) return {};
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/oss/images-exists'),
            headers: {'Content-Type': 'application/json', 'token': _token},
            body: jsonEncode({'paths': logicalPaths}),
          )
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) return {};
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) return {};
      return ((data['data'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v?.toString() ?? ''));
    } catch (_) {
      return {};
    }
  }

  Future<String> _uploadOne(String logical, String absPath) async {
    final request = http.MultipartRequest('POST', Uri.parse('$_base/oss/image'))
      ..headers['token'] = _token
      ..fields['path'] = logical
      ..files.add(await http.MultipartFile.fromPath('file', absPath));
    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final data =
        jsonDecode(utf8.decode(await streamed.stream.toBytes())) as Map<String, dynamic>;
    if (data['code'] != 0) {
      throw Exception(data['msg']?.toString() ?? '图片上传失败'.tr);
    }
    return data['data'].toString();
  }

  String _toLogical(String absPath) {
    final normalized = absPath.replaceAll('\\', '/');
    final idx = normalized.indexOf('/images/');
    if (idx >= 0) return normalized.substring(idx + 8);
    final digest = sha1.convert(utf8.encode(normalized)).toString();
    return 'misc/$digest${p.extension(normalized)}';
  }
}

class CloudCustomModuleResult {
  final bool success;
  final String message;
  final int count;

  const CloudCustomModuleResult({required this.success, this.message = '', this.count = 0});
}
