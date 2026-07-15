import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'epub_stream_service.dart';
import '../../utils/image_path_helper.dart';

/// Simple file reference with path and optional anchor.
class Href {
  final String path;
  final String anchor;

  const Href({required this.path, this.anchor = 'top'});

  @override
  String toString() => '$path#$anchor';
}

/// WebView request handler for streaming EPUB content.
/// Intercepts requests to virtual domain and serves files from compressed EPUB.
class EpubWebViewHandler {
  final EpubStreamService _streamService;

  /// Virtual domain for EPUB content.
  /// Format: epub://localhost/book/{fileHash}/{filePath}
  static const String virtualDomain = 'localhost';
  static const String virtualScheme = 'epub';
  static const _headers = {'Cache-Control': 'public, max-age=31536000'};

  EpubWebViewHandler({required EpubStreamService streamService})
      : _streamService = streamService;

  /// Cached documents directory path.
  static String? _documentsPath;

  static Future<String> getDocumentsPath() async {
    if (_documentsPath != null) return _documentsPath!;
    final appDirPath = await ImagePathHelper.getAppDir();
    _documentsPath = '$appDirPath/';
    return _documentsPath!;
  }

  /// Create WebView resource request handler.
  /// This should be set as the shouldInterceptRequest callback.
  Future<WebResourceResponse?> handleRequest({
    required String epubPath,
    required String fileHash,
    required WebUri requestUrl,
  }) async {
    try {
      // Serve user-imported fonts.
      if (isFontRequest(requestUrl)) {
        final fontResult = await _readFontFile(requestUrl);
        if (fontResult == null) {
          return WebResourceResponse(
            statusCode: 404,
            reasonPhrase: 'Not Found',
            data: Uint8List.fromList('Font not found'.codeUnits),
          );
        }
        return WebResourceResponse(
          contentType: fontResult.$2,
          statusCode: 200,
          reasonPhrase: 'OK',
          data: fontResult.$1,
          headers: _headers,
        );
      }

      // Read file from EPUB
      final result = await _readFileFromEpub(epubPath, fileHash, requestUrl);

      if (result == null) {
        return WebResourceResponse(
          statusCode: 404,
          reasonPhrase: 'Not Found',
          data: Uint8List.fromList('File not found'.codeUnits),
        );
      }

      return WebResourceResponse(
        contentType: result.$2,
        statusCode: 200,
        reasonPhrase: 'OK',
        data: result.$1,
        headers: _headers,
      );
    } catch (e) {
      return WebResourceResponse(
        statusCode: 500,
        reasonPhrase: 'Internal Server Error',
        data: Uint8List.fromList('Error: $e'.codeUnits),
      );
    }
  }

  Future<CustomSchemeResponse?> handleRequestWithCustomScheme({
    required String epubPath,
    required String fileHash,
    required WebUri requestUrl,
  }) async {
    try {
      debugPrint('[EPUB-Handler] customScheme: $requestUrl');

      // Serve user-imported fonts.
      if (isFontRequest(requestUrl)) {
        final fontResult = await _readFontFile(requestUrl);
        if (fontResult == null) {
          return CustomSchemeResponse(
            contentType: 'text/plain',
            data: Uint8List.fromList('Font not found'.codeUnits),
          );
        }
        return CustomSchemeResponse(
          contentType: fontResult.$2,
          data: fontResult.$1,
        );
      }

      final result = await _readFileFromEpub(epubPath, fileHash, requestUrl);

      if (result == null) {
        return CustomSchemeResponse(
          contentType: 'text/plain',
          data: Uint8List.fromList('File not found'.codeUnits),
        );
      }

      return CustomSchemeResponse(
        contentType: result.$2,
        data: result.$1,
      );
    } catch (e) {
      return CustomSchemeResponse(
        contentType: 'text/plain',
        data: Uint8List.fromList('Error reading file: $e'.codeUnits),
      );
    }
  }

  /// Read a file from an EPUB.
  /// Returns (data, mimeType) or null on failure.
  Future<(Uint8List, String)?> _readFileFromEpub(
    String epubPath,
    String fileHash,
    WebUri requestUrl,
  ) async {
    final prefix = "/book/$fileHash/";
    if (!requestUrl.path.startsWith(prefix)) {
      debugPrint('[EPUB-Handler] path mismatch: ${requestUrl.path} does not start with $prefix');
      return null;
    }

    final decodedPath = Uri.decodeFull(requestUrl.path);
    final relativePath = decodedPath.substring(prefix.length);
    final fileRelativePath = relativePath.split('#')[0];

    final data = await _streamService.readFileFromEpub(
      epubPath: epubPath,
      targetFilePath: fileRelativePath,
    );

    if (data == null) {
      debugPrint('[EPUB-Handler] file not found in epub: $fileRelativePath');
      return null;
    }

    final mimeType = _streamService.getMimeType(fileRelativePath);
    debugPrint('[EPUB-Handler] serving: $fileRelativePath ($mimeType, ${data.length} bytes)');
    return (data, mimeType);
  }

  /// Reads a font file from the app's fonts directory.
  /// URL format: epub://localhost/fonts/{fileName}
  Future<(Uint8List, String)?> _readFontFile(WebUri requestUrl) async {
    const prefix = '/fonts/';
    if (!requestUrl.path.startsWith(prefix)) {
      return null;
    }
    final fileName = Uri.decodeComponent(
      requestUrl.path.substring(prefix.length),
    );
    if (fileName.isEmpty || fileName.contains('/')) {
      return null;
    }

    final documentsPath = await getDocumentsPath();
    final filePath = '${documentsPath}fonts/$fileName';
    final file = File(filePath);
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    final ext = fileName.toLowerCase().split('.').last;
    final mimeType = _fontMimeTypes[ext] ?? 'application/octet-stream';
    return (bytes, mimeType);
  }

  static const _fontMimeTypes = {
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
  };

  /// Read HTML content from EPUB for srcdoc injection (Windows WebView2).
  /// [url] is the virtual epub:// URL; extracts the relative path and reads the file.
  /// Returns (htmlContent, baseUrl) where baseUrl points to the file's directory
  /// so that relative URLs in the HTML resolve correctly.
  Future<(String, String)?> readHtmlContentWithBaseUrl({
    required String epubPath,
    required String fileHash,
    required String url,
  }) async {
    try {
      final uri = Uri.parse(url);
      final prefix = "/book/$fileHash/";
      if (!uri.path.startsWith(prefix)) return null;
      final decodedPath = Uri.decodeFull(uri.path);
      final relativePath = decodedPath.substring(prefix.length).split('#')[0];
      final data = await _streamService.readFileFromEpub(
        epubPath: epubPath,
        targetFilePath: relativePath,
      );
      if (data == null) return null;
      final htmlContent = String.fromCharCodes(data);
      // Base URL should point to the directory containing the HTML file
      final dirPath = relativePath.contains('/')
          ? relativePath.substring(0, relativePath.lastIndexOf('/') + 1)
          : '';
      final baseUrl = '$virtualScheme://$virtualDomain/book/$fileHash/$dirPath';
      return (htmlContent, baseUrl);
    } catch (_) {
      return null;
    }
  }

  /// Generate base URL for a chapter.
  /// This URL should be used as the baseUrl parameter when loading HTML.
  static String getBaseUrl() {
    return '$virtualScheme://$virtualDomain/book/index.html';
  }

  /// Generate full URL for a specific file.
  static String getFileUrl(String fileHash, Href href) {
    final url =
        '$virtualScheme://$virtualDomain/book/$fileHash/${href.path}${'#${href.anchor}'}';
    return Uri.encodeFull(url);
  }

  /// Generate URL for a user-imported font file.
  /// Format: epub://localhost/fonts/{fileName}
  static String getFontUrl(String fileName) {
    return '$virtualScheme://$virtualDomain/fonts/$fileName';
  }

  /// Check if a request is for an EPUB file.
  static bool isEpubRequest(WebUri requestUrl) {
    return requestUrl.scheme == virtualScheme &&
        requestUrl.host == virtualDomain &&
        requestUrl.path.startsWith('/book/');
  }

  /// Resolve image bytes from an EPUB for the image viewer.
  /// The imageUrl may be a virtual epub:// URL or a relative path.
  Future<Uint8List?> resolveImageFromEpub({
    required String epubPath,
    required String imageUrl,
    required String fileHash,
  }) async {
    try {
      String relativePath;
      if (imageUrl.startsWith(virtualScheme)) {
        final uri = Uri.parse(imageUrl);
        final prefix = '/book/$fileHash/';
        if (!uri.path.startsWith(prefix)) return null;
        relativePath = Uri.decodeFull(uri.path).substring(prefix.length);
      } else {
        relativePath = imageUrl;
      }
      relativePath = relativePath.split('#')[0];

      return await _streamService.readFileFromEpub(
        epubPath: epubPath,
        targetFilePath: relativePath,
      );
    } catch (_) {
      return null;
    }
  }

  /// Check if a request is for a user-imported font.
  static bool isFontRequest(WebUri requestUrl) {
    return requestUrl.scheme == virtualScheme &&
        requestUrl.host == virtualDomain &&
        requestUrl.path.startsWith('/fonts/');
  }
}
