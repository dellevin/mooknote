import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/fade_in_local_image.dart';

/// 数据统计页面 - 多维度数据分析
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _cloudTabIndex = 0;
  bool get _showMovies => UserPrefs().showMovieTab;
  bool get _showBooks => UserPrefs().showBookTab;
  bool get _showNotes => UserPrefs().showNoteTab;

  // 缓存过滤后的列表，避免每次 build 都重新过滤
  List<Movie>? _cachedMovies;
  List<Book>? _cachedBooks;
  List<Note>? _cachedNotes;
  List<Movie>? _filteredMovies;
  List<Book>? _filteredBooks;
  List<Note>? _filteredNotes;

  (List<Movie>, List<Book>, List<Note>) _getFilteredLists(
      List<Movie> movies, List<Book> books, List<Note> notes) {
    if (!identical(movies, _cachedMovies) ||
        !identical(books, _cachedBooks) ||
        !identical(notes, _cachedNotes)) {
      _cachedMovies = movies;
      _cachedBooks = books;
      _cachedNotes = notes;
      _filteredMovies = movies.where((m) => !m.isDeleted).toList();
      _filteredBooks = books.where((b) => !b.isDeleted).toList();
      _filteredNotes = notes.where((n) => !n.isDeleted).toList();
    }
    return (_filteredMovies!, _filteredBooks!, _filteredNotes!);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final movies = context.select<AppProvider, List<Movie>>((p) => p.movies);
    final books = context.select<AppProvider, List<Book>>((p) => p.books);
    final notes = context.select<AppProvider, List<Note>>((p) => p.notes);
    final (fm, fb, fn) = _getFilteredLists(movies, books, notes);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('数据统计')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. 总览
          _buildOverview(fm, fb, fn),
              const SizedBox(height: 28),
              // 2. 状态分布
              if (_showMovies) ...[
                _buildStatusSection('影视状态分布', fm, (m) => m.status, {'已看': 'watched', '在看': 'watching', '想看': 'want_to_watch'}),
                const SizedBox(height: 28),
              ],
              if (_showBooks) ...[
                _buildStatusSection('阅读状态分布', fb, (b) => b.status, {'已读': 'read', '在读': 'reading', '想读': 'want_to_read'}),
                const SizedBox(height: 28),
              ],
              // 3. 习惯洞察
              _buildHabitsInsight(fm, fb, fn),
              const SizedBox(height: 28),
              // 4. 类型偏好雷达图
              _buildGenreRadar(fm, fb),
              const SizedBox(height: 28),
              // 5. 导演/作者 TOP 5
              _buildDirectorTop5(fm),
              const SizedBox(height: 28),
              _buildAuthorTop5(fb),
              const SizedBox(height: 28),
              // 6. 高分之最
              _buildTopRated(fm, fb),
              const SizedBox(height: 28),
              // 7. 评分分布
              _buildRatingDistribution(fm, fb),
              const SizedBox(height: 28),
              // 8. 年度趋势
              _buildYearlyTrend(fm, fb, fn),
              const SizedBox(height: 28),
              // 9. 星期分布
              _buildWeekdayDistribution(fm, fb, fn),
              const SizedBox(height: 28),
              // 10. 累计增长
              _buildCumulativeGrowth(fm, fb, fn),
              const SizedBox(height: 28),
              // 11. 标签词云
              _buildTagCloud(fm, fb, fn),
              const SizedBox(height: 28),
              // 12+13. 马拉松 + 标签之最
              _buildFunStats(fm, fb, fn),
              const SizedBox(height: 80),
            ],
          ),
        );
  }

  // ─── 1. 总览区域 ──────────────────────────────────────────────────────

  Widget _buildOverview(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final completed = movies.where((m) => m.status == 'watched').length +
        books.where((b) => b.status == 'read').length;
    final totalWithStatus = movies.length + books.length;
    final completionRate = totalWithStatus > 0 ? completed / totalWithStatus : 0.0;

    // 本月新增
    final now = DateTime.now();
    final thisMonth = movies.where((m) => m.createdAt.year == now.year && m.createdAt.month == now.month).length +
        books.where((b) => b.createdAt.year == now.year && b.createdAt.month == now.month).length +
        notes.where((n) => n.createdAt.year == now.year && n.createdAt.month == now.month).length;
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonth = movies.where((m) => m.createdAt.year == lastMonthDate.year && m.createdAt.month == lastMonthDate.month).length +
        books.where((b) => b.createdAt.year == lastMonthDate.year && b.createdAt.month == lastMonthDate.month).length +
        notes.where((n) => n.createdAt.year == lastMonthDate.year && n.createdAt.month == lastMonthDate.month).length;
    final monthDiff = thisMonth - lastMonth;

    // 平均评分
    final allRatings = [...movies, ...books].map((e) => (e as dynamic).rating as double?).where((r) => r != null && r > 0).toList();
    final avgRating = allRatings.isNotEmpty ? allRatings.reduce((a, b) => a! + b!)! / allRatings.length : 0.0;

    // 记录天数
    final allDates = [...movies.map((m) => m.createdAt), ...books.map((b) => b.createdAt), ...notes.map((n) => n.createdAt)];
    final daysTracked = allDates.isNotEmpty ? now.difference(allDates.reduce((a, b) => a.isBefore(b) ? a : b)).inDays + 1 : 0;

    return Row(
      children: [
        _buildOverviewCard('完成率', completionRate == 0 ? '-' : '${(completionRate * 100).toStringAsFixed(0)}%', Icons.check_circle_outline, colors.primary, subtitle: completionRate > 0 ? '已看+已读' : null),
        const SizedBox(width: 10),
        _buildOverviewCard('本月新增', '$thisMonth', Icons.trending_up, const Color(0xFF66BB6A), subtitle: monthDiff >= 0 ? '↑$monthDiff' : '↓${monthDiff.abs()}'),
        const SizedBox(width: 10),
        _buildOverviewCard('平均评分', avgRating > 0 ? avgRating.toStringAsFixed(1) : '-', Icons.star_outline, const Color(0xFFFFB800), subtitle: avgRating > 0 ? '/ 10' : null),
        const SizedBox(width: 10),
        _buildOverviewCard('记录天数', daysTracked > 0 ? '$daysTracked' : '-', Icons.calendar_today_outlined, const Color(0xFF7E57C2), subtitle: daysTracked > 0 ? '天' : null),
      ],
    );
  }

  Widget _buildOverviewCard(String label, String value, IconData icon, Color color, {String? subtitle}) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
            ],
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
          ],
        ),
      ),
    );
  }

  // ─── 2. 状态分布 ────────────────────────────────────────────────────────

  Widget _buildStatusSection(String title, List items, String Function(dynamic) getStatus, Map<String, String> labels) {
    final colors = Theme.of(context).colorScheme;
    final total = items.length;

    return _buildCard(
      title: title,
      child: Column(
        children: labels.entries.map((e) {
          final count = items.where((i) => getStatus(i) == e.value).length;
          final pct = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.key, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                    const Spacer(),
                    Text('$count', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    const SizedBox(width: 4),
                    Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: pct, backgroundColor: colors.outlineVariant, color: colors.primary, minHeight: 6),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 3. 习惯洞察 ────────────────────────────────────────────────────────

  Widget _buildHabitsInsight(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final allDates = [
      ...movies.map((m) => m.createdAt),
      ...books.map((b) => b.createdAt),
      ...notes.map((n) => n.createdAt),
    ]..sort();
    if (allDates.isEmpty) return const SizedBox.shrink();

    // 最活跃月份
    final monthCounts = <int, int>{};
    for (final d in allDates) {
      monthCounts[d.month] = (monthCounts[d.month] ?? 0) + 1;
    }
    final busiestMonth = monthCounts.entries.isEmpty ? 1 : monthCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    const monthNames = ['', '一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];

    // 记录频率
    final firstDate = allDates.first;
    final totalMonths = math.max(1, (DateTime.now().year - firstDate.year) * 12 + DateTime.now().month - firstDate.month + 1);
    final avgPerMonth = (allDates.length / totalMonths).toStringAsFixed(1);

    // 观影/阅读节奏（已看完的平均间隔天数）
    final watchedDates = movies.where((m) => m.status == 'watched').map((m) => m.createdAt).toList()..sort();
    final readDates = books.where((b) => b.status == 'read').map((b) => b.createdAt).toList()..sort();
    final watchedAvgGap = _calcAvgGap(watchedDates);
    final readAvgGap = _calcAvgGap(readDates);

    return _buildCard(
      title: '习惯洞察',
      child: Column(
        children: [
          _buildInsightRow(Icons.calendar_month_outlined, '最活跃月份', monthNames[busiestMonth]),
          Divider(height: 1, color: colors.outlineVariant),
          _buildInsightRow(Icons.speed_outlined, '记录频率', '平均每月 $avgPerMonth 条'),
          Divider(height: 1, color: colors.outlineVariant),
          if (watchedAvgGap > 0)
            _buildInsightRow(Icons.movie_outlined, '观影节奏', '平均 ${watchedAvgGap.toStringAsFixed(0)} 天一部'),
          if (watchedAvgGap > 0 && readAvgGap > 0)
            Divider(height: 1, color: colors.outlineVariant),
          if (readAvgGap > 0)
            _buildInsightRow(Icons.menu_book_outlined, '阅读节奏', '平均 ${readAvgGap.toStringAsFixed(0)} 天一本'),
        ],
      ),
    );
  }

  double _calcAvgGap(List<DateTime> dates) {
    if (dates.length < 2) return 0;
    final sorted = dates.toList()..sort();
    double totalGap = 0;
    for (int i = 1; i < sorted.length; i++) {
      totalGap += sorted[i].difference(sorted[i - 1]).inDays.toDouble();
    }
    return totalGap / (sorted.length - 1);
  }

  Widget _buildInsightRow(IconData icon, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ],
      ),
    );
  }

  // ─── 4. 类型偏好雷达图 ──────────────────────────────────────────────────

  Widget _buildGenreRadar(List<Movie> movies, List<Book> books) {
    final colors = Theme.of(context).colorScheme;
    final movieGenres = <String, int>{};
    final bookGenres = <String, int>{};
    for (final m in movies) { for (final g in m.genres) { movieGenres[g] = (movieGenres[g] ?? 0) + 1; } }
    for (final b in books) { for (final g in b.genres) { bookGenres[g] = (bookGenres[g] ?? 0) + 1; } }

    final allGenres = <String, int>{};
    allGenres.addAll(movieGenres);
    for (final e in bookGenres.entries) { allGenres[e.key] = (allGenres[e.key] ?? 0) + e.value; }
    final sorted = allGenres.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top6 = sorted.take(6).toList();
    if (top6.length < 3) return const SizedBox.shrink();

    final maxVal = top6.first.value.toDouble();

    return _buildCard(
      title: '类型偏好',
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                dataSets: [
                  if (movieGenres.isNotEmpty)
                    RadarDataSet(
                      dataEntries: top6.map((e) => RadarEntry(value: (movieGenres[e.key] ?? 0) / math.max(1, maxVal))).toList(),
                      borderColor: const Color(0xFF4A90D9),
                      fillColor: const Color(0xFF4A90D9).withValues(alpha: 0.15),
                      borderWidth: 2,
                    ),
                  if (bookGenres.isNotEmpty)
                    RadarDataSet(
                      dataEntries: top6.map((e) => RadarEntry(value: (bookGenres[e.key] ?? 0) / math.max(1, maxVal))).toList(),
                      borderColor: const Color(0xFF7E57C2),
                      fillColor: const Color(0xFF7E57C2).withValues(alpha: 0.15),
                      borderWidth: 2,
                    ),
                ],
                radarBorderData: BorderSide(color: colors.outlineVariant, width: 0.5),
                gridBorderData: BorderSide(color: colors.outlineVariant, width: 0.5),
                tickBorderData: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3), width: 0.5),
                ticksTextStyle: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3)),
                titleTextStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
                titlePositionPercentageOffset: 0.15,
                getTitle: (index, angle) => RadarChartTitle(text: top6[index].key),
                tickCount: 3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (movieGenres.isNotEmpty) ...[
                Container(width: 10, height: 3, decoration: BoxDecoration(color: const Color(0xFF4A90D9), borderRadius: BorderRadius.circular(1.5))),
                const SizedBox(width: 4),
                Text('影视', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                const SizedBox(width: 16),
              ],
              if (bookGenres.isNotEmpty) ...[
                Container(width: 10, height: 3, decoration: BoxDecoration(color: const Color(0xFF7E57C2), borderRadius: BorderRadius.circular(1.5))),
                const SizedBox(width: 4),
                Text('书籍', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── 5. 导演/作者 TOP 5 ────────────────────────────────────────────────

  Widget _buildDirectorTop5(List<Movie> movies) {
    final colors = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    for (final m in movies) { for (final d in m.directors) { counts[d] = (counts[d] ?? 0) + 1; } }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();
    final maxVal = top5.first.value.toDouble();

    return _buildCard(
      title: '导演 TOP 5',
      child: Column(
        children: top5.map((e) {
          final ratio = e.value / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: ratio, backgroundColor: colors.outlineVariant, color: const Color(0xFF4A90D9), minHeight: 4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}部', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuthorTop5(List<Book> books) {
    final colors = Theme.of(context).colorScheme;
    final counts = <String, int>{};
    for (final b in books) { for (final a in b.authors) { counts[a] = (counts[a] ?? 0) + 1; } }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    if (top5.isEmpty) return const SizedBox.shrink();
    final maxVal = top5.first.value.toDouble();

    return _buildCard(
      title: '作者 TOP 5',
      child: Column(
        children: top5.map((e) {
          final ratio = e.value / maxVal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 60, child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.7)), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: ratio, backgroundColor: colors.outlineVariant, color: const Color(0xFF7E57C2), minHeight: 4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}本', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 6. 高分之最 TOP 5 ─────────────────────────────────────────────────

  Widget _buildTopRated(List<Movie> movies, List<Book> books) {
    final colors = Theme.of(context).colorScheme;
    final ratedMovies = movies.where((m) => m.rating != null && m.rating! > 0).toList()
      ..sort((a, b) => b.rating!.compareTo(a.rating!));
    final ratedBooks = books.where((b) => b.rating != null && b.rating! > 0).toList()
      ..sort((a, b) => b.rating!.compareTo(a.rating!));

    if (ratedMovies.isEmpty && ratedBooks.isEmpty) return const SizedBox.shrink();

    return _buildCard(
      title: '高分之最',
      child: Column(
        children: [
          if (ratedMovies.isNotEmpty) ...[
            Text('影视 TOP 5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            ...ratedMovies.take(5).map((m) => _buildTopRatedItem(m.title, m.rating!, m.posterPath, colors)),
            if (ratedBooks.isNotEmpty) const SizedBox(height: 16),
          ],
          if (ratedBooks.isNotEmpty) ...[
            Text('书籍 TOP 5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            ...ratedBooks.take(5).map((b) => _buildTopRatedItem(b.title, b.rating!, b.coverPath, colors)),
          ],
        ],
      ),
    );
  }

  Widget _buildTopRatedItem(String title, double rating, String? imagePath, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 44,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
            clipBehavior: Clip.antiAlias,
            child: imagePath != null && imagePath.isNotEmpty
                ? FadeInLocalImage(path: imagePath, fit: BoxFit.cover, errorWidget: Icon(Icons.image_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)))
                : Icon(Icons.image_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: colors.onSurface))),
          Icon(Icons.star, size: 16, color: const Color(0xFFFFB800)),
          const SizedBox(width: 4),
          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: colors.onSurface)),
        ],
      ),
    );
  }

  // ─── 7. 评分分布 ────────────────────────────────────────────────────────

  Widget _buildRatingDistribution(List<Movie> movies, List<Book> books) {
    final colors = Theme.of(context).colorScheme;
    final allRatings = <double>[];
    for (final m in movies) { if (m.rating != null) allRatings.add(m.rating!); }
    for (final b in books) { if (b.rating != null) allRatings.add(b.rating!); }
    if (allRatings.isEmpty) return const SizedBox.shrink();

    final avg = allRatings.reduce((a, b) => a + b) / allRatings.length;
    final counts = List.filled(10, 0);
    for (final r in allRatings) { counts[(r.round()).clamp(1, 10) - 1]++; }
    final maxCount = counts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) return const SizedBox.shrink();

    const barColors = [
      Color(0xFFBDBDBD), Color(0xFFBDBDBD), Color(0xFFFFCC80), Color(0xFFFFCC80),
      Color(0xFFFFB74D), Color(0xFFFFB74D), Color(0xFFFFA726), Color(0xFFFFA726),
      Color(0xFFFFB800), Color(0xFFFFB800),
    ];

    return _buildCard(
      title: '评分分布',
      child: Column(
        children: [
          Row(
            children: [
              Text('平均评分', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
              const Spacer(),
              Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface)),
              Text(' / 10', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxCount * 1.2,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem('${group.x + 1}星 ${rod.toY.toInt()}部', TextStyle(color: colors.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600));
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('${value.toInt() + 1}', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.5))),
                    ),
                    reservedSize: 24,
                  )),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(10, (i) => BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    color: barColors[i],
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxCount * 1.2, color: colors.outlineVariant.withValues(alpha: 0.3)),
                  ),
                ])),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('星级评分', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  // ─── 8. 年度趋势折线图 ──────────────────────────────────────────────────

  Widget _buildYearlyTrend(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      final d = DateTime(now.year, now.month - (11 - i), 1);
      return '${d.month}月';
    });

    List<int> countByMonth(List items) {
      return List.generate(12, (i) {
        final d = DateTime(now.year, now.month - (11 - i), 1);
        return items.where((item) => item.createdAt.year == d.year && item.createdAt.month == d.month).length;
      });
    }

    final movieData = countByMonth(movies);
    final bookData = countByMonth(books);
    final noteData = countByMonth(notes);
    final allValues = [...movieData, ...bookData, ...noteData];
    final maxVal = allValues.isEmpty ? 1 : allValues.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    return _buildCard(
      title: '年度趋势',
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: (safeMax * 1.3).toDouble(),
                lineBarsData: [
                  _buildLineData(movieData, const Color(0xFF4A90D9)),
                  _buildLineData(bookData, const Color(0xFF7E57C2)),
                  _buildLineData(noteData, const Color(0xFF66BB6A)),
                ],
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    interval: 2,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(months[idx], style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                      );
                    },
                    reservedSize: 24,
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
                    reservedSize: 28,
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, safeMax / 3).toDouble(),
                  getDrawingHorizontalLine: (value) => FlLine(color: colors.outlineVariant, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colors.inverseSurface,
                    getTooltipItems: (spots) => spots.map((s) {
                      final labels = ['影视', '书籍', '笔记'];
                      return LineTooltipItem('${labels[s.barIndex]} ${s.y.toInt()}', TextStyle(color: colors.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600));
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(const Color(0xFF4A90D9), '影视'),
              const SizedBox(width: 16),
              _buildLegend(const Color(0xFF7E57C2), '书籍'),
              const SizedBox(width: 16),
              _buildLegend(const Color(0xFF66BB6A), '笔记'),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLineData(List<int> data, Color color) {
    return LineChartBarData(
      spots: List.generate(12, (i) => FlSpot(i.toDouble(), data[i].toDouble())),
      isCurved: true,
      color: color,
      barWidth: 2,
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: color, strokeWidth: 0)),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.08)),
    );
  }

  Widget _buildLegend(Color color, String label) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1.5))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  // ─── 9. 星期分布 ────────────────────────────────────────────────────────

  Widget _buildWeekdayDistribution(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final allDates = [
      ...movies.map((m) => m.createdAt),
      ...books.map((b) => b.createdAt),
      ...notes.map((n) => n.createdAt),
    ];
    if (allDates.isEmpty) return const SizedBox.shrink();

    final weekdayCounts = List.filled(7, 0);
    for (final d in allDates) {
      weekdayCounts[d.weekday - 1]++;
    }
    final maxCount = weekdayCounts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) return const SizedBox.shrink();
    final dayLabels = ['一', '二', '三', '四', '五', '六', '日'];

    return _buildCard(
      title: '星期分布',
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final ratio = weekdayCounts[i] / maxCount;
            final barHeight = (ratio * 96).clamp(4.0, 96.0);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${weekdayCounts[i]}', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                    const SizedBox(height: 4),
                    Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.6 + ratio * 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(dayLabels[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─── 10. 累计增长曲线 ──────────────────────────────────────────────────

  Widget _buildCumulativeGrowth(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final allItems = [...movies.map((m) => m.createdAt), ...books.map((b) => b.createdAt), ...notes.map((n) => n.createdAt)];
    if (allItems.isEmpty) return const SizedBox.shrink();
    allItems.sort();

    // 按月累计
    final monthlyCumulative = <int, int>{};
    int cumulative = 0;
    final now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final nextMonth = DateTime(d.year, d.month + 1, 1);
      final count = allItems.where((date) => !date.isBefore(d) && date.isBefore(nextMonth)).length;
      cumulative += count;
      monthlyCumulative[11 - i] = cumulative;
    }
    final maxVal = cumulative.toDouble();
    if (maxVal == 0) return const SizedBox.shrink();

    return _buildCard(
      title: '累计增长',
      child: SizedBox(
        height: 160,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxVal * 1.2,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(12, (i) => FlSpot(i.toDouble(), (monthlyCumulative[i] ?? 0).toDouble())),
                isCurved: true,
                color: colors.primary,
                barWidth: 2.5,
                dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: colors.primary, strokeWidth: 0)),
                belowBarData: BarAreaData(show: true, color: colors.primary.withValues(alpha: 0.08)),
              ),
            ],
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, meta) {
                  final d = DateTime(now.year, now.month - (11 - value.toInt()), 1);
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${d.month}月', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                  );
                },
                reservedSize: 24,
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
                reservedSize: 28,
              )),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: math.max(1, maxVal / 3).toDouble(),
              getDrawingHorizontalLine: (value) => FlLine(color: colors.outlineVariant, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  // ─── 11. 标签词云 ──────────────────────────────────────────────────────

  Widget _buildTagCloud(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final tabs = <String>[];
    if (_showMovies) tabs.add('影视');
    if (_showBooks) tabs.add('书籍');
    if (_showNotes) tabs.add('笔记');
    if (tabs.isEmpty) return const SizedBox.shrink();
    if (_cloudTabIndex >= tabs.length) _cloudTabIndex = 0;

    final tagCounts = <String, int>{};
    switch (tabs[_cloudTabIndex]) {
      case '影视':
        for (final m in movies) { for (final g in m.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
        break;
      case '书籍':
        for (final b in books) { for (final g in b.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
        break;
      case '笔记':
        for (final n in notes) { for (final t in n.tags) { tagCounts[t] = (tagCounts[t] ?? 0) + 1; } }
        break;
    }

    final sorted = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxCount = sorted.first.value;
    final minCount = sorted.last.value;
    final range = math.max(maxCount - minCount, 1);

    const cloudColors = [
      Color(0xFFE53935), Color(0xFF4A90D9), Color(0xFF7E57C2),
      Color(0xFF66BB6A), Color(0xFFFF8F00), Color(0xFF00ACC1),
      Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFF8D6E63),
    ];

    return _buildCard(
      title: '标签词云',
      child: Column(children: [
        Row(
          children: tabs.map((t) {
            final i = tabs.indexOf(t);
            final selected = _cloudTabIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _cloudTabIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  margin: EdgeInsets.only(right: i < tabs.length - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: selected ? colors.primary : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sorted.map((e) {
            final ratio = (e.value - minCount) / range;
            final fontSize = (12.0 + ratio * 18.0).roundToDouble();
            final c = cloudColors[((ratio * (cloudColors.length - 1)).round()).clamp(0, cloudColors.length - 1)];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(e.key, style: TextStyle(fontSize: fontSize, fontWeight: fontSize > 18 ? FontWeight.w700 : FontWeight.w500, color: c, height: 1.3)),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ─── 12+13. 趣味统计 ──────────────────────────────────────────────────

  Widget _buildFunStats(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final allItems = [...movies.map((m) => m.createdAt), ...books.map((b) => b.createdAt), ...notes.map((n) => n.createdAt)];
    if (allItems.isEmpty) return const SizedBox.shrink();

    // 观影马拉松
    final sortedDates = allItems.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()..sort();
    int maxStreak = 1, currentStreak = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      if (sortedDates[i].difference(sortedDates[i - 1]).inDays == 1) {
        currentStreak++;
        maxStreak = math.max(maxStreak, currentStreak);
      } else {
        currentStreak = 1;
      }
    }

    // 标签之最
    final tagCounts = <String, int>{};
    for (final m in movies) { for (final g in m.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
    for (final b in books) { for (final g in b.genres) { tagCounts[g] = (tagCounts[g] ?? 0) + 1; } }
    for (final n in notes) { for (final t in n.tags) { tagCounts[t] = (tagCounts[t] ?? 0) + 1; } }
    final topTag = tagCounts.entries.isEmpty ? null : tagCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);

    return Row(
      children: [
        Expanded(
          child: _buildFunCard(Icons.local_fire_department_outlined, '连续记录', maxStreak > 1 ? '$maxStreak 天' : '-', '最长连续记录天数', const Color(0xFFFF8F00), colors),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFunCard(Icons.label_outlined, '最常用标签', topTag != null ? topTag.key : '-', topTag != null ? '使用 ${topTag.value} 次' : '', const Color(0xFF26A69A), colors),
        ),
      ],
    );
  }

  Widget _buildFunCard(IconData icon, String label, String value, String sub, Color color, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
          ],
        ],
      ),
    );
  }

  // ─── 通用卡片 ────────────────────────────────────────────────────────

  Widget _buildCard({required String title, required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 14, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
