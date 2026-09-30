import 'dart:io';

/// 平台判断工具：统一"桌面端"语义，避免散落各处的 Platform.isWindows 判断
class PlatformUtils {
  /// 桌面平台（Windows / Linux）
  /// 用于：FFI 数据库初始化、窗口管理、桌面布局、移动专属功能（分享/相册选图/WebView）降级
  static bool get isDesktop => Platform.isWindows || Platform.isLinux;
}
