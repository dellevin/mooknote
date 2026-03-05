import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 自定义底部导航栏
class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return BottomNavigationBar(
          currentIndex: provider.bottomNavIndex,
          onTap: (index) {
            if (index == 1) {
              // 新增按钮 - 显示选择对话框
              _showAddDialog(context, provider);
            } else {
              // 切换主页/我的页面
              provider.setBottomNavIndex(index);
            }
          },
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '主页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: '新增',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        );
      },
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
                  // 直接打开添加观影表单
                  Navigator.pushNamed(context, '/movie-form');
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.orange),
                title: const Text('添加阅读'),
                subtitle: const Text('记录你读过的书'),
                onTap: () {
                  Navigator.pop(context);
                  // 直接打开添加阅读表单
                  Navigator.pushNamed(context, '/book-form');
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
