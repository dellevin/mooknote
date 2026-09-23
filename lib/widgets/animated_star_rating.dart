import 'package:flutter/material.dart';

/// 星级评分组件，支持可选的入场动画（星星逐个弹入）
class AnimatedStarRating extends StatefulWidget {
  final double rating;
  final double starSize;
  final Color color;
  final bool showNumber;

  /// 是否播放入场动画（列表中建议 false，详情/表单页建议 true）
  final bool animate;

  const AnimatedStarRating({
    super.key,
    required this.rating,
    this.starSize = 14,
    this.color = const Color(0xFFFFB800),
    this.showNumber = false,
    this.animate = false,
  });

  @override
  State<AnimatedStarRating> createState() => _AnimatedStarRatingState();
}

class _AnimatedStarRatingState extends State<AnimatedStarRating>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedStarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.forward(from: 0);
    } else if (!widget.animate) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final starValue = widget.rating / 2;
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

          if (!widget.animate) {
            return Icon(iconData, size: widget.starSize, color: widget.color);
          }

          // 逐个弹入：每颗星延迟 80ms
          final start = index * 0.13;
          final end = (start + 0.5).clamp(0.0, 1.0);
          final starAnim = CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: Curves.easeOutBack),
          );
          return ScaleTransition(
            scale: starAnim,
            child: FadeTransition(
              opacity: starAnim,
              child: Icon(iconData, size: widget.starSize, color: widget.color),
            ),
          );
        }),
        if (widget.showNumber) ...[
          const SizedBox(width: 4),
          Text(
            widget.rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: widget.starSize,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}
