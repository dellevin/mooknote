import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/server_config.dart';
import '../utils/user_prefs.dart';

/// 崩溃上报 + 意见反馈（设备维度，免登录，与心跳同鉴权方式）
///
/// 崩溃上报：按签名去重（与服务端相同的规范化规则），
/// 同一签名只上报一次，已上报签名持久化在本地。
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  static const String _reportedKey = 'reported_crash_sigs';
  static const int _maxReported = 200;

  bool _hookInstalled = false;
  FlutterExceptionHandler? _prevFlutterError;
  bool Function(Object, StackTrace)? _prevPlatformError;

  /// 本 session 已尝试过上报的签名（成功或失败都只试一次，避免刷屏）
  final Set<String> _attempted = {};

  String? _appVersionCache;

  // ─── 崩溃自动上报 ────────────────────────────────────────────────────

  /// 安装全局崩溃钩子（main 中调用，与调试日志开关无关）。
  /// 调试模式下 LogService 随后安装时会链式包装，addError 里也会触发上报，
  /// 同一签名经过去重不会重复提交。
  void installCrashHook() {
    if (_hookInstalled) return;
    _hookInstalled = true;

    _prevFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      reportCrash(
          '[FlutterError] ${details.exceptionAsString()}\n${details.stack}');
      _prevFlutterError?.call(details);
    };

    _prevPlatformError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      reportCrash('[Uncaught] $error\n$stack');
      final prev = _prevPlatformError;
      if (prev != null) return prev(error, stack);
      return false; // 不拦截，继续走默认处理
    };
  }

  /// 上报一条崩溃（带堆栈文本）。已上报/已尝试过的签名直接跳过。
  /// 返回是否实际上传成功。
  Future<bool> reportCrash(String error) async {
    if (error.trim().isEmpty) return false;
    final sig = _signature(error);
    if (!_attempted.add(sig)) return false;
    if (_loadReported().contains(sig)) return false;
    final deviceId = UserPrefs().deviceId;
    if (deviceId.isEmpty) return false;

    try {
      final resp = await http
          .post(
            Uri.parse('${ServerConfig.apiBase}/crash-report'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_hash': deviceId,
              'app_version': await _appVersion(),
              'device_type': Platform.operatingSystem,
              'error': error,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        await _markReported(sig);
        return true;
      }
    } catch (_) {
      // 静默失败，不影响主流程
    }
    return false;
  }

  /// 手动提交运行日志（用户主动触发，不做签名去重，每次都上传；
  /// 首行统一为 [用户日志] 前缀，服务端聚合到同一分组下）
  Future<bool> reportLogs(String text) async {
    final deviceId = UserPrefs().deviceId;
    if (deviceId.isEmpty || text.trim().isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('${ServerConfig.apiBase}/crash-report'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_hash': deviceId,
              'app_version': await _appVersion(),
              'device_type': Platform.operatingSystem,
              'error': text,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 崩溃签名：与服务端一致（首行规范化后 sha256 前 16 位）
  static final _hexRe = RegExp(r'0x[0-9a-fA-F]+');
  static final _numRe = RegExp(r'\d+');
  String _signature(String error) {
    var first = error.split('\n').first.trim();
    first = first.replaceAll(_hexRe, '0x').replaceAll(_numRe, 'N');
    return sha256.convert(utf8.encode(first)).toString().substring(0, 16);
  }

  Set<String> _loadReported() =>
      (UserPrefs().prefs.getStringList(_reportedKey) ?? []).toSet();

  Future<void> _markReported(String sig) async {
    final list = UserPrefs().prefs.getStringList(_reportedKey) ?? [];
    if (list.contains(sig)) return;
    list.add(sig);
    if (list.length > _maxReported) {
      list.removeRange(0, list.length - _maxReported);
    }
    await UserPrefs().prefs.setStringList(_reportedKey, list);
  }

  Future<String> _appVersion() async {
    if (_appVersionCache != null) return _appVersionCache!;
    try {
      final p = await PackageInfo.fromPlatform();
      _appVersionCache = '${p.version}+${p.buildNumber}';
    } catch (_) {
      _appVersionCache = '';
    }
    return _appVersionCache!;
  }

  // ─── 意见反馈 ────────────────────────────────────────────────────────

  /// 提交反馈，成功返回 true
  Future<bool> submitFeedback(String content, String contact) async {
    final deviceId = UserPrefs().deviceId;
    if (deviceId.isEmpty || content.trim().isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('${ServerConfig.apiBase}/feedback'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_hash': deviceId,
              'content': content.trim(),
              'contact': contact.trim(),
              'app_version': await _appVersion(),
              'device_type': Platform.operatingSystem,
            }),
          )
          .timeout(const Duration(seconds: 8));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// 拉取自己的反馈与管理员回复
  Future<List<Map<String, dynamic>>> fetchMyFeedback() async {
    final deviceId = UserPrefs().deviceId;
    if (deviceId.isEmpty) return [];
    try {
      final resp = await http
          .get(Uri.parse(
              '${ServerConfig.apiBase}/feedback?device_hash=$deviceId'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return (data['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      // 静默失败
    }
    return [];
  }
}
