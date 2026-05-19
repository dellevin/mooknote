import 'package:flutter/services.dart';

/// 应用图标原生通道
/// 通过 MethodChannel 调用 Android activity-alias 切换桌面图标
class AppIconChannel {
  static const MethodChannel _channel =
      MethodChannel('top.iletter.mooknote/icon');

  /// 切换桌面图标
  /// [iconName] 图标名称，如 'app_icon' 或 'app_icon2'
  /// 返回是否成功
  static Future<bool> switchIcon(String iconName) async {
    try {
      final result = await _channel.invokeMethod('switchIcon', {
        'iconName': iconName,
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// 获取当前启用的图标名称
  static Future<String> getCurrentIcon() async {
    try {
      final result = await _channel.invokeMethod('getCurrentIcon');
      return result as String? ?? 'app_icon';
    } catch (e) {
      return 'app_icon';
    }
  }
}
