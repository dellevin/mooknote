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
  final Function(TocEntry) onTocItemSelected;
  final VoidCallback? onCoverTap;
  final ThemeData themeData;

  const TocDrawer({
    super.key,
    required this.bookTitle,
    this.coverPath,
    required this.totalChapters,
    required this.toc,
    required this.activeTocItems,
    required this.onTocItemSelected,
    this.onCoverTap,
    required this.themeData,
  });

  @override
  State<TocDrawer> createState() => _TocDrawerState();
}

class _TocDrawerState extends State<TocDrawer> {
  final ScrollController _scrollController = ScrollController();
  final Set<TocEntry> _expandedItems = {};
  List<_TocRowItem> _visibleItems = [];

  @override
  void initState() {
    super.initState();
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
    _scrollController.dispose();
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

    if (index != -1 && _scrollController.hasClients) {
      final offset = (index * 56.0) - (56.0 * 4);
      _scrollController.jumpTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeData.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: widget.themeData.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _visibleItems.length + 1,
                itemExtent: 56.0,
                itemBuilder: (context, index) {
                  if (index == _visibleItems.length) {
                    return const SizedBox(height: 56);
                  }

                  final row = _visibleItems[index];
                  return _buildRowItem(context, row, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowItem(BuildContext context, _TocRowItem row, bool isDark) {
    final item = row.item;
    final isActive = widget.activeTocItems.contains(item);

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

  Widget _buildHeader(BuildContext context, bool isDark) {
    const authorText = '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.themeData.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: widget.themeData.colorScheme.outline,
            width: 1,
          ),
        ),
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
