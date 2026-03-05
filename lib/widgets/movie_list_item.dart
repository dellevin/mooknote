import 'dart:io';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/movie-detail', arguments: movie);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 海报
              _buildPoster(context),
              
              const SizedBox(width: 14),
              
              // 影片信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      movie.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // 上映日期和评分
                    Row(
                      children: [
                        if (movie.releaseDate != null) ...[
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${movie.releaseDate!.year}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        
                        if (movie.rating != null) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            movie.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 导演
                    if (movie.directors.isNotEmpty)
                      _buildInfoRow(
                        context,
                        prefix: '导演',
                        items: movie.directors.take(2).toList(),
                      ),
                    
                    if (movie.directors.isNotEmpty && movie.genres.isNotEmpty)
                      const SizedBox(height: 4),
                    
                    // 类型标签
                    if (movie.genres.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: movie.genres.take(3).map((genre) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.primary.withOpacity(0.8),
                            ),
                          ),
                        )).toList(),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // 状态标签
                    _buildStatusTag(context),
                  ],
                ),
              ),
              
              // 右侧操作按钮
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 20, color: colorScheme.primary),
                    onPressed: () {
                      Navigator.pushNamed(context, '/movie-form', arguments: movie);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error.withOpacity(0.7)),
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

  /// 构建海报
  Widget _buildPoster(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 70,
        height: 100,
        color: colorScheme.surfaceContainerHighest,
        child: movie.posterPath != null && movie.posterPath!.isNotEmpty
            ? Image.file(
                File(movie.posterPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.movie_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
        size: 28,
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(BuildContext context, {required String prefix, required List<String> items}) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        Text(
          '$prefix: ',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
        Expanded(
          child: Text(
            items.join(' / '),
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 11,
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context, Movie movie) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          '确定要删除"${movie.title}"吗？',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(movie.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('已删除'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: colorScheme.primary,
                ),
              );
            },
            child: Text(
              '删除',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
