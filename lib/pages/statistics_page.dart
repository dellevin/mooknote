import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/user_prefs.dart';

/// 数据统计页面 - 多维度数据分析
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int _cloudTabIndex = 0; // 0=影视, 1=书籍, 2=笔记
  bool get _showMovies => UserPrefs().showMovieTab;
  bool get _showBooks => UserPrefs().showBookTab;
  bool get _showNotes => UserPrefs().showNoteTab;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('数据统计')),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final movies = provider.movies.where((m) => !m.isDeleted).toList();
          final books = provider.books;
          final notes = provider.notes;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildTotalCards(movies, books, notes),
              const SizedBox(height: 28),
              if (_showMovies) ...[
                _buildStatusSection('影视状态分布', movies, (m) => m.status, {'已看': 'watched', '在看': 'watching', '想看': 'want_to_watch'}),
                const SizedBox(height: 28),
                _buildGenreDistribution('影视类型分布', movies),
                const SizedBox(height: 28),
              ],
              if (_showBooks) ...[
                _buildStatusSection('阅读状态分布', books, (b) => b.status, {'已读': 'read', '在读': 'reading', '想读': 'want_to_read'}),
                const SizedBox(height: 28),
                _buildGenreDistribution('书籍类型分布', books),
                const SizedBox(height: 28),
              ],
              if (_showNotes) ...[
                _buildNoteTagDistribution('笔记标签分布', notes),
                const SizedBox(height: 28),
              ],
              _buildTagCloud(movies, books, notes),
              const SizedBox(height: 28),
              _buildRatingDistribution('评分分布', movies, books),
              const SizedBox(height: 28),
              _buildMonthlyTrend(movies, books, notes),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  // ─── 总览卡片 ────────────────────────────────────────────────────────

  Widget _buildTotalCards(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final items = <_CardData>[];
    if (_showMovies) items.add(_CardData('影视', movies.length, Icons.movie_outlined, const Color(0xFF4A90D9)));
    if (_showBooks) items.add(_CardData('书籍', books.length, Icons.menu_book_outlined, const Color(0xFF7E57C2)));
    if (_showNotes) items.add(_CardData('笔记', notes.length, Icons.note_outlined, const Color(0xFF66BB6A)));

    return Row(
      children: items.map((d) => Expanded(
        child: Container(
          margin: EdgeInsets.only(right: d == items.last ? 0 : 10),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: d.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(d.icon, size: 26, color: d.color),
              const SizedBox(height: 10),
              Text('${d.count}', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: d.color)),
              const SizedBox(height: 2),
              Text(d.label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      )).toList(),
    );
  }

  // ─── 状态分布 ────────────────────────────────────────────────────────

  Widget _buildStatusSection(String title, List items, String Function(dynamic) getStatus, Map<String, String> labels) {
    final colors = Theme.of(context).colorScheme;
    final active = items.where((i) => !(i is Movie) || !i.isDeleted).toList();
    final total = active.length;

    return _buildCard(
      title: title,
      child: Column(
        children: labels.entries.map((e) {
          final count = active.where((i) => getStatus(i) == e.value).length;
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
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: colors.outlineVariant,
                    color: colors.primary,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 类型/标签分布 ───────────────────────────────────────────────────

  Widget _buildGenreDistribution(String title, List items) {
    final colors = Theme.of(context).colorScheme;
    final genreCounts = <String, int>{};
    for (final item in items) {
      for (final genre in (item.genres as List<String>)) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }
    final sorted = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxCount = top.first.value;

    return _buildCard(
      title: title,
      child: Column(
        children: top.map((e) {
          final pct = maxCount > 0 ? e.value / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: pct, backgroundColor: colors.outlineVariant, color: colors.primary, minHeight: 4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoteTagDistribution(String title, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final tagCounts = <String, int>{};
    for (final note in notes) {
      for (final tag in note.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final sorted = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxCount = top.first.value;

    return _buildCard(
      title: title,
      child: Column(
        children: top.map((e) {
          final pct = maxCount > 0 ? e.value / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(e.key, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6)), overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(value: pct, backgroundColor: colors.outlineVariant, color: colors.primary, minHeight: 4),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 评分分布 ────────────────────────────────────────────────────────

  Widget _buildRatingDistribution(String title, List<Movie> movies, List<Book> books) {
    final colors = Theme.of(context).colorScheme;
    final allRatings = <double>[];
    for (final m in movies) {
      if (m.rating != null) allRatings.add(m.rating!);
    }
    for (final b in books) {
      if (b.rating != null) allRatings.add(b.rating!);
    }
    if (allRatings.isEmpty) return const SizedBox.shrink();

    final avg = allRatings.reduce((a, b) => a + b) / allRatings.length;

    // 按 1-10 分统计
    final counts = List.filled(10, 0);
    for (final r in allRatings) {
      final idx = (r.round()).clamp(1, 10) - 1;
      counts[idx]++;
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) return const SizedBox.shrink();

    // 渐变色：低分灰色 → 高分金色
    const barColors = [
      Color(0xFFBDBDBD), Color(0xFFBDBDBD), // 1-2 灰
      Color(0xFFFFCC80), Color(0xFFFFCC80), // 3-4 橙黄
      Color(0xFFFFB74D), Color(0xFFFFB74D), // 5-6 橙
      Color(0xFFFFA726), Color(0xFFFFA726), // 7-8 深橙
      Color(0xFFFFB800), Color(0xFFFFB800), // 9-10 金
    ];

    return _buildCard(
      title: title,
      child: Column(
        children: [
          // 平均评分
          Row(
            children: [
              Text('平均评分', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
              const Spacer(),
              Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface)),
              Text(' / 10', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(height: 20),
          // 柱状图
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
                      return BarTooltipItem(
                        '${group.x + 1}星 ${rod.toY.toInt()}部',
                        TextStyle(color: colors.onInverseSurface, fontSize: 12, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${value.toInt() + 1}', style: TextStyle(
                            fontSize: 10, color: colors.onSurface.withValues(alpha: 0.5))),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(10, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: barColors[i],
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxCount * 1.2,
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 底部标签
          Text('星级评分', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  // ─── 月度趋势 ────────────────────────────────────────────────────────

  Widget _buildMonthlyTrend(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i), 1);
      return '${d.month}月';
    });

    final counts = <String, List<int>>{};
    if (_showMovies) counts['影视'] = List.filled(6, 0);
    if (_showBooks) counts['书籍'] = List.filled(6, 0);
    if (_showNotes) counts['笔记'] = List.filled(6, 0);

    for (final m in movies) {
      final idx = _monthIndex(m.createdAt, now);
      if (idx >= 0 && idx < 6) counts['影视']?[idx] = (counts['影视']?[idx] ?? 0) + 1;
    }
    for (final b in books) {
      final idx = _monthIndex(b.createdAt, now);
      if (idx >= 0 && idx < 6) counts['书籍']?[idx] = (counts['书籍']?[idx] ?? 0) + 1;
    }
    for (final n in notes) {
      final idx = _monthIndex(n.createdAt, now);
      if (idx >= 0 && idx < 6) counts['笔记']?[idx] = (counts['笔记']?[idx] ?? 0) + 1;
    }

    final allValues = counts.values.expand((l) => l);
    final maxVal = allValues.isEmpty ? 1 : allValues.reduce((a, b) => a > b ? a : b);
    final safeMax = maxVal == 0 ? 1 : maxVal;

    final brandColors = { '影视': const Color(0xFF4A90D9), '书籍': const Color(0xFF7E57C2), '笔记': const Color(0xFF66BB6A) };

    return _buildCard(
      title: '近6月趋势',
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(6, (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ...counts.entries.map((e) {
                        final h = (e.value[i] / safeMax * 80).clamp(0, 80).toDouble();
                        return Container(
                          height: h < 2 && e.value[i] > 0 ? 2 : h,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: brandColors[e.key]!.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              )),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: colors.outlineVariant),
          const SizedBox(height: 8),
          // 月份标签
          Row(
            children: months.map((m) => Expanded(
              child: Text(m, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
            )).toList(),
          ),
          const SizedBox(height: 12),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: counts.keys.map((k) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: brandColors[k], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 4),
                  Text(k, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  int _monthIndex(DateTime date, DateTime now) {
    final diff = (now.year - date.year) * 12 + (now.month - date.month);
    return 5 - diff; // index 0..5 where 0=5 months ago, 5=current month
  }

  // ─── 标签词云 ──────────────────────────────────────────────────────────

  Widget _buildTagCloud(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final tabs = <String>[];
    if (_showMovies) tabs.add('影视');
    if (_showBooks) tabs.add('书籍');
    if (_showNotes) tabs.add('笔记');
    if (tabs.isEmpty) return const SizedBox.shrink();

    // 确保 cloudTabIndex 在有效范围内
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
        // Tab 切换
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
        // 词云
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

class _CardData {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  _CardData(this.label, this.count, this.icon, this.color);
}
