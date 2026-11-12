import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/fade_in_local_image.dart';

/// 想看清单总览页面 - 汇总影视/书籍/游戏的想看记录
class WatchlistPage extends StatefulWidget {
  const WatchlistPage({super.key});

  @override
  State<WatchlistPage> createState() => _WatchlistPageState();
}

class _WatchlistPageState extends State<WatchlistPage> {
  // 筛选索引：0=全部, 1=影视, 2=阅读, 3=游戏（按可见筛选列表下标）
  int _filterIndex = 0;
  // 0 卡片网格，1 列表
  late int _layoutStyle = UserPrefs().watchlistLayoutStyle;

  bool _isSearching = false;
  String _keyword = '';
  final TextEditingController _searchCtrl = TextEditingController();

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
  static const _typeColor = <String, Color>{
    'movie': Color(0xFF2563EB),
    'book': Color(0xFF16A34A),
    'game': Color(0xFFEA580C),
  };
  static const _typeIcon = <String, IconData>{
    'movie': Icons.movie_outlined,
    'book': Icons.menu_book_outlined,
    'game': Icons.sports_esports_outlined,
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_WatchlistEntry> _buildItems(AppProvider provider, UserPrefs userPrefs) {
    final movies = provider.movies.where((m) => !m.isDeleted);
    final books = provider.books.where((b) => !b.isDeleted);
    final games = provider.games.where((g) => !g.isDeleted);

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
    return items;
  }

  /// 底部弹出类型筛选
  Future<void> _showFilterSheet(
      List<(String, String)> visibleFilters, List<_WatchlistEntry> items) {
    final colors = Theme.of(context).colorScheme;
    return appModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '筛选'.tr,
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < visibleFilters.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 56,
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      _buildFilterOption(
                        sheetContext,
                        visibleFilters[i],
                        i == _filterIndex,
                        visibleFilters[i].$2.isEmpty
                            ? items.length
                            : items.where((e) => e.type == visibleFilters[i].$2).length,
                        colors,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(
    BuildContext sheetContext,
    (String, String) filter,
    bool selected,
    int count,
    ColorScheme colors,
  ) {
    final type = filter.$2;
    final accent = type.isEmpty ? colors.primary : _typeColor[type]!;
    return InkWell(
      onTap: () {
        Navigator.pop(sheetContext);
        setState(() => _filterIndex = _filterDefs.indexOf(filter));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                type.isEmpty ? Icons.apps_rounded : _typeIcon[type],
                size: 17,
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                filter.$1.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: colors.onSurface,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(width: 10),
            if (selected) Icon(Icons.check_rounded, size: 19, color: colors.primary),
          ],
        ),
      ),
    );
  }

  /// 底部弹出显示方式切换
  Future<void> _showLayoutSheet() async {
    final colors = Theme.of(context).colorScheme;
    final options = <(int, IconData, String)>[
      (0, Icons.grid_view_rounded, '卡片'.tr),
      (1, Icons.view_agenda_rounded, '列表'.tr),
    ];
    await appModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '显示方式'.tr,
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 56,
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      InkWell(
                        onTap: () async {
                          final navigator = Navigator.of(sheetContext);
                          await UserPrefs().setWatchlistLayoutStyle(options[i].$1);
                          if (!mounted) return;
                          setState(() => _layoutStyle = options[i].$1);
                          navigator.pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(options[i].$2, size: 17, color: colors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  options[i].$3,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight:
                                        _layoutStyle == options[i].$1 ? FontWeight.w600 : FontWeight.w400,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                              if (_layoutStyle == options[i].$1)
                                Icon(Icons.check_rounded, size: 19, color: colors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final userPrefs = UserPrefs();

    final items = _buildItems(provider, userPrefs);

    // 可见筛选标签
    final visibleFilters = <(String, String)>[];
    visibleFilters.add(_filterDefs[0]);
    if (userPrefs.showMovieTab) visibleFilters.add(_filterDefs[1]);
    if (userPrefs.showBookTab) visibleFilters.add(_filterDefs[2]);
    if (userPrefs.showGameTab) visibleFilters.add(_filterDefs[3]);

    final filterIdx = _filterIndex.clamp(0, visibleFilters.length - 1);
    final (_, filterType) = visibleFilters[filterIdx];
    final hasTypeFilter = filterType.isNotEmpty;
    var filtered =
        filterType.isEmpty ? items : items.where((i) => i.type == filterType).toList();
    if (_keyword.isNotEmpty) {
      final kw = _keyword.toLowerCase();
      filtered = filtered.where((i) => i.title.toLowerCase().contains(kw)).toList();
    }

    final searchWidth = (MediaQuery.of(context).size.width - 132).clamp(180.0, 320.0);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('想看清单'.tr),
        actions: [
          if (items.isNotEmpty) ...[
            // 搜索按钮向左展开为药丸输入框（AnimatedSize 右对齐生长）
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerRight,
              child: _isSearching
                  ? Container(
                      width: searchWidth,
                      height: 40,
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search,
                              size: 19, color: colors.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: true,
                              cursorColor: colors.primary,
                              style: TextStyle(color: colors.onSurface, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '搜索想看的影视、书籍或游戏'.tr,
                                hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurface.withValues(alpha: 0.35)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                filled: false,
                              ),
                              onChanged: (v) => setState(() => _keyword = v),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              FocusManager.instance.primaryFocus?.unfocus();
                              setState(() {
                                _keyword = '';
                                _isSearching = false;
                              });
                            },
                            child: Icon(Icons.close,
                                size: 17, color: colors.onSurface.withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: '搜索'.tr,
                      onPressed: () => setState(() => _isSearching = true),
                    ),
            ),
            // 搜索展开时隐藏筛选与显示方式按钮，避免窄屏溢出
            if (!_isSearching) ...[
              IconButton(
                tooltip: '筛选'.tr,
                icon: Icon(
                  hasTypeFilter ? Icons.tune_rounded : Icons.tune_outlined,
                  size: 20,
                  color: hasTypeFilter
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.7),
                ),
                onPressed: () => _showFilterSheet(visibleFilters, items),
              ),
              IconButton(
                tooltip: '显示方式'.tr,
                icon: const Icon(Icons.more_vert, size: 22),
                onPressed: _showLayoutSheet,
              ),
              const SizedBox(width: 4),
            ],
          ],
        ],
      ),
      body: items.isEmpty
          ? _buildEmpty(colors, searching: false)
          : filtered.isEmpty
              ? _buildEmpty(colors, searching: true)
              : _layoutStyle == 0
                  ? _buildGrid(colors, filtered)
                  : _buildList(colors, filtered),
    );
  }

  Widget _buildGrid(ColorScheme colors, List<_WatchlistEntry> filtered) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 14,
        childAspectRatio: 0.55,
      ),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _buildGridItem(colors, filtered[i]),
    );
  }

  Widget _buildList(ColorScheme colors, List<_WatchlistEntry> filtered) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildListItem(colors, filtered[i]),
    );
  }

  // 海报方格单条：海报 + 左上角类型角标 + 标题
  Widget _buildGridItem(ColorScheme colors, _WatchlistEntry item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.imagePath != null && item.imagePath!.isNotEmpty
                      ? FadeInLocalImage(
                          path: item.imagePath,
                          fit: BoxFit.cover,
                          errorWidget: Icon(Icons.image_outlined,
                              size: 22, color: colors.onSurface.withValues(alpha: 0.2)))
                      : Icon(Icons.image_outlined,
                          size: 22, color: colors.onSurface.withValues(alpha: 0.2)),
                ),
                // 类型角标
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: _typeColor[item.type],
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      _typeLabel[item.type]!.tr,
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colors.onSurface,
                height: 1.3),
          ),
        ],
      ),
    );
  }

  // 列表单条：封面 + 标题/类型/加入日期
  Widget _buildListItem(ColorScheme colors, _WatchlistEntry item) {
    final accent = _typeColor[item.type]!;
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  color: colors.surfaceContainerHighest,
                  child: item.imagePath != null && item.imagePath!.isNotEmpty
                      ? FadeInLocalImage(
                          path: item.imagePath,
                          fit: BoxFit.cover,
                          errorWidget: Icon(Icons.image_outlined,
                              size: 18, color: colors.onSurface.withValues(alpha: 0.2)))
                      : Icon(Icons.image_outlined,
                          size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _typeLabel[item.type]!.tr,
                          style: TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w600, color: accent),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(item.createdAt),
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildEmpty(ColorScheme colors, {required bool searching}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(searching ? Icons.search_off_rounded : Icons.bookmark_border,
              size: 48, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            searching ? '未找到匹配的内容'.tr : '暂无想看记录'.tr,
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }
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
