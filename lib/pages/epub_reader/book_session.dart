import 'dart:async';

import '../../utils/epub/epub_webview_handler.dart';
import '../../utils/epub/reader_dao.dart';
import '../../utils/epub/reader_models.dart';

/// Manages the current reading session including book data, TOC state, and
/// progress tracking.  Adapted from lumina's BookSession but uses mooknote's
/// existing models instead of Isar.
class BookSession {
  final String fileHash;
  final Map<String, dynamic> bookData;
  EpubBookInfo epubInfo;
  final ReaderDao _readerDao;

  // TOC Synchronization: Pre-calculated lookup maps
  final Map<String, List<String>> _spineToAnchorsMap = {};
  final List<TocEntry> _tocItemFallback = [];
  final List<TocEntry> _flatToc = [];
  final Map<String, int> _hrefToTocIndexMap = {};
  Set<String> _activeAnchors = {};

  final List<SpineItem> _spine = [];
  final List<SpineItem> _noLinearSpine = [];

  Timer? _debounceTimer;

  BookSession({
    required this.fileHash,
    required this.bookData,
    required this.epubInfo,
    required ReaderDao readerDao,
  }) : _readerDao = readerDao;

  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Update EPUB info after parsing (called when session is created before parse)
  void updateEpubInfo(EpubBookInfo info) {
    epubInfo = info;
  }

  // Getters
  Map<String, dynamic> get book => bookData;
  EpubBookInfo get epubBookInfo => epubInfo;
  List<SpineItem> get spine => _spine;
  List<SpineItem> get noLinearSpine => _noLinearSpine;
  List<TocEntry> get toc => epubInfo.toc;
  Set<String> get activeAnchors => _activeAnchors;
  bool get isLoaded => true; // data is passed at construction time
  int get direction => 0; // mooknote reader_books has no direction column

  /// Initialize spine filtering and TOC lookup maps from passed data.
  /// Call once after construction.
  void load() {
    // Filter spine into linear / non-linear
    _spine.clear();
    _noLinearSpine.clear();
    for (final item in epubInfo.spine) {
      if (item.linear) {
        _spine.add(item);
      } else {
        _noLinearSpine.add(item);
      }
    }

    _buildTocLookupMaps();
  }

  /// Pre-calculate TOC lookup maps for efficient synchronization.
  void _buildTocLookupMaps() {
    _flatToc.clear();
    _hrefToTocIndexMap.clear();
    _spineToAnchorsMap.clear();

    void processItem(TocEntry item) {
      final id = _flatToc.length;
      _flatToc.add(item);

      // TocEntry.href is "path#anchor"
      final parts = item.href.split('#');
      final filePath = parts[0];
      final anchorId = parts.length > 1 ? parts[1] : 'top';

      // Use composite key "path#anchor" for uniqueness
      _hrefToTocIndexMap[item.href] = id;
      _spineToAnchorsMap.putIfAbsent(filePath, () => []).add(anchorId);

      for (final child in item.children) {
        processItem(child);
      }
    }

    for (final item in epubInfo.toc) {
      processItem(item);
    }

    // Build fallback: for each spine item, pick the nearest preceding TOC entry
    TocEntry? fallback;
    _tocItemFallback.clear();
    for (final spineItem in _spine) {
      if (fallback != null) _tocItemFallback.add(fallback);
      final anchors = _spineToAnchorsMap[spineItem.href] ?? [];
      if (anchors.isNotEmpty) {
        final lastHref = '${spineItem.href}#${anchors.last}';
        final idx = _hrefToTocIndexMap[lastHref];
        if (idx != null) {
          fallback = _flatToc[idx];
        }
      }
    }
  }

  // ─── Progress saving ──────────────────────────────────────────────

  /// Save reading progress (debounced 10ms).
  void saveProgress({
    required int currentChapterIndex,
    required int currentPageInChapter,
    required int totalPagesInChapter,
  }) {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 10), () async {
      var progress = 0.0;
      if (_spine.isNotEmpty) {
        final delta = 1.0 / _spine.length;
        progress = (currentChapterIndex + 1) / _spine.length;
        if (totalPagesInChapter > 0) {
          progress -= delta;
          progress +=
              delta * ((currentPageInChapter + 1) / totalPagesInChapter);
        }
      }

      await _readerDao.updateReadingProgress(
        fileHash,
        '$currentChapterIndex',
        progress,
      );
    });
  }

  // ─── Spine / TOC helpers ──────────────────────────────────────────

  /// Get anchors (anchor ids) for a given spine file path.
  List<String> getAnchorsForSpine(String spinePath) {
    return _spineToAnchorsMap[spinePath] ?? [];
  }

  /// Update active anchors based on scroll position.
  void updateActiveAnchors(List<String> anchorIds) {
    _activeAnchors = anchorIds.toSet();
  }

  /// Get the virtual URL for a spine item, optionally with an anchor.
  String getSpineItemUrl(int index, [String anchor = 'top']) {
    if (index < 0 || index >= _spine.length) return '';
    final href = Href(path: _spine[index].href, anchor: anchor);
    return EpubWebViewHandler.getFileUrl(fileHash, href);
  }

  /// Find the spine index that contains a given TOC entry.
  int? findSpineIndexForTocItem(TocEntry item) {
    final parts = item.href.split('#');
    final targetPath = parts[0];
    final index = _spine.indexWhere((s) => s.href == targetPath);
    return index != -1 ? index : null;
  }

  /// Resolve all active TOC items for the current spine item + anchors.
  Set<TocEntry> resolveActiveItems(int currentSpineItemIndex) {
    final activeItems = <TocEntry>{};
    if (currentSpineItemIndex < 0 ||
        currentSpineItemIndex >= _spine.length) {
      return activeItems;
    }

    final path = _spine[currentSpineItemIndex].href;
    for (final anchor in _activeAnchors) {
      final key = '$path#$anchor';
      final tocIndex = _hrefToTocIndexMap[key];
      if (tocIndex != null && tocIndex < _flatToc.length) {
        activeItems.add(_flatToc[tocIndex]);
      }
    }

    if (activeItems.isEmpty &&
        _tocItemFallback.isNotEmpty &&
        currentSpineItemIndex < _tocItemFallback.length) {
      activeItems.add(_tocItemFallback[currentSpineItemIndex]);
    }
    return activeItems;
  }

  /// Find the first valid (non-empty path) href in a TOC entry tree.
  TocEntry? findFirstValidHref(TocEntry item) {
    final parts = item.href.split('#');
    if (parts[0].isNotEmpty) {
      return item;
    }

    for (final child in item.children) {
      final found = findFirstValidHref(child);
      if (found != null) return found;
    }

    return null;
  }

  /// Get spine item properties (if any). Mooknote SpineItem has no
  /// properties field, so return null.
  String? getSpineProperties(int index) => null;

  /// Resolve the TOC entry that best represents the current view.
  TocEntry? resolveActiveTocEntry(int currentSpineItemIndex) {
    if (currentSpineItemIndex < 0 ||
        currentSpineItemIndex >= _spine.length) {
      return null;
    }

    final path = _spine[currentSpineItemIndex].href;
    for (final anchor in _activeAnchors) {
      final key = '$path#$anchor';
      final tocIndex = _hrefToTocIndexMap[key];
      if (tocIndex != null && tocIndex < _flatToc.length) {
        return _flatToc[tocIndex];
      }
    }

    // Fallback
    if (_tocItemFallback.isNotEmpty &&
        currentSpineItemIndex < _tocItemFallback.length) {
      return _tocItemFallback[currentSpineItemIndex];
    }
    return null;
  }

  /// Find spine index from a URL string (virtual epub:// or relative path).
  int? findSpineIndexByUrl(String url) {
    String path;
    if (url.startsWith(EpubWebViewHandler.virtualScheme)) {
      final uri = Uri.parse(url);
      path = uri.pathSegments.skip(2).join('/');
    } else {
      path = url.split('#')[0];
    }

    final index = _spine.indexWhere((s) => s.href == path);
    return index != -1 ? index : null;
  }

  // ─── Initial position (from saved state) ──────────────────────────

  /// The last-read chapter index stored in the book record.
  int get initialChapterIndex {
    final cfi = bookData['last_read_cfi'] as String? ?? '';
    if (cfi.isEmpty) return 0;
    return int.tryParse(cfi) ?? 0;
  }

  /// No scroll-position column in reader_books yet; return null.
  double? get initialScrollPosition => null;
}
