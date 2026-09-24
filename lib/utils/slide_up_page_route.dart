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
          transitionDuration: const Duration(milliseconds: 2300),
          reverseTransitionDuration: const Duration(milliseconds: 1600),
        );
}

/// 分段直线 RectTween（与 BookOpenHero 的淡化区间同节奏）：
/// 打开（目标比源大）：600ms 放大到全屏 → 800ms 定格 → 900ms 定格（淡出期）；
/// 关闭（目标比源小）：900ms 定格（淡入期）→ 300ms 定格 → 400ms 缩小。
class _PhasedRectTween extends RectTween {
  _PhasedRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    final b = begin, e = end;
    if (b == null || e == null) return super.lerp(t);
    final expanding = e.shortestSide > b.shortestSide;
    final tt = expanding
        ? const Interval(0.0, 600 / 2300, curve: Curves.easeInOutCubic).transform(t)
        : const Interval(1200 / 1600, 1.0, curve: Curves.easeInOutCubic).transform(t);
    return Rect.lerp(b, e, tt);
  }
}

/// 放大打开式整页 Hero — 三段式容器变换：
/// 打开（2300ms）：①600ms 封面（海报）从所在位置放大铺满全屏
///       ②800ms 全屏定格（海报完整展示）
///       ③900ms 封面线性淡出，露出详情页；
/// 关闭（1600ms）：①900ms 详情页线性淡成海报
///       ②300ms 全屏定格
///       ③400ms 封面缩小退回海报位置。
/// 直线轨迹（无弧线回弹）+ 圆角随形变 + 线性同步淡化，两端状态与
/// 列表卡片/详情页逐像素一致，无生硬切换。
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
      createRectTween: (begin, end) => _PhasedRectTween(begin: begin, end: end),
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
            // 透明度用线性区间：同步交叉淡化，无加速"闪变"
            final t = flight.value;
            // 打开：放大与定格阶段（前 1400ms）封面完全不透明；
            //       最后 900ms 封面线性淡出、书页同步淡入
            // 关闭：前 900ms 书页线性淡出、封面同步淡入；
            //       定格 300ms 后封面缩小 400ms 收回
            final pageOpacity = opening
                ? const Interval(1400 / 2300, 1.0).transform(t)
                : 1 - const Interval(0.0, 900 / 1600).transform(t);
            final coverOpacity = opening
                ? 1 - const Interval(1400 / 2300, 1.0).transform(t)
                : const Interval(0.0, 900 / 1600).transform(t);
            // 圆角随容器形变（与 _PhasedRectTween 同节奏），落点与列表卡片一致
            final radiusT = opening
                ? const Interval(0.0, 600 / 2300, curve: Curves.easeInOutCubic).transform(t)
                : const Interval(1200 / 1600, 1.0, curve: Curves.easeInOutCubic).transform(t);
            final radius = _cardRadius * (1 - radiusT);
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
