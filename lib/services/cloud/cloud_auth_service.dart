import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../l10n/app_strings.dart';
import '../../main.dart';
import '../../utils/server_config.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';

/// 云端账号操作结果
class CloudAuthResult {
  final bool success;
  final String message;

  /// 头像上传成功时返回的图片 URL
  final String? url;

  const CloudAuthResult({required this.success, this.message = '', this.url});
}

/// 服务器云同步：注册/登录/续期（my_sys api 模块 /app/auth）
class CloudAuthService {
  CloudAuthService._();
  static final CloudAuthService instance = CloudAuthService._();

  String get _base => '${ServerConfig.cloudApiBase}/app/auth';

  String get token => UserPrefs().cloudToken;
  bool get isLoggedIn => token.isNotEmpty;

  /// 图形验证码地址（每次刷新生成新 uuid，加时间戳避免图片缓存）
  String captchaUrl(String uuid) =>
      '$_base/captcha?uuid=$uuid&_t=${DateTime.now().millisecondsSinceEpoch}';

  /// 注册（成功即登录，服务端直接返回 token）
  Future<CloudAuthResult> register({
    required String username,
    required String password,
    required String captcha,
    required String uuid,
    required String mobile,
    required String email,
    String? inviteCode,
  }) {
    return _authenticate('register', {
      'username': username,
      'password': password,
      'captcha': captcha,
      'uuid': uuid,
      'mobile': mobile,
      'email': email,
      'inviteCode': inviteCode ?? '',
      'deviceHash': UserPrefs().deviceId,
    });
  }

  /// 注册是否必填邀请码（后台参数控制，公开接口）。
  /// 网络异常按非必填处理，服务端仍会做兜底校验。
  Future<bool> fetchInviteRequired() async {
    try {
      final resp = await http
          .get(Uri.parse('$_base/invite-required'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      return data['code'] == 0 && data['data'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 登录
  Future<CloudAuthResult> login({
    required String username,
    required String password,
    required String captcha,
    required String uuid,
  }) {
    return _authenticate('login', {
      'username': username,
      'password': password,
      'captcha': captcha,
      'uuid': uuid,
      'deviceHash': UserPrefs().deviceId,
    });
  }

  Future<CloudAuthResult> _authenticate(String path, Map<String, dynamic> body) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) {
        return CloudAuthResult(success: false, message: data['msg']?.toString() ?? '');
      }
      await _saveLoginData(data['data'] as Map<String, dynamic>?);
      return const CloudAuthResult(success: true);
    } catch (_) {
      return CloudAuthResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  /// 退出登录，无论服务端结果如何都清除本地登录态
  Future<void> logout() async {
    final t = token;
    if (t.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse('$_base/logout'),
              headers: {'token': t},
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // 静默处理，本地照常退出
      }
    }
    await UserPrefs().clearCloudAccount();
  }

  /// App 启动时调用：token 有效则滑动续期；失效则清除本地登录态。
  /// 返回 true 表示仍在线，false 表示已失效（调用方提示并保持本地数据可用）。
  Future<bool> renewOnStartup() async {
    final t = token;
    if (t.isEmpty) return false;
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/renew'),
            headers: {'token': t},
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) {
        await UserPrefs().clearCloudAccount();
        return false;
      }
      await _saveUserInfo(data['data'] as Map<String, dynamic>?);
      return true;
    } catch (_) {
      // 网络异常不踢登录，下次启动再校验
      return true;
    }
  }

  /// 主动校验当前登录态（进入云账号页时调用）。
  /// 失效（被强制下线/停用/token 过期）返回 false 并清除本地登录态、全局提示；
  /// 网络异常返回 true，不踢登录，下次再校验。
  Future<bool> checkLoginStatus() async {
    final t = token;
    if (t.isEmpty) return false;
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/me'),
            headers: {'token': t},
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) {
        if (_handleUnauthorized(data)) return false;
        return false;
      }
      await _saveUserInfo(data['data'] as Map<String, dynamic>?);
      return true;
    } catch (_) {
      // 网络异常不踢登录
      return true;
    }
  }

  /// 上传头像到 MinIO，成功时 url 为可访问的图片地址
  Future<CloudAuthResult> uploadAvatar(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/avatar'))
        ..headers['token'] = token
        ..files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final data = jsonDecode(utf8.decode(await streamed.stream.toBytes()))
          as Map<String, dynamic>;
      if (data['code'] != 0) {
        if (_handleUnauthorized(data)) return _expiredResult();
        return CloudAuthResult(success: false, message: data['msg']?.toString() ?? '');
      }
      return CloudAuthResult(success: true, url: data['data']?.toString() ?? '');
    } catch (_) {
      return CloudAuthResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  /// 编辑资料（昵称、用户名、手机号、邮箱、座右铭、头像），成功后同步更新本地用户信息
  Future<CloudAuthResult> updateProfile({
    required String username,
    required String nickname,
    required String mobile,
    required String email,
    required String motto,
    required String avatar,
  }) async {
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/profile'),
            headers: {'Content-Type': 'application/json', 'token': token},
            body: jsonEncode({
              'username': username,
              'nickname': nickname,
              'mobile': mobile,
              'email': email,
              'motto': motto,
              'avatar': avatar,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['code'] != 0) {
        if (_handleUnauthorized(data)) return _expiredResult();
        return CloudAuthResult(success: false, message: data['msg']?.toString() ?? '');
      }
      await _saveUserInfo(data['data'] as Map<String, dynamic>?);
      return const CloudAuthResult(success: true);
    } catch (_) {
      return CloudAuthResult(success: false, message: '网络连接失败，请稍后再试'.tr);
    }
  }

  /// 会话失效统一处理：清除本地登录态（含云端模式开关）并全局提示，本地数据不受影响。
  /// 供不经过本类接口的云端通道（explore/journal 等）在收到 401 时调用。
  Future<void> handleSessionExpired() async {
    await UserPrefs().clearCloudAccount();
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ToastUtil.show(ctx, '登录失效，已切换成本地数据，请重新登录'.tr);
    }
  }

  /// 服务端返回 401（token 过期/被后台强制下线/用户停用）：
  /// 清除本地登录态并全局提示，本地数据不受影响
  bool _handleUnauthorized(Map<String, dynamic> data) {
    if (data['code'] != 401) return false;
    UserPrefs().clearCloudAccount();
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ToastUtil.show(ctx, '登录失效，已切换成本地数据，请重新登录'.tr);
    }
    return true;
  }

  CloudAuthResult _expiredResult() =>
      CloudAuthResult(success: false, message: '登录失效，已切换成本地数据，请重新登录'.tr);

  Future<void> _saveLoginData(Map<String, dynamic>? data) async {
    if (data == null) return;
    final prefs = UserPrefs();
    await prefs.setCloudToken(data['token']?.toString() ?? '');
    await _saveUserInfo(data['userInfo'] as Map<String, dynamic>?);
  }

  Future<void> _saveUserInfo(Map<String, dynamic>? user) async {
    if (user == null) return;
    final prefs = UserPrefs();
    await prefs.setCloudUserId(user['id']?.toString() ?? '');
    await prefs.setCloudUsername(user['username']?.toString() ?? '');
    await prefs.setCloudNickname(user['nickname']?.toString() ?? '');
    await prefs.setCloudMobile(user['mobile']?.toString() ?? '');
    await prefs.setCloudEmail(user['email']?.toString() ?? '');
    await prefs.setCloudAvatar(user['avatar']?.toString() ?? '');
    await prefs.setCloudMotto(user['motto']?.toString() ?? '');
  }
}
