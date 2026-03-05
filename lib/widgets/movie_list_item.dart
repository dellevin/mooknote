import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/app_theme.dart';

/// 观影列表项组件
class MovieListItem extends StatelessWidget {
  final Movie movie;

  const MovieListItem({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // 跳转到详情页
          Navigator.pushNamed(context, '/movie-detail', arguments: movie);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 海报占位图
              _buildPoster(),
              
              const SizedBox(width: 12),
              
              // 影片信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题和年份
                    Text(
                      movie.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    if (movie.year != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${movie.year}年',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    // 评分和状态
                    Row(
                      children: [
                        if (movie.rating != null) ...[
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.rating.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        
                        // 状态标签
                        _buildStatusTag(context),
                      ],
                    ),
                    
                    if (movie.watchDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '观看日期：${_formatDate(movie.watchDate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    
                    if (movie.note != null && movie.note!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        movie.note!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // 右侧操作按钮
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      Navigator.pushNamed(context, '/movie-form', arguments: movie);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () => _showDeleteDialog(context, movie),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建海报占位图
  Widget _buildPoster() {
    return Container(
      width: 60,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.movie,
        color: Colors.grey[500],
        size: 32,
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusTag(BuildContext context) {
    Color statusColor;
    String statusText;
    
    switch (movie.status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: statusColor,
          width: 1,
        ),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 11,
          color: statusColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context, Movie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除"${movie.title}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(movie.id);
              if (!context.mounted) return;
              Navigator.pop(context);
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
