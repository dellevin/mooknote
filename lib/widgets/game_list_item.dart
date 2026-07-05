import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import '../widgets/fade_in_local_image.dart';
import '../widgets/animated_star_rating.dart';
import '../utils/toast_util.dart';

/// 游戏列表项组件 - 网格布局设计
class GameListItem extends StatelessWidget {
  final Game game;
  final bool selected;
  final VoidCallback? onTap;

  const GameListItem({super.key, required this.game, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap ?? () => Navigator.pushNamed(context, '/game-detail', arguments: game),
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.primary, width: 2),
              )
            : null,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildCover(colors),
          ),
          const SizedBox(height: 8),
          Text(
            game.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (game.rating != null)
            AnimatedStarRating(rating: game.rating!, starSize: 12, showNumber: true)
          else
            const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }

  Widget _buildCover(ColorScheme colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: FadeInLocalImage(
        path: game.coverPath,
        fit: BoxFit.cover,
        placeholder: Center(child: Icon(Icons.sports_esports_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25))),
        errorWidget: Center(child: Icon(Icons.sports_esports_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25))),
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
          '确定要删除《${game.title}》吗？删除后可在回收站恢复。',
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
              await context.read<AppProvider>().removeGame(game.id);
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
