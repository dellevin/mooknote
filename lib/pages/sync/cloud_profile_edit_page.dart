import 'dart:io';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../services/cloud/cloud_auth_service.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_back_button.dart';

/// 云同步账号资料编辑：用户名、手机号、邮箱、座右铭、头像
class CloudProfileEditPage extends StatefulWidget {
  const CloudProfileEditPage({super.key});

  @override
  State<CloudProfileEditPage> createState() => _CloudProfileEditPageState();
}

class _CloudProfileEditPageState extends State<CloudProfileEditPage> {
  final _usernameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mottoCtrl = TextEditingController();

  String _avatar = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final prefs = UserPrefs();
    _usernameCtrl.text = prefs.cloudUsername;
    _nicknameCtrl.text = prefs.cloudNickname;
    _mobileCtrl.text = prefs.cloudMobile;
    _emailCtrl.text = prefs.cloudEmail;
    _mottoCtrl.text = prefs.cloudMotto;
    _avatar = prefs.cloudAvatar;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _nicknameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _mottoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await pickSingleLocalImage(context);
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    if (await file.length() > 10 * 1024 * 1024) {
      _toast('头像不能超过10MB'.tr);
      return;
    }
    _showLoading();
    CloudAuthResult result;
    try {
      result = await CloudAuthService.instance.uploadAvatar(file);
    } finally {
      if (mounted) _hideLoading();
    }
    if (!mounted) return;
    if (result.success && result.url != null && result.url!.isNotEmpty) {
      setState(() => _avatar = result.url!);
    } else {
      _toast(result.message.isEmpty ? '头像上传失败'.tr : result.message);
    }
  }

  /// 全屏加载动画（与 App 内其他网络操作的 loading 样式一致）
  void _showLoading() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      barrierColor: Colors.black.withValues(alpha: 0.06),
      builder: (_) => Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.primary),
          ),
        ),
      ),
    );
  }

  void _hideLoading() => Navigator.of(context, rootNavigator: false).pop();

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim().replaceAll('＠', '@');
    final motto = _mottoCtrl.text.trim();
    if (username.isEmpty || mobile.isEmpty || email.isEmpty) {
      _toast('请填写完整信息'.tr);
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(username)) {
      _toast('用户名为4-20位字母、数字或下划线'.tr);
      return;
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(mobile)) {
      _toast('请输入正确的手机号'.tr);
      return;
    }
    if (!RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(email)) {
      _toast('请输入正确的邮箱'.tr);
      return;
    }

    setState(() => _saving = true);
    final result = await CloudAuthService.instance.updateProfile(
      username: username,
      nickname: nickname,
      mobile: mobile,
      email: email,
      motto: motto,
      avatar: _avatar,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.success) {
      _toast('资料修改成功'.tr);
      Navigator.pop(context, true);
    } else {
      _toast(result.message.isEmpty ? '操作失败，请稍后再试'.tr : result.message);
      // 登录失效时本地账号已被清除，退出编辑页让账号页回到登录表单
      if (!CloudAuthService.instance.isLoggedIn) {
        Navigator.pop(context);
      }
    }
  }

  void _toast(String msg) => ToastUtil.show(context, msg);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('编辑信息'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: _avatar.isEmpty
                    ? Icon(Icons.person_outline, size: 44, color: colors.onSurface.withValues(alpha: 0.4))
                    : Image.network(_avatar, fit: BoxFit.cover, gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Icon(Icons.person_outline,
                            size: 44, color: colors.onSurface.withValues(alpha: 0.4))),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('点击更换头像'.tr,
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
          ),
          const SizedBox(height: 24),
          _label(colors, '用户名'.tr),
          _inputField(
            controller: _usernameCtrl,
            hint: '4-20位字母、数字或下划线'.tr,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 16),
          _label(colors, '昵称'.tr),
          _inputField(
            controller: _nicknameCtrl,
            hint: '可与他人重复，留空默认同用户名'.tr,
            icon: Icons.badge_outlined,
            maxLength: 50,
          ),
          const SizedBox(height: 16),
          _label(colors, '手机号'.tr),
          _inputField(
            controller: _mobileCtrl,
            hint: '请输入手机号'.tr,
            icon: Icons.smartphone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _label(colors, '邮箱'.tr),
          _inputField(
            controller: _emailCtrl,
            hint: '请输入邮箱'.tr,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          _label(colors, '座右铭'.tr),
          _inputField(
            controller: _mottoCtrl,
            hint: '写点什么介绍自己吧'.tr,
            icon: Icons.format_quote_outlined,
            maxLength: 100,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('保存'.tr),
          ),
        ],
      ),
    );
  }

  Widget _label(ColorScheme colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(fontSize: 14, color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)),
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: colors.surface,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
    );
  }
}
