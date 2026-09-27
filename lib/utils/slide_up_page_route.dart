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

/// 纯淡入路由 — 配合整页 Hero 使用，页面本身由 Hero 动画携带，
/// 路由层不做位移，避免与 Hero 飞行叠加产生割裂感
class FadePageRoute extends PageRouteBuilder {
  FadePageRoute({required Widget page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: Curves.easeOut),
            );
            return FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 400),
        );
}

/// 直线 RectTween（easeInOutCubic 缓动）：打开全程放大、关闭全程缩小，
/// 无弧线回弹、无全屏定格
class _LinearRectTween extends RectTween {
  _LinearRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    final b = begin, e = end;
    if (b == null || e == null) return super.lerp(t);
    return Rect.lerp(b, e, Curves.easeInOutCubic.transform(t));
  }
}

/// 放大打开式整页 Hero — 容器变换一体完成：
/// 打开（500ms）：封面（海报）从所在位置放大铺满全屏，途中封面淡出、详情页淡入；
/// 关闭（400ms）：详情页缩小退回海报位置，途中详情页淡出、封面淡入。
/// 无全屏定格。直线轨迹（无弧线回弹）+ 圆角随形变 + 同步交叉淡化，
/// 两端状态与列表卡片/详情页逐像素一致，无生硬切换。
class BookOpenHero extends StatelessWidget {
  final String tag;
  final Widget child;

  const BookOpenHero({super.key, required this.tag, required this.child});

  /// 列表卡片的圆角（与 movie/book/game_list_item 的 borderRadius 一致）
  static const double _cardRadius = 8;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      // 分段直线轨迹：展开与淡化分两段进行，避免弧线回弹
      createRectTween: (begin, end) => _LinearRectTween(begin: begin, end: end),
      flightShuttleBuilder: (ctx, animation, direction, fromCtx, toCtx) {
        final opening = direction == HeroFlightDirection.push;
        // 取 Hero 的 child（封面=海报图，书页=详情页），不在飞行体里嵌套 Hero
        final cover = ((opening ? fromCtx : toCtx).widget as Hero).child;
        final page = ((opening ? toCtx : fromCtx).widget as Hero).child;
        final screen = MediaQuery.sizeOf(ctx);
        // 框架传给 shuttle 的动画在 pop 时是倒流的（1→0），而矩形轨迹
        // 用的是反向包装后的 0→1。归一化为沿飞行方向 0→1，两者才同步
        final flight = opening ? animation : ReverseAnimation(animation);
        return AnimatedBuilder(
          animation: flight,
          builder: (context, _) {
            // 形变与交叉淡化一体进行：打开时封面在放大中淡出、详情页同步淡入；
            // 关闭时详情页在缩小中淡出、封面同步淡入。线性区间避免加速"闪变"
            final t = flight.value;
            const fadeIn = Interval(0.35, 1.0);
            const fadeOut = Interval(0.0, 0.65);
            final pageOpacity =
                opening ? fadeIn.transform(t) : 1 - fadeOut.transform(t);
            final coverOpacity =
                opening ? 1 - fadeIn.transform(t) : fadeOut.transform(t);
            // 圆角随容器形变（与 RectTween 同一条缓动曲线），落点与列表卡片一致
            final radiusT = Curves.easeInOutCubic.transform(t);
            final radius =
                opening ? _cardRadius * (1 - radiusT) : _cardRadius * radiusT;
            return ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: pageOpacity,
                    // 书页始终按全屏尺寸布局、整体缩放进动画容器：
                    // 避免容器很小时页面被迫用小尺寸重排（Row 溢出 / 文字挤压）
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: screen.width,
                        height: screen.height,
                        child: page,
                      ),
                    ),
                  ),
                  Opacity(opacity: coverOpacity, child: cover),
                ],
              ),
            );
          },
        );
      },
      child: child,
    );
  }
}
