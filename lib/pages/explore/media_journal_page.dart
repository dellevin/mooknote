import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/lunar_calendar.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../l10n/app_strings.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';
import '../note/note_detail_page.dart';
import 'journal_poster_page.dart';

/// 碎阅：四类（影视/书籍/游戏/笔记）混合的月度/年度标记回顾
/// 视图：日历（月/年）+ 时间轴；月度海报分享
class MediaJournalPage extends StatefulWidget {
  const MediaJournalPage({super.key});

  @override
  State<MediaJournalPage> createState() => _MediaJournalPageState();
}

class JournalItem {
  final String? path;
  final String title;
  final String type; // movie / book / game / note
  final dynamic data;
  final DateTime date;
  JournalItem({
    required this.path,
    required this.title,
    required this.type,
    required this.data,
    required this.date,
  });
}

class _MediaJournalPageState extends State<MediaJournalPage> {
  // 0=日历视图，1=时间轴视图
  int _viewMode = 0;
  // 日历粒度：0=月，1=年
  int _granularity = 0;

  late DateTime _currentMonth;
  late int _currentYear;
  DateTime? _selectedDay;

  bool _loading = true;
  final Map<DateTime, List<JournalItem>> _dayItems = {};

  // PageView 基准页：该页对应当前真实月份/年份，向前后无限翻页
  static const int _kBasePage = 10000;
  PageController? _monthController;
  PageController? _yearController;
  int _monthPage = _kBasePage;
  int _yearPage = _kBasePage;

  int _monthPageOf(DateTime m) {
    final now = DateTime.now();
    return _kBasePage + (m.year - now.year) * 12 + (m.month - now.month);
  }

  /// 重建指定粒度的 controller，使其下次挂载时定位到当前周期页
  void _resetController(int granularity) {
    if (granularity == 0) {
      _monthController?.dispose();
      _monthController = PageController(initialPage: _monthPage);
    } else {
      _yearController?.dispose();
      _yearController = PageController(initialPage: _yearPage);
    }
  }

  /// 回到当前真实日期：重置选中日，并把日历平滑滑回基准页
  void _backToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month);
      _currentYear = now.year;
      _selectedDay = DateTime(now.year, now.month, now.day);
      _monthPage = _kBasePage;
      _yearPage = _kBasePage;
    });
    final controller = _granularity == 0 ? _monthController : _yearController;
    if (controller != null && controller.hasClients) {
      controller.animateToPage(
        _kBasePage,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 底部功能面板：日期类型切换 + 生成海报
  Future<void> _openActionsSheet() async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget optionTile({
          required IconData icon,
          required String title,
          required String subtitle,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return Material(
            color: selected
                ? colors.primary.withValues(alpha: 0.1)
                : colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.45)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.15)
                            : colors.onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon,
                          size: 20,
                          color: selected
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: selected ? colors.primary : colors.onSurface,
                              )),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: colors.onSurface.withValues(alpha: 0.45),
                              )),
                        ],
                      ),
                    ),
                    Icon(
                      selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 21,
                      color: selected
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('日期类型'.tr,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface.withValues(alpha: 0.45))),
                ),
                const SizedBox(height: 10),
                optionTile(
                  icon: Icons.event_note_outlined,
                  title: '创建日期'.tr,
                  subtitle: '按影视、书籍、游戏的录入时间归格'.tr,
                  selected: _dateMode == 0,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setDateMode(0);
                  },
                ),
                const SizedBox(height: 8),
                optionTile(
                  icon: Icons.history_rounded,
                  title: '观看/阅读'.tr,
                  subtitle: '按观看、读完、通关的实际日期归格'.tr,
                  selected: _dateMode == 1,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setDateMode(1);
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openPoster();
                    },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_outlined, size: 19),
                    label: Text('生成海报'.tr,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<MovieEpisode> _episodes = [];
  List<BookChapter> _chapters = [];
  List<GameLevel> _levels = [];
  // 游戏通关记录（按游戏 id 分组），观看/阅读模式下使用
  Map<String, List<GameCompletion>> _completionMap = {};

  // 0=创建日期，1=观看/阅读日期；与书影日历共享同一份偏好
  int _dateMode = 0;

  static const _typeColors = <String, Color>{
    'movie': Color(0xFF4A90D9),
    'book': Color(0xFF7E57C2),
    'game': Color(0xFF66BB6A),
    'note': Color(0xFFE0A030),
  };

  Color _typeColor(String type) => _typeColors[type] ?? const Color(0xFF7E57C2);

  String _typeLabel(String type) => switch (type) {
        'movie' => '影视'.tr,
        'book' => '书籍'.tr,
        'game' => '游戏'.tr,
        _ => '笔记'.tr,
      };

  IconData _typeIcon(String type) => switch (type) {
        'movie' => Icons.movie_outlined,
        'book' => Icons.menu_book_outlined,
        'game' => Icons.sports_esports_outlined,
        _ => Icons.sticky_note_2_outlined,
      };

  AppProvider? _provider;
  bool _reloadScheduled = false;
  bool _dirtyDuringThrottle = false;
  DateTime? _lastLoadedAt;
  static const _reloadThrottle = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _dateMode = UserPrefs().calendarDateMode;
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _currentYear = now.year;
    _selectedDay = DateTime(now.year, now.month, now.day);
    _monthController = PageController(initialPage: _kBasePage);
    _yearController = PageController(initialPage: _kBasePage);
  }

  void _setDateMode(int mode) {
    if (_dateMode == mode) return;
    setState(() => _dateMode = mode);
    UserPrefs().setCalendarDateMode(mode);
    final provider = context.read<AppProvider>();
    if (mode == 1 && _completionMap.isEmpty) {
      provider.getGameCompletionsMap().then((map) {
        if (!mounted) return;
        _completionMap = map;
        setState(() => _buildDayMap(provider));
      });
    } else {
      setState(() => _buildDayMap(provider));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 页面常驻在首页 Stack 中：监听 provider，新增/删除标记后自动刷新
    final provider = context.read<AppProvider>();
    if (identical(_provider, provider)) return;
    _provider?.removeListener(_scheduleReload);
    _provider = provider..addListener(_scheduleReload);
    _loadData();
  }

  @override
  void dispose() {
    _provider?.removeListener(_scheduleReload);
    _monthController?.dispose();
    _yearController?.dispose();
    super.dispose();
  }

  /// 一帧内多次 notifyListeners 合并为一次刷新，避免连续 DB 查询
  void _scheduleReload() {
    if (_reloadScheduled || !mounted) return;
    final last = _lastLoadedAt;
    final elapsed = last == null ? _reloadThrottle : DateTime.now().difference(last);
    if (elapsed >= _reloadThrottle) {
      _kickReload();
    } else {
      // 节流窗口内：挂起一次，窗口结束后补刷，避免漏掉真正的增删
      _dirtyDuringThrottle = true;
      Future.delayed(_reloadThrottle - elapsed, () {
        if (mounted && _dirtyDuringThrottle && !_reloadScheduled) {
          _dirtyDuringThrottle = false;
          _kickReload();
        }
      });
    }
  }

  void _kickReload() {
    _reloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadScheduled = false;
      if (mounted) _loadData();
    });
  }

  Future<void> _loadData() async {
    _lastLoadedAt = DateTime.now();
    final provider = context.read<AppProvider>();
    final results = await Future.wait([
      provider.getAllMovieEpisodes(),
      provider.getAllBookChapters(),
      provider.getAllGameLevels(),
      if (_dateMode == 1)
        provider.getGameCompletionsMap()
      else
        Future.value(<String, List<GameCompletion>>{}),
    ]);
    if (!mounted) return;
    _episodes = results[0] as List<MovieEpisode>;
    _chapters = results[1] as List<BookChapter>;
    _levels = results[2] as List<GameLevel>;
    if (_dateMode == 1) {
      _completionMap = results[3] as Map<String, List<GameCompletion>>;
    }
    setState(() {
      _buildDayMap(provider);
      _loading = false;
    });
  }

  /// 按当前 _dateMode 归格：0=创建日期，1=观看/阅读日期（本地日）
  /// key 为去时分的 DateTime
  void _buildDayMap(AppProvider provider) {
    _dayItems.clear();
    DateTime dayOnly(DateTime d) {
      final local = d.toLocal();
      return DateTime(local.year, local.month, local.day);
    }

    final seen = <String>{};
    void addRecord({
      required DateTime? date,
      required String? path,
      required String title,
      required String type,
      required dynamic data,
      required String parentId,
    }) {
      if (date == null) return;
      final DateTime day = dayOnly(date);
      final key = '${day.toString()}|$type|$parentId';
      if (!seen.add(key)) return;
      _dayItems.putIfAbsent(day, () => []);
      _dayItems[day]!.add(JournalItem(
        path: path,
        title: title,
        type: type,
        data: data,
        date: date,
      ));
    }

    final byCreate = _dateMode == 0;

    for (final m in provider.movies) {
      if (m.isDeleted) continue;
      addRecord(
        date: byCreate ? m.createdAt : m.watchDate,
        path: (m.posterPath?.isNotEmpty ?? false) ? m.posterPath : null,
        title: m.title,
        type: 'movie',
        data: m,
        parentId: m.id,
      );
    }
    for (final b in provider.books) {
      if (b.isDeleted) continue;
      addRecord(
        date: byCreate ? b.createdAt : (b.finishDate ?? b.startDate),
        path: (b.coverPath?.isNotEmpty ?? false) ? b.coverPath : null,
        title: b.title,
        type: 'book',
        data: b,
        parentId: b.id,
      );
    }
    for (final g in provider.games) {
      if (g.isDeleted) continue;
      if (byCreate) {
        addRecord(
          date: g.createdAt,
          path: (g.coverPath?.isNotEmpty ?? false) ? g.coverPath : null,
          title: g.title,
          type: 'game',
          data: g,
          parentId: g.id,
        );
      } else {
        // 观看模式：每条通关记录各占一格
        for (final c in _completionMap[g.id] ?? const <GameCompletion>[]) {
          addRecord(
            date: c.completionDate,
            path: (g.coverPath?.isNotEmpty ?? false) ? g.coverPath : null,
            title: g.title,
            type: 'game',
            data: g,
            parentId: g.id,
          );
        }
      }
    }
    final movieById = {for (final m in provider.movies) m.id: m};
    final bookById = {for (final b in provider.books) b.id: b};
    final gameById = {for (final g in provider.games) g.id: g};

    for (final e in _episodes) {
      if (!e.watched) continue;
      final m = movieById[e.movieId];
      if (m == null || m.isDeleted) continue;
      addRecord(
        date: byCreate ? e.createdAt : e.watchDate,
        path: (m.posterPath?.isNotEmpty ?? false) ? m.posterPath : null,
        title: m.title,
        type: 'movie',
        data: m,
        parentId: m.id,
      );
    }
    for (final c in _chapters) {
      if (!c.read) continue;
      final b = bookById[c.bookId];
      if (b == null || b.isDeleted) continue;
      addRecord(
        date: byCreate ? c.createdAt : c.readDate,
        path: (b.coverPath?.isNotEmpty ?? false) ? b.coverPath : null,
        title: b.title,
        type: 'book',
        data: b,
        parentId: b.id,
      );
    }
    for (final l in _levels) {
      if (!l.cleared) continue;
      final g = gameById[l.gameId];
      if (g == null || g.isDeleted) continue;
      addRecord(
        date: byCreate ? l.createdAt : l.clearDate,
        path: (g.coverPath?.isNotEmpty ?? false) ? g.coverPath : null,
        title: g.title,
        type: 'game',
        data: g,
        parentId: g.id,
      );
    }
  }

  // ─── 导航 ───

  String get _periodTitle {
    if (_granularity == 0) {
      return '{y}年{m}月'.trf({'y': _currentMonth.year, 'm': _currentMonth.month});
    }
    return '{y}年'.trf({'y': _currentYear});
  }

  /// 某月的全部记录（按日归格的 map 过滤）
  Map<int, List<JournalItem>> _itemsOfMonth(int year, int month) {
    final result = <int, List<JournalItem>>{};
    _dayItems.forEach((day, items) {
      if (day.year == year && day.month == month) result[day.day] = items;
    });
    return result;
  }

  int _monthCount(int year, int month) =>
      _itemsOfMonth(year, month).values.fold<int>(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('碎阅'.tr),
            const SizedBox(height: 1),
            Text(
              '春生夏长，秋收冬藏'.tr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: colors.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        actions: [
          if (_viewMode == 0)
            IconButton(
              tooltip: '回到今天'.tr,
              icon: const Icon(Icons.today_outlined),
              onPressed: _backToToday,
            ),
          IconButton(
            tooltip: '更多'.tr,
            icon: const Icon(Icons.more_horiz),
            onPressed: _openActionsSheet,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              // 仅左右安全边距；dock 避让由各滚动视图末尾的 120 间距承担
              // （与“我的”页一致）
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _buildSwitcher(colors),
                  const SizedBox(height: 6),
                  Expanded(
                    child: _viewMode == 0
                        ? (_granularity == 0
                            ? _buildMonthPager(colors)
                            : _buildYearPager(colors))
                        : _buildTimelineView(colors),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── 顶部分段切换 ───

  Widget _buildSwitcher(ColorScheme colors) {
    // 左侧年月标题（仅日历视图），右侧月/年 + 日历/时间轴分段
    return Row(
      mainAxisAlignment:
          _viewMode == 0 ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (_viewMode == 0)
          Expanded(
            child: Text(
              _periodTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                letterSpacing: 0.3,
              ),
            ),
          ),
        if (_viewMode == 0) ...[
          _segmented(
            colors,
            options: [('月'.tr, 0), ('年'.tr, 1)],
            current: _granularity,
            onChanged: (v) => setState(() => _granularity = v),
          ),
          const SizedBox(width: 8),
        ],
        _segmented(
          colors,
          options: [('日历'.tr, 0), ('时间轴'.tr, 1)],
          current: _viewMode,
          onChanged: (v) => setState(() => _viewMode = v),
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
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4.5),
                decoration: BoxDecoration(
                  color: value == current ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: value == current
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: value == current ? FontWeight.w700 : FontWeight.w500,
                    color: value == current
                        ? colors.onSurface
                        : colors.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── 月视图 ───

  /// 月历翻页：跟手 PageView，每页一个月，基准页对应当前真实月份
  Widget _buildMonthPager(ColorScheme colors) {
    final now = DateTime.now();
    return PageView.builder(
      controller: _monthController,
      onPageChanged: (page) {
        _monthPage = page;
        setState(() {
          _currentMonth = DateTime(now.year, now.month + (page - _kBasePage));
        });
      },
      itemBuilder: (context, page) {
        final month = DateTime(now.year, now.month + (page - _kBasePage));
        return _buildMonthView(colors, month);
      },
    );
  }

  Widget _buildMonthView(ColorScheme colors, DateTime month) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Column(
      children: [
        _buildWeekdayLabels(colors),
        const SizedBox(height: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 36) / 7;
              final cellHeight = (cellWidth * 1.22).clamp(56.0, 92.0);
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMonthGrid(colors, today, cellHeight, month),
                    // 选中日详情只在其所属月份页展示，避免相邻预构建页重复
                    if (_selectedDay != null &&
                        _selectedDay!.year == month.year &&
                        _selectedDay!.month == month.month) ...[
                      const SizedBox(height: 8),
                      _buildSelectedDayDetail(colors),
                    ],
                    // 与"我的"页一致：滚动内容末尾留 120 避让悬浮 dock
                    const SizedBox(height: 120),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(ColorScheme colors) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: weekdays
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMonthGrid(ColorScheme colors, DateTime today, double cellHeight, DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final rows = ((startOffset + totalDays) / 7).ceil();
    final monthItems = _itemsOfMonth(month.year, month.month);

    return Column(
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
              final items = monthItems[day] ?? [];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    margin: const EdgeInsets.all(1.8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: items.isEmpty
                          ? (isSelected
                              ? colors.primary.withValues(alpha: 0.1)
                              : isToday
                                  ? colors.primary.withValues(alpha: 0.07)
                                  : null)
                          : colors.surfaceContainerHighest.withValues(alpha: 0.55),
                      border: isSelected
                          ? Border.all(color: colors.primary.withValues(alpha: 0.55), width: 1.4)
                          : isToday
                              ? Border.all(color: colors.primary.withValues(alpha: 0.8), width: 1.2)
                              : null,
                    ),
                    child: items.isEmpty
                        ? Stack(
                            children: [
                              if (isToday)
                                Positioned(
                                  right: 4,
                                  top: 3,
                                  child: Icon(Icons.star,
                                      size: 11, color: colors.primary),
                                ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '$day',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                          color: isToday
                                              ? colors.primary
                                              : colors.onSurface.withValues(alpha: 0.55),
                                        ),
                                      ),
                                      const SizedBox(height: 0.5),
                                      Text(
                                        LunarCalendar.dayLabel(date),
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: isToday ? FontWeight.w600 : FontWeight.w400,
                                          color: isToday
                                              ? colors.primary.withValues(alpha: 0.85)
                                              : colors.onSurface.withValues(alpha: 0.32),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _buildMosaicCell(colors, day, items, isToday),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  /// 封面拼贴格：1 张填满；2 张左右；3 张左一右二；4 张 2×2；超出显示 +N
  /// 笔记等无封面项用类型图标占位
  Widget _buildMosaicCell(ColorScheme colors, int day, List<JournalItem> items, bool isToday) {
    final show = items.take(4).toList();
    const gap = 1.5;
    Widget thumb(JournalItem item) => _coverThumb(colors, item, radius: 0);

    late final Widget mosaic;
    switch (show.length) {
      case 1:
        mosaic = thumb(show[0]);
      case 2:
        // stretch：交叉轴给紧约束，图片 cover 才能铺满半格而非按原比例留白
        mosaic = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: thumb(show[0])),
          const SizedBox(width: gap),
          Expanded(child: thumb(show[1])),
        ]);
      case 3:
        // 左列 1 张大图，右列上下 2 张
        mosaic = Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: thumb(show[0])),
          const SizedBox(width: gap),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: thumb(show[1])),
              const SizedBox(height: gap),
              Expanded(child: thumb(show[2])),
            ]),
          ),
        ]);
      default: // 4：2×2
        mosaic = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: thumb(show[0])),
              const SizedBox(width: gap),
              Expanded(child: thumb(show[1])),
            ]),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: thumb(show[2])),
              const SizedBox(width: gap),
              Expanded(child: thumb(show[3])),
            ]),
          ),
        ]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          mosaic,
          // 今日星标
          if (isToday)
            const Positioned(
              left: 4,
              top: 3,
              child: Icon(Icons.star, size: 13, color: Color(0xFFFFD54F),
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)]),
            ),
          // 超出 4 条的 +N 遮罩
          if (items.length > 4)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '+${items.length - 4}',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          // 日期药丸（今日：金色底 + 星标）
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isToday ? 5 : 6, vertical: 2),
              decoration: BoxDecoration(
                color: isToday
                    ? const Color(0xFFFFD54F)
                    : Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isToday) ...[
                    const Icon(Icons.star, size: 9, color: Color(0xFF5D4037)),
                    const SizedBox(width: 2),
                  ],
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isToday ? const Color(0xFF5D4037) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 封面缩略；无封面（笔记）用类型色 + 图标占位
  Widget _coverThumb(ColorScheme colors, JournalItem item, {double radius = 4}) {
    final content = item.path == null
        ? Container(
            color: _typeColor(item.type).withValues(alpha: 0.16),
            child: Center(
              child: Icon(_typeIcon(item.type), size: 18, color: _typeColor(item.type)),
            ),
          )
        : FadeInLocalImage(
            path: item.path!,
            fit: BoxFit.cover,
            duration: const Duration(milliseconds: 250),
            errorWidget: Container(
              color: colors.surfaceContainerHighest,
              child: Center(
                child: Icon(Icons.image_outlined,
                    size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
              ),
            ),
          );
    if (radius <= 0) return content;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: content);
  }

  // ─── 选中日详情 ───

  Widget _buildSelectedDayDetail(ColorScheme colors) {
    if (_selectedDay == null) return const SizedBox.shrink();
    final items = _dayItems[_selectedDay] ?? [];
    final d = _selectedDay!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Text(
                '{m}月{d}日'.trf({'m': d.month, 'd': d.day}),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
              ),
              const SizedBox(width: 8),
              Text(
                '{n} 条'.trf({'n': items.length}),
                style: TextStyle(fontSize: 12.5, color: colors.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '这天还没有标记'.tr,
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)),
              ),
            ),
          )
        else
          ...items.map((item) => _buildRecordCard(colors, item)),
      ],
    );
  }

  /// 记录卡次要信息：(评分, 导演/作者/开发者文本)
  (double?, String) _recordMeta(JournalItem item) {
    final dynamic data = item.data;
    return switch (item.type) {
      'movie' => (data.rating as double?, (data.directors as List).cast<String>().take(2).join(' / ')),
      'book' => (data.rating as double?, (data.authors as List).cast<String>().take(2).join(' / ')),
      'game' => (data.rating as double?, (data.developer as List).cast<String>().take(2).join(' / ')),
      _ => (null, ''),
    };
  }

  Widget _buildRecordCard(ColorScheme colors, JournalItem item) {
    final accent = _typeColor(item.type);
    final (rating, creators) = _recordMeta(item);
    final isWhole = rating == rating?.truncateToDouble();
    final ratingText = rating?.toStringAsFixed(isWhole ? 0 : 1);
    return InkWell(
      onTap: () => _openDetail(item),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 2),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 52,
              child: _coverThumb(colors, item, radius: 4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _typeLabel(item.type),
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: accent),
                        ),
                      ),
                      if (ratingText != null) ...[
                        const SizedBox(width: 7),
                        const Icon(Icons.star_rounded, size: 12.5, color: Color(0xFFE8A33D)),
                        const SizedBox(width: 2),
                        Text(ratingText,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface.withValues(alpha: 0.65))),
                      ],
                      if (creators.isNotEmpty) ...[
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            creators,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: colors.onSurface.withValues(alpha: 0.45)),
                          ),
                        ),
                      ],
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

  void _openDetail(JournalItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => switch (item.type) {
          'movie' => MovieDetailPage(movie: item.data as Movie),
          'book' => BookDetailPage(book: item.data as Book),
          'game' => GameDetailPage(game: item.data as Game),
          _ => NoteDetailPage(note: item.data as Note),
        },
      ),
    );
  }

  // ─── 年视图：12 个月卡片 ───

  /// 年历翻页：跟手 PageView，每页一年，基准页对应当前真实年份
  Widget _buildYearPager(ColorScheme colors) {
    final now = DateTime.now();
    return PageView.builder(
      controller: _yearController,
      onPageChanged: (page) {
        _yearPage = page;
        setState(() {
          _currentYear = now.year + (page - _kBasePage);
        });
      },
      itemBuilder: (context, page) {
        final year = now.year + (page - _kBasePage);
        return _buildYearView(colors, year);
      },
    );
  }

  Widget _buildYearView(ColorScheme colors, int year) {
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            // 末尾 120 间距避让悬浮 dock（与"我的"页一致）
            padding: const EdgeInsets.only(bottom: 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.88,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final month = i + 1;
              final monthItems = _itemsOfMonth(year, month);
              final covers = monthItems.values.expand((e) => e).take(4).toList();
              final count = _monthCount(year, month);
              return GestureDetector(
                onTap: () => setState(() {
                  _currentMonth = DateTime(year, month);
                  _monthPage = _monthPageOf(_currentMonth);
                  // 月历下次挂载时直接定位到所选月份
                  _resetController(0);
                  _granularity = 0;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: covers.isEmpty
                              ? Container(
                                  color: colors.surface.withValues(alpha: 0.6),
                                )
                              : GridView.count(
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: 2,
                                  padding: EdgeInsets.zero,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2,
                                  children: [
                                    for (final item in covers) _coverThumb(colors, item, radius: 0),
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: count > 0 ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '{n} 条'.trf({'n': count}),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: count > 0
                                  ? colors.primary
                                  : colors.onSurface.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
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

  // ─── 时间轴视图 ───

  Widget _buildTimelineView(ColorScheme colors) {
    final days = _dayItems.keys.toList()..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) {
      return Center(
        child: Text(
          '还没有任何标记'.tr,
          style: TextStyle(fontSize: 13.5, color: colors.onSurface.withValues(alpha: 0.35)),
        ),
      );
    }
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return ListView.builder(
      // 末尾 120 间距避让悬浮 dock（与"我的"页一致）
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final items = _dayItems[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '{m}月{d}日'.trf({'m': day.month, 'd': day.day}),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    weekdays[day.weekday - 1],
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                  ),
                  const Spacer(),
                  Text(
                    '{n} 条'.trf({'n': items.length}),
                    style: TextStyle(fontSize: 12.5, color: colors.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
            ...items.map((item) => _buildRecordCard(colors, item)),
          ],
        );
      },
    );
  }

  // ─── 月度海报 ───

  void _openPoster() {
    // 全量数据交给海报页，由其内部按月/年范围筛选
    final all = _dayItems.values.expand((e) => e).toList();
    if (all.isEmpty) {
      ToastUtil.show(context, '还没有标记，无法生成海报'.tr);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JournalPosterPage(
          anchorMonth: _currentMonth,
          items: all,
          typeColor: _typeColor,
          typeLabel: _typeLabel,
          typeIcon: _typeIcon,
        ),
      ),
    );
  }
}

