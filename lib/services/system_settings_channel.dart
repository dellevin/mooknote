import 'package:flutter/services.dart';

/// 系统设置跳转通道
/// permission_handler 对已授权的存储权限不再拉起授权页，需原生直达
class SystemSettingsChannel {
  static const MethodChannel _channel =
      MethodChannel('top.iletter.mooknote/settings');

  /// 打开系统"所有文件访问"授权页（Android 11+），失败返回 false
  static Future<bool> openAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('openAllFilesAccess') ?? false;
    } catch (_) {
      return false;
    }
  }
}
