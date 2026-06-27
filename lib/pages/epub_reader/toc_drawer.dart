import 'dart:io';

import 'package:flutter/material.dart';
import '../../utils/epub/reader_models.dart';

/// Helper class to represent a visible row in the flattened TOC list
class _TocRowItem {
  final TocEntry item;
  final int depth;
  final bool isExpanded;
  final bool hasChildren;

  _TocRowItem({
    required this.item,
    required this.depth,
    required this.isExpanded,
    required this.hasChildren,
  });
}

class TocDrawer extends StatefulWidget {
  final String bookTitle;
  final String? coverPath;
  final int totalChapters;
  final List<TocEntry> toc;
  final Set<TocEntry> activeTocItems;
  final int currentSpineIndex;
  final Function(TocEntry) onTocItemSelected;
  final VoidCallback? onCoverTap;
  final ThemeData themeData;

  // 书签相关
  final List<Map<String, dynamic>> bookmarks;
  final void Function(Map<String, dynamic> bookmark)? onBookmarkTap;
  final void Function(int bookmarkId)? onBookmarkDelete;

  const TocDrawer({
    super.key,
    required this.bookTitle,
    this.coverPath,
    required this.totalChapters,
    required this.toc,
    required this.activeTocItems,
    this.currentSpineIndex = -1,
    required this.onTocItemSelected,
    this.onCoverTap,
    required this.themeData,
    this.bookmarks = const [],
    this.onBookmarkTap,
    this.onBookmarkDelete,
  });

  @override
  State<TocDrawer> createState() => _TocDrawerState();
}

class _TocDrawerState extends State<TocDrawer> with SingleTickerProviderStateMixin {
  final ScrollController _tocScrollController = ScrollController();
  final Set<TocEntry> _expandedItems = {};
  List<_TocRowItem> _visibleItems = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initExpansionState();
    _regenerateVisibleItems();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToFirstActive();
    });
  }

  @override
  void didUpdateWidget(covariant TocDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.toc != oldWidget.toc) {
      _expandedItems.clear();
      _initExpansionState();
      _regenerateVisibleItems();
    } else if (widget.activeTocItems != oldWidget.activeTocItems) {
      bool expandedChanged = _autoExpandParents();
      if (expandedChanged) {
        _regenerateVisibleItems();
      }
    }
  }

  @override
  void dispose() {
    _tocScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initExpansionState() {
    _autoExpandParents();
  }

  bool _autoExpandParents() {
    bool changed = false;
    if (widget.activeTocItems.isEmpty) return false;

    bool findAndExpand(TocEntry current, TocEntry target) {
      if (current == target) return true;

      for (final child in current.children) {
        if (findAndExpand(child, target)) {
          if (!_expandedItems.contains(current)) {
            _expandedItems.add(current);
            changed = true;
          }
          return true;
        }
      }
      return false;
    }

    for (final root in widget.toc) {
      for (final active in widget.activeTocItems) {
        findAndExpand(root, active);
      }
    }
    return changed;
  }

  void _regenerateVisibleItems() {
    final newItems = <_TocRowItem>[];

    void traverse(List<TocEntry> items, int depth) {
      for (final item in items) {
        final isExpanded = _expandedItems.contains(item);
        final hasChildren = item.children.isNotEmpty;

        newItems.add(
          _TocRowItem(
            item: item,
            depth: depth,
            isExpanded: isExpanded,
            hasChildren: hasChildren,
          ),
        );

        if (hasChildren && isExpanded) {
          traverse(item.children, depth + 1);
        }
      }
    }

    traverse(widget.toc, 0);

    setState(() {
      _visibleItems = newItems;
    });
  }

  void _toggleExpansion(TocEntry item) {
    if (_expandedItems.contains(item)) {
      _expandedItems.remove(item);
    } else {
      _expandedItems.add(item);
    }
    _regenerateVisibleItems();
  }

  void _scrollToFirstActive() {
    if (widget.activeTocItems.isEmpty || _visibleItems.isEmpty) return;

    final index = _visibleItems.indexWhere(
      (row) => widget.activeTocItems.contains(row.item),
    );

    if (index != -1 && _tocScrollController.hasClients) {
      final offset = (index * 56.0) - (56.0 * 4);
      _tocScrollController.jumpTo(
        offset.clamp(0.0, _tocScrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeData.brightness == Brightness.dark;
    final colors = widget.themeData.colorScheme;

    return Drawer(
      backgroundColor: widget.themeData.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            // Tab bar
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: colors.onSurface,
                unselectedLabelColor: colors.onSurfaceVariant,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
                indicatorColor: colors.onSurface,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '目录'),
                  Tab(text: '书签'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTocTab(context, isDark),
                  _buildBookmarkTab(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 目录 Tab ────────────────────────────────────────────────

  Widget _buildTocTab(BuildContext context, bool isDark) {
    return ListView.builder(
      controller: _tocScrollController,
      itemCount: _visibleItems.length + 1,
      itemExtent: 56.0,
      itemBuilder: (context, index) {
        if (index == _visibleItems.length) {
          return const SizedBox(height: 56);
        }

        final row = _visibleItems[index];
        return _buildRowItem(context, row, isDark);
      },
    );
  }

  Widget _buildRowItem(BuildContext context, _TocRowItem row, bool isDark) {
    final item = row.item;
    // 用 activeTocItems 匹配，或者直接用 spineIndex 匹配当前章节
    final isActive = widget.activeTocItems.contains(item) ||
        (item.spineIndex >= 0 && item.spineIndex == widget.currentSpineIndex);

    final double paddingLeft = 16.0 + (row.depth * 16.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (row.hasChildren) {
            _toggleExpansion(item);
          } else {
            widget.onTocItemSelected(item);
            Navigator.of(context).pop();
          }
        },
        child: Container(
          height: 56.0,
          padding: EdgeInsets.only(left: paddingLeft, right: 16.0),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              if (row.hasChildren)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    row.isExpanded
                        ? Icons.expand_more_outlined
                        : Icons.chevron_right_outlined,
                    size: 20,
                    color: widget.themeData.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                const SizedBox(width: 28),

              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: widget.themeData.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: isActive
                        ? widget.themeData.colorScheme.onSurface
                        : widget.themeData.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              if (isActive)
                Icon(
                  Icons.circle_outlined,
                  size: 8,
                  color: widget.themeData.colorScheme.onSurface,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 书签 Tab ────────────────────────────────────────────────

  Widget _buildBookmarkTab(BuildContext context, bool isDark) {
    final colors = widget.themeData.colorScheme;

    if (widget.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无书签', style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            Text('阅读时点击顶部书签图标添加', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.3))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 56),
      itemCount: widget.bookmarks.length,
      itemBuilder: (context, index) {
        final bm = widget.bookmarks[index];
        return _buildBookmarkItem(context, bm);
      },
    );
  }

  Widget _buildBookmarkItem(BuildContext context, Map<String, dynamic> bookmark) {
    final colors = widget.themeData.colorScheme;
    final content = bookmark['content'] as String? ?? '';
    final cfi = bookmark['cfi'] as String? ?? '';
    final createdAt = bookmark['created_at'] as String? ?? '';
    final bookmarkId = bookmark['id'] as int;

    // 解析页码信息
    String pageInfo = '';
    if (cfi.isNotEmpty) {
      final parts = cfi.split(':');
      if (parts.length >= 2) {
        final chapterIdx = int.tryParse(parts[0]) ?? 0;
        pageInfo = '第 ${chapterIdx + 1} 章';
      }
    }

    // 解析时间
    String timeStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        timeStr = '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Dismissible(
      key: ValueKey(bookmarkId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colors.error,
        child: Icon(Icons.delete_outline, color: colors.onError, size: 20),
      ),
      onDismissed: (_) {
        widget.onBookmarkDelete?.call(bookmarkId);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            widget.onBookmarkTap?.call(bookmark);
            Navigator.of(context).pop();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark, size: 18, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content.isNotEmpty ? content : pageInfo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.themeData.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (pageInfo.isNotEmpty && content.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          pageInfo,
                          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withValues(alpha: 0.5)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    const authorText = '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.themeData.colorScheme.surface,
      ),
      child: GestureDetector(
        onTap: () {
          widget.onCoverTap?.call();
          Navigator.of(context).pop();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover (placeholder or local image)
            SizedBox(
              width: 60,
              height: 90,
              child: _buildCoverPlaceholder(),
            ),

            const SizedBox(width: 16),

            // Book Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bookTitle,
                    style: widget.themeData.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (authorText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      authorText,
                      style: widget.themeData.textTheme.bodySmall?.copyWith(
                        color: widget.themeData.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '共 ${widget.totalChapters} 章',
                    style: widget.themeData.textTheme.bodySmall?.copyWith(
                      color: widget.themeData.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    if (widget.coverPath != null &&
        widget.coverPath!.isNotEmpty &&
        File(widget.coverPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(widget.coverPath!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderIcon(),
        ),
      );
    }
    return _placeholderIcon();
  }

  Widget _placeholderIcon() {
    return Container(
      decoration: BoxDecoration(
        color: widget.themeData.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Icon(
          Icons.book_outlined,
          size: 32,
          color: widget.themeData.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
