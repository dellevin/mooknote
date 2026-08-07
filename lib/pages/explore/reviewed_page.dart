import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/animated_star_rating.dart';
import '../../utils/user_prefs.dart';
import '../../utils/responsive.dart';
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

class _GenreGroup {
  final _ItemType type;
  final List<String> genres;
  final Color color;
  _GenreGroup(this.type, this.genres, this.color);
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
          appBar: AppBar(
            title: const Text('已阅'),
            actions: [
              if (allItems.isNotEmpty)
                IconButton(
                  icon: Icon(UserPrefs().reviewedLayoutStyle == 1 ? Icons.view_list_outlined : Icons.grid_view_outlined, size: 20),
                  onPressed: () {
                    final newStyle = UserPrefs().reviewedLayoutStyle == 1 ? 0 : 1;
                    UserPrefs().setReviewedLayoutStyle(newStyle);
                    setState(() {});
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              // 统计概览（固定）
              _buildStatsHeader(allItems, filtered, context),
              // 筛选栏（固定）
              if (allItems.isNotEmpty)
                _buildFilterBar(years, allItems, context),
              // 列表（可滚动）
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('暂无已阅记录',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.3))),
                      )
                    : UserPrefs().reviewedLayoutStyle == 1
                        ? _buildGridView(context, filtered)
                        : _buildListView(context, filtered),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 列表视图 ─────────────────────────────────────────────────────

  Widget _buildListView(BuildContext context, List<_ReviewedItem> filtered) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildListItem(context, filtered[index]),
    );
  }

  // ─── 网格视图 ─────────────────────────────────────────────────────

  Widget _buildGridView(BuildContext context, List<_ReviewedItem> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildGridItem(context, filtered[index]),
        );
      },
    );
  }

  Widget _buildGridItem(BuildContext context, _ReviewedItem item) {
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

    return GestureDetector(
      onTap: () {
        final page = switch (item.type) {
          _ItemType.movie => MovieDetailPage(movie: item.original as Movie),
          _ItemType.book => BookDetailPage(book: item.original as Book),
          _ItemType.game => GameDetailPage(game: item.original as Game),
        };
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colors.surfaceContainerHighest,
              ),
              clipBehavior: Clip.antiAlias,
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
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
          const SizedBox(height: 3),
          Row(
            children: [
              if (item.rating != null)
                AnimatedStarRating(rating: item.rating!, starSize: 10, showNumber: true)
              else
                const SizedBox(height: 14),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(typeLabel,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: typeColor)),
              ),
            ],
          ),
        ],
      ),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // 第一行：总数 + 评分
          Row(
            children: [
              _buildStatItem('${filtered.length}', '已阅', colors.primary, Icons.done_all_rounded, colors),
              _buildStatDivider(colors),
              _buildStatItem(avg, '均分', Colors.amber, Icons.star_rounded, colors),
              _buildStatDivider(colors),
              // 分类计数
              _buildMiniCategory('影视', movieCount, Colors.blue, _ItemType.movie, colors),
              const SizedBox(width: 12),
              _buildMiniCategory('书籍', bookCount, Colors.teal, _ItemType.book, colors),
              const SizedBox(width: 12),
              _buildMiniCategory('游戏', gameCount, Colors.orange, _ItemType.game, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color, IconData icon, ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
      ],
    );
  }

  Widget _buildStatDivider(ColorScheme colors) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: colors.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildMiniCategory(String label, int count, Color color, _ItemType type, ColorScheme colors) {
    final selected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = selected ? null : type),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? color : color.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(width: 1),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: selected ? color : colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  // ─── 筛选栏 ───────────────────────────────────────────────────────

  Widget _buildFilterBar(List<int> years, List<_ReviewedItem> allItems, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final genreGroups = _buildGenreGroups(allItems);
    if (genreGroups.isEmpty && years.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 各分类类型筛选，每个分类一行
          for (final group in genreGroups)
            Container(
              height: 30,
              margin: EdgeInsets.fromLTRB(0, genreGroups.indexOf(group) == 0 ? 8 : 4, 0, 0),
              child: _FadeEdgeScrollView(
                colors: colors,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildTypeTag(group.type, colors),
                    const SizedBox(width: 5),
                    for (final genre in group.genres) ...[
                      _buildFilterChip(genre, genre, colors,
                          color: group.color,
                          isSelected: _selectedGenre == genre,
                          onTap: () => setState(() => _selectedGenre = _selectedGenre == genre ? null : genre)),
                      const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
            ),
          // 年份筛选
          if (years.isNotEmpty)
            Container(
              height: 30,
              margin: const EdgeInsets.only(top: 4),
              child: _FadeEdgeScrollView(
                colors: colors,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildTypeTag(null, colors),
                    const SizedBox(width: 5),
                    for (final year in years) ...[
                      _buildFilterChip(year, '$year', colors, isSelected: _selectedYear == year, onTap: () => setState(() => _selectedYear = _selectedYear == year ? null : year)),
                      const SizedBox(width: 5),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeTag(_ItemType? type, ColorScheme colors) {
    final (label, color) = switch (type) {
      _ItemType.movie => ('影视', Colors.blue),
      _ItemType.book => ('书籍', Colors.teal),
      _ItemType.game => ('游戏', Colors.orange),
      null => ('年份', colors.onSurface.withValues(alpha: 0.5)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }

  Widget _buildFilterChip(dynamic key, String label, ColorScheme colors, {Color? color, required bool isSelected, required VoidCallback onTap}) {
    final chipColor = color ?? colors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
        ),
      ),
    );
  }

  List<_GenreGroup> _buildGenreGroups(List<_ReviewedItem> items) {
    final movieGenres = <String>{};
    final bookGenres = <String>{};
    final gameGenres = <String>{};
    for (final i in items) {
      switch (i.type) {
        case _ItemType.movie:
          movieGenres.addAll(i.genres);
        case _ItemType.book:
          bookGenres.addAll(i.genres);
        case _ItemType.game:
          gameGenres.addAll(i.genres);
      }
    }
    final groups = <_GenreGroup>[];
    if (movieGenres.isNotEmpty) groups.add(_GenreGroup(_ItemType.movie, movieGenres.toList()..sort(), Colors.blue));
    if (bookGenres.isNotEmpty) groups.add(_GenreGroup(_ItemType.book, bookGenres.toList()..sort(), Colors.teal));
    if (gameGenres.isNotEmpty) groups.add(_GenreGroup(_ItemType.game, gameGenres.toList()..sort(), Colors.orange));
    return groups;
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

  Widget _buildListItem(BuildContext context, _ReviewedItem item) {
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

/// 横向 ListView 左右渐变遮罩（用 Stack + 透明渐变覆盖层）
class _FadeEdgeScrollView extends StatelessWidget {
  final ColorScheme colors;
  final Widget child;
  const _FadeEdgeScrollView({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    final fadeColor = colors.surface;
    return Stack(
      children: [
        child,
        // 左渐变
        Positioned(
          left: 0, top: 0, bottom: 0, width: 16,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
        // 右渐变
        Positioned(
          right: 0, top: 0, bottom: 0, width: 16,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
