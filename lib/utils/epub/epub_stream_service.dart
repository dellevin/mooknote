import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class EpubStreamService {
  String? _currentBookPath;
  String? _pendingBookPath;
  Future<void>? _openBookFuture;

  /// Cached decoded archive for the current book.
  Archive? _cachedArchive;

  Future<void> warmUp() async {}

  Future<void> openBook(String epubPath) {
    if (_currentBookPath == epubPath && _cachedArchive != null) {
      return Future.value();
    }

    if (_pendingBookPath == epubPath && _openBookFuture != null) {
      return _openBookFuture!;
    }

    _pendingBookPath = epubPath;
    _openBookFuture = _doOpenBook(epubPath);
    return _openBookFuture!;
  }

  Future<void> _doOpenBook(String epubPath) async {
    try {
      final bytes = await File(epubPath).readAsBytes();
      _cachedArchive = ZipDecoder().decodeBytes(bytes);
      _currentBookPath = epubPath;
    } catch (e) {
      _currentBookPath = null;
      _cachedArchive = null;
      rethrow;
    } finally {
      if (_pendingBookPath == epubPath) {
        _pendingBookPath = null;
        _openBookFuture = null;
      }
    }
  }

  /// Read a single file from the currently open EPUB archive.
  /// Returns the file bytes, or null if not found / no book loaded.
  Future<Uint8List?> readFileFromEpub({
    required String targetFilePath,
    String? epubPath,
  }) async {
    if (epubPath != null && epubPath != _currentBookPath) {
      await openBook(epubPath);
    }

    if (_currentBookPath == null || _cachedArchive == null) {
      return null;
    }

    final file = _cachedArchive!.findFile(targetFilePath);
    if (file == null || file.content == null) {
      return null;
    }

    return file.content is Uint8List
        ? file.content as Uint8List
        : Uint8List.fromList(file.content as List<int>);
  }

  void dispose() {
    _cachedArchive = null;
    _currentBookPath = null;
    _pendingBookPath = null;
    _openBookFuture = null;
  }

  String getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    return _mimeTypeMap[ext] ?? 'application/octet-stream';
  }

  static const _mimeTypeMap = {
    'html': 'text/html',
    'htm': 'text/html',
    'xhtml': 'application/xhtml+xml',
    'xml': 'application/xml',
    'css': 'text/css',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'svg': 'image/svg+xml',
    'webp': 'image/webp',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
    'js': 'application/javascript',
  };
}
