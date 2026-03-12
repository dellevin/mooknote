import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/sync/backup_service.dart';
import '../../utils/sync/auto_backup_service.dart';
import '../../utils/toast_util.dart';

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
  String? _backupDirPath;

  @override
  void initState() {
    super.initState();
    _loadAutoBackupStatus();
  }

  Future<void> _loadAutoBackupStatus() async {
    final enabled = await AutoBackupService.instance.getEnabled();
    final dirPath = await AutoBackupService.instance.getBackupDirectoryPath();
    if (mounted) {
      setState(() {
        _autoBackupEnabled = enabled;
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
          // 数据操作区域
          _buildSectionTitle('手动备份'),
          const SizedBox(height: 16),
          
          // 导出数据
          _buildActionCard(
            title: '导出数据',
            description: '将所有数据导出为 zip 文件，可用于备份或迁移到其他设备',
            icon: Icons.upload_outlined,
            buttonText: '导出',
            isLoading: _isExporting,
            onTap: _exportData,
          ),
          
          const SizedBox(height: 16),
          
          // 导入数据
          _buildActionCard(
            title: '导入数据',
            description: '从备份文件导入数据，将覆盖当前所有数据',
            icon: Icons.download_outlined,
            buttonText: '导入',
            isLoading: _isImporting,
            onTap: _importData,
            isDestructive: true,
          ),
          
          const SizedBox(height: 32),
          
          // 自动备份开关
          _buildAutoBackupSection(),
          
          const SizedBox(height: 32),
          
          // 使用说明
          _buildInfoSection(),
        ],
      ),
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  /// 构建操作卡片
  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required bool isLoading,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDestructive 
                        ? Colors.red.withOpacity(0.3) 
                        : const Color(0xFFE8E8E8),
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isDestructive ? Colors.red : const Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDestructive 
                    ? Colors.red 
                    : const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息说明区域
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '使用说明',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('1', '导出数据会生成一个 .zip 文件，包含所有数据和图片'),
          const SizedBox(height: 12),
          _buildInfoItem('2', '选择保存路径后，可以通过微信、邮件等方式发送备份文件'),
          const SizedBox(height: 12),
          _buildInfoItem('3', '在新设备上选择导入数据，选择备份文件即可恢复'),
          const SizedBox(height: 12),
          _buildInfoItem('4', '导入数据会完全覆盖当前设备的数据，请谨慎操作'),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ),
      ],
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
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 22,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动本地备份',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '每2分钟自动备份，保留最近10个备份',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _autoBackupEnabled,
                onChanged: (value) async {
                  setState(() => _autoBackupEnabled = value);
                  await AutoBackupService.instance.setEnabled(value);
                  if (value) {
                    ToastUtil.show(context, '自动备份已开启');
                  } else {
                    ToastUtil.show(context, '自动备份已关闭');
                  }
                  await _loadAutoBackupStatus();
                },
                activeColor: const Color(0xFF1A1A1A),
                activeTrackColor: const Color(0xFF1A1A1A).withOpacity(0.3),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE5E5E5),
              ),
            ],
          ),
          if (_backupDirPath != null && _autoBackupEnabled) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_outlined,
                    size: 16,
                    color: Color(0xFF999999),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _backupDirPath!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}
