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
  SyncDirection _syncDirection = SyncDirection.upload;

  // 远程备份信息
  DateTime? _remoteModifiedTime;
  int? _remoteFileSize;
  bool _isLoadingRemoteInfo = false;

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
      _loadRemoteInfo();
    }

    final autoSyncEnabled = await WebDAVService.instance.isAutoSyncEnabled();
    final autoSyncInterval = await WebDAVService.instance.getAutoSyncInterval();
    debugPrint('WebDAV auto sync: enabled=$autoSyncEnabled, interval=$autoSyncInterval');
  }

  Future<void> _loadRemoteInfo() async {
    setState(() => _isLoadingRemoteInfo = true);
    final info = await WebDAVService.instance.getRemoteBackupInfo();
    if (mounted) {
      setState(() {
        _remoteModifiedTime = info?['modifiedTime'] as DateTime?;
        _remoteFileSize = info?['size'] as int?;
        _isLoadingRemoteInfo = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final path = _pathController.text.trim();

    if (url.isEmpty) {
      ToastUtil.show(context, '请输入服务器地址');
      return;
    }
    if (username.isEmpty) {
      ToastUtil.show(context, '请输入用户名');
      return;
    }
    if (password.isEmpty) {
      ToastUtil.show(context, '请输入密码');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await WebDAVService.instance.testConnection(
        url: url,
        username: username,
        password: password,
        path: path,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        await WebDAVService.instance.saveConfig(
          url: url,
          username: username,
          password: password,
          path: path,
        );
        setState(() => _isConfigured = true);
        // 保存成功后立即加载远程备份信息
        _loadRemoteInfo();
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
        // 同步成功后刷新远程文件信息
        _loadRemoteInfo();
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
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check, color: colors.primary, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(content,
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6),
                textAlign: TextAlign.center),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  minimumSize: const Size(120, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('确定', style: TextStyle(fontSize: 14, color: colors.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUploadConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认上传',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('该操作会覆盖掉远程数据，请谨慎操作，点击确定继续上传',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() => _syncDirection = SyncDirection.upload);
      _syncData();
    }
  }

  Future<void> _showDownloadConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认下载',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('该操作会拉取远程数据覆盖掉本地数据，请谨慎操作，点击确定将数据拉取到本地',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() => _syncDirection = SyncDirection.download);
      _syncData();
    }
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Text('清除配置',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('确定要清除 WebDAV 配置吗？',
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('取消', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('清除', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await WebDAVService.instance.clearConfig();
      setState(() {
        _urlController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _pathController.text = '/mooknote';
        _isConfigured = false;
      });
      if (mounted) ToastUtil.show(context, '配置已清除');
    }
  }

  // ── UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('WebDAV 备份')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 4),

              // 已连接提示
              if (_isConfigured) _buildConnectedBanner(colors),

              // 服务器配置
              _buildSectionLabel(colors, '服务器配置'),
                const SizedBox(height: 12),
                _buildInput(
                  colors: colors,
                  controller: _urlController,
                  hint: '服务器地址，如 https://dav.example.com',
                  icon: Icons.link,
                ),
                const SizedBox(height: 8),
                _buildInput(
                  colors: colors,
                  controller: _usernameController,
                  hint: '用户名',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 8),
                _buildInput(
                  colors: colors,
                  controller: _passwordController,
                  hint: '密码',
                  icon: Icons.lock_outline,
                  obscure: _obscurePassword,
                  suffix: GestureDetector(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(height: 8),
                _buildInput(
                  colors: colors,
                  controller: _pathController,
                  hint: '同步路径，如 /mooknote',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 16),

                // 测试并保存
                _buildBtn(colors, '测试并保存', onTap: _isLoading ? null : _saveConfig),
                if (_isConfigured) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading ? null : _clearConfig,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('清除配置',
                            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),

                if (_isConfigured) ...[
                  // 远程备份信息卡片（包含操作按钮）
                  _buildRemoteInfoCard(colors),
                  const SizedBox(height: 24),
                ],

              const SizedBox(height: 24),
              _buildTips(colors),
              const SizedBox(height: 40),
            ],
          ),
          if (_isLoading)
            Container(
              color: colors.surface.withValues(alpha: 0.7),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
            ),
        ],
      ),
    );
  }

  // ── widgets ─────────────────────────────────────────

  Widget _buildConnectedBanner(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _urlController.text,
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('已连接',
              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ColorScheme colors, String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.4),
            letterSpacing: 0.5));
  }

  Widget _buildInput({
    required ColorScheme colors,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(fontSize: 15, color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.3)),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 8),
          child: Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: suffix,
              )
            : null,
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildBtn(ColorScheme colors, String text, {VoidCallback? onTap, bool loading = false}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? colors.onSurface.withValues(alpha: 0.15) : colors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, valueColor: AlwaysStoppedAnimation(colors.onPrimary)))
              : Text(text,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: colors.onPrimary)),
        ),
      ),
    );
  }

  Widget _buildRemoteInfoCard(ColorScheme colors) {
    String timeText;
    String sizeText = '';

    if (_isLoadingRemoteInfo) {
      timeText = '加载中...';
    } else if (_remoteModifiedTime != null) {
      final dt = _remoteModifiedTime!;
      timeText = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (_remoteFileSize != null) {
        sizeText = _formatFileSize(_remoteFileSize!);
      }
    } else {
      timeText = '暂无备份文件';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text('云端备份', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const Spacer(),
              if (_isLoadingRemoteInfo)
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
              else
                GestureDetector(
                  onTap: _loadRemoteInfo,
                  child: Icon(Icons.refresh, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('上传时间', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(height: 4),
                    Text(timeText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  ],
                ),
              ),
              if (sizeText.isNotEmpty)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('文件大小', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      Text(sizeText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBtn(colors, '上传', onTap: _isLoading ? null : () => _showUploadConfirm(), loading: _isLoading),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBtn(colors, '下载', onTap: _isLoading ? null : () => _showDownloadConfirm(), loading: _isLoading),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
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
          Text('支持的服务',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _tip(colors, '坚果云、Nextcloud、AList 等 WebDAV 服务'),
          _tip(colors, '服务器地址需包含 https://'),
          _tip(colors, '首次同步可能需要较长时间'),
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
            padding: const EdgeInsets.only(top: 8),
            child: Icon(Icons.circle,
                size: 4, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5))),
        ],
      ),
    );
  }
}
