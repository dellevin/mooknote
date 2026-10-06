import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../l10n/app_strings.dart';
import '../../services/badge_service.dart';
import '../../utils/user_prefs.dart';

/// 成就徽章页：徽章定义来自服务端，本地统计进度判定解锁
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  List<BadgeDef> _defs = [];
  Map<String, int> _metrics = {};
  Map<String, String> _unlocked = {};
  bool _loading = true;

  /// 分组主题色（按指标归类）
  static const _groupColors = <String, Color>{
    '特殊成就': Color(0xFFFFB300),
    '观影成就': Color(0xFF5C6BC0),
    '阅读成就': Color(0xFF66BB6A),
    '游戏成就': Color(0xFFAB47BC),
    '评论成就': Color(0xFF26A69A),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final defs = await BadgeService.fetchDefs();
    final metrics = await BadgeService.collectMetrics();
    // 进入页面时也评估一次（保底，正常启动时已评估过）
    await BadgeService.evaluate(defs, metrics);
    // 取出待庆祝的新解锁并清空队列
    final pendingSlugs = UserPrefs().badgePendingCelebrate;
    if (pendingSlugs.isNotEmpty) {
      await UserPrefs().setBadgePendingCelebrate([]);
    }
    if (!mounted) return;
    setState(() {
      _defs = defs;
      _metrics = metrics;
      _unlocked = UserPrefs().badgeUnlocked;
      _loading = false;
    });
    // 在徽章页内庆祝新解锁（不在主页弹窗）
    if (pendingSlugs.isNotEmpty) {
      final pendingDefs =
          defs.where((d) => pendingSlugs.contains(d.slug)).toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showUnlockDialogs(pendingDefs);
      });
    }
  }

  Future<void> _showUnlockDialogs(List<BadgeDef> badges) async {
    for (final b in badges) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => _UnlockDialog(badge: b),
      );
    }
  }

  /// 按指标分组（保持 defs 原有顺序）
  Map<String, List<BadgeDef>> get _groups {
    String labelOf(String metric) {
      switch (metric) {
        case 'first_use':
        case 'streak_days':
          return '其他';
        case 'movie_count':
          return '观影';
        case 'book_count':
          return '阅读';
        case 'game_count':
          return '游戏';
        default:
          return '评论';
      }
    }

    final groups = <String, List<BadgeDef>>{};
    for (final d in _defs) {
      groups.putIfAbsent(labelOf(d.metric), () => []).add(d);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final unlockedCount =
        _defs.where((d) => _unlocked.containsKey(d.slug)).length;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('成就徽章'.tr)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _defs.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text('暂无徽章，请检查网络后下拉刷新'.tr,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.4))),
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        // 顶部汇总
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🏆 已解锁 $unlockedCount / ${_defs.length}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFB300)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in _groups.entries) ...[
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 14, bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color:
                                        _groupColors[entry.key] ??
                                            colors.primary,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _groupColors[entry.key] ??
                                          colors.primary),
                                ),
                              ],
                            ),
                          ),
                          // 列表式卡片：左图标、中名称+进度、右日期/数值
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < entry.value.length; i++)
                                  _buildRow(
                                      entry.value[i],
                                      _groupColors[entry.key] ??
                                          colors.primary,
                                      colors,
                                      showDivider:
                                          i < entry.value.length - 1),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
    );
  }

  /// 列表式徽章行：左侧大图标，中间名称+进度条，右侧解锁日期/进度数值
  Widget _buildRow(BadgeDef badge, Color groupColor, ColorScheme colors,
      {required bool showDivider}) {
    final unlockedAt = _unlocked[badge.slug];
    final unlocked = unlockedAt != null;
    final current = _metrics[badge.metric] ?? 0;
    final progress = (current / badge.threshold).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showBadgeDetail(badge, groupColor),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: unlocked
                  ? BoxDecoration(
                      color: groupColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Row(
                children: [
                  // B：左侧组色竖条（仅已解锁）
                  if (unlocked) ...[
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: groupColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // 图标主视觉：已解锁 64px 大图标 + 组色光晕 + 右下角对勾
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: unlocked
                              ? groupColor.withValues(alpha: 0.15)
                              : colors.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: BadgeIcon(
                              icon: badge.icon,
                              size: 40,
                              locked: !unlocked,
                              colors: colors),
                        ),
                      ),
                      if (unlocked)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: groupColor,
                              border:
                                  Border.all(color: colors.surface, width: 2),
                            ),
                            child: const Icon(Icons.check,
                                size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // 名称 + 进度条
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: unlocked
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.45),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!unlocked) ...[
                          const SizedBox(height: 7),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: colors.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(
                                  groupColor.withValues(alpha: 0.7)),
                            ),
                          ),
                        ] else if (badge.desc.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            badge.desc,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 右侧：解锁日期（组色加粗）/ 进度数值
                  Text(
                    unlocked
                        ? _fmtDate(unlockedAt)
                        : '${current > badge.threshold ? badge.threshold : current}/${badge.threshold}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: unlocked
                          ? groupColor
                          : colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            if (showDivider && !unlocked)
              Divider(
                  height: 1,
                  indent: 92,
                  endIndent: 14,
                  color: colors.outlineVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  /// 点击徽章放大查看详情
  void _showBadgeDetail(BadgeDef badge, Color groupColor) {
    final colors = Theme.of(context).colorScheme;
    final unlockedAt = _unlocked[badge.slug];
    final unlocked = unlockedAt != null;
    final current = _metrics[badge.metric] ?? 0;
    final progress = (current / badge.threshold).clamp(0.0, 1.0);

    final prefs = UserPrefs();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final floated = prefs.badgeFloat.containsKey(badge.slug);
          final floatPages = prefs.badgeFloatPages(badge.slug);

          /// 切换某个页面的浮动显示；关掉最后一个页面时直接取消浮动
          Future<void> togglePage(String page) async {
            final next = Set<String>.from(floatPages);
            if (next.contains(page)) {
              next.remove(page);
            } else {
              next.add(page);
            }
            if (next.isEmpty) {
              final map = prefs.badgeFloat;
              map.remove(badge.slug);
              await prefs.setBadgeFloat(map);
            } else {
              await prefs.setBadgeFloatPages(badge.slug, next);
            }
            setDlgState(() {});
          }

          Widget pageChip(String label, String page) {
            final selected = floatPages.contains(page);
            return ChoiceChip(
              label: Text(label.tr, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => togglePage(page),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }

          // 已解锁的徽章可浮动显示图标（我的页/主页，位置共享）
          final floatSwitch = SwitchListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text('浮动显示图标'.tr,
                style: const TextStyle(fontSize: 13)),
            value: floated,
            onChanged: (v) async {
              final map = prefs.badgeFloat;
              if (v) {
                // 默认放在右上角，按数量纵向错开
                map[badge.slug] = (
                  x: 0.85,
                  y: 0.02 + (map.length % 6) * 0.08,
                );
              } else {
                map.remove(badge.slug);
              }
              await prefs.setBadgeFloat(map);
              setDlgState(() {});
            },
          );

          // 已解锁：银白镭射卡片（按住滑动显示镭射纹理）
          if (unlocked) {
            return Dialog(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _HoloBadgeCard(badge: badge, unlockedAt: unlockedAt),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            color: colors.surface,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                floatSwitch,
                                if (floated)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 0, 12, 10),
                                    child: Row(
                                      children: [
                                        pageChip('我的', 'profile'),
                                        const SizedBox(width: 8),
                                        pageChip('主页', 'home'),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          // 未解锁：进度展示
          return Dialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    child: Center(
                      child: BadgeIcon(
                          icon: badge.icon,
                          size: 76,
                          locked: true,
                          colors: colors),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    badge.name,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface),
                    textAlign: TextAlign.center,
                  ),
                  if (badge.desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      badge.desc,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: colors.onSurface.withValues(alpha: 0.5)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(groupColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${current > badge.threshold ? badge.threshold : current} / ${badge.threshold}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

/// 徽章图标：http(s):// 开头按图片 URL 渲染，否则按 SVG 内容渲染
class BadgeIcon extends StatelessWidget {
  final String icon;
  final double size;
  final bool locked;
  final ColorScheme colors;

  const BadgeIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.locked,
    required this.colors,
  });

  bool get _isUrl => icon.startsWith('http://') || icon.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    // 未解锁：保留原色但降低透明度（不再纯灰，保持彩色感）
    final child = _buildRaw(context);
    if (!locked) return child;
    return Opacity(opacity: 0.3, child: child);
  }

  Widget _buildRaw(BuildContext context) {
    if (icon.isEmpty) {
      return Icon(Icons.emoji_events_outlined,
          size: size, color: colors.primary);
    }
    if (_isUrl) {
      return Image.network(
        icon,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined,
            size: size, color: colors.onSurface.withValues(alpha: 0.2)),
      );
    }
    return SvgPicture.string(icon, width: size, height: size);
  }
}

/// 解锁庆祝弹窗
class _UnlockDialog extends StatelessWidget {
  final BadgeDef badge;

  const _UnlockDialog({required this.badge});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text('🎉', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB300).withValues(alpha: 0.15),
            ),
            child: Center(
              child: BadgeIcon(
                  icon: badge.icon, size: 60, locked: false, colors: colors),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '解锁成就'.tr,
            style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 4),
          Text(
            badge.name,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
            textAlign: TextAlign.center,
          ),
          if (badge.desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              badge.desc,
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('太棒了'.tr),
          ),
        ),
      ],
    );
  }
}

/// 银白闪卡：按住时银色光带循环扫过、图标左右摆动，抬起播完当前一次后停
/// 灰白相间横向条纹底（上覆柔光罩），上面是徽章图标，分割线下方靠右是名称/用户名/座右铭/解锁时间
class _HoloBadgeCard extends StatefulWidget {
  final BadgeDef badge;
  final String unlockedAt;

  const _HoloBadgeCard({required this.badge, required this.unlockedAt});

  @override
  State<_HoloBadgeCard> createState() => _HoloBadgeCardState();
}

class _HoloBadgeCardState extends State<_HoloBadgeCard>
    with SingleTickerProviderStateMixin {
  static const double _cardHeight = 400;

  /// 点击播放：驱动光带扫过 + 图标摆动
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final prefs = UserPrefs();
    final d = DateTime.tryParse(widget.unlockedAt)?.toLocal();
    final dateStr = d == null
        ? ''
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return Listener(
      // 按住时无限循环播放光带+摆动（单向无缝循环），抬起播完当前一次自动停
      onPointerDown: (_) => _ctrl.repeat(),
      onPointerUp: (_) => _ctrl.forward(),
      onPointerCancel: (_) => _ctrl.forward(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: _cardHeight,
          decoration: const BoxDecoration(
            // 灰白相间横向条纹底（硬边、无渐变、行高一致）
            gradient: LinearGradient(
              begin: Alignment(0, -1.0),
              end: Alignment(0, -0.6),
              tileMode: TileMode.repeated,
              colors: [
                Color(0xFFFCFCFE),
                Color(0xFFFCFCFE),
                Color(0xFFEEF0F4),
                Color(0xFFEEF0F4),
              ],
              stops: [0.0, 0.5, 0.5, 1.0],
            ),
          ),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              // 光带匀速左→右；三条带间距 3 = 一个循环的行程，
              // 循环结束时每条带恰好进入下一条带的位置 → 真正无缝无限滚动
              final shineX = -3.0 + _ctrl.value * 3.0;
              // 图标摆动：上下左右缓慢绕一圈
              final angle = _ctrl.value * 2 * pi;
              final tilt = Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateX(sin(angle) * 0.16)
                ..rotateY(cos(angle) * 0.16);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // 柔光罩：压低条纹对比度，文字不违和
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                  // 金属光泽光带 ×3：间距=单循环行程，无缝衔接；亮核+淡羽化
                  if (_ctrl.isAnimating)
                    for (final offset in const [0.0, 3.0, 6.0])
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(shineX + offset - 0.8, -0.5),
                            end: Alignment(shineX + offset + 0.8, 0.5),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.5),
                              Colors.white.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                          ),
                        ),
                      ),
                  // 边缘细框
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 1.5),
                    ),
                  ),
                  // 内容
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Column(
                      children: [
                        // 图标（点击时左右摆动一次）
                        Expanded(
                          child: Center(
                            child: Transform(
                              alignment: Alignment.center,
                              transform:
                                  _ctrl.isAnimating ? tilt : Matrix4.identity(),
                              child: BadgeIcon(
                                  icon: widget.badge.icon,
                                  size: 180,
                                  locked: false,
                                  colors: colors),
                            ),
                          ),
                        ),
                        // 分割线
                        Divider(
                            height: 1,
                            thickness: 0.8,
                            color: const Color(0xFF9AA0B0)
                                .withValues(alpha: 0.35)),
                        const SizedBox(height: 10),
                        // 下方信息靠右
                        Align(
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.badge.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2B2F3A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                prefs.nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6B7080),
                                ),
                              ),
                              if (prefs.motto.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  prefs.motto,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: const Color(0xFF8A8F9E)
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                  color: Color(0xFF9AA0B0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
