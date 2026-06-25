import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/reader_book.dart';
import '../../providers/app_provider.dart';
import '../../service/book_server.dart';
import '../../utils/reader/book_file_helper.dart';
import '../../utils/reader/reader_url_generator.dart';

/// 目录条目
class TocItem {
  final String href;
  final String title;

  TocItem({required this.href, required this.title});

  factory TocItem.fromJson(Map<String, dynamic> json) {
    return TocItem(
      href: json['href'] ?? '',
      title: json['title'] ?? '',
    );
  }
}

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
  int chapterCurrentPage = 0;
  int chapterTotalPages = 0;

  Timer? _styleTimer;

  InAppWebViewSettings get _settings => InAppWebViewSettings(
    supportZoom: false,
    transparentBackground: true,
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

  // ─── 样式方法 ───────────────────────────────────────

  void changeStyle({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    String? fontColor,
    String? backgroundColor,
  }) {
    _styleTimer?.cancel();
    _styleTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;

      final params = <String, dynamic>{};
      if (fontSize != null) params['fontSize'] = (fontSize * 100).round();
      if (lineHeight != null) params['spacing'] = lineHeight;
      if (paragraphSpacing != null) params['paragraphSpacing'] = paragraphSpacing;
      if (fontColor != null) params['fontColor'] = '#$fontColor';
      if (backgroundColor != null) params['backgroundColor'] = '#$backgroundColor';

      if (params.isEmpty) return;

      final jsonParams = jsonEncode(params);
      _controller.evaluateJavascript(source: 'changeStyle($jsonParams)');
    });
  }

  void changeTheme(String bgColor, String textColor) {
    _controller.evaluateJavascript(source: '''
      changeStyle({
        backgroundColor: '#$bgColor',
        fontColor: '#$textColor',
      })
    ''');
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

  // ─── WebView 回调 ───────────────────────────────────

  Future<void> _onWebViewCreated(InAppWebViewController controller) async {
    _controller = controller;
    _setHandlers(controller);
    // 开启常亮
    WakelockPlus.enable();
  }

  void _setHandlers(InAppWebViewController controller) {
    // 阅读位置变化
    controller.addJavaScriptHandler(
      handlerName: 'onRelocated',
      callback: (args) {
        final location = args[0] as Map<String, dynamic>;
        setState(() {
          cfi = location['cfi'] ?? '';
          percentage = double.tryParse(location['percentage']?.toString() ?? '0') ?? 0.0;
          chapterTitle = location['chapterTitle'] ?? '';
          chapterCurrentPage = location['chapterCurrentPage'] ?? 0;
          chapterTotalPages = location['chapterTotalPages'] ?? 0;
        });
      },
    );

    // 点击事件（控制翻页和工具栏）
    controller.addJavaScriptHandler(
      handlerName: 'onClick',
      callback: (args) {
        final location = args[0] as Map<String, dynamic>;
        final x = location['x'] as num?;
        final y = location['y'] as num?;
        if (x == null || y == null) return;

        final pageWidth = MediaQuery.of(context).size.width;
        final clickX = x.toDouble() * pageWidth;
        final oneThird = pageWidth / 3;
        final twoThird = pageWidth * 2 / 3;

        if (clickX < oneThird) {
          prevPage();
        } else if (clickX > twoThird) {
          nextPage();
        } else {
          widget.showOrHideToolbar();
        }
      },
    );

    // 目录数据
    controller.addJavaScriptHandler(
      handlerName: 'onSetToc',
      callback: (args) {
        final List<dynamic> rawToc = args[0];
        final toc = rawToc.map((item) {
          if (item is Map) {
            return TocItem.fromJson(Map<String, dynamic>.from(item));
          }
          return TocItem(href: '', title: item.toString());
        }).toList();
        widget.onTocReady?.call(toc);
      },
    );

    // 翻页上拉手势
    controller.addJavaScriptHandler(
      handlerName: 'onPullUp',
      callback: (args) {
        widget.showOrHideToolbar();
      },
    );
  }

  @override
  void dispose() {
    _styleTimer?.cancel();
    saveReadingProgress();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fileAbsolute = BookFileHelper.instance.resolveAbsolutePath(widget.book.filePath);
    final fileExists = fileAbsolute.isNotEmpty && File(fileAbsolute).existsSync();
    final bookUrl = 'http://127.0.0.1:${Server().port}/book/${Uri.encodeComponent(fileAbsolute)}';
    final initialCfi = widget.initialCfi ?? widget.book.lastReadCfi;

    final bgColor = isDark ? 'FF1A1A1A' : 'FFFFFFFF';
    final textColor = isDark ? 'FFE5E5E5' : 'FF1A1A1A';

    final url = generateReaderUrl(
      fileUrl: bookUrl,
      cfi: initialCfi,
      backgroundColor: bgColor,
      textColor: textColor,
      isDarkMode: isDark,
    );

    debugPrint('[EpubPlayer] port=${Server().port} running=${Server().isRunning}');
    debugPrint('[EpubPlayer] fileAbsolute=$fileAbsolute exists=$fileExists');

    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: _settings,
      onWebViewCreated: _onWebViewCreated,
      onReceivedError: (controller, request, error) {
        debugPrint('[EpubPlayer] WebView error: ${error.description}');
      },
      onConsoleMessage: (controller, msg) {
        debugPrint('[EpubPlayer] JS: ${msg.message}');
      },
    );
  }
}
