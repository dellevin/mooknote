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
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/movie-detail', arguments: movie);
      },
      onLongPress: () => _showDeleteDialog(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildPoster(colors),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (movie.rating != null)
            AnimatedStarRating(rating: movie.rating!, starSize: 12, showNumber: true)
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPoster(ColorScheme colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: FadeInLocalImage(
        path: movie.posterPath,
        fit: BoxFit.cover,
        placeholder: Center(child: Icon(Icons.movie_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25))),
        errorWidget: Center(child: Icon(Icons.movie_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25))),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          '确定要删除《${movie.title}》吗？删除后可在回收站恢复。',
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
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
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
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
