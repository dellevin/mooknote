import 'package:flutter/material.dart';
import '../main.dart' show routeObserver;
import '../pages/profile/badges_page.dart' show BadgeIcon;
import '../services/badge_service.dart';
import '../utils/user_prefs.dart';

/// 浮动徽章叠加层：放在"我的"/主页等内容区 Stack 顶层，
/// 展示已开启浮动显示的徽章图标，可自由拖拽换位。
/// 位置以 0~1 比例坐标按页面分开持久化（UserPrefs.badgeFloatFor）。
/// [page] = 'profile'（我的）/ 'home'（主页），各自独立存取位置。
/// 注意：本组件不会拦截图标以外的点击（Stack 默认不自身命中）。
class FloatBadgeOverlay extends StatefulWidget {
  /// 'profile' = 我的页，'home' = 主页
  final String page;

  const FloatBadgeOverlay({super.key, required this.page});

  @override
  State<FloatBadgeOverlay> createState() => _FloatBadgeOverlayState();
}

class _FloatBadgeOverlayState extends State<FloatBadgeOverlay>
    with RouteAware {
  final UserPrefs _userPrefs = UserPrefs();

  Map<String, BadgeDef> _badgeDefs = {};
  Map<String, ({double x, double y})> _badgeFloat = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 从徽章页返回时可能改了浮动显示开关
    _load();
  }

  /// 先读缓存定义即时展示，再后台刷新定义
  void _load() {
    if (!mounted) return;
    setState(() {
      _badgeFloat = _userPrefs.badgeFloatFor(widget.page);
      _badgeDefs = {for (final d in BadgeService.cachedDefs()) d.slug: d};
    });
    BadgeService.fetchDefs().then((fresh) {
      if (!mounted || fresh.isEmpty) return;
      setState(() => _badgeDefs = {for (final d in fresh) d.slug: d});
    });
  }

  @override
  Widget build(BuildContext context) {
    final slugs = _badgeFloat.keys
        .where((s) => _badgeDefs.containsKey(s))
        .toList();
    if (slugs.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          for (final slug in slugs)
            _FloatBadgeIcon(
              key: ValueKey(slug),
              icon: _badgeDefs[slug]!.icon,
              pos: _badgeFloat[slug]!,
              constraints: constraints,
              onChanged: (p) => setState(() => _badgeFloat[slug] = p),
              onDragEnd: () =>
                  _userPrefs.setBadgeFloatFor(widget.page, _badgeFloat),
            ),
        ],
      ),
    );
  }
}

/// 浮动徽章图标：本地状态实时跟手拖拽，松手后回写父级持久化
class _FloatBadgeIcon extends StatefulWidget {
  final String icon;
  final ({double x, double y}) pos;
  final BoxConstraints constraints;
  final ValueChanged<({double x, double y})> onChanged;
  final VoidCallback onDragEnd;

  const _FloatBadgeIcon({
    super.key,
    required this.icon,
    required this.pos,
    required this.constraints,
    required this.onChanged,
    required this.onDragEnd,
  });

  @override
  State<_FloatBadgeIcon> createState() => _FloatBadgeIconState();
}

class _FloatBadgeIconState extends State<_FloatBadgeIcon> {
  static const double _iconSize = 64;

  // 拖拽中的实时位置（像素），null 表示未在拖拽，用父级传入的比例坐标
  Offset? _dragPos;
  // 按压状态（点击反馈）
  bool _pressed = false;

  Offset get _basePos => Offset(
        widget.pos.x * widget.constraints.maxWidth - _iconSize / 2,
        widget.pos.y * widget.constraints.maxHeight - _iconSize / 2,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxX =
        (widget.constraints.maxWidth - _iconSize).clamp(0.0, double.infinity);
    final maxY =
        (widget.constraints.maxHeight - _iconSize).clamp(0.0, double.infinity);
    final p = _dragPos ?? _basePos;

    return Positioned(
      left: p.dx.clamp(0.0, maxX),
      top: p.dy.clamp(0.0, maxY),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () {
          // 拖拽赢得手势竞技场时也会触发，此时保持按压态
          if (_dragPos == null && _pressed) {
            setState(() => _pressed = false);
          }
        },
        onPanStart: (_) {
          _dragPos = _basePos;
          if (!_pressed) setState(() => _pressed = true);
        },
        onPanUpdate: (details) {
          final cur = _dragPos ?? _basePos;
          setState(() => _dragPos = Offset(
                (cur.dx + details.delta.dx).clamp(0.0, maxX),
                (cur.dy + details.delta.dy).clamp(0.0, maxY),
              ));
        },
        onPanEnd: (_) {
          final p = _dragPos;
          if (p != null &&
              widget.constraints.maxWidth > 0 &&
              widget.constraints.maxHeight > 0) {
            // 转回比例坐标（以图标中心点记）
            widget.onChanged((
              x: ((p.dx + _iconSize / 2) / widget.constraints.maxWidth)
                  .clamp(0.0, 1.0),
              y: ((p.dy + _iconSize / 2) / widget.constraints.maxHeight)
                  .clamp(0.0, 1.0),
            ));
            widget.onDragEnd();
          }
          setState(() {
            _dragPos = null;
            _pressed = false;
          });
        },
        onPanCancel: () => setState(() {
              _dragPos = null;
              _pressed = false;
            }),
        child: SizedBox(
          width: _iconSize,
          height: _iconSize,
          child: AnimatedScale(
            scale: _pressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: _pressed ? 0.7 : 1.0,
              duration: const Duration(milliseconds: 120),
              child: BadgeIcon(
                  icon: widget.icon,
                  size: _iconSize,
                  locked: false,
                  colors: colors),
            ),
          ),
        ),
      ),
    );
  }
}
