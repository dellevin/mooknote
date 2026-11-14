import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../services/cloud/cloud_auth_service.dart';
import '../../services/cloud/cloud_domain_sync_service.dart';
import '../../services/cloud/cloud_movie_sync_service.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_back_button.dart';
import 'cloud_profile_edit_page.dart';

/// 服务器云同步账号页：登录 / 注册
class CloudAccountPage extends StatefulWidget {
  const CloudAccountPage({super.key});

  @override
  State<CloudAccountPage> createState() => _CloudAccountPageState();
}

class _CloudAccountPageState extends State<CloudAccountPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  /// true=注册 false=登录
  bool _isRegister = false;
  bool _loading = false;
  /// 正在处理的卡片 key（影视='movie'，其余为 domain）；null=空闲。
  /// 任一卡片处理期间禁用全部入口，但只有该卡片显示转圈。
  String? _syncingKey;
  bool get _syncing => _syncingKey != null;
  bool _obscure = true;
  String _captchaUuid = const Uuid().v4();
  // 图片地址按 uuid 固定，仅手动刷新时变更，避免重建导致验证码被静默替换
  late String _captchaUrl = CloudAuthService.instance.captchaUrl(_captchaUuid);

  @override
  void initState() {
    super.initState();
    // 已登录时主动校验，覆盖运行中被后台强制下线/停用的场景（页面本身只读本地缓存）
    if (CloudAuthService.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verifyLogin());
    }
  }

  Future<void> _verifyLogin() async {
    final valid = await CloudAuthService.instance.checkLoginStatus();
    // 失效时 service 内部已清登录态并弹全局提示，这里重建切回登录表单
    if (!valid && mounted) setState(() {});
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  void _refreshCaptcha() {
    setState(() {
      _captchaUuid = const Uuid().v4();
      _captchaUrl = CloudAuthService.instance.captchaUrl(_captchaUuid);
      _captchaCtrl.clear();
    });
  }

  Future<void> _submit() async {
    // 登录支持用户名/手机号/邮箱，兼容全角＠误输入
    final username = _usernameCtrl.text.trim().replaceAll('＠', '@');
    final password = _passwordCtrl.text;
    final captcha = _captchaCtrl.text.trim();

    if (username.isEmpty || password.isEmpty || captcha.isEmpty) {
      _toast('请填写完整信息'.tr);
      return;
    }
    if (_isRegister && !RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(username)) {
      _toast('用户名为4-20位字母、数字或下划线'.tr);
      return;
    }
    if (password.length < 6 || password.length > 20) {
      _toast('密码长度为6-20位'.tr);
      return;
    }
    if (_isRegister && _confirmCtrl.text != password) {
      _toast('两次输入的密码不一致'.tr);
      return;
    }
    final mobile = _mobileCtrl.text.trim();
    // 兼容中文输入法误输入的全角＠，统一转半角再校验
    final email = _emailCtrl.text.trim().replaceAll('＠', '@');
    if (_isRegister) {
      if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(mobile)) {
        _toast('请输入正确的手机号'.tr);
        return;
      }
      if (!RegExp(r'^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$').hasMatch(email)) {
        _toast('请输入正确的邮箱'.tr);
        return;
      }
    }

    setState(() => _loading = true);
    final service = CloudAuthService.instance;
    final result = _isRegister
        ? await service.register(
            username: username,
            password: password,
            captcha: captcha,
            uuid: _captchaUuid,
            mobile: mobile,
            email: email,
          )
        : await service.login(
            username: username,
            password: password,
            captcha: captcha,
            uuid: _captchaUuid,
          );
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      _toast(_isRegister ? '注册成功'.tr : '登录成功'.tr);
      // 留在本页，由 build 根据登录态切换为已登录视图
      setState(() {});
    } else {
      _toast(result.message.isEmpty ? '操作失败，请稍后再试'.tr : result.message);
      _refreshCaptcha();
    }
  }

  /// 影视云端模式入口：先查云端状态，再给出迁移/切换选项
  Future<void> _openMovieCloudSheet() async {
    if (_syncing) return;
    setState(() => _syncingKey = 'movie');
    final status = await CloudMovieSyncService.instance.fetchCloudStatus();
    if (!mounted) return;
    setState(() => _syncingKey = null);
    if (status == null) {
      _toast('网络连接失败，请稍后再试'.tr);
      return;
    }
    final cloudEmpty = (status['movies'] ?? 0) == 0;
    final cloudMode = CloudMovieSyncService.instance.isCloudMode;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: false,
      builder: (_) => _MovieCloudSheet(
        cloudEmpty: cloudEmpty,
        cloudMode: cloudMode,
        cloudMovieCount: status['movies'] ?? 0,
        onUpload: () => _migrateLocalToCloud(cloudEmpty),
        onUseCloud: _switchToCloud,
        onSwitchLocal: _switchToLocal,
      ),
    );
  }

  /// 本地 → 云端：云端非空时二次确认清除，整库替换上传，成功后进入云端模式
  Future<void> _migrateLocalToCloud(bool cloudEmpty) async {
    if (!cloudEmpty) {
      final confirmed = await _confirmDialog(
        title: '覆盖云端数据'.tr,
        content: '云端已有影视数据，上传将清空云端现有数据并以本机数据覆盖，确定继续？'.tr,
        danger: true,
      );
      if (confirmed != true) return;
    }
    setState(() => _syncingKey = 'movie');
    final notifier = ValueNotifier<_CloudProgress>(_CloudProgress('准备中…'.tr));
    _showProgressDialog(notifier);
    final result = await CloudMovieSyncService.instance.uploadLocalToCloud(
      onProgress: (stage, done, total) =>
          notifier.value = _CloudProgress(stage, done: done, total: total),
    );
    if (mounted) Navigator.of(context).pop();
    notifier.dispose();
    if (!mounted) return;
    setState(() => _syncingKey = null);
    if (!result.success) {
      _toast(result.message);
      return;
    }
    await UserPrefs().setCloudMovieMode(true);
    if (!mounted) return;
    setState(() {});
    _toast('已上传 {n} 条记录，当前为云端浏览模式'.trf({'n': result.count}));
  }

  /// 直接使用云端数据：仅切换数据来源，不下载、不清空本机数据；
  /// 纯实时模式下所有增删改查直连云端，切回本地模式本机数据原样可见
  Future<void> _switchToCloud() async {
    await UserPrefs().setCloudMovieMode(true);
    if (!mounted) return;
    // 立即拉取云端首页填充内存，驱动列表页刷新与毛玻璃封面
    await context.read<AppProvider>().loadMovies();
    if (!mounted) return;
    setState(() {});
    _toast('已切换为云端浏览模式'.tr);
  }

  /// 仅切回本地浏览模式，不移动任何数据
  Future<void> _switchToLocal() async {
    await UserPrefs().setCloudMovieMode(false);
    if (!mounted) return;
    // 重新加载本机数据，让列表立即恢复本地内容
    await context.read<AppProvider>().loadMovies();
    if (!mounted) return;
    setState(() {});
    _toast('已切换为本地浏览模式'.tr);
  }

  /// 书籍/游戏/笔记云端模式入口：查域内云端状态，再给出迁移/切换选项
  Future<void> _openDomainCloudSheet(_DomainCloud d) async {
    if (_syncing) return;
    setState(() => _syncingKey = d.domain);
    final status = await CloudDomainSyncService.instance.fetchCloudStatus(d.domain);
    if (!mounted) return;
    setState(() => _syncingKey = null);
    if (status == null) {
      _toast('网络连接失败，请稍后再试'.tr);
      return;
    }
    final cloudEmpty = (status[d.mainTable] ?? 0) == 0;
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      showDragHandle: false,
      builder: (_) => _DomainCloudSheet(
        d: d,
        cloudEmpty: cloudEmpty,
        cloudMode: d.isCloudMode(),
        cloudCount: status[d.mainTable] ?? 0,
        onUpload: () => _migrateDomainToCloud(d, cloudEmpty),
        onUseCloud: () => _switchDomainMode(d, true),
        onSwitchLocal: () => _switchDomainMode(d, false),
      ),
    );
  }

  /// 书籍/游戏/笔记：本地 → 云端整库替换上传，成功后进入该域云端模式
  Future<void> _migrateDomainToCloud(_DomainCloud d, bool cloudEmpty) async {
    if (!cloudEmpty) {
      final confirmed = await _confirmDialog(
        title: '覆盖云端数据'.tr,
        content: d.overwriteConfirmText.tr,
        danger: true,
      );
      if (confirmed != true) return;
    }
    setState(() => _syncingKey = d.domain);
    final notifier = ValueNotifier<_CloudProgress>(_CloudProgress('准备中…'.tr));
    _showProgressDialog(notifier);
    final result = await CloudDomainSyncService.instance.uploadLocalToCloud(
      d.domain,
      onProgress: (stage, done, total) =>
          notifier.value = _CloudProgress(stage, done: done, total: total),
    );
    if (mounted) Navigator.of(context).pop();
    notifier.dispose();
    if (!mounted) return;
    setState(() => _syncingKey = null);
    if (!result.success) {
      _toast(result.message);
      return;
    }
    await d.setCloudMode(true);
    if (!mounted) return;
    await d.reload(context.read<AppProvider>());
    if (!mounted) return;
    setState(() {});
    _toast('已上传 {n} 条记录，当前为云端浏览模式'.trf({'n': result.count}));
  }

  /// 仅切换数据来源，不下载、不清空本机数据
  Future<void> _switchDomainMode(_DomainCloud d, bool cloud) async {
    await d.setCloudMode(cloud);
    if (!mounted) return;
    await d.reload(context.read<AppProvider>());
    if (!mounted) return;
    setState(() {});
    _toast(cloud ? '已切换为云端浏览模式'.tr : '已切换为本地浏览模式'.tr);
  }

  /// 不可取消的进度对话框：fraction 为 null 时走不确定进度条
  void _showProgressDialog(ValueNotifier<_CloudProgress> notifier) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          content: ValueListenableBuilder<_CloudProgress>(
            valueListenable: notifier,
            builder: (_, p, __) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.stage,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: p.fraction,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                if (p.done != null && p.total != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${p.done}/${p.total}',
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5))),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String content,
    bool danger = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        content: Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定'.tr,
                style: danger ? TextStyle(color: colors.error) : null),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) => ToastUtil.show(context, msg);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loggedIn = CloudAuthService.instance.isLoggedIn;

    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('服务器云同步'.tr),
        actions: [
          if (loggedIn)
            TextButton(
              onPressed: () async {
                await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudProfileEditPage()),
                );
                if (mounted) setState(() {});
              },
              child: Text('编辑信息'.tr),
            )
          else
            TextButton(
              onPressed: () => setState(() => _isRegister = !_isRegister),
              child: Text(_isRegister ? '登录'.tr : '注册'.tr),
            ),
        ],
      ),
      body: loggedIn ? _buildLoggedIn(colors) : _buildForm(colors),
    );
  }

  Widget _buildLoggedIn(ColorScheme colors) {
    final prefs = UserPrefs();
    final nickname = prefs.cloudNickname.isEmpty ? prefs.cloudUsername : prefs.cloudNickname;
    return RefreshIndicator(
      onRefresh: () async {
        // 拉取最新用户信息并回写本地；失效时 service 内部已清登录态并弹提示
        await CloudAuthService.instance.checkLoginStatus();
        if (mounted) setState(() {});
      },
      child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        // 顶部头像 + 昵称 + 登录状态
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: prefs.cloudAvatar.isEmpty
                  ? Container(
                      color: colors.primaryContainer,
                      child: Icon(Icons.person, size: 40, color: colors.onPrimaryContainer))
                  : Image.network(prefs.cloudAvatar, fit: BoxFit.cover, gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Container(
                          color: colors.primaryContainer,
                          child: Icon(Icons.person, size: 40, color: colors.onPrimaryContainer))),
            ),
            const SizedBox(height: 14),
            Text(nickname,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            if (prefs.cloudMotto.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(prefs.cloudMotto,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.55))),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 14, color: colors.primary),
                const SizedBox(width: 4),
                Text('已登录至云服务器'.tr,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // 账号信息
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            _infoRow(colors, Icons.alternate_email, '用户名'.tr, prefs.cloudUsername),
            Divider(height: 1, indent: 52, color: colors.outlineVariant.withValues(alpha: 0.5)),
            _infoRow(colors, Icons.smartphone_outlined, '手机号'.tr, prefs.cloudMobile),
            Divider(height: 1, indent: 52, color: colors.outlineVariant.withValues(alpha: 0.5)),
            _infoRow(colors, Icons.email_outlined, '邮箱'.tr, prefs.cloudEmail),
          ]),
        ),
        const SizedBox(height: 20),
        _buildCloudDataSection(colors),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  await CloudAuthService.instance.logout();
                  if (mounted) setState(() => _loading = false);
                },
          style: FilledButton.styleFrom(
            backgroundColor: colors.errorContainer,
            foregroundColor: colors.onErrorContainer,
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text('退出登录'.tr),
        ),
      ],
      ),
    );
  }

  /// 四类数据云同步入口
  Widget _buildCloudDataSection(ColorScheme colors) {
    final movieCloud = CloudMovieSyncService.instance.isCloudMode;
    final items = <_CloudCategory>[
      _CloudCategory('movie', '影视'.tr, Icons.movie_outlined, true, _openMovieCloudSheet,
          badge: movieCloud ? '云端模式'.tr : null),
      for (final d in _DomainCloud.all)
        _CloudCategory(d.domain, d.name.tr, d.icon, true, () => _openDomainCloudSheet(d),
            badge: d.isCloudMode() ? '云端模式'.tr : null),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('云数据'.tr,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                  color: colors.onSurface.withValues(alpha: 0.6))),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: items.map((item) => _categoryCard(colors, item)).toList(),
        ),
      ],
    );
  }

  Widget _categoryCard(ColorScheme colors, _CloudCategory item) {
    final isActive = _syncingKey == item.key;
    final enabled = item.enabled && !_syncing;
    final subtitle = !item.enabled
        ? '敬请期待'.tr
        : isActive
            ? '处理中…'.tr
            : (item.badge ?? '点击管理云端数据'.tr);
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? item.onTap : null,
        child: Opacity(
          opacity: item.enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(item.icon, size: 26,
                  color: item.enabled ? colors.primary : colors.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: item.badge != null
                                ? colors.primary
                                : colors.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              if (item.enabled && isActive)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.primary),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(ColorScheme colors, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.55)),
        const SizedBox(width: 16),
        Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
        const Spacer(),
        Flexible(
          child: Text(value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _buildForm(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _label(colors, (_isRegister ? '用户名' : '用户名/手机号/邮箱').tr, required: true),
        _inputField(
          controller: _usernameCtrl,
          hint: (_isRegister ? '4-20位字母、数字或下划线' : '可使用用户名、手机号或邮箱登录').tr,
          icon: Icons.person_outline,
        ),
        if (_isRegister) ...[
          const SizedBox(height: 12),
          _label(colors, '手机号'.tr, required: true),
          _inputField(
            controller: _mobileCtrl,
            hint: '请输入手机号'.tr,
            icon: Icons.smartphone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _label(colors, '邮箱'.tr, required: true),
          _inputField(
            controller: _emailCtrl,
            hint: '请输入邮箱'.tr,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
        ],
        const SizedBox(height: 12),
        _label(colors, '密码'.tr, required: true),
        _inputField(
          controller: _passwordCtrl,
          hint: '6-20位密码'.tr,
          icon: Icons.lock_outline,
          obscure: _obscure,
          suffix: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        if (_isRegister) ...[
          const SizedBox(height: 12),
          _label(colors, '确认密码'.tr, required: true),
          _inputField(
            controller: _confirmCtrl,
            hint: '请再次输入密码'.tr,
            icon: Icons.lock_outline,
            obscure: true,
          ),
        ],
        const SizedBox(height: 12),
        _label(colors, '图形验证码'.tr, required: true),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: _inputField(
              controller: _captchaCtrl,
              hint: '请输入验证码'.tr,
              icon: Icons.verified_user_outlined,
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _refreshCaptcha,
            child: Container(
              width: 130,
              height: 48,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outlineVariant),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                _captchaUrl,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => Icon(Icons.refresh,
                    size: 20, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isRegister ? '注册并登录'.tr : '登录'.tr),
        ),
      ],
    );
  }

  Widget _label(ColorScheme colors, String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(children: [
          if (required)
            TextSpan(text: '* ', style: TextStyle(fontSize: 13, color: colors.error)),
          TextSpan(text: text),
        ]),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputAction? textInputAction,
    TextInputType? keyboardType,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 14, color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)),
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.surface,
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

/// 云端迁移进度（fraction 为 null 表示不确定进度）
class _CloudProgress {
  final String stage;
  final int? done;
  final int? total;

  const _CloudProgress(this.stage, {this.done, this.total});

  double? get fraction =>
      (done != null && total != null && total! > 0) ? done! / total! : null;
}

/// 云数据分类入口（影视/书籍/游戏/笔记）
class _CloudCategory {
  /// 与 _syncingKey 对应：影视='movie'，其余为 domain
  final String key;
  final String name;
  final IconData icon;
  final bool enabled;
  final Future<void> Function()? onTap;
  final String? badge;

  const _CloudCategory(this.key, this.name, this.icon, this.enabled, this.onTap, {this.badge});
}

/// 书籍/游戏/笔记三个云端域的静态描述（影视由独立的 CloudMovieSyncService 处理）
class _DomainCloud {
  /// 服务端 domain / push 协议字段
  final String domain;

  /// 状态查询结果里主表的 key
  final String mainTable;
  final String name;
  final IconData icon;
  final String sheetTitle;
  final String cloudEmptyText;
  final String cloudCountText;
  final String overwriteConfirmText;

  const _DomainCloud({
    required this.domain,
    required this.mainTable,
    required this.name,
    required this.icon,
    required this.sheetTitle,
    required this.cloudEmptyText,
    required this.cloudCountText,
    required this.overwriteConfirmText,
  });

  bool isCloudMode() => switch (domain) {
        'books' => UserPrefs().cloudBookMode,
        'games' => UserPrefs().cloudGameMode,
        _ => UserPrefs().cloudNoteMode,
      };

  Future<void> setCloudMode(bool value) => switch (domain) {
        'books' => UserPrefs().setCloudBookMode(value),
        'games' => UserPrefs().setCloudGameMode(value),
        _ => UserPrefs().setCloudNoteMode(value),
      };

  Future<void> reload(AppProvider provider) => switch (domain) {
        'books' => provider.loadBooks(),
        'games' => provider.loadGames(),
        _ => provider.loadNotes(),
      };

  static const all = <_DomainCloud>[
    _DomainCloud(
      domain: 'books',
      mainTable: 'books',
      name: '书籍',
      icon: Icons.menu_book_outlined,
      sheetTitle: '书籍云端数据',
      cloudEmptyText: '云端暂无书籍数据',
      cloudCountText: '云端已有 {n} 本书籍',
      overwriteConfirmText: '云端已有书籍数据，上传将清空云端现有数据并以本机数据覆盖，确定继续？',
    ),
    _DomainCloud(
      domain: 'games',
      mainTable: 'games',
      name: '游戏',
      icon: Icons.sports_esports_outlined,
      sheetTitle: '游戏云端数据',
      cloudEmptyText: '云端暂无游戏数据',
      cloudCountText: '云端已有 {n} 款游戏',
      overwriteConfirmText: '云端已有游戏数据，上传将清空云端现有数据并以本机数据覆盖，确定继续？',
    ),
    _DomainCloud(
      domain: 'notes',
      mainTable: 'notes',
      name: '笔记',
      icon: Icons.sticky_note_2_outlined,
      sheetTitle: '笔记云端数据',
      cloudEmptyText: '云端暂无笔记数据',
      cloudCountText: '云端已有 {n} 条笔记',
      overwriteConfirmText: '云端已有笔记数据，上传将清空云端现有数据并以本机数据覆盖，确定继续？',
    ),
  ];
}

/// 书籍/游戏/笔记云端数据管理底部弹窗（与影视弹窗同构，文案按域区分）
class _DomainCloudSheet extends StatelessWidget {
  final _DomainCloud d;
  final bool cloudEmpty;
  final bool cloudMode;
  final int cloudCount;
  final Future<void> Function() onUpload;
  final Future<void> Function() onUseCloud;
  final Future<void> Function() onSwitchLocal;

  const _DomainCloudSheet({
    required this.d,
    required this.cloudEmpty,
    required this.cloudMode,
    required this.cloudCount,
    required this.onUpload,
    required this.onUseCloud,
    required this.onSwitchLocal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(d.sheetTitle.tr,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 6),
            Text(
              cloudEmpty
                  ? d.cloudEmptyText.tr
                  : d.cloudCountText.trf({'n': cloudCount}),
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 18),
            _sheetAction(
              colors,
              icon: Icons.cloud_upload_outlined,
              title: '本机数据上传至云端'.tr,
              subtitle: cloudEmpty
                  ? '云端为空，直接上传并进入云端浏览模式'.tr
                  : '清空云端现有数据，以本机数据整库覆盖'.tr,
              danger: !cloudEmpty,
              onTap: () {
                Navigator.pop(context);
                onUpload();
              },
            ),
            const SizedBox(height: 10),
            _sheetAction(
              colors,
              icon: Icons.cloud_outlined,
              title: '直接使用云端数据'.tr,
              subtitle: '不动本机数据，所有增删改查实时走云端'.tr,
              disabled: cloudEmpty || cloudMode,
              onTap: () {
                Navigator.pop(context);
                onUseCloud();
              },
            ),
            if (cloudMode) ...[
              const SizedBox(height: 10),
              _sheetAction(
                colors,
                icon: Icons.smartphone_outlined,
                title: '切回本地浏览模式'.tr,
                subtitle: '不移动数据，仅切换数据来源'.tr,
                onTap: () {
                  Navigator.pop(context);
                  onSwitchLocal();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetAction(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, size: 24, color: danger ? colors.error : colors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: danger ? colors.error : colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 影视云端数据管理底部弹窗
class _MovieCloudSheet extends StatelessWidget {
  final bool cloudEmpty;
  final bool cloudMode;
  final int cloudMovieCount;
  final Future<void> Function() onUpload;
  final Future<void> Function() onUseCloud;
  final Future<void> Function() onSwitchLocal;

  const _MovieCloudSheet({
    required this.cloudEmpty,
    required this.cloudMode,
    required this.cloudMovieCount,
    required this.onUpload,
    required this.onUseCloud,
    required this.onSwitchLocal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('影视云端数据'.tr,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 6),
            Text(
              cloudEmpty
                  ? '云端暂无影视数据'.tr
                  : '云端已有 {n} 部影视'.trf({'n': cloudMovieCount}),
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.55)),
            ),
            const SizedBox(height: 18),
            _sheetAction(
              colors,
              icon: Icons.cloud_upload_outlined,
              title: '本机数据上传至云端'.tr,
              subtitle: cloudEmpty
                  ? '云端为空，直接上传并进入云端浏览模式'.tr
                  : '清空云端现有数据，以本机数据整库覆盖'.tr,
              danger: !cloudEmpty,
              onTap: () {
                Navigator.pop(context);
                onUpload();
              },
            ),
            const SizedBox(height: 10),
            _sheetAction(
              colors,
              icon: Icons.cloud_outlined,
              title: '直接使用云端数据'.tr,
              subtitle: '不动本机数据，所有增删改查实时走云端'.tr,
              disabled: cloudEmpty || cloudMode,
              onTap: () {
                Navigator.pop(context);
                onUseCloud();
              },
            ),
            if (cloudMode) ...[
              const SizedBox(height: 10),
              _sheetAction(
                colors,
                icon: Icons.smartphone_outlined,
                title: '切回本地浏览模式'.tr,
                subtitle: '不移动数据，仅切换数据来源'.tr,
                onTap: () {
                  Navigator.pop(context);
                  onSwitchLocal();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sheetAction(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, size: 24, color: danger ? colors.error : colors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: danger ? colors.error : colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
