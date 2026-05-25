import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 自定义底部导航栏 - Dock栏悬浮设计
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          height: 64 + bottomPadding + 16,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
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
              ),
              SizedBox(height: bottomPadding + 8),
            ],
          ),
        );
      },
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
      onTap: () => _showAddDialog(context, provider),
      onLongPress: () => _showQuickAddDialog(context, provider),
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

  void _showQuickAddDialog(BuildContext context, AppProvider provider) {
    final currentTab = provider.mainTabIndex;

    switch (currentTab) {
      case 0:
        final statusMap = {
          0: 'watched',
          1: 'watching',
          2: 'want_to_watch',
        };
        final currentStatus = statusMap[provider.movieStatusIndex] ?? 'want_to_watch';
        Navigator.pushNamed(
          context,
          '/movie-form',
          arguments: {'initialStatus': currentStatus},
        );
        break;
      case 1:
        final statusMap = {
          0: 'read',
          1: 'reading',
          2: 'want_to_read',
        };
        final currentStatus = statusMap[provider.bookStatusIndex] ?? 'want_to_read';
        Navigator.pushNamed(
          context,
          '/book-form',
          arguments: {'initialStatus': currentStatus},
        );
        break;
      case 2:
        Navigator.pushNamed(context, '/note-form');
        break;
      default:
        _showAddDialog(context, provider);
    }
  }

  void _showAddDialog(BuildContext context, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        final bottomColors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: bottomColors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '新增记录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: bottomColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildAddOption(
                  colors: bottomColors,
                  icon: Icons.movie_outlined,
                  title: '添加观影',
                  subtitle: '记录你看过的电影',
                  onTap: () {
                    Navigator.pop(context);
                    final statusMap = {
                      0: 'watched',
                      1: 'watching',
                      2: 'want_to_watch',
                    };
                    final currentStatus = statusMap[provider.movieStatusIndex] ?? 'want_to_watch';
                    Navigator.pushNamed(
                      context,
                      '/movie-form',
                      arguments: {'initialStatus': currentStatus},
                    );
                  },
                ),
                _buildAddOption(
                  colors: bottomColors,
                  icon: Icons.menu_book_outlined,
                  title: '添加阅读',
                  subtitle: '记录你读过的书',
                  onTap: () {
                    Navigator.pop(context);
                    final statusMap = {
                      0: 'read',
                      1: 'reading',
                      2: 'want_to_read',
                    };
                    final currentStatus = statusMap[provider.bookStatusIndex] ?? 'want_to_read';
                    Navigator.pushNamed(
                      context,
                      '/book-form',
                      arguments: {'initialStatus': currentStatus},
                    );
                  },
                ),
                _buildAddOption(
                  colors: bottomColors,
                  icon: Icons.note_outlined,
                  title: '添加笔记',
                  subtitle: '记录你的想法和笔记',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/note-form');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddOption({
    required ColorScheme colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.25),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
