import 'package:flutter/material.dart';

/// Master-Detail 布局中右侧详情区的空白占位
class DetailPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;

  const DetailPlaceholder({
    super.key,
    this.message = '选择一条记录查看详情',
    this.icon = Icons.touch_app_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: colors.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}
