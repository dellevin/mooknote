import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/toast_util.dart';
import '../../utils/sync/webdav_service.dart';
import '../../providers/app_provider.dart';

/// WebDAV 备份页面
class WebDAVSyncPage extends StatefulWidget {
  const WebDAVSyncPage({super.key});

  @override
  State<WebDAVSyncPage> createState() => _WebDAVSyncPageState();
}

class _WebDAVSyncPageState extends State<WebDAVSyncPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController(text: '/mooknote');

  bool _isLoading = false;
  bool _isConfigured = false;
  bool _obscurePassword = true;
  bool _isAutoSyncEnabled = false;
  int _autoSyncInterval = 5;
  SyncDirection _syncDirection = SyncDirection.upload;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await WebDAVService.instance.getConfig();
    if (config != null) {
      setState(() {
        _urlController.text = config['url'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
        _pathController.text = config['path'] ?? '/mooknote';
        _isConfigured = true;
      });
    }

    final autoSyncEnabled = await WebDAVService.instance.isAutoSyncEnabled();
    final autoSyncInterval = await WebDAVService.instance.getAutoSyncInterval();
    setState(() {
      _isAutoSyncEnabled = autoSyncEnabled;
      _autoSyncInterval = autoSyncInterval;
    });
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final path = _pathController.text.trim();

    if (url.isEmpty) { ToastUtil.show(context, '请输入服务器地址'); return; }
    if (username.isEmpty) { ToastUtil.show(context, '请输入用户名'); return; }
    if (password.isEmpty) { ToastUtil.show(context, '请输入密码'); return; }

    setState(() => _isLoading = true);

    try {
      final result = await WebDAVService.instance.testConnection(
        url: url, username: username, password: password, path: path,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await WebDAVService.instance.saveConfig(
          url: url, username: username, password: password, path: path,
        );
        setState(() => _isConfigured = true);
        ToastUtil.show(context, result['message'] ?? '连接成功，配置已保存');
      } else {
        ToastUtil.show(context, result['message'] ?? '连接失败，请检查配置');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '连接失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isLoading = true);

    try {
      final result = await WebDAVService.instance.syncData(direction: _syncDirection);
      if (!mounted) return;

      if (result.success) {
        final details = '上传: ${result.uploadedFiles} 文件, ${result.uploadedImages} 图片\n'
                       '下载: ${result.downloadedFiles} 文件, ${result.downloadedImages} 图片';

        if (result.needReload) {
          ToastUtil.show(context, '数据已更新，正在重新加载...');
          final provider = context.read<AppProvider>();
          await provider.loadMovies();
          await provider.loadBooks();
          await provider.loadNotes();
          if (mounted) _showResultDialog('同步成功', details);
        } else {
          _showResultDialog('同步成功', details);
        }
      } else {
        ToastUtil.show(context, result.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '同步失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check, color: Color(0xFF1A1A1A), size: 24),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(content, style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6), textAlign: TextAlign.center),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(minimumSize: const Size(120, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('确定', style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAutoSync(bool value) async {
    setState(() => _isLoading = true);
    try {
      if (value) {
        await WebDAVService.instance.startAutoSync();
        if (mounted) ToastUtil.show(context, '自动同步已开启，每 $_autoSyncInterval 分钟同步一次');
      } else {
        await WebDAVService.instance.stopAutoSync();
        if (mounted) ToastUtil.show(context, '自动同步已关闭');
      }
      setState(() => _isAutoSyncEnabled = value);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '设置失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showIntervalPicker() async {
    final intervals = [1, 3, 5, 10, 15, 30, 60];
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('同步间隔', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 8),
            ...intervals.map((i) => ListTile(
              title: Text('$i 分钟', style: TextStyle(fontSize: 15, fontWeight: _autoSyncInterval == i ? FontWeight.w600 : FontWeight.w400, color: const Color(0xFF1A1A1A))),
              trailing: _autoSyncInterval == i ? const Icon(Icons.check, color: Color(0xFF1A1A1A), size: 20) : null,
              onTap: () => Navigator.pop(ctx, i),
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null && selected != _autoSyncInterval) {
      setState(() => _isLoading = true);
      try {
        await WebDAVService.instance.setAutoSyncInterval(selected);
        setState(() => _autoSyncInterval = selected);
        if (mounted) ToastUtil.show(context, '同步间隔已设置为 $selected 分钟');
      } catch (e) {
        if (mounted) ToastUtil.show(context, '设置失败: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('清除配置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('确定要清除 WebDAV 配置吗？', style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('清除', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await WebDAVService.instance.clearConfig();
      setState(() {
        _urlController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _pathController.text = '/mooknote';
        _isConfigured = false;
        _isAutoSyncEnabled = false;
      });
      if (mounted) ToastUtil.show(context, '配置已清除');
    }
  }

  // ── UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('WebDAV 备份')),
      body: _isLoading && !_isConfigured
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const SizedBox(height: 8),

                // 已连接提示
                if (_isConfigured) _buildConnectedBanner(),

                // 服务器配置
                _buildSectionLabel('服务器配置'),
                const SizedBox(height: 16),
                _buildInput(
                  controller: _urlController,
                  hint: '服务器地址，如 https://dav.example.com',
                  icon: Icons.link,
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _usernameController,
                  hint: '用户名',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _passwordController,
                  hint: '密码',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFFBBBBBB)),
                  ),
                ),
                const SizedBox(height: 12),
                _buildInput(
                  controller: _pathController,
                  hint: '同步路径，如 /mooknote',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 24),

                // 测试并保存
                _buildBtn('测试并保存', onTap: _isLoading ? null : _saveConfig),
                const SizedBox(height: 40),

                if (_isConfigured) ...[
                  // 自动同步
                  _buildSectionLabel('自动同步'),
                  const SizedBox(height: 12),
                  _buildSwitchRow(
                    icon: Icons.sync,
                    label: '自动同步',
                    sub: _isAutoSyncEnabled ? '每 $_autoSyncInterval 分钟自动同步' : '关闭',
                    value: _isAutoSyncEnabled,
                    onChanged: _isLoading ? null : _toggleAutoSync,
                  ),
                  if (_isAutoSyncEnabled) ...[
                    const SizedBox(height: 4),
                    _buildTappableRow(
                      label: '同步间隔',
                      value: '$_autoSyncInterval 分钟',
                      onTap: _isLoading ? null : _showIntervalPicker,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 手动同步
                  _buildSectionLabel('手动同步'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDirectionChip('上传到云端', SyncDirection.upload, Icons.upload)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDirectionChip('下载到本地', SyncDirection.download, Icons.download)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildBtn('立即同步', onTap: _isLoading ? null : _syncData, loading: _isLoading),

                  const SizedBox(height: 32),

                  // 清除配置
                  _buildTextBtn('清除配置', onTap: _isLoading ? null : _clearConfig),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 32),
                _buildTips(),
                const SizedBox(height: 60),
              ],
            ),
    );
  }

  // ── widgets ─────────────────────────────────────────

  Widget _buildConnectedBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _urlController.text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Text('已连接', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF999999), letterSpacing: 0.5));
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 15, color: Color(0xFFBBBBBB)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Icon(icon, size: 20, color: const Color(0xFFBBBBBB)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffix != null ? Padding(
          padding: const EdgeInsets.only(right: 8),
          child: suffix,
        ) : null,
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      ),
    );
  }

  Widget _buildBtn(String text, {VoidCallback? onTap, bool loading = false}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFDDDDDD) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildTextBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(text, style: TextStyle(fontSize: 14, color: onTap == null ? const Color(0xFFCCCCCC) : const Color(0xFF999999)))),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? const Color(0xFF1A1A1A) : const Color(0xFFBBBBBB)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value ? sub : label,
              style: TextStyle(fontSize: 14, color: value ? const Color(0xFF666666) : const Color(0xFF1A1A1A)),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF1A1A1A),
            activeTrackColor: const Color(0xFF1A1A1A).withOpacity(0.3),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFDDDDDD),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableRow({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 32),
            Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFCCCCCC)),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionChip(String label, SyncDirection dir, IconData icon) {
    final selected = _syncDirection == dir;
    return GestureDetector(
      onTap: () => setState(() => _syncDirection = dir),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : const Color(0xFF999999)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : const Color(0xFF666666))),
          ],
        ),
      ),
    );
  }

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('支持的服务', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF999999), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _tip('坚果云、Nextcloud、AList 等 WebDAV 服务'),
          _tip('服务器地址需包含 https://'),
          _tip('首次同步可能需要较长时间'),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Icon(Icons.circle, size: 4, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF888888), height: 1.5))),
        ],
      ),
    );
  }
}
