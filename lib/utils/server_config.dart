import 'package:flutter/foundation.dart';

/// 服务端地址配置
class ServerConfig {
  ServerConfig._();

  static const String baseUrl = kDebugMode
      ? 'http://192.168.31.48:27047'
      : 'http://api.mooknote.iletter.top';

  static const String apiBase = '$baseUrl/api';

  static const String vipBaseUrl = kDebugMode
      ? 'http://vipapi.mooknote.iletter.top'
      // ? 'http://192.168.31.48:8081'
      : 'http://vipapi.mooknote.iletter.top';

  /// 服务器云同步（my_sys api 模块，context-path 为 /api）
  static const String cloudApiBase = kDebugMode
      ? 'http://192.168.31.48:8082/api'
      : 'http://vipapi.mooknote.iletter.top/api';
}
