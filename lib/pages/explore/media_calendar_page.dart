import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../movies/movie_detail_page.dart';
import '../movies/movie_form_page.dart';
import '../book/book_detail_page.dart';
import '../book/book_form_page.dart';

/// 书影日历 - 按月展示影视/书籍添加记录
class MediaCalendarPage extends StatefulWidget {
  const MediaCalendarPage({super.key});

  @override
  State<MediaCalendarPage> createState() => _MediaCalendarPageState();
}

class _MediaCalendarPageState extends State<MediaCalendarPage> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;

  // {DateTime(dayOnly): [{path, title, type, data}]}
  late Map<DateTime, List<_CalendarItem>> _dayItems;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _buildDayMap();
  }

  void _buildDayMap() {
    final provider = context.read<AppProvider>();
    final map = <DateTime, List<_CalendarItem>>{};

    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      if (m.posterPath == null || m.posterPath!.isEmpty) continue;
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      map.putIfAbsent(day, () => []);
      map[day]!.add(_CalendarItem(
        path: m.posterPath!,
        title: m.title,
        type: 'movie',
        data: m,
      ));
    }

    for (final b in provider.books.where((b) => !b.isDeleted)) {
      if (b.coverPath == null || b.coverPath!.isEmpty) continue;
      final day = DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);
      map.putIfAbsent(day, () => []);
      map[day]!.add(_CalendarItem(
        path: b.coverPath!,
        title: b.title,
        type: 'book',
        data: b,
      ));
    }

    _dayItems = map;
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('书影日历')),
      body: Column(
        children: [
          _buildMonthHeader(colors),
          _buildWeekdayLabels(colors),
          Expanded(
            child: _selectedDay != null && (_dayItems[_selectedDay]?.isNotEmpty ?? false)
                ? Column(
                    children: [
                      SingleChildScrollView(
                        child: _buildCalendarGrid(colors, today),
                      ),
                      Expanded(
                        child: _buildSelectedDayDetail(colors),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCalendarGrid(colors, today),
                        if (_selectedDay != null) _buildSelectedDayDetail(colors),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedDay != null
          ? FloatingActionButton(
              onPressed: () => _showAddMenu(context),
              backgroundColor: colors.primary,
              child: Icon(Icons.add, color: colors.onPrimary),
            )
          : null,
    );
  }

  // ─── 月份标题 ───

  Widget _buildMonthHeader(ColorScheme colors) {
    final months = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: Icon(Icons.chevron_left, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
          Expanded(
            child: Text(
              '${_currentMonth.year}年${months[_currentMonth.month - 1]}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface),
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  // ─── 星期头 ───

  Widget _buildWeekdayLabels(ColorScheme colors) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: weekdays.map((d) => Expanded(
          child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.35)))),
        )).toList(),
      ),
    );
  }

  // ─── 日历网格 ───

  static const double _cellHeight = 62;

  Widget _buildCalendarGrid(ColorScheme colors, DateTime today) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: List.generate(rows, (row) {
          return SizedBox(
            height: _cellHeight,
            child: Row(
              children: List.generate(7, (col) {
                final index = row * 7 + col;
                if (index < startOffset || index >= startOffset + totalDays) {
                  return const Expanded(child: SizedBox());
                }
                final day = index - startOffset + 1;
                final date = DateTime(_currentMonth.year, _currentMonth.month, day);
                final isToday = date == today;
                final isSelected = _selectedDay == date;
                final items = _dayItems[date] ?? [];
                return Expanded(child: _buildDayCell(colors, date, day, isToday, isSelected, items));
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayCell(ColorScheme colors, DateTime date, int day, bool isToday, bool isSelected, List<_CalendarItem> items) {
    final hasItems = items.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : hasItems
                  ? colors.surfaceContainerHigh
                  : null,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: colors.primary, width: 1.5)
              : isSelected
                  ? Border.all(color: colors.primary.withValues(alpha: 0.3), width: 1)
                  : null,
        ),
        child: hasItems
            ? _buildImageCell(colors, day, items, isToday)
            : Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                    color: isToday
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildImageCell(ColorScheme colors, int day, List<_CalendarItem> items, bool isToday) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: FileImage(File(items.first.path)),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: colors.surfaceContainerHighest,
              child: Center(child: Icon(Icons.image_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.2))),
            ),
          ),
          // 底部渐变 + 日期
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                ),
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? const Color(0xFFFFD54F) : Colors.white,
                ),
              ),
            ),
          ),
          // +N 标记
          if (items.length > 1)
            Positioned(
              top: 3, right: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('+${items.length - 1}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 选中日期的详情 ───

  Widget _buildSelectedDayDetail(ColorScheme colors) {
    final items = _dayItems[_selectedDay] ?? [];
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          '${_selectedDay!.month}月${_selectedDay!.day}日  暂无记录',
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Text(
                  '${_selectedDay!.month}月${_selectedDay!.day}日',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${items.length}条记录',
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 0.5, color: colors.outlineVariant),
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 40, height: 40,
                      child: Image(
                        image: FileImage(File(item.path)),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(Icons.image_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
                        ),
                      ),
                    ),
                  ),
                  title: Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.type == 'movie' ? const Color(0xFF4A90D9).withValues(alpha: 0.1) : const Color(0xFF7E57C2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.type == 'movie' ? '影视' : '书籍',
                      style: TextStyle(fontSize: 11, color: item.type == 'movie' ? const Color(0xFF4A90D9) : const Color(0xFF7E57C2)),
                    ),
                  ),
                  onTap: () {
                    if (item.type == 'movie') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('添加记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.movie_outlined, size: 20, color: const Color(0xFF4A90D9))),
            title: Text('添加影视', style: TextStyle(fontSize: 14, color: colors.onSurface)),
            subtitle: Text('记录一部影视作品', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieFormPage()));
            },
          ),
          Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.menu_book_outlined, size: 20, color: const Color(0xFF7E57C2))),
            title: Text('添加书籍', style: TextStyle(fontSize: 14, color: colors.onSurface)),
            subtitle: Text('记录一本书籍', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormPage()));
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

class _CalendarItem {
  final String path;
  final String title;
  final String type;
  final dynamic data;

  _CalendarItem({
    required this.path,
    required this.title,
    required this.type,
    required this.data,
  });
}
