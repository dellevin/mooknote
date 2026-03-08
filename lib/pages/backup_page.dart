import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/backup_service.dart';
import '../utils/auto_backup_service.dart';
import '../utils/toast_util.dart';

/// 本地备份页面
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _autoBackupEnabled = false;
  bool _isLoading = true;
  List<File> _autoBackupFiles = [];
  String? _backupDirPath;

  @override
  void initState() {
    super.initState();
    _loadAutoBackupStatus();
  }

  Future<void> _loadAutoBackupStatus() async {
    final enabled = await AutoBackupService.instance.getEnabled();
    final files = await AutoBackupService.instance.getBackupFiles();
    final dirPath = await AutoBackupService.instance.getBackupDirectoryPath();
    if (mounted) {
      setState(() {
        _autoBackupEnabled = enabled;
        _autoBackupFiles = files;
        _backupDirPath = dirPath;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('本地备份'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 自动备份开关
          _buildAutoBackupSection(),
          
          const SizedBox(height: 32),
          
          // 自动备份文件列表
          if (_autoBackupFiles.isNotEmpty) ...[
            _buildBackupFilesSection(),
            const SizedBox(height: 32),
          ],
          
          // 导出数据
          _buildSection(
            title: '导出数据',
            description: '将所有数据导出为 zip 文件，可用于备份或迁移到其他设备',
            icon: Icons.upload_outlined,
            buttonText: '导出',
            isLoading: _isExporting,
            onTap: _exportData,
          ),
          
          const SizedBox(height: 32),
          
          // 导入数据
          _buildSection(
            title: '导入数据',
            description: '从备份文件导入数据，将覆盖当前所有数据',
            icon: Icons.download_outlined,
            buttonText: '导入',
            isLoading: _isImporting,
            onTap: _importData,
            isDestructive: true,
          ),
          
          const SizedBox(height: 48),
          
          // 说明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border.all(color: const Color(0xFFE5E5E5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: const Color(0xFF666666),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '使用说明',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '1. 导出数据会生成一个 .zip 文件，包含所有数据和图片\n'
                  '2. 选择保存路径后，可以通过微信、邮件等方式发送备份文件\n'
                  '3. 在新设备上选择导入数据，选择备份文件即可恢复\n'
                  '4. 导入数据会完全覆盖当前设备的数据，请谨慎操作',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF999999),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required bool isLoading,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isLoading ? null : onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
                side: BorderSide(
                  color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
                ),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          isDestructive ? Colors.red : const Color(0xFF1A1A1A),
                        ),
                      ),
                    )
                  : Text(buttonText),
            ),
          ),
        ],
      ),
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
        // 显示导出成功信息
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text('导出成功'),
            content: Text(
              '备份文件已保存到:\n${result.filePath}\n\n'
              '包含数据:\n'
              '• 影视: ${result.movieCount}\n'
              '• 书籍: ${result.bookCount}\n'
              '• 笔记: ${result.noteCount}\n'
              '• 图片: ${result.imageCount}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认导入'),
        content: const Text(
          '导入数据将覆盖当前所有数据，此操作不可恢复。\n\n是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认导入', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            title: const Text('导入成功'),
            content: Text('成功导入数据：\n${result.statsText}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
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

  /// 构建自动备份区域
  Widget _buildAutoBackupSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.schedule,
                size: 24,
                color: Color(0xFF1A1A1A),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '自动本地备份',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Switch(
                value: _autoBackupEnabled,
                onChanged: (value) async {
                  setState(() => _autoBackupEnabled = value);
                  await AutoBackupService.instance.setEnabled(value);
                  if (value) {
                    ToastUtil.show(context, '自动备份已开启，每2分钟备份一次');
                  } else {
                    ToastUtil.show(context, '自动备份已关闭');
                  }
                  // 刷新文件列表
                  await _loadAutoBackupStatus();
                },
                activeColor: const Color(0xFF1A1A1A),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '每隔2分钟自动备份到下载目录/mooknote文件夹，最多保留10个备份文件',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          if (_backupDirPath != null) ...[
            const SizedBox(height: 8),
            Text(
              '备份位置: $_backupDirPath',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建备份文件列表区域
  Widget _buildBackupFilesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 24,
                color: Color(0xFF1A1A1A),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '自动备份文件 (${_autoBackupFiles.length}/10)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._autoBackupFiles.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            final fileName = file.path.split('/').last;
            final stat = file.statSync();
            final size = _formatFileSize(stat.size);
            final modified = _formatDateTime(stat.modified);
            
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: index < _autoBackupFiles.length - 1
                      ? const BorderSide(color: Color(0xFFE5E5E5))
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.backup,
                    size: 18,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$modified · $size',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: const Text(
                        '最新',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
