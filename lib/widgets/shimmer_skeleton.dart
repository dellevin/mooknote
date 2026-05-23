import 'package:flutter/material.dart';

/// 骨架屏加载组件 — 闪烁占位动画
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0).withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// 影视骨架屏
class MovieSkeletonGrid extends StatelessWidget {
  const MovieSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShimmerSkeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 8,
            ),
          ),
          const SizedBox(height: 8),
          const ShimmerSkeleton(width: double.infinity, height: 14),
          const SizedBox(height: 4),
          const ShimmerSkeleton(width: 70, height: 12),
        ],
      ),
    );
  }
}

/// 书籍骨架屏
class BookSkeletonGrid extends StatelessWidget {
  const BookSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: 9,
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ShimmerSkeleton(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 4,
            ),
          ),
          const SizedBox(height: 8),
          const ShimmerSkeleton(width: double.infinity, height: 14),
          const SizedBox(height: 4),
          const ShimmerSkeleton(width: 70, height: 12),
        ],
      ),
    );
  }
}

/// 笔记列表骨架屏
class NoteSkeletonList extends StatelessWidget {
  const NoteSkeletonList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerSkeleton(width: 60, height: 12),
                SizedBox(width: 8),
                ShimmerSkeleton(width: 24, height: 12),
              ],
            ),
            SizedBox(height: 8),
            ShimmerSkeleton(width: 150, height: 16),
            SizedBox(height: 6),
            ShimmerSkeleton(width: double.infinity, height: 13),
            SizedBox(height: 4),
            ShimmerSkeleton(width: 200, height: 13),
          ],
        ),
      ),
    );
  }
}
