import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/reader_book.dart';
import '../../providers/app_provider.dart';
import '../../service/book_server.dart';
import '../../utils/reader/book_file_helper.dart';
import '../../utils/reader/coordinates_to_part.dart';
import '../../utils/reader/reader_url_generator.dart';

/// 目录条目
class TocItem {
  final String href;
  final String title;
  final int level;

  TocItem({required this.href, required this.title, this.level = 1});

  factory TocItem.fromJson(Map<String, dynamic> json) {
    return TocItem(
      href: json['href'] ?? '',
      title: json['label'] ?? json['title'] ?? '',
      level: json['level'] as int? ?? 1,
    );
  }
}

/// 递归展平嵌套目录
List<TocItem> _flattenToc(List<dynamic> items, [int level = 1]) {
  final result = <TocItem>[];
  for (final item in items) {
    if (item is Map) {
      final map = Map<String, dynamic>.from(item);
      result.add(TocItem(
        href: map['href'] ?? '',
        title: map['label'] ?? map['title'] ?? '',
        level: level,
      ));
      if (map['subitems'] is List && (map['subitems'] as List).isNotEmpty) {
        result.addAll(_flattenToc(map['subitems'] as List, level + 1));
      }
    }
  }
  return result;
}

/// 翻页区域动作
enum PageTurnAction { prev, next, menu, none }

/// 默认九宫格布局（中间菜单，左右翻页）
const List<PageTurnAction> _defaultZoneActions = [
  PageTurnAction.prev, PageTurnAction.menu, PageTurnAction.next,
  PageTurnAction.prev, PageTurnAction.menu, PageTurnAction.next,
  PageTurnAction.prev, PageTurnAction.menu, PageTurnAction.next,
];

/// 核心电子书阅读组件 — 使用 InAppWebView 渲染 foliate-js 阅读器
class EpubPlayer extends StatefulWidget {
  final ReaderBook book;
  final String? initialCfi;
  final VoidCallback showOrHideToolbar;
  final ValueChanged<List<TocItem>>? onTocReady;

  const EpubPlayer({
    super.key,
    required this.book,
    this.initialCfi,
    required this.showOrHideToolbar,
    this.onTocReady,
  });

  @override
  State<EpubPlayer> createState() => EpubPlayerState();
}

class EpubPlayerState extends State<EpubPlayer> {
  late InAppWebViewController _controller;
  String cfi = '';
  double percentage = 0.0;
  String chapterTitle = '';
  String chapterHref = '';
  int chapterCurrentPage = 0;
  int chapterTotalPages = 0;

  // 浏览历史
  bool _showHistory = false;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // 滚轮翻页
  Timer? _scrollDebounceTimer;
  double _accumulatedScrollDelta = 0;
  static const double _scrollThreshold = 50.0;

  InAppWebViewSettings get _settings => InAppWebViewSettings(
    supportZoom: false,
    transparentBackground: true,
    isInspectable: kDebugMode,
    useHybridComposition: true,
    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
  );

  // ─── 翻页方法 ───────────────────────────────────────

  void prevPage() {
    _controller.evaluateJavascript(source: 'prevPage()');
  }

  void nextPage() {
    _controller.evaluateJavascript(source: 'nextPage()');
  }

  void prevChapter() {
    _controller.evaluateJavascript(source: 'prevSection()');
  }

  void nextChapter() {
    _controller.evaluateJavascript(source: 'nextSection()');
  }

  void goToPercentage(double value) {
    _controller.evaluateJavascript(source: 'goToPercent($value)');
  }

  void goToHref(String href) {
    _controller.evaluateJavascript(source: "goToHref('$href')");
  }

  void goToCfi(String cfi) {
    _controller.evaluateJavascript(source: "goToCfi('$cfi')");
  }

  // ─── 历史导航 ───────────────────────────────────────

  void backHistory() {
    _controller.evaluateJavascript(source: 'back()');
  }

  void forwardHistory() {
    _controller.evaluateJavascript(source: 'forward()');
  }

  // ─── 保存进度 ───────────────────────────────────────

  Future<void> saveReadingProgress() async {
    if (cfi.isEmpty) return;
    final provider = context.read<AppProvider>();
    final updated = widget.book.copyWith(
      lastReadCfi: cfi,
      readingPercentage: percentage,
      updatedAt: DateTime.now(),
    );
    await provider.updateReaderBook(updated);
  }

  // ─── 翻页区域处理 ──────────────────────────────────

  void _onClick(Map<String, dynamic> location) {
    final x = (location['x'] as num).toDouble();
    final y = (location['y'] as num).toDouble();
    final part = coordinatesToPart(x, y);
    final action = _defaultZoneActions[part];

    switch (action) {
      case PageTurnAction.prev:
        prevPage();
        break;
      case PageTurnAction.next:
        nextPage();
        break;
      case PageTurnAction.menu:
        widget.showOrHideToolbar();
        break;
      case PageTurnAction.none:
        break;
    }
  }

  // ─── 滚轮翻页 ──────────────────────────────────────

  Future<void> _handlePointerEvents(PointerEvent event) async {
    if (event is! PointerScrollEvent) return;
    _accumulatedScrollDelta += event.scrollDelta.dy;

    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 80), () {
      if (_accumulatedScrollDelta.abs() >= _scrollThreshold) {
        if (_accumulatedScrollDelta > 0) {
          nextPage();
        } else {
          prevPage();
        }
      }
      _accumulatedScrollDelta = 0;
    });
  }

  // ─── 外部链接处理 ──────────────────────────────────

  Future<void> _handleExternalLink(dynamic rawLink) async {
    String? link;
    if (rawLink is String && rawLink.trim().isNotEmpty) {
      link = rawLink.trim();
    } else if (rawLink is Map && rawLink['href'] is String) {
      link = (rawLink['href'] as String).trim();
    }
    if (!mounted || link == null || link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme.isEmpty || uri.scheme == 'javascript') return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打开外部链接'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('是否在浏览器中打开以下链接？'),
            const SizedBox(height: 8),
            SelectableText(link!, style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('打开')),
        ],
      ),
    );

    if (shouldOpen == true) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─── WebView 回调 ───────────────────────────────────

  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    _controller = controller;
    _setHandlers(controller);
    WakelockPlus.enable();
  }

  void _setHandlers(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'onLoadEnd',
      callback: (args) {},
    );

    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        final location = args[0] as Map<String, dynamic>;
        if (cfi == location['cfi']) return;
        setState(() {
          cfi = location['cfi'] ?? '';
          percentage = double.tryParse(location['percentage']?.toString() ?? '0') ?? 0.0;
          chapterTitle = location['chapterTitle'] ?? '';
          chapterHref = location['chapterHref'] ?? '';
          chapterCurrentPage = location['chapterCurrentPage'] ?? 0;
          chapterTotalPages = location['chapterTotalPages'] ?? 0;
        });
        saveReadingProgress();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        final location = args[0] as Map<String, dynamic>;
        _onClick(location);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onExternalLink',
      callback: (args) async {
        await _handleExternalLink(args.isNotEmpty ? args.first : null);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        final List<dynamic> rawToc = args[0];
        final toc = _flattenToc(rawToc);
        widget.onTocReady?.call(toc);
      },
    );

    // 以下 handler 保留注册以避免 JS 端报错，但不做处理
    controller.addJavaScriptHandler(handlerName: 'onSelectionEnd', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'onSelectionCleared', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'onAnnotationClick', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'onSearch', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'renderAnnotations', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'onImageClick', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'onFootnoteClose', callback: (args) {});
    controller.addJavaScriptHandler(handlerName: 'handleBookmark', callback: (args) {});

    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        final state = args[0] as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _canGoBack = state['canGoBack'] ?? false;
          _canGoForward = state['canGoForward'] ?? false;
          _showHistory = _canGoBack || _canGoForward;
        });
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onPullUp',
      callback: (args) {
        widget.showOrHideToolbar();
      },
    );
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    saveReadingProgress();
    WakelockPlus.disable();
    super.dispose();
  }

  // ─── 阅读信息浮层 ──────────────────────────────────

  Widget _buildReadingInfo() {
    if (chapterCurrentPage == 0 && percentage == 0.0) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final infoColor = isDark ? Colors.white.withAlpha(130) : Colors.black.withAlpha(130);
    final infoStyle = TextStyle(color: infoColor, fontSize: 10);

    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
            child: Text(
              chapterTitle.isNotEmpty ? chapterTitle : widget.book.title,
              style: infoStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$chapterCurrentPage/$chapterTotalPages', style: infoStyle),
                Text('${(percentage * 100).toStringAsFixed(1)}%', style: infoStyle),
                _buildBatteryWidget(infoColor),
                _buildClockWidget(infoStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryWidget(Color color) {
    return FutureBuilder<int>(
      future: Battery().batteryLevel,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_std, size: 12, color: color),
            const SizedBox(width: 2),
            Text('${snapshot.data}%', style: TextStyle(color: color, fontSize: 10)),
          ],
        );
      },
    );
  }

  Widget _buildClockWidget(TextStyle style) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Text(
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
          style: style,
        );
      },
    );
  }

  // ─── 历史导航胶囊 ──────────────────────────────────

  Widget _buildHistoryCapsule() {
    final colors = Theme.of(context).colorScheme;
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
    );

    Widget btn(IconData icon, String label, VoidCallback onPressed) {
      return TextButton.icon(
        icon: Icon(icon, size: 18, color: colors.onSurface.withAlpha(180)),
        label: Text(label, style: TextStyle(color: colors.onSurface.withAlpha(180), fontSize: 14)),
        onPressed: onPressed,
        style: buttonStyle,
      );
    }

    final buttons = <Widget>[];
    if (_canGoBack) buttons.add(btn(Icons.arrow_back, '返回', backHistory));
    buttons.add(btn(Icons.close, '关闭', () => setState(() => _showHistory = false)));
    if (_canGoForward) buttons.add(btn(Icons.arrow_forward, '前进', forwardHistory));

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: colors.surfaceContainer.withAlpha(123),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: colors.outline, width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileAbsolute = BookFileHelper.instance.resolveAbsolutePath(widget.book.filePath);
    final bookUrl = 'http://127.0.0.1:${Server().port}/book/${Uri.encodeComponent(fileAbsolute)}';
    final initialCfi = widget.initialCfi ?? widget.book.lastReadCfi;

    final url = generateReaderUrl(
      fileUrl: bookUrl,
      cfi: initialCfi,
      backgroundColor: 'FFFBFBF3',
      textColor: 'FF343434',
    );

    return Listener(
      onPointerSignal: _handlePointerEvents,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            SizedBox.expand(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(url)),
                initialSettings: _settings,
                onWebViewCreated: _onWebViewCreated,
                onReceivedError: (controller, request, error) {
                  debugPrint('[EpubPlayer] WebView error: ${error.description}');
                },
                onConsoleMessage: (controller, msg) {
                  debugPrint('[EpubPlayer] JS: ${msg.message}');
                },
              ),
            ),
            _buildReadingInfo(),
            if (_showHistory) _buildHistoryCapsule(),
          ],
        ),
      ),
    );
  }
}
