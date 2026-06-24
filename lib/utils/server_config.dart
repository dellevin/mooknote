import 'package:flutter/foundation.dart';

/// 服务端地址配置
class ServerConfig {
  ServerConfig._();

  static final String baseUrl = kDebugMode
      ? 'http://192.168.31.48:27047'
      : 'http://api.mooknote.iletter.top';

  static final String apiBase = '$baseUrl/api';

  static final String vipBaseUrl = kDebugMode
      ? 'http://192.168.31.48:8081'
      : 'http://vipapi.mooknote.iletter.top';
}
