import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class FootnotePopupOverlay extends StatefulWidget {
  final Rect anchorRect;
  final String rawHtml;
  final VoidCallback onDismiss;
  final ColorScheme colorScheme;
  final double zoom;

  const FootnotePopupOverlay({
    super.key,
    required this.anchorRect,
    required this.rawHtml,
    required this.onDismiss,
    required this.colorScheme,
    this.zoom = 1.0,
  });

  @override
  State<FootnotePopupOverlay> createState() => FootnotePopupOverlayState();
}

class FootnotePopupOverlayState extends State<FootnotePopupOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  late bool _slideFromLeft;

  Future<void> playReverseAnimation() async {
    if (mounted) {
      await _animationController.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideFromLeft = true;
    if (!_animationController.isAnimating &&
        !_animationController.isCompleted) {
      _animationController.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    _slideFromLeft = widget.anchorRect.center.dx < (screenWidth / 2);
    _slideAnimation =
        Tween<Offset>(
          begin: Offset(_slideFromLeft ? -1.0 : 1.0, 0.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final safePadding = MediaQuery.of(context).padding;

    const double minBookmarkWidth = 150;
    final double maxBookmarkWidth = screenSize.width * 0.8;

    final spaceBelow =
        screenSize.height -
        widget.anchorRect.bottom -
        max(safePadding.bottom, 32);
    final spaceAbove = widget.anchorRect.top - safePadding.top;

    final bool showBelow = spaceBelow >= spaceAbove;

    final double calculatedMaxHeight = showBelow
        ? (spaceBelow - safePadding.bottom - 12.0)
        : (spaceAbove - safePadding.top - 12.0);

    final double maxBookmarkHeight = calculatedMaxHeight.clamp(
      100.0,
      screenSize.height * 0.4,
    );

    final double topPosition = showBelow ? widget.anchorRect.bottom + 6.0 : -1;
    final double bottomPosition = !showBelow
        ? (screenSize.height - widget.anchorRect.top) + 6.0
        : -1;

    final borderRadius = BorderRadius.horizontal(
      left: _slideFromLeft ? Radius.zero : const Radius.circular(4),
      right: _slideFromLeft ? const Radius.circular(4) : Radius.zero,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Strip HTML tags and decode entities for simple text display
    final plainText = widget.rawHtml
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: topPosition != -1 ? topPosition : null,
          bottom: bottomPosition != -1 ? bottomPosition : null,
          left: _slideFromLeft ? 0 : null,
          right: !_slideFromLeft ? 0 : null,
          child: Material(
            color: Colors.transparent,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: widget.colorScheme.shadow.withAlpha(
                        isDark ? 50 : 25,
                      ),
                      blurRadius: 16,
                      offset: Offset(_slideFromLeft ? 4 : -4, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: maxBookmarkHeight,
                        maxWidth: maxBookmarkWidth,
                        minWidth: minBookmarkWidth,
                      ),
                      decoration: BoxDecoration(
                        color: widget.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.75),
                        border: Border(
                          left: !_slideFromLeft
                              ? BorderSide(
                                  color: widget.colorScheme.primary,
                                  width: 4,
                                )
                              : BorderSide.none,
                          right: _slideFromLeft
                              ? BorderSide(
                                  color: widget.colorScheme.primary,
                                  width: 4,
                                )
                              : BorderSide.none,
                          top: BorderSide(
                            color: widget.colorScheme.outlineVariant,
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: widget.colorScheme.outlineVariant,
                            width: 1,
                          ),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Text(
                          plainText,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: widget.colorScheme.onSurface,
                                height: 1.6,
                                fontSize:
                                    (Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.fontSize ??
                                            14.0) *
                                    widget.zoom,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
