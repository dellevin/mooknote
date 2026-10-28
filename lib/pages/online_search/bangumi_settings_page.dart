import 'package:flutter/material.dart';
import '../../services/bangumi_service.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';

/// Bangumi 搜索设置页面 —— 填写 Access Token，测试成功才保存
class BangumiSettingsPage extends StatefulWidget {
  const BangumiSettingsPage({super.key});

  @override
  State<BangumiSettingsPage> createState() => _BangumiSettingsPageState();
}

class _BangumiSettingsPageState extends State<BangumiSettingsPage> {
  final _userPrefs = UserPrefs();
  final _tokenController = TextEditingController();
  final _proxyController = TextEditingController();

  bool _saved = false; // 是否已有保存的 Token
  bool _testing = false;
  // null=未验证, true=有效, false=无效/网络不通
  bool? _valid;
  String? _message;

  @override
  void initState() {
    super.initState();
    final token = _userPrefs.bangumiAccessToken;
    _tokenController.text = token;
    _proxyController.text = _userPrefs.bangumiProxy;
    _saved = token.isNotEmpty;
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _proxyController.dispose();
    super.dispose();
  }

  /// 仅测试当前输入的 Token/代理，不保存
  Future<void> _test() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ToastUtil.show(context, '请输入 Access Token'.tr);
      return;
    }
    setState(() {
      _testing = true;
      _valid = null;
      _message = null;
    });

    final status = await BangumiService.testToken(token,
        proxy: _proxyController.text.trim());
    if (!mounted) return;

    switch (status) {
      case BangumiTestStatus.ok:
        setState(() {
          _valid = true;
          _message = '测试成功，可以保存'.tr;
        });
        break;
      case BangumiTestStatus.invalidToken:
        setState(() {
          _valid = false;
          _message = 'Token 无效'.tr;
        });
        break;
      case BangumiTestStatus.networkError:
        setState(() {
          _valid = false;
          _message = '网络不通，无法连接 Bangumi 服务器'.tr;
        });
        break;
    }
    setState(() => _testing = false);
  }

  /// 直接保存当前输入（Token 与代理），不强制要求测试
  Future<void> _save() async {
    final token = _tokenController.text.trim();
    final proxy = _proxyController.text.trim();
    if (token.isEmpty) {
      ToastUtil.show(context, '请输入 Access Token'.tr);
      return;
    }
    await _userPrefs.setBangumiAccessToken(token);
    await _userPrefs.setBangumiProxy(proxy);
    BangumiService.instance.configure(token, proxy: proxy);
    if (!mounted) return;
    setState(() {
      _saved = true;
      _valid = true;
      _message = '已保存'.tr;
    });
    ToastUtil.show(context, '保存成功'.tr);
  }

  Future<void> _clear() async {
    await _userPrefs.setBangumiAccessToken('');
    BangumiService.instance.configure('',
        proxy: _proxyController.text.trim());
    if (!mounted) return;
    setState(() {
      _saved = false;
      _valid = null;
      _message = null;
      _tokenController.clear();
    });
    if (mounted) ToastUtil.show(context, '已清除 Bangumi Token'.tr);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('Bangumi 搜索'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatusBanner(colors),
          const SizedBox(height: 20),
          _buildSectionLabel(colors, 'Bangumi Access Token'.tr),
          const SizedBox(height: 8),
          _buildTokenInput(colors),
          const SizedBox(height: 20),
          _buildSectionLabel(colors, 'HTTP 代理地址（选填）'.tr),
          const SizedBox(height: 8),
          _buildProxyInput(colors),
          const SizedBox(height: 28),
          _buildButtons(colors),
          if (_saved) ...[
            const SizedBox(height: 12),
            _buildClearButton(colors),
          ],
          const SizedBox(height: 20),
          _buildEditorToggle(colors),
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
              _saved ? 'Bangumi 搜索已开启'.tr : '填写 Access Token 并测试成功后开启'.tr,
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
                    hintText: '输入 Access Token'.tr,
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
                    _message ?? (_valid! ? 'Token 有效'.tr : '验证失败'.tr),
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

  Widget _buildButtons(ColorScheme colors) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _testing ? null : () => _test(),
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
                          color: colors.onSurface.withValues(alpha: 0.4)))
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
    );
  }

  /// 添加后自动打开编辑页开关（默认关，保持原有静默入库流）
  Widget _buildEditorToggle(ColorScheme colors) {
    final enabled = _userPrefs.bangumiOpenEditorAfterAdd;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('添加后打开编辑页'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text('点击想看/在看/看过后，直接弹出自动填好的编辑表单'.tr,
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.3),
            inactiveThumbColor: colors.surface,
            inactiveTrackColor: colors.outline,
            onChanged: (v) {
              setState(() {});
              _userPrefs.setBangumiOpenEditorAfterAdd(v);
            },
          ),
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
          _tip(colors, '在 bgm.tv 登录后，于 设置 → 开发者 → Access Token 页面创建令牌'.tr),
          _tip(colors, '支持搜索动画、书籍、游戏、三次元条目'.tr),
          _tip(colors, '需要设备能正常访问 Bangumi 服务器'.tr),
          _tip(colors, '无法直连时，可填写本地 HTTP 代理地址，仅对 Bangumi 接口生效（不支持 SOCKS5）'.tr),
          _tip(colors, 'Token 仅保存在本地，用于搜索条目信息'.tr),
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
