import 'package:flutter/material.dart';

/// 自定义页面过渡动画 — 向上滑入 + 淡入
/// [withFade] 关闭时只滑入不淡入：毛玻璃页面若整体淡入，Flutter 会给页面加
/// group-opacity 层，导致页内 BackdropFilter 在转场期间失效（卡片透明、落定才磨砂）
class SlideUpPageRoute extends PageRouteBuilder {
  SlideUpPageRoute({
    required Widget page,
    Duration duration = const Duration(milliseconds: 350),
    Duration reverseDuration = const Duration(milliseconds: 250),
    double beginOffsetY = 0.08,
    bool withFade = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = Offset(0.0, beginOffsetY);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: Curves.easeOutCubic),
            );
            final slide = SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
            if (!withFade) return slide;
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
            );
            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: slide,
            );
          },
          transitionDuration: duration,
          reverseTransitionDuration: reverseDuration,
        );
}
