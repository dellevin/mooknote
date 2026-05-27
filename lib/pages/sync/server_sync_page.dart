import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/sync/server_sync_service.dart';
import '../../utils/sync/server_data_service.dart';
import '../../utils/toast_util.dart';

/// 服务端实时同步页面
class ServerSyncPage extends StatefulWidget {
  const ServerSyncPage({super.key});

  @override
  State<ServerSyncPage> createState() => _ServerSyncPageState();
}

class _ServerSyncPageState extends State<ServerSyncPage> {
  final UserPrefs _prefs = UserPrefs();
  final _urlController = TextEditingController();
  final _codeController = TextEditingController();

  bool _syncEnabled = false;
  bool _isActivated = false;
  bool _isChecking = false;
  String _expiresText = '';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _codeController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _loadSettings() {
    final url = _prefs.syncServerUrl;
    final code = _prefs.syncActivationCode;
    _urlController.text = url;
    _codeController.text = code;
    _isActivated = url.isNotEmpty && code.isNotEmpty;
    _syncEnabled = _isActivated && _prefs.syncEnabled;
    _updateExpiresText();
    if (_isActivated) _startStatusPolling();
  }

  void _updateExpiresText() {
    if (_prefs.syncIsPermanent) {
      _expiresText = '永久有效';
    } else {
      final exp = _prefs.syncExpiresAt;
      if (exp.isNotEmpty) {
        try {
          final dt = DateTime.parse(exp).add(const Duration(hours: 8));
          _expiresText = '有效期至 ${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          _expiresText = '有效期至 $exp';
        }
      } else {
        _expiresText = '';
      }
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (!_isActivated) return;
    final result = await ServerSyncService.instance.checkActivation();
    if (!mounted) return;
    if (result == null || result['valid'] != true) {
      await _prefs.setSyncEnabled(false);
      setState(() {
        _isActivated = false;
        _syncEnabled = false;
        _expiresText = '激活码已失效';
      });
      if (mounted) ToastUtil.show(context, '激活码已失效，同步已关闭');
    } else {
      await _prefs.setSyncExpiresAt(result['expires_at'] ?? '');
      await _prefs.setSyncIsPermanent(result['is_permanent'] == true);
      _updateExpiresText();
    }
  }

  Future<void> _checkActivation() async {
    final url = _urlController.text.trim();
    final code = _codeController.text.trim().toUpperCase();
    if (url.isEmpty || code.isEmpty) {
      ToastUtil.show(context, '请输入服务器地址和激活码');
      return;
    }
    setState(() => _isChecking = true);
    await _prefs.setSyncServerUrl(url);
    await _prefs.setSyncActivationCode(code);

    final result = await ServerSyncService.instance.checkActivation();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (result != null && result['valid'] == true) {
      _isActivated = true;
      await _prefs.setSyncExpiresAt(result['expires_at'] ?? '');
      await _prefs.setSyncIsPermanent(result['is_permanent'] == true);
      _updateExpiresText();
      _startStatusPolling();
      await _prefs.setSyncEnabled(true);
      _syncEnabled = true;
      await ServerSyncService.instance.syncWithServer();
      if (mounted) ToastUtil.show(context, '激活成功，实时同步已开启');
    } else {
      final error = result?['error'] ?? '激活失败';
      if (mounted) ToastUtil.show(context, error.toString());
    }
  }

  Future<void> _toggleSync(bool value) async {
    if (value && _isActivated) {
      // 开启同步：合并本地与服务端数据
      await _prefs.setSyncEnabled(true);
      setState(() => _syncEnabled = true);
      if (mounted) ToastUtil.show(context, '正在同步数据...');
      await ServerSyncService.instance.syncWithServer();
      final provider = context.read<AppProvider>();
      await provider.loadMovies();
      await provider.loadBooks();
      await provider.loadNotes();
      if (mounted) ToastUtil.show(context, '同步已开启，数据已合并');
    } else {
      // 关闭同步：先合并最新数据，再切换到本地
      if (mounted) ToastUtil.show(context, '正在同步数据到本地...');
      await ServerSyncService.instance.syncWithServer();
      await _prefs.setSyncEnabled(false);
      setState(() => _syncEnabled = false);
      final provider = context.read<AppProvider>();
      await provider.loadMovies();
      await provider.loadBooks();
      await provider.loadNotes();
      if (mounted) ToastUtil.show(context, '同步已关闭，已切换到本地数据');
    }
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('断开连接', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          content: Text('将清除服务器配置和激活信息，确定要断开吗？',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确定', style: TextStyle(color: Color(0xFFE53935)))),
          ],
        );
      },
    );
    if (confirm != true) return;

    _statusTimer?.cancel();
    await _toggleSync(false);
    await _prefs.setSyncServerUrl('');
    await _prefs.setSyncActivationCode('');
    await _prefs.setSyncExpiresAt('');
    await _prefs.setSyncIsPermanent(false);
    await _prefs.setSyncEnabled(false);

    setState(() {
      _isActivated = false;
      _syncEnabled = false;
      _expiresText = '';
      _urlController.clear();
      _codeController.clear();
    });
    if (mounted) ToastUtil.show(context, '已断开连接');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(title: const Text('服务端实时同步')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // 状态卡片
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _isActivated
                          ? const Color(0xFF66BB6A)
                          : colors.onSurface.withValues(alpha: 0.15),
                      shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(_isActivated ? '已激活' : '未激活',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isActivated
                          ? const Color(0xFF66BB6A)
                          : colors.onSurface.withValues(alpha: 0.3))),
              const Spacer(),
              if (_isActivated)
                GestureDetector(
                  onTap: _disconnect,
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                      child: const Text('断开',
                          style: TextStyle(fontSize: 12, color: Color(0xFFE57373)))),
                ),
            ]),
            const SizedBox(height: 20),
            Text('服务器地址',
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: _inputDeco(colors, '例: http://192.168.1.100:5000'),
            ),
            const SizedBox(height: 14),
            Text('激活码',
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 6),
            TextField(
                controller: _codeController,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                textCapitalization: TextCapitalization.characters,
                decoration: _inputDeco(colors, '例: MK-A1B2C3D4E5F6')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChecking ? null : _checkActivation,
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.onSurface.withValues(alpha: 0.15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                child: _isChecking
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.onPrimary))
                    : Text(_isActivated ? '重新验证' : '验证激活',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            if (_expiresText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time,
                    size: 14,
                    color: _prefs.syncIsPermanent
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFFFF9800)),
                const SizedBox(width: 6),
                Text(_expiresText,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _prefs.syncIsPermanent
                            ? const Color(0xFF66BB6A)
                            : const Color(0xFFFF9800))),
              ])),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // 同步开关
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))
              ]),
          child: Row(children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(_syncEnabled ? Icons.sync : Icons.sync_disabled,
                    color: _syncEnabled
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.25),
                    size: 22)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('服务端实时同步',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
              const SizedBox(height: 2),
              Text(_syncEnabled ? '使用服务端数据，多设备实时共享' : '关闭后下载数据到本地使用',
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
            ])),
            Switch(
                value: _syncEnabled,
                onChanged: _isActivated ? _toggleSync : null,
                activeThumbColor: colors.primary,
                activeTrackColor: colors.primary.withValues(alpha: 0.3),
                inactiveThumbColor: colors.surface,
                inactiveTrackColor: colors.outline),
          ]),
        ),
        const SizedBox(height: 24),
        // 说明
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))
              ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.info_outline,
                      size: 18, color: colors.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 10),
              Text('使用说明',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ]),
            const SizedBox(height: 14),
            _infoItem(colors, '1. 在服务端管理后台生成激活码'),
            const SizedBox(height: 8),
            _infoItem(colors, '2. 输入服务器地址和激活码完成验证'),
            const SizedBox(height: 8),
            _infoItem(colors, '3. 验证通过后自动开启实时同步'),
            const SizedBox(height: 8),
            _infoItem(colors, '4. 开启时所有数据通过服务端接口操作'),
            const SizedBox(height: 8),
            _infoItem(colors, '5. 关闭时从服务端下载数据到本地使用'),
          ]),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  InputDecoration _inputDeco(ColorScheme colors, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25)),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.primary, width: 1)),
    );
  }

  Widget _infoItem(ColorScheme colors, String text) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.3), shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5))),
    ]);
  }
}
