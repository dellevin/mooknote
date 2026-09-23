import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../webdav_service.dart';
import 'inc_protocol.dart';

/// 增量同步远程文件操作：所有数据位于 <同步目录>/inc/ 下
class IncRemote {
  final String base;
  final WebDAVService _dav = WebDAVService.instance;

  IncRemote(this.base);

  static Future<IncRemote> create() async {
    final base = await WebDAVService.instance.getBaseDirUrl();
    final remote = IncRemote('$base/inc');
    await remote._ensureDirs();
    return remote;
  }

  /// 确保 inc/、blobs/、delta/ 目录存在（WebDAV 不自动建目录，缺失时 PUT 返回 403/409）
  Future<void> _ensureDirs() async {
    for (final url in [base, '$base/blobs', '$base/delta']) {
      final resp = await _dav.requestBytes(method: 'MKCOL', url: url);
      debugPrint('[Inc] MKCOL $url -> ${resp.statusCode}');
      // 201 创建成功 / 405 已存在，均视为可用
    }
  }

  /// 目录不存在时补建（处理 MKCOL 期间被删等边缘情况）
  Future<void> _ensureBlobDir() async {
    await _dav.requestBytes(method: 'MKCOL', url: '$base/blobs');
  }

  String get _manifestUrl => '$base/manifest.json';
  String _blobUrl(String hash) => '$base/blobs/$hash';
  String _deltaUrl(String clientId, int seq) => '$base/delta/$clientId/$seq.json';

  /// 获取全局 manifest。
  /// 404 返回 null（允许调用方建立首个基线）；其他失败抛异常，
  /// 防止把网络故障误判为"无基线"从而覆盖云端数据。
  Future<Manifest?> getManifest() async {
    final resp = await _dav.requestBytes(method: 'GET', url: _manifestUrl);
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

  /// 列出各客户端已存在的 delta 序号：clientId → seqs
  /// 请求失败返回 null，目录为空返回 {}
  Future<Map<String, List<int>>?> listDeltas() async {
    // 首选 Depth:2 一次拿全（文件路径 delta/<clientId>/<seq>.json）
    final hrefs = await _propfindHrefs('$base/delta', depth: '2');
    if (hrefs == null) {
      // 不支持 Depth:2 的服务器：降级为先列客户端目录，再逐个列文件
      final clientDirs = await _propfindHrefs('$base/delta', depth: '1');
      if (clientDirs == null) return null;
      final result = <String, List<int>>{};
      for (final href in clientDirs) {
        final m = RegExp(r'delta/([^/]+)/?$').firstMatch(href);
        if (m == null) continue;
        final cid = m.group(1)!;
        final files = await _propfindHrefs('$base/delta/$cid', depth: '1');
        if (files == null) continue;
        for (final f in files) {
          final fm = RegExp(r'delta/[^/]+/(\d+)\.json$').firstMatch(f);
          if (fm != null) {
            result.putIfAbsent(cid, () => []).add(int.parse(fm.group(1)!));
          }
        }
      }
      for (final list in result.values) {
        list.sort();
      }
      return result;
    }

    final result = <String, List<int>>{};
    for (final href in hrefs) {
      final match = RegExp(r'delta/([^/]+)/(\d+)\.json$').firstMatch(href);
      if (match != null) {
        final cid = match.group(1)!;
        final seq = int.parse(match.group(2)!);
        result.putIfAbsent(cid, () => []).add(seq);
      }
    }
    for (final list in result.values) {
      list.sort();
    }
    return result;
  }

  /// PROPFIND 并提取 href 列表；404 补建目录后视为空；其他失败返回 null
  Future<List<String>?> _propfindHrefs(String url, {required String depth}) async {
    var resp = await _dav.requestBytes(
      method: 'PROPFIND',
      url: url,
      headers: {'Depth': depth},
    );
    if (resp.statusCode == 404 && url.endsWith('/delta')) {
      // delta 目录不存在：补建后视为空
      await _dav.requestBytes(method: 'MKCOL', url: url);
      return [];
    }
    if (resp.statusCode != 207) {
      debugPrint('[Inc] PROPFIND Depth=$depth $url -> ${resp.statusCode}');
      return null;
    }
    final body = utf8.decode(resp.body);
    final hrefRegExp = RegExp(r'<(?:\w+:)?href[^>]*>([^<]+)</(?:\w+:)?href>', caseSensitive: false);
    return hrefRegExp
        .allMatches(body)
        .map((m) => Uri.decodeFull(m.group(1) ?? ''))
        .toList();
  }

  Future<DeltaFile?> getDelta(String clientId, int seq) async {
    final resp = await _dav.requestBytes(method: 'GET', url: _deltaUrl(clientId, seq));
    if (resp.statusCode != 200) return null;
    try {
      return DeltaFile.fromJson(jsonDecode(utf8.decode(resp.body)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[Inc] delta 解析失败: $e');
      return null;
    }
  }

  final Set<String> _ensuredDeltaDirs = {};

  Future<bool> putDelta(DeltaFile delta) async {
    if (!_ensuredDeltaDirs.contains(delta.clientId)) {
      await _dav.requestBytes(method: 'MKCOL', url: '$base/delta/${delta.clientId}');
      _ensuredDeltaDirs.add(delta.clientId);
    }
    final bytes = utf8.encode(jsonEncode(delta.toJson()));
    var ok = await _dav.putVerified(
      _deltaUrl(delta.clientId, delta.seq),
      bytes,
      contentType: 'application/json',
    );
    if (!ok) {
      // 目录可能被压实/手动删除，补建后重试
      _ensuredDeltaDirs.remove(delta.clientId);
      await _dav.requestBytes(method: 'MKCOL', url: '$base/delta/${delta.clientId}');
      _ensuredDeltaDirs.add(delta.clientId);
      ok = await _dav.putVerified(
        _deltaUrl(delta.clientId, delta.seq),
        bytes,
        contentType: 'application/json',
      );
    }
    return ok;
  }

  Future<bool> blobExists(String hash) async {
    final resp = await _dav.requestBytes(method: 'HEAD', url: _blobUrl(hash));
    return resp.statusCode == 200;
  }

  Future<Uint8List?> getBlob(String hash) async {
    final resp = await _dav.requestBytes(method: 'GET', url: _blobUrl(hash));
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

  Future<void> deleteDelta(String clientId, int seq) async {
    await _dav.requestBytes(method: 'DELETE', url: _deltaUrl(clientId, seq));
  }
}
