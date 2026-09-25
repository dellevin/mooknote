import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../services/sync/webdav_service.dart';
import '../../services/sync/incremental/inc_sync_service.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_overlay.dart';
import '../../l10n/app_strings.dart';

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
  String _syncStep = '';

  /// 备份方式：full 全量 zip / inc 增量
  String _backupMode = 'full';

  // 增量同步信息
  int? _incManifestVersion;
  String? _incLastSync;
  bool _isLoadingIncInfo = false;

  // 增量自动同步设置
  bool _incAutoSyncEnabled = false;
  int _incAutoSyncInterval = 30;

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
    final prefs = await SharedPreferences.getInstance();
    _backupMode = prefs.getString('webdav_backup_mode') ?? 'full';
    final userPrefs = UserPrefs();
    _incAutoSyncEnabled = userPrefs.webdavIncAutoSyncEnabled;
    _incAutoSyncInterval = userPrefs.webdavIncAutoSyncIntervalMinutes;
    if (config != null && mounted) {
      setState(() {
        _urlController.text = config['url'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
        _pathController.text = config['path'] ?? '/mooknote';
        _isConfigured = true;
      });
      _loadRemoteInfo();
      _loadIncInfo();
    }
  }

  Future<void> _loadIncInfo() async {
    setState(() => _isLoadingIncInfo = true);
    final info = await IncSyncService.instance.getInfo();
    if (mounted) {
      setState(() {
        _incManifestVersion = info['manifestVersion'] as int?;
        _incLastSync = info['lastSync'] as String?;
        _isLoadingIncInfo = false;
      });
    }
  }

  Future<void> _switchMode(String mode) async {
    if (_backupMode == mode) return;
    setState(() => _backupMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_backup_mode', mode);
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
      ToastUtil.show(context, '请输入服务器地址'.tr);
      return;
    }
    if (username.isEmpty) {
      ToastUtil.show(context, '请输入用户名'.tr);
      return;
    }
    if (password.isEmpty) {
      ToastUtil.show(context, '请输入密码'.tr);
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
        ToastUtil.show(context, result['message'] ?? '连接成功，配置已保存'.tr);
      } else {
        ToastUtil.show(context, result['message'] ?? '连接失败，请检查配置'.tr);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '连接失败: {e}'.trf({'e': e}));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isLoading = true);

    try {
      // ── 增量备份分支：双向同步（推本地变更 + 拉云端变更，LWW 合并）──
      if (_backupMode == 'inc') {
        setState(() => _syncStep = '正在同步数据...'.tr);
        await Future.delayed(Duration.zero);
        final result = await IncSyncService.instance.upload();
        if (!mounted) return;
        _loadIncInfo();
        if (result.success) {
          final details =
              '上传: {rec} 记录, {img} 图片（去重 {dedup}）\n下载: {drec} 记录, {dimg} 图片'
                  .trf({
            'rec': result.uploadedRecords,
            'img': result.uploadedImages,
            'dedup': result.dedupImages,
            'drec': result.downloadedRecords,
            'dimg': result.downloadedImages,
          });
          if (result.needReload) {
            ToastUtil.show(context, '数据已更新，正在重新加载...'.tr);
            final provider = context.read<AppProvider>();
            await provider.loadMovies();
            await provider.loadBooks();
            await provider.loadNotes();
            await provider.loadGames();
            await provider.loadPlaylists();
            await provider.loadPeople();
          }
          if (mounted) {
            _showResultDialog('同步成功'.tr, details);
          }
        } else {
          ToastUtil.show(context, result.message);
        }
        return;
      }

      SyncResult result;

      if (_syncDirection == SyncDirection.upload) {
        // 上传：先打包再上传，分步显示
        setState(() => _syncStep = '正在打包数据...'.tr);
        await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
        final exportResult = await WebDAVService.instance.exportLocalData();
        if (!exportResult.success || exportResult.zipPath == null) {
          if (mounted) {
            setState(() { _isLoading = false; _syncStep = ''; });
            ToastUtil.show(context, exportResult.errorMessage ?? '创建备份失败'.tr);
          }
          return;
        }
        if (!mounted) return;
        setState(() => _syncStep = '正在上传到云端...'.tr);
        await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
        result = await WebDAVService.instance.uploadExportedData(exportResult);
      } else {
        // 下载
        setState(() => _syncStep = '正在从云端下载...'.tr);
        await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
        result = await WebDAVService.instance.syncData(direction: SyncDirection.download);
      }

      if (!mounted) return;

      if (result.success) {
        // 同步成功后刷新远程文件信息
        _loadRemoteInfo();
        final details = '上传: {files} 文件, {images} 图片\n下载: {dfiles} 文件, {dimages} 图片'
            .trf({
          'files': result.uploadedFiles,
          'images': result.uploadedImages,
          'dfiles': result.downloadedFiles,
          'dimages': result.downloadedImages,
        });

        if (result.needReload) {
          ToastUtil.show(context, '数据已更新，正在重新加载...'.tr);
          final provider = context.read<AppProvider>();
          await provider.loadMovies();
          await provider.loadBooks();
          await provider.loadNotes();
          await provider.loadGames();
          await provider.loadPlaylists();
          await provider.loadPeople();
          if (mounted) _showResultDialog('同步成功'.tr, details);
        } else {
          _showResultDialog('同步成功'.tr, details);
        }
      } else {
        ToastUtil.show(context, result.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '同步失败: {e}'.trf({'e': e}));
    } finally {
      if (mounted) setState(() { _isLoading = false; _syncStep = ''; });
    }
  }

  void _showResultDialog(String title, String content) {
    appDialog(
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
              child: Text('确定'.tr, style: TextStyle(fontSize: 14, color: colors.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showIncSyncConfirm() async {
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('立即同步'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text(
              '推送本地变更到云端，并拉取云端变更与本地合并（同一条记录以最后修改为准），点击确定继续'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('确定'.tr),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      _syncData();
    }
  }

  Future<void> _showUploadConfirm() async {
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认上传'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('该操作会覆盖掉远程数据，请谨慎操作，点击确定继续上传'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('确定'.tr),
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
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认下载'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('该操作会拉取远程数据覆盖掉本地数据，请谨慎操作，点击确定将数据拉取到本地'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('确定'.tr),
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

  Future<void> _forcePushConfirm() async {
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('强制推送'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('以本机数据为准覆盖云端：云端将被重建为本机当前状态，其他设备尚未同步到本机的变更会丢失。确定继续？'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('确定'.tr),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _syncStep = '正在强制推送...'.tr;
      });
      try {
        final result = await IncSyncService.instance.forcePush();
        if (!mounted) return;
        _loadIncInfo();
        if (result.success) {
          _showResultDialog('推送完成'.tr,
              '上传: {rec} 记录, {img} 图片'.trf({
            'rec': result.uploadedRecords,
            'img': result.uploadedImages,
          }));
        } else {
          ToastUtil.show(context, result.message);
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; _syncStep = ''; });
      }
    }
  }

  Future<void> _reDownloadConfirm() async {
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('重新同步'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('重新从云端完整拉取一遍数据。本地较新的修改不会被覆盖。当同步结果不正常、拉取不到其他设备的数据时使用。'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('确定'.tr),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _syncStep = '正在重新同步...'.tr;
      });
      try {
        final result = await IncSyncService.instance.reDownload();
        if (!mounted) return;
        _loadIncInfo();
        if (result.success) {
          if (result.needReload) {
            final provider = context.read<AppProvider>();
            await provider.loadMovies();
            await provider.loadBooks();
            await provider.loadNotes();
            await provider.loadGames();
            await provider.loadPlaylists();
            await provider.loadPeople();
          }
          if (mounted) {
            _showResultDialog('同步成功'.tr,
                '下载: {drec} 记录, {dimg} 图片'.trf({
              'drec': result.downloadedRecords,
              'dimg': result.downloadedImages,
            }));
          }
        } else {
          ToastUtil.show(context, result.message);
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; _syncStep = ''; });
      }
    }
  }

  Future<void> _restoreConfirm() async {
    final confirmed = await appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('从云端恢复'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('以云端数据为准覆盖本机：删除过的内容会重新回来，本地的旧内容被云端版本覆盖。本地新增且未上传的数据会保留。确定继续？'.tr,
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('确定'.tr),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _syncStep = '正在从云端恢复...'.tr;
      });
      try {
        final result = await IncSyncService.instance.restoreDownload();
        if (!mounted) return;
        _loadIncInfo();
        if (result.success) {
          if (result.needReload) {
            final provider = context.read<AppProvider>();
            await provider.loadMovies();
            await provider.loadBooks();
            await provider.loadNotes();
            await provider.loadGames();
            await provider.loadPlaylists();
            await provider.loadPeople();
          }
          if (mounted) {
            _showResultDialog('恢复完成'.tr,
                '恢复: {drec} 记录, {dimg} 图片'.trf({
              'drec': result.downloadedRecords,
              'dimg': result.downloadedImages,
            }));
          }
        } else {
          ToastUtil.show(context, result.message);
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; _syncStep = ''; });
      }
    }
  }

  Future<void> _clearConfig() async {
    final confirmed = await appDialog<bool>(
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
              Text('清除配置'.tr,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text('确定要清除 WebDAV 配置吗？'.tr,
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
              child: Text('取消'.tr, style: const TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('清除'.tr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
      if (mounted) ToastUtil.show(context, '配置已清除'.tr);
    }
  }

  // ── UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text('WebDAV 备份'.tr),
          leading: _isLoading ? const SizedBox.shrink() : null,
        ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 4),

              // 已连接提示
              if (_isConfigured) _buildConnectedBanner(colors),

              if (_isConfigured) ...[
                // 备份方式切换
                _buildModeSwitch(colors),
                const SizedBox(height: 16),
                // 远程备份信息卡片（包含操作按钮）
                if (_backupMode == 'full')
                  _buildRemoteInfoCard(colors)
                else
                  _buildIncrementalInfoCard(colors),
                const SizedBox(height: 24),
              ],

              // 服务器配置
              _buildSectionLabel(colors, '服务器配置'.tr),
                const SizedBox(height: 12),
                _buildInput(
                  colors: colors,
                  controller: _urlController,
                  hint: '服务器地址，如 https://dav.example.com'.tr,
                  icon: Icons.link,
                ),
                const SizedBox(height: 8),
                _buildInput(
                  colors: colors,
                  controller: _usernameController,
                  hint: '用户名'.tr,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 8),
                _buildInput(
                  colors: colors,
                  controller: _passwordController,
                  hint: '密码'.tr,
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
                  hint: '同步路径，如 /mooknote'.tr,
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 16),

                // 测试并保存
                _buildBtn(colors, '测试并保存'.tr, onTap: _isLoading ? null : _saveConfig),
                if (_isConfigured) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _isLoading ? null : _clearConfig,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('清除配置'.tr,
                            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),

              const SizedBox(height: 24),
              _buildTips(colors),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    ),
    );
  }

  // ── widgets ─────────────────────────────────────────

  Widget _buildModeSwitch(ColorScheme colors) {
    Widget segment(String mode, String label, IconData icon) {
      final selected = _backupMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: _isLoading ? null : () => _switchMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          segment('full', '全量备份'.tr, Icons.inventory_2_outlined),
          segment('inc', '增量备份'.tr, Icons.timeline),
        ],
      ),
    );
  }

  Widget _buildIncrementalInfoCard(ColorScheme colors) {
    String versionText = _incManifestVersion == null
        ? '尚未建立'.tr
        : 'v$_incManifestVersion';
    String syncText = '暂无记录'.tr;
    if (_incLastSync != null) {
      final dt = DateTime.tryParse(_incLastSync!)?.toLocal();
      if (dt != null) {
        syncText = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
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
              Icon(Icons.timeline, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text('增量备份'.tr,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const Spacer(),
              if (_isLoadingIncInfo)
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
              else
                GestureDetector(
                  onTap: _loadIncInfo,
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
                    Text('基线版本'.tr,
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(height: 4),
                    Text(versionText,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('上次同步'.tr,
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(height: 4),
                    Text(syncText,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 12),
          if (_isLoading) ...[
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                backgroundColor: colors.surfaceContainerHighest,
                color: colors.primary,
                minHeight: 3,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(height: 10),
            Text(_syncStep,
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
          ] else ...[
            _buildIncAutoSyncSection(colors),
            const SizedBox(height: 10),
            _buildBtn(colors, '立即同步'.tr,
                onTap: _isLoading ? null : _showIncSyncConfirm),
            const SizedBox(height: 10),
            Text(
              '推送本地变更到云端，并拉取云端变更与本地合并（同一条记录以最后修改为准）'.tr,
              style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.4),
                  height: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _isLoading ? null : _forcePushConfirm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text('强制推送'.tr,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  color: colors.onSurface.withValues(alpha: 0.15),
                ),
                GestureDetector(
                  onTap: _isLoading ? null : _restoreConfirm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text('从云端恢复'.tr,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ),
                ),
                Container(
                  width: 1,
                  height: 12,
                  color: colors.onSurface.withValues(alpha: 0.15),
                ),
                GestureDetector(
                  onTap: _isLoading ? null : _reDownloadConfirm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text('重新同步'.tr,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 自动同步设置：开关 + 间隔（分钟）选择
  Widget _buildIncAutoSyncSection(ColorScheme colors) {
    const options = [15, 30, 60, 120];
    String intervalLabel(int m) =>
        m < 60 ? '{m}分钟'.trf({'m': m}) : '{h}小时'.trf({'h': m ~/ 60});

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('自动同步'.tr,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                    const SizedBox(height: 1),
                    Text(
                      _incAutoSyncEnabled
                          ? '每隔 {t} 自动同步一次'.trf({'t': intervalLabel(_incAutoSyncInterval)})
                          : '开启后按设定间隔自动同步'.tr,
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4), height: 1.3),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _incAutoSyncEnabled,
                onChanged: (value) async {
                  await UserPrefs().setWebdavIncAutoSyncEnabled(value);
                  setState(() => _incAutoSyncEnabled = value);
                },
              ),
            ],
          ),
          if (_incAutoSyncEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: options.map((m) {
                final selected = m == _incAutoSyncInterval;
                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await UserPrefs().setWebdavIncAutoSyncIntervalMinutes(m);
                      setState(() => _incAutoSyncInterval = m);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? colors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          intervalLabel(m),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectedBanner(ColorScheme colors) {    return Container(
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
          Text('已连接'.tr,
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

  Widget _buildBtn(ColorScheme colors, String text, {VoidCallback? onTap}) {
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
          child: Text(text,
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
      timeText = '加载中...'.tr;
    } else if (_remoteModifiedTime != null) {
      final dt = _remoteModifiedTime!;
      timeText = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (_remoteFileSize != null) {
        sizeText = _formatFileSize(_remoteFileSize!);
      }
    } else {
      timeText = '暂无备份文件'.tr;
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
              Text('云端备份'.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
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
                    Text('上传时间'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
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
                      Text('文件大小'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
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
          if (_isLoading) ...[
            SizedBox(
              width: double.infinity,
              child: LinearProgressIndicator(
                backgroundColor: colors.surfaceContainerHighest,
                color: colors.primary,
                minHeight: 3,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(height: 10),
            Text(_syncStep, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildBtn(colors, '上传'.tr, onTap: _isLoading ? null : () => _showUploadConfirm()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBtn(colors, '下载'.tr, onTap: _isLoading ? null : () => _showDownloadConfirm()),
                ),
              ],
            ),
          ],
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
          Text('支持的服务'.tr,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.4),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _tip(colors, '坚果云、Nextcloud、AList 等 WebDAV 服务'.tr),
          _tip(colors, '服务器地址需包含 https://'.tr),
          _tip(colors, '首次同步可能需要较长时间'.tr),
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
