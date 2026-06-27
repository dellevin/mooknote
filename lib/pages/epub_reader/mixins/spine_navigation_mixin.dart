part of '../reader_screen.dart';

mixin _SpineNavigationMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  BookSession get bookSession;

  ReaderRendererController get rendererController;

  bool get isWebViewLoading;
  set isWebViewLoading(bool v);

  int get currentSpineItemIndex;
  set currentSpineItemIndex(int v);

  int get currentPageInChapter;
  set currentPageInChapter(int v);

  int get totalPagesInChapter;

  // === Cross-mixin: _ProgressMixin ===
  void updateProgressDebounced();
  void saveProgress();

  // === Cross-mixin: _ThemeMixin ===
  EpubTheme getEpubTheme();

  List<String> getAnchorsForSpine(String spinePath) {
    return bookSession.getAnchorsForSpine(spinePath);
  }

  void handleScrollAnchors(List<String> anchorIds) {
    setState(() {
      bookSession.updateActiveAnchors(anchorIds);
    });
  }

  String getSpineItemUrl(int index, [String anchor = 'top']) {
    return bookSession.getSpineItemUrl(index, anchor);
  }

  String? getSpineProperties(int index) {
    return bookSession.getSpineProperties(index);
  }

  Future<void> loadCarousel({
    String anchor = 'top',
    int? overrideSpineIndex,
    double? restoreScrollRatio,
  }) async {
    if (bookSession.spine.isEmpty) return;
    if (currentSpineItemIndex < 0) currentSpineItemIndex = 0;
    if (mounted) {
      setState(() {
        isWebViewLoading = true;
      });
    }

    if (overrideSpineIndex != null &&
        overrideSpineIndex >= 0 &&
        overrideSpineIndex < bookSession.spine.length) {
      currentSpineItemIndex = overrideSpineIndex;
    }
    final currIndex = currentSpineItemIndex;
    final prevIndex = currIndex > 0 ? currIndex - 1 : null;
    final nextIndex = currIndex < bookSession.spine.length - 1
        ? currIndex + 1
        : null;

    final tokensForWait = <int>[];

    final currUrl = getSpineItemUrl(currIndex, anchor);
    final currentSpinePath = bookSession.spine[currIndex].href;
    final currToken = await rendererController.preloadCurrentChapter(
      currUrl,
      getAnchorsForSpine(currentSpinePath),
      getSpineProperties(currIndex),
    );
    if (currToken != null) tokensForWait.add(currToken);

    if (prevIndex != null) {
      final prevUrl = getSpineItemUrl(prevIndex);
      final prevSpinePath = bookSession.spine[prevIndex].href;
      final prevToken = await rendererController.preloadPreviousChapter(
        prevUrl,
        getAnchorsForSpine(prevSpinePath),
        getSpineProperties(prevIndex),
      );
      if (prevToken != null) tokensForWait.add(prevToken);
    }

    if (nextIndex != null) {
      final nextUrl = getSpineItemUrl(nextIndex);
      final nextSpinePath = bookSession.spine[nextIndex].href;
      final nextToken = await rendererController.preloadNextChapter(
        nextUrl,
        getAnchorsForSpine(nextSpinePath),
        getSpineProperties(nextIndex),
      );
      if (nextToken != null) tokensForWait.add(nextToken);
    }

    await rendererController.waitForEvents(tokensForWait);

    if (restoreScrollRatio != null) {
      await rendererController.restoreScrollPosition(restoreScrollRatio);
    }

    await Future.delayed(const Duration(milliseconds: 30));
    setState(() {
      isWebViewLoading = false;
    });
  }

  Future<void> preloadNextOf(int currentIndex) async {
    final nextIndex = currentIndex + 1;
    if (nextIndex < bookSession.spine.length) {
      final url = getSpineItemUrl(nextIndex);
      final nextSpinePath = bookSession.spine[nextIndex].href;
      await rendererController.preloadNextChapter(
        url,
        getAnchorsForSpine(nextSpinePath),
        getSpineProperties(nextIndex),
      );
    }
  }

  Future<void> preloadPreviousOf(int currentIndex) async {
    final prevIndex = currentIndex - 1;
    if (prevIndex >= 0) {
      final url = getSpineItemUrl(prevIndex);
      final prevSpinePath = bookSession.spine[prevIndex].href;
      await rendererController.preloadPreviousChapter(
        url,
        getAnchorsForSpine(prevSpinePath),
        getSpineProperties(prevIndex),
      );
    }
  }

  Future<void> navigateToSpineItem(int index, [String anchor = 'top']) async {
    if (index < 0 || index >= bookSession.spine.length) return;

    setState(() {
      currentSpineItemIndex = index;
      currentPageInChapter = 0;
    });
    updateProgressDebounced();

    await loadCarousel(anchor: anchor);
    bookSession.flushProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }

  Future<void> previousSpineItem() async {
    if (currentSpineItemIndex <= 0) {
      _showToast('已经是第一章');
      return;
    }

    await rendererController.jumpToPreviousChapterLastPage();

    setState(() {
      currentSpineItemIndex--;
    });

    preloadPreviousOf(currentSpineItemIndex);
    bookSession.flushProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }

  Future<void> previousSpineItemFirstPage() async {
    if (currentSpineItemIndex <= 0) {
      _showToast('已经是第一章');
      return;
    }

    await rendererController.jumpToPreviousChapterFirstPage();

    setState(() {
      currentSpineItemIndex--;
      currentPageInChapter = 0;
    });
    updateProgressDebounced();

    preloadPreviousOf(currentSpineItemIndex);
    bookSession.flushProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }

  Future<void> nextSpineItem() async {
    if (currentSpineItemIndex >= bookSession.spine.length - 1) {
      _showToast('已经是最后一章');
      return;
    }

    await rendererController.jumpToNextChapter();

    setState(() {
      currentSpineItemIndex++;
      currentPageInChapter = 0;
    });
    updateProgressDebounced();

    preloadNextOf(currentSpineItemIndex);
    bookSession.flushProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }

  Future<void> navigateToTocItem(TocEntry item) async {
    final targetHref = bookSession.findFirstValidHref(item);

    if (targetHref == null) {
      _showToast('该章节无内容');
      return;
    }

    final index = bookSession.findSpineIndexForTocItem(item);

    if (index != null) {
      final anchor = targetHref.href.contains('#')
          ? targetHref.href.split('#').last
          : 'top';
      await navigateToSpineItem(index, anchor);
    } else {
      _showToast('目录章节未找到');
      debugPrint(
        'Warning: Chapter with href ${targetHref.href} not found in spine.',
      );
    }
  }

  Future<void> navigateToFirstTocItemFirstPage() async {
    navigateToSpineItem(0, 'top');
  }

  Set<TocEntry> resolveActiveItems() {
    return bookSession.resolveActiveItems(currentSpineItemIndex);
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }
}
