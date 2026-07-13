import 'dart:convert';

import 'webview_bridge.dart';

/// Typed Dart mirror of the TypeScript `ReaderApi` interface
/// (`web_assets/controller.js/api.ts`).
///
/// Every public method corresponds 1-to-1 with its TypeScript counterpart.
/// The token parameter is managed internally by [WebViewBridge] — callers
/// never touch raw token integers through this class.
///
/// Methods that return `Future<int>` fire the JS call and return a token the
/// caller can later pass to [WebViewBridge.waitForEvent] / [waitForEvents]
/// when it wants to batch-await multiple operations together.
///
/// Methods that return `Future<void>` fire the JS call and await its
/// completion before returning.
class ReaderApi {
  final WebViewBridge _bridge;

  ReaderApi(this._bridge);

  // ─── Token-based (deferred await) ──────────────────────────────────

  /// Loads [url] into the iframe identified by [slot].
  /// [anchors] should be a JSON-encoded list: `'["id1","id2"]'`.
  Future<int> loadFrame(
    String slot,
    String url,
    String anchors,
    String properties,
  ) => _bridge.call(
    (t) => "window.api.loadFrame($t, '$slot', '$url', $anchors, $properties)",
  );

  /// Loads HTML content via srcdoc into the iframe identified by [slot].
  /// Used on Windows where iframe src with custom scheme doesn't load subresources.
  /// [htmlContent] is the raw HTML string to inject.
  /// [baseUrl] is used as the iframe's base URL for resolving relative paths.
  Future<int> loadFrameSrcdoc(
    String slot,
    String htmlContent,
    String baseUrl,
    String anchors,
    String properties,
  ) {
    final escapedHtml = _escapeForJs(htmlContent);
    return _bridge.call(
      (t) => "window.api.loadFrameSrcdoc($t, '$slot', '$escapedHtml', '$baseUrl', $anchors, $properties)",
    );
  }

  /// Escapes a string for safe embedding in a JS single-quoted string literal.
  String _escapeForJs(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll(r'$', r'\$');
  }

  /// Scrolls [slot]'s iframe to [pageIndex] without immediately awaiting.
  Future<int> jumpToPageFor(String slot, int pageIndex) =>
      _bridge.call((t) => "window.api.jumpToPageFor($t, '$slot', $pageIndex)");

  /// Scrolls [slot]'s iframe to its last page without immediately awaiting.
  Future<int> jumpToLastPageOfFrame(String slot) =>
      _bridge.call((t) => "window.api.jumpToLastPageOfFrame($t, '$slot')");

  /// Rotates the iframe triple in [direction] (`'next'` or `'prev'`).
  Future<int> cycleFrames(String direction) =>
      _bridge.call((t) => "window.api.cycleFrames($t, '$direction')");

  // ─── Fire-and-await ────────────────────────────────────────────────

  /// Scrolls the current iframe to [pageIndex] and awaits completion.
  Future<void> jumpToPage(int pageIndex) =>
      _bridge.callAndWait((t) => 'window.api.jumpToPage($t, $pageIndex)', 1000);

  /// Restores the scroll position using a fractional [ratio] in [0,1].
  Future<void> restoreScrollPosition(double ratio) => _bridge.callAndWait(
    (t) => 'window.api.restoreScrollPosition($t, $ratio)',
    1000,
  );

  /// Waits for the current frame to finish rendering.
  Future<void> waitForRender() =>
      _bridge.callAndWait((t) => 'window.api.waitForRender($t)', 1000);

  /// Updates the reader theme/layout and awaits completion.
  ///
  /// [theme] must be a JSON-serialisable map produced by `EpubTheme.toMap()`.
  Future<void> updateTheme(
    double viewWidth,
    double viewHeight,
    Map<String, dynamic> theme,
  ) {
    final themeJson = jsonEncode(theme);
    return _bridge.callAndWait(
      (t) => 'window.api.updateTheme($t, $viewWidth, $viewHeight, $themeJson)',
    );
  }

  // ─── Fire-and-forget ───────────────────────────────────────────────

  /// Checks whether there is an interactive element (image, etc.) at (x, y).
  Future<void> checkLongPressElementAt(double x, double y) =>
      _bridge.evaluate('window.api.checkLongPressElementAt($x, $y)');

  /// Checks whether the tap at (x, y) hits a link, footnote, or other element.
  Future<void> checkTapElementAt(double x, double y) =>
      _bridge.evaluate('window.api.checkTapElementAt($x, $y)');
}
