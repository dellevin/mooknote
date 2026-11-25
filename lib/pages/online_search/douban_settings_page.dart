import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/app_back_button.dart';
import '../../services/douban_service.dart';
import '../../services/http_proxy_overrides.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';
import 'douban_login_page.dart';

/// 豆瓣搜索设置页：WebView 登录收割 cookie，登录后支持分类翻页搜索
class DoubanSettingsPage extends StatefulWidget {
  const DoubanSettingsPage({super.key});

  @override
  State<DoubanSettingsPage> createState() => _DoubanSettingsPageState();
}

class _DoubanSettingsPageState extends State<DoubanSettingsPage> {
  final _userPrefs = UserPrefs();
  final _proxyController = TextEditingController();

  bool _busy = false;
  late bool _enabled;
  bool? _valid;
  String? _message;

  bool get _loggedIn => _userPrefs.doubanLoggedIn;

  @override
  void initState() {
    super.initState();
    _proxyController.text = _userPrefs.doubanProxy;
    _enabled = _userPrefs.doubanSearchEnabled;
  }

  Future<void> _toggle(bool value) async {
    await _userPrefs.setDoubanSearchEnabled(value);
    if (mounted) setState(() => _enabled = value);
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final cookiesJson =
        await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const DoubanLoginPage(),
    ));
    if (cookiesJson == null || cookiesJson.isEmpty) return;
    await _userPrefs.setDoubanCookies(cookiesJson);
    _applyServiceConfig();
    if (!mounted) return;
    setState(() {
      _valid = null;
      _message = null;
    });
    ToastUtil.show(context, '豆瓣登录成功'.tr);
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _valid = null;
      _message = null;
    });
    final ok = await DoubanService.testLogin(
      _userPrefs.doubanCookies,
      proxy: _proxyController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _valid = ok;
      _message = ok ? '登录态有效'.tr : '登录已失效，请重新登录'.tr;
    });
  }

  Future<void> _saveProxy() async {
    final proxy = _proxyController.text.trim();
    await _userPrefs.setDoubanProxy(proxy);
    _applyServiceConfig();
    if (!mounted) return;
    ToastUtil.show(context, '保存成功'.tr);
  }

  void _applyServiceConfig() {
    DoubanService.instance
        .configure(_userPrefs.doubanCookies, proxy: _userPrefs.doubanProxy);
    // 保持全局代理覆盖已安装（豆瓣图片流量仍走直连，代理仅作用于搜索接口）
    installHttpProxyOverrides(
      bangumiProxy: _userPrefs.bangumiProxy,
      tmdbProxy: _userPrefs.tmdbProxy,
    );
  }

  Future<void> _clear() async {
    await _userPrefs.setDoubanCookies('');
    DoubanService.instance.configure('', proxy: _userPrefs.doubanProxy);
    if (!mounted) return;
    setState(() {
      _valid = null;
      _message = null;
    });
    ToastUtil.show(context, '已清除豆瓣登录信息'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('豆瓣搜索'.tr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSwitchRow(colors),
          const SizedBox(height: 16),
          _buildStatusBanner(colors),
          const SizedBox(height: 20),
          _buildLoginButtons(colors),
          const SizedBox(height: 20),
          _buildSectionLabel(colors, 'HTTP 代理地址（选填）'.tr),
          const SizedBox(height: 8),
          _buildProxyInput(colors),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _saveProxy,
              child: Text('保存代理'.tr),
            ),
          ),
          if (_loggedIn) ...[
            const SizedBox(height: 8),
            _buildClearButton(colors),
          ],
          const SizedBox(height: 24),
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
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: SvgPicture.asset('assets/svg/douban_search.svg'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('豆瓣搜索'.tr,
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
        color: _loggedIn
            ? const Color(0xFF16A34A).withValues(alpha: 0.08)
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _loggedIn
              ? const Color(0xFF16A34A).withValues(alpha: 0.3)
              : colors.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _loggedIn ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: _loggedIn
                ? const Color(0xFF16A34A)
                : colors.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _loggedIn
                  ? '豆瓣已登录，支持书籍/影视分类翻页搜索'.tr
                  : '未登录仅能使用综合搜索（首屏结果），登录后可分类翻页'.tr,
              style: TextStyle(
                fontSize: 13,
                color: _loggedIn
                    ? const Color(0xFF16A34A)
                    : colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButtons(ColorScheme colors) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _login,
            icon: const Icon(Icons.login, size: 18),
            label: Text(_loggedIn ? '重新登录豆瓣'.tr : '登录豆瓣'.tr,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: _busy || !_loggedIn ? null : _test,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              side: BorderSide(color: colors.outlineVariant),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _busy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colors.onSurface.withValues(alpha: 0.4)))
                : Text('测试登录态'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
          ),
        ),
        if (_valid != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                Icon(_valid! ? Icons.check_circle : Icons.cancel,
                    size: 14,
                    color: _valid! ? const Color(0xFF16A34A) : colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_message ?? '',
                      style: TextStyle(
                          fontSize: 11,
                          color: _valid!
                              ? const Color(0xFF16A34A)
                              : colors.error)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSectionLabel(ColorScheme colors, String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colors.onSurface.withValues(alpha: 0.5)));
  }

  Widget _buildProxyInput(ColorScheme colors) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.vpn_lock_outlined,
              size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _proxyController,
              style: TextStyle(fontSize: 13, color: colors.onSurface),
              decoration: InputDecoration(
                hintText: '如 127.0.0.1:7890（仅支持 HTTP 代理）'.tr,
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
          border: Border.all(
              color: colors.error.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Center(
          child: Text('清除豆瓣登录信息'.tr,
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
          _tip(colors, '点击「登录豆瓣」在打开的页面中手动登录，登录成功后会自动返回'.tr),
          _tip(colors, '未登录可使用综合搜索；登录后支持书籍、影视分类搜索和深度翻页'.tr),
          _tip(colors, '登录凭证仅保存在本机，用于搜索公开条目信息'.tr),
          _tip(colors, '请避免高频搜索，登录态接口调用过于频繁可能触发豆瓣账号风控'.tr),
          _tip(colors, '代理仅对豆瓣搜索接口生效，封面图片仍走直连（不支持 SOCKS5）'.tr),
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
