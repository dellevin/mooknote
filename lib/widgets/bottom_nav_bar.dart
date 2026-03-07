import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 自定义底部导航栏 - 极简主义设计
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          height: 48,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFF999999),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
  
  /// 构建中间新增按钮
  Widget _buildAddButton(BuildContext context, AppProvider provider) {
    return InkWell(
      onTap: () => _showAddDialog(context, provider),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  /// 显示新增对话框
  void _showAddDialog(BuildContext context, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.movie, color: Colors.green),
                title: const Text('添加观影'),
                subtitle: const Text('记录你看过的电影'),
                onTap: () {
                  Navigator.pop(context);
                  // 根据当前影视标签页的选中状态设置默认值
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
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.orange),
                title: const Text('添加阅读'),
                subtitle: const Text('记录你读过的书'),
                onTap: () {
                  Navigator.pop(context);
                  // 根据当前阅读标签页的选中状态设置默认值
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
              ListTile(
                leading: const Icon(Icons.note, color: Colors.blue),
                title: const Text('添加笔记'),
                subtitle: const Text('记录你的想法和笔记'),
                onTap: () {
                  Navigator.pop(context);
                  // 直接打开添加笔记表单
                  Navigator.pushNamed(context, '/note-form');
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
