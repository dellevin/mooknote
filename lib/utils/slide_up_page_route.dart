import 'package:flutter/material.dart';

/// 自定义页面过渡动画 — 向上滑入 + 淡入
class SlideUpPageRoute extends PageRouteBuilder {
  SlideUpPageRoute({
    required Widget page,
    Duration duration = const Duration(milliseconds: 350),
    Duration reverseDuration = const Duration(milliseconds: 250),
    double beginOffsetY = 0.08,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = Offset(0.0, beginOffsetY);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: Curves.easeOutCubic),
            );
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
            );
            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
        );
}
