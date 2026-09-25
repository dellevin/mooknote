import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
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

    final filterIdx = _filterIndex.clamp(0, visibleFilters.length - 1);
    final (_, filterType) = visibleFilters[filterIdx];
    final filtered = filterType.isEmpty
        ? items
        : items.where((i) => i.type == filterType).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('想看清单'.tr),
        actions: [
          if (visibleFilters.length > 1)
            PopupMenuButton<int>(
              tooltip: '筛选'.tr,
              initialValue: filterIdx,
              onSelected: (i) => setState(() => _filterIndex = i),
              itemBuilder: (ctx) => [
                for (int i = 0; i < visibleFilters.length; i++)
                  PopupMenuItem<int>(
                    value: i,
                    child: Row(
                      children: [
                        Icon(
                          i == filterIdx ? Icons.check : null,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(visibleFilters[i].$1.tr),
                      ],
                    ),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${visibleFilters[filterIdx].$1.tr} · ${filtered.length}',
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7)),
                    ),
                    Icon(Icons.arrow_drop_down, size: 18, color: colors.onSurface.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: filtered.isEmpty
          ? _buildEmpty(colors)
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 14,
                childAspectRatio: 0.55,
              ),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) => _buildGridItem(colors, filtered[i]),
            ),
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

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border,
              size: 48, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text('暂无想看记录'.tr,
              style: TextStyle(
                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
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
