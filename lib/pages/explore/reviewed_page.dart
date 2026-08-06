import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/animated_star_rating.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';

enum _ItemType { movie, book, game }

class _ReviewedItem {
  final String id;
  final String title;
  final String subtitle;
  final String? coverPath;
  final double? rating;
  final DateTime createdAt;
  final int? year; // 上映/出版/发售年份
  final List<String> genres;
  final _ItemType type;
  final dynamic original;

  _ReviewedItem({
    required this.id,
    required this.title,
    required this.subtitle,
    this.coverPath,
    this.rating,
    required this.createdAt,
    this.year,
    required this.genres,
    required this.type,
    required this.original,
  });
}

class ReviewedPage extends StatefulWidget {
  const ReviewedPage({super.key});

  @override
  State<ReviewedPage> createState() => _ReviewedPageState();
}

class _ReviewedPageState extends State<ReviewedPage> {
  int? _selectedYear; // null = 全部
  _ItemType? _selectedType; // null = 全部
  String? _selectedGenre; // null = 全部

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final allItems = _buildAllItems(provider);
        final years = _buildYearList(allItems);
        final filtered = _filterItems(allItems);

        return Scaffold(
          appBar: AppBar(title: const Text('已阅')),
          body: CustomScrollView(
            slivers: [
              // 统计概览
              SliverToBoxAdapter(child: _buildStatsHeader(allItems, filtered, context)),
              // 筛选栏
              if (allItems.isNotEmpty)
                SliverToBoxAdapter(child: _buildFilterBar(years, allItems, context)),
              // 列表
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text('暂无已阅记录',
                        style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.3))),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildItem(context, filtered[index]),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── 统计概览 ─────────────────────────────────────────────────────

  Widget _buildStatsHeader(List<_ReviewedItem> all, List<_ReviewedItem> filtered, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final movieCount = all.where((i) => i.type == _ItemType.movie).length;
    final bookCount = all.where((i) => i.type == _ItemType.book).length;
    final gameCount = all.where((i) => i.type == _ItemType.game).length;
    final avgRating = filtered.isNotEmpty
        ? filtered.where((i) => i.rating != null).map((i) => i.rating!).toList()
        : <double>[];
    final avg = avgRating.isNotEmpty
        ? (avgRating.reduce((a, b) => a + b) / avgRating.length).toStringAsFixed(1)
        : '--';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 总数 + 平均评分
          Row(
            children: [
              _buildStatCard('已阅总数', '${filtered.length}', Icons.done_all, colors.primary, colors),
              const SizedBox(width: 12),
              _buildStatCard('平均评分', avg, Icons.star_outline, Colors.amber, colors),
            ],
          ),
          const SizedBox(height: 12),
          // 分类统计
          Row(
            children: [
              Expanded(
                child: _buildCategoryChip('影视', movieCount, Colors.blue, _ItemType.movie),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryChip('书籍', bookCount, Colors.teal, _ItemType.book),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCategoryChip('游戏', gameCount, Colors.orange, _ItemType.game),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color iconColor, ColorScheme colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, int count, Color color, _ItemType type) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = selected ? null : type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: color.withValues(alpha: 0.3), width: 1) : null,
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: selected ? color : colors.onSurface)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: selected ? color : colors.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }

  // ─── 筛选栏 ───────────────────────────────────────────────────────

  Widget _buildFilterBar(List<int> years, List<_ReviewedItem> allItems, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final genres = _buildGenreList(allItems);

    return Column(
      children: [
        // 类型筛选
        if (genres.isNotEmpty)
          Container(
            height: 32,
            margin: const EdgeInsets.only(top: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(null, '全部', colors, isSelected: _selectedGenre == null, onTap: () => setState(() => _selectedGenre = null)),
                const SizedBox(width: 6),
                for (final genre in genres) ...[
                  _buildFilterChip(genre, genre, colors, isSelected: _selectedGenre == genre, onTap: () => setState(() => _selectedGenre = _selectedGenre == genre ? null : genre)),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        // 年份筛选
        if (years.isNotEmpty)
          Container(
            height: 32,
            margin: const EdgeInsets.only(top: 6),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(null, '全部', colors, isSelected: _selectedYear == null, onTap: () => setState(() => _selectedYear = null)),
                const SizedBox(width: 6),
                for (final year in years) ...[
                  _buildFilterChip(year, '$year', colors, isSelected: _selectedYear == year, onTap: () => setState(() => _selectedYear = _selectedYear == year ? null : year)),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(dynamic key, String label, ColorScheme colors, {required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.55))),
        ),
      ),
    );
  }

  List<String> _buildGenreList(List<_ReviewedItem> items) {
    final genres = <String>{};
    for (final i in items) {
      genres.addAll(i.genres);
    }
    return genres.toList()..sort();
  }

  // ─── 数据构建 ─────────────────────────────────────────────────────

  List<_ReviewedItem> _buildAllItems(AppProvider provider) {
    final items = <_ReviewedItem>[];

    for (final m in provider.movies) {
      if (!m.isDeleted && m.status == 'watched') {
        items.add(_ReviewedItem(
          id: m.id,
          title: m.title,
          subtitle: m.directors.isNotEmpty ? m.directors.join(' / ') : '',
          coverPath: m.posterPath,
          rating: m.rating,
          createdAt: m.createdAt,
          year: m.releaseDate?.year,
          genres: m.genres,
          type: _ItemType.movie,
          original: m,
        ));
      }
    }

    for (final b in provider.books) {
      if (!b.isDeleted && b.status == 'read') {
        items.add(_ReviewedItem(
          id: b.id,
          title: b.title,
          subtitle: b.authors.isNotEmpty ? b.authors.join(' / ') : '',
          coverPath: b.coverPath,
          rating: b.rating,
          createdAt: b.createdAt,
          year: b.publishDate?.year,
          genres: b.genres,
          type: _ItemType.book,
          original: b,
        ));
      }
    }

    for (final g in provider.games) {
      if (!g.isDeleted && g.status == 'completed') {
        items.add(_ReviewedItem(
          id: g.id,
          title: g.title,
          subtitle: g.developer.isNotEmpty ? g.developer.join(' / ') : (g.platforms.isNotEmpty ? g.platforms.join(' / ') : ''),
          coverPath: g.coverPath,
          rating: g.rating,
          createdAt: g.createdAt,
          year: g.releaseDate?.year,
          genres: g.genres,
          type: _ItemType.game,
          original: g,
        ));
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<int> _buildYearList(List<_ReviewedItem> items) {
    final years = items.map((i) => i.year).whereType<int>().toSet().toList()..sort((a, b) => b.compareTo(a));
    return years;
  }

  List<_ReviewedItem> _filterItems(List<_ReviewedItem> items) {
    return items.where((i) {
      if (_selectedYear != null && i.year != _selectedYear) return false;
      if (_selectedType != null && i.type != _selectedType) return false;
      if (_selectedGenre != null && !i.genres.contains(_selectedGenre)) return false;
      return true;
    }).toList();
  }

  // ─── 列表项 ───────────────────────────────────────────────────────

  Widget _buildItem(BuildContext context, _ReviewedItem item) {
    final colors = Theme.of(context).colorScheme;
    final typeColor = switch (item.type) {
      _ItemType.movie => Colors.blue,
      _ItemType.book => Colors.teal,
      _ItemType.game => Colors.orange,
    };
    final typeLabel = switch (item.type) {
      _ItemType.movie => '影视',
      _ItemType.book => '书籍',
      _ItemType.game => '游戏',
    };

    return InkWell(
      onTap: () {
        final page = switch (item.type) {
          _ItemType.movie => MovieDetailPage(movie: item.original as Movie),
          _ItemType.book => BookDetailPage(book: item.original as Book),
          _ItemType.game => GameDetailPage(game: item.original as Game),
        };
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60,
                height: 80,
                child: item.coverPath != null && item.coverPath!.isNotEmpty
                    ? FadeInLocalImage(
                        path: item.coverPath,
                        fit: BoxFit.cover,
                        placeholder: _buildPlaceholder(item.type, colors),
                        errorWidget: _buildPlaceholder(item.type, colors),
                      )
                    : _buildPlaceholder(item.type, colors),
              ),
            ),
            const SizedBox(width: 12),
            // 信息
            Expanded(
              child: SizedBox(
                height: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)),
                    const SizedBox(height: 4),
                    // 副标题
                    if (item.subtitle.isNotEmpty)
                      Text(item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.45))),
                    const Spacer(),
                    // 底部：评分 + 类型标签 + 年份
                    Row(
                      children: [
                        if (item.rating != null)
                          AnimatedStarRating(rating: item.rating!, starSize: 11, showNumber: true)
                        else
                          Text('未评分', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25))),
                        const Spacer(),
                        if (item.year != null)
                          Text('${item.year}',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurface.withValues(alpha: 0.3))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(typeLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: typeColor)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(_ItemType type, ColorScheme colors) {
    final icon = switch (type) {
      _ItemType.movie => Icons.movie_outlined,
      _ItemType.book => Icons.menu_book_outlined,
      _ItemType.game => Icons.sports_esports_outlined,
    };
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
          child: Icon(icon,
              size: 22, color: colors.onSurface.withValues(alpha: 0.25))),
    );
  }
}
