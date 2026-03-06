import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'movie_tab_page.dart';
import 'book_tab_page.dart';
import 'note_tab_page.dart';
import 'search_page.dart';

/// 主内容页 - 观影/阅读/笔记标签页
class MainContentPage extends StatelessWidget {
  const MainContentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部 AppBar
        _buildAppBar(context),
        
        // 三个标签页的标题栏
        _buildTabBar(context),
        
        // 标签页内容
        Expanded(
          child: _buildTabContent(),
        ),
      ],
    );
  }

  /// 构建顶部 AppBar
  Widget _buildAppBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return AppBar(
          title: Text(_getAppBarTitle(provider)),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchPage(),
                  ),
                );
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
  Widget _buildTabBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              _buildTabItem(
                context,
                '观影',
                0,
                provider.mainTabIndex,
                () => provider.setMainTabIndex(0),
              ),
              _buildTabItem(
                context,
                '阅读',
                1,
                provider.mainTabIndex,
                () => provider.setMainTabIndex(1),
              ),
              _buildTabItem(
                context,
                '笔记',
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
    int index,
    int currentIndex,
    VoidCallback onTap,
  ) {
    final isSelected = index == currentIndex;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected 
                      ? const Color(0xFF1A1A1A) 
                      : const Color(0xFF999999),
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 20,
                  height: 2,
                  color: const Color(0xFF1A1A1A),
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.movie, color: Color(0xFF1A1A1A)),
                title: const Text('添加观影'),
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
              const Divider(height: 0.5, indent: 56),
              ListTile(
                leading: const Icon(Icons.menu_book, color: Color(0xFF1A1A1A)),
                title: const Text('添加阅读'),
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
              const Divider(height: 0.5, indent: 56),
              ListTile(
                leading: const Icon(Icons.note, color: Color(0xFF1A1A1A)),
                title: const Text('添加笔记'),
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
