import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../pages/explore/encounter_page.dart';
import '../pages/explore/stroll_page.dart';
import '../pages/explore/media_calendar_page.dart';
import '../pages/explore/person_list_page.dart';
import '../pages/markdown_reader/md_reader_tab_page.dart';
import '../pages/epub_reader/epub_library_page.dart';
import '../pages/settings/tag_management_page.dart';
import '../pages/movies/movie_detail_page.dart';
import '../pages/movies/movie_form_page.dart';
import '../pages/book/book_detail_page.dart';
import '../pages/book/book_form_page.dart';
import '../pages/note/note_detail_page.dart';
import '../pages/note/note_form_page.dart';
import '../pages/game/game_detail_page.dart';
import '../pages/profile/settings_page.dart';
import '../models/data_models.dart';
import 'fade_in_local_image.dart';

/// 自定义侧边栏
class CustomDrawer extends StatefulWidget {
  final bool embedded;
  const CustomDrawer({super.key, this.embedded = false});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _version = '0.1.5';

  // 热力图缓存
  int _cachedMoviesHash = 0;
  int _cachedBooksHash = 0;
  int _cachedNotesHash = 0;
  int _cachedGamesHash = 0;
  Map<DateTime, int>? _cachedDailyCounts;
  int? _cachedMaxCount;

  // 最近添加缓存
  List<_RecentItem>? _cachedRecentItems;

  /// 用列表长度 + 首末元素ID生成轻量哈希，避免 identical() 在 Provider 返回新实例时永远失败
  int _listHash<T>(List<T> list) {
    if (list.isEmpty) return 0;
    final first = list.first;
    final last = list.last;
    return Object.hash(list.length, first, last);
  }

  bool _isHeatmapCacheValid(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    return _cachedDailyCounts != null &&
        _cachedMoviesHash == _listHash(movies) &&
        _cachedBooksHash == _listHash(books) &&
        _cachedNotesHash == _listHash(notes) &&
        _cachedGamesHash == _listHash(games);
  }

  bool _isRecentCacheValid(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    return _cachedRecentItems != null &&
        _cachedMoviesHash == _listHash(movies) &&
        _cachedBooksHash == _listHash(books) &&
        _cachedNotesHash == _listHash(notes) &&
        _cachedGamesHash == _listHash(games);
  }

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = packageInfo.version);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();
    final showHeatmap = userPrefs.showSidebarHeatmap;
    final showRecent = userPrefs.showSidebarRecent;
    final showQuickActions = userPrefs.showSidebarQuickActions;
    final showTools = userPrefs.showSidebarEncounter ||
        userPrefs.showSidebarStroll ||
        userPrefs.showSidebarCalendar ||
        userPrefs.showSidebarPerson ||
        userPrefs.showSidebarTags ||
        userPrefs.showSidebarMdReader ||
        userPrefs.showSidebarEpub;

    final content = SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(context),
            if (showQuickActions) ...[
              const SizedBox(height: 12),
              _buildQuickActions(context),
            ],
            if (showHeatmap) ...[
              const SizedBox(height: 16),
              _buildCalendarSection(context),
            ],
            if (showRecent) ...[
              const SizedBox(height: 16),
              _buildRecentSection(context),
            ],
            if (showTools) ...[
              const SizedBox(height: 16),
              _buildToolsCard(context),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('v$_version', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.2))),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      if (!widget.embedded) Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                    },
                    child: Icon(Icons.settings_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    return Drawer(
      backgroundColor: colors.surfaceContainerHigh,
      child: content,
    );
  }

  // ─── 头像 + 统计卡片 ─────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        final userPrefs = UserPrefs();
        final nickname = userPrefs.nickname;
        final motto = userPrefs.motto;
        final avatarPath = userPrefs.avatarPath;
        final movieCount = provider.movies.where((m) => !m.isDeleted).length;
        final bookCount = provider.books.length;
        final noteCount = provider.notes.length;
        final gameCount = provider.games.where((g) => !g.isDeleted).length;

        // 根据功能开关过滤显示的统计项
        final statItems = <(IconData, int, String, Color)>[];
        if (userPrefs.showMovieTab) statItems.add((Icons.movie_outlined, movieCount, '观影', const Color(0xFF2563EB)));
        if (userPrefs.showBookTab) statItems.add((Icons.menu_book_outlined, bookCount, '阅读', const Color(0xFF16A34A)));
        if (userPrefs.showNoteTab) statItems.add((Icons.note_outlined, noteCount, '笔记', const Color(0xFF9333EA)));
        if (userPrefs.showGameTab) statItems.add((Icons.sports_esports_outlined, gameCount, '游戏', const Color(0xFFEA580C)));

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceContainerHighest,
                      border: Border.all(color: colors.outlineVariant, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarPath != null && avatarPath.isNotEmpty
                        ? FadeInLocalImage(path: avatarPath, fit: BoxFit.cover,
                            errorWidget: Icon(Icons.person_outline, size: 22, color: colors.onSurface.withValues(alpha: 0.3)))
                        : Icon(Icons.person_outline, size: 22, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nickname, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text(motto, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                ],
              ),
              if (statItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: statItems.map((item) {
                    final (icon, count, label, color) = item;
                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_formatCount(count), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                              const SizedBox(width: 3),
                              Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 快捷操作 ──────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();

    final actions = <(IconData, String, Color, VoidCallback)>[];
    if (userPrefs.showMovieTab) actions.add((
      Icons.add_photo_alternate_outlined, '影视', const Color(0xFF2563EB),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieFormPage())); },
    ));
    if (userPrefs.showBookTab) actions.add((
      Icons.menu_book_outlined, '阅读', const Color(0xFF16A34A),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormPage())); },
    ));
    if (userPrefs.showNoteTab) actions.add((
      Icons.edit_note_outlined, '笔记', const Color(0xFF9333EA),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteFormPage())); },
    ));

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) {
          final (icon, label, color, onTap) = action;
          return Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 功能入口卡片 ────────────────────────────────────────────────────

  Widget _buildToolsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();

    final exploreItems = <(IconData, String, Widget)>[];
    if (userPrefs.showSidebarEncounter) exploreItems.add((Icons.favorite_border, '统计', const EncounterPage()));
    if (userPrefs.showSidebarStroll) exploreItems.add((Icons.explore_outlined, '漫步', const StrollPage()));
    if (userPrefs.showSidebarCalendar) exploreItems.add((Icons.calendar_month_outlined, '书影日历', const MediaCalendarPage()));

    final toolItems = <(IconData, String, Widget)>[];
    if (userPrefs.showSidebarPerson) toolItems.add((Icons.people_outline, '角色信息', const PersonListPage()));
    if (userPrefs.showSidebarTags) toolItems.add((Icons.label_outline, '标签管理', const TagManagementPage()));
    if (userPrefs.showSidebarMdReader) toolItems.add((Icons.description_outlined, 'MD阅读', const MdReaderTabPage()));
    if (userPrefs.showSidebarEpub) toolItems.add((Icons.auto_stories_outlined, 'EPUB阅读', const EpubLibraryPage()));

    if (exploreItems.isEmpty && toolItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exploreItems.isNotEmpty) ...[
          _buildGroupTitle('探索', colors),
          const SizedBox(height: 6),
          _buildGroupCard(context, exploreItems),
        ],
        if (toolItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGroupTitle('工具', colors),
          const SizedBox(height: 6),
          _buildGroupCard(context, toolItems),
        ],
      ],
    );
  }

  Widget _buildGroupTitle(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.3), letterSpacing: 1)),
    );
  }

  Widget _buildGroupCard(BuildContext context, List<(IconData, String, Widget)> items) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(height: 1, indent: 52, endIndent: 20, color: colors.outlineVariant);
          }
          final idx = i ~/ 2;
          final (icon, title, page) = items[idx];
          return _buildToolItem(icon, title, () {
            if (!widget.embedded) Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          }, topRounded: idx == 0, bottomRounded: idx == items.length - 1);
        }),
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String title, VoidCallback onTap, {bool topRounded = false, bool bottomRounded = false, bool enabled = true}) {
    final colors = Theme.of(context).colorScheme;
    final effectiveOnTap = enabled ? onTap : null;
    final iconOpacity = enabled ? 0.7 : 0.25;
    final textOpacity = enabled ? 1.0 : 0.35;
    return InkWell(
      onTap: effectiveOnTap,
      borderRadius: BorderRadius.only(
        topLeft: topRounded ? const Radius.circular(16) : Radius.zero,
        topRight: topRounded ? const Radius.circular(16) : Radius.zero,
        bottomLeft: bottomRounded ? const Radius.circular(16) : Radius.zero,
        bottomRight: bottomRounded ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: iconOpacity)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: textOpacity)))),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  // ─── 热力图 ──────────────────────────────────────────────────────────

  // ─── 热力图缓存计算 ───

  (int, Map<DateTime, int>) _computeDailyCounts(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    if (_isHeatmapCacheValid(movies, books, notes, games)) {
      return (_cachedMaxCount!, _cachedDailyCounts!);
    }

    final dailyCounts = <DateTime, int>{};
    for (final movie in movies.where((m) => !m.isDeleted)) {
      final date = DateTime(movie.createdAt.year, movie.createdAt.month, movie.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    for (final book in books.where((b) => !b.isDeleted)) {
      final date = DateTime(book.createdAt.year, book.createdAt.month, book.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    for (final note in notes.where((n) => !n.isDeleted)) {
      final date = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    for (final game in games.where((g) => !g.isDeleted)) {
      final date = DateTime(game.createdAt.year, game.createdAt.month, game.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    int maxCount = 0;
    for (final c in dailyCounts.values) {
      if (c > maxCount) maxCount = c;
    }
    if (maxCount == 0) maxCount = 1;

    _cachedMoviesHash = _listHash(movies);
    _cachedBooksHash = _listHash(books);
    _cachedNotesHash = _listHash(notes);
    _cachedGamesHash = _listHash(games);
    _cachedDailyCounts = dailyCounts;
    _cachedMaxCount = maxCount;
    return (maxCount, dailyCounts);
  }

  List<_RecentItem> _computeRecentItems(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    if (_isRecentCacheValid(movies, books, notes, games)) {
      return _cachedRecentItems!;
    }

    final items = <_RecentItem>[];
    for (final m in movies.where((m) => !m.isDeleted)) {
      items.add(_RecentItem(type: 'movie', title: m.title, date: m.createdAt, data: m));
    }
    for (final b in books.where((b) => !b.isDeleted)) {
      items.add(_RecentItem(type: 'book', title: b.title, date: b.createdAt, data: b));
    }
    for (final n in notes.where((n) => !n.isDeleted)) {
      items.add(_RecentItem(type: 'note', title: n.title.isNotEmpty ? n.title : '随手记', date: n.createdAt, data: n));
    }
    for (final g in games.where((g) => !g.isDeleted)) {
      items.add(_RecentItem(type: 'game', title: g.title, date: g.createdAt, data: g));
    }
    items.sort((a, b) => b.date.compareTo(a.date));

    _cachedMoviesHash = _listHash(movies);
    _cachedBooksHash = _listHash(books);
    _cachedNotesHash = _listHash(notes);
    _cachedGamesHash = _listHash(games);
    _cachedRecentItems = items;
    return items;
  }

  Widget _buildCalendarSection(BuildContext context) {
    final movies = context.select<AppProvider, List<Movie>>((p) => p.movies);
    final books = context.select<AppProvider, List<Book>>((p) => p.books);
    final notes = context.select<AppProvider, List<Note>>((p) => p.notes);
    final games = context.select<AppProvider, List<Game>>((p) => p.games);
    final colors = Theme.of(context).colorScheme;

    final (maxCount, dailyCounts) = _computeDailyCounts(movies, books, notes, games);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysSinceSunday = today.weekday % 7;
        final lastSunday = today.subtract(Duration(days: daysSinceSunday));

        const totalWeeks = 20;
        const weekDays = 7;
        const cellGap = 1.5;
        // 可用宽度 = drawer宽度 - margin(16*2) - container padding(18*2)
        final drawerWidth = widget.embedded ? 260.0 : MediaQuery.sizeOf(context).width;
        final availableWidth = drawerWidth - 32 - 36;
        final cellSize = ((availableWidth - (totalWeeks - 1) * cellGap) / totalWeeks).clamp(6.0, 10.0);

        final cells = List.generate(weekDays, (_) => List.generate(totalWeeks, (_) => 0));
        for (int week = 0; week < totalWeeks; week++) {
          for (int day = 0; day < weekDays; day++) {
            final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7 + (6 - day)));
            cells[day][week] = dailyCounts[date] ?? 0;
          }
        }

        // 连续打卡天数
        int streak = 0;
        for (int i = 0; i < 365; i++) {
          final date = today.subtract(Duration(days: i));
          if (dailyCounts[date] != null && dailyCounts[date]! > 0) {
            streak++;
          } else {
            break;
          }
        }

        final monthLabels = <int, String>{};
        for (int week = 0; week < totalWeeks; week++) {
          final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7));
          final key = date.month;
          if (!monthLabels.containsKey(key) || date.day <= 7) {
            monthLabels[week] = '${date.month}月';
          }
        }
        final sortedWeeks = monthLabels.keys.toList()..sort();
        final keepWeeks = {sortedWeeks.first, sortedWeeks[sortedWeeks.length ~/ 2], sortedWeeks.last};

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text('热力图', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
                  const Spacer(),
                  if (streak > 0) ...[
                    Icon(Icons.local_fire_department, size: 14, color: const Color(0xFFFF6D00)),
                    const SizedBox(width: 3),
                    Text('连续 $streak 天', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFFF6D00))),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: List.generate(totalWeeks, (week) {
                          final label = keepWeeks.contains(week) ? monthLabels[week] : null;
                          return SizedBox(
                            width: week < totalWeeks - 1 ? cellSize + cellGap : cellSize,
                            child: label != null ? Text(label, style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))) : null,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ...List.generate(weekDays, (day) => Row(
                      children: List.generate(totalWeeks, (week) {
                        final count = cells[day][week];
                        final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7 + (6 - day)));
                        return GestureDetector(
                          onTap: count > 0 ? () => _showDayDetail(context, date, dailyCounts[date] ?? 0, movies, books, notes, games) : null,
                          child: Tooltip(
                            message: '${date.month}月${date.day}日${count > 0 ? ' · $count条' : ''}',
                            child: Container(
                              width: cellSize, height: cellSize,
                              margin: EdgeInsets.only(right: week < totalWeeks - 1 ? cellGap : 0, bottom: day < weekDays - 1 ? cellGap : 0),
                              decoration: BoxDecoration(
                                color: _heatmapColor(count, maxCount),
                                borderRadius: BorderRadius.circular(2),
                                border: count > 0 ? null : Border.all(color: colors.outlineVariant.withValues(alpha: 0.3), width: 0.5),
                              ),
                            ),
                          ),
                        );
                      }),
                    )),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('少', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
                  const SizedBox(width: 3),
                  _legendCell(const Color(0xFFF0F0F0)),
                  _legendCell(const Color(0xFFC8E6C9)),
                  _legendCell(const Color(0xFF66BB6A)),
                  _legendCell(const Color(0xFF2E7D32)),
                  _legendCell(const Color(0xFF1B5E20)),
                  const SizedBox(width: 3),
                  Text('多', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
                ],
              ),
            ],
          ),
        );
  }

  void _showDayDetail(BuildContext context, DateTime date, int count, List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    final colors = Theme.of(context).colorScheme;
    final dayMovies = movies.where((m) => !m.isDeleted && DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day) == date).toList();
    final dayBooks = books.where((b) => !b.isDeleted && DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day) == date).toList();
    final dayNotes = notes.where((n) => !n.isDeleted && DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day) == date).toList();
    final dayGames = games.where((g) => !g.isDeleted && DateTime(g.createdAt.year, g.createdAt.month, g.createdAt.day) == date).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text('${date.month}月${date.day}日', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(width: 8),
                  Text('$count条记录', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (dayMovies.isNotEmpty) ...[
                    for (final m in dayMovies) _dayDetailItem(ctx, Icons.movie_outlined, m.title, colors.primary),
                  ],
                  if (dayBooks.isNotEmpty) ...[
                    for (final b in dayBooks) _dayDetailItem(ctx, Icons.menu_book_outlined, b.title, const Color(0xFF16A34A)),
                  ],
                  if (dayNotes.isNotEmpty) ...[
                    for (final n in dayNotes) _dayDetailItem(ctx, Icons.note_outlined, n.title.isNotEmpty ? n.title : '随手记', const Color(0xFF9333EA)),
                  ],
                  if (dayGames.isNotEmpty) ...[
                    for (final g in dayGames) _dayDetailItem(ctx, Icons.sports_esports_outlined, g.title, const Color(0xFFEA580C)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayDetailItem(BuildContext ctx, IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Color _heatmapColor(int count, int maxCount) {
    if (count == 0) return const Color(0xFFF0F0F0);
    final ratio = count / maxCount;
    if (ratio <= 0.25) return const Color(0xFFC8E6C9);
    if (ratio <= 0.50) return const Color(0xFF66BB6A);
    if (ratio <= 0.75) return const Color(0xFF2E7D32);
    return const Color(0xFF1B5E20);
  }

  Widget _legendCell(Color color) {
    return Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
  }

  // ─── 最近添加 ────────────────────────────────────────────────────────

  Widget _buildRecentSection(BuildContext context) {
    final movies = context.select<AppProvider, List<Movie>>((p) => p.movies);
    final books = context.select<AppProvider, List<Book>>((p) => p.books);
    final notes = context.select<AppProvider, List<Note>>((p) => p.notes);
    final games = context.select<AppProvider, List<Game>>((p) => p.games);
    final colors = Theme.of(context).colorScheme;
    final recent = _computeRecentItems(movies, books, notes, games);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text('最近添加', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 14),
          ...recent.take(6).map((item) => InkWell(
            onTap: () => _openRecentItem(context, item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: _typeColor(item.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      item.type == 'movie' ? Icons.movie_outlined : item.type == 'book' ? Icons.menu_book_outlined : item.type == 'game' ? Icons.sports_esports_outlined : Icons.note_outlined,
                      size: 12, color: _typeColor(item.type),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75))),
                  ),
                  const SizedBox(width: 8),
                  Text(_recentTimeAgo(item.date), style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.25))),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _openRecentItem(BuildContext context, _RecentItem item) {
    if (!widget.embedded) Navigator.pop(context);
    switch (item.type) {
      case 'movie':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
      case 'book':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
      case 'note':
        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: item.data as Note)));
      case 'game':
        Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailPage(game: item.data as Game)));
    }
  }

  String _recentTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}年前';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}月前';
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    return '刚刚';
  }

  Color _typeColor(String type) {
    return switch (type) {
      'movie' => const Color(0xFF2563EB),
      'book' => const Color(0xFF16A34A),
      'note' => const Color(0xFF9333EA),
      'game' => const Color(0xFFEA580C),
      _ => const Color(0xFF6B7280),
    };
  }
}

class _RecentItem {
  final String type;
  final String title;
  final DateTime date;
  final dynamic data;
  _RecentItem({required this.type, required this.title, required this.date, required this.data});
}
