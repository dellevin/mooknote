import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reader_style_sheet.dart';

class ControlPanel extends StatefulWidget {
  final bool showControls;
  final String title;
  final int currentSpineItemIndex;
  final int totalSpineItems;
  final int currentPageInChapter;
  final int totalPagesInChapter;
  final int direction;
  final double fontSize;
  final double zoom;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final VoidCallback onBack;
  final VoidCallback onOpenDrawer;
  final VoidCallback onPreviousPage;
  final VoidCallback onFirstPage;
  final VoidCallback onNextPage;
  final VoidCallback onLastPage;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onToggleStyleDrawer;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onMarginTopChanged;
  final ValueChanged<double> onMarginBottomChanged;
  final ValueChanged<double> onMarginLeftChanged;
  final ValueChanged<double> onMarginRightChanged;

  const ControlPanel({
    super.key,
    required this.showControls,
    required this.title,
    required this.currentSpineItemIndex,
    required this.totalSpineItems,
    required this.currentPageInChapter,
    required this.totalPagesInChapter,
    required this.direction,
    required this.fontSize,
    required this.zoom,
    required this.marginTop,
    required this.marginBottom,
    required this.marginLeft,
    required this.marginRight,
    required this.onBack,
    required this.onOpenDrawer,
    required this.onPreviousPage,
    required this.onFirstPage,
    required this.onNextPage,
    required this.onLastPage,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onToggleStyleDrawer,
    required this.onZoomChanged,
    required this.onFontSizeChanged,
    required this.onMarginTopChanged,
    required this.onMarginBottomChanged,
    required this.onMarginLeftChanged,
    required this.onMarginRightChanged,
  });

  bool get isVertical => direction == 1;

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  Timer? _longPressTimer;

  static const int _animDurationMs = 250;
  static const double _topBarHeight = 64.0;
  static const double _bottomBarHeight = 48.0 + 16.0 + 16.0;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  bool get _shouldHandleOnPreviousChapter {
    return widget.currentSpineItemIndex > 0 || widget.currentPageInChapter > 0;
  }

  bool get _shouldHandleOnNextChapter {
    return widget.currentSpineItemIndex < widget.totalSpineItems - 1 ||
        (widget.currentSpineItemIndex == widget.totalSpineItems - 1 &&
            widget.currentPageInChapter < widget.totalPagesInChapter - 1);
  }

  bool get _shouldHandleOnLongPressLeft {
    if (widget.isVertical) {
      return _shouldHandleOnNextChapter;
    } else {
      return _shouldHandleOnPreviousChapter;
    }
  }

  bool get _shouldHandleOnLongPressRight {
    if (widget.isVertical) {
      return _shouldHandleOnPreviousChapter;
    } else {
      return _shouldHandleOnNextChapter;
    }
  }

  bool get _shouldHandleOnPreviousPage {
    return widget.currentSpineItemIndex > 0 || widget.currentPageInChapter > 0;
  }

  bool get _shouldHandleOnNextPage {
    return widget.currentSpineItemIndex < widget.totalSpineItems - 1 ||
        widget.currentPageInChapter < widget.totalPagesInChapter - 1;
  }

  bool get _shouldHandleOnPressLeft {
    if (widget.isVertical) {
      return _shouldHandleOnNextPage;
    } else {
      return _shouldHandleOnPreviousPage;
    }
  }

  bool get _shouldHandleOnPressRight {
    if (widget.isVertical) {
      return _shouldHandleOnPreviousPage;
    } else {
      return _shouldHandleOnNextPage;
    }
  }

  void _handlePreviousChapter() {
    if (widget.currentPageInChapter == 0 && widget.currentSpineItemIndex > 0) {
      HapticFeedback.selectionClick();
      widget.onPreviousChapter();
    } else if (widget.currentPageInChapter > 0) {
      HapticFeedback.selectionClick();
      widget.onFirstPage();
    }
  }

  void _handleNextChapter() {
    if (widget.currentSpineItemIndex < widget.totalSpineItems - 1) {
      HapticFeedback.selectionClick();
      widget.onNextChapter();
    } else if (widget.currentSpineItemIndex == widget.totalSpineItems - 1 &&
        widget.currentPageInChapter < widget.totalPagesInChapter - 1) {
      HapticFeedback.selectionClick();
      widget.onLastPage();
    }
  }

  void _handleLongPressLeft() {
    if (widget.isVertical) {
      _handleNextChapter();
    } else {
      _handlePreviousChapter();
    }
  }

  void _handleLongPressRight() {
    if (widget.isVertical) {
      _handlePreviousChapter();
    } else {
      _handleNextChapter();
    }
  }

  void _handleTapLeft() {
    if (widget.isVertical) {
      widget.onNextPage();
    } else {
      widget.onPreviousPage();
    }
  }

  void _handleTapRight() {
    if (widget.isVertical) {
      widget.onPreviousPage();
    } else {
      widget.onNextPage();
    }
  }

  String _formatPageIndicator(int current, int total) {
    if (total == 0) {
      return '0/0';
    }
    current = current.clamp(1, total);
    final totalStr = total.toString();
    final currentStr = current.toString();
    return '$currentStr/$totalStr';
  }

  void _openStyleSheet() {
    widget.onToggleStyleDrawer();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      barrierColor: Colors.black54,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 24, bottom: 16),
                    height: 4,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Flexible(
                  child: ReaderStyleSheet(
                    zoom: widget.zoom,
                    marginTop: widget.marginTop,
                    marginBottom: widget.marginBottom,
                    marginLeft: widget.marginLeft,
                    marginRight: widget.marginRight,
                    fontSize: widget.fontSize,
                    onZoomChanged: widget.onZoomChanged,
                    onFontSizeChanged: widget.onFontSizeChanged,
                    onMarginTopChanged: widget.onMarginTopChanged,
                    onMarginBottomChanged: widget.onMarginBottomChanged,
                    onMarginLeftChanged: widget.onMarginLeftChanged,
                    onMarginRightChanged: widget.onMarginRightChanged,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final topStatusBarHeight = MediaQuery.of(context).padding.top;
    final bottomStatusBarHeight = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        // Top Bar
        AnimatedPositioned(
          duration: const Duration(milliseconds: _animDurationMs),
          curve: Curves.easeInOut,
          top: widget.showControls ? 0 : -(_topBarHeight + topStatusBarHeight),
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: _animDurationMs),
            opacity: widget.showControls ? 1.0 : 0.0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
              ),
              child: AppBar(
                backgroundColor: colorScheme.surfaceContainer,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_outlined),
                  onPressed: widget.onBack,
                ),
                title: Text(
                  widget.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),

        // Bottom Bar
        AnimatedPositioned(
          duration: const Duration(milliseconds: _animDurationMs),
          curve: Curves.easeInOut,
          bottom: widget.showControls
              ? 0
              : -(_bottomBarHeight + bottomStatusBarHeight),
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: _animDurationMs),
            opacity: widget.showControls ? 1.0 : 0.0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomStatusBarHeight + 16,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
              ),
              constraints: BoxConstraints(
                maxHeight: _bottomBarHeight + bottomStatusBarHeight,
                minHeight: _bottomBarHeight + bottomStatusBarHeight,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.list_outlined),
                    onPressed: widget.onOpenDrawer,
                    color: colorScheme.onSurface,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onLongPressStart: _shouldHandleOnLongPressLeft
                            ? (_) {
                                _handleLongPressLeft();
                                _longPressTimer = Timer.periodic(
                                  const Duration(milliseconds: 500),
                                  (timer) {
                                    _handleLongPressLeft();
                                  },
                                );
                              }
                            : null,
                        onLongPressEnd: (_) {
                          _longPressTimer?.cancel();
                        },
                        onLongPressCancel: () {
                          _longPressTimer?.cancel();
                        },
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left_outlined),
                          onPressed:
                              _shouldHandleOnPressLeft ? _handleTapLeft : null,
                          onLongPress: null,
                          disabledColor: Theme.of(context).disabledColor,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Visibility(
                                visible: false,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: Text(
                                  '0' * (2 * 4 + 1),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                _formatPageIndicator(
                                  widget.currentSpineItemIndex + 1,
                                  widget.totalSpineItems,
                                ),
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (widget.totalPagesInChapter > 1)
                            Text(
                              _formatPageIndicator(
                                widget.currentPageInChapter + 1,
                                widget.totalPagesInChapter,
                              ),
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 10,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                        ],
                      ),
                      GestureDetector(
                        onLongPressStart: _shouldHandleOnLongPressRight
                            ? (_) {
                                _handleLongPressRight();
                                _longPressTimer = Timer.periodic(
                                  const Duration(milliseconds: 500),
                                  (timer) {
                                    _handleLongPressRight();
                                  },
                                );
                              }
                            : null,
                        onLongPressEnd: (_) {
                          _longPressTimer?.cancel();
                        },
                        onLongPressCancel: () {
                          _longPressTimer?.cancel();
                        },
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right_outlined),
                          onPressed: _shouldHandleOnPressRight
                              ? _handleTapRight
                              : null,
                          onLongPress: null,
                          disabledColor: Theme.of(context).disabledColor,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.brush_outlined),
                    onPressed: _openStyleSheet,
                    color: colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
