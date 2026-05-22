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
          // 自动备份开关 - 紧凑一行
          _buildAutoBackupSection(),

          const SizedBox(height: 24),

          // 手动备份
          _buildSectionTitle('手动备份'),
          const SizedBox(height: 12),
          _buildActionCard(
            title: '导出数据',
            description: '将所有数据导出为 zip 文件，可用于备份或迁移到其他设备',
            icon: Icons.upload_outlined,
            buttonText: '导出',
            isLoading: _isExporting,
            onTap: _exportData,
          ),
          const SizedBox(height: 12),
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
          GestureDetector(
            onTap: isLoading ? null : onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isLoading ? const Color(0xFFCCCCCC) : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
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
                          color: Colors.white,
                        ),
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

  /// 显示成功弹窗
  void _showSuccessDialog({
    required String title,
    required String content,
    String? detail,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Column(
          children: [
            Container(
              width: 48,
              height: 48,
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6),
              textAlign: TextAlign.center,
            ),
            if (detail != null && detail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detail,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              minimumSize: const Size(120, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确定', style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
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
        _showSuccessDialog(
          title: '导出成功',
          content: '备份文件已保存，包含:\n影视 ${result.movieCount} · 书籍 ${result.bookCount} · 笔记 ${result.noteCount} · 图片 ${result.imageCount}',
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('确认导入', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          ],
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            '导入数据将覆盖当前所有数据，此操作不可恢复。',
            style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6),
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666), fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确认导入', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600)),
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

  /// 构建自动备份区域 - 紧凑一行
  Widget _buildAutoBackupSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            child: const Icon(Icons.schedule, size: 20, color: Color(0xFF666666)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _backupDirPath != null && _autoBackupEnabled
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '自动本地备份',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _backupDirPath!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : const Text(
                    '自动本地备份',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
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
    );
  }

}
