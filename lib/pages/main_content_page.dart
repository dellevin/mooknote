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
    _loadTabSettings();
  }

  List<_TabItem> get _enabledTabs {
    final tabs = <_TabItem>[];
    if (_showMovieTab) tabs.add(_TabItem('影视', 0));
    if (_showBookTab) tabs.add(_TabItem('阅读', 1));
    if (_showNoteTab) tabs.add(_TabItem('笔记', 2));
    return tabs;
  }

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
        _buildAppBar(context),
        _buildTabBar(context),
        Expanded(
          child: _buildTabContent(),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        return AppBar(
          title: Text(_getAppBarTitle(provider)),
          actions: [
            _buildCloudSyncButton(context),
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

  Widget _buildCloudSyncButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '上传数据',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
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
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.cloud_download_outlined,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '下载数据',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
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
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'WebDAV设置',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
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

  Future<void> _performSync(BuildContext context, SyncDirection direction) async {
    final colors = Theme.of(context).colorScheme;
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

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            color: colors.primary,
          ),
        ),
      );
    }

    final result = await WebDAVService.instance.syncData(direction: direction);

    if (context.mounted) {
      Navigator.pop(context);
    }

    if (result.success && result.needReload && context.mounted) {
      final provider = context.read<AppProvider>();
      await provider.loadMovies();
      await provider.loadBooks();
      await provider.loadNotes();
    }

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

  void _showResultDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
    Map<String, dynamic>? details,
  }) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
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
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
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
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
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

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isError ? const Color(0xFFE57373) : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

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

  IconData _getTabIcon(String label) {
    switch (label) {
      case '影视':
        return Icons.movie_outlined;
      case '阅读':
        return Icons.menu_book_outlined;
      case '笔记':
        return Icons.notes;
      default:
        return Icons.circle;
    }
  }

  Widget _buildTabBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        final tabs = _enabledTabs;
        final currentEnabledIndex = _mapToEnabledTabIndex(provider.mainTabIndex);
        final safeIndex = currentEnabledIndex < tabs.length ? currentEnabledIndex : 0;

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 14),
                child: Row(
                  children: tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    final isSelected = index == safeIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => provider.setMainTabIndex(tab.originalIndex),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getTabIcon(tab.label),
                                size: 22,
                                color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tab.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final indicatorWidth = 24.0;
                    final tabWidth = constraints.maxWidth / tabs.length;
                    final indicatorLeft = safeIndex * tabWidth + (tabWidth - indicatorWidth) / 2;
                    return SizedBox(
                      height: 3,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOut,
                            left: indicatorLeft,
                            top: 0,
                            child: Container(
                              width: indicatorWidth,
                              height: 3,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(height: 0.5, thickness: 0.5, color: colors.outline),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final tabs = _enabledTabs;
        _TabItem? currentTab;
        for (final tab in tabs) {
          if (tab.originalIndex == provider.mainTabIndex) {
            currentTab = tab;
            break;
          }
        }
        if (currentTab == null && tabs.isNotEmpty) {
          currentTab = tabs.first;
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

  void _showAddDialog(BuildContext context, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.movie, color: colors.onSurface),
                title: const Text('添加观影'),
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
              Divider(height: 0.5, indent: 56, color: colors.outlineVariant),
              ListTile(
                leading: Icon(Icons.menu_book, color: colors.onSurface),
                title: const Text('添加阅读'),
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
              Divider(height: 0.5, indent: 56, color: colors.outlineVariant),
              ListTile(
                leading: Icon(Icons.note, color: colors.onSurface),
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

class _TabItem {
  final String label;
  final int originalIndex;

  _TabItem(this.label, this.originalIndex);
}
