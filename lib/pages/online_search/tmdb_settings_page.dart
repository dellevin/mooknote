import 'package:flutter/material.dart';
import '../../services/tmdb_service.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';

/// TMDB 搜索设置页面 —— 填写 API Token，测试成功才保存
class TmdbSettingsPage extends StatefulWidget {
  const TmdbSettingsPage({super.key});

  @override
  State<TmdbSettingsPage> createState() => _TmdbSettingsPageState();
}

class _TmdbSettingsPageState extends State<TmdbSettingsPage> {
  final _userPrefs = UserPrefs();
  final _tokenController = TextEditingController();

  bool _saved = false; // 是否已有保存的 Token
  bool _testing = false;
  // null=未验证, true=有效, false=无效/网络不通
  bool? _valid;
  String? _message;

  @override
  void initState() {
    super.initState();
    final token = _userPrefs.tmdbApiToken;
    _tokenController.text = token;
    _saved = token.isNotEmpty;
    if (_saved) _testAndSave(silent: true);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  /// 测试 Token；成功则保存，失败不保存
  Future<void> _testAndSave({bool silent = false}) async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      if (!silent) ToastUtil.show(context, '请输入 API Token'.tr);
      return;
    }
    setState(() {
      _testing = true;
      _valid = null;
      _message = null;
    });

    final result = await TmdbService.testToken(token);
    if (!mounted) return;

    switch (result.status) {
      case TmdbTestStatus.ok:
        await _userPrefs.setTmdbApiToken(token);
        await _userPrefs.setTmdbAuthType(result.authType);
        TmdbService.instance.configure(token, result.authType);
        setState(() {
          _saved = true;
          _valid = true;
          _message = '测试成功，Token 已保存'.tr;
        });
        break;
      case TmdbTestStatus.invalidToken:
        setState(() {
          _valid = false;
          _message = 'Token 无效，未保存'.tr;
        });
        break;
      case TmdbTestStatus.networkError:
        setState(() {
          _valid = false;
          _message = '网络不通，无法连接 TMDB 服务器，未保存'.tr;
        });
        break;
    }
    setState(() => _testing = false);
  }

  Future<void> _clear() async {
    await _userPrefs.setTmdbApiToken('');
    TmdbService.instance.configure('', 'bearer');
    setState(() {
      _saved = false;
      _valid = null;
      _message = null;
      _tokenController.clear();
    });
    if (mounted) ToastUtil.show(context, '已清除 TMDB Token'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('TMDB 搜索'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatusBanner(colors),
          const SizedBox(height: 20),
          _buildSectionLabel(colors, 'TMDB API Token'.tr),
          const SizedBox(height: 8),
          _buildTokenInput(colors),
          const SizedBox(height: 28),
          _buildSaveButton(colors),
          if (_saved) ...[
            const SizedBox(height: 12),
            _buildClearButton(colors),
          ],
          const SizedBox(height: 32),
          _buildTips(colors),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _saved
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _saved
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : colors.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _saved ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: _saved
                ? const Color(0xFF16A34A)
                : colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saved ? 'TMDB 搜索已开启'.tr : '填写 API Token 并测试成功后开启'.tr,
              style: TextStyle(
                fontSize: 13,
                color: _saved
                    ? const Color(0xFF16A34A)
                    : colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ColorScheme colors, String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurface.withValues(alpha: 0.5)));
  }

  Widget _buildTokenInput(ColorScheme colors) {
    return Column(
      children: [
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.key,
                  size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tokenController,
                  style: TextStyle(fontSize: 13, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: '输入 API Token 或 API Key'.tr,
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        if (_testing)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.onSurface.withValues(alpha: 0.3))),
                const SizedBox(width: 6),
                Text('测试中...'.tr,
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          )
        else if (_valid != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  _valid! ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: _valid! ? const Color(0xFF16A34A) : colors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _message ??
                        (_valid! ? 'Token 有效'.tr : '验证失败'.tr),
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            _valid! ? const Color(0xFF16A34A) : colors.error),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSaveButton(ColorScheme colors) {
    return GestureDetector(
      onTap: _testing ? null : () => _testAndSave(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _testing
              ? colors.primary.withValues(alpha: 0.5)
              : colors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text('测试并保存'.tr,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.onPrimary)),
        ),
      ),
    );
  }

  Widget _buildClearButton(ColorScheme colors) {
    return GestureDetector(
      onTap: _clear,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Center(
          child: Text('清除已保存的 Token'.tr,
              style: TextStyle(fontSize: 14, color: colors.error)),
        ),
      ),
    );
  }

  Widget _buildTips(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('说明'.tr,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _tip(colors, '在 themoviedb.org 注册账号后，于 设置 → API 页面申请 Token'.tr),
          _tip(colors, '支持 API Read Access Token 和 API Key，会自动识别'.tr),
          _tip(colors, '需要设备能正常访问 TMDB 服务器'.tr),
          _tip(colors, 'Token 仅保存在本地，用于搜索电影和剧集信息'.tr),
        ],
      ),
    );
  }

  Widget _tip(ColorScheme colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Icon(Icons.circle,
                size: 4, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5),
                      height: 1.5))),
        ],
      ),
    );
  }
}
