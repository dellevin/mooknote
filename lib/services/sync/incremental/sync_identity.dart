import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// 同步客户端标识：每台设备安装后生成一个稳定 UUID
class SyncIdentity {
  static const String _key = 'sync_client_id';
  static const Uuid _uuid = Uuid();

  static String? _cached;
  static String get cachedClientId => _cached ?? '';

  static Future<String> clientId() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }
}
