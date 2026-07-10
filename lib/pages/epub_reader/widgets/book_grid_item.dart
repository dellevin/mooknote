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
              // 阅读状态角标
              _buildStatusBadge(context),
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

  /// Compact: cover only, title + author gradient overlay + progress badge.
  Widget _buildCompact(BuildContext context) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';

    return _buildCoverStack(
      context,
      fit: StackFit.expand,
      extras: [
        // 阅读状态角标
        _buildStatusBadge(context),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(6),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 24, 6, 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
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
                  if (author.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
    final colors = Theme.of(context).colorScheme;
    final title = book['title'] as String? ?? '';
    final initial = title.isNotEmpty ? title.substring(0, 1) : '';
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: initial.isNotEmpty
            ? Text(initial,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.2),
                ))
            : Icon(
                Icons.auto_stories_outlined,
                size: 36,
                color: colors.onSurface.withValues(alpha: 0.2),
              ),
      ),
    );
  }

  // ─── badge helpers ────────────────────────────────────────────────────────

  /// 阅读状态角标（左上角，含百分比）
  Widget _buildStatusBadge(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = _readingProgress;
    final String label;
    final Color color;
    if (progress >= 1.0) {
      label = '已读';
      color = const Color(0xFF16A34A);
    } else if (progress > 0.0) {
      label = '在读 ${(progress * 100).toInt()}%';
      color = colors.primary;
    } else {
      label = '未读';
      color = const Color(0xFFDC2626);
    }

    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  double get _readingProgress =>
      (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;
}
