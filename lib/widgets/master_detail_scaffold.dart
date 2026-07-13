import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Master-Detail 布局包装器
/// 手机或 detail 为 null 时只显示 master；平板显示左右分栏
class MasterDetailScaffold extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final double masterFraction;
  final double minMasterWidth;

  const MasterDetailScaffold({
    super.key,
    required this.master,
    this.detail,
    this.masterFraction = 0.38,
    this.minMasterWidth = 320,
  });

  @override
  Widget build(BuildContext context) {
    // 桌面三栏布局下只显示 detail（列表已在侧边栏）
    if (Breakpoint.isDesktop(context) && detail != null) {
      return detail!;
    }
    if (!Breakpoint.isWideContent(context) || detail == null) {
      return master;
    }
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectiveMasterWidth =
        (screenWidth * masterFraction).clamp(minMasterWidth, screenWidth * 0.5);
    return Row(
      children: [
        SizedBox(width: effectiveMasterWidth, child: master),
        const VerticalDivider(width: 0.5, thickness: 0.5),
        Expanded(child: detail!),
      ],
    );
  }
}
