part of '../reader_screen.dart';

/// 文本选中和高亮功能的 mixin
///
/// 提供：
/// - 选中文字后弹出工具条（高亮/复制/摘抄）
/// - 高亮持久化到 [book_annotations] 表
/// - spine 加载后恢复已保存的高亮
mixin _TextSelectionMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  ReaderDao get _readerDao;
  BookSession get bookSession;
  ReaderRendererController get rendererController;
  int get currentSpineItemIndex;
  Completer<void>? get pageCountReadyCompleter;

  // ─── 选中工具条状态 ──────────────────────────────────────────────
  String? _selectionText;
  Rect? _selectionRect;
  int? _selectionSpineIndex;
  Offset? _startHandle;
  Offset? _endHandle;
  Map<String, dynamic>? _selectionInfo;
  String? _pendingScrollXPath;
  String? _pendingScrollText;

  // 已有高亮/摘抄信息（选中文字时检测）
  int? _existingHighlightId;
  bool _existingIsExcerpt = false;

  bool get isSelectionToolbarVisible =>
      _selectionText != null && _selectionRect != null;

  ReaderWebViewController? get _webViewControllerMixin =>
      rendererController.webViewController;

  /// 文本选中回调 —— 由 ReaderWebView 触发
  void handleTextSelection(
    String selectedText,
    Rect rect,
    int spineIndex,
    double scrollRatio,
    Offset? startHandle,
    Offset? endHandle,
    Map<String, dynamic>? selectionInfo,
  ) {
    if (selectedText.isEmpty) {
      _dismissSelectionToolbar();
      return;
    }
    // 检测选中文本是否已有高亮/摘抄
    _detectExistingHighlight(selectedText, currentSpineItemIndex);
    setState(() {
      _selectionText = selectedText;
      _selectionRect = rect;
      _selectionSpineIndex = currentSpineItemIndex;
      _startHandle = startHandle;
      _endHandle = endHandle;
      _selectionInfo = selectionInfo;
    });
  }

  /// 检测选中文本是否已有高亮或摘抄
  Future<void> _detectExistingHighlight(String text, int spineIndex) async {
    final existing = await _readerDao.getHighlightsByBookId(widget.bookId);
    final match = existing.where((h) =>
        h['chapter'] == spineIndex.toString() &&
        h['content'] == text).toList();
    if (match.isEmpty) {
      _existingHighlightId = null;
      _existingIsExcerpt = false;
    } else {
      final h = match.first;
      _existingHighlightId = h['id'] as int?;
      _existingIsExcerpt = h['color'] == 'excerpt';
    }
  }

  /// 关闭工具条并清除 WebView 选区
  void _dismissSelectionToolbar() {
    if (!isSelectionToolbarVisible) return;
    _webViewControllerMixin?.clearSelection();
    setState(() {
      _selectionText = null;
      _selectionRect = null;
      _selectionSpineIndex = null;
      _startHandle = null;
      _endHandle = null;
      _selectionInfo = null;
      _existingHighlightId = null;
      _existingIsExcerpt = false;
    });
  }

  // ─── 手柄拖动 ───────────────────────────────────────────────────

  /// 拖动起点手柄
  void onDragStartHandle(DragUpdateDetails details) {
    final globalPos = details.globalPosition;
    _webViewControllerMixin?.extendSelection(globalPos.dx, globalPos.dy, true);
  }

  /// 拖动终点手柄
  void onDragEndHandle(DragUpdateDetails details) {
    final globalPos = details.globalPosition;
    _webViewControllerMixin?.extendSelection(globalPos.dx, globalPos.dy, false);
  }

  // ─── 工具条按钮处理 ──────────────────────────────────────────────

  /// 高亮：获取选区 DOM 信息 → 保存到 DB → 应用 <mark> → 关闭工具条
  Future<void> _onHighlightButton() async {
    final text = _selectionText;
    final spineIndex = _selectionSpineIndex;
    final info = _selectionInfo;
    if (text == null || spineIndex == null || info == null) {
      ToastUtil.show(context, '选区信息已失效，请重新选择');
      _dismissSelectionToolbar();
      return;
    }

    final controller = _webViewControllerMixin;
    if (controller == null) {
      ToastUtil.show(context, '阅读器未就绪');
      return;
    }

    // 重复检测：相同 content + chapter 已有黄色高亮
    final existing = await _readerDao.getHighlightsByBookId(widget.bookId);
    final dup = existing.any((h) =>
        h['chapter'] == spineIndex.toString() &&
        h['content'] == text &&
        h['color'] != 'excerpt');
    if (dup) {
      if (!mounted) return;
      ToastUtil.show(context, '该内容已高亮');
      _dismissSelectionToolbar();
      return;
    }

    final now = DateTime.now().toIso8601String();
    final highlight = <String, dynamic>{
      'book_id': widget.bookId,
      'content': text,
      'cfi': jsonEncode({
        'startXPath': info['startXPath'],
        'startOffset': info['startOffset'],
        'endXPath': info['endXPath'],
        'endOffset': info['endOffset'],
      }),
      'chapter': spineIndex.toString(),
      'type': 'highlight',
      'color': 'FFEB3B',
      'reader_note': '',
      'created_at': now,
      'updated_at': now,
    };

    final id = await _readerDao.saveHighlight(highlight);
    // 先清除浏览器选区，防止 splitText 时活跃选区干扰 DOM 渲染（精排版书籍尤其明显）
    await controller.clearSelection();
    await Future.delayed(const Duration(milliseconds: 50));
    await controller.applyHighlight(info, id.toString(), color: 'highlight', text: text);

    if (!mounted) return;
    ToastUtil.show(context, '已高亮');
    _dismissSelectionToolbar();
  }

  /// 复制：复制到剪贴板 → 关闭工具条
  Future<void> _onCopyButton() async {
    final text = _selectionText;
    if (text == null) return;
    await copyTextToClipboard(text);
    if (!mounted) return;
    ToastUtil.show(context, '已复制');
    _dismissSelectionToolbar();
  }

  /// 摘抄：保存到 book_excerpts 表 + 用蓝色高亮标注 → 关闭工具条
  Future<void> _onExcerptButton() async {
    final text = _selectionText;
    final spineIndex = _selectionSpineIndex;
    final info = _selectionInfo;
    if (text == null || info == null) {
      ToastUtil.show(context, '选区信息已失效，请重新选择');
      _dismissSelectionToolbar();
      return;
    }

    final linkedBookId = bookSession.book['book_id'] as String? ?? '';
    if (linkedBookId.isEmpty) {
      ToastUtil.show(context, '请先在 EPUB 详情页关联书籍后再摘抄');
      _dismissSelectionToolbar();
      return;
    }

    // 重复检测：相同 content + chapter 已有摘抄
    final existing = await _readerDao.getHighlightsByBookId(widget.bookId);
    final dup = existing.any((h) =>
        h['chapter'] == (spineIndex ?? 0).toString() &&
        h['content'] == text &&
        h['color'] == 'excerpt');
    if (dup) {
      if (!mounted) return;
      ToastUtil.show(context, '该内容已摘抄');
      _dismissSelectionToolbar();
      return;
    }

    final now = DateTime.now().toIso8601String();

    // 获取章节标题（用于摘抄显示）
    final chapterTitle = bookSession.getChapterTitleForSpine(currentSpineItemIndex);
    final displayChapter = chapterTitle.isNotEmpty
        ? chapterTitle
        : '第 ${(spineIndex ?? 0) + 1} 章';

    // 1. 保存到 book_excerpts 表（chapter 用章节标题）
    await DatabaseHelper.instance.database.then((db) async {
      await db.insert('book_excerpts', {
        'id': 'excerpt_${DateTime.now().millisecondsSinceEpoch}',
        'book_id': linkedBookId,
        'chapter': displayChapter,
        'content': text,
        'comment': '',
        'is_deleted': 0,
        'created_at': now,
        'updated_at': now,
      });
    });

    // 2. 同时保存蓝色高亮标注到 book_annotations 表（chapter 用 spine 索引，用于恢复高亮）
    final controller = _webViewControllerMixin;
    if (controller != null) {
      final highlight = <String, dynamic>{
        'book_id': widget.bookId,
        'content': text,
        'cfi': jsonEncode({
          'startXPath': info['startXPath'],
          'startOffset': info['startOffset'],
          'endXPath': info['endXPath'],
          'endOffset': info['endOffset'],
        }),
        'chapter': (spineIndex ?? 0).toString(),
        'type': 'highlight',
        'color': 'excerpt',
        'reader_note': '',
        'created_at': now,
        'updated_at': now,
      };
      final id = await _readerDao.saveHighlight(highlight);
      // 先清除浏览器选区，防止 splitText 时活跃选区干扰 DOM 渲染
      await controller.clearSelection();
      await Future.delayed(const Duration(milliseconds: 50));
      await controller.applyHighlight(info, id.toString(), color: 'excerpt', text: text);
    }

    if (!mounted) return;
    ToastUtil.show(context, '已保存到摘抄');
    _dismissSelectionToolbar();
  }

  // ─── 取消高亮/摘抄 ─────────────────────────────────────────────

  /// 取消高亮：删除 DB 记录 + 移除 DOM 标注 → 关闭工具条
  Future<void> _onRemoveHighlightButton() async {
    final id = _existingHighlightId;
    if (id == null) return;
    final controller = _webViewControllerMixin;
    await _readerDao.deleteHighlight(id);
    if (controller != null) {
      // 先清除浏览器选区，防止活跃选区干扰 DOM 操作
      await controller.clearSelection();
      await Future.delayed(const Duration(milliseconds: 50));
      await controller.removeHighlight(id.toString());
    }
    if (!mounted) return;
    ToastUtil.show(context, '已取消高亮');
    _dismissSelectionToolbar();
  }

  /// 取消摘抄：删除 book_excerpts 记录 + 删除蓝色标注 → 关闭工具条
  Future<void> _onRemoveExcerptButton() async {
    final text = _selectionText;
    final id = _existingHighlightId;
    if (text == null || id == null) return;

    final linkedBookId = bookSession.book['book_id'] as String? ?? '';

    // 1. 删除 book_excerpts 中的摘抄记录
    if (linkedBookId.isNotEmpty) {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'book_excerpts',
        where: 'book_id = ? AND content = ?',
        whereArgs: [linkedBookId, text],
      );
    }

    // 2. 删除 book_annotations 中的蓝色标注
    await _readerDao.deleteHighlight(id);

    // 3. 移除 DOM 中的高亮标记
    final controller = _webViewControllerMixin;
    if (controller != null) {
      // 先清除浏览器选区，防止活跃选区干扰 DOM 操作
      await controller.clearSelection();
      await Future.delayed(const Duration(milliseconds: 50));
      await controller.removeHighlight(id.toString());
    }

    if (!mounted) return;
    ToastUtil.show(context, '已取消摘抄');
    _dismissSelectionToolbar();
  }

  // ─── 高亮恢复 ───────────────────────────────────────────────────

  /// spine 加载完成后调用：先跳转到高亮位置，再恢复高亮
  Future<void> restoreHighlightsForCurrentSpine() async {
    final controller = _webViewControllerMixin;
    if (controller == null) return;
    if (currentSpineItemIndex < 0) return;

    // 1. 先跳转到高亮所在位置（在应用高亮之前，XPath 还指向原始文本节点）
    if (_pendingScrollXPath != null) {
      final xpath = _pendingScrollXPath!;
      final text = _pendingScrollText ?? '';
      _pendingScrollXPath = null;
      _pendingScrollText = null;

      // 等待分栏布局完成（onPageCountReady 触发后）
      final completer = pageCountReadyCompleter;
      if (completer != null && !completer.isCompleted) {
        await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {});
      }
      // 分栏完成后额外等待一帧确保布局稳定
      await Future.delayed(const Duration(milliseconds: 100));

      // 用文本搜索定位（比 XPath 更可靠）
      int pageIndex = -1;
      if (text.isNotEmpty) {
        pageIndex = await controller.getPageIndexForText(text);
        debugPrint('[MN] scrollToText: page $pageIndex');
      }
      if (pageIndex < 0 && xpath.isNotEmpty) {
        pageIndex = await controller.getPageIndexForXPath(xpath);
        debugPrint('[MN] scrollToXPath: $xpath → page $pageIndex');
      }
      if (pageIndex >= 0) {
        await controller.jumpToPage(pageIndex);
        debugPrint('[MN] jumped to page $pageIndex');
      }
    }

    // 2. 查询当前 spine 应有的高亮
    final highlights =
        await _readerDao.getHighlightsByBookId(widget.bookId);
    final spineHighlights = highlights.where((h) {
      final chapter = h['chapter'] as String? ?? '';
      return chapter == currentSpineItemIndex.toString();
    }).toList();

    // 3. 先清除 DOM 中所有旧高亮，再从 DB 重新应用
    //    这样外部删除摘抄/高亮后，返回阅读器时 DOM 能同步更新
    await controller.clearAllHighlights();

    if (spineHighlights.isEmpty) return;

    final jsHighlights = <Map<String, dynamic>>[];
    for (final h in spineHighlights) {
      final cfi = h['cfi'] as String? ?? '';
      if (cfi.isEmpty) continue;
      try {
        final decoded = jsonDecode(cfi) as Map<String, dynamic>;
        jsHighlights.add({
          'id': (h['id'] ?? '').toString(),
          'color': h['color'] == 'excerpt' ? 'excerpt' : 'highlight',
          'text': h['content'] as String? ?? '',
          'info': {
            'startXPath': decoded['startXPath'] ?? '',
            'startOffset': decoded['startOffset'] ?? 0,
            'endXPath': decoded['endXPath'] ?? '',
            'endOffset': decoded['endOffset'] ?? 0,
          },
        });
      } catch (_) {}
    }

    if (jsHighlights.isEmpty) return;

    debugPrint('[MN] restoreHighlights: ${jsHighlights.length} highlights for spine $currentSpineItemIndex');

    // 重试 3 次，确保 iframe DOM 就绪
    for (int attempt = 0; attempt < 3; attempt++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final applied = await controller.applyHighlights(jsHighlights);
      debugPrint('[MN] restoreHighlights: attempt=$attempt applied=$applied/${jsHighlights.length}');
      if (applied >= jsHighlights.length) break;
    }
  }
}
