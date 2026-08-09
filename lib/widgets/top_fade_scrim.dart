import 'package:flutter/material.dart';

/// 列表顶部渐变遮罩带：从 surface 色渐变到透明，
/// 让滚动内容从状态栏下方淡入淡出。
class TopFadeScrim extends StatelessWidget {
  const TopFadeScrim({super.key, this.height = 12});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.surface,
                colors.surface.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
