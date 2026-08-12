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
          height: 64 + bottomPadding + 16,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDock(context, provider: provider),
              SizedBox(height: bottomPadding + 8),
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
      height: 56,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(28),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            colors: colors,
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            isActive: provider.bottomNavIndex == 0,
            onTap: () => provider.setBottomNavIndex(0),
          ),
          _buildAddButton(context, provider),
          _buildNavItem(
            colors: colors,
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            isActive: provider.bottomNavIndex == 2,
            onTap: () => provider.setBottomNavIndex(2),
          ),
        ],
      ),
    );

    // 毛玻璃模式下：裁剪 + 模糊区域与胶囊同宽（外围留白），避免整行全宽模糊
    Widget result = dock;
    if (isFrosted) {
      result = ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: dock,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: result,
    );
  }

  Widget _buildNavItem({
    required ColorScheme colors,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        color: Colors.transparent,
        child: Center(
          child: Icon(
            isActive ? activeIcon : icon,
            color: isActive ? colors.primary : colors.onSurface.withValues(alpha: 0.4),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showAddSheet(context, provider),
      onLongPress: () => showQuickAddSheet(context, provider),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.add,
          color: colors.onPrimary,
          size: 24,
        ),
      ),
    );
  }
}