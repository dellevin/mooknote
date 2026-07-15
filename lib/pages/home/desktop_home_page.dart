import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/fade_in_local_image.dart';

/// 桌面端主页 - 多维度数据分析概览
class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  int _cloudTabIndex = 0;
  bool get _showMovies => UserPrefs().showMovieTab;
  bool get _showBooks => UserPrefs().showBookTab;
  bool get _showNotes => UserPrefs().showNoteTab;
  bool get _showGames => UserPrefs().showGameTab;

  static const _movieColor = Color(0xFF2563EB);
  static const _bookColor = Color(0xFF16A34A);
  static const _noteColor = Color(0xFF9333EA);
  static const _gameColor = Color(0xFFEA580C);

  // 缓存
  List<Movie>? _cachedMovies;
  List<Book>? _cachedBooks;
  List<Note>? _cachedNotes;
  List<Game>? _cachedGames;
  List<Movie>? _fm;
  List<Book>? _fb;
  List<Note>? _fn;
  List<Game>? _fg;

  void _updateCache(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    if (!identical(movies, _cachedMovies) || !identical(books, _cachedBooks) ||
        !identical(notes, _cachedNotes) || !identical(games, _cachedGames)) {
      _cachedMovies = movies;
      _cachedBooks = books;
      _cachedNotes = notes;
      _cachedGames = games;
      _fm = movies.where((m) => !m.isDeleted).toList();
      _fb = books.where((b) => !b.isDeleted).toList();
      _fn = notes.where((n) => !n.isDeleted).toList();
      _fg = games.where((g) => !g.isDeleted).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final movies = context.select<AppProvider, List<Movie>>((p) => p.movies);
    final books = context.select<AppProvider, List<Book>>((p) => p.books);
    final notes = context.select<AppProvider, List<Note>>((p) => p.notes);
    final games = context.select<AppProvider, List<Game>>((p) => p.games);
    _updateCache(movies, books, notes, games);
    final fm = _fm!, fb = _fb!, fn = _fn!, fg = _fg!;

    // 预计算总览数据
    final completed = fm.where((m) => m.status == 'watched').length +
        fb.where((b) => b.status == 'read').length +
        fg.where((g) => g.status == 'completed').length;
    final totalWithStatus = fm.length + fb.length + fg.length;
    final completionRate = totalWithStatus > 0 ? completed / totalWithStatus : 0.0;
    final now = DateTime.now();
    final thisMonth = fm.where((m) => m.createdAt.year == now.year && m.createdAt.month == now.month).length +
        fb.where((b) => b.createdAt.year == now.year && b.createdAt.month == now.month).length +
        fn.where((n) => n.createdAt.year == now.year && n.createdAt.month == now.month).length +
        fg.where((g) => g.createdAt.year == now.year && g.createdAt.month == now.month).length;
    final allRatings = <double>[];
    for (final m in fm) { if (m.rating != null && m.rating! > 0) allRatings.add(m.rating!); }
    for (final b in fb) { if (b.rating != null && b.rating! > 0) allRatings.add(b.rating!); }
    for (final g in fg) { if (g.rating != null && g.rating! > 0) allRatings.add(g.rating!); }
    final avgRating = allRatings.isNotEmpty ? allRatings.reduce((a, b) => a + b) / allRatings.length : 0.0;

    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        // 顶部：问候 + 模块卡片
        _buildHeroSection(fm, fb, fn, fg, completionRate, thisMonth, avgRating, colors),
        const SizedBox(height: 20),
        // 双列：年度趋势 + 状态分布
        _buildTwoCol(
          _buildYearlyTrend(fm, fb, fn, fg, colors),
          _buildAllStatus(fm, fb, fg, colors),
        ),
        const SizedBox(height: 20),
        // 双列：类型雷达 + 习惯洞察
        _buildTwoCol(
          _buildGenreRadar(fm, fb, fg, colors),
          _buildHabitsInsight(fm, fb, fn, fg, colors),
        ),
        const SizedBox(height: 20),
        // 双列：导演TOP5 + 作者TOP5
        _buildTwoCol(
          _showMovies ? _buildDirectorTop5(fm, colors) : const SizedBox.shrink(),
          _showBooks ? _buildAuthorTop5(fb, colors) : const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        // 高分之最（全宽）
        _buildTopRated(fm, fb, fg, colors),
        const SizedBox(height: 20),
        // 双列：评分分布 + 星期分布
        _buildTwoCol(
          _buildRatingDistribution(fm, fb, fg, colors),
          _buildWeekdayDistribution(fm, fb, fn, fg, colors),
        ),
        const SizedBox(height: 20),
        // 双列：累计增长 + 趣味统计
        _buildTwoCol(
          _buildCumulativeGrowth(fm, fb, fn, fg, colors),
          _buildFunStats(fm, fb, fn, fg, colors),
        ),
        const SizedBox(height: 20),
        // 标签词云（全宽）
        _buildTagCloud(fm, fb, fn, fg, colors),
        const SizedBox(height: 60),
      ],
    );
  }

  // ─── 双列布局辅助 ──────────────────────────────────────────────────────

  Widget _buildTwoCol(Widget left, Widget right) {
    if (left is SizedBox && right is SizedBox) return const SizedBox.shrink();
    if (left is SizedBox) return right;
    if (right is SizedBox) return left;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 20),
          Expanded(child: right),
        ],
      ),
    );
  }

  // ─── 顶部英雄区域 ──────────────────────────────────────────────────────

  Widget _buildHeroSection(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg,
      double completionRate, int thisMonth, double avgRating, ColorScheme colors) {
    final hour = DateTime.now().hour;
    final greeting = hour < 6 ? '夜深了' : hour < 12 ? '早上好' : hour < 18 ? '下午好' : '晚上好';
    final nickname = UserPrefs().nickname;
    final firstUse = UserPrefs().firstUseDate;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(firstUse.year, firstUse.month, firstUse.day))
        .inDays + 1;

    // 模块卡片数据
    final items = <_ModuleData>[];
    if (_showMovies) {
      final watched = fm.where((m) => m.status == 'watched').length;
      items.add(_ModuleData(Icons.movie_outlined, '影视', fm.length, '已看$watched', _movieColor, 0));
    }
    if (_showBooks) {
      final read = fb.where((b) => b.status == 'read').length;
      items.add(_ModuleData(Icons.menu_book_outlined, '阅读', fb.length, '已读$read', _bookColor, 1));
    }
    if (_showNotes) {
      final words = fn.fold<int>(0, (sum, n) => sum + n.content.length);
      final ws = words >= 10000 ? '${(words / 10000).toStringAsFixed(1)}万' : '$words';
      items.add(_ModuleData(Icons.note_outlined, '笔记', fn.length, '$ws字', _noteColor, 2));
    }
    if (_showGames) {
      final completed = fg.where((g) => g.status == 'completed').length;
      items.add(_ModuleData(Icons.sports_esports_outlined, '游戏', fg.length, '通关$completed', _gameColor, 3));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 问候
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting，$nickname', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: colors.onSurface)),
                const SizedBox(height: 4),
                Text('${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}  ·  相遇第 $days 天', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
              ],
            ),
            const Spacer(),
            // 右侧快捷指标
            _buildQuickChip('完成率', completionRate > 0 ? '${(completionRate * 100).toStringAsFixed(0)}%' : '-', Icons.check_circle_outline, colors.primary, colors),
            const SizedBox(width: 8),
            _buildQuickChip('本月', '$thisMonth', Icons.trending_up, const Color(0xFF66BB6A), colors),
            const SizedBox(width: 8),
            _buildQuickChip('均分', avgRating > 0 ? avgRating.toStringAsFixed(1) : '-', Icons.star_outline, const Color(0xFFFFB800), colors),
          ],
        ),
        const SizedBox(height: 20),
        // 模块卡片
        Row(
          children: items.asMap().entries.map((e) {
            final d = e.value;
            return Expanded(
              child: GestureDetector(
                onTap: () => context.read<AppProvider>().setMainTabIndex(d.tabIndex),
                child: Container(
                  margin: EdgeInsets.only(right: e.key < items.length - 1 ? 12 : 0),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [d.color.withValues(alpha: 0.12), d.color.withValues(alpha: 0.04)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: d.color.withValues(alpha: 0.15), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: d.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                          child: Icon(d.icon, size: 15, color: d.color),
                        ),
                        const SizedBox(width: 8),
                        Text(d.label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                      ]),
                      const SizedBox(height: 14),
                      Text('${d.count}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: d.color, height: 1)),
                      const SizedBox(height: 4),
                      Text(d.sub, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickChip(String label, String value, IconData icon, Color color, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  // ─── 合并状态分布 ──────────────────────────────────────────────────────

  Widget _buildAllStatus(List<Movie> fm, List<Book> fb, List<Game> fg, ColorScheme colors) {
    return _buildCard(
        title: '状态分布',
        colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showMovies) ...[
            _buildModuleStatusChip(Icons.movie_outlined, '影视', _movieColor, colors),
            const SizedBox(height: 10),
            ..._buildStatusRows(fm, (m) => m.status, {'已看': 'watched', '在看': 'watching', '想看': 'want_to_watch'}, _movieColor, colors),
            if (_showBooks || _showGames) ...[const SizedBox(height: 16), Divider(height: 1, color: colors.outlineVariant), const SizedBox(height: 16)],
          ],
          if (_showBooks) ...[
            _buildModuleStatusChip(Icons.menu_book_outlined, '阅读', _bookColor, colors),
            const SizedBox(height: 10),
            ..._buildStatusRows(fb, (b) => b.status, {'已读': 'read', '在读': 'reading', '想读': 'want_to_read'}, _bookColor, colors),
            if (_showGames) ...[const SizedBox(height: 16), Divider(height: 1, color: colors.outlineVariant), const SizedBox(height: 16)],
          ],
          if (_showGames) ...[
            _buildModuleStatusChip(Icons.sports_esports_outlined, '游戏', _gameColor, colors),
            const SizedBox(height: 10),
            ..._buildStatusRows(fg, (g) => g.status, {'通关': 'completed', '在玩': 'playing', '想玩': 'want_to_play', '弃游': 'abandoned'}, _gameColor, colors),
          ],
        ],
      ),
    );
  }

  Widget _buildModuleStatusChip(IconData icon, String label, Color color, ColorScheme colors) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ],
    );
  }

  List<Widget> _buildStatusRows(List items, String Function(dynamic) getStatus, Map<String, String> labels, Color barColor, ColorScheme colors) {
    final total = items.length;
    return labels.entries.map((e) {
      final count = items.where((i) => getStatus(i) == e.value).length;
      final pct = total > 0 ? count / total : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(width: 48, child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: pct, backgroundColor: colors.outlineVariant, color: barColor, minHeight: 5),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(width: 4),
                Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
              ],
            )),
          ],
        ),
      );
    }).toList();
  }

  // ─── 习惯洞察 ─────────────────────────────────────────────────────────

  Widget _buildHabitsInsight(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg, ColorScheme colors) {
    final allDates = [
      ...fm.map((m) => m.createdAt), ...fb.map((b) => b.createdAt),
      ...fn.map((n) => n.createdAt), ...fg.map((g) => g.createdAt),
    ]..sort();
    if (allDates.isEmpty) return const SizedBox.shrink();

    final monthCounts = <int, int>{};
    for (final d in allDates) { monthCounts[d.month] = (monthCounts[d.month] ?? 0) + 1; }
    final busiestMonth = monthCounts.entries.isEmpty ? 1 : monthCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    const monthNames = ['', '一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];

    final firstDate = allDates.first;
    final totalMonths = math.max(1, (DateTime.now().year - firstDate.year) * 12 + DateTime.now().month - firstDate.month + 1);
    final avgPerMonth = (allDates.length / totalMonths).toStringAsFixed(1);

    final watchedDates = fm.where((m) => m.status == 'watched').map((m) => m.createdAt).toList()..sort();
    final readDates = fb.where((b) => b.status == 'read').map((b) => b.createdAt).toList()..sort();
    final playedDates = fg.where((g) => g.status == 'completed').map((g) => g.createdAt).toList()..sort();

    return _buildCard(
      title: '习惯洞察',
      colors: colors,
      child: Column(
        children: [
          _buildInsightRow(Icons.calendar_month_outlined, '最活跃月份', monthNames[busiestMonth], colors),
          Divider(height: 1, color: colors.outlineVariant),
          _buildInsightRow(Icons.speed_outlined, '记录频率', '每月 $avgPerMonth 条', colors),
          if (watchedDates.length >= 2) ...[
            Divider(height: 1, color: colors.outlineVariant),
            _buildInsightRow(Icons.movie_outlined, '观影节奏', '${_calcAvgGap(watchedDates).toStringAsFixed(0)} 天/部', colors),
          ],
          if (readDates.length >= 2) ...[
            Divider(height: 1, color: colors.outlineVariant),
            _buildInsightRow(Icons.menu_book_outlined, '阅读节奏', '${_calcAvgGap(readDates).toStringAsFixed(0)} 天/本', colors),
          ],
          if (playedDates.length >= 2) ...[
            Divider(height: 1, color: colors.outlineVariant),
            _buildInsightRow(Icons.sports_esports_outlined, '游戏节奏', '${_calcAvgGap(playedDates).toStringAsFixed(0)} 天/款', colors),
          ],
        ],
      ),
    );
  }

  double _calcAvgGap(List<DateTime> dates) {
    if (dates.length < 2) return 0;
    final sorted = dates.toList()..sort();
    double totalGap = 0;
    for (int i = 1; i < sorted.length; i++) { totalGap += sorted[i].difference(sorted[i - 1]).inDays.toDouble(); }
    return totalGap / (sorted.length - 1);
  }

  Widget _buildInsightRow(IconData icon, String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ],
      ),
    );
  }

  // ─── 类型偏好雷达图 ────────────────────────────────────────────────────

  Widget _buildGenreRadar(List<Movie> fm, List<Book> fb, List<Game> fg, ColorScheme colors) {
    final movieGenres = <String, int>{};
    final bookGenres = <String, int>{};
    final gameGenres = <String, int>{};
    for (final m in fm) { for (final g in m.genres) { movieGenres[g] = (movieGenres[g] ?? 0) + 1; } }
    for (final b in fb) { for (final g in b.genres) { bookGenres[g] = (bookGenres[g] ?? 0) + 1; } }
    for (final g in fg) { for (final ge in g.genres) { gameGenres[ge] = (gameGenres[ge] ?? 0) + 1; } }

    final allGenres = <String, int>{};
    allGenres.addAll(movieGenres);
    for (final e in bookGenres.entries) { allGenres[e.key] = (allGenres[e.key] ?? 0) + e.value; }
    for (final e in gameGenres.entries) { allGenres[e.key] = (allGenres[e.key] ?? 0) + e.value; }
    final sorted = allGenres.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top6 = sorted.take(6).toList();
    if (top6.length < 3) return const SizedBox.shrink();

    final maxVal = top6.first.value.toDouble();
    final dataSets = <RadarDataSet>[];
    if (movieGenres.isNotEmpty) dataSets.add(RadarDataSet(dataEntries: top6.map((e) => RadarEntry(value: (movieGenres[e.key] ?? 0) / math.max(1, maxVal))).toList(), borderColor: _movieColor, fillColor: _movieColor.withValues(alpha: 0.12), borderWidth: 2));
    if (bookGenres.isNotEmpty) dataSets.add(RadarDataSet(dataEntries: top6.map((e) => RadarEntry(value: (bookGenres[e.key] ?? 0) / math.max(1, maxVal))).toList(), borderColor: _bookColor, fillColor: _bookColor.withValues(alpha: 0.12), borderWidth: 2));
    if (gameGenres.isNotEmpty) dataSets.add(RadarDataSet(dataEntries: top6.map((e) => RadarEntry(value: (gameGenres[e.key] ?? 0) / math.max(1, maxVal))).toList(), borderColor: _gameColor, fillColor: _gameColor.withValues(alpha: 0.12), borderWidth: 2));

    return _buildCard(
      title: '类型偏好',
      colors: colors,
      child: Column(
        children: [
          SizedBox(height: 200, child: RadarChart(RadarChartData(
            radarShape: RadarShape.polygon,
            dataSets: dataSets,
            radarBorderData: BorderSide(color: colors.outlineVariant, width: 0.5),
            gridBorderData: BorderSide(color: colors.outlineVariant, width: 0.5),
            tickBorderData: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3), width: 0.5),
            ticksTextStyle: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3)),
            titleTextStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
            titlePositionPercentageOffset: 0.15,
            getTitle: (index, angle) => RadarChartTitle(text: top6[index].key),
            tickCount: 3,
          ))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (movieGenres.isNotEmpty) ...[_buildLegend(_movieColor, '影视', colors), const SizedBox(width: 14)],
            if (bookGenres.isNotEmpty) ...[_buildLegend(_bookColor, '书籍', colors), const SizedBox(width: 14)],
            if (gameGenres.isNotEmpty) _buildLegend(_gameColor, '游戏', colors),
          ]),
        ],
      ),
    );
  }

  // ─── 导演/作者 TOP 5 ──────────────────────────────────────────────────

  Widget _buildDirectorTop5(List<Movie> fm, ColorScheme colors) {
    final counts = <String, int>{};
    for (final m in fm) { for (final d in m.directors) { counts[d] = (counts[d] ?? 0) + 1; } }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();
    final maxVal = top5.first.value.toDouble();
    return _buildCard(title: '导演 TOP 5', colors: colors, child: Column(children: top5.map((e) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        SizedBox(width: 56, child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: e.value / maxVal, backgroundColor: colors.outlineVariant, color: _movieColor, minHeight: 4))),
        const SizedBox(width: 8),
        Text('${e.value}部', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ]));
    }).toList()));
  }

  Widget _buildAuthorTop5(List<Book> fb, ColorScheme colors) {
    final counts = <String, int>{};
    for (final b in fb) { for (final a in b.authors) { counts[a] = (counts[a] ?? 0) + 1; } }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();
    final maxVal = top5.first.value.toDouble();
    return _buildCard(title: '作者 TOP 5', colors: colors, child: Column(children: top5.map((e) {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        SizedBox(width: 56, child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: e.value / maxVal, backgroundColor: colors.outlineVariant, color: _bookColor, minHeight: 4))),
        const SizedBox(width: 8),
        Text('${e.value}本', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ]));
    }).toList()));
  }

  // ─── 高分之最 ──────────────────────────────────────────────────────────

  Widget _buildTopRated(List<Movie> fm, List<Book> fb, List<Game> fg, ColorScheme colors) {
    final ratedMovies = fm.where((m) => m.rating != null && m.rating! > 0).toList()..sort((a, b) => b.rating!.compareTo(a.rating!));
    final ratedBooks = fb.where((b) => b.rating != null && b.rating! > 0).toList()..sort((a, b) => b.rating!.compareTo(a.rating!));
    final ratedGames = fg.where((g) => g.rating != null && g.rating! > 0).toList()..sort((a, b) => b.rating!.compareTo(a.rating!));
    if (ratedMovies.isEmpty && ratedBooks.isEmpty && ratedGames.isEmpty) return const SizedBox.shrink();

    // 三列并排
    return _buildCard(
      title: '高分之最',
      colors: colors,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ratedMovies.isNotEmpty) Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionChip(Icons.movie_outlined, '影视', _movieColor, colors),
              const SizedBox(height: 8),
              ...ratedMovies.take(5).map((m) => _buildTopRatedItem(m.title, m.rating!, m.posterPath, colors)),
            ],
          )),
          if (ratedMovies.isNotEmpty && (ratedBooks.isNotEmpty || ratedGames.isNotEmpty))
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: VerticalDivider(width: 1, color: colors.outlineVariant)),
          if (ratedBooks.isNotEmpty) Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionChip(Icons.menu_book_outlined, '书籍', _bookColor, colors),
              const SizedBox(height: 8),
              ...ratedBooks.take(5).map((b) => _buildTopRatedItem(b.title, b.rating!, b.coverPath, colors)),
            ],
          )),
          if (ratedBooks.isNotEmpty && ratedGames.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: VerticalDivider(width: 1, color: colors.outlineVariant)),
          if (ratedGames.isNotEmpty) Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionChip(Icons.sports_esports_outlined, '游戏', _gameColor, colors),
              const SizedBox(height: 8),
              ...ratedGames.take(5).map((g) => _buildTopRatedItem(g.title, g.rating!, g.coverPath, colors)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildSectionChip(IconData icon, String label, Color color, ColorScheme colors) {
    return Row(children: [
      Container(width: 20, height: 20, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
        child: Icon(icon, size: 11, color: color)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
    ]);
  }

  Widget _buildTopRatedItem(String title, double rating, String? imagePath, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30, height: 42,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
            clipBehavior: Clip.antiAlias,
            child: imagePath != null && imagePath.isNotEmpty
                ? FadeInLocalImage(path: imagePath, fit: BoxFit.cover, errorWidget: Icon(Icons.image_outlined, size: 12, color: colors.onSurface.withValues(alpha: 0.2)))
                : Icon(Icons.image_outlined, size: 12, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface))),
          const Icon(Icons.star, size: 14, color: Color(0xFFFFB800)),
          const SizedBox(width: 3),
          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurface)),
        ],
      ),
    );
  }

  // ─── 评分分布 ──────────────────────────────────────────────────────────

  Widget _buildRatingDistribution(List<Movie> fm, List<Book> fb, List<Game> fg, ColorScheme colors) {
    final allRatings = <double>[];
    for (final m in fm) { if (m.rating != null) allRatings.add(m.rating!); }
    for (final b in fb) { if (b.rating != null) allRatings.add(b.rating!); }
    for (final g in fg) { if (g.rating != null) allRatings.add(g.rating!); }
    if (allRatings.isEmpty) return const SizedBox.shrink();

    final avg = allRatings.reduce((a, b) => a + b) / allRatings.length;
    final counts = List.filled(10, 0);
    for (final r in allRatings) { counts[(r.round()).clamp(1, 10) - 1]++; }
    final maxCount = counts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) return const SizedBox.shrink();

    const barColors = [Color(0xFFBDBDBD), Color(0xFFBDBDBD), Color(0xFFFFCC80), Color(0xFFFFCC80),
      Color(0xFFFFB74D), Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFFFFA726),
      Color(0xFFFFB800), Color(0xFFFFB800)];

    return _buildCard(title: '评分分布', colors: colors, child: Column(children: [
      Row(children: [
        Text('平均评分', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
        const Spacer(),
        Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface)),
        Text(' / 10', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
      ]),
      const SizedBox(height: 16),
      SizedBox(height: 140, child: BarChart(BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount * 1.2, minY: 0,
        barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => colors.inverseSurface,
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem('${group.x + 1}星 ${rod.toY.toInt()}个', TextStyle(color: colors.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w600)),
        )),
        titlesData: FlTitlesData(show: true,
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Padding(padding: const EdgeInsets.only(top: 4), child: Text('${value.toInt() + 1}', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.4)))), reservedSize: 20)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(10, (i) => BarChartGroupData(x: i, barRods: [
          BarChartRodData(toY: counts[i].toDouble(), color: barColors[i], width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxCount * 1.2, color: colors.outlineVariant.withValues(alpha: 0.3))),
        ])),
      ))),
    ]));
  }

  // ─── 年度趋势 ──────────────────────────────────────────────────────────

  Widget _buildYearlyTrend(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg, ColorScheme colors) {
    final now = DateTime.now();
    final months = List.generate(12, (i) { final d = DateTime(now.year, now.month - (11 - i), 1); return '${d.month}月'; });
    List<int> countByMonth(List items) => List.generate(12, (i) {
      final d = DateTime(now.year, now.month - (11 - i), 1);
      return items.where((item) => (item as dynamic).createdAt.year == d.year && (item as dynamic).createdAt.month == d.month).length;
    });
    final movieData = countByMonth(fm), bookData = countByMonth(fb), noteData = countByMonth(fn), gameData = countByMonth(fg);
    final allValues = [...movieData, ...bookData, ...noteData, ...gameData];
    final maxVal = allValues.isEmpty ? 1 : allValues.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    final lineBars = <LineChartBarData>[
      if (_showMovies) _buildLineData(movieData, _movieColor),
      if (_showBooks) _buildLineData(bookData, _bookColor),
      if (_showNotes) _buildLineData(noteData, _noteColor),
      if (_showGames) _buildLineData(gameData, _gameColor),
    ];
    final legends = <(Color, String)>[];
    if (_showMovies) legends.add((_movieColor, '影视'));
    if (_showBooks) legends.add((_bookColor, '书籍'));
    if (_showNotes) legends.add((_noteColor, '笔记'));
    if (_showGames) legends.add((_gameColor, '游戏'));

    return _buildCard(title: '年度趋势', colors: colors, child: Column(children: [
      SizedBox(
        height: 280,
        child: LineChart(LineChartData(
          minY: 0, maxY: (safeMax * 1.3).toDouble(),
          lineBarsData: lineBars,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 6), child: Text(months[idx], style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))));
            }, reservedSize: 24)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))), reservedSize: 28)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: math.max(1, safeMax / 3).toDouble(),
            getDrawingHorizontalLine: (value) => FlLine(color: colors.outlineVariant, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.inverseSurface,
            getTooltipItems: (spots) => spots.map((s) {
              final labels = legends.map((l) => l.$2).toList();
              return LineTooltipItem('${labels[s.barIndex]} ${s.y.toInt()}', TextStyle(color: colors.onInverseSurface, fontSize: 11, fontWeight: FontWeight.w600));
            }).toList(),
          )),
        )),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: legends.asMap().entries.expand((e) {
        return [<Widget>[_buildLegend(e.value.$1, e.value.$2, colors)], if (e.key < legends.length - 1) [const SizedBox(width: 14)]].expand((x) => x);
      }).toList()),
    ]));
  }

  LineChartBarData _buildLineData(List<int> data, Color color) => LineChartBarData(
    spots: List.generate(12, (i) => FlSpot(i.toDouble(), data[i].toDouble())),
    isCurved: true, color: color, barWidth: 2,
    dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 2.5, color: color, strokeWidth: 0)),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
  );

  Widget _buildLegend(Color color, String label, ColorScheme colors) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5))),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
  ]);

  // ─── 星期分布 ──────────────────────────────────────────────────────────

  Widget _buildWeekdayDistribution(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg, ColorScheme colors) {
    final allDates = [...fm.map((m) => m.createdAt), ...fb.map((b) => b.createdAt), ...fn.map((n) => n.createdAt), ...fg.map((g) => g.createdAt)];
    if (allDates.isEmpty) return const SizedBox.shrink();
    final weekdayCounts = List.filled(7, 0);
    for (final d in allDates) { weekdayCounts[d.weekday - 1]++; }
    final maxCount = weekdayCounts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) return const SizedBox.shrink();
    final dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return _buildCard(title: '星期分布', colors: colors, child: SizedBox(height: 130, child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final ratio = weekdayCounts[i] / maxCount;
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('${weekdayCounts[i]}', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.35))),
            const SizedBox(height: 3),
            Container(height: (ratio * 80).clamp(4.0, 80.0), decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.5 + ratio * 0.5), borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 5),
            Text(dayLabels[i], style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.45))),
          ],
        )));
      }),
    )));
  }

  // ─── 累计增长 ──────────────────────────────────────────────────────────

  Widget _buildCumulativeGrowth(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg, ColorScheme colors) {
    final allItems = [...fm.map((m) => m.createdAt), ...fb.map((b) => b.createdAt), ...fn.map((n) => n.createdAt), ...fg.map((g) => g.createdAt)];
    if (allItems.isEmpty) return const SizedBox.shrink();
    allItems.sort();
    final monthlyCumulative = <int, int>{};
    int cumulative = 0;
    final now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(d.year, d.month + 1, 1);
      cumulative += allItems.where((date) => !date.isBefore(d) && date.isBefore(nextMonth)).length;
      monthlyCumulative[11 - i] = cumulative;
    }
    final maxVal = cumulative.toDouble();
    if (maxVal == 0) return const SizedBox.shrink();

    return _buildCard(title: '累计增长', colors: colors, child: SizedBox(height: 150, child: LineChart(LineChartData(
      minY: 0, maxY: maxVal * 1.2,
      lineBarsData: [LineChartBarData(
        spots: List.generate(12, (i) => FlSpot(i.toDouble(), (monthlyCumulative[i] ?? 0).toDouble())),
        isCurved: true, color: colors.primary, barWidth: 2.5,
        dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 2.5, color: colors.primary, strokeWidth: 0)),
        belowBarData: BarAreaData(show: true, color: colors.primary.withValues(alpha: 0.08)),
      )],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 2, getTitlesWidget: (value, meta) {
          final d = DateTime(now.year, now.month - (11 - value.toInt()), 1);
          return Padding(padding: const EdgeInsets.only(top: 6), child: Text('${d.month}月', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.4))));
        }, reservedSize: 20)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))), reservedSize: 28)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: math.max(1, maxVal / 3).toDouble(),
        getDrawingHorizontalLine: (value) => FlLine(color: colors.outlineVariant, strokeWidth: 0.5)),
      borderData: FlBorderData(show: false),
    ))));
  }

  // ─── 标签词云 ──────────────────────────────────────────────────────────

  Widget _buildTagCloud(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg, ColorScheme colors) {
    final tabs = <String>[];
    if (_showMovies) tabs.add('影视');
    if (_showBooks) tabs.add('书籍');
    if (_showNotes) tabs.add('笔记');
    if (_showGames) tabs.add('游戏');
    if (tabs.isEmpty) return const SizedBox.shrink();
    if (_cloudTabIndex >= tabs.length) _cloudTabIndex = 0;

    final tagCounts = <String, int>{};
    switch (tabs[_cloudTabIndex]) {
      case '影视': for (final m in fm) { for (final g in m.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
      case '书籍': for (final b in fb) { for (final g in b.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
      case '笔记': for (final n in fn) { for (final t in n.tags) { tagCounts[t] = (tagCounts[t] ?? 0) + 1; } }
      case '游戏': for (final g in fg) { for (final ge in g.genres) { tagCounts[ge] = (tagCounts[ge] ?? 0) + 1; } }
    }
    final sorted = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxCount = sorted.first.value, minCount = sorted.last.value;
    final range = math.max(maxCount - minCount, 1);
    const cloudColors = [Color(0xFFE53935), Color(0xFF4A90D9), Color(0xFF7E57C2), Color(0xFF66BB6A), Color(0xFFFF8F00), Color(0xFF00ACC1), Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFF8D6E63)];

    return _buildCard(title: '标签词云', colors: colors, child: Column(children: [
      Row(children: tabs.asMap().entries.map((e) {
        final selected = _cloudTabIndex == e.key;
        return Expanded(child: GestureDetector(
          onTap: () => setState(() => _cloudTabIndex = e.key),
          child: Container(padding: const EdgeInsets.symmetric(vertical: 6), margin: EdgeInsets.only(right: e.key < tabs.length - 1 ? 4 : 0),
            decoration: BoxDecoration(color: selected ? colors.primary : colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
            child: Text(e.value, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)))),
        ));
      }).toList()),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 4, children: sorted.map((e) {
        final ratio = (e.value - minCount) / range;
        final fontSize = (11.0 + ratio * 16.0).roundToDouble();
        final c = cloudColors[((ratio * (cloudColors.length - 1)).round()).clamp(0, cloudColors.length - 1)];
        return Text(e.key, style: TextStyle(fontSize: fontSize, fontWeight: fontSize > 18 ? FontWeight.w700 : FontWeight.w500, color: c, height: 1.3));
      }).toList()),
    ]));
  }

  // ─── 趣味统计 ──────────────────────────────────────────────────────────

  Widget _buildFunStats(List<Movie> fm, List<Book> fb, List<Note> fn, List<Game> fg, ColorScheme colors) {
    final allItems = [...fm.map((m) => m.createdAt), ...fb.map((b) => b.createdAt), ...fn.map((n) => n.createdAt), ...fg.map((g) => g.createdAt)];
    if (allItems.isEmpty) return const SizedBox.shrink();
    final sortedDates = allItems.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
    int maxStreak = 1, currentStreak = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      if (sortedDates[i].difference(sortedDates[i - 1]).inDays == 1) { currentStreak++; maxStreak = math.max(maxStreak, currentStreak); }
      else { currentStreak = 1; }
    }
    final tagCounts = <String, int>{};
    for (final m in fm) { for (final g in m.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
    for (final b in fb) { for (final g in b.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
    for (final n in fn) { for (final t in n.tags) { tagCounts[t] = (tagCounts[t] ?? 0) + 1; } }
    for (final g in fg) { for (final ge in g.genres) { tagCounts[ge] = (tagCounts[ge] ?? 0) + 1; } }
    final topTag = tagCounts.entries.isEmpty ? null : tagCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return _buildCard(title: '趣味统计', colors: colors, child: Column(children: [
      _buildFunCard(Icons.local_fire_department_outlined, '连续记录', maxStreak > 1 ? '$maxStreak 天' : '-', '最长连续记录天数', const Color(0xFFFF8F00), colors),
      const SizedBox(height: 10),
      _buildFunCard(Icons.label_outlined, '最常用标签', topTag != null ? topTag.key : '-', topTag != null ? '使用 ${topTag.value} 次' : '', const Color(0xFF26A69A), colors),
    ]));
  }

  Widget _buildFunCard(IconData icon, String label, String value, String sub, Color color, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ])),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
      ]),
    );
  }

  // ─── 通用卡片 ──────────────────────────────────────────────────────────

  Widget _buildCard({required String title, required Widget child, required ColorScheme colors}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 3, height: 12, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(1.5))),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ]),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ModuleData {
  final IconData icon;
  final String label;
  final int count;
  final String sub;
  final Color color;
  final int tabIndex;
  _ModuleData(this.icon, this.label, this.count, this.sub, this.color, this.tabIndex);
}
