import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/fade_in_local_image.dart';

/// 想看清单总览页面 - 汇总影视/书籍/游戏的想看记录
class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  // 筛选索引：0=全部, 1=影视, 2=阅读, 3=游戏
  int _filterIndex = 0;

  static const _filterDefs = <(String, String)>[
    ('全部', ''),
    ('影视', 'movie'),
    ('阅读', 'book'),
    ('游戏', 'game'),
  ];

  static const _typeLabel = <String, String>{
    'movie': '影视',
    'book': '阅读',
    'game': '游戏',
  };
  static const _typeIcon = <String, IconData>{
    'movie': Icons.movie_outlined,
    'book': Icons.menu_book_outlined,
    'game': Icons.sports_esports_outlined,
  };
  static const _typeColor = <String, Color>{
    'movie': Color(0xFF2563EB),
    'book': Color(0xFF16A34A),
    'game': Color(0xFFEA580C),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final userPrefs = UserPrefs();

    final movies = provider.movies.where((m) => !m.isDeleted).toList();
    final books = provider.books.where((b) => !b.isDeleted).toList();
    final games = provider.games.where((g) => !g.isDeleted).toList();

    final items = <_WatchlistEntry>[];
    if (userPrefs.showMovieTab) {
      for (final m in movies.where((m) => m.status == 'want_to_watch')) {
        items.add(_WatchlistEntry(
          title: m.title,
          imagePath: m.posterPath,
          type: 'movie',
          createdAt: m.createdAt,
          onTap: () => Navigator.pushNamed(context, '/movie-detail', arguments: m),
        ));
      }
    }
    if (userPrefs.showBookTab) {
      for (final b in books.where((b) => b.status == 'want_to_read')) {
        items.add(_WatchlistEntry(
          title: b.title,
          imagePath: b.coverPath,
          type: 'book',
          createdAt: b.createdAt,
          onTap: () => Navigator.pushNamed(context, '/book-detail', arguments: b),
        ));
      }
    }
    if (userPrefs.showGameTab) {
      for (final g in games.where((g) => g.status == 'want_to_play')) {
        items.add(_WatchlistEntry(
          title: g.title,
          imagePath: g.coverPath,
          type: 'game',
          createdAt: g.createdAt,
          onTap: () => Navigator.pushNamed(context, '/game-detail', arguments: g),
        ));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 可见筛选标签
    final visibleFilters = <(String, String)>[];
    visibleFilters.add(_filterDefs[0]);
    if (userPrefs.showMovieTab) visibleFilters.add(_filterDefs[1]);
    if (userPrefs.showBookTab) visibleFilters.add(_filterDefs[2]);
    if (userPrefs.showGameTab) visibleFilters.add(_filterDefs[3]);

    final (_, filterType) = visibleFilters[_filterIndex.clamp(0, visibleFilters.length - 1)];
    final filtered = filterType.isEmpty
        ? items
        : items.where((i) => i.type == filterType).toList();

    // 按类型分组（仅"全部"视图分组，单类型筛选不分组）
    final useGroups = filterType.isEmpty;
    final groups = <_WatchlistGroup>[];
    if (useGroups) {
      for (final type in const ['movie', 'book', 'game']) {
        final groupItems = filtered.where((i) => i.type == type).toList();
        if (groupItems.isNotEmpty) {
          groups.add(_WatchlistGroup(type: type, items: groupItems));
        }
      }
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('想看清单')),
      body: CustomScrollView(
        slivers: _buildSlivers(
          colors: colors,
          visibleFilters: visibleFilters,
          filtered: filtered,
          useGroups: useGroups,
          groups: groups,
        ),
      ),
    );
  }

  List<Widget> _buildSlivers({
    required ColorScheme colors,
    required List<(String, String)> visibleFilters,
    required List<_WatchlistEntry> filtered,
    required bool useGroups,
    required List<_WatchlistGroup> groups,
  }) {
    final slivers = <Widget>[];
    if (visibleFilters.length > 1) {
      slivers.add(SliverPersistentHeader(
        pinned: true,
        delegate: _StickyFilterDelegate(
          visibleFilters: visibleFilters,
          filterIndex: _filterIndex,
          count: filtered.length,
          onTap: (i) => setState(() => _filterIndex = i),
        ),
      ));
    }
    if (filtered.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmpty(colors),
      ));
    } else if (useGroups) {
      for (final g in groups) {
        slivers.addAll(_buildGroupSlivers(g, colors));
      }
    } else {
      slivers.add(SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildItemCard(colors, filtered[i]),
            childCount: filtered.length,
          ),
        ),
      ));
    }
    return slivers;
  }

  // 分组 slivers：小标题 + 卡片列表
  List<Widget> _buildGroupSlivers(_WatchlistGroup group, ColorScheme colors) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: _typeColor[group.type],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(_typeLabel[group.type]!,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.7))),
              const SizedBox(width: 6),
              Text('${group.items.length}',
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _buildItemCard(colors, group.items[i]),
            childCount: group.items.length,
          ),
        ),
      ),
    ];
  }

  // 单条卡片
  Widget _buildItemCard(ColorScheme colors, _WatchlistEntry item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Container(
              width: 52,
              height: 74,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: item.imagePath != null && item.imagePath!.isNotEmpty
                  ? FadeInLocalImage(
                      path: item.imagePath,
                      fit: BoxFit.cover,
                      errorWidget: Icon(Icons.image_outlined,
                          size: 18, color: colors.onSurface.withValues(alpha: 0.2)))
                  : Icon(Icons.image_outlined,
                      size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            const SizedBox(width: 10),
            // 左侧竖色条
            Container(
              width: 3,
              height: 50,
              decoration: BoxDecoration(
                color: _typeColor[item.type]!.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // 标题 + 类型
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                          height: 1.3)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(_typeIcon[item.type],
                          size: 11, color: _typeColor[item.type]),
                      const SizedBox(width: 3),
                      Text(_typeLabel[item.type]!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _typeColor[item.type])),
                    ],
                  ),
                ],
              ),
            ),
            // 右侧加入时间
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatRelative(item.createdAt),
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border,
              size: 48, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text('暂无想看记录',
              style: TextStyle(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  String _formatRelative(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}个月前';
    return '${(diff.inDays / 365).floor()}年前';
  }
}

// 吸顶筛选栏
class _StickyFilterDelegate extends SliverPersistentHeaderDelegate {
  final List<(String, String)> visibleFilters;
  final int filterIndex;
  final int count;
  final ValueChanged<int> onTap;

  _StickyFilterDelegate({
    required this.visibleFilters,
    required this.filterIndex,
    required this.count,
    required this.onTap,
  });

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surface,
      height: 52,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          for (int i = 0; i < visibleFilters.length; i++) ...[
            if (i != 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: i == filterIndex
                      ? colors.primary
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(visibleFilters[i].$1,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            i == filterIndex ? FontWeight.w600 : FontWeight.w400,
                        color: i == filterIndex
                            ? colors.onPrimary
                            : colors.onSurface.withValues(alpha: 0.6))),
              ),
            ),
          ],
          const Spacer(),
          Text('$count项',
              style: TextStyle(
                  fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyFilterDelegate oldDelegate) =>
      filterIndex != oldDelegate.filterIndex || count != oldDelegate.count;
}

class _WatchlistEntry {
  final String title;
  final String? imagePath;
  final String type; // movie / book / game
  final DateTime createdAt;
  final VoidCallback onTap;

  const _WatchlistEntry({
    required this.title,
    this.imagePath,
    required this.type,
    required this.createdAt,
    required this.onTap,
  });
}

class _WatchlistGroup {
  final String type;
  final List<_WatchlistEntry> items;
  const _WatchlistGroup({required this.type, required this.items});
}
