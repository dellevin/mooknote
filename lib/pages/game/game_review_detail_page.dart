import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import 'game_review_form_page.dart';

/// 游戏评价详情页
class GameReviewDetailPage extends StatefulWidget {
  final GameReview review;
  final String gameId;

  const GameReviewDetailPage({super.key, required this.review, required this.gameId});

  @override
  State<GameReviewDetailPage> createState() => _GameReviewDetailPageState();
}

class _GameReviewDetailPageState extends State<GameReviewDetailPage> {
  late GameReview _review;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  Future<void> _refreshReviewData() async {
    final provider = context.read<AppProvider>();
    final reviews = await provider.getGameReviews(widget.gameId);
    final updatedReview = reviews.where((r) => r.id == widget.review.id).firstOrNull;
    if (updatedReview != null && updatedReview.id == _review.id) {
      setState(() => _review = updatedReview);
    }
  }

  Game? _getGame() {
    return context.read<AppProvider>().games.where((g) => g.id == widget.gameId).firstOrNull;
  }

  Future<void> _deleteReview() async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除这条评价吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    if (confirmed == true) {
      await context.read<AppProvider>().removeGameReview(_review.id);
      if (mounted) { ToastUtil.show(context, '已删除'); Navigator.pop(context); }
    }
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameReviewFormPage(gameId: widget.gameId, review: _review)),
    ).then((_) => _refreshReviewData());
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final game = _getGame();

    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        title: const Text('评价详情'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _navigateToEdit(context), tooltip: '编辑'),
          IconButton(icon: Icon(Icons.delete_outline, size: 20, color: colors.error.withValues(alpha: 0.7)), onPressed: _deleteReview, tooltip: '删除'),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (game != null) _buildGameCard(game, colors),
          if (game != null) const SizedBox(height: 16),
          _buildContentCard(colors),
          const SizedBox(height: 16),
          _buildInfoCard(colors),
        ]),
      ),
    );
  }

  Widget _buildGameCard(Game game, ColorScheme colors) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Container(
        width: 52, height: 68,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: colors.surfaceContainerHighest),
        clipBehavior: Clip.antiAlias,
        child: game.coverPath != null
            ? FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover,
                errorWidget: Icon(Icons.sports_esports_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)))
            : Icon(Icons.sports_esports_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(game.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
        if (game.rating != null) ...[const SizedBox(height: 4), Row(children: [
          Icon(Icons.star, size: 14, color: const Color(0xFFFFB800)),
          const SizedBox(width: 2),
          Text('${game.rating}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
        ])],
      ])),
    ]),
  );

  Widget _buildContentCard(ColorScheme colors) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_review.content, style: TextStyle(fontSize: 16, color: colors.onSurface, height: 1.8)),
      const SizedBox(height: 16),
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(_review.typeText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.primary)),
        ),
      ]),
    ]),
  );

  Widget _buildInfoCard(ColorScheme colors) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      _infoRow(Icons.person_outline, '评价人', _review.reviewer.isNotEmpty ? _review.reviewer : '匿名', colors),
      Divider(height: 24, color: colors.outlineVariant),
      if (_review.source.isNotEmpty) ...[
        _infoRow(Icons.link, '来源', _review.source, colors),
        const Divider(height: 24),
      ],
      _infoRow(Icons.access_time, '时间', _formatDate(_review.createdAt), colors),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value, ColorScheme colors) => Row(children: [
    Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
    const Spacer(),
    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
  ]);
}
