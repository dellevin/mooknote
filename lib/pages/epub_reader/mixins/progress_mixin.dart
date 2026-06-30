part of '../reader_screen.dart';

mixin _ProgressMixin on State<ReaderScreen> {
  // === Borrowed state (provided by _ReaderScreenState fields) ===
  int get totalPagesInChapter;

  int get currentPageInChapter;

  int get currentSpineItemIndex;

  BookSession get bookSession;

  bool get isWebViewLoading;

  String get displayProgress;
  set displayProgress(String v);

  Timer? get progressDebouncer;
  set progressDebouncer(Timer? v);

  Map<int, int> get chapterPageCounts;

  void updateProgressDebounced() {
    progressDebouncer?.cancel();
    progressDebouncer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (isWebViewLoading) return;

      final totalChapters = bookSession.spine.length;

      // 用当前章节页数估算全书页数
      final avgPages = totalPagesInChapter > 0 ? totalPagesInChapter : 1;
      final estimatedTotalPages = avgPages * totalChapters;

      // 估算绝对页码 = 已读章节数 * 平均每章页数 + 当前页
      final estimatedAbsolutePage =
          currentSpineItemIndex * avgPages + currentPageInChapter + 1;

      final pageStr = totalChapters > 0
          ? '$estimatedAbsolutePage/$estimatedTotalPages'
          : '${currentPageInChapter + 1}/$totalPagesInChapter';

      if (displayProgress != pageStr) {
        setState(() {
          displayProgress = pageStr;
        });
      }
    });
  }

  void saveProgress() {
    bookSession.saveProgress(
      currentChapterIndex: currentSpineItemIndex,
      currentPageInChapter: currentPageInChapter,
      totalPagesInChapter: totalPagesInChapter,
    );
  }
}
