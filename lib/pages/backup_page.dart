import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/backup_service.dart';

/// 数据备份页面
class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('数据备份'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 导出数据
          _buildSection(
            title: '导出数据',
            description: '将所有数据导出为 JSON 文件，可用于备份或迁移到其他设备',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消导出')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? '导出失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消导入')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? '导入失败')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}
