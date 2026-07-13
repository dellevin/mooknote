import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';

/// 响应式布局断点工具
class Breakpoint {
  /// ≥600dp: 平板布局（常驻侧边栏 + NavigationRail）
  static const double tablet = 600.0;

  /// ≥900dp: 宽屏内容区（列表-详情并排显示）
  static const double wideContent = 900.0;

  /// ≥1200dp: 桌面布局（侧边导航 + 宽内容区）
  static const double desktop = 1200.0;

  static bool isTablet(BuildContext context) =>
      Platform.isWindows || MediaQuery.sizeOf(context).width >= tablet;

  static bool isPhone(BuildContext context) =>
      !Platform.isWindows && MediaQuery.sizeOf(context).width < tablet;

  /// 是否使用宽屏内容布局（列表+详情并排）
  /// 桌面模式下始终为 true（列表已在第二栏，第三栏只显示详情）
  static bool isWideContent(BuildContext context) =>
      Platform.isWindows || MediaQuery.sizeOf(context).width >= wideContent;

  /// 是否使用桌面布局（侧边导航 + 宽内容区）
  /// Windows 平台始终使用桌面布局
  static bool isDesktop(BuildContext context) =>
      Platform.isWindows || MediaQuery.sizeOf(context).width >= desktop;
}

/// 根据可用宽度动态计算网格列数
int responsiveCrossAxisCount(
  double availableWidth, {
  double minItemWidth = 160,
  int minCount = 2,
  int maxCount = 6,
}) {
  final count = (availableWidth / minItemWidth).floor();
  return count.clamp(minCount, maxCount);
}
