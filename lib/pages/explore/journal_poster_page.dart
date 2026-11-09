import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';
import 'media_journal_page.dart';

/// 月度海报工作台：布局/筛选/元素可编辑，截图后系统分享
class JournalPosterPage extends StatefulWidget {
  final DateTime anchorMonth;
  final List<JournalItem> items;
  final Color Function(String) typeColor;
  final String Function(String) typeLabel;
  final IconData Function(String) typeIcon;

  const JournalPosterPage({
    super.key,
    required this.anchorMonth,
    required this.items,
    required this.typeColor,
    required this.typeLabel,
    required this.typeIcon,
  });

  @override
  State<JournalPosterPage> createState() => _JournalPosterPageState();
}

class _JournalPosterPageState extends State<JournalPosterPage> {
  final _posterKey = GlobalKey();
  bool _generating = false;
  bool _capturing = false; // 截图期间隐藏编辑角标

  // 0=海报网格 1=列表 2=海报墙(斜) 3=海报墙(小)
  int _layout = 0;
  int _bottomTab = 0; // 0=分享 1=布局 2=筛选 3=元素

  // 海报范围：0=月，1=年；_anchor 记录当前所在月/年
  int _scope = 0;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _anchor = DateTime(widget.anchorMonth.year, widget.anchorMonth.month);
  }

  void _shiftPeriod(int delta) {
    setState(() {
      _anchor = _scope == 0
          ? DateTime(_anchor.year, _anchor.month + delta)
          : DateTime(_anchor.year + delta, _anchor.month);
      _excluded.clear();
      _slotPicks.clear();
    });
  }

  /// 当前范围（月/年）内的记录
  List<JournalItem> get _scopedItems {
    return widget.items.where((e) {
      final d = e.date.toLocal();
      if (_scope == 1) return d.year == _anchor.year;
      return d.year == _anchor.year && d.month == _anchor.month;
    }).toList();
  }

  final Set<String> _activeTypes = {'movie', 'book', 'game', 'note'};
  final Set<int> _excluded = <int>{}; // 被手动移除的原始下标
  // 各布局下每个格位手动选中的 _filtered 下标；未设置时按 slot % count 循环
  final Map<int, List<int?>> _slotPicks = {};

  bool _showTitle = true;
  bool _showStats = true;
  bool _showRating = false;
  bool _showCalendar = false;
  bool _showBrand = true;

  static const _bg = Color(0xFFFBF7EF);
  static const _ink = Color(0xFF2B2620);

  List<JournalItem> get _filtered => [
        for (var i = 0; i < widget.items.length; i++)
          if (!_excluded.contains(i) &&
              _activeTypes.contains(widget.items[i].type) &&
              _scopedItems.contains(widget.items[i]))
            widget.items[i],
      ];

  String get _periodText => _scope == 0
      ? '{y}年{m}月'.trf({'y': _anchor.year, 'm': _anchor.month})
      : '{y}年'.trf({'y': _anchor.year});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('海报'.tr)),
      body: Column(
        children: [
          _buildScopeBar(colors),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(key: _posterKey, child: _buildPoster()),
            ),
          ),
          if (_excluded.isNotEmpty) _buildRestoreBar(colors),
          _buildBottomPanel(colors),
        ],
      ),
    );
  }

  // ─── 范围切换（月/年 + 周期导航，不属于截图内容）───

  Widget _buildScopeBar(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Row(
        children: [
          _circleNav(colors, Icons.chevron_left, () => _shiftPeriod(-1)),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (label, value) in [('月海报'.tr, 0), ('年海报'.tr, 1)])
                      GestureDetector(
                        onTap: () => setState(() {
                          _scope = value;
                          _excluded.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 7),
                          decoration: BoxDecoration(
                            color: _scope == value
                                ? colors.surface
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: _scope == value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _scope == value
                                  ? colors.onSurface
                                  : colors.onSurface.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _circleNav(colors, Icons.chevron_right, () => _shiftPeriod(1)),
        ],
      ),
    );
  }

  Widget _circleNav(ColorScheme colors, IconData icon, VoidCallback onTap) {
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

  // ─── 海报预览 ───

  Widget _buildPoster() {
    final filtered = _filtered;
    return Container(
      decoration:
          BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_showTitle)
            Text(
              '$_periodText${'海报墙'.tr}',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: _ink),
            ),
          if (_showTitle) const SizedBox(height: 14),
          if (_showStats) _buildStats(filtered),
          if (_showStats) const SizedBox(height: 20),
          if (_showCalendar && _scope == 0) ...[
            _buildMiniCalendar(filtered),
            const SizedBox(height: 20)
          ],
          filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      '当前筛选下没有标记'.tr,
                      style: TextStyle(
                          fontSize: 13, color: _ink.withValues(alpha: 0.4)),
                    ),
                  ),
                )
              : _DeferredBody(
                  // 布局/数据量变化时重建：先画加载动画，下一帧再构建重内容，
                  // 避免大量海报同帧构建导致切换卡死
                  key: ValueKey('body-$_layout-${filtered.length}'),
                  child: switch (_layout) {
                    1 => _buildListBody(filtered),
                    2 => _buildWall(filtered, 104),
                    3 => _buildWall(filtered, 72),
                    _ => _buildGridBody(filtered),
                  },
                ),
          if (_showBrand) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon/app_icon.webp',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MookNote',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    Text('简洁的书影管理工具'.tr,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: _ink.withValues(alpha: 0.45))),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(List<JournalItem> filtered) {
    final counts = <String, int>{};
    for (final i in filtered) {
      counts[i.type] = (counts[i.type] ?? 0) + 1;
    }
    const units = {'movie': '部影视', 'book': '本书', 'game': '款游戏', 'note': '条笔记'};
    final spans = <InlineSpan>[
      TextSpan(text: (_scope == 0 ? '这个月你标记了' : '这一年你标记了').tr),
    ];
    final active = counts.entries.where((e) => e.value > 0).toList();
    for (var i = 0; i < active.length; i++) {
      final type = active[i].key;
      spans.add(TextSpan(
        text: ' ${active[i].value} ',
        style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: widget.typeColor(type)),
      ));
      spans.add(TextSpan(text: units[type]!.tr));
      if (i < active.length - 1) spans.add(const TextSpan(text: '、'));
    }
    if (active.isEmpty) spans.add(TextSpan(text: '0 '.tr));
    return Text.rich(
      TextSpan(
        style: const TextStyle(
            fontSize: 15.5, fontWeight: FontWeight.w600, color: _ink),
        children: spans,
      ),
    );
  }

  /// 卡片/列表的最小框位：数据不足时循环补齐到卡片 12 格、列表 6 行；
  /// 数据更多时展示全部数据，每格都可删除/换封面。
  static const _minGridSlots = 12;
  static const _minListSlots = 6;

  Widget _buildGridBody(List<JournalItem> filtered) {
    const cols = 3;
    const layoutKey = 0;
    final slotCount = math.max(_minGridSlots, filtered.length);
    final slotItems = [
      for (var slot = 0; slot < slotCount; slot++)
        _slotItem(filtered, layoutKey, slot),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileW = (constraints.maxWidth - 12) / 3;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.72,
          children: [
            for (var slot = 0; slot < slotItems.length; slot++)
              Stack(fit: StackFit.expand, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _posterImage(slotItems[slot], tileW),
                ),
                if (_ratingBadge(slotItems[slot]) != null)
                  _ratingBadge(slotItems[slot])!,
                if (!_capturing) ...[
                  _replaceBadge(
                      () => _pickSlotCover(filtered, layoutKey, slot)),
                  _editBadge(() => _removeItem(slotItems[slot])),
                ],
              ]),
          ],
        );
      },
    );
  }

  Widget _buildListBody(List<JournalItem> filtered) {
    const layoutKey = 1;
    final slotCount = math.max(_minListSlots, filtered.length);
    final slots = [
      for (var i = 0; i < slotCount; i++) _slotItem(filtered, layoutKey, i),
    ];
    return Column(
      children: [
        for (var slot = 0; slot < slots.length; slot++)
          Builder(builder: (context) {
            final item = slots[slot];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 54,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: _posterImage(item, 40)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _ink),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: widget
                                    .typeColor(item.type)
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                widget.typeLabel(item.type),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: widget.typeColor(item.type)),
                              ),
                            ),
                            if (_showRating &&
                                item.type != 'note' &&
                                (item.data as dynamic).rating != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.star_rounded,
                                  size: 13, color: Color(0xFFE8A33D)),
                              const SizedBox(width: 2),
                              Text(
                                _ratingText(item),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _ink.withValues(alpha: 0.55)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!_capturing) ...[
                    GestureDetector(
                      onTap: () => _pickSlotCover(filtered, layoutKey, slot),
                      child: Tooltip(
                        message: '选择封面'.tr,
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.swap_horiz_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeItem(item),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                            color: Color(0xFFE53935), shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 15, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  /// 斜海报墙；tileW 为固定瓦片宽（斜=大、小=密），不随条目数缩小。
  /// 框高取数据自然堆叠高度（未旋转的行高之和），旋转网格按“整框严格内含
  /// 于旋转矩形”的充要条件反向扩列/扩行（循环复用海报），保证框内零留白；
  /// 网格旋转外接框高出框的部分由 ClipRRect 裁掉（与片单海报墙一致）。
  /// 瓦片数动态上限 = max(100, 各候选角度容纳自然框高所需网格的最大值)：
  /// 保证每条有封面的数据至少上墙一次且框内零留白；
  /// 配合 _DeferredBody 避免同帧卡顿。
  static const _minWallTiles = 100;

  /// 海报墙左右安全边距：框边不再腰斩瓦片，露出细窄底色呼吸条
  static const _wallSidePadding = 14.0;
  // 从浅到深的倾角候选（弧度，约 14°~29°）
  static const _wallAngles = [0.24, 0.32, 0.40, 0.50];

  Widget _buildWall(List<JournalItem> filtered, double tileW) {
    if (filtered.isEmpty) return const SizedBox.shrink();
    const spacing = 10.0;
    final tileH = tileW * 1.38;
    // 海报墙只循环有封面的条目：无封面（如纯文字笔记）在墙上只能画占位块，
    // 数据量大时会出现大片空白；它们仍计入统计文案和卡片/列表。
    // 全部条目都没封面时回退全量，避免整面空墙。
    final withCover = filtered.where((e) => e.path != null).toList();
    final unique = withCover.isNotEmpty ? withCover : filtered;

    return LayoutBuilder(
      builder: (context, constraints) {
        final frameW = constraints.maxWidth - 2 * _wallSidePadding;
        final count = unique.length;
        final baseCols =
            math.max(1, ((frameW + spacing) / (tileW + spacing)).floor());
        // 全部数据的自然行数，框高随数据量自然增长
        final naturalRows = (count / baseCols).ceil();
        final targetFrameH = naturalRows * tileH;
        // 动态瓦片上限：按整框内含的充要条件，算出每个候选角度下容纳自然
        // 框高所需的网格规模，取最大值——保证求解器一定能在某档角度收敛，
        // 全部数据至少上墙一次，且不产生无意义的超额瓦片。
        var tileCap = math.max(_minWallTiles, naturalRows * baseCols);
        for (final a in _wallAngles) {
          final needCols =
              ((frameW * math.cos(a) + targetFrameH * math.sin(a) + spacing) /
                      (tileW + spacing))
                  .ceil();
          final needRows =
              ((frameW * math.sin(a) + targetFrameH * math.cos(a) + spacing) /
                      (tileH + spacing))
                  .ceil();
          tileCap = math.max(tileCap, needCols * needRows);
        }

        // 整框（Fw×Fh）内含于旋转网格（W×H，旋转角 a）的充要条件：
        //   Fw·cos + Fh·sin ≤ W 且 Fw·sin + Fh·cos ≤ H
        // 反解给定网格能容纳的最大框高，哪个方向是瓶颈就扩对应的列/行；
        // 格子数超上限即放弃该角度、升级倾角。
        late double angle;
        late int cols;
        late int rows;
        late double frameH;
        var solved = false;
        for (final a in _wallAngles) {
          final ca = math.cos(a);
          final sa = math.sin(a);
          var c = baseCols;
          var r = naturalRows;
          for (var i = 0; i < 200; i++) {
            final w = c * tileW + (c - 1) * spacing;
            final h = r * tileH + (r - 1) * spacing;
            // 前置条件：网格先得比框的投影宽/高，否则反解出负框高
            if (w <= frameW * ca || h <= frameW * sa) {
              if (w <= frameW * ca) {
                c++;
              } else {
                r++;
              }
              if (c * r > tileCap) break;
              continue;
            }
            final limitByW = (w - frameW * ca) / sa;
            final limitByH = (h - frameW * sa) / ca;
            final maxFrameH = math.min(limitByW, limitByH);
            if (maxFrameH >= targetFrameH - 0.5) {
              angle = a;
              cols = c;
              rows = r;
              frameH = targetFrameH;
              solved = true;
              break;
            }
            if (limitByW < limitByH) {
              c++;
            } else {
              r++;
            }
            if (c * r > tileCap) break;
          }
          if (solved) break;
        }
        // 兜底（理论不可达：tileCap 已覆盖各角度的理论网格）：
        // 按最陡角度的理论网格构建，框高保持自然高度不收缩
        if (!solved) {
          angle = _wallAngles.last;
          final ca = math.cos(angle);
          final sa = math.sin(angle);
          cols =
              ((frameW * ca + targetFrameH * sa + spacing) / (tileW + spacing))
                  .ceil();
          rows =
              ((frameW * sa + targetFrameH * ca + spacing) / (tileH + spacing))
                  .ceil();
          frameH = targetFrameH;
        }
        final need = math.min(tileCap, cols * rows);

        Widget tile(int index) {
          final item = unique[index % count];
          return SizedBox(
            width: tileW,
            height: tileH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: _posterImage(item, tileW),
                ),
                if (_ratingBadge(item) != null) _ratingBadge(item)!,
                // 循环副本同样可移除：移除的是同一条数据，其所有副本一起消失
                if (!_capturing) _editBadge(() => _removeItem(item)),
              ],
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _wallSidePadding),
            // OverflowBox 允许子节点画到自身边界外，必须在此处再裁一道，
            // 旋转网格的绘制才会被限制在带安全边距的内框内
            child: ClipRect(
              child: SizedBox(
                height: frameH,
                child: OverflowBox(
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  alignment: Alignment.center,
                  child: Transform.rotate(
                    angle: -angle,
                    child: SizedBox(
                      width: cols * tileW + (cols - 1) * spacing,
                      height: rows * tileH + (rows - 1) * spacing,
                      child: Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (var i = 0; i < need; i++) tile(i),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniCalendar(List<JournalItem> filtered) {
    final y = _anchor.year;
    final m = _anchor.month;
    final offset = DateTime(y, m, 1).weekday - 1;
    final days = DateTime(y, m + 1, 0).day;
    final marked = {for (final e in filtered) e.date.toLocal().day};
    final cells = <Widget>[];
    for (var i = 0; i < offset; i++) {
      cells.add(const Expanded(child: SizedBox(height: 30)));
    }
    for (var d = 1; d <= days; d++) {
      final isMarked = marked.contains(d);
      cells.add(Expanded(
        child: SizedBox(
          height: 30,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: isMarked
                  ? BoxDecoration(
                      color: _ink, borderRadius: BorderRadius.circular(7))
                  : null,
              child: Center(
                child: Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isMarked ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isMarked ? Colors.white : _ink.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
    }
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, (i + 7).clamp(0, cells.length))));
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: rows),
    );
  }

  /// 海报页三种布局共用的静态图：无 AnimationController、无异步文件检查，
  /// 同路径直接复用 ImageCache；cacheWidth 按显示像素限制解码尺寸。
  /// tileW 为逻辑像素的显示宽度。
  Widget _posterImage(JournalItem item, double tileW) {
    if (item.path == null) {
      return Container(
        color: widget.typeColor(item.type).withValues(alpha: 0.16),
        child: Center(
          child: Icon(widget.typeIcon(item.type),
              size: 22, color: widget.typeColor(item.type)),
        ),
      );
    }
    final cacheW = (tileW * MediaQuery.devicePixelRatioOf(context)).round();
    final errorWidget = Container(
      color: Colors.white.withValues(alpha: 0.6),
      child: Icon(Icons.image_outlined,
          size: 20, color: _ink.withValues(alpha: 0.25)),
    );
    final path = item.path!;
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        errorBuilder: (_, __, ___) => errorWidget,
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheW,
      errorBuilder: (_, __, ___) => errorWidget,
    );
  }

  Widget _editBadge(VoidCallback onRemove) {
    return Positioned(
      top: 4,
      right: 4,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
              color: Color(0xFFE53935), shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 14, color: Colors.white),
        ),
      ),
    );
  }

  /// 封面底部评分角标（网格/海报墙共用）；无评分或笔记类型返回 null
  Widget? _ratingBadge(JournalItem item) {
    if (!_showRating || item.type == 'note') return null;
    final r = (item.data as dynamic).rating as double?;
    if (r == null) return null;
    return Positioned(
      left: 4,
      bottom: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 10, color: Color(0xFFFFD54F)),
            const SizedBox(width: 1.5),
            Text(
              r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 1),
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFD54F)),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingText(JournalItem item) {
    final r = (item.data as dynamic).rating as double?;
    return r == null
        ? '未评分'.tr
        : '{n}分'
            .trf({'n': r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 1)});
  }

  void _removeItem(JournalItem item) {
    final idx = widget.items.indexOf(item);
    if (idx < 0) return;
    setState(() => _excluded.add(idx));
  }

  /// 取布局 [layoutKey] 下第 [slot] 格位当前展示的条目
  JournalItem _slotItem(List<JournalItem> filtered, int layoutKey, int slot) {
    final count = filtered.length;
    final picks = _slotPicks.putIfAbsent(layoutKey, () => []);
    if (picks.length <= slot) picks.length = slot + 1;
    final pick = picks[slot];
    // 移除数据后下标可能越界，回退到默认循环位
    if (pick == null || pick >= count) {
      picks[slot] = slot % count;
      return filtered[slot % count];
    }
    return filtered[pick];
  }

  /// 弹出封面选择面板，由用户指定该格位展示哪条记录的封面
  Future<void> _pickSlotCover(
      List<JournalItem> filtered, int layoutKey, int slot) async {
    final current = _slotItem(filtered, layoutKey, slot);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('选择封面'.tr,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface)),
              ),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    final selected = identical(item, current);
                    return GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(i),
                      child: Stack(fit: StackFit.expand, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _posterImage(item, 80),
                        ),
                        Positioned(
                          left: 4,
                          right: 4,
                          bottom: 4,
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                        if (selected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4A90D9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                      ]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      final picks = _slotPicks.putIfAbsent(layoutKey, () => []);
      if (picks.length <= slot) picks.length = slot + 1;
      picks[slot] = picked;
    });
  }

  /// 瓦片中央的“选择封面”按钮（截图时隐藏）
  Widget _replaceBadge(VoidCallback onReplace, {double size = 30}) {
    return Positioned.fill(
      child: Center(
        child: GestureDetector(
          onTap: onReplace,
          child: Tooltip(
            message: '选择封面'.tr,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.swap_horiz_rounded,
                  size: size * 0.6, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreBar(ColorScheme colors) {
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('已移除 {n} 项'.trf({'n': _excluded.length}),
                style: TextStyle(
                    fontSize: 12.5,
                    color: colors.onSurface.withValues(alpha: 0.6))),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(_excluded.clear),
              child: Text('恢复全部'.tr,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: colors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 底部编辑面板 ───

  Widget _buildBottomPanel(ColorScheme colors) {
    const tabs = ['分享', '布局', '筛选', '元素'];
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
            top: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _bottomTab = i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          children: [
                            Text(
                              tabs[i].tr,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: _bottomTab == i
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _bottomTab == i
                                    ? colors.primary
                                    : colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 20,
                              height: 2,
                              decoration: BoxDecoration(
                                color: _bottomTab == i
                                    ? colors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // 所有 tab 统一固定高度；元素开关多时内部上下滚动
            SizedBox(height: 92, child: _buildPanelContent(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelContent(ColorScheme colors) {
    switch (_bottomTab) {
      case 1:
        return _layoutPanel(colors);
      case 2:
        return _filterPanel(colors);
      case 3:
        return _elementPanel(colors);
      default:
        return _sharePanel(colors);
    }
  }

  Widget _sharePanel(ColorScheme colors) {
    return Center(
      child: FilledButton.icon(
        onPressed: _generating ? null : _share,
        icon: _generating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.ios_share_outlined),
        label: Text(_generating ? '正在生成...'.tr : '分享海报'.tr),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }

  Widget _layoutPanel(ColorScheme colors) {
    const options = <(IconData, String)>[
      (Icons.grid_view_rounded, '卡片'),
      (Icons.view_agenda_outlined, '列表'),
      (Icons.diamond_outlined, '海报墙（斜）'),
      (Icons.apps_rounded, '海报墙（小）'),
    ];
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: GestureDetector(
              onTap: () => setState(() => _layout = i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _layout == i
                          ? colors.primary.withValues(alpha: 0.12)
                          : colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(options[i].$1,
                        size: 20,
                        color: _layout == i
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.55)),
                  ),
                  const SizedBox(height: 3),
                  Text(options[i].$2.tr,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              _layout == i ? FontWeight.w700 : FontWeight.w500,
                          color: _layout == i
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterPanel(ColorScheme colors) {
    const options = <(String, IconData)>[
      ('movie', Icons.movie_outlined),
      ('book', Icons.menu_book_outlined),
      ('game', Icons.sports_esports_outlined),
      ('note', Icons.sticky_note_2_outlined),
    ];
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      children: [
        for (final (type, icon) in options)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTap: () => setState(() {
                if (!_activeTypes.remove(type)) _activeTypes.add(type);
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _activeTypes.contains(type)
                          ? colors.primary.withValues(alpha: 0.12)
                          : colors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon,
                        size: 20,
                        color: _activeTypes.contains(type)
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(height: 3),
                  Text(widget.typeLabel(type),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: _activeTypes.contains(type)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _activeTypes.contains(type)
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _elementPanel(ColorScheme colors) {
    final rows = <(String, bool, ValueChanged<bool>)>[
      ('标题'.tr, _showTitle, (v) => setState(() => _showTitle = v)),
      ('统计文案'.tr, _showStats, (v) => setState(() => _showStats = v)),
      ('评分信息'.tr, _showRating, (v) => setState(() => _showRating = v)),
      ('月历缩略'.tr, _showCalendar, (v) => setState(() => _showCalendar = v)),
      ('品牌行'.tr, _showBrand, (v) => setState(() => _showBrand = v)),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        for (final (label, value, onChanged) in rows)
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface.withValues(alpha: 0.8))),
                const Spacer(),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── 截图分享 ───

  Future<void> _share() async {
    if (_filtered.isEmpty) {
      ToastUtil.show(context, '当前筛选下没有标记，无法生成海报'.tr);
      return;
    }
    setState(() {
      _generating = true;
      _capturing = true; // 隐藏红色移除角标
    });
    await WidgetsBinding.instance.endOfFrame;
    try {
      final boundary = _posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取海报边界'.tr);
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据'.tr);
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/journal_poster_${_anchor.year}${_anchor.month}_${_scope}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$_periodText${'海报墙 · MookNote'.tr}',
      );
    } catch (e) {
      if (mounted) ToastUtil.show(context, '生成海报失败：{e}'.trf({'e': e}));
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
          _capturing = false;
        });
      }
    }
  }
}

/// 延迟一帧构建重内容：首帧只画加载动画，让切换交互先响应，
/// 下一帧再挂载大量海报组件，避免同帧构建造成的卡顿/ANR。
class _DeferredBody extends StatefulWidget {
  final Widget child;

  const _DeferredBody({super.key, required this.child});

  @override
  State<_DeferredBody> createState() => _DeferredBodyState();
}

class _DeferredBodyState extends State<_DeferredBody> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return widget.child;
  }
}
