import 'package:flutter/services.dart';

/// 系统媒体库扫描通道
/// 触发 Android MediaScanner 重新索引公共图片目录（Pictures / DCIM）
class MediaScanChannel {
  static const MethodChannel _channel =
      MethodChannel('top.iletter.mooknote/media_scan');

  static bool _handlerRegistered = false;
  static void Function(int done, int total)? _onProgress;

  /// 触发媒体扫描，返回提交扫描的文件数；失败返回 -1
  /// [onProgress] 每扫完一个文件回调一次（done/total）
  static Future<int> scanMedia({
    void Function(int done, int total)? onProgress,
  }) async {
    _onProgress = onProgress;
    if (!_handlerRegistered) {
      // 接收原生侧回传的扫描进度
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onProgress') {
          final args = call.arguments as Map;
          _onProgress?.call(
            (args['done'] as num).toInt(),
            (args['total'] as num).toInt(),
          );
        }
      });
      _handlerRegistered = true;
    }
    try {
      final result = await _channel.invokeMethod<int>('scanMedia');
      return result ?? -1;
    } catch (_) {
      return -1;
    } finally {
      _onProgress = null;
    }
  }
}
