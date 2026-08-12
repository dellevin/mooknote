import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 毛玻璃主题下的通用磨砂面板：真实背景模糊 + 半透明深色
/// 仅在毛玻璃模式下生效，其余主题直接透传 child，不影响原样式
class FrostedPanel extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final Color color;

  const FrostedPanel({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.color = const Color(0xCC121418),
  });

  @override
  Widget build(BuildContext context) {
    final frosted = context.watch<AppProvider>().frostedActive;
    if (!frosted) return child;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: ColoredBox(color: color, child: child),
      ),
    );
  }
}

/// 毛玻璃版底部弹层：毛玻璃模式下自动加磨砂，其余主题与原 showModalBottomSheet 一致
Future<T?> appModalBottomSheet<T>({
  required BuildContext context,
  Color? backgroundColor,
  Color? barrierColor,
  double? elevation,
  ShapeBorder? shape,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  bool showDragHandle = false,
  BoxConstraints? constraints,
  bool useRootNavigator = false,
  required WidgetBuilder builder,
}) {
  final frosted = context.read<AppProvider>().frostedActive;
  return showModalBottomSheet(
    context: context,
    backgroundColor: frosted ? Colors.transparent : backgroundColor,
    barrierColor: barrierColor,
    elevation: elevation,
    shape: shape,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    constraints: constraints,
    useRootNavigator: useRootNavigator,
    builder: (ctx) {
      final content = builder(ctx);
      if (!frosted) return content;
      return FrostedPanel(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: content,
      );
    },
  );
}

/// 毛玻璃版对话框：毛玻璃模式下自动加磨砂
Future<T?> appDialog<T>({
  required BuildContext context,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
  bool useRootNavigator = true,
  required WidgetBuilder builder,
}) {
  final frosted = context.read<AppProvider>().frostedActive;
  return showDialog(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    useRootNavigator: useRootNavigator,
    builder: (ctx) {
      final content = builder(ctx);
      if (!frosted) return content;
      return FrostedPanel(
        borderRadius: BorderRadius.circular(20),
        child: content,
      );
    },
  );
}