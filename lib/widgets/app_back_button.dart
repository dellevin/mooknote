import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 全局统一返回按钮：使用 assets/svg/fan_hui.svg
/// 颜色默认跟随 AppBar/IconTheme，点击默认 Navigator.maybePop
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.size = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    return IconButton(
      icon: SvgPicture.asset(
        'assets/svg/fan_hui.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      ),
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}
