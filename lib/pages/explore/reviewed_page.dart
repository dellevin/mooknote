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
import '../../l10n/app_strings.dart';

enum _ItemType { movie, book, game }

enum _SortKey { created, actionDate, count, rating }

class _GenreGroup {
  final _ItemType type;
  final List<String> genres;
  final Color color;
  _GenreGroup(this.type, this.genres, this.color);
}

class _ReviewedItem {
  final String id;
  final String title;
  final String subtitle;
  final String? coverPath;
  final double? rating;
  final DateTime createdAt;
  final DateTime? actionDate; // 观看 / 读完 / 最近通关日期
  final int count; // 观看 / 阅读 / 游玩次数
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
    this.actionDate,
    this.count = 0,
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

  final UserPrefs _userPrefs = UserPrefs();
  // 排序：读取持久化偏好（默认创建时间降序，与原年份分组行为一致）
  late _SortKey _sortKey = _SortKey.values[_userPrefs.reviewedSortKey.clamp(0, _SortKey.values.length - 1)];
  late bool _sortAscending = _userPrefs.reviewedSortAscending;
  // 游戏最近通关日期（gameId -> 最近一条通关记录日期），异步加载
  Map<String, DateTime?> _gameCompletionDate = {};

  @override
  void initState() {
    super.initState();
    _loadGameCompletionDates();
  }

  Future<void> _loadGameCompletionDates() async {
    final map = await context.read<AppProvider>().getGameCompletionsMap();
    if (!mounted) return;
    setState(() {
      _gameCompletionDate = map.map((gameId, list) {
        final dates = list.where((c) => !c.isDeleted).map((c) => c.completionDate);
        return MapEntry(gameId, dates.isEmpty ? null : dates.reduce((a, b) => a.isAfter(b) ? a : b));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final allItems = _buildAllItems(provider);
        final years = _buildYearList(allItems);
        final filtered = _sortItems(_filterItems(allItems));

        return Scaffold(
          appBar: AppBar(
            title: Text('已阅'.tr),
            actions: [
              if (allItems.isNotEmpty) ...[
                _buildSortButton(context),
                _buildFilterButton(years, allItems, context),
                IconButton(
                  icon: Icon(UserPrefs().reviewedLayoutStyle == 1 ? Icons.view_list_outlined : Icons.grid_view_outlined, size: 20),
                  onPressed: () {
                    final newStyle = UserPrefs().reviewedLayoutStyle == 1 ? 0 : 1;
                    UserPrefs().setReviewedLayoutStyle(newStyle);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          body: Column(
            children: [
              // 统计概览（固定）
              _buildStatsHeader(allItems, filtered, context),
              // 激活的筛选条件提示条
              if (_activeFilterLabel != null) _buildActiveFilterBar(context),
              // 列表（可滚动）
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text('暂无已阅记录'.tr,
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
    // 非「创建时间」排序时全局平铺，避免排序结果被年份分组切块
    if (_sortKey != _SortKey.created) {
      return ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        children: [
          for (final item in filtered) _buildListItem(context, item),
        ],
      );
    }
    // 按录入年份分组（今年 / 去年 / yyyy年），同年内保持原排序
    final groups = <int, List<_ReviewedItem>>{};
    for (final item in filtered) {
      groups.putIfAbsent(item.createdAt.year, () => []).add(item);
    }
    final years = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final nowYear = DateTime.now().year;

    final children = <Widget>[];
    for (final y in years) {
      final label = y == nowYear ? '今年'.tr : (y == nowYear - 1 ? '去年'.tr : '$y年');
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(width: 8),
            Text(
              '{n}部'.trf({'n': groups[y]!.length}),
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ));
      children.addAll(groups[y]!.map((item) => _buildListItem(context, item)));
    }
    children.add(const SizedBox(height: 12));

    return ListView(
      padding: const EdgeInsets.only(top: 2, bottom: 12),
      children: children,
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
                child: Text(typeLabel.tr,
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
    final ratings = filtered.where((i) => i.rating != null).map((i) => i.rating!).toList();
    final avg = ratings.isEmpty
        ? '--'
        : (ratings.reduce((a, b) => a + b) / ratings.length).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.06), width: 0.7),
      ),
      child: Row(
        children: [
          _buildBigStat('${filtered.length}', '已阅'.tr, colors.primary, colors),
          const SizedBox(width: 18),
          _buildBigStat(avg, '均分'.tr, Colors.amber, colors),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          const Spacer(),
          Row(
            children: [
              _buildMiniType('影视'.tr, movieCount, Colors.blue, _ItemType.movie, colors),
              const SizedBox(width: 14),
              _buildMiniType('书籍'.tr, bookCount, Colors.teal, _ItemType.book, colors),
              const SizedBox(width: 14),
              _buildMiniType('游戏'.tr, gameCount, Colors.orange, _ItemType.game, colors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBigStat(String value, String label, Color accent, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.0, color: accent)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: colors.onSurface.withValues(alpha: 0.42))),
      ],
    );
  }

  /// 统计条右侧：点击即按类型筛选
  Widget _buildMiniType(String label, int count, Color color, _ItemType type, ColorScheme colors) {
    final selected = _selectedType == type;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _selectedType = selected ? null : type;
        // 切换类型后清空标签选择，避免筛出空列表
        _selectedGenre = null;
      }),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              height: 1.0,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? color : colors.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: selected ? 1 : 0.4),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: selected ? color : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── 筛选栏 ───────────────────────────────────────────────────────

  // ─── 筛选弹窗 ───────────────────────────────────────────────────────

  bool get _hasActiveFilter => _selectedYear != null || _selectedType != null || _selectedGenre != null;

  String? get _activeFilterLabel {
    if (!_hasActiveFilter) return null;
    final parts = <String>[];
    if (_selectedType != null) {
      parts.add(switch (_selectedType!) {
        _ItemType.movie => '影视'.tr,
        _ItemType.book => '书籍'.tr,
        _ItemType.game => '游戏'.tr,
      });
    }
    if (_selectedYear != null) parts.add('$_selectedYear');
    if (_selectedGenre != null) parts.add(_selectedGenre!);
    return parts.join(' · ');
  }

  Widget _buildFilterButton(List<int> years, List<_ReviewedItem> allItems, BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: '筛选'.tr,
      icon: Icon(
        _hasActiveFilter ? Icons.tune_rounded : Icons.tune_outlined,
        size: 20,
        color: _hasActiveFilter ? colors.primary : colors.onSurface.withValues(alpha: 0.7),
      ),
      onPressed: () => _showFilterSheet(years, allItems),
    );
  }

  Widget _buildActiveFilterBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
        child: GestureDetector(
          onTap: () => setState(() {
            _selectedYear = null;
            _selectedType = null;
            _selectedGenre = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt_rounded, size: 12, color: colors.primary),
                const SizedBox(width: 5),
                Text(_activeFilterLabel!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary)),
                const SizedBox(width: 4),
                Icon(Icons.close_rounded, size: 13, color: colors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 筛选弹窗当前模块：0 年份，1 影视，2 书籍，3 游戏
  int _filterTab = 0;

  void _showFilterSheet(List<int> years, List<_ReviewedItem> allItems) {
    final colors = Theme.of(context).colorScheme;
    final genreGroups = _buildGenreGroups(allItems);
    final typeOfTab = [null, _ItemType.movie, _ItemType.book, _ItemType.game];

    // 默认打开与当前筛选相关的模块
    if (_selectedGenre != null) {
      _filterTab = switch (_selectedType) {
        _ItemType.book => 2,
        _ItemType.game => 3,
        _ => 1,
      };
    } else if (_selectedType != null) {
      _filterTab = switch (_selectedType!) {
        _ItemType.movie => 1,
        _ItemType.book => 2,
        _ItemType.game => 3,
      };
    } else {
      _filterTab = 0;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            void choose(VoidCallback action) {
              setState(action);
              sheetSetState(() {});
            }

            final tabs = <(String, IconData)>[
              ('年份'.tr, Icons.calendar_today_outlined),
              ('影视'.tr, Icons.movie_outlined),
              ('书籍'.tr, Icons.menu_book_outlined),
              ('游戏'.tr, Icons.sports_esports_outlined),
            ];

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.62,
                child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Text('筛选'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface)),
                        const Spacer(),
                        if (_hasActiveFilter)
                          GestureDetector(
                            onTap: () => choose(() {
                              _selectedYear = null;
                              _selectedType = null;
                              _selectedGenre = null;
                            }),
                            child: Text('清除'.tr, style: TextStyle(fontSize: 13, color: colors.primary)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 顶部模块切换
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: i == tabs.length - 1 ? 0 : 8),
                              child: _buildSheetTab(
                                label: tabs[i].$1,
                                icon: tabs[i].$2,
                                active: _filterTab == i,
                                colors: colors,
                                onTap: () => sheetSetState(() => _filterTab = i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 当前模块内容：药丸自动换行，区域固定高度、超出纵滚
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        child: _buildSheetPillWrap(
                          colors: colors,
                          tab: _filterTab,
                          years: years,
                          group: _genreGroupFor(genreGroups, typeOfTab[_filterTab]),
                          onChoose: choose,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text('完成'.tr),
                      ),
                    ),
                  ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  _GenreGroup? _genreGroupFor(List<_GenreGroup> groups, _ItemType? type) {
    for (final g in groups) {
      if (g.type == type) return g;
    }
    return null;
  }

  Widget _buildSheetTab({
    required String label,
    required IconData icon,
    required bool active,
    required ColorScheme colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前模块的药丸：自动换行（一行排满换下一行）
  Widget _buildSheetPillWrap({
    required ColorScheme colors,
    required int tab,
    required List<int> years,
    required _GenreGroup? group,
    required void Function(VoidCallback) onChoose,
  }) {
    final pills = <Widget>[];

    if (tab == 0) {
      for (final year in years) {
        pills.add(_buildFilterChip(year, '$year', colors,
            isSelected: _selectedYear == year,
            onTap: () => onChoose(() => _selectedYear = _selectedYear == year ? null : year)));
      }
    } else if (group != null) {
      // 该类型的「全部」药丸：只按类型筛选，不限标签
      final allSelected = _selectedType == group.type && _selectedGenre == null;
      pills.add(_buildFilterChip(null, '全部'.tr, colors,
          color: group.color,
          isSelected: allSelected,
          onTap: () => onChoose(() {
                _selectedType = allSelected ? null : group.type;
                _selectedGenre = null;
              })));
      for (final genre in group.genres) {
        pills.add(_buildFilterChip(genre, genre, colors,
            color: group.color,
            isSelected: _selectedType == group.type && _selectedGenre == genre,
            onTap: () => onChoose(() {
                  // 已选中则取消；否则同时锁定类型 + 标签
                  if (_selectedType == group.type && _selectedGenre == genre) {
                    _selectedType = null;
                    _selectedGenre = null;
                  } else {
                    _selectedType = group.type;
                    _selectedGenre = genre;
                  }
                })));
      }
    }

    if (pills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Center(
          child: Text('暂无选项'.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: pills,
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
    groups.add(_GenreGroup(_ItemType.movie, movieGenres.toList()..sort(), Colors.blue));
    groups.add(_GenreGroup(_ItemType.book, bookGenres.toList()..sort(), Colors.teal));
    groups.add(_GenreGroup(_ItemType.game, gameGenres.toList()..sort(), Colors.orange));
    return groups;
  }

  Widget _buildFilterChip(dynamic key, String label, ColorScheme colors, {Color? color, required bool isSelected, required VoidCallback onTap}) {
    final chipColor = color ?? colors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.55))),
      ),
    );
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
          actionDate: m.watchDate,
          count: m.watchCount,
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
          actionDate: b.finishDate,
          count: b.readCount,
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
          actionDate: _gameCompletionDate[g.id],
          count: g.playCount,
          year: g.releaseDate?.year,
          genres: g.genres,
          type: _ItemType.game,
          original: g,
        ));
      }
    }

    return items;
  }

  // ─── 排序 ─────────────────────────────────────────────────────────

  static const _sortLabels = <_SortKey, String>{
    _SortKey.created: '创建时间',
    _SortKey.actionDate: '完成时间',
    _SortKey.count: '次数',
    _SortKey.rating: '我的评分',
  };

  List<_ReviewedItem> _sortItems(List<_ReviewedItem> items) {
    Comparable? keyOf(_ReviewedItem i) => switch (_sortKey) {
      _SortKey.created => i.createdAt,
      _SortKey.actionDate => i.actionDate,
      _SortKey.count => i.count,
      _SortKey.rating => i.rating,
    };
    items.sort((a, b) {
      final ka = keyOf(a);
      final kb = keyOf(b);
      // 空值（未填完成时间 / 未评分）始终排在最后，与升降序无关
      if (ka == null && kb == null) return 0;
      if (ka == null) return 1;
      if (kb == null) return -1;
      final r = ka.compareTo(kb);
      if (r != 0) return _sortAscending ? r : -r;
      // 同值回退到创建时间，保证顺序稳定
      return b.createdAt.compareTo(a.createdAt);
    });
    return items;
  }

  Widget _buildSortButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _sortKey != _SortKey.created || _sortAscending;
    return IconButton(
      tooltip: '排序'.tr,
      icon: Icon(
        _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        size: 20,
        color: active ? colors.primary : colors.onSurface.withValues(alpha: 0.7),
      ),
      onPressed: _showSortSheet,
    );
  }

  void _showSortSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            void choose(_SortKey key) {
              _userPrefs.setReviewedSortKey(key.index);
              setState(() => _sortKey = key);
              sheetSetState(() {});
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      children: [
                        Text('排序'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface)),
                        const Spacer(),
                        // 升降序切换
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final next = !_sortAscending;
                            _userPrefs.setReviewedSortAscending(next);
                            setState(() => _sortAscending = next);
                            sheetSetState(() {});
                          },
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(
                              _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 16, color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _sortAscending ? '升序'.tr : '降序'.tr,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.primary),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  for (final key in _SortKey.values)
                    InkWell(
                      onTap: () => choose(key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Text(
                              _sortLabels[key]!.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _sortKey == key ? FontWeight.w700 : FontWeight.w500,
                                color: _sortKey == key ? colors.primary : colors.onSurface.withValues(alpha: 0.75),
                              ),
                            ),
                            const Spacer(),
                            if (_sortKey == key) Icon(Icons.check_rounded, size: 20, color: colors.primary),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            final page = switch (item.type) {
              _ItemType.movie => MovieDetailPage(movie: item.original as Movie),
              _ItemType.book => BookDetailPage(book: item.original as Book),
              _ItemType.game => GameDetailPage(game: item.original as Game),
            };
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.06), width: 0.7),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 类型色条
                Container(
                  width: 3,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(2)),
                ),
                // 封面
                Container(
                  width: 64,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
                    height: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        const SizedBox(height: 4),
                        if (item.subtitle.isNotEmpty)
                          Text(item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
                        const Spacer(),
                        Row(
                          children: [
                            if (item.rating != null)
                              AnimatedStarRating(rating: item.rating!, starSize: 11, showNumber: true)
                            else
                              Text('未评分'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25))),
                            const Spacer(),
                            if (item.year != null)
                              Text('${item.year}',
                                  style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
