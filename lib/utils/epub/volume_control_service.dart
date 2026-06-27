import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// 音量键翻页服务
/// 注意：需要原生 Android 实现才能工作，当前为空操作
class VolumeControlService {
  static const MethodChannel _methodChannel = MethodChannel(
    'mooknote/volume_control',
  );

  static bool _available = false;
  static bool _checked = false;

  static Future<void> enableInterception() async {
    if (!Platform.isAndroid) return;
    if (!_checked) await _checkAvailable();
    if (!_available) return;
    try {
      await _methodChannel.invokeMethod('enableInterception');
    } catch (_) {}
  }

  static Future<void> disableInterception() async {
    if (!Platform.isAndroid) return;
    if (!_available) return;
    try {
      await _methodChannel.invokeMethod('disableInterception');
    } catch (_) {}
  }

  static Stream<String> get volumeKeyEvents {
    if (!Platform.isAndroid || !_available) return const Stream.empty();
    // 需要原生 EventChannel 实现，当前返回空流
    return const Stream.empty();
  }

  /// 检查原生端是否实现了该 channel
  static Future<void> _checkAvailable() async {
    _checked = true;
    try {
      await _methodChannel.invokeMethod('enableInterception');
      _available = true;
    } on MissingPluginException {
      _available = false;
    } catch (_) {
      _available = false;
    }
  }
}
