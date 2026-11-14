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

/// 片单（playlists + playlist_items）整库推送到服务器云端。
///
/// 片单跨影视/书籍/游戏三域，不属于任何单域整库迁移，故独立成服务：
/// - 封面图先传 MinIO，行内 cover_path 替换为网络 URL
/// - playlist_items 作为父行 groups（key: playlist_items）随片单上行
/// - 走 sync/push 但【不带 replace】，仅 LWW 幂等 upsert，不清空其它表
/// 用于把存量本地片单补齐到云端（两个单域迁移服务的表清单均不含片单）。
class CloudPlaylistSyncService {
  CloudPlaylistSyncService._();
  static final CloudPlaylistSyncService instance = CloudPlaylistSyncService._();

  static const _pushBatch = 200;

  /// playlists 业务列白名单（与服务端 SyncTableRegistry 对齐，不含 id/user_id/client_id）
  static const _playlistColumns = [
    'name', 'description', 'type', 'cover_path', 'item_count', 'sort_order',
    'is_deleted', 'created_at', 'updated_at',
  ];

  /// playlist_items 业务列白名单
  static const _itemColumns = ['playlist_id', 'item_id', 'sort_order', 'added_at'];

  String get _base => '${ServerConfig.cloudApiBase}/app';
  String get _token => CloudAuthService.instance.token;

  /// 逻辑路径 -> 已上传云端 URL 的去重缓存
  final Map<String, String> _uploaded = {};

  /// 推送本地全部未删除片单（含条目）到云端。成功返回推送的片单条数。
  Future<CloudPlaylistResult> uploadLocalToCloud() async {
    if (!CloudAuthService.instance.isLoggedIn) {
      return CloudPlaylistResult(
          success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
    }
    try {
      final db = await DatabaseHelper.instance.database;
      final clientId = await SyncIdentity.clientId();

      // 含已软删片单：upsert 时把 is_deleted=1 一并推到云端，删除才能跨设备传播
      final playlistRows = await db.query(
        'playlists',
        orderBy: 'sort_order ASC, created_at ASC',
      );
      if (playlistRows.isEmpty) {
        return const CloudPlaylistResult(success: true, count: 0);
      }
      final activePlaylistIds = playlistRows
          .where((r) => (r['is_deleted'] as int? ?? 0) == 0)
          .map((r) => r['id'] as String)
          .toSet();

      // 封面图先批量探测，缺失的并发上传
      final imagePaths = <String>{};
      final absByLogical = <String, String>{};
      for (final r in playlistRows) {
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

      // 条目按片单 id 分桶；只推未删除片单的条目，避免给云端制造孤儿条目
      final itemRows = await db.query('playlist_items', orderBy: 'sort_order ASC, id ASC');
      final itemsByPlaylist = <String, List<Map<String, dynamic>>>{};
      for (final r in itemRows) {
        if (!activePlaylistIds.contains(r['playlist_id'])) continue;
        itemsByPlaylist
            .putIfAbsent(r['playlist_id'] as String, () => [])
            .add(await _project(r, _itemColumns, keepId: true));
      }

      final ops = <Map<String, dynamic>>[];
      for (final r in playlistRows) {
        final op = <String, dynamic>{
          't': 'playlists',
          'id': r['id'] as String,
          'ts': r['updated_at'] as String,
          'row': await _project(r, _playlistColumns, keepId: false),
        };
        final items = itemsByPlaylist[r['id'] as String];
        if (items != null && items.isNotEmpty) {
          op['g'] = {'playlist_items': items};
        }
        ops.add(op);
      }

      for (var i = 0; i < ops.length; i += _pushBatch) {
        final slice = ops.sublist(i, (i + _pushBatch).clamp(0, ops.length));
        final resp = await http
            .post(
              Uri.parse('$_base/sync/push'),
              headers: {'Content-Type': 'application/json', 'token': _token},
              // 不带 replace：仅幂等 upsert 片单两表，不影响其它任何表
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
          return CloudPlaylistResult(
              success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);
        }
        if (data['code'] != 0) {
          return CloudPlaylistResult(
              success: false, message: data['msg']?.toString() ?? '上传失败'.tr);
        }
      }
      return CloudPlaylistResult(success: true, count: ops.length);
    } catch (_) {
      return CloudPlaylistResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  Future<Map<String, dynamic>> _project(
    Map<String, dynamic> local,
    List<String> columns, {
    required bool keepId,
  }) async {
    final out = <String, dynamic>{};
    if (keepId) out['id'] = local['id'];
    for (final col in columns) {
      out[col] = local[col];
    }
    if (local.containsKey('cover_path')) {
      out['cover_path'] = await _uploadIfLocal(local['cover_path'] as String?);
    }
    return out;
  }

  Future<String?> _uploadIfLocal(String? value) async {
    if (value == null || value.isEmpty || value.startsWith('http')) return value;
    final logical = _toLogical(value);
    final cached = _uploaded[logical];
    if (cached != null) return cached;
    // 预扫描漏网：文件还在就补传，避免本地路径写进云端行
    if (await File(value).exists()) {
      final url = await _uploadOne(logical, value);
      _uploaded[logical] = url;
      return url;
    }
    debugPrint('[CloudPlaylist] 本地封面丢失，云端行将保留不可访问的本地路径: $value');
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
    // 不符合标准布局时用完整路径哈希命名，避免不同目录同名文件映射到同一 OSS 对象
    final digest = sha1.convert(utf8.encode(normalized)).toString();
    return 'misc/$digest${p.extension(normalized)}';
  }
}

class CloudPlaylistResult {
  final bool success;
  final String message;
  final int count;

  const CloudPlaylistResult({required this.success, this.message = '', this.count = 0});
}
