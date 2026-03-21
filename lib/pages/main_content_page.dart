import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/sync/webdav_service.dart';
import '../utils/toast_util.dart';
import 'movies/movie_tab_page.dart';
import 'book/book_tab_page.dart';
import 'note/note_tab_page.dart';
import 'search_page.dart';
import 'sync/webdav_sync_page.dart';

/// 主内容页 - 观影/阅读/笔记标签页
class MainContentPage extends StatefulWidget {
  const MainContentPage({super.key});

  @override
  State<MainContentPage> createState() => _MainContentPageState();
}

class _MainContentPageState extends State<MainContentPage> {
  final UserPrefs _userPrefs = UserPrefs();

  bool _showMovieTab = true;
  bool _showBookTab = true;
  bool _showNoteTab = true;

  @override
  void initState() {
    super.initState();
    _loadTabSettings();
  }

  /// 加载标签显示设置
  void _loadTabSettings() {
    setState(() {
      _showMovieTab = _userPrefs.showMovieTab;
      _showBookTab = _userPrefs.showBookTab;
      _showNoteTab = _userPrefs.showNoteTab;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当页面重新获得焦点时刷新设置
    _loadTabSettings();
  }

  /// 获取启用的标签列表
  List<_TabItem> get _enabledTabs {
    final tabs = <_TabItem>[];
    if (_showMovieTab) tabs.add(_TabItem('影视', 0));
    if (_showBookTab) tabs.add(_TabItem('阅读', 1));
    if (_showNoteTab) tabs.add(_TabItem('笔记', 2));
    return tabs;
  }

  /// 将原始索引映射到启用标签的索引
  int _mapToEnabledTabIndex(int originalIndex) {
    final tabs = _enabledTabs;
    for (int i = 0; i < tabs.length; i++) {
      if (tabs[i].originalIndex == originalIndex) return i;
    }
    return 0;
  }

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
            // 云备份按钮
            _buildCloudSyncButton(context),
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

  /// 构建云备份按钮
  Widget _buildCloudSyncButton(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.cloud_sync_outlined),
      tooltip: '云备份',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '上传数据',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'download',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.cloud_download_outlined,
                  size: 18,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '下载数据',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'WebDAV设置',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        switch (value) {
          case 'upload':
            await _performSync(context, SyncDirection.upload);
            break;
          case 'download':
            await _performSync(context, SyncDirection.download);
            break;
          case 'settings':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WebDAVSyncPage(),
              ),
            );
            break;
        }
      },
    );
  }

  /// 执行同步操作
  Future<void> _performSync(BuildContext context, SyncDirection direction) async {
    // 检查是否已配置
    final config = await WebDAVService.instance.getConfig();
    if (config == null) {
      if (context.mounted) {
        _showResultDialog(
          context,
          title: '同步失败',
          message: '请先配置 WebDAV 服务器',
          isSuccess: false,
        );
      }
      return;
    }

    // 显示加载对话框
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1A1A1A),
          ),
        ),
      );
    }

    // 执行同步
    final result = await WebDAVService.instance.syncData(direction: direction);

    // 关闭加载对话框
    if (context.mounted) {
      Navigator.pop(context);
    }

    // 显示结果
    if (context.mounted) {
      final isSuccess = result.success;
      final message = result.message.isNotEmpty ? result.message : (isSuccess ? '同步成功' : '同步失败');
      
      _showResultDialog(
        context,
        title: isSuccess ? '同步成功' : '同步失败',
        message: message,
        isSuccess: isSuccess,
        details: {
          'uploaded': result.uploadedFiles + result.uploadedImages,
          'downloaded': result.downloadedFiles + result.downloadedImages,
        },
      );
    }
  }

  /// 显示同步结果对话框
  void _showResultDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
    Map<String, dynamic>? details,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (details['uploaded'] != null)
                      _buildDetailRow('上传文件', '${details['uploaded']} 个'),
                    if (details['downloaded'] != null)
                      _buildDetailRow('下载文件', '${details['downloaded']} 个'),
                    if (details['conflicts'] != null)
                      _buildDetailRow('冲突处理', '${details['conflicts']} 个'),
                    if (details['errors'] != null && details['errors'] > 0)
                      _buildDetailRow('错误', '${details['errors']} 个', isError: true),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('确定'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 构建详情行
  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF999999),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isError ? const Color(0xFFE57373) : const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取 AppBar 标题
  String _getAppBarTitle(AppProvider provider) {
    switch (provider.mainTabIndex) {
      case 0:
        return '影视';
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
        final tabs = _enabledTabs;
        // 如果当前选中的标签被禁用了，切换到第一个启用的标签
        final currentEnabledIndex = _mapToEnabledTabIndex(provider.mainTabIndex);
        final safeIndex = currentEnabledIndex < tabs.length ? currentEnabledIndex : 0;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
            ),
          ),
          child: Row(
            children: tabs.asMap().entries.map((entry) {
              final index = entry.key;
              final tab = entry.value;
              return _buildTabItem(
                context,
                tab.label,
                index,
                safeIndex,
                () => provider.setMainTabIndex(tab.originalIndex),
              );
            }).toList(),
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
        final tabs = _enabledTabs;
        // 找到当前应该显示的标签
        _TabItem? currentTab;
        for (final tab in tabs) {
          if (tab.originalIndex == provider.mainTabIndex) {
            currentTab = tab;
            break;
          }
        }
        // 如果当前标签被禁用了，显示第一个启用的标签
        if (currentTab == null && tabs.isNotEmpty) {
          currentTab = tabs.first;
          // 更新 provider 的索引
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.setMainTabIndex(currentTab!.originalIndex);
          });
        }

        if (currentTab == null) {
          return const Center(child: Text('请至少启用一个标签页'));
        }

        switch (currentTab.originalIndex) {
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

/// 标签项数据类
class _TabItem {
  final String label;
  final int originalIndex;

  _TabItem(this.label, this.originalIndex);
}
