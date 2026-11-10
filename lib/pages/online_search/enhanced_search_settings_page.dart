import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../utils/user_prefs.dart';
import '../../utils/server_config.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';

/// 增强搜索设置页面
class EnhancedSearchSettingsPage extends StatefulWidget {
  const EnhancedSearchSettingsPage({super.key});

  @override
  State<EnhancedSearchSettingsPage> createState() =>
      _EnhancedSearchSettingsPageState();
}

class _EnhancedSearchSettingsPageState
    extends State<EnhancedSearchSettingsPage> {
  final _userPrefs = UserPrefs();
  final _movieTokenController = TextEditingController();
  final _bookTokenController = TextEditingController();

  bool _enabled = false;
  bool _testing = false;
  // null=未验证/检查中, true=有效, false=无效
  bool? _movieTokenValid;
  bool? _bookTokenValid;
  String? _movieTokenMessage;
  String? _bookTokenMessage;

  @override
  void initState() {
    super.initState();
    _enabled = _userPrefs.enhancedSearchEnabled;
    _movieTokenController.text = _userPrefs.movieSearchToken;
    _bookTokenController.text = _userPrefs.bookSearchToken;
  }

  @override
  void dispose() {
    _movieTokenController.dispose();
    _bookTokenController.dispose();
    super.dispose();
  }

  /// 仅测试当前输入的两个 Token，不保存
  Future<void> _verifyTokens() async {
    final movieToken = _movieTokenController.text.trim();
    final bookToken = _bookTokenController.text.trim();
    if (movieToken.isEmpty && bookToken.isEmpty) return;

    setState(() {
      _testing = true;
      _movieTokenValid = null;
      _bookTokenValid = null;
      _movieTokenMessage = null;
      _bookTokenMessage = null;
    });

    try {
      await Future.wait([
        if (movieToken.isNotEmpty) _verifyMovie(movieToken),
        if (bookToken.isNotEmpty) _verifyBook(bookToken),
      ]);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _verifyMovie(String token) async {
    final result = await _checkToken(token, 'movie');
    if (!mounted) return;
    if (result != null && result['valid'] == true) {
      setState(() {
        _movieTokenValid = true;
        _movieTokenMessage = result['messageString'] as String?;
      });
    } else {
      // 当前类型失败，用另一种类型重试
      final retry = await _checkToken(token, 'book');
      if (!mounted) return;
      setState(() {
        _movieTokenValid = false;
        _movieTokenMessage = retry != null && retry['valid'] == true
            ? '该 Token 可能是书籍类型，请检查是否填错位置'.tr
            : ((result != null ? result['messageString'] as String? : null) ??
                '验证失败'.tr);
      });
    }
  }

  Future<void> _verifyBook(String token) async {
    final result = await _checkToken(token, 'book');
    if (!mounted) return;
    if (result != null && result['valid'] == true) {
      setState(() {
        _bookTokenValid = true;
        _bookTokenMessage = result['messageString'] as String?;
      });
    } else {
      final retry = await _checkToken(token, 'movie');
      if (!mounted) return;
      setState(() {
        _bookTokenValid = false;
        _bookTokenMessage = retry != null && retry['valid'] == true
            ? '该 Token 可能是影视类型，请检查是否填错位置'.tr
            : ((result != null ? result['messageString'] as String? : null) ??
                '验证失败'.tr);
      });
    }
  }

  Future<Map<String, dynamic>?> _checkToken(String token, String type) async {
    try {
      final url = '${ServerConfig.vipBaseUrl}/api/token/check?token=$token&type=$type';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        if (data['code'] == 0 && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      await _userPrefs.setMovieSearchToken(_movieTokenController.text.trim());
      await _userPrefs.setBookSearchToken(_bookTokenController.text.trim());
      await _userPrefs.setEnhancedSearchEnabled(true);
      if (mounted) setState(() => _enabled = true);
    } else {
      await _userPrefs.setEnhancedSearchEnabled(false);
      if (mounted) setState(() => _enabled = false);
    }
  }

  /// 直接保存当前输入的两个 Token，不强制测试
  Future<void> _save() async {
    await _userPrefs.setMovieSearchToken(_movieTokenController.text.trim());
    await _userPrefs.setBookSearchToken(_bookTokenController.text.trim());
    if (mounted) ToastUtil.show(context, '保存成功'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('增强搜索'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSwitchRow(colors),
          const SizedBox(height: 16),
          _buildStatusBanner(colors),
          const SizedBox(height: 20),
          _buildSectionLabel(colors, '影视增强搜索 Token'.tr),
          const SizedBox(height: 8),
          _buildTokenInput(
            colors: colors,
            controller: _movieTokenController,
            hint: '输入影视搜索 Token'.tr,
            valid: _movieTokenValid,
            message: _movieTokenMessage,
          ),
          const SizedBox(height: 16),
          _buildSectionLabel(colors, '书籍增强搜索 Token'.tr),
          const SizedBox(height: 8),
          _buildTokenInput(
            colors: colors,
            controller: _bookTokenController,
            hint: '输入书籍搜索 Token'.tr,
            valid: _bookTokenValid,
            message: _bookTokenMessage,
          ),
          const SizedBox(height: 28),
          _buildSaveButton(colors),
          const SizedBox(height: 32),
          _buildTips(colors),
        ],
      ),
    );
  }

  Widget _buildSwitchRow(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _enabled
                  ? colors.primary.withValues(alpha: 0.1)
                  : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.manage_search,
                size: 18,
                color: _enabled
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('增强搜索'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 1),
                Text(_enabled ? '已开启'.tr : '未开启'.tr,
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _toggle,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: colors.surface,
            inactiveTrackColor: colors.outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _enabled
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _enabled
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : colors.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _enabled ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: _enabled
                ? const Color(0xFF16A34A)
                : colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _enabled ? '增强搜索已开启'.tr : '填写 Token 后开启增强搜索'.tr,
              style: TextStyle(
                fontSize: 13,
                color: _enabled
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

  Widget _buildTokenInput({
    required ColorScheme colors,
    required TextEditingController controller,
    required String hint,
    bool? valid,
    String? message,
  }) {
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
                  controller: controller,
                  style: TextStyle(fontSize: 13, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: hint,
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
        if (valid != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  valid ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: valid ? const Color(0xFF16A34A) : colors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    message ?? (valid ? 'Token 有效'.tr : 'Token 无效'.tr),
                    style: TextStyle(
                        fontSize: 11,
                        color: valid ? const Color(0xFF16A34A) : colors.error),
                  ),
                ),
              ],
            ),
          ),
        if (_testing && valid == null && controller.text.trim().isNotEmpty)
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
                Text('验证中...'.tr,
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSaveButton(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: _testing ? null : _verifyTokens,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.outlineVariant),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _testing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color:
                                  colors.onSurface.withValues(alpha: 0.4)))
                      : Text('测试连接'.tr,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurface)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: _testing ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('保存'.tr,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => launchUrl(
                Uri.parse(
                    'https://mooknote.iletter.top/info/token_doc.html'),
                mode: LaunchMode.externalApplication),
            child: Text('点击获取 Token'.tr, style: TextStyle(fontSize: 12, color: colors.primary)),
          ),
        ),
      ],
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
          _tip(colors, '增强搜索可在线检索影视和书籍的详细信息'.tr),
          _tip(colors, 'Token 过期或失效后需重新获取并填写'.tr),
          _tip(colors, '作者会在 QQ 群不定期发放增强搜索的token'.tr),
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
