import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/fade_in_local_image.dart';
import '../movies/movie_detail_page.dart';
import '../movies/movie_form_page.dart';
import '../book/book_detail_page.dart';
import '../book/book_form_page.dart';
import '../game/game_detail_page.dart';
import '../game/game_form_page.dart';
import '../../widgets/app_overlay.dart';
import '../../l10n/app_strings.dart';

/// 书影日历 - 按月展示影视/书籍添加记录
class MediaCalendarPage extends StatefulWidget {
  const MediaCalendarPage({super.key});

  @override
  State<MediaCalendarPage> createState() => _MediaCalendarPageState();
}

class _MediaCalendarPageState extends State<MediaCalendarPage> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;
  int _dateMode = 0; // 0: 创建日期, 1: 观看/开始阅读日期

  // {DateTime(dayOnly): [{path, title, type, data}]}
  // 初始空表：数据在 _initData 异步加载完成后填充，避免首帧访问未初始化的 late 字段
  Map<DateTime, List<_CalendarItem>> _dayItems = {};

  // 游戏通关记录（按游戏 id 分组），供“观看/阅读”模式使用
  Map<String, List<GameCompletion>> _completionMap = {};

  // 分集/章节/关卡记录，两种日期模式都会入历（格子显示父作品封面）
  List<MovieEpisode> _episodes = [];
  List<BookChapter> _chapters = [];
  List<GameLevel> _levels = [];

  @override
  void initState() {
    super.initState();
    _dateMode = UserPrefs().calendarDateMode;
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _initData();
  }

  Future<void> _initData() async {
    final provider = context.read<AppProvider>();
    final results = await Future.wait([
      provider.getAllMovieEpisodes(),
      provider.getAllBookChapters(),
      provider.getAllGameLevels(),
      if (_dateMode == 1) provider.getGameCompletionsMap() else Future.value(<String, List<GameCompletion>>{}),
    ]);
    if (!mounted) return;
    _episodes = results[0] as List<MovieEpisode>;
    _chapters = results[1] as List<BookChapter>;
    _levels = results[2] as List<GameLevel>;
    if (_dateMode == 1) {
      _completionMap = results[3] as Map<String, List<GameCompletion>>;
    }
    setState(_buildDayMap);
  }

  void _buildDayMap() {
    final provider = context.read<AppProvider>();
    final map = <DateTime, List<_CalendarItem>>{};

    // 日期在库里统一存 UTC，日历按本地日期归格（UTC+8 凌晨的记录不应落到前一天/上月）
    DateTime dayOnly(DateTime d) {
      final local = d.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      if (m.posterPath == null || m.posterPath!.isEmpty) continue;
      final date = _dateMode == 1 ? m.watchDate : m.createdAt;
      if (date == null) continue;
      final day = dayOnly(date);
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
      final date = _dateMode == 1 ? b.startDate : b.createdAt;
      if (date == null) continue;
      final day = dayOnly(date);
      map.putIfAbsent(day, () => []);
      map[day]!.add(_CalendarItem(
        path: b.coverPath!,
        title: b.title,
        type: 'book',
        data: b,
      ));
    }

    for (final g in provider.games.where((g) => !g.isDeleted)) {
      if (g.coverPath == null || g.coverPath!.isEmpty) continue;
      if (_dateMode == 1) {
        // 观看/阅读模式：按每条通关记录的日期各占一格
        for (final c in _completionMap[g.id] ?? const <GameCompletion>[]) {
          final date = c.completionDate;
          final day = dayOnly(date);
          map.putIfAbsent(day, () => []);
          map[day]!.add(_CalendarItem(path: g.coverPath!, title: g.title, type: 'game', data: g));
        }
      } else {
        final date = g.createdAt;
        final day = dayOnly(date);
        map.putIfAbsent(day, () => []);
        map[day]!.add(_CalendarItem(path: g.coverPath!, title: g.title, type: 'game', data: g));
      }
    }

    // 分集/章节/关卡：仅已完成的记录入历，同一部作品同一天只显示一格封面
    final movieById = {for (final m in provider.movies) m.id: m};
    final bookById = {for (final b in provider.books) b.id: b};
    final gameById = {for (final g in provider.games) g.id: g};
    // 去重键：日期 + 类型 + 父作品 id
    final seenRecordKeys = <String>{};

    void addRecord({
      required DateTime? date,
      required String cover,
      required String title,
      required String type,
      required String parentId,
      required dynamic parent,
    }) {
      if (date == null) return;
      final day = dayOnly(date);
      final key = '${day.toIso8601String()}|$type|$parentId';
      if (!seenRecordKeys.add(key)) return;
      map.putIfAbsent(day, () => []);
      map[day]!.add(_CalendarItem(path: cover, title: title, type: type, data: parent));
    }

    for (final e in _episodes) {
      if (!e.watched) continue;
      final m = movieById[e.movieId];
      if (m == null || m.isDeleted || m.posterPath == null || m.posterPath!.isEmpty) continue;
      addRecord(
        date: _dateMode == 1 ? e.watchDate : e.createdAt,
        cover: m.posterPath!,
        title: m.title,
        type: 'movie',
        parentId: m.id,
        parent: m,
      );
    }
    for (final c in _chapters) {
      if (!c.read) continue;
      final b = bookById[c.bookId];
      if (b == null || b.isDeleted || b.coverPath == null || b.coverPath!.isEmpty) continue;
      addRecord(
        date: _dateMode == 1 ? c.readDate : c.createdAt,
        cover: b.coverPath!,
        title: b.title,
        type: 'book',
        parentId: b.id,
        parent: b,
      );
    }
    for (final l in _levels) {
      if (!l.cleared) continue;
      final g = gameById[l.gameId];
      if (g == null || g.isDeleted || g.coverPath == null || g.coverPath!.isEmpty) continue;
      addRecord(
        date: _dateMode == 1 ? l.clearDate : l.createdAt,
        cover: g.coverPath!,
        title: g.title,
        type: 'game',
        parentId: g.id,
        parent: g,
      );
    }

    _dayItems = map;
  }

  // 切月滑动方向：1=下一月（内容向左），-1=上一月（内容向右）
  int _slideDir = 1;

  Future<void> _setDateMode(int mode) async {
    if (_dateMode == mode) return;
    _dateMode = mode;
    UserPrefs().setCalendarDateMode(mode);
    if (mode == 1 && _completionMap.isEmpty) {
      _completionMap = await context.read<AppProvider>().getGameCompletionsMap();
      if (!mounted) return;
    }
    setState(_buildDayMap);
  }

  void _prevMonth() {
    setState(() {
      _slideDir = -1;
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _slideDir = 1;
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
      appBar: AppBar(
        title: Text('书影日历'.tr),
        actions: [_buildModeMenu(colors), const SizedBox(width: 6)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _buildMonthHeader(colors),
                const SizedBox(height: 12),
                _buildWeekdayLabels(colors),
                const SizedBox(height: 6),
                _buildCalendarArea(colors, today, constraints.maxWidth),
                const SizedBox(height: 12),
                Expanded(child: _buildSelectedDayDetail(colors)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _selectedDay != null
          ? Padding(
              // 避让首页悬浮 Dock 底栏（Dock 高 68 + 外围留白 + 安全区）
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 92),
              child: FloatingActionButton(
                onPressed: () => _showAddMenu(context),
                backgroundColor: colors.primary,
                child: Icon(Icons.add, color: colors.onPrimary),
              ),
            )
          : null,
    );
  }

  // ─── 月份标题 ───

  Widget _buildMonthHeader(ColorScheme colors) {
    final months = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        children: [
          _circleNavButton(colors, Icons.chevron_left, _prevMonth),
          Expanded(
            child: Text(
              '{y}年{m}'.trf({'y': _currentMonth.year, 'm': months[_currentMonth.month - 1].tr}),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: colors.onSurface, letterSpacing: 0.5),
            ),
          ),
          _circleNavButton(colors, Icons.chevron_right, _nextMonth),
        ],
      ),
    );
  }

  Widget _circleNavButton(ColorScheme colors, IconData icon, VoidCallback onTap) {
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: colors.onSurface.withValues(alpha: 0.65)),
        ),
      ),
    );
  }

  // ─── 日期模式（AppBar 右上角菜单）───

  Widget _buildModeMenu(ColorScheme colors) {
    return PopupMenuButton<int>(
      initialValue: _dateMode,
      tooltip: '日期类型'.tr,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          _dateMode == 0 ? Icons.event_note_outlined : Icons.history_rounded,
          key: ValueKey(_dateMode),
          color: colors.onSurface.withValues(alpha: 0.75),
        ),
      ),
      onSelected: _setDateMode,
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, child: _modeMenuRow(colors, Icons.event_note_outlined, '创建日期'.tr, 0)),
        PopupMenuItem(value: 1, child: _modeMenuRow(colors, Icons.history_rounded, '观看/阅读'.tr, 1)),
      ],
    );
  }

  Widget _modeMenuRow(ColorScheme colors, IconData icon, String label, int mode) {
    final active = _dateMode == mode;
    return Row(
      children: [
        Icon(icon, size: 18, color: active ? colors.primary : colors.onSurface.withValues(alpha: 0.55)),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? colors.primary : colors.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 16),
        Icon(
          active ? Icons.check_rounded : null,
          size: 18,
          color: colors.primary,
        ),
      ],
    );
  }

  // ─── 星期头 ───

  Widget _buildWeekdayLabels(ColorScheme colors) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Row(
      children: weekdays.map((d) => Expanded(
        child: Center(child: Text(d.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4)))),
      )).toList(),
    );
  }

  // ─── 日历网格 ───

  /// 日历区域：横滑切月 + 切月滑动淡入过渡
  Widget _buildCalendarArea(ColorScheme colors, DateTime today, double maxWidth) {
    // 外层 padding 12*2，7 格每格左右各 3px margin（共 42）
    final cellWidth = (maxWidth - 42) / 7;
    // 竖向长方形格子（接近海报感），高度随屏宽浮动并上下限幅
    final cellHeight = (cellWidth * 1.24).clamp(54.0, 86.0);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity;
        if (v == null) return;
        const threshold = 300.0;
        if (v < -threshold) {
          _nextMonth();
        } else if (v > threshold) {
          _prevMonth();
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          final begin = Offset(_slideDir * 0.12, 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(animation), child: child),
          );
        },
        child: _buildCalendarGrid(
          key: ValueKey('${_currentMonth.year}-${_currentMonth.month}'),
          colors: colors,
          today: today,
          cellHeight: cellHeight,
        ),
      ),
    );
  }

  Widget _buildCalendarGrid({
    Key? key,
    required ColorScheme colors,
    required DateTime today,
    required double cellHeight,
  }) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (row) {
        return SizedBox(
          height: cellHeight,
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
    );
  }

  Widget _buildDayCell(ColorScheme colors, DateTime date, int day, bool isToday, bool isSelected, List<_CalendarItem> items) {
    final hasItems = items.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          // 今天只以黄色日期突出；封面格不加选中底色/边框，只在空白格上给淡底色
          color: (hasItems || isToday)
              ? null
              : (isSelected ? colors.primary.withValues(alpha: 0.12) : null),
          border: (isSelected && !hasItems && !isToday)
              ? Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: hasItems
            ? _buildImageCell(colors, day, items, isToday)
            : Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                    color: isToday
                        ? const Color(0xFFFFD54F)
                        : colors.onSurface.withValues(alpha: 0.42),
                  ),
                ),
              ),
      ),
    );
  }

  /// 层叠封面：最多露出 3 张，最前面一张完整显示，后面的依次上缩错位
  static const int _maxStackCovers = 3;

  Widget _buildImageCell(ColorScheme colors, int day, List<_CalendarItem> items, bool isToday) {
    final accent = _typeColor(items.first.type);
    final showCount = items.length.clamp(1, _maxStackCovers);
    // 扇形牌堆：多张时后面的牌向上和两侧伸出，前景封面缩小压底；单张填满整格
    // (left, right, top, bottom, 旋转弧度)
    const backOffsets2 = <(double, double, double, double, double)>[
      (9.0, -7.0, 1.0, 8.0, 0.13),   // 2 张：后牌向右上伸出
    ];
    const backOffsets3 = <(double, double, double, double, double)>[
      (-7.0, 9.0, 4.0, 12.0, -0.16), // 3 张：最靠后向左上伸出
      (9.0, -7.0, 1.0, 8.0, 0.13),   // 中间向右上伸出
    ];
    final stackCards = <Widget>[];
    final backOffsets = showCount == 3 ? backOffsets3 : (showCount == 2 ? backOffsets2 : null);
    if (backOffsets != null) {
      for (final o in backOffsets) {
        final (left, right, top, bottom, angle) = o;
        stackCards.add(Positioned(
          left: left,
          right: right,
          top: top,
          bottom: bottom,
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.bottomCenter,
            child: _coverCard(colors, items[stackCards.length].path),
          ),
        ));
      }
    }
    // 前景封面：多张时缩小压底，单张时填满整格（且不要卡片边框）
    final frontInset = showCount > 1 ? (2.0, 2.0, 13.0, 0.0) : (0.0, 0.0, 0.0, 0.0);
    stackCards.add(Positioned(
      left: frontInset.$1,
      right: frontInset.$2,
      top: frontInset.$3,
      bottom: frontInset.$4,
      child: _coverCard(colors, items[showCount - 1].path, framed: showCount > 1),
    ));

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ...stackCards,
        // 前景封面上的日期/角标层
        Positioned(
          left: 0, right: 0, bottom: 0, height: 26,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
              ),
            ),
          ),
        ),
        // 左下角日期药丸
        Positioned(
          left: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isToday ? const Color(0xFFFFD54F) : Colors.white,
              ),
            ),
          ),
        ),
        // +N 标记（超出层叠数量的部分）
        if (items.length > _maxStackCovers)
          Positioned(
            top: 5, right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Text('+${items.length - _maxStackCovers}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        // 今日圆点
        if (isToday)
          Positioned(
            top: 5, left: 5,
            child: Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD54F),
                border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 0.8),
              ),
            ),
          ),
      ],
    );
  }

  Widget _coverCard(ColorScheme colors, String path, {bool framed = true}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: framed ? Border.all(color: colors.surface.withValues(alpha: 0.9), width: 1.2) : null,
        boxShadow: framed
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 3, offset: const Offset(0, 1))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: FadeInLocalImage(
          path: path,
          fit: BoxFit.cover,
          duration: const Duration(milliseconds: 250),
          errorWidget: Container(
            color: colors.surfaceContainerHighest,
            child: Center(child: Icon(Icons.image_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.2))),
          ),
        ),
      ),
    );
  }

  // ─── 选中日期的详情 ───

  Widget _buildSelectedDayDetail(ColorScheme colors) {
    if (_selectedDay == null) {
      return const SizedBox.shrink();
    }
    final items = _dayItems[_selectedDay] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 扁平小标题：日期 + 灰色记录数，无药丸底色
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Text(
                '{m}月{d}日'.trf({'m': _selectedDay!.month, 'd': _selectedDay!.day}),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              const SizedBox(width: 8),
              Text(
                '{n}条记录'.trf({'n': items.length}),
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.onSurface.withValues(alpha: 0.08)),
        Expanded(
          child: items.isEmpty
              ? _buildEmptyDetail(colors)
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 74, color: colors.onSurface.withValues(alpha: 0.06)),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final accent = _typeColor(item.type);
                    return InkWell(
                      onTap: () {
                          if (item.type == 'movie') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
                          } else if (item.type == 'book') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailPage(game: item.data as Game)));
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          child: Row(
                            children: [
                              // 2:3 海报缩略卡
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 46,
                                  height: 62,
                                  child: FadeInLocalImage(
                                    path: item.path,
                                    fit: BoxFit.cover,
                                    duration: const Duration(milliseconds: 250),
                                    errorWidget: Container(
                                      color: colors.surfaceContainerHighest,
                                      child: Icon(Icons.image_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 7, height: 7,
                                          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(_typeLabel(item.type), style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        ),
        ],
    );
  }

  Widget _buildEmptyDetail(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.18)),
          const SizedBox(height: 10),
          Text(
            '这一天还没有记录'.tr,
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) => switch (type) {
        'movie' => const Color(0xFF4A90D9),
        'game' => const Color(0xFF66BB6A),
        _ => const Color(0xFF7E57C2),
      };

  String _typeLabel(String type) => switch (type) {
        'movie' => '影视'.tr,
        'game' => '游戏'.tr,
        _ => '书籍'.tr,
      };

  void _showAddMenu(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('添加记录'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.movie_outlined, size: 20, color: Color(0xFF4A90D9))),
            title: Text('添加影视'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface)),
            subtitle: Text('记录一部影视作品'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
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
                child: const Icon(Icons.menu_book_outlined, size: 20, color: Color(0xFF7E57C2))),
            title: Text('添加书籍'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface)),
            subtitle: Text('记录一本书籍'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormPage()));
            },
          ),
          Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sports_esports_outlined, size: 20, color: Color(0xFF66BB6A))),
            title: Text('添加游戏'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface)),
            subtitle: Text('记录一款游戏'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GameFormPage()));
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
