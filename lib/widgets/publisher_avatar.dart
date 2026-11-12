import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 出版社头像（只读聚合实体，无独立 logo，统一用 SVG 图标占位）。
class PublisherAvatar extends StatelessWidget {
  final double size;
  final double iconSize;

  /// 圆角；为 null 时显示圆形
  final double? borderRadius;

  const PublisherAvatar({
    super.key,
    required this.size,
    this.iconSize = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: borderRadius == null ? null : BorderRadius.circular(borderRadius!),
        shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: SvgPicture.asset(
          'assets/svg/chubanshe.svg',
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            colors.onSurface.withValues(alpha: 0.35),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
