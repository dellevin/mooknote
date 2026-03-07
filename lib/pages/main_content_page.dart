import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'movie_tab_page.dart';
import 'book_tab_page.dart';
import 'note_tab_page.dart';
import 'search_page.dart';
import 'webdav_sync_page.dart';
import '../utils/webdav_service.dart';

/// 云同步模式
enum SyncMode {
  bidirectional, // 双向同步
  uploadOnly, // 仅上传
  downloadOnly, // 仅下载
}

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
            // 云同步按钮
            IconButton(
              icon: const Icon(Icons.cloud_sync_outlined),
              onPressed: () => _showCloudSyncDialog(context, provider),
              tooltip: '云同步',
            ),
            // 搜索按钮
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

  /// 显示云同步对话框
  Future<void> _showCloudSyncDialog(BuildContext context, AppProvider provider) async {
    // 检查是否已配置 WebDAV
    final config = await WebDAVService.instance.getConfig();
    
    if (!context.mounted) return;
    
    // 如果没有配置，直接跳转到配置页面
    if (config == null || config.isEmpty) {
      // 关闭云同步对话框
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // 等待对话框关闭完成
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (!context.mounted) return;
      
      // 跳转到配置页面
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WebDAVSyncPage()),
      );
      
      // 配置页面返回后，重新检查配置
      if (!context.mounted) return;
      
      final newConfig = await WebDAVService.instance.getConfig();
      if (newConfig != null && newConfig.isNotEmpty) {
        // 配置成功，显示同步选项
        _showSyncOptionsDialog(context, provider);
      }
      return;
    }
    
    // 已配置，显示同步选项
    _showSyncOptionsDialog(context, provider);
  }

  /// 显示同步选项对话框
  void _showSyncOptionsDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
                    ),
                  ),
                  child: const Text(
                    '云同步',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                
                // 同步选项
                Column(
                  children: [
                    _buildSyncOption(
                      context,
                      icon: Icons.sync,
                      iconColor: const Color(0xFF1A1A1A),
                      title: '双向同步',
                      subtitle: '本地和云端数据合并，冲突时以最新为准',
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToSync(context, SyncMode.bidirectional);
                      },
                    ),
                    const Divider(height: 0.5, indent: 56, color: Color(0xFFE5E5E5)),
                    _buildSyncOption(
                      context,
                      icon: Icons.cloud_upload,
                      iconColor: const Color(0xFF1A1A1A),
                      title: '仅上传',
                      subtitle: '将本地数据上传到云端，覆盖云端数据',
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToSync(context, SyncMode.uploadOnly);
                      },
                    ),
                    const Divider(height: 0.5, indent: 56, color: Color(0xFFE5E5E5)),
                    _buildSyncOption(
                      context,
                      icon: Icons.cloud_download,
                      iconColor: const Color(0xFF1A1A1A),
                      title: '仅下载',
                      subtitle: '从云端下载数据到本地，覆盖本地数据',
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToSync(context, SyncMode.downloadOnly);
                      },
                    ),
                  ],
                ),
                
                // 取消按钮
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建同步选项
  Widget _buildSyncOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF1A1A1A),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
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
            // 箭头
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

  /// 导航到同步页面
  void _navigateToSync(BuildContext context, SyncMode mode) {
    // TODO: 打开 WebDAV 同步页面并传递同步模式
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => WebDAVSyncPage(syncMode: mode),
    //   ),
    // );
    
    // 暂时显示提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('即将开始${_getSyncModeText(mode)}...'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 获取同步模式文本
  String _getSyncModeText(SyncMode mode) {
    switch (mode) {
      case SyncMode.bidirectional:
        return '双向同步';
      case SyncMode.uploadOnly:
        return '上传';
      case SyncMode.downloadOnly:
        return '下载';
    }
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
