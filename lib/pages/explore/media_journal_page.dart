import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../l10n/app_strings.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';
import '../note/note_detail_page.dart';
import 'journal_poster_page.dart';

/// 岁阅：四类（影视/书籍/游戏/笔记）混合的月度/年度标记回顾
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
    // 笔记没有观看/阅读日期，两种模式都按创建时间
    for (final n in provider.notes) {
      if (n.isDeleted) continue;
      addRecord(
        date: n.createdAt,
        path: null,
        title: n.title.isEmpty ? n.content.split('\n').first : n.title,
        type: 'note',
        data: n,
        parentId: n.id,
      );
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

  void _prevPeriod() {
    setState(() {
      if (_granularity == 0) {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      } else {
        _currentYear -= 1;
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_granularity == 0) {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      } else {
        _currentYear += 1;
      }
    });
  }

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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('岁阅'.tr),
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
          PopupMenuButton<int>(
            tooltip: '日期类型'.tr,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: 0.75, end: 1.0)
                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                _dateMode == 0 ? Icons.event_note_outlined : Icons.history_rounded,
                key: ValueKey(_dateMode),
                color: colors.onSurface.withValues(alpha: 0.75),
              ),
            ),
            initialValue: _dateMode,
            onSelected: _setDateMode,
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 0,
                  child: Row(children: [
                    Icon(Icons.event_note_outlined,
                        size: 18,
                        color: _dateMode == 0 ? colors.primary : colors.onSurface.withValues(alpha: 0.55)),
                    const SizedBox(width: 10),
                    Text('创建日期'.tr),
                  ])),
              PopupMenuItem(
                  value: 1,
                  child: Row(children: [
                    Icon(Icons.history_rounded,
                        size: 18,
                        color: _dateMode == 1 ? colors.primary : colors.onSurface.withValues(alpha: 0.55)),
                    const SizedBox(width: 10),
                    Text('观看/阅读'.tr),
                  ])),
            ],
          ),
          IconButton(
            tooltip: '生成海报'.tr,
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _openPoster,
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: _viewMode == 0
                        ? (_granularity == 0 ? _buildMonthView(colors) : _buildYearView(colors))
                        : _buildTimelineView(colors),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── 顶部分段切换 ───

  Widget _buildSwitcher(ColorScheme colors) {
    return Row(
      children: [
        if (_viewMode == 0) ...[
          _segmented(
            colors,
            options: [('月'.tr, 0), ('年'.tr, 1)],
            current: _granularity,
            onChanged: (v) => setState(() => _granularity = v),
          ),
          const Spacer(),
        ] else
          const Spacer(),
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                decoration: BoxDecoration(
                  color: value == current ? colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: value == current
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
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

  Widget _buildMonthView(ColorScheme colors) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Column(
      children: [
        _buildPeriodHeader(colors),
        const SizedBox(height: 10),
        _buildWeekdayLabels(colors),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellWidth = (constraints.maxWidth - 36) / 7;
              final cellHeight = (cellWidth * 1.18).clamp(56.0, 92.0);
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMonthGrid(colors, today, cellHeight),
                    const SizedBox(height: 12),
                    _buildSelectedDayDetail(colors),
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

  Widget _buildPeriodHeader(ColorScheme colors) {
    return Row(
      children: [
        _circleNavButton(colors, Icons.chevron_left, _prevPeriod),
        Expanded(
          child: Text(
            _periodTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
              letterSpacing: 0.5,
            ),
          ),
        ),
        _circleNavButton(colors, Icons.chevron_right, _nextPeriod),
      ],
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

  Widget _buildMonthGrid(ColorScheme colors, DateTime today, double cellHeight) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final rows = ((startOffset + totalDays) / 7).ceil();
    final monthItems = _itemsOfMonth(_currentMonth.year, _currentMonth.month);

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
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isToday = date == today;
              final isSelected = _selectedDay == date;
              final items = monthItems[day] ?? [];
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: items.isEmpty
                          ? (isSelected ? colors.primary.withValues(alpha: 0.1) : null)
                          : colors.surfaceContainerHighest.withValues(alpha: 0.55),
                      border: isSelected
                          ? Border.all(color: colors.primary.withValues(alpha: 0.55), width: 1.4)
                          : null,
                    ),
                    child: items.isEmpty
                        ? Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                  color: isToday
                                      ? colors.primary
                                      : colors.onSurface.withValues(alpha: 0.42),
                                ),
                              ),
                            ),
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
        mosaic = Row(children: [
          Expanded(child: thumb(show[0])),
          const SizedBox(width: gap),
          Expanded(child: thumb(show[1])),
        ]);
      case 3:
        // 左列 1 张大图，右列上下 2 张
        mosaic = Row(children: [
          Expanded(child: thumb(show[0])),
          const SizedBox(width: gap),
          Expanded(
            child: Column(children: [
              Expanded(child: thumb(show[1])),
              const SizedBox(height: gap),
              Expanded(child: thumb(show[2])),
            ]),
          ),
        ]);
      default: // 4：2×2
        mosaic = Column(children: [
          Expanded(
            child: Row(children: [
              Expanded(child: thumb(show[0])),
              const SizedBox(width: gap),
              Expanded(child: thumb(show[1])),
            ]),
          ),
          const SizedBox(height: gap),
          Expanded(
            child: Row(children: [
              Expanded(child: thumb(show[2])),
              const SizedBox(width: gap),
              Expanded(child: thumb(show[3])),
            ]),
          ),
        ]);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          mosaic,
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
          // 日期药丸
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
        ],
      ),
    );
  }

  /// 封面缩略；无封面（笔记）用类型色 + 图标占位
  Widget _coverThumb(ColorScheme colors, JournalItem item, {double radius = 8}) {
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
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              Text(
                '{m}月{d}日'.trf({'m': d.month, 'd': d.day}),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.onSurface),
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
            padding: const EdgeInsets.symmetric(vertical: 24),
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

  Widget _buildRecordCard(ColorScheme colors, JournalItem item) {
    final accent = _typeColor(item.type);
    return InkWell(
      onTap: () => _openDetail(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 62,
              child: _coverThumb(colors, item, radius: 8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _typeLabel(item.type),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: accent),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
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

  Widget _buildYearView(ColorScheme colors) {
    return Column(
      children: [
        _buildPeriodHeader(colors),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            // 末尾 120 间距避让悬浮 dock（与"我的"页一致）
            padding: const EdgeInsets.only(bottom: 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: 12,
            itemBuilder: (context, i) {
              final month = i + 1;
              final monthItems = _itemsOfMonth(_currentYear, month);
              final covers = monthItems.values.expand((e) => e).take(4).toList();
              final count = _monthCount(_currentYear, month);
              return GestureDetector(
                onTap: () => setState(() {
                  _currentMonth = DateTime(_currentYear, month);
                  _granularity = 0;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Text(
                            '{m}月'.trf({'m': month}),
                            style: TextStyle(
                              fontSize: 14,
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
              padding: const EdgeInsets.only(top: 14, bottom: 8, left: 2),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
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

