import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../webdav_service.dart';
import 'inc_protocol.dart';

/// 增量同步 v2 远程文件操作：所有数据位于 <同步目录>/inc2/ 下
///
/// 目录结构：
///   inc2/manifest.json      全局快照清单
///   inc2/blobs/<sha256>     内容寻址数据块（记录 chunk / 图片）
///   inc2/delta/<uuid>.json  平铺的增量包（UUID 文件名，无序号）
class IncRemote {
  final String base;
  final WebDAVService _dav = WebDAVService.instance;

  IncRemote(this.base);

  static Future<IncRemote> create() async {
    final base = await WebDAVService.instance.getBaseDirUrl();
    final remote = IncRemote('$base/inc2');
    await remote._ensureDirs();
    return remote;
  }

  /// 确保 inc2/、blobs/、delta/ 目录存在（WebDAV 不自动建目录，缺失时 PUT 返回 403/409）
  Future<void> _ensureDirs() async {
    for (final url in [base, '$base/blobs', '$base/delta']) {
      final resp = await _dav.requestBytes(method: 'MKCOL', url: url);
      debugPrint('[Inc2] MKCOL $url -> ${resp.statusCode}');
      // 201 创建成功 / 405 已存在，均视为可用
    }
  }

  /// 目录不存在时补建（处理 MKCOL 期间被删等边缘情况）
  Future<void> _ensureBlobDir() async {
    await _dav.requestBytes(method: 'MKCOL', url: '$base/blobs');
  }

  String get _manifestUrl => '$base/manifest.json';
  String _blobUrl(String hash) => '$base/blobs/$hash';
  String _deltaUrl(String name) => '$base/delta/$name';

  /// 防缓存：反代/CDN 可能缓存 GET/HEAD/PROPFIND 响应，导致读到旧的
  /// manifest 或 delta 列表（同步"成功"但实际没拉到新数据）
  static String _noCache(String url) =>
      '$url?_ts=${DateTime.now().millisecondsSinceEpoch}';

  /// 获取全局 manifest。
  /// 404 返回 null（允许调用方建立首个基线）；其他失败抛异常，
  /// 防止把网络故障误判为"无基线"从而覆盖云端数据。
  Future<Manifest?> getManifest() async {
    final resp = await _dav.requestBytes(method: 'GET', url: _noCache(_manifestUrl));
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw Exception('manifest 获取失败: HTTP ${resp.statusCode}');
    }
    try {
      final json = jsonDecode(utf8.decode(resp.body)) as Map<String, dynamic>;
      return Manifest.fromJson(json);
    } catch (e) {
      throw Exception('manifest 解析失败: $e');
    }
  }

  Future<bool> putManifest(Manifest manifest) async {
    final bytes = utf8.encode(jsonEncode(manifest.toJson()));
    var ok = await _dav.putVerified(_manifestUrl, bytes, contentType: 'application/json');
    if (!ok) {
      await _ensureDirs();
      ok = await _dav.putVerified(_manifestUrl, bytes, contentType: 'application/json');
    }
    return ok;
  }

  /// 列出 delta 目录下所有增量包文件名（如 "abc-uuid.json"）。
  /// 请求失败返回 null，目录为空/不存在返回 []。
  Future<List<String>?> listDeltaNames() async {
    final hrefs = await _propfindHrefs('$base/delta');
    if (hrefs == null) return null;
    final result = <String>[];
    for (final href in hrefs) {
      final m = RegExp(r'delta/([^/]+\.json)$').firstMatch(href);
      if (m != null) result.add(m.group(1)!);
    }
    result.sort();
    return result;
  }

  /// PROPFIND 并提取 href 列表；404 补建目录后视为空；其他失败返回 null
  Future<List<String>?> _propfindHrefs(String url) async {
    var resp = await _dav.requestBytes(
      method: 'PROPFIND',
      url: _noCache(url),
      headers: {'Depth': '1'},
    );
    if (resp.statusCode == 404 && url.endsWith('/delta')) {
      // delta 目录不存在：补建后视为空
      await _dav.requestBytes(method: 'MKCOL', url: url);
      return [];
    }
    if (resp.statusCode != 207) {
      debugPrint('[Inc2] PROPFIND $url -> ${resp.statusCode}');
      return null;
    }
    final body = utf8.decode(resp.body);
    final hrefRegExp = RegExp(r'<(?:\w+:)?href[^>]*>([^<]+)</(?:\w+:)?href>', caseSensitive: false);
    return hrefRegExp
        .allMatches(body)
        .map((m) => Uri.decodeFull(m.group(1) ?? ''))
        .toList();
  }

  Future<DeltaFile?> getDelta(String name) async {
    final resp = await _dav.requestBytes(method: 'GET', url: _noCache(_deltaUrl(name)));
    if (resp.statusCode != 200) return null;
    try {
      return DeltaFile.fromJson(jsonDecode(utf8.decode(resp.body)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Inc2] delta 解析失败: $e');
      return null;
    }
  }

  Future<bool> putDelta(String name, DeltaFile delta) async {
    final bytes = utf8.encode(jsonEncode(delta.toJson()));
    var ok = await _dav.putVerified(
      _deltaUrl(name),
      bytes,
      contentType: 'application/json',
    );
    if (!ok) {
      // delta 目录可能被删，补建后重试
      await _dav.requestBytes(method: 'MKCOL', url: '$base/delta');
      ok = await _dav.putVerified(
        _deltaUrl(name),
        bytes,
        contentType: 'application/json',
      );
    }
    return ok;
  }

  Future<bool> blobExists(String hash) async {
    final resp = await _dav.requestBytes(method: 'HEAD', url: _noCache(_blobUrl(hash)));
    return resp.statusCode == 200;
  }

  Future<Uint8List?> getBlob(String hash) async {
    final resp = await _dav.requestBytes(method: 'GET', url: _noCache(_blobUrl(hash)));
    if (resp.statusCode != 200) return null;
    return resp.body;
  }

  /// 内容寻址 blob 上传（已存在则跳过）
  Future<bool> putBlob(String hash, Uint8List bytes) async {
    if (await blobExists(hash)) return true;
    return _dav.putVerified(_blobUrl(hash), bytes);
  }

  /// blob 直接上传（调用方已确认远程不存在）
  Future<bool> uploadBlob(String hash, Uint8List bytes) async {
    var ok = await _dav.putVerified(_blobUrl(hash), bytes);
    if (!ok) {
      // 可能是父目录被删，补建后重试一次
      await _ensureBlobDir();
      ok = await _dav.putVerified(_blobUrl(hash), bytes);
    }
    return ok;
  }

  Future<void> deleteDelta(String name) async {
    await _dav.requestBytes(method: 'DELETE', url: _deltaUrl(name));
  }
}
