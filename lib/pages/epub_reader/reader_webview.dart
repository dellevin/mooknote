import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../utils/epub/epub_theme.dart';
import 'book_session.dart';
import '../../utils/epub/epub_webview_handler.dart';
import '../../utils/epub/reader_scripts.dart';
import '../../utils/epub/web/webview_bridge.dart';
import '../../utils/epub/web/reader_api.dart';

/// Controller for ReaderWebView that provides methods to control the WebView
class ReaderWebViewController {
  _ReaderWebViewState? _webViewState;

  bool get isAttached => _webViewState != null;

  void _attachState(_ReaderWebViewState? state) {
    _webViewState = state;
  }

  // JavaScript wrapper methods
  Future<int?> jumpToLastPageOfFrame(String frame) async {
    return await _webViewState?._jumpToLastPageOfFrame(frame);
  }

  Future<int?> cycleFrames(String direction) async {
    return await _webViewState?._cycleFrames(direction);
  }

  Future<int?> jumpToPageFor(String frame, int pageIndex) async {
    return await _webViewState?._jumpToPageFor(frame, pageIndex);
  }

  Future<int?> loadFrame(
    String frame,
    String url,
    String anchors,
    String properties,
  ) async {
    return await _webViewState?._loadFrame(frame, url, anchors, properties);
  }

  Future<void> jumpToPage(int pageIndex) async {
    await _webViewState?._jumpToPage(pageIndex);
  }

  Future<void> restoreScrollPosition(double ratio) async {
    await _webViewState?._restoreScrollPosition(ratio);
  }

  Future<void> checkLongPressElementAt(double x, double y) async {
    await _webViewState?._checkLongPressElementAt(x, y);
  }

  Future<void> checkTapElementAt(double x, double y) async {
    await _webViewState?._checkTapElementAt(x, y);
  }

  /// 获取当前 iframe 中用户选中的文字（长按后调用）
  Future<String?> getTextSelection() async {
    return await _webViewState?._getTextSelection();
  }

  Future<ui.Image?> takeScreenshot() async {
    return await _webViewState?._takeScreenshot();
  }

  Future<void> waitForRender() async {
    await _webViewState?._waitForRender();
  }

  Future<void> updateTheme(EpubTheme theme) async {
    await _webViewState?._updateTheme(theme);
  }

  Future<void> waitForEvent(int token, [int timeoutMs = 10000]) async {
    await _webViewState?._bridge.waitForEvent(token, timeoutMs);
  }

  Future<void> waitForEvents(List<int> tokens, [int timeoutMs = 10000]) async {
    await _webViewState?._bridge.waitForEvents(tokens, timeoutMs);
  }

  Future<dynamic> runJavaScriptReturningResult(String js) async {
    return await _webViewState?._controller?.evaluateJavascript(source: js);
  }

  /// 获取当前 iframe 中选区的详细信息（用于高亮持久化）
  Future<Map<String, dynamic>?> getSelectionInfo() async {
    final result = await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.getSelectionInfo()',
    );
    if (result == null) return null;
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  /// 应用单个高亮到当前 iframe
  Future<bool> applyHighlight(Map<String, dynamic> info, String id, {String color = 'highlight', String text = ''}) async {
    final infoJson = jsonEncode(info);
    final textArg = text.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    final result = await _webViewState?._controller?.evaluateJavascript(
      source:
          "window.__mooknoteHL && window.__mooknoteHL.applyHighlight($infoJson, \"$id\", \"$color\", '$textArg')",
    );
    return result == true;
  }

  /// 批量应用高亮（用于 spine 加载后恢复）
  Future<int> applyHighlights(List<Map<String, dynamic>> highlights) async {
    if (highlights.isEmpty) return 0;
    final list = jsonEncode(highlights.map((h) {
      // 优先使用嵌套的 info 对象（来自 restoreHighlightsForCurrentSpine）
      final rawInfo = h['info'];
      Map<String, dynamic> info;
      if (rawInfo is Map) {
        info = Map<String, dynamic>.from(rawInfo);
      } else {
        // 兼容扁平字段
        info = {
          'startXPath': h['start_x_path'] ?? h['startXPath'] ?? '',
          'startOffset': h['start_offset'] ?? h['startOffset'] ?? 0,
          'endXPath': h['end_x_path'] ?? h['endXPath'] ?? '',
          'endOffset': h['end_offset'] ?? h['endOffset'] ?? 0,
        };
      }
      return {
        'info': info,
        'id': (h['id'] ?? '').toString(),
        'color': h['color'] == 'excerpt' ? 'excerpt' : 'highlight',
        'text': h['text'] ?? h['content'] ?? '',
      };
    }).toList());
    final result = await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.applyHighlights($list)',
    );
    if (result is int) return result;
    if (result is num) return result.toInt();
    return 0;
  }

  /// 移除指定 id 的高亮
  Future<void> removeHighlight(String id) async {
    await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.removeHighlight("$id")',
    );
  }

  /// 移除当前文档中所有高亮标记
  Future<void> clearAllHighlights() async {
    await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.clearAllHighlights()',
    );
  }

  /// 清除当前选区
  Future<void> clearSelection() async {
    await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.clearSelection()',
    );
  }

  /// 编程式选中长按位置的文字（用于 Flutter 长按手势触发文本选择）
  Future<void> selectWordAt(double x, double y) async {
    await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.selectWordAt($x, $y)',
    );
  }

  /// 拖动手柄时扩展选区
  Future<void> extendSelection(double x, double y, bool isStart) async {
    await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.extendSelection($x, $y, ${isStart ? 'true' : 'false'})',
    );
  }

  /// 根据 XPath 获取元素所在的页码（用于跳转到高亮位置）
  Future<int> getPageIndexForXPath(String xpath) async {
    final result = await _webViewState?._controller?.evaluateJavascript(
      source: 'window.__mooknoteHL && window.__mooknoteHL.getPageIndexForXPath("$xpath")',
    );
    if (result is int) return result;
    if (result is num) return result.toInt();
    return -1;
  }

  /// 根据文本内容获取所在页码（XPath 失败时的回退方案）
  Future<int> getPageIndexForText(String text) async {
    if (text.isEmpty) return -1;
    final escaped = text.replaceAll('\\', '\\\\').replaceAll("'", "\\'").replaceAll('\n', '\\n');
    final result = await _webViewState?._controller?.evaluateJavascript(
      source: "window.__mooknoteHL && window.__mooknoteHL.getPageIndexForText('$escaped')",
    );
    if (result is int) return result;
    if (result is num) return result.toInt();
    return -1;
  }
}

final InAppWebViewSettings defaultSettings = InAppWebViewSettings(
  disableContextMenu: false,
  disableLongPressContextMenuOnLinks: true,
  selectionGranularity: SelectionGranularity.CHARACTER,
  transparentBackground: true,
  allowFileAccessFromFileURLs: true,
  allowUniversalAccessFromFileURLs: true,
  useShouldInterceptRequest: true,
  useOnLoadResource: false,
  useShouldOverrideUrlLoading: true,
  javaScriptEnabled: true,
  disableHorizontalScroll: true,
  disableVerticalScroll: true,
  supportZoom: false,
  useHybridComposition: true,
  resourceCustomSchemes: [EpubWebViewHandler.virtualScheme],
  verticalScrollBarEnabled: false,
  horizontalScrollBarEnabled: false,
  overScrollMode: OverScrollMode.NEVER,
);

/// Callbacks for WebView events
class ReaderWebViewCallbacks {
  final Function() onInitialized;
  final Function(int totalPages) onPageCountReady;
  final Function(int pageIndex) onPageChanged;
  final Function(List<String> anchors) onScrollAnchors;
  final Function(String imageUrl, Rect rect) onImageLongPress;
  final Function(double x, double y) onTap;
  final Function(String innerHtml, Rect rect, String baseUrl) onFootnoteTap;
  final Function(String url) onLinkTap;
  final bool Function(String url) shouldHandleLinkTap;
  final Function(String selectedText, Rect rect, int spineIndex, double scrollRatio, Offset? startHandle, Offset? endHandle, Map<String, dynamic>? selectionInfo)? onTextSelection;

  const ReaderWebViewCallbacks({
    required this.onInitialized,
    required this.onPageCountReady,
    required this.onPageChanged,
    required this.onScrollAnchors,
    required this.onImageLongPress,
    required this.onTap,
    required this.onFootnoteTap,
    required this.onLinkTap,
    required this.shouldHandleLinkTap,
    this.onTextSelection,
  });
}

/// WebView widget for reading EPUB content
class ReaderWebView extends StatefulWidget {
  final BookSession bookSession;
  final EpubWebViewHandler webViewHandler;
  final String fileHash;
  final ReaderWebViewCallbacks callbacks;
  final EpubTheme initializeTheme;
  final bool isLoading;
  final ReaderWebViewController controller;
  final VoidCallback? onWebViewCreated;
  final bool shouldShowWebView;
  final String? coverRelativePath;
  final int direction;

  const ReaderWebView({
    super.key,
    required this.bookSession,
    required this.webViewHandler,
    required this.fileHash,
    required this.callbacks,
    required this.initializeTheme,
    required this.isLoading,
    required this.controller,
    this.onWebViewCreated,
    required this.shouldShowWebView,
    this.coverRelativePath,
    required this.direction,
  });

  @override
  State<ReaderWebView> createState() => _ReaderWebViewState();
}

class _ReaderWebViewState extends State<ReaderWebView> {
  final GlobalKey _repaintKey = GlobalKey();

  InAppWebViewController? _controller;
  HeadlessInAppWebView? _headlessWebView;
  bool _isHeadlessInitialized = false;

  bool _isSubsequentLoad = false;

  late EpubTheme _currentTheme;

  final WebViewBridge _bridge = WebViewBridge();
  late final ReaderApi _api = ReaderApi(_bridge);

  @override
  void initState() {
    super.initState();
    _currentTheme = widget.initializeTheme;
    widget.controller._attachState(this);
  }

  @override
  void dispose() {
    widget.controller._attachState(null);
    _bridge.detach();
    _headlessWebView?.dispose();
    _headlessWebView = null;
    _controller = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLoading && widget.isLoading) {
      setState(() {
        _isSubsequentLoad = true;
      });
    }
  }

  void _initHeadlessWebViewIfNeeded(double width, double height) {
    if (_isHeadlessInitialized) return;

    _headlessWebView = HeadlessInAppWebView(
      initialData: _generateInitialData(width, height),
      initialSettings: defaultSettings,
      shouldInterceptRequest: _shouldInterceptRequest,
      onLoadResourceWithCustomScheme: _onLoadResourceWithCustomScheme,
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
      onWebViewCreated: _onWebViewCreated,
      onLoadStop: _onLoadStop,
    );

    _headlessWebView?.run();
    _isHeadlessInitialized = true;
  }

  Future<void> _waitForWebviewRender() async {
    if (_controller == null) return;
    await _api.waitForRender();
  }

  Future<void> _waitForRender() async {
    await _waitForWebviewRender();
  }

  Future<int> _jumpToLastPageOfFrame(String frame) =>
      _api.jumpToLastPageOfFrame(frame);

  Future<int> _cycleFrames(String direction) => _api.cycleFrames(direction);

  Future<int> _jumpToPageFor(String frame, int pageIndex) =>
      _api.jumpToPageFor(frame, pageIndex);

  Future<int> _loadFrame(
    String frame,
    String url,
    String anchors,
    String properties,
  ) => _api.loadFrame(frame, url, anchors, properties);

  Future<void> _jumpToPage(int pageIndex) => _api.jumpToPage(pageIndex);

  Future<void> _restoreScrollPosition(double ratio) =>
      _api.restoreScrollPosition(ratio);

  Future<void> _checkLongPressElementAt(double x, double y) =>
      _api.checkLongPressElementAt(x, y);

  Future<void> _checkTapElementAt(double x, double y) =>
      _api.checkTapElementAt(x, y);

  /// 获取当前 iframe 中用户选中的文字
  Future<String?> _getTextSelection() async {
    if (_controller == null) return null;
    final result = await _controller!.evaluateJavascript(source: '''
(function(){
  var f = document.getElementById('frame-curr');
  if (!f || !f.contentWindow) return '';
  var sel = f.contentWindow.getSelection();
  return sel ? sel.toString() : '';
})()
''');
    if (result == null) return null;
    return result.toString();
  }

  InAppWebViewInitialData _generateInitialData(double width, double height) {
    return InAppWebViewInitialData(
      data: generateSkeletonHtml(
        width,
        height,
        _currentTheme,
        widget.direction,
      ),
      baseUrl: WebUri(EpubWebViewHandler.getBaseUrl()),
    );
  }

  Future<WebResourceResponse?> _shouldInterceptRequest(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    return await widget.webViewHandler.handleRequest(
      epubPath: widget.bookSession.book['file_path'] as String,
      fileHash: widget.fileHash,
      requestUrl: request.url,
    );
  }

  Future<CustomSchemeResponse?> _onLoadResourceWithCustomScheme(
    InAppWebViewController controller,
    WebResourceRequest request,
  ) async {
    return await widget.webViewHandler.handleRequestWithCustomScheme(
      epubPath: widget.bookSession.book['file_path'] as String,
      fileHash: widget.fileHash,
      requestUrl: request.url,
    );
  }

  Future<NavigationActionPolicy?> _shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction navigationAction,
  ) async {
    final uri = navigationAction.request.url!;
    if (uri.scheme == 'data') {
      return NavigationActionPolicy.ALLOW;
    }
    if (EpubWebViewHandler.isEpubRequest(uri)) {
      return NavigationActionPolicy.ALLOW;
    }
    return NavigationActionPolicy.CANCEL;
  }

  void _onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    _bridge.attach(controller);
    _setupJavaScriptHandlers(controller);
    widget.onWebViewCreated?.call();
  }

  void _onLoadStop(InAppWebViewController controller, WebUri? url) {
    // 注入高亮辅助函数库 + CSS + 文本选中检测（一次性注入，定时重新应用到新 contentDocument）
    controller.evaluateJavascript(source: r'''
      (function(){
        if (window.__mooknoteHL) {
          console.log('[MN] already injected, re-running setup');
          setupSelectionListener();
          return;
        }
        console.log('[MN] injecting highlight + selection JS');

        function getFrameDoc() {
          var f = document.getElementById('frame-curr');
          return f && f.contentDocument ? f.contentDocument : null;
        }

        function getFrameWin() {
          var f = document.getElementById('frame-curr');
          return f && f.contentWindow ? f.contentWindow : null;
        }

        function getXPath(node, root) {
          if (node.nodeType === 3) {
            var parent = node.parentNode;
            var textIndex = 0;
            for (var i = 0; i < parent.childNodes.length; i++) {
              if (parent.childNodes[i] === node) break;
              if (parent.childNodes[i].nodeType === 3) textIndex++;
            }
            return getXPath(parent, root) + '/text()[' + (textIndex + 1) + ']';
          }
          if (node.nodeType !== 1) return '';
          if (node === root) return '';
          var parts = [];
          var current = node;
          while (current && current.nodeType === 1 && current !== root) {
            var parent = current.parentNode;
            if (!parent) break;
            var index = 1;
            var siblings = parent.childNodes;
            for (var i = 0; i < siblings.length; i++) {
              var s = siblings[i];
              if (s.nodeType === 1 && s.tagName === current.tagName) {
                if (s === current) break;
                index++;
              }
            }
            parts.unshift(current.tagName.toLowerCase() + '[' + index + ']');
            current = parent;
          }
          return '/' + parts.join('/');
        }

        function getNodeByXPath(doc, xpath) {
          if (!doc.evaluate) return null;
          try {
            var result = doc.evaluate(xpath, doc, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null);
            return result.singleNodeValue;
          } catch (e) {
            return null;
          }
        }

        /// 计算节点在分栏排版中的页码
        function calcPageIndex(doc, node) {
          if (!node) return -1;
          var el = node.nodeType === 3 ? node.parentNode : node;
          var f = document.getElementById('frame-curr');
          if (!f) return -1;
          var iframeWidth = f.clientWidth;
          var iframeHeight = f.clientHeight;
          // 获取元素相对于 iframe 内容的偏移
          var rect = el.getBoundingClientRect();
          var scrollLeft = doc.documentElement.scrollLeft || doc.body.scrollLeft || 0;
          var scrollTop = doc.documentElement.scrollTop || doc.body.scrollTop || 0;
          // 水平分栏
          var pageX = iframeWidth > 0 ? Math.floor((rect.left + scrollLeft) / iframeWidth) : 0;
          // 垂直分栏
          var pageY = iframeHeight > 0 ? Math.floor((rect.top + scrollTop) / iframeHeight) : 0;
          // 判断是水平还是垂直分栏：看 scrollWidth 是否大于 clientWidth
          var hasHorizontalPagination = doc.documentElement.scrollWidth > doc.documentElement.clientWidth + 10;
          return hasHorizontalPagination ? pageX : pageY;
        }

        /// 文本搜索回退：遍历所有文本节点，拼接后搜索目标文本，定位并高亮
        function applyHighlightByTextSearch(doc, text, id, color) {
          if (!text || text.length === 0) return false;
          try {
            var walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT, {
              acceptNode: function(node) {
                if (node.textContent.trim().length > 0) return NodeFilter.FILTER_ACCEPT;
                return NodeFilter.FILTER_SKIP;
              }
            }, null);
            var nodes = [];
            var n;
            while (n = walker.nextNode()) nodes.push(n);
            if (nodes.length === 0) return false;

            var fullText = '';
            var ranges = [];
            for (var i = 0; i < nodes.length; i++) {
              var c = nodes[i].textContent;
              ranges.push({ node: nodes[i], start: fullText.length, len: c.length });
              fullText += c;
            }

            var idx = fullText.indexOf(text);
            if (idx === -1) return false;
            var endIdx = idx + text.length;

            var startInfo = null, endInfo = null;
            for (var i = 0; i < ranges.length; i++) {
              var r = ranges[i];
              if (!startInfo && idx >= r.start && idx < r.start + r.len) {
                startInfo = { node: r.node, offset: idx - r.start };
              }
              if (endIdx > r.start && endIdx <= r.start + r.len) {
                endInfo = { node: r.node, offset: endIdx - r.start };
                break;
              }
            }
            if (!startInfo || !endInfo) return false;

            var range = doc.createRange();
            range.setStart(startInfo.node, startInfo.offset);
            range.setEnd(endInfo.node, endInfo.offset);

            return wrapRangeMultiNode(doc, range, id, color);
          } catch (e) {
            console.log('[MN] applyHighlightByTextSearch error: ' + e);
            return false;
          }
        }

        /// 多节点包裹：遍历 range 内所有文本节点，逐个包裹在 <mooknote-mark> 中
        /// 保留段落结构，不用 extractContents
        function wrapRangeMultiNode(doc, range, id, color) {
          var bg = color === 'excerpt' ? 'rgba(33, 150, 243, 0.35)' : 'rgba(255, 235, 59, 0.5)';
          var markType = color === 'excerpt' ? 'excerpt' : 'highlight';

          var ancestor = range.commonAncestorContainer;
          var walkerRoot = ancestor.nodeType === 3 ? ancestor.parentNode : ancestor;
          var walker = doc.createTreeWalker(walkerRoot, NodeFilter.SHOW_TEXT, null);

          var nodesToWrap = [];
          var n;
          while (n = walker.nextNode()) {
            if (range.intersectsNode(n)) {
              var s = 0, e = n.length;
              if (n === range.startContainer) s = range.startOffset;
              if (n === range.endContainer) e = range.endOffset;
              if (n === range.startContainer && n === range.endContainer) { s = range.startOffset; e = range.endOffset; }
              if (s < e) nodesToWrap.push({ node: n, start: s, end: e });
            }
          }

          if (nodesToWrap.length === 0) {
            var mark = doc.createElement('mooknote-mark');
            mark.setAttribute('data-hl-id', id);
            mark.setAttribute('data-hl-type', markType);
            mark.style.backgroundColor = bg;
            mark.style.color = 'inherit';
            mark.style.borderRadius = '2px';
            try {
              range.surroundContents(mark);
              return true;
            } catch (e) {
              return false;
            }
          }

          // 倒序包裹（防止 splitText 影响后面的节点索引）
          for (var i = nodesToWrap.length - 1; i >= 0; i--) {
            var item = nodesToWrap[i];
            var tn = item.node;
            var start = item.start;
            var end = item.end;

            var wrapNode = tn;
            if (start > 0) wrapNode = tn.splitText(start);
            if (end - start < wrapNode.length) wrapNode.splitText(end - start);

            var mk = doc.createElement('mooknote-mark');
            mk.setAttribute('data-hl-id', id);
            mk.setAttribute('data-hl-type', markType);
            mk.style.backgroundColor = bg;
            mk.style.color = 'inherit';
            mk.style.borderRadius = '2px';

            wrapNode.parentNode.insertBefore(mk, wrapNode);
            mk.appendChild(wrapNode);
          }
          return true;
        }

        window.__mooknoteHL = {
          getSelectionInfo: function() {
            var win = getFrameWin();
            if (!win) return null;
            var sel = win.getSelection();
            if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null;
            var range = sel.getRangeAt(0);
            var doc = getFrameDoc();
            if (!doc) return null;
            return {
              text: sel.toString(),
              startXPath: getXPath(range.startContainer, doc),
              startOffset: range.startOffset,
              endXPath: getXPath(range.endContainer, doc),
              endOffset: range.endOffset
            };
          },

          applyHighlight: function(info, id, color, text) {
            var doc = getFrameDoc();
            if (!doc || !info) {
              return false;
            }

            var startNode = getNodeByXPath(doc, info.startXPath);
            var endNode = getNodeByXPath(doc, info.endXPath);

            if (!startNode || !endNode) {
              if (text && text.length > 0) {
                return applyHighlightByTextSearch(doc, text, id, color);
              }
              return false;
            }

            try {
              var so = Math.min(info.startOffset, startNode.length || 0);
              var eo = Math.min(info.endOffset, endNode.length || 0);

              var range = doc.createRange();
              range.setStart(startNode, so);
              range.setEnd(endNode, eo);

              return wrapRangeMultiNode(doc, range, id, color);
            } catch (e) {
              if (text) return applyHighlightByTextSearch(doc, text, id, color);
              return false;
            }
          },

          applyHighlights: function(list) {
            if (!list || list.length === 0) return 0;
            // 按文档位置倒序排序（从末尾往前应用），避免前面的高亮分裂文本节点影响后面的 XPath
            // 用数字排序而非字符串排序（/p[10] 应排在 /p[2] 之后）
            function docOrder(item) {
              var xp = (item && item.info && item.info.startXPath) || '';
              // 提取所有 [N] 中的数字，组成数组用于比较
              var nums = [];
              var re = /\[(\d+)\]/g;
              var m;
              while ((m = re.exec(xp)) !== null) nums.push(parseInt(m[1], 10));
              return nums;
            }
            function compareNums(a, b) {
              for (var i = 0; i < Math.max(a.length, b.length); i++) {
                var av = a[i] || 0;
                var bv = b[i] || 0;
                if (av !== bv) return av - bv;
              }
              return 0;
            }
            var sorted = list.slice().sort(function(a, b) {
              return compareNums(docOrder(b), docOrder(a)); // 倒序
            });
            var applied = 0;
            for (var i = 0; i < sorted.length; i++) {
              if (this.applyHighlight(sorted[i].info, sorted[i].id, sorted[i].color, sorted[i].text)) applied++;
            }
            return applied;
          },

          removeHighlight: function(id) {
            var doc = getFrameDoc();
            if (!doc) return;
            var mark = doc.querySelector('[data-hl-id="' + id + '"]');
            if (mark && mark.tagName === 'MOOKNOTE-MARK') {
              var parent = mark.parentNode;
              while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
              parent.removeChild(mark);
              parent.normalize();
            }
          },

          clearAllHighlights: function() {
            var doc = getFrameDoc();
            if (!doc) return;
            var marks = doc.querySelectorAll('mooknote-mark[data-hl-id]');
            for (var i = 0; i < marks.length; i++) {
              var mark = marks[i];
              var parent = mark.parentNode;
              while (mark.firstChild) parent.insertBefore(mark.firstChild, mark);
              parent.removeChild(mark);
            }
            // normalize 合并相邻文本节点
            if (doc.body) doc.body.normalize();
          },

          clearSelection: function() {
            var win = getFrameWin();
            if (!win) return;
            var sel = win.getSelection();
            if (sel) sel.removeAllRanges();
          },

          /// 根据 XPath 获取元素所在页码（用于跳转到高亮位置）
          getPageIndexForXPath: function(xpath) {
            var doc = getFrameDoc();
            if (!doc || !xpath) return -1;
            var node = getNodeByXPath(doc, xpath);
            if (!node) return -1;
            return calcPageIndex(doc, node);
          },

          /// 根据文本内容获取所在页码（XPath 失败时的回退）
          getPageIndexForText: function(text) {
            var doc = getFrameDoc();
            if (!doc || !text) return -1;
            // 遍历所有文本节点，找到包含目标文本的节点
            var walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT, null, null);
            var n;
            while (n = walker.nextNode()) {
              if (n.textContent.indexOf(text) !== -1) {
                return calcPageIndex(doc, n);
              }
            }
            // 去掉空白再试
            var cleanText = text.replace(/\s+/g, '');
            walker = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT, null, null);
            while (n = walker.nextNode()) {
              if (n.textContent.replace(/\s+/g, '').indexOf(cleanText) !== -1) {
                return calcPageIndex(doc, n);
              }
            }
            return -1;
          },

          /// 编程式选中最接近 (x,y) 的文字（单词/句子），并触发 onTextSelection 回调
          selectWordAt: function(x, y) {
            var f = document.getElementById('frame-curr');
            if (!f || !f.contentDocument || !f.contentWindow) {
              console.log('[MN] selectWordAt: no frame');
              return false;
            }
            var doc = f.contentDocument;
            var win = f.contentWindow;
            var iframeRect = f.getBoundingClientRect();
            var localX = x - iframeRect.left;
            var localY = y - iframeRect.top;

            // 用 caretRangeFromPoint 找到该位置的文本节点
            var range = null;
            if (doc.caretRangeFromPoint) {
              range = doc.caretRangeFromPoint(localX, localY);
            } else if (doc.caretPositionFromPoint) {
              var pos = doc.caretPositionFromPoint(localX, localY);
              if (pos) {
                range = doc.createRange();
                range.setStart(pos.offsetNode, pos.offset);
                range.setEnd(pos.offsetNode, pos.offset);
              }
            }
            if (!range || !range.startContainer || range.startContainer.nodeType !== 3) {
              console.log('[MN] selectWordAt: no text node at (' + x + ',' + y + ')');
              return false;
            }

            var node = range.startContainer;
            var offset = range.startOffset;
            var text = node.textContent;

            // 向前找到词/句边界（支持中文和英文）
            var start = offset;
            while (start > 0) {
              var ch = text[start - 1];
              // 遇到空格、标点、换行就停
              if (/[\s。，！？；：、""''（）【】《》\n\r]/.test(ch)) break;
              start--;
            }
            // 向后找到词/句边界
            var end = offset;
            while (end < text.length) {
              var ch = text[end];
              if (/[\s。，！？；：、""''（）【】《》\n\r]/.test(ch)) break;
              end++;
            }

            // 如果只选中了一个字，尝试扩展到整个句子（按句号分割）
            if (end - start <= 1) {
              start = 0;
              end = text.length;
            }

            var selRange = doc.createRange();
            selRange.setStart(node, start);
            selRange.setEnd(node, end);

            // 应用选区
            var sel = win.getSelection();
            sel.removeAllRanges();
            sel.addRange(selRange);

            var selectedText = sel.toString();
            console.log('[MN] selectWordAt: selected "' + selectedText.substring(0, 30) + '"');

            var selRect = selRange.getBoundingClientRect();
            var rect = [iframeRect.left + selRect.left, iframeRect.top + selRect.top, selRect.width, selRect.height];

            var handles = getHandlePositions(f, selRange, iframeRect);
            var info = {
              startXPath: getXPath(selRange.startContainer, doc),
              startOffset: selRange.startOffset,
              endXPath: getXPath(selRange.endContainer, doc),
              endOffset: selRange.endOffset
            };

            // 触发 onTextSelection 回调
            window.flutter_inappwebview.callHandler('onTextSelection',
              selectedText,
              rect,
              0,
              0,
              handles.start,
              handles.end,
              info
            );
            return true;
          },

          /// 拖动手柄时扩展选区：将起点或终点移动到 (x, y) 处的文字位置
          extendSelection: function(x, y, isStart) {
            var f = document.getElementById('frame-curr');
            if (!f || !f.contentDocument || !f.contentWindow) return false;
            var doc = f.contentDocument;
            var win = f.contentWindow;
            var iframeRect = f.getBoundingClientRect();
            var localX = x - iframeRect.left;
            var localY = y - iframeRect.top;

            var pos = null;
            if (doc.caretRangeFromPoint) {
              var r = doc.caretRangeFromPoint(localX, localY);
              if (r) pos = { node: r.startContainer, offset: r.startOffset };
            } else if (doc.caretPositionFromPoint) {
              var p = doc.caretPositionFromPoint(localX, localY);
              if (p) pos = { node: p.offsetNode, offset: p.offset };
            }
            if (!pos) return false;

            var sel = win.getSelection();
            if (!sel || sel.rangeCount === 0) return false;
            var currentRange = sel.getRangeAt(0);

            var newRange = doc.createRange();
            if (isStart) {
              // 拖动起点手柄：新起点 = pos，终点 = 原终点
              newRange.setStart(pos.node, pos.offset);
              newRange.setEnd(currentRange.endContainer, currentRange.endOffset);
            } else {
              // 拖动终点手柄：起点 = 原起点，新终点 = pos
              newRange.setStart(currentRange.startContainer, currentRange.startOffset);
              newRange.setEnd(pos.node, pos.offset);
            }

            // 确保起点在终点之前
            if (newRange.collapsed || currentRange.startContainer === newRange.endContainer && newRange.startOffset > newRange.endOffset) {
              // 反向了，交换
              if (isStart) {
                newRange.setStart(currentRange.endContainer, currentRange.endOffset);
                newRange.setEnd(pos.node, pos.offset);
              } else {
                newRange.setStart(pos.node, pos.offset);
                newRange.setEnd(currentRange.startContainer, currentRange.startOffset);
              }
            }

            sel.removeAllRanges();
            sel.addRange(newRange);

            var text = sel.toString();
            var selRect = newRange.getBoundingClientRect();
            var rect = [iframeRect.left + selRect.left, iframeRect.top + selRect.top, selRect.width, selRect.height];
            var handles = getHandlePositions(f, newRange, iframeRect);
            var info = {
              startXPath: getXPath(newRange.startContainer, doc),
              startOffset: newRange.startOffset,
              endXPath: getXPath(newRange.endContainer, doc),
              endOffset: newRange.endOffset
            };

            window.flutter_inappwebview.callHandler('onTextSelection',
              text,
              rect,
              0,
              0,
              handles.start,
              handles.end,
              info
            );
            return true;
          }
        };

        // ─── 文本选中检测 ────────────────────────────────────
        var lastText = '';
        var debounceTimer = null;

        function checkSelection() {
          var f = document.getElementById('frame-curr');
          if (!f || !f.contentWindow || !f.contentDocument) {
            console.log('[MN] checkSelection: no frame');
            return;
          }
          var win = f.contentWindow;
          var doc = f.contentDocument;
          var sel = win.getSelection();
          if (!sel) {
            console.log('[MN] checkSelection: no getSelection');
            return;
          }
          if (sel.isCollapsed || sel.rangeCount === 0) {
            lastText = '';
            return;
          }
          var text = sel.toString();
          if (!text || text === lastText) return;
          lastText = text;
          console.log('[MN] selection detected: ' + text.substring(0, 30));

          var range = sel.getRangeAt(0);
          var selRect = range.getBoundingClientRect();
          var iframeRect = f.getBoundingClientRect();
          var left = iframeRect.left + selRect.left;
          var top = iframeRect.top + selRect.top;

          var scrollRatio = 0;
          if (doc.documentElement) {
            var sh = doc.documentElement.scrollHeight - doc.documentElement.clientHeight;
            if (sh > 0) scrollRatio = doc.documentElement.scrollTop / sh;
          }

          var handles = getHandlePositions(f, range, iframeRect);
          var info = getSelectionInfoInternal();

          window.flutter_inappwebview.callHandler('onTextSelection',
            text,
            [left, top, selRect.width, selRect.height],
            0,
            scrollRatio,
            handles.start,
            handles.end,
            info
          );
        }

        /// 获取选区 DOM 信息（XPath + offset），用于高亮持久化
        function getSelectionInfoInternal() {
          var win = getFrameWin();
          if (!win) return null;
          var sel = win.getSelection();
          if (!sel || sel.isCollapsed || sel.rangeCount === 0) return null;
          var range = sel.getRangeAt(0);
          var doc = getFrameDoc();
          if (!doc) return null;
          return {
            startXPath: getXPath(range.startContainer, doc),
            startOffset: range.startOffset,
            endXPath: getXPath(range.endContainer, doc),
            endOffset: range.endOffset
          };
        }

        /// 获取选区起点和终点的屏幕坐标
        function getHandlePositions(f, range, iframeRect) {
          var rects = range.getClientRects();
          if (rects.length === 0) {
            var r = range.getBoundingClientRect();
            rects = [r];
          }
          var firstRect = rects[0];
          var lastRect = rects[rects.length - 1];
          // 起点手柄：第一行的左下角（手柄线覆盖文字行，圆点在上方）
          var startX = iframeRect.left + firstRect.left;
          var startY = iframeRect.top + firstRect.bottom;
          // 终点手柄：最后一行的右上角（手柄线覆盖文字行，圆点在下方）
          var endX = iframeRect.left + lastRect.right;
          var endY = iframeRect.top + lastRect.top;
          return { start: [startX, startY], end: [endX, endY] };
        }

        // 每次 iframe 内容变化后重新注入 CSS + 事件监听
        function setupSelectionListener() {
          var f = document.getElementById('frame-curr');
          if (!f || !f.contentDocument) return;
          var doc = f.contentDocument;

          // 1. 重新注入 user-select CSS（loadFrame 会替换 contentDocument，CSS 会丢失）
          var s = doc.getElementById('_ts_css');
          if (!s) {
            s = doc.createElement('style');
            s.id = '_ts_css';
            doc.head.appendChild(s);
            s.textContent = 'html,body,p,span,div,a,h1,h2,h3,h4,h5,h6,li,td,th,blockquote,figcaption{-webkit-user-select:text!important;-moz-user-select:text!important;user-select:text!important;-webkit-touch-callout:default!important}';
            console.log('[MN] CSS injected into new contentDocument');
          }

          // 2. 附加事件监听器
          if (doc.__mnSelListener) return;
          doc.__mnSelListener = true;
          console.log('[MN] attaching selection listeners');

          doc.addEventListener('selectionchange', function() {
            if (debounceTimer) clearTimeout(debounceTimer);
            debounceTimer = setTimeout(checkSelection, 250);
          });

          doc.addEventListener('touchend', function() {
            if (debounceTimer) clearTimeout(debounceTimer);
            debounceTimer = setTimeout(checkSelection, 350);
          }, true);
          doc.addEventListener('mouseup', function() {
            if (debounceTimer) clearTimeout(debounceTimer);
            debounceTimer = setTimeout(checkSelection, 350);
          }, true);
        }

        // 定时重新注入 CSS + 重新附加监听器（iframe 内容会在翻页/切换章节时变化）
        setInterval(setupSelectionListener, 500);
        setupSelectionListener();
        console.log('[MN] injection complete');
      })();
    ''');

    widget.callbacks.onInitialized();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - _currentTheme.padding.horizontal;
        final height = constraints.maxHeight - _currentTheme.padding.vertical;
        _initHeadlessWebViewIfNeeded(width, height);

        return Stack(
          children: [
            RepaintBoundary(
              key: _repaintKey,
              child: AbsorbPointer(
                child: widget.shouldShowWebView
                    ? InAppWebView(
                        headlessWebView: _headlessWebView,
                        initialData: _generateInitialData(width, height),
                        initialSettings: defaultSettings,
                        shouldInterceptRequest: _shouldInterceptRequest,
                        onLoadResourceWithCustomScheme:
                            _onLoadResourceWithCustomScheme,
                        shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
                        onWebViewCreated: _onWebViewCreated,
                        onLoadStop: _onLoadStop,
                        onConsoleMessage: (controller, consoleMessage) {
                          debugPrint('[EPUB-JS] ${consoleMessage.message}');
                        },
                      )
                    : Container(color: _currentTheme.surfaceColor),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !widget.isLoading && widget.shouldShowWebView,
                child: AnimatedOpacity(
                  duration: (widget.isLoading || !widget.shouldShowWebView)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  opacity: (widget.isLoading || !widget.shouldShowWebView)
                      ? 1.0
                      : 0.0,
                  child: Container(
                    color: _currentTheme.surfaceColor,
                    child: _isSubsequentLoad
                        ? null
                        : Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.4,
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.6,
                              ),
                              child: _buildCoverPlaceholder(),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Simple cover placeholder — loads image from file if available,
  /// otherwise shows a book icon.
  Widget _buildCoverPlaceholder() {
    final path = widget.coverRelativePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, fit: BoxFit.cover),
        );
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: _currentTheme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.book_outlined,
        size: 64,
        color: _currentTheme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _setupJavaScriptHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onPageCountReady',
      callback: (args) async {
        if (args.isNotEmpty && args[0] is int) {
          widget.callbacks.onPageCountReady(args[0] as int);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onPageChanged',
      callback: (args) {
        if (args.isNotEmpty && args[0] is int) {
          widget.callbacks.onPageChanged(args[0] as int);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onScrollAnchors',
      callback: (args) {
        if (args.isEmpty) return;
        final List<String> anchors = List<String>.from(args[0] as List);
        widget.callbacks.onScrollAnchors(anchors);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onTap',
      callback: (args) {
        if (args.isEmpty) return;
        final x = (args[0] as num).toDouble();
        final y = (args[1] as num).toDouble();
        widget.callbacks.onTap(x, y);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onFootnoteTap',
      callback: (args) {
        if (args.isEmpty) return;
        final innerHtml = args[0] as String;
        final rect = Rect.fromLTWH(
          (args[1] as num).toDouble(),
          (args[2] as num).toDouble(),
          (args[3] as num).toDouble(),
          (args[4] as num).toDouble(),
        );
        final baseUrl = args.length > 5 && args[5] is String
            ? args[5] as String
            : '';
        widget.callbacks.onFootnoteTap(innerHtml, rect, baseUrl);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onLinkTap',
      callback: (args) {
        if (args.isEmpty) return;
        final url = args[0] as String;
        final x = (args[1] as num).toDouble();
        final y = (args[2] as num).toDouble();
        if (widget.callbacks.shouldHandleLinkTap(url)) {
          widget.callbacks.onLinkTap(url);
        } else {
          widget.callbacks.onTap(x, y);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onImageLongPress',
      callback: (args) {
        if (args.length >= 5 && args[0] is String) {
          final imageUrl = args[0] as String;
          final rect = Rect.fromLTWH(
            (args[1] as num).toDouble(),
            (args[2] as num).toDouble(),
            (args[3] as num).toDouble(),
            (args[4] as num).toDouble(),
          );
          widget.callbacks.onImageLongPress(imageUrl, rect);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onViewportResize',
      callback: (args) {
        _updateTheme(_currentTheme);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onEventFinished',
      callback: (args) {
        if (args.isNotEmpty) {
          _bridge.resolveToken(args[0] as int);
        }
      },
    );

    // ─── 文本选择（划线功能） ────────────────
    controller.addJavaScriptHandler(
      handlerName: 'onTextSelection',
      callback: (args) async {
        debugPrint('[MN] onTextSelection handler called, args: ${args.length}');
        if (args.isEmpty) return;
        final selectedText = args[0] as String? ?? '';
        final rectList = args[1] as List?;
        final spineIndex = (args[2] as num?)?.toInt() ?? 0;
        final scrollRatio = (args[3] as num?)?.toDouble() ?? 0.0;
        Offset? startHandle;
        Offset? endHandle;
        Map<String, dynamic>? selectionInfo;
        if (args.length >= 6) {
          final startList = args[4] as List?;
          final endList = args[5] as List?;
          if (startList != null && startList.length >= 2) {
            startHandle = Offset(
              (startList[0] as num).toDouble(),
              (startList[1] as num).toDouble(),
            );
          }
          if (endList != null && endList.length >= 2) {
            endHandle = Offset(
              (endList[0] as num).toDouble(),
              (endList[1] as num).toDouble(),
            );
          }
        }
        if (args.length >= 7) {
          final rawInfo = args[6];
          if (rawInfo is Map) {
            selectionInfo = Map<String, dynamic>.from(rawInfo);
          }
        }
        debugPrint('[MN] selectedText="$selectedText" info=$selectionInfo');
        Rect? rect;
        if (rectList != null && rectList.length >= 4) {
          rect = Rect.fromLTWH(
            (rectList[0] as num).toDouble(),
            (rectList[1] as num).toDouble(),
            (rectList[2] as num).toDouble(),
            (rectList[3] as num).toDouble(),
          );
        }
        if (selectedText.isNotEmpty && rect != null) {
          widget.callbacks.onTextSelection?.call(
            selectedText,
            rect,
            spineIndex,
            scrollRatio,
            startHandle,
            endHandle,
            selectionInfo,
          );
        }
      },
    );
  }

  Future<ui.Image?> _takeScreenshot() async {
    if (Platform.isAndroid) {
      // for Android
      final BuildContext? context = _repaintKey.currentContext;
      if (context == null) return null;

      final RenderRepaintBoundary? boundary =
          context.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      return image;
    } else {
      throw UnimplementedError(
        'Do not use screenshot on iOS, it may cause performance issues.',
      );
    }
  }

  Future<void> _updateTheme(EpubTheme theme) async {
    if (_controller == null) return;
    final width = MediaQuery.of(context).size.width - theme.padding.horizontal;
    final height = MediaQuery.of(context).size.height - theme.padding.vertical;
    _currentTheme = theme;
    await _api.updateTheme(width, height, theme.toThemeMap());
  }
}
