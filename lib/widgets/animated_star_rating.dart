import 'package:flutter/material.dart';

/// 带动画的星级评分组件 — 星星依次亮起 + 数字滚动
class AnimatedStarRating extends StatefulWidget {
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
  State<AnimatedStarRating> createState() => _AnimatedStarRatingState();
}

class _AnimatedStarRatingState extends State<AnimatedStarRating>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;
  late Animation<double> _numberAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animations = List.generate(5, (i) {
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(i * 0.12, (i * 0.12) + 0.35, curve: Curves.easeOutBack),
      );
    });
    _numberAnim = Tween<double>(begin: 0, end: widget.rating).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          return ScaleTransition(
            scale: _animations[index],
            child: Icon(iconData, size: widget.starSize, color: widget.color),
          );
        }),
        if (widget.showNumber) ...[
          const SizedBox(width: 4),
          AnimatedBuilder(
            animation: _numberAnim,
            builder: (context, child) {
              return Text(
                _numberAnim.value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: widget.starSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF666666),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
