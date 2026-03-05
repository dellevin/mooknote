import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/bottom_nav_bar.dart';
import 'movie_tab_page.dart';
import 'book_tab_page.dart';
import 'note_tab_page.dart';

/// 主页 - 包含顶部菜单、三个标签页、底部导航
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 左侧弹出菜单
      drawer: const CustomDrawer(),
      
      // 主体内容
      body: Column(
        children: [
          // 顶部 AppBar
          _buildAppBar(),
          
          // 三个标签页的标题栏
          _buildTabBar(),
          
          // 标签页内容
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
      
      // 底部导航栏
      bottomNavigationBar: const CustomBottomNavBar(),
    );
  }

  /// 构建顶部 AppBar
  Widget _buildAppBar() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return AppBar(
          title: Text(_getAppBarTitle(provider)),
          actions: [
            // 添加按钮
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddDialog(context, provider),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // TODO: 搜索功能
              },
            ),
          ],
        );
      },
    );
  }

  /// 获取 AppBar 标题
  String _getAppBarTitle(AppProvider provider) {
    switch (provider.mainTabIndex) {
      case 0:
        return '观影';
      case 1:
        return '阅读';
      case 2:
        return '笔记';
      default:
        return 'MookNote';
    }
  }

  /// 构建标签栏
  Widget _buildTabBar() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 观影
              _buildTabItem(
                context,
                '观影',
                Icons.movie,
                0,
                provider.mainTabIndex,
                () => provider.setMainTabIndex(0),
              ),
              
              // 阅读
              _buildTabItem(
                context,
                '阅读',
                Icons.menu_book,
                1,
                provider.mainTabIndex,
                () => provider.setMainTabIndex(1),
              ),
              
              // 笔记
              _buildTabItem(
                context,
                '笔记',
                Icons.note,
                2,
                provider.mainTabIndex,
                () => provider.setMainTabIndex(2),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个标签项
  Widget _buildTabItem(
    BuildContext context,
    String label,
    IconData icon,
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final isSelected = index == currentIndex;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建标签页内容
  Widget _buildTabContent() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        switch (provider.mainTabIndex) {
          case 0:
            return const MovieTabPage();
          case 1:
            return const BookTabPage();
          case 2:
            return const NoteTabPage();
          default:
            return const MovieTabPage();
        }
      },
    );
  }

  /// 显示添加对话框
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
                  Navigator.pushNamed(context, '/movie-form');
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Colors.orange),
                title: const Text('添加阅读'),
                subtitle: const Text('记录你读过的书'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/book-form');
                },
              ),
              ListTile(
                leading: const Icon(Icons.note, color: Colors.blue),
                title: const Text('添加笔记'),
                subtitle: const Text('记录你的想法和笔记'),
                onTap: () {
                  Navigator.pop(context);
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
