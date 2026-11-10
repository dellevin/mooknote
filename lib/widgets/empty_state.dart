import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// Notion 风格空状态：插画（或淡色小图标）+ 浅色短文案，
/// 可选一个虚线描边的操作按钮（如「添加影视」）。
/// 插画为白底黑线 PNG，深色主题下整体反色以贴合 surface。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    this.image,
    required this.message,
    this.actionLabel,
    this.onAction,
  }) : assert(icon != null || image != null, 'EmptyState 需要 icon 或 image 之一');

  final IconData? icon;
  final String? image;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Widget artwork;
    if (image != null) {
      final img = Image.asset(image!, width: 170, height: 170);
      artwork = isDark
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                -1, 0, 0, 0, 255,
                0, -1, 0, 0, 255,
                0, 0, -1, 0, 255,
                0, 0, 0, 1, 0,
              ]),
              child: img,
            )
          : img;
    } else {
      artwork = Icon(icon, size: 30, color: colors.onSurface.withValues(alpha: 0.22));
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          artwork,
          SizedBox(height: image != null ? 16 : 14),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.38),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            _DashedActionButton(label: actionLabel!, onTap: onAction!),
          ],
        ],
      ),
    );
  }
}

/// 虚线描边按钮：Notion 标志性的 dashed border 操作入口
class _DashedActionButton extends StatelessWidget {
  const _DashedActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = colors.onSurface.withValues(alpha: 0.45);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedRectPainter(color: color, radius: 10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label.tr,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashGap = 4.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final next = math.min(dist + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
