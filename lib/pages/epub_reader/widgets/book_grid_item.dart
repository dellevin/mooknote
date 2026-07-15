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
    return RepaintBoundary(
      child: GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: switch (viewMode) {
        ViewMode.relaxed => _buildRelaxed(context),
        ViewMode.compact => _buildCompact(context),
      },
      ),
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
              // 阅读状态圆点
              _buildStatusDot(context),
              // 底部进度条
              if (progress > 0 && progress < 1.0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildProgressBar(context, progress, height: 3),
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

  /// Compact: cover only, title + author gradient overlay + progress badge.
  Widget _buildCompact(BuildContext context) {
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final progress = _readingProgress;

    return _buildCoverStack(
      context,
      fit: StackFit.expand,
      extras: [
        // 阅读状态圆点
        _buildStatusDot(context),
        // 底部进度条
        if (progress > 0 && progress < 1.0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(context, progress, height: 3),
          ),
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
    final title = book['title'] as String? ?? '';
    final initial = title.isNotEmpty ? title.substring(0, 1) : '';
    // 根据书名首字生成渐变色
    final gradientColors = _generateGradientColors(initial);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: initial.isNotEmpty
            ? Text(initial,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ))
            : Icon(
                Icons.auto_stories_outlined,
                size: 36,
                color: Colors.white.withValues(alpha: 0.5),
              ),
      ),
    );
  }

  // ─── badge helpers ────────────────────────────────────────────────────────

  /// 阅读状态圆点（左上角，三色）
  Widget _buildStatusDot(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = _readingProgress;
    final Color dotColor;
    if (progress >= 1.0) {
      dotColor = const Color(0xFF16A34A);
    } else if (progress > 0.0) {
      dotColor = colors.primary;
    } else {
      dotColor = const Color(0xFFDC2626);
    }

    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: dotColor.withValues(alpha: 0.4),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部进度条
  Widget _buildProgressBar(BuildContext context, double progress, {double height = 3}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: height,
          backgroundColor: Colors.black26,
          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          borderRadius: BorderRadius.zero,
        ),
      ],
    );
  }

  // ─── helpers ──────────────────────────────────────────────────────────────

  double get _readingProgress =>
      (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;

  /// 根据首字符生成渐变色
  List<Color> _generateGradientColors(String initial) {
    if (initial.isEmpty) return [const Color(0xFF6B7280), const Color(0xFF9CA3AF)];
    final code = initial.codeUnitAt(0);
    final palettes = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)], // 靛蓝-紫
      [const Color(0xFF3B82F6), const Color(0xFF06B6D4)], // 蓝-青
      [const Color(0xFF10B981), const Color(0xFF34D399)], // 绿
      [const Color(0xFFF59E0B), const Color(0xFFF97316)], // 琥珀-橙
      [const Color(0xFFEF4444), const Color(0xFFF472B6)], // 红-粉
      [const Color(0xFF8B5CF6), const Color(0xFFEC4899)], // 紫-粉
      [const Color(0xFF14B8A6), const Color(0xFF3B82F6)], // 青-蓝
      [const Color(0xFFF97316), const Color(0xFFEF4444)], // 橙-红
    ];
    return palettes[code % palettes.length];
  }
}
