import 'package:flutter/material.dart';

/// 静态星级评分组件
class AnimatedStarRating extends StatelessWidget {
  final double rating;
  final double starSize;
  final Color color;
  final bool showNumber;

  const AnimatedStarRating({
    super.key,
    required this.rating,
    this.starSize = 14,
    this.color = const Color(0xFFFFB800),
    this.showNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final starValue = rating / 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starIndex = index + 1;
          IconData iconData;
          if (starValue >= starIndex) {
            iconData = Icons.star;
          } else if (starValue >= starIndex - 0.5) {
            iconData = Icons.star_half;
          } else {
            iconData = Icons.star_border;
          }
          return Icon(iconData, size: starSize, color: color);
        }),
        if (showNumber) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: starSize,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}
