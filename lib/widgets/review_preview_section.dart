import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../l10n/app_strings.dart';
import '../pages/movies/movie_reviews_page.dart';
import '../pages/movies/movie_review_detail_page.dart';
import '../pages/book/book_reviews_page.dart';
import '../pages/book/book_review_detail_page.dart';
import '../pages/game/game_reviews_page.dart';
import '../pages/game/game_review_detail_page.dart';

/// 详情页影评预览模块：列表形式展示前 5 条，超过 5 条显示"查看更多"跳转列表页。
/// 支持影视 / 书籍 / 游戏三种类型，无影评时自动隐藏。
class ReviewPreviewSection extends StatefulWidget {
  final String workId;
  final String workType; // 'movie' / 'book' / 'game'
  final bool isOverlay;
  final EdgeInsetsGeometry padding;

  const ReviewPreviewSection({
    super.key,
    required this.workId,
    required this.workType,
    this.isOverlay = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<ReviewPreviewSection> createState() => _ReviewPreviewSectionState();
}

class _ReviewPreviewSectionState extends State<ReviewPreviewSection> {
  static const int _previewCount = 5;

  List<dynamic> _reviews = [];
  int _total = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReviewPreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workId != widget.workId || oldWidget.workType != widget.workType) {
      _load();
    }
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    final List<dynamic> all;
    switch (widget.workType) {
      case 'book':
        all = await provider.getBookReviews(widget.workId);
      case 'game':
        all = await provider.getGameReviews(widget.workId);
      default:
        all = await provider.getMovieReviews(widget.workId);
    }
    if (!mounted) return;
    setState(() {
      _total = all.length;
      _reviews = all.take(_previewCount).toList();
      _loaded = true;
    });
  }

  String get _title => switch (widget.workType) {
        'book' => '书评',
        'game' => '游戏评价',
        _ => '影评',
      };

  void _openReviewDetail(dynamic review) {
    final Widget page = switch (widget.workType) {
      'book' => BookReviewDetailPage(review: review as BookReview, bookId: widget.workId),
      'game' => GameReviewDetailPage(review: review as GameReview, gameId: widget.workId),
      _ => MovieReviewDetailPage(review: review as MovieReview, movieId: widget.workId),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => _load());
  }

  void _openAll() {
    final provider = context.read<AppProvider>();
    Widget? page;
    switch (widget.workType) {
      case 'book':
        final book = provider.books.where((b) => b.id == widget.workId).firstOrNull;
        if (book != null) page = BookReviewsPage(book: book);
      case 'game':
        final game = provider.games.where((g) => g.id == widget.workId).firstOrNull;
        if (game != null) page = GameReviewsPage(game: game);
      default:
        final movie = provider.movies.where((m) => m.id == widget.workId).firstOrNull;
        if (movie != null) page = MovieReviewsPage(movie: movie);
    }
    if (page == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page!)).then((_) => _load());
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _total == 0) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final isOverlay = widget.isOverlay;
    final textColor = isOverlay ? Colors.white : colors.onSurface;
    final subColor = isOverlay ? Colors.white.withValues(alpha: 0.6) : colors.onSurface.withValues(alpha: 0.6);
    final faintColor = isOverlay ? Colors.white.withValues(alpha: 0.4) : colors.onSurface.withValues(alpha: 0.4);
    final cardColor = isOverlay ? Colors.white.withValues(alpha: 0.08) : colors.surfaceContainerHighest;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            Text(_title.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(width: 8),
            Text('共 {n} 条'.trf({'n': _total}), style: TextStyle(fontSize: 12, color: faintColor)),
          ]),
          const SizedBox(height: 12),
          // 影评列表（前 5 条）
          for (final review in _reviews) ...[
            _buildReviewItem(review, colors, textColor, subColor, faintColor, cardColor),
            const SizedBox(height: 10),
          ],
          // 查看更多
          if (_total > _previewCount)
            InkWell(
              onTap: _openAll,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('查看更多'.tr, style: TextStyle(fontSize: 13, color: subColor)),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: subColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(
    dynamic review,
    ColorScheme colors,
    Color textColor,
    Color subColor,
    Color faintColor,
    Color cardColor,
  ) {
    final int reviewType = review.reviewType as int;
    final String reviewer = review.reviewer as String;
    return InkWell(
      onTap: () => _openReviewDetail(review),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: reviewType == 1
                    ? (widget.isOverlay ? Colors.white.withValues(alpha: 0.15) : colors.surface)
                    : colors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                (review.typeText as String).tr,
                style: TextStyle(
                  fontSize: 10,
                  color: reviewType == 1
                      ? subColor
                      : colors.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 评论内容
            Text(
              review.content as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.5),
            ),
            const SizedBox(height: 8),
            // 评论人 + 日期
            Row(children: [
              if (reviewer.isNotEmpty)
                Expanded(
                  child: Text(
                    reviewer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: subColor),
                  ),
                )
              else
                const Spacer(),
              Text(
                _formatDate(review.createdAt as DateTime),
                style: TextStyle(fontSize: 11, color: faintColor),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
