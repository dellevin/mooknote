import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/sync/backup_service.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';

/// 本地备份页面
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isRunningAutoBackup = false;
  List<FileSystemEntity> _autoBackupFiles = [];

  @override
  void initState() {
    super.initState();
    _loadAutoBackupFiles();
  }

  Future<void> _loadAutoBackupFiles() async {
    if (!Platform.isAndroid) return;
    final files = await BackupService.instance.listLocalAutoBackups();
    if (mounted) {
      setState(() => _autoBackupFiles = files);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('本地备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 手动备份
          _buildSectionTitle(colors, '手动备份'),
          const SizedBox(height: 10),
          _buildActionCard(
            colors: colors,
            title: '导出数据',
            description: '将所有数据导出为 zip 文件，可用于备份或迁移到其他设备',
            icon: Icons.upload_outlined,
            buttonText: '导出',
            isLoading: _isExporting,
            onTap: _exportData,
          ),
          const SizedBox(height: 8),
          _buildActionCard(
            colors: colors,
            title: '导入数据',
            description: '从备份文件导入数据，将覆盖当前所有数据',
            icon: Icons.download_outlined,
            buttonText: '导入',
            isLoading: _isImporting,
            onTap: _importData,
            isDestructive: true,
          ),

          const SizedBox(height: 24),

          // 自动备份
          if (Platform.isAndroid) ...[
            _buildSectionTitle(colors, '自动备份'),
            const SizedBox(height: 10),
            _buildAutoBackupSection(colors),
          ],

          const SizedBox(height: 24),

          // 使用说明
          _buildInfoSection(colors),
        ],
      ),
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(ColorScheme colors, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
      ],
    );
  }

  /// 构建操作卡片
  Widget _buildActionCard({
    required ColorScheme colors,
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required bool isLoading,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isDestructive ? Colors.red : colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isLoading ? null : onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isLoading ? colors.onSurface.withValues(alpha: 0.25) : colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(colors.onPrimary),
                        ),
                      )
                    : Text(
                        buttonText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建自动备份区域
  Widget _buildAutoBackupSection(ColorScheme colors) {
    final userPrefs = UserPrefs();
    final isEnabled = userPrefs.localAutoBackupEnabled;
    final intervalHours = userPrefs.localAutoBackupIntervalHours;
    final lastTime = userPrefs.lastLocalAutoBackupTime;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 开关行
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.sync_outlined,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动备份',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isEnabled
                          ? '每 $intervalHours 小时自动备份一次，保留最新 5 个'
                          : '开启后自动定期备份数据',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (value) async {
                  await userPrefs.setLocalAutoBackupEnabled(value);
                  setState(() {});
                },
              ),
            ],
          ),

          if (isEnabled) ...[
            const SizedBox(height: 12),
            // 间隔选择
            _buildIntervalSelector(colors, intervalHours),
            const SizedBox(height: 10),
            // 立即备份按钮
            GestureDetector(
              onTap: _isRunningAutoBackup ? null : _runAutoBackupNow,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isRunningAutoBackup
                      ? colors.onSurface.withValues(alpha: 0.25)
                      : colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _isRunningAutoBackup
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colors.onPrimary),
                          ),
                        )
                      : Text(
                          '立即备份',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
            // 上次备份时间
            if (lastTime != null) ...[
              const SizedBox(height: 8),
              Text(
                '上次备份: ${_formatBackupTime(lastTime)}',
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
            // 备份文件列表
            if (_autoBackupFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._autoBackupFiles.map((f) => _buildBackupFileItem(colors, f)),
            ],
          ],
        ],
      ),
    );
  }

  /// 构建间隔选择器
  Widget _buildIntervalSelector(ColorScheme colors, int currentHours) {
    const options = [6, 12, 24, 48];
    return Row(
      children: options.map((h) {
        final selected = h == currentHours;
        return Expanded(
          child: GestureDetector(
            onTap: () async {
              await UserPrefs().setLocalAutoBackupIntervalHours(h);
              setState(() {});
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text(
                  h < 24 ? '$h小时' : '${h ~/ 24}天',
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
    );
  }

  /// 构建备份文件条目
  Widget _buildBackupFileItem(ColorScheme colors, FileSystemEntity file) {
    final name = file.path.split('/').last;
    final stat = file.statSync();
    final size = _formatFileSize(stat.size);
    final time = _formatBackupTime(stat.modified.toIso8601String());

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.description_outlined,
              size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$time · $size',
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息说明区域
  Widget _buildInfoSection(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '使用说明',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem(colors, '导出数据会生成一个 .zip 文件，包含所有数据和图片'),
          const SizedBox(height: 8),
          _buildInfoItem(colors, '选择保存路径后，可以通过微信、邮件等方式发送备份文件'),
          const SizedBox(height: 8),
          _buildInfoItem(colors, '在新设备上选择导入数据，选择备份文件即可恢复'),
          const SizedBox(height: 8),
          _buildInfoItem(colors, '导入数据会完全覆盖当前设备的数据，请谨慎操作'),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(ColorScheme colors, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Icon(Icons.circle,
              size: 4, color: colors.onSurface.withValues(alpha: 0.25)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.5),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 显示成功弹窗
  void _showSuccessDialog({
    required String title,
    required String content,
    String? detail,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Icon(Icons.check_circle_outline, color: colors.primary, size: 40),
              const SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(
                    fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6),
                textAlign: TextAlign.center,
              ),
              if (detail != null && detail.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    detail,
                    style:
                        TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                minimumSize: const Size(120, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('确定', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      },
    );
  }

  /// 导出数据
  Future<void> _exportData() async {
    setState(() => _isExporting = true);

    try {
      final result = await BackupService.instance.exportDataWithImages();

      if (!mounted) return;

      if (result.cancelled) {
        ToastUtil.show(context, '已取消导出');
      } else if (result.success) {
        _showSuccessDialog(
          title: '导出成功',
          content:
              '备份文件已保存，包含:\n影视 ${result.movieCount} · 书籍 ${result.bookCount} · 笔记 ${result.noteCount} · 图片 ${result.imageCount}',
          detail: result.filePath ?? '',
        );
      } else {
        ToastUtil.show(context, result.errorMessage ?? '导出失败');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '导出失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// 导入数据
  Future<void> _importData() async {
    // 显示确认对话框
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
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
              ),
              const SizedBox(width: 12),
              Text('确认导入',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          content: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '导入数据将覆盖当前所有数据，此操作不可恢复。',
              style: TextStyle(
                  fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurface.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('取消', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('确认导入', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isImporting = true);

    try {
      final result = await BackupService.instance.importData();

      if (!mounted) return;

      if (result.cancelled) {
        ToastUtil.show(context, '已取消导入');
      } else if (result.success) {
        // 刷新数据
        await context.read<AppProvider>().loadMovies();
        await context.read<AppProvider>().loadBooks();
        await context.read<AppProvider>().loadNotes();
        await context.read<AppProvider>().loadGames();
        await context.read<AppProvider>().loadPlaylists();
        await context.read<AppProvider>().loadPeople();

        if (!mounted) return;

        _showSuccessDialog(
          title: '导入成功',
          content: result.statsText,
        );
      } else {
        ToastUtil.show(context, result.errorMessage ?? '导入失败');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '导入失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  /// 立即执行一次自动备份
  Future<void> _runAutoBackupNow() async {
    setState(() => _isRunningAutoBackup = true);
    try {
      final result = await BackupService.instance.performLocalAutoBackup();
      if (!mounted) return;
      if (result.success) {
        ToastUtil.show(context, '自动备份完成');
        await _loadAutoBackupFiles();
      } else {
        ToastUtil.show(context, result.errorMessage ?? '自动备份失败');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '自动备份失败: $e');
    } finally {
      if (mounted) setState(() => _isRunningAutoBackup = false);
    }
  }

  /// 格式化备份时间
  String _formatBackupTime(String isoTime) {
    final dt = DateTime.tryParse(isoTime)?.toLocal();
    if (dt == null) return isoTime;
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)} ${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
