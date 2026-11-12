import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../utils/lunar_calendar.dart';
import '../../widgets/fade_in_local_image.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';
import '../../l10n/app_strings.dart';

/// 书影日历 - 按月展示影视/书籍添加记录
class MediaCalendarPage extends StatefulWidget {
  const MediaCalendarPage({super.key});

  @override
  State<MediaCalendarPage> createState() => _MediaCalendarPageState();
}

class _MediaCalendarPageState extends State<MediaCalendarPage> {
  late DateTime _currentMonth;
  late int _currentYear;
  DateTime? _selectedDay;
  int _dateMode = 0; // 0: 创建日期, 1: 观看/开始阅读日期
  int _granularity = 0; // 日历粒度：0=月，1=年

  // PageView 基准页：该页对应当前真实月份/年份，向前后无限翻页
  static const int _kBasePage = 10000;
  late final PageController _monthController;
  late final PageController _yearController;
  int _monthPage = _kBasePage;
  int _yearPage = _kBasePage;

  int _monthPageOf(DateTime m) {
    final now = DateTime.now();
    return _kBasePage + (m.year - now.year) * 12 + (m.month - now.month);
  }

  /// 重建月历 controller，使其下次挂载时定位到当前月份页
  void _resetMonthController() {
    _monthController.dispose();
    _monthController = PageController(initialPage: _monthPage);
  }

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
    _currentYear = now.year;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _monthController = PageController(initialPage: _monthPage);
    _yearController = PageController(initialPage: _yearPage);
    _initData();
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
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

  // ─── 搜索：按作品名匹配日历记录，命中后跳到对应日期 ───

  Future<void> _openSearch() async {
    final entries = _dayItems.entries
        .expand((e) => e.value.map((item) => _SearchEntry(day: e.key, item: item)))
        .toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    final day = await Navigator.push<DateTime>(
      context,
      MaterialPageRoute(builder: (_) => _CalendarSearchPage(entries: entries)),
    );
    if (day != null && mounted) _jumpToDay(day);
  }

  /// 切到月视图并定位到指定日期（年视图下同样适用）
  void _jumpToDay(DateTime day) {
    final targetPage = _monthPageOf(DateTime(day.year, day.month));
    setState(() {
      _granularity = 0;
      _currentMonth = DateTime(day.year, day.month);
      _selectedDay = day;
      _monthPage = targetPage;
    });
    // 月视图已挂载时直接跳页；dispose 重建 controller 会导致已挂载的 PageView 不响应 initialPage
    if (_monthController.hasClients) {
      _monthController.jumpToPage(targetPage);
    } else {
      _resetMonthController();
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索'.tr,
            onPressed: _openSearch,
          ),
          _buildModeMenu(colors),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                _buildHeader(colors),
                const SizedBox(height: 12),
                Expanded(
                  child: _granularity == 0
                      ? _buildMonthMode(colors, today, constraints.maxWidth)
                      : _buildYearPager(colors),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── 头部：年月标题 + 月/年分段 ───

  Widget _buildHeader(ColorScheme colors) {
    final months = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    final title = _granularity == 0
        ? '{y}年{m}'.trf({'y': _currentMonth.year, 'm': months[_currentMonth.month - 1].tr})
        : '{y}年'.trf({'y': _currentYear});
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface, letterSpacing: 0.3),
          ),
        ),
        _segmented(
          colors,
          options: [('月'.tr, 0), ('年'.tr, 1)],
          current: _granularity,
          onChanged: (v) => setState(() => _granularity = v),
        ),
      ],
    );
  }

  Widget _segmented(
    ColorScheme colors, {
    required List<(String, int)> options,
    required int current,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, value) in options)
            GestureDetector(
              onTap: () => onChanged(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                decoration: BoxDecoration(
                  color: value == current ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: value == current
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: value == current ? FontWeight.w700 : FontWeight.w500,
                    color: value == current ? colors.onSurface : colors.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 月视图：横滑翻页 + 选中日详情 ───

  Widget _buildMonthMode(ColorScheme colors, DateTime today, double maxWidth) {
    final cellWidth = (maxWidth - 42) / 7;
    final cellHeight = (cellWidth * 1.24).clamp(54.0, 86.0);
    final items = _selectedDay == null ? <_CalendarItem>[] : (_dayItems[_selectedDay] ?? []);
    // 整体滚动：日历与下方记录同处一个滚动视图，上滑时日历一起滚走，而非只有列表滚动
    // PageView 会预构建相邻月份，相邻月可能有 6 行，高度须按最大 6 行预留，否则 6 行月份溢出
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildWeekdayLabels(colors),
          const SizedBox(height: 6),
          SizedBox(
            height: 6 * cellHeight,
            child: PageView.builder(
              controller: _monthController,
              onPageChanged: (page) {
                _monthPage = page;
                final now = DateTime.now();
                setState(() {
                  _currentMonth = DateTime(now.year, now.month + (page - _kBasePage));
                });
              },
              itemBuilder: (context, page) {
                final now = DateTime.now();
                final month = DateTime(now.year, now.month + (page - _kBasePage));
                return _buildMonthGrid(colors: colors, month: month, today: today, cellHeight: cellHeight);
              },
            ),
          ),
          // 选中日无记录时整个详情区不显示
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailHeader(colors, items.length),
            Divider(height: 1, color: colors.onSurface.withValues(alpha: 0.08)),
            for (var i = 0; i < items.length; i++) ...[
              _buildDetailRow(colors, items[i]),
              if (i != items.length - 1)
                Divider(height: 1, indent: 74, color: colors.onSurface.withValues(alpha: 0.06)),
            ],
            const SizedBox(height: 12),
          ],
        ],
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

  Widget _buildMonthGrid({
    required ColorScheme colors,
    required DateTime month,
    required DateTime today,
    required double cellHeight,
  }) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Column(
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
              final date = DateTime(month.year, month.month, day);
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
    final lunar = LunarCalendar.dayLabel(date);
    final highlighted = isToday || isSelected;

    // 边框规则：图片格始终描边（选中加粗主色，避免被封面盖住）；
    // 空白格仅选中日描边，今天只给淡色高亮不加框
    final Border? border = hasItems
        ? Border.all(
            color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.18),
            width: isSelected ? 2 : 1,
          )
        : (isSelected
            ? Border.all(color: colors.primary, width: 1.6)
            : null);
    final Color? bgColor = hasItems
        ? null
        : (isSelected
            ? colors.primary.withValues(alpha: 0.1)
            : (isToday ? colors.primary.withValues(alpha: 0.12) : null));

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: bgColor,
          border: border,
        ),
        child: hasItems
            ? _buildImageCell(colors, day, lunar, items, isToday)
            : Stack(
                children: [
                  if (isToday)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.star, size: 11, color: Color(0xFFFFD54F)),
                    ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                            color: highlighted
                                ? colors.primary
                                : colors.onSurface.withValues(alpha: 0.42),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          lunar,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                            color: highlighted
                                ? colors.primary.withValues(alpha: 0.75)
                                : colors.onSurface.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 层叠封面：最多露出 3 张，最前面一张完整显示，后面的依次上缩错位
  static const int _maxStackCovers = 3;

  Widget _buildImageCell(ColorScheme colors, int day, String lunar, List<_CalendarItem> items, bool isToday) {
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
        // 左下角日期药丸：公历日 + 农历
        Positioned(
          left: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isToday ? const Color(0xFFFFD54F) : Colors.white,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 34),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      lunar,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ],
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
        // 今日星星
        if (isToday)
          Positioned(
            top: 4, left: 5,
            child: Icon(Icons.star, size: 12, color: const Color(0xFFFFD54F),
                shadows: [Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 3)]),
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

  // ─── 年视图：横滑翻年，12 个月卡片 ───

  Widget _buildYearPager(ColorScheme colors) {
    return PageView.builder(
      controller: _yearController,
      onPageChanged: (page) {
        _yearPage = page;
        setState(() {
          _currentYear = DateTime.now().year + (page - _kBasePage);
        });
      },
      itemBuilder: (context, page) {
        final year = DateTime.now().year + (page - _kBasePage);
        return _buildYearView(colors, year);
      },
    );
  }

  List<_CalendarItem> _itemsOfMonth(int year, int month) {
    return _dayItems.entries
        .where((e) => e.key.year == year && e.key.month == month)
        .expand((e) => e.value)
        .toList();
  }

  Widget _buildYearView(ColorScheme colors, int year) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: 12,
      itemBuilder: (context, i) {
        final month = i + 1;
        final items = _itemsOfMonth(year, month);
        final covers = items.map((e) => e.path).toSet().take(4).toList();
        final now = DateTime.now();
        final isCurrentMonth = year == now.year && month == now.month;
        return GestureDetector(
          onTap: () => setState(() {
            _currentMonth = DateTime(year, month);
            _monthPage = _monthPageOf(_currentMonth);
            _resetMonthController();
            _granularity = 0;
          }),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: isCurrentMonth
                  ? Border.all(color: colors.primary.withValues(alpha: 0.6), width: 1.2)
                  : null,
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: covers.isEmpty
                        ? Container(color: colors.surface.withValues(alpha: 0.6))
                        : GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            padding: EdgeInsets.zero,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                            children: [
                              for (final path in covers)
                                FadeInLocalImage(path: path, fit: BoxFit.cover),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      '{m}月'.trf({'m': month}),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: items.isNotEmpty ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    const Spacer(),
                    if (isCurrentMonth)
                      const Icon(Icons.star, size: 12, color: Color(0xFFFFD54F))
                    else if (items.isNotEmpty)
                      Text(
                        '{n} 条'.trf({'n': items.length}),
                        style: TextStyle(fontSize: 11, color: colors.primary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 选中日期的详情（无记录时整块不渲染）───

  Widget _buildDetailHeader(ColorScheme colors, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Text(
            '{m}月{d}日'.trf({'m': _selectedDay!.month, 'd': _selectedDay!.day}),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface),
          ),
          const SizedBox(width: 8),
          Text(
            '{n}条记录'.trf({'n': count}),
            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(ColorScheme colors, _CalendarItem item) {
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

/// 搜索结果行：某条日历记录及其所在日期
class _SearchEntry {
  final DateTime day;
  final _CalendarItem item;

  _SearchEntry({required this.day, required this.item});
}

/// 日历记录搜索页：按作品名过滤，点击跳回对应日期
class _CalendarSearchPage extends StatefulWidget {
  final List<_SearchEntry> entries;

  const _CalendarSearchPage({required this.entries});

  @override
  State<_CalendarSearchPage> createState() => _CalendarSearchPageState();
}

class _CalendarSearchPageState extends State<_CalendarSearchPage> {
  String _keyword = '';
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kw = _keyword.toLowerCase();
    final results = kw.isEmpty
        ? widget.entries
        : widget.entries.where((e) => e.item.title.toLowerCase().contains(kw)).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          cursorColor: colors.primary,
          style: TextStyle(color: colors.onSurface, fontSize: 15),
          decoration: InputDecoration(
            hintText: '搜索影视、书籍或游戏'.tr,
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            isDense: true,
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
      body: results.isEmpty
          ? Center(
              child: Text(
                '未找到匹配的内容'.tr,
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) {
                final entry = results[i];
                final item = entry.item;
                final accent = _typeColor(item.type);
                return InkWell(
                  onTap: () => Navigator.pop(context, entry.day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 40,
                            height: 54,
                            child: FadeInLocalImage(
                              path: item.path,
                              fit: BoxFit.cover,
                              errorWidget: Container(
                                color: colors.surfaceContainerHighest,
                                child: Icon(Icons.image_outlined,
                                    size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration:
                                        BoxDecoration(color: accent, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(_typeLabel(item.type),
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurface.withValues(alpha: 0.45))),
                                  const SizedBox(width: 10),
                                  Text(
                                    '{m}月{d}日'.trf({'m': entry.day.month, 'd': entry.day.day}) +
                                        ' · {y}年'.trf({'y': entry.day.year}),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: colors.onSurface.withValues(alpha: 0.45)),
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
              },
            ),
    );
  }
}
