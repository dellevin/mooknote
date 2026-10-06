import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

/// 一条日志记录
class LogEntry {
  final DateTime time;
  final String message;

  LogEntry(this.time, this.message);

  /// 模块名（消息前缀 [xxx] 中的内容），无前缀返回 ''
  String get module {
    if (!message.startsWith('[')) return '';
    final end = message.indexOf(']');
    return end > 1 ? message.substring(1, end) : '';
  }

  /// 根据消息内容简单判断是否错误类日志（用于标红显示）
  bool get isError =>
      message.contains('错误') ||
      message.contains('失败') ||
      message.contains('异常') ||
      message.contains('Exception') ||
      message.contains('Error');

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 导出用格式化：2026-10-03 14:30:00.123 [模块] 消息
  String format() {
    final t = time;
    return '${t.year}-${_two(t.month)}-${_two(t.day)} '
        '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.'
        '${t.millisecond.toString().padLeft(3, '0')} $message';
  }
}

/// 运行日志服务：开启调试模式后接管全局 debugPrint / FlutterError，
/// 将日志保存在内存环形缓冲中，供调试日志页查看与导出。
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  static const int _maxEntries = 3000;
  static const int _maxErrors = 100;

  /// 按时间正序存放（新日志在末尾）
  final List<LogEntry> entries = [];

  /// 崩溃/异常记录（带堆栈），与普通日志分开存放
  final List<LogEntry> errors = [];

  bool _installed = false;
  bool get installed => _installed;

  DebugPrintCallback? _originalDebugPrint;
  FlutterExceptionHandler? _originalOnError;

  /// 安装全局钩子（幂等）
  void install() {
    if (_installed) return;
    _installed = true;

    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) add(message);
      _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
    };

    _originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      add('[FlutterError] ${details.exceptionAsString()}');
      addError('[FlutterError] ${details.exceptionAsString()}\n${details.stack}');
      _originalOnError?.call(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      add('[Uncaught] $error\n$stack');
      addError('[Uncaught] $error\n$stack');
      return false; // 不拦截，继续走默认处理
    };

    // 捕获 package:logging 输出（media_kit 等插件的日志通道）
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      var msg = '[${record.loggerName}] ${record.message}';
      if (record.error != null) msg += '\n${record.error}';
      add(msg);
    });

    add('[LogService] 调试日志已开启');
  }

  void add(String message) {
    entries.add(LogEntry(DateTime.now(), message));
    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }
  }

  /// 记录崩溃/异常（带堆栈），独立环形缓冲
  void addError(String message) {
    errors.add(LogEntry(DateTime.now(), message));
    if (errors.length > _maxErrors) {
      errors.removeRange(0, errors.length - _maxErrors);
    }
  }

  void clear() => entries.clear();
  void clearErrors() => errors.clear();
}

/// 记录页面导航轨迹的路由观察者（替换全局 routeObserver 使用）
class LoggingRouteObserver extends RouteObserver<ModalRoute<void>> {
  String _name(Route<dynamic> route) =>
      route.settings.name ?? route.runtimeType.toString();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    LogService.instance.add('[Route] 打开 ${_name(route)}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final back =
        previousRoute != null ? '，返回 ${_name(previousRoute)}' : '';
    LogService.instance.add('[Route] 关闭 ${_name(route)}$back');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      LogService.instance.add('[Route] 替换为 ${_name(newRoute)}');
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
