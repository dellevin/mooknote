import 'dart:io';
import 'package:flutter/material.dart';

/// Display mode for the book grid item.
enum ViewMode { relaxed, compact }

/// Book grid item widget – displays a single book in the grid.
/// Appearance branches based on [ViewMode].
class BookGridItem extends StatelessWidget {
  final Map<String, dynamic> book;
  final ViewMode viewMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const BookGridItem({
    super.key,
    required this.book,
    required this.viewMode,
    this.onTap,
    this.onLongPress,
  });

  // ─── public build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: switch (viewMode) {
        ViewMode.relaxed => _buildRelaxed(context),
        ViewMode.compact => _buildCompact(context),
      },
    );
  }

  // ─── mode helpers ─────────────────────────────────────────────────────────

  /// Relaxed: 封面卡片 + 标题 + 作者，底部进度条。
  Widget _buildRelaxed(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final progress = _readingProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildCoverStack(context, fit: StackFit.expand, extras: [
              // 底部渐变背景 + 进度条
              if (progress > 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 12,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.5,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white70),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: colors.onSurface,
          ),
        ),
        if (author.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );
  }

  /// Compact: cover only, title gradient overlay + progress badge.
  Widget _buildCompact(BuildContext context) {
    final title = book['title'] as String? ?? '';

    return _buildCoverStack(
      context,
      fit: StackFit.expand,
      extras: [
        // Bottom gradient + title
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(6),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 32, 6, 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  shadows: [
                    const Shadow(
                      color: Colors.black54,
                      blurRadius: 2.0,
                      offset: Offset(0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Progress badge (top-right)
        _buildProgressBadge(context),
      ],
    );
  }

  // ─── shared cover stack ───────────────────────────────────────────────────

  Widget _buildCoverStack(
    BuildContext context, {
    List<Widget> extras = const [],
    StackFit fit = StackFit.loose,
  }) {
    final coverPath = book['cover_path'] as String?;
    final hasCover =
        coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync();

    return Stack(
      fit: fit,
      children: [
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: hasCover
              ? Image.file(
                  File(coverPath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(context),
                )
              : _buildPlaceholder(context),
        ),
        ...extras,
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.auto_stories_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  // ─── badge helpers ────────────────────────────────────────────────────────

  /// Progress badge (compact mode).
  Widget _buildProgressBadge(BuildContext context) {
    final progress = _readingProgress;
    if (progress <= 0) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.8),
          child: Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  double get _readingProgress =>
      (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;
}
