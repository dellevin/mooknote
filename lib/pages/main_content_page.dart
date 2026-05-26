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
        Expanded(child: _buildTabContent()),
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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCloudSyncButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.cloud_sync_outlined),
      tooltip: '云备份',
      onPressed: () => _showCloudSheet(context),
    );
  }

  void _showCloudSheet(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final hasConfig = (await WebDAVService.instance.getConfig()) != null;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final bc = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: bc.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
              )),
              Text('云备份', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: bc.onSurface)),
              const SizedBox(height: 20),
              _cloudCard(
                icon: Icons.cloud_upload_outlined,
                title: '上传数据',
                desc: hasConfig ? '将本地数据同步到云端' : '请先配置 WebDAV 服务器',
                onTap: hasConfig ? () { Navigator.pop(ctx); _performSync(context, SyncDirection.upload); } : null,
                enabled: hasConfig,
                colors: bc,
              ),
              const SizedBox(height: 12),
              _cloudCard(
                icon: Icons.cloud_download_outlined,
                title: '下载数据',
                desc: hasConfig ? '从云端恢复数据到本地' : '请先配置 WebDAV 服务器',
                onTap: hasConfig ? () { Navigator.pop(ctx); _performSync(context, SyncDirection.download); } : null,
                enabled: hasConfig,
                colors: bc,
              ),
              const SizedBox(height: 12),
              _cloudCard(
                icon: Icons.settings_outlined,
                title: 'WebDAV 设置',
                desc: '配置服务器地址与认证信息',
                onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSyncPage())); },
                enabled: true,
                colors: bc,
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _cloudCard({required IconData icon, required String title, required String desc, required bool enabled, required VoidCallback? onTap, required ColorScheme colors}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled ? colors.primary.withValues(alpha: 0.04) : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: enabled ? colors.primary.withValues(alpha: 0.1) : colors.outlineVariant, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: enabled ? colors.primary.withValues(alpha: 0.08) : colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: enabled ? colors.primary : colors.onSurface.withValues(alpha: 0.18)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: enabled ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25))),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 12, color: enabled ? colors.onSurface.withValues(alpha: 0.4) : colors.onSurface.withValues(alpha: 0.2))),
          ])),
          Icon(Icons.chevron_right, size: 20, color: enabled ? colors.onSurface.withValues(alpha: 0.15) : colors.onSurface.withValues(alpha: 0.08)),
        ]),
      ),
    );
  }

  Future<void> _performSync(BuildContext context, SyncDirection direction) async {
    final colors = Theme.of(context).colorScheme;
    final config = await WebDAVService.instance.getConfig();
    if (config == null) {
      if (context.mounted) _showResultDialog(context, title: '同步失败', message: '请先配置 WebDAV 服务器', isSuccess: false);
      return;
    }
    if (context.mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: colors.primary)));
    }
    final result = await WebDAVService.instance.syncData(direction: direction);
    if (context.mounted) Navigator.pop(context);
    if (result.success && result.needReload && context.mounted) {
      final provider = context.read<AppProvider>();
      await provider.loadMovies();
      await provider.loadBooks();
      await provider.loadNotes();
    }
    if (context.mounted) {
      _showResultDialog(context,
        title: result.success ? '同步成功' : '同步失败',
        message: result.message.isNotEmpty ? result.message : (result.success ? '同步成功' : '同步失败'),
        isSuccess: result.success,
        details: {'uploaded': result.uploadedFiles + result.uploadedImages, 'downloaded': result.downloadedFiles + result.downloadedImages},
      );
    }
  }

  void _showResultDialog(BuildContext context, {required String title, required String message, required bool isSuccess, Map<String, dynamic>? details}) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
            child: Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373), size: 24),
          ),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          if (details != null) ...[
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (details['uploaded'] != null) _detailRow('上传文件', '${details['uploaded']} 个', colors),
              if (details['downloaded'] != null) _detailRow('下载文件', '${details['downloaded']} 个', colors),
            ])),
          ],
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            child: const Text('确定'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme colors) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
    ]),
  );

  String _getAppBarTitle(AppProvider provider) {
    switch (provider.mainTabIndex) {
      case 0: return '影视';
      case 1: return '阅读';
      case 2: return '笔记';
      default: return 'MookNote';
    }
  }

  Widget _buildTabBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        final tabs = _enabledTabs;
        final safeIndex = _mapToEnabledTabIndex(provider.mainTabIndex).clamp(0, tabs.length - 1);

        return Container(
          color: colors.surface,
          padding: const EdgeInsets.only(top: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: tabs.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final tab = entry.value;
                  final selected = idx == safeIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => provider.setMainTabIndex(tab.originalIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _tabIcon(tab.label),
                              size: 18,
                              color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(width: 5),
                            Text(tab.label, textAlign: TextAlign.center, style: TextStyle(
                              fontSize: 15,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3),
                            )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = tabs.isNotEmpty ? constraints.maxWidth / tabs.length : 0.0;
                  return SizedBox(height: 2.5, child: Stack(children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                      left: safeIndex * tabWidth, top: 0,
                      width: tabWidth,
                      child: Container(height: 2.5, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2))),
                    ),
                  ]));
                },
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildTabContent() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final tabs = _enabledTabs;
        _TabItem? currentTab;
        for (final tab in tabs) { if (tab.originalIndex == provider.mainTabIndex) { currentTab = tab; break; } }
        if (currentTab == null && tabs.isNotEmpty) {
          currentTab = tabs.first;
          WidgetsBinding.instance.addPostFrameCallback((_) => provider.setMainTabIndex(currentTab!.originalIndex));
        }
        if (currentTab == null) return const Center(child: Text('请至少启用一个标签页'));
        switch (currentTab.originalIndex) {
          case 0: return const MovieTabPage();
          case 1: return const BookTabPage();
          case 2: return const NoteTabPage();
          default: return const MovieTabPage();
        }
      },
    );
  }

  IconData _tabIcon(String label) {
    switch (label) {
      case '影视': return Icons.movie_outlined;
      case '阅读': return Icons.menu_book_outlined;
      case '笔记': return Icons.note_outlined;
      default: return Icons.circle;
    }
  }

  void _showAddDialog(BuildContext context, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context, backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: Icon(Icons.movie, color: colors.onSurface), title: const Text('添加观影'), onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/movie-form', arguments: {'initialStatus': ['watched', 'watching', 'want_to_watch'][provider.movieStatusIndex]}); }),
          Divider(height: 0.5, indent: 56, color: colors.outlineVariant),
          ListTile(leading: Icon(Icons.menu_book, color: colors.onSurface), title: const Text('添加阅读'), onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/book-form', arguments: {'initialStatus': ['read', 'reading', 'want_to_read'][provider.bookStatusIndex]}); }),
          Divider(height: 0.5, indent: 56, color: colors.outlineVariant),
          ListTile(leading: Icon(Icons.note, color: colors.onSurface), title: const Text('添加笔记'), onTap: () { Navigator.pop(context); Navigator.pushNamed(context, '/note-form'); }),
        ]),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final int originalIndex;
  _TabItem(this.label, this.originalIndex);
}
