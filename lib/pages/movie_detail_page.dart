import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/app_theme.dart';

/// 影视详情页
class MovieDetailPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.movie.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEdit(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报区域
            _buildPosterSection(context),

            // 基本信息
            _buildInfoSection(context),

            // 笔记区域
            if (widget.movie.note != null && widget.movie.note!.isNotEmpty)
              _buildNoteSection(context),
          ],
        ),
      ),
    );
  }

  /// 构建海报区域
  Widget _buildPosterSection(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[300],
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.movie,
              size: 80,
              color: Colors.grey[500],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _buildStatusTag(context),
          ),
        ],
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusTag(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (widget.movie.status) {
      case 'watched':
        statusColor = AppTheme.watchedColor;
        statusText = '已看';
        break;
      case 'want_to_watch':
        statusColor = AppTheme.wantToWatchColor;
        statusText = '想看';
        break;
      case 'watching':
        statusColor = AppTheme.watchingColor;
        statusText = '在看';
        break;
      default:
        statusColor = Colors.grey;
        statusText = '未知';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 构建信息区域
  Widget _buildInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            widget.movie.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          // 年份和评分
          Row(
            children: [
              if (widget.movie.year != null) ...[
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today,
                  label: '${widget.movie.year}年',
                ),
                const SizedBox(width: 16),
              ],
              if (widget.movie.rating != null) ...[
                _buildInfoItem(
                  context,
                  icon: Icons.star,
                  label: widget.movie.rating.toString(),
                  iconColor: Colors.amber[700],
                  textColor: Colors.amber[700],
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // 观看日期
          if (widget.movie.watchDate != null)
            _buildInfoItem(
              context,
              icon: Icons.event,
              label: '观看日期：${_formatDate(widget.movie.watchDate!)}',
            ),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: textColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 构建笔记区域
  Widget _buildNoteSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '笔记',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.movie.note!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/movie-form', arguments: widget.movie).then((_) {
      // 返回后刷新数据
      context.read<AppProvider>().loadMovies();
    });
  }

  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${widget.movie.title}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(widget.movie.id);
              if (!context.mounted) return;
              Navigator.pop(context); // 关闭对话框
              Navigator.pop(context); // 返回上一页
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已删除'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
