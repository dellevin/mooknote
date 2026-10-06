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
    '其他': Color(0xFFFFB300),
    '观影': Color(0xFF5C6BC0),
    '阅读': Color(0xFF66BB6A),
    '游戏': Color(0xFFAB47BC),
    '评论': Color(0xFF26A69A),
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
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // 窄屏一行 3 个，宽屏一行 4 个
                        final crossCount =
                            constraints.maxWidth > 720 ? 4 : 3;
                        return ListView(
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
                              GridView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossCount,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: entry.value.length,
                                itemBuilder: (context, i) => _buildCard(
                                    entry.value[i],
                                    _groupColors[entry.key] ??
                                        colors.primary,
                                    colors),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildCard(BadgeDef badge, Color groupColor, ColorScheme colors) {
    final unlockedAt = _unlocked[badge.slug];
    final unlocked = unlockedAt != null;
    final current = _metrics[badge.metric] ?? 0;
    final progress = (current / badge.threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge, groupColor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: unlocked
              ? groupColor.withValues(alpha: 0.10)
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: unlocked
              ? Border.all(color: groupColor.withValues(alpha: 0.4))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 圆形徽章：未解锁时外圈显示进度环、图标保留淡色
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!unlocked)
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        backgroundColor: colors.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                            groupColor.withValues(alpha: 0.5)),
                      ),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked
                          ? groupColor.withValues(alpha: 0.18)
                          : colors.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                    ),
                    child: Center(
                      child: BadgeIcon(
                          icon: badge.icon,
                          size: 30,
                          locked: !unlocked,
                          colors: colors),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: unlocked
                    ? colors.onSurface
                    : colors.onSurface.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              unlocked
                  ? _fmtDate(unlockedAt)
                  : '${current > badge.threshold ? badge.threshold : current}/${badge.threshold}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: unlocked
                    ? groupColor
                    : colors.onSurface.withValues(alpha: 0.35),
              ),
            ),
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
          return Dialog(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  color: unlocked
                      ? groupColor.withValues(alpha: 0.15)
                      : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: unlocked
                      ? Border.all(
                          color: groupColor.withValues(alpha: 0.4), width: 2)
                      : null,
                ),
                child: Center(
                  child: BadgeIcon(
                      icon: badge.icon,
                      size: 76,
                      locked: !unlocked,
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
              if (unlocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: groupColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${'已解锁'.tr} · ${_fmtDate(unlockedAt)}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: groupColor),
                  ),
                )
              else ...[
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
              // 已解锁的徽章可在"我的"页浮动显示图标
              if (unlocked) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('在"我的"页浮动显示图标'.tr,
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
                ),
              ],
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
