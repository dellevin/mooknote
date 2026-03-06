import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 观影列表项组件 - 极简主义设计
class MovieListItem extends StatelessWidget {
  final Movie movie;
  
  const MovieListItem({super.key, required this.movie});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/movie-detail', arguments: movie);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报
            _buildPoster(),
            
            const SizedBox(width: 16),
            
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 影视名称
                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // 导演
                  if (movie.directors.isNotEmpty)
                    Text(
                      movie.directors.take(2).join(' / '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // 评分和状态
                  Row(
                    children: [
                      if (movie.rating != null) ...[
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          movie.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      _buildStatusTag(),
                    ],
                  ),
                  
                  // 类型
                  if (movie.genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      movie.genres.take(3).join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // 操作按钮
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: const Color(0xFF666666),
                  onPressed: () {
                    Navigator.pushNamed(context, '/movie-form', arguments: movie);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                  onPressed: () => _showDeleteDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建海报
  Widget _buildPoster() {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      child: movie.posterPath != null && movie.posterPath!.isNotEmpty
          ? Image.file(
              File(movie.posterPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPosterPlaceholder(),
            )
          : _buildPosterPlaceholder(),
    );
  }
  
  Widget _buildPosterPlaceholder() {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        size: 24,
        color: Color(0xFFCCCCCC),
      ),
    );
  }
  
  /// 构建状态标签
  Widget _buildStatusTag() {
    String label;
    Color color;
    switch (movie.status) {
      case 'watched':
        label = '已看';
        color = const Color(0xFF1A1A1A);
        break;
      case 'watching':
        label = '在看';
        color = const Color(0xFF666666);
        break;
      case 'want_to_watch':
        label = '想看';
        color = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        color = const Color(0xFFCCCCCC);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: Text('确定要删除"${movie.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(movie.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
