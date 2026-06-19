import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

/// 本地 HTTP 服务器，为 WebView 提供书籍文件和 foliate-js 资源
class Server {
  static final Server _singleton = Server._internal();
  factory Server() => _singleton;
  Server._internal();

  HttpServer? _server;
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  Future<void> start({int preferredPort = 0}) async {
    if (_server != null) {
      await stop();
    }

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    try {
      _server = await io.serve(handler, '127.0.0.1', preferredPort);
    } catch (_) {
      _server = await io.serve(handler, '127.0.0.1', 0);
    }
  }

  Future<void> stop() async {
    if (_server == null) return;
    await _server!.close(force: true);
    _server = null;
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    final uriPath = request.requestedUri.path;

    // 书籍文件请求
    if (uriPath.startsWith('/book/')) {
      final bookPath = Uri.decodeComponent(uriPath.substring(6));
      final file = File(bookPath);
      if (!await file.exists()) {
        return shelf.Response.notFound('Book not found');
      }
      return shelf.Response.ok(
        file.openRead(),
        headers: {
          'Content-Type': 'application/epub+zip',
          'Access-Control-Allow-Origin': '*',
        },
      );
    }

    // foliate-js 资源请求
    if (uriPath.startsWith('/foliate-js/')) {
      final assetPath = 'assets/foliate-js/${uriPath.substring(12)}';

      String contentType;
      if (uriPath.endsWith('.html')) {
        contentType = 'text/html';
      } else if (uriPath.endsWith('.css')) {
        contentType = 'text/css';
      } else if (uriPath.endsWith('.js') || uriPath.endsWith('.mjs')) {
        contentType = 'application/javascript';
      } else if (uriPath.endsWith('.json')) {
        contentType = 'application/json';
      } else if (uriPath.endsWith('.svg')) {
        contentType = 'image/svg+xml';
      } else {
        contentType = 'application/octet-stream';
      }

      try {
        // 优先尝试 load() 加载为字节流（最可靠），再转为字符串或直接返回
        final data = await rootBundle.load(assetPath);
        return shelf.Response.ok(
          data.buffer.asUint8List(),
          headers: {
            'Content-Type': contentType,
            'Access-Control-Allow-Origin': '*',
          },
        );
      } catch (e) {
        debugPrint('[Server] Asset not found: $assetPath error=$e');
        return shelf.Response.notFound('Asset not found: $assetPath');
      }
    }

    return shelf.Response.ok(
      'OK',
      headers: {'Access-Control-Allow-Origin': '*'},
    );
  }
}
