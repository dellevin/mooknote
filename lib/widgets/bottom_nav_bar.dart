import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'add_sheet.dart';

/// 自定义底部导航栏 - Dock栏悬浮设计
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          height: 68 + bottomPadding + 12,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDock(context, provider: provider),
              SizedBox(height: bottomPadding + 4),
            ],
          ),
        );
      },
    );
  }

  /// Dock 悬浮导航条；毛玻璃模式下加真实模糊，保证可读
  Widget _buildDock(BuildContext context, {required AppProvider provider}) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFrosted = provider.frostedActive;

    final dock = Container(
      height: 64,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavArea(colors, provider),
            Container(
              width: 1,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: colors.onSurface.withValues(alpha: 0.12),
            ),
            _buildAddButton(context, provider),
          ],
        ),
      ),
    );

    // 毛玻璃模式下：裁剪 + 模糊区域与胶囊同宽（外围留白），避免整行全宽模糊
    Widget result = dock;
    if (isFrosted) {
      result = ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: dock,
        ),
      );
    }
    return Center(child: result);
  }

  /// 单个导航项固定宽度：水平 padding 18×2 + 图标 26；项间距 6
  static const double _navItemWidth = 62;
  static const double _navItemGap = 6;
  static const double _navItemHeight = 46;

  /// 三个主导航 + 共享高亮胶囊：胶囊在 Stack 底层按索引滑动
  Widget _buildNavArea(ColorScheme colors, AppProvider provider) {
    final activeIndex = provider.bottomNavIndex.clamp(0, 2);
    return SizedBox(
      height: _navItemHeight,
      child: Stack(
        children: [
          // 滑动胶囊：唯一真源是 provider.bottomNavIndex，声明式驱动
          AnimatedPositioned(
            left: activeIndex * (_navItemWidth + _navItemGap),
            top: 0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: Container(
              width: _navItemWidth,
              height: _navItemHeight,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavItem(
                colors: colors,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                isActive: provider.bottomNavIndex == 0,
                onTap: () => provider.setBottomNavIndex(0),
              ),
              const SizedBox(width: _navItemGap),
              _buildNavItem(
                colors: colors,
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month_rounded,
                isActive: provider.bottomNavIndex == 1,
                onTap: () => provider.setBottomNavIndex(1),
              ),
              const SizedBox(width: _navItemGap),
              _buildNavItem(
                colors: colors,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                isActive: provider.bottomNavIndex == 2,
                onTap: () => provider.setBottomNavIndex(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required ColorScheme colors,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: _navItemWidth,
      height: _navItemHeight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: Icon(
            isActive ? activeIcon : icon,
            color: isActive
                ? colors.onSurface
                : colors.onSurface.withValues(alpha: 0.4),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return _AddButton(
      colors: colors,
      onTap: () => showAddSheet(context, provider),
      onLongPress: () => showQuickAddSheet(context, provider),
    );
  }
}

/// Add 按钮 — 按压缩放动画
class _AddButton extends StatefulWidget {
  final ColorScheme colors;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AddButton({
    required this.colors,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _ctrl.forward(from: 0);
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: widget.colors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.add_rounded,
            color: widget.colors.onPrimary,
            size: 28,
          ),
        ),
      ),
    );
  }
}