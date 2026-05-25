import 'package:flutter/material.dart';

/// 自定义下拉刷新包装器 — 统一使用品牌色
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final String? semanticsLabel;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      strokeWidth: 2.5,
      displacement: 60,
      semanticsLabel: semanticsLabel,
      child: child,
    );
  }
}
