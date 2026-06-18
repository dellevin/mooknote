import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../pages/stroll_page.dart';
import '../pages/markdown_reader/md_reader_tab_page.dart';
import '../pages/tag_management_page.dart';
import '../pages/profile_page.dart';
import '../pages/movies/movie_detail_page.dart';
import '../pages/book/book_detail_page.dart';
import '../pages/note/note_detail_page.dart';
import '../models/data_models.dart';
import 'fade_in_local_image.dart';

/// 自定义侧边栏
class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _version = '0.1.5';

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
    return Drawer(
      backgroundColor: colors.surfaceContainerHigh,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(context),
              const SizedBox(height: 16),
              _buildCalendarSection(context),
              const SizedBox(height: 16),
              _buildRecentSection(context),
              const SizedBox(height: 16),
              _buildToolsCard(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Center(
                  child: Text('v$_version', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.2))),
                ),
              ),
            ],
          ),
        ),
      ),
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

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(20),
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
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceContainerHighest,
                      border: Border.all(color: colors.outlineVariant, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarPath != null && avatarPath.isNotEmpty
                        ? FadeInLocalImage(path: avatarPath, fit: BoxFit.cover,
                            errorWidget: Icon(Icons.person_outline, size: 26, color: colors.onSurface.withValues(alpha: 0.3)))
                        : Icon(Icons.person_outline, size: 26, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nickname, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text(motto, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
              _buildProfileStatRow(Icons.movie_outlined, movieCount, '观影'),
              const SizedBox(height: 12),
              _buildProfileStatRow(Icons.menu_book_outlined, bookCount, '阅读'),
              const SizedBox(height: 12),
              _buildProfileStatRow(Icons.note_outlined, noteCount, '笔记'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileStatRow(IconData icon, int count, String label) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
        const Spacer(),
        Text(_formatCount(count), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 功能入口卡片 ────────────────────────────────────────────────────

  Widget _buildToolsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildToolItem(Icons.explore_outlined, '漫步', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StrollPage()));
          }, topRounded: true),
          Divider(height: 1, indent: 52, endIndent: 20, color: colors.outlineVariant),
          _buildToolItem(Icons.label_outline, '标签管理', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TagManagementPage()));
          }),
          Divider(height: 1, indent: 52, endIndent: 20, color: colors.outlineVariant),
          _buildToolItem(Icons.description_outlined, 'MD阅读', () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MdReaderTabPage()));
          }, bottomRounded: true),
        ],
      ),
    );
  }

  Widget _buildToolItem(IconData icon, String title, VoidCallback onTap, {bool topRounded = false, bool bottomRounded = false}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
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
            Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface))),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  // ─── 热力图 ──────────────────────────────────────────────────────────

  Widget _buildCalendarSection(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        final Map<DateTime, int> dailyCounts = {};
        for (final movie in provider.movies.where((m) => !m.isDeleted)) {
          final date = DateTime(movie.createdAt.year, movie.createdAt.month, movie.createdAt.day);
          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }
        for (final book in provider.books.where((b) => !b.isDeleted)) {
          final date = DateTime(book.createdAt.year, book.createdAt.month, book.createdAt.day);
          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }
        for (final note in provider.notes.where((n) => !n.isDeleted)) {
          final date = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }

        int maxCount = 0;
        for (final c in dailyCounts.values) {
          if (c > maxCount) maxCount = c;
        }
        if (maxCount == 0) maxCount = 1;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysSinceSunday = today.weekday % 7;
        final lastSunday = today.subtract(Duration(days: daysSinceSunday));

        const totalWeeks = 20;
        const weekDays = 7;
        const cellSize = 13.0;
        const cellGap = 3.0;

        final cells = List.generate(weekDays, (_) => List.generate(totalWeeks, (_) => 0));
        for (int week = 0; week < totalWeeks; week++) {
          for (int day = 0; day < weekDays; day++) {
            final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7 + (6 - day)));
            cells[day][week] = dailyCounts[date] ?? 0;
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
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: List.generate(totalWeeks, (week) {
                          final label = keepWeeks.contains(week) ? monthLabels[week] : null;
                          return SizedBox(
                            width: cellSize + cellGap,
                            child: label != null ? Text(label, style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))) : null,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ...List.generate(weekDays, (day) => Row(
                      children: List.generate(totalWeeks, (week) {
                        final count = cells[day][week];
                        return Container(
                          width: cellSize, height: cellSize,
                          margin: EdgeInsets.only(right: week < totalWeeks - 1 ? cellGap : 0, bottom: day < weekDays - 1 ? cellGap : 0),
                          decoration: BoxDecoration(color: _heatmapColor(count, maxCount), borderRadius: BorderRadius.circular(2)),
                        );
                      }),
                    )),
                  ],
                ),
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
      },
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
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        final recent = _getRecentItems(provider);
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
              ...recent.take(4).map((item) => InkWell(
                onTap: () => _openRecentItem(context, item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 2),
                  child: Row(
                    children: [
                      Icon(
                        item.type == 'movie' ? Icons.movie_outlined : item.type == 'book' ? Icons.menu_book_outlined : Icons.note_outlined,
                        size: 14, color: colors.onSurface.withValues(alpha: 0.3),
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
      },
    );
  }

  List<_RecentItem> _getRecentItems(AppProvider provider) {
    final items = <_RecentItem>[];
    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      items.add(_RecentItem(type: 'movie', title: m.title, date: m.createdAt, data: m));
    }
    for (final b in provider.books.where((b) => !b.isDeleted)) {
      items.add(_RecentItem(type: 'book', title: b.title, date: b.createdAt, data: b));
    }
    for (final n in provider.notes.where((n) => !n.isDeleted)) {
      items.add(_RecentItem(type: 'note', title: n.title.isNotEmpty ? n.title : '随手记', date: n.createdAt, data: n));
    }
    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  void _openRecentItem(BuildContext context, _RecentItem item) {
    Navigator.pop(context);
    switch (item.type) {
      case 'movie':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
      case 'book':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
      case 'note':
        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: item.data as Note)));
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
}

class _RecentItem {
  final String type;
  final String title;
  final DateTime date;
  final dynamic data;
  _RecentItem({required this.type, required this.title, required this.date, required this.data});
}
