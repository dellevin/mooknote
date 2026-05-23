import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import '../widgets/fade_in_local_image.dart';
import '../widgets/animated_star_rating.dart';
import '../utils/toast_util.dart';

/// 观影列表项组件 - 网格布局设计
class MovieListItem extends StatelessWidget {
  final Movie movie;

  const MovieListItem({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/movie-detail', arguments: movie);
      },
      onLongPress: () => _showDeleteDialog(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报
          Expanded(
            child: _buildPoster(),
          ),

          const SizedBox(height: 8),

          // 影视名称
          Text(
            movie.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // 评分
          if (movie.rating != null)
            AnimatedStarRating(rating: movie.rating!, starSize: 12, showNumber: true)
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  /// 构建海报
  Widget _buildPoster() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: FadeInLocalImage(
        path: movie.posterPath,
        fit: BoxFit.cover,
        placeholder: const Center(child: Icon(Icons.movie_outlined, size: 24, color: Color(0xFFCCCCCC))),
        errorWidget: const Center(child: Icon(Icons.movie_outlined, size: 24, color: Color(0xFFCCCCCC))),
      ),
    );
  }
  
  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要删除《${movie.title}》吗？删除后可在回收站恢复。',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(movie.id);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
