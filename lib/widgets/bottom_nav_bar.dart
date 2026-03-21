import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 自定义底部导航栏 - Dock栏悬浮设计
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取底部安全区域高度
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          // 高度：导航栏本身高度 + 底部安全距离 + 上下边距
          height: 64 + bottomPadding + 16,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dock栏主体 - 悬浮效果
              Container(
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 主页按钮
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home,
                      isActive: provider.bottomNavIndex == 0,
                      onTap: () => provider.setBottomNavIndex(0),
                    ),
                    
                    // 中间新增按钮
                    _buildAddButton(context, provider),
                    
                    // 我的按钮
                    _buildNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      isActive: provider.bottomNavIndex == 2,
                      onTap: () => provider.setBottomNavIndex(2),
                    ),
                  ],
                ),
              ),
              // 底部安全距离占位
              SizedBox(height: bottomPadding + 8),
            ],
          ),
        );
      },
    );
  }
  
  /// 构建导航项
  Widget _buildNavItem({
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
            color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFF999999),
            size: 26,
          ),
        ),
      ),
    );
  }
  
  /// 构建中间新增按钮
  Widget _buildAddButton(BuildContext context, AppProvider provider) {
    return GestureDetector(
      onTap: () => _showAddDialog(context, provider),
      onLongPress: () => _showQuickAddDialog(context, provider),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// 长按快速添加 - 根据当前界面直接跳转到对应添加界面
  void _showQuickAddDialog(BuildContext context, AppProvider provider) {
    // 根据当前主标签页决定跳转到哪个添加界面
    final currentTab = provider.mainTabIndex;
    
    switch (currentTab) {
      case 0: // 观影标签页
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
      case 1: // 阅读标签页
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
      case 2: // 笔记标签页
        Navigator.pushNamed(context, '/note-form');
        break;
      default:
        _showAddDialog(context, provider);
    }
  }

  /// 显示新增对话框
  void _showAddDialog(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部指示条
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // 标题
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '新增记录',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 选项列表
                _buildAddOption(
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

  /// 构建新增选项
  Widget _buildAddOption({
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
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
