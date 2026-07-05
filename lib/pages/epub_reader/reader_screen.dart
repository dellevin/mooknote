import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database_helper.dart';
import '../../services/epub/epub_theme.dart';
import '../../services/epub/epub_webview_handler.dart';
import '../../services/epub/epub_stream_service.dart';
import '../../services/epub/epub_parser.dart';
import '../../services/epub/reader_settings.dart';
import '../../data/epub/reader_models.dart';
import '../../data/epub/reader_dao.dart';
import '../../utils/toast_util.dart';
import 'book_session.dart';
import 'reader_renderer.dart';
import 'reader_webview.dart';
import 'control_panel.dart';
import 'toc_drawer.dart';
import 'image_viewer.dart';
import 'footnote_popup.dart';
import 'search_sheet.dart';
import 'epub_selection_toolbar.dart';
import 'selection_handles.dart';

part 'mixins/spine_navigation_mixin.dart';
part 'mixins/page_navigation_mixin.dart';
part 'mixins/progress_mixin.dart';
part 'mixins/theme_mixin.dart';
part 'mixins/link_handling_mixin.dart';
part 'mixins/image_viewer_mixin.dart';
part 'mixins/footnote_mixin.dart';
part 'mixins/text_selection_mixin.dart';

/// Reads EPUB directly from compressed file without extraction.
class ReaderScreen extends StatefulWidget {
  final String bookId;
  final String filePath;
  final String title;
  final String? coverPath;
  final Map<String, dynamic>? bookData;
  final int? initialSpineIndex;
  final String? scrollToXPath;
  final String? scrollToText;

  const ReaderScreen({
    super.key,
    required this.bookId,
    required this.filePath,
    required this.title,
    this.coverPath,
    this.bookData,
    this.initialSpineIndex,
    this.scrollToXPath,
    this.scrollToText,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with
        WidgetsBindingObserver,
        _SpineNavigationMixin,
        _PageNavigationMixin,
        _ProgressMixin,
        _ThemeMixin,
        _LinkHandlingMixin,
        _ImageViewerMixin,
        _FootnoteMixin,
        _TextSelectionMixin {
  @override
  late final EpubWebViewHandler webViewHandler;

  @override
  late final BookSession bookSession;

  @override
  final ReaderRendererController rendererController =
      ReaderRendererController();

  // Core UI state
  @override
  bool isWebViewLoading = true;

  @override
  bool showControls = false;

  // WebView visibility control for smoother transitions
  Animation<double>? routeAnimation;
  bool shouldShowWebView = false;

  // Spine navigation state (used by _SpineNavigationMixin)
  @override
  int currentSpineItemIndex = 0;

  // Pagination state (used by _PageNavigationMixin)
  @override
  int currentPageInChapter = 0;
  @override
  int totalPagesInChapter = 1;

  // Progress state (used by _ProgressMixin)
  @override
  String displayProgress = '';
  @override
  Timer? progressDebouncer;
  final Map<int, int> _chapterPageCounts = {};
  @override
  Map<int, int> get chapterPageCounts => _chapterPageCounts;

  // Theme state (used by _ThemeMixin)
  @override
  ThemeData? currentTheme;
  @override
  bool updatingTheme = false;
  @override
  Timer? themeUpdateDebouncer;
  @override
  ReaderSettings readerSettings = const ReaderSettings();

  // Image viewer state (used by _ImageViewerMixin)
  @override
  bool isImageViewerVisible = false;
  @override
  Uint8List? currentImageData;
  @override
  Rect? currentImageRect;

  // Footnote state (used by _FootnoteMixin)
  @override
  OverlayEntry? footnoteOverlayEntry;
  @override
  final GlobalKey<FootnotePopupOverlayState> footnoteKey =
      GlobalKey<FootnotePopupOverlayState>();
  @override
  bool isClosingFootnote = false;

  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  bool tocDrawerOpen = false;
  bool styleDrawerOpen = false;
  AppLifecycleState? lastLifecycleState = AppLifecycleState.resumed;

  // 等待分栏布局完成
  Completer<void>? _pageCountReadyCompleter;
  @override
  Completer<void>? get pageCountReadyCompleter => _pageCountReadyCompleter;

  // 书签
  final List<Map<String, dynamic>> _bookmarks = [];

  // Services
  final EpubStreamService _streamService = EpubStreamService();
  @override
  final ReaderDao _readerDao = ReaderDao();
  final EpubParser _epubParser = EpubParser();

  @override
  void initState() {
    super.initState();
    webViewHandler = EpubWebViewHandler(streamService: _streamService);

    // Create a placeholder BookSession; epubInfo will be replaced after parsing.
    bookSession = BookSession(
      fileHash: widget.bookId,
      bookData: widget.bookData ?? {
        'id': widget.bookId,
        'file_path': widget.filePath,
        'cover_path': widget.coverPath,
        'last_read_cfi': '',
      },
      epubInfo: EpubBookInfo(
        title: widget.title,
        author: '',
        authors: [],
        opfRootPath: '',
        epubVersion: '',
        spine: [],
        toc: [],
      ),
      readerDao: _readerDao,
    );

    // Load settings first, then book
    ReaderSettings.load().then((settings) {
      readerSettings = settings;
      _pendingScrollXPath = widget.scrollToXPath;
      _pendingScrollText = widget.scrollToText;
      if (mounted) {
        setupVolumeControl();
        _loadBook();
      }
    });

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        routeAnimation = route.animation!;
        routeAnimation?.addStatusListener(handleRouteAnimationStatus);
      } else {
        shouldShowWebView = true;
      }
    });
    hideBottomNavigationBar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeAnimation?.removeStatusListener(handleRouteAnimationStatus);
    routeAnimation = null;
    themeUpdateDebouncer?.cancel();
    progressDebouncer?.cancel();
    removeFootnoteOverlay(animate: false);
    restoreSystemUI();
    bookSession.flushProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
    bookSession.dispose();
    _streamService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      saveProgress();
    }

    lastLifecycleState = state;
    setupVolumeControl();
  }

  void setupVolumeControl() {
    // VolumeControlService removed — native implementation never existed.
    // TODO: reimplement if native volume-key interception is added.
  }

  void hideBottomNavigationBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  void restoreSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (currentTheme == null) {
      currentTheme = Theme.of(context);
    } else if (currentTheme?.colorScheme != Theme.of(context).colorScheme) {
      currentTheme = Theme.of(context);
      updateWebViewThemeWithDebounce();
    }
  }

  void handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        shouldShowWebView = true;
      });
      routeAnimation?.removeStatusListener(handleRouteAnimationStatus);
      routeAnimation = null;
    }
  }

  /// Load book data from EPUB file and initialize session.
  Future<void> _loadBook() async {
    try {
      // filePath is the original absolute path from import
      final fullEpubPath = widget.filePath;

      // Parse EPUB metadata using existing EpubParser
      final epubInfo = await _epubParser.parseFromFile(
        fullEpubPath,
        fileName: widget.title,
      );

      if (epubInfo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('EPUB 解析失败')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Open archive in stream service for WebView resource serving
      await _streamService.openBook(fullEpubPath);

      // Update session with parsed data
      bookSession.updateEpubInfo(epubInfo);
      bookSession.load();

      if (mounted) {
        setState(() {
          currentSpineItemIndex = widget.initialSpineIndex ?? bookSession.initialChapterIndex;
        });
        updateProgressDebounced();
        _loadBookmarks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载书籍失败: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // ─── 书签 ──────────────────────────────────────────────────────

  Future<void> _loadBookmarks() async {
    final list = await _readerDao.getBookmarksByBookId(widget.bookId);
    if (mounted) setState(() => _bookmarks..clear()..addAll(list));
  }

  bool get _currentPageHasBookmark {
    final cfi = '$currentSpineItemIndex:${(currentPageInChapter / (totalPagesInChapter > 0 ? totalPagesInChapter : 1)).toStringAsFixed(4)}';
    return _bookmarks.any((bm) => (bm['cfi'] as String? ?? '') == cfi);
  }

  Future<void> _toggleBookmark() async {
    // 检查当前页是否已有书签
    final cfi = '$currentSpineItemIndex:${(currentPageInChapter / (totalPagesInChapter > 0 ? totalPagesInChapter : 1)).toStringAsFixed(4)}';
    final existing = _bookmarks.where((bm) => (bm['cfi'] as String? ?? '') == cfi).firstOrNull;

    if (existing != null) {
      // 删除已有书签
      await _readerDao.deleteBookmark(existing['id'] as int);
      if (mounted) ToastUtil.show(context, '已移除书签');
    } else {
      // 添加书签
      // 尝试从 TOC 找更友好的标题
      String title = '';
      for (final toc in bookSession.toc) {
        if (toc.spineIndex == currentSpineItemIndex) {
          title = toc.label;
          break;
        }
      }
      // 如果 TOC 没有标题（或者标题是原始文件路径），用页内文字内容
      if (title.isEmpty || title.contains('.htm') || title.contains('.xhtml')) {
        title = await _getPageTextPreview();
        if (title.isEmpty) {
          title = '第${currentSpineItemIndex + 1}章';
        }
      }

      await _readerDao.insertBookmark({
        'book_id': widget.bookId,
        'content': title,
        'cfi': cfi,
        'chapter': currentSpineItemIndex.toString(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) ToastUtil.show(context, '已添加书签');
    }
    await _loadBookmarks();
  }

  /// 获取当前页的文字预览（前 20 个字符）
  Future<String> _getPageTextPreview() async {
    try {
      final result = await rendererController.webViewController?.runJavaScriptReturningResult(
        "(function(){var f=document.getElementById('frame-curr');if(!f||!f.contentDocument)return '';var t=f.contentDocument.body.textContent||'';return t.trim().substring(0,20)})();"
      );
      if (result != null) {
        final s = result.toString();
        return (s.startsWith('"') && s.endsWith('"') && s.length >= 2
            ? s.substring(1, s.length - 1) : s).trim();
      }
    } catch (_) {}
    return '';
  }

  void _jumpToBookmark(Map<String, dynamic> bookmark) {
    final cfi = bookmark['cfi'] as String? ?? '';
    if (cfi.isEmpty) return;
    final parts = cfi.split(':');
    if (parts.isEmpty) return;
    final chapterIndex = int.tryParse(parts[0]) ?? 0;
    final scrollRatio = parts.length >= 2 ? (double.tryParse(parts[1]) ?? 0.0) : 0.0;

    if (chapterIndex >= 0 && chapterIndex < bookSession.spine.length) {
      setState(() {
        currentSpineItemIndex = chapterIndex;
      });
      loadCarousel(restoreScrollRatio: scrollRatio);
    }
  }

  Future<void> _deleteBookmark(int id) async {
    await _readerDao.deleteBookmark(id);
    await _loadBookmarks();
  }

  void toggleControls() {
    if (showControls) {
      hideBottomNavigationBar();
    } else {
      restoreSystemUI();
    }
    setState(() {
      showControls = !showControls;
    });
  }

  void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SearchSheet(
        bookSession: bookSession,
        streamService: _streamService,
        onNavigate: (spineIndex, keyword, scrollRatio) {
          Navigator.pop(ctx);
          if (spineIndex >= 0 && spineIndex < bookSession.spine.length) {
            setState(() => currentSpineItemIndex = spineIndex);
            loadCarousel(restoreScrollRatio: scrollRatio);
          } else if (mounted) {
            ToastUtil.show(context, '章节位置无效');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!bookSession.isLoaded) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const SizedBox.shrink(),
      );
    }

    final epubTheme = getEpubTheme();
    final isDark = epubTheme.isDark;
    final colorScheme = epubTheme.colorScheme;
    final themeData = Theme.of(context);

    final overlayStyle = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: colorScheme.surface,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: colorScheme.surface,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    final activeItems = resolveActiveItems();
    final activateTocTitle = activeItems.isNotEmpty
        ? activeItems.last.label
        : widget.title;

    return PopScope(
      canPop: footnoteOverlayEntry == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (footnoteOverlayEntry != null) {
          removeFootnoteOverlay();
          return;
        }
        // 和 lumina 一样：先保存，再 pop
        saveProgress();
        Navigator.of(context).pop();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Stack(
          children: [
            Scaffold(
              key: scaffoldKey,
              backgroundColor: colorScheme.surfaceContainer,
              drawer: TocDrawer(
                bookTitle: widget.title,
                coverPath: widget.coverPath,
                totalChapters: bookSession.spine.length,
                toc: bookSession.toc,
                activeTocItems: activeItems,
                currentSpineIndex: currentSpineItemIndex >= 0 && currentSpineItemIndex < bookSession.spine.length
                    ? bookSession.spine[currentSpineItemIndex].index
                    : -1,
                onTocItemSelected: navigateToTocItem,
                onCoverTap: navigateToFirstTocItemFirstPage,
                themeData: themeData,
                bookmarks: _bookmarks,
                onBookmarkTap: _jumpToBookmark,
                onBookmarkDelete: _deleteBookmark,
              ),
              onDrawerChanged: (isOpened) {
                tocDrawerOpen = isOpened;
                setupVolumeControl();
              },
              body: Container(
                color: epubTheme.surfaceColor,
                child: Stack(
                  children: [
                    ReaderRenderer(
                      controller: rendererController,
                      bookSession: bookSession,
                      webViewHandler: webViewHandler,
                      fileHash: widget.bookId,
                      showControls: showControls,
                      isLoading: isWebViewLoading || updatingTheme,
                      canPerformPageTurn: canPerformPageTurn,
                      onPerformPageTurn: handlePageTurn,
                      onToggleControls: toggleControls,
                      onInitialized: () async {
                        // 从详情页跳转时不恢复滚动位置
                        final ratio = widget.initialSpineIndex != null
                            ? null
                            : bookSession.initialScrollPosition;
                        // 如果有跳转目标，创建 Completer 等待分栏布局完成
                        if (widget.initialSpineIndex != null && (widget.scrollToXPath != null || widget.scrollToText != null)) {
                          _pageCountReadyCompleter = Completer<void>();
                        }
                        await loadCarousel(restoreScrollRatio: ratio);
                      },
                      onPageCountReady: (totalPages) async {
                        // 通知分栏布局已完成
                        if (_pageCountReadyCompleter != null && !_pageCountReadyCompleter!.isCompleted) {
                          _pageCountReadyCompleter!.complete();
                        }
                        setState(() {
                          totalPagesInChapter = totalPages;
                          if (currentPageInChapter >= totalPagesInChapter) {
                            currentPageInChapter = totalPagesInChapter - 1;
                          }
                        });
                        updateProgressDebounced();
                      },
                      onPageChanged: (pageIndex) {
                        setState(() {
                          currentPageInChapter = pageIndex;
                        });
                        updateProgressDebounced();
                        saveProgress();
                      },
                      onScrollAnchors: handleScrollAnchors,
                      onImageLongPress: handleImageLongPress,
                      onFootnoteTap: handleFootnoteTap,
                      onLinkTap: handleLinkTap,
                      shouldHandleLinkTap: shouldHandleLinkTap,
                      onTextSelection: handleTextSelection,
                      shouldShowWebView: shouldShowWebView,
                      initializeTheme: epubTheme,
                      statusBarLeftContent: activateTocTitle,
                      statusBarRightContent: displayProgress,
                      pageAnimation: readerSettings.pageAnimation,
                    ),

                    ControlPanel(
                      showControls: showControls,
                      title: bookSession.spine.isEmpty
                          ? widget.title
                          : activateTocTitle,
                      currentSpineItemIndex: currentSpineItemIndex,
                      totalSpineItems: bookSession.spine.length,
                      currentPageInChapter: currentPageInChapter,
                      totalPagesInChapter: totalPagesInChapter,
                      direction: bookSession.direction,
                      fontSize: readerSettings.zoom * 18.0,
                      zoom: readerSettings.zoom,
                      marginTop: readerSettings.marginTop,
                      marginBottom: readerSettings.marginBottom,
                      marginLeft: readerSettings.marginLeft,
                      marginRight: readerSettings.marginRight,
                      onBack: () {
                        saveProgress();
                        Navigator.of(context).pop();
                      },
                      onOpenDrawer: openDrawer,
                      onPreviousPage: () =>
                          rendererController.performPreviousPageTurn(),
                      onFirstPage: () => goToPage(0),
                      onNextPage: () =>
                          rendererController.performNextPageTurn(),
                      onLastPage: () => goToPage(totalPagesInChapter - 1),
                      onPreviousChapter: previousSpineItemFirstPage,
                      onNextChapter: nextSpineItem,
                      onToggleStyleDrawer: () {
                        // Style sheet is opened internally by ControlPanel
                      },
                      onZoomChanged: (value) {
                        setState(() {
                          readerSettings = readerSettings.copyWith(zoom: value);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      onFontSizeChanged: (value) {
                        // 将字号值映射为 zoom（12px→0.7, 18px→1.0, 32px→1.8）
                        final zoom = value / 18.0;
                        setState(() {
                          readerSettings = readerSettings.copyWith(zoom: zoom);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      onMarginTopChanged: (value) {
                        setState(() {
                          readerSettings =
                              readerSettings.copyWith(marginTop: value);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      onMarginBottomChanged: (value) {
                        setState(() {
                          readerSettings =
                              readerSettings.copyWith(marginBottom: value);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      onMarginLeftChanged: (value) {
                        setState(() {
                          readerSettings =
                              readerSettings.copyWith(marginLeft: value);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      onMarginRightChanged: (value) {
                        setState(() {
                          readerSettings =
                              readerSettings.copyWith(marginRight: value);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      themeIndex: readerSettings.themeIndex,
                      customBgColor: readerSettings.customBgColor,
                      customTextColor: readerSettings.customTextColor,
                      onThemeIndexChanged: (index) {
                        setState(() {
                          readerSettings = readerSettings.copyWith(themeIndex: index);
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      onCustomColorChanged: (bgColor, textColor) {
                        setState(() {
                          readerSettings = readerSettings.copyWith(
                            customBgColor: bgColor,
                            customTextColor: textColor,
                          );
                        });
                        readerSettings.save();
                        updateWebViewTheme();
                      },
                      currentPageHasBookmark: _currentPageHasBookmark,
                      onBookmarkToggle: _toggleBookmark,
                      onSearchTap: _openSearch,
                    ),
                  ],
                ),
              ),
            ),

            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isImageViewerVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  opacity: isImageViewerVisible ? 1.0 : 0.0,
                  child: (currentImageData != null && currentImageRect != null)
                      ? ImageViewer(
                          imageData: currentImageData!,
                          onClose: closeImageViewer,
                          sourceRect: currentImageRect!,
                          colorScheme: colorScheme,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            // 文本选中工具条
            if (isSelectionToolbarVisible)
              EpubSelectionToolbar(
                selectionRect: _selectionRect!,
                onCopy: _onCopyButton,
                onHighlight: _onHighlightButton,
                onExcerpt: _onExcerptButton,
                onRemoveHighlight: _existingHighlightId != null && !_existingIsExcerpt ? _onRemoveHighlightButton : null,
                onRemoveExcerpt: _existingHighlightId != null && _existingIsExcerpt ? _onRemoveExcerptButton : null,
                onDismiss: _dismissSelectionToolbar,
              ),
            // 选区手柄（起点和终点）
            if (isSelectionToolbarVisible)
              SelectionHandles(
                startPosition: _startHandle,
                endPosition: _endHandle,
                onDragStart: onDragStartHandle,
                onDragEnd: onDragEndHandle,
              ),
          ],
        ),
      ),
    );
  }
}
