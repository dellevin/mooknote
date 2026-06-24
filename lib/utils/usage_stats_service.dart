import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_prefs.dart';
import 'server_config.dart';

/// 匿名用户统计服务（静默运行，对用户不可见）
///
/// App 启动后每 5 分钟向统计服务器发送匿名心跳。
/// 统计数据在服务端管理后台查看，App 内无入口。
class UsageStatsService with WidgetsBindingObserver {
  static final UsageStatsService instance = UsageStatsService._();
  UsageStatsService._();

  final UserPrefs _prefs = UserPrefs();

  /// 统计服务器地址，debug 走局域网，release 走线上
  static String serverUrl = '${ServerConfig.baseUrl}/';
  Timer? _heartbeatTimer;
  bool _started = false;

  static const _heartbeatInterval = Duration(minutes: 1);

  /// 启动统计服务（App 启动时调用一次）
  Future<void> start() async {
    if (_started) return;
    _started = true;

    // 未配置服务器地址则直接跳过
    if (serverUrl.isEmpty) return;

    // 首次启动生成匿名设备ID
    await _ensureDeviceId();

    // 注册生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 立即发送一次心跳
    await _sendHeartbeat();

    // 启动定时心跳
    _startTimer();
  }

  /// 停止统计服务
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  // ─── 内部方法 ──────────────────────────────────────────────────────────

  /// 确保设备有匿名ID
  Future<void> _ensureDeviceId() async {
    if (_prefs.deviceId.isEmpty) {
      final id = _generateDeviceId();
      await _prefs.setDeviceId(id);
    }
  }

  /// 生成匿名设备标识
  String _generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// 发送心跳
  Future<void> _sendHeartbeat() async {
    if (serverUrl.isEmpty) return;
    final deviceId = _prefs.deviceId;
    if (deviceId.isEmpty) return;

    try {
      await http
          .post(
            Uri.parse('$serverUrl/api/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_hash': deviceId,
              'device_type':
                  Platform.operatingSystem, // android/ios/windows/macos/linux
              'device_name':
                  '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }

  /// 启动定时心跳
  void _startTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
  }

  // ─── 生命周期 ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台：立即发送心跳，恢复定时器
      _sendHeartbeat();
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      // 进入后台：停止定时器
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }
}
