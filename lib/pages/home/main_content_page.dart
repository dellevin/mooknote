import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/responsive.dart';
import '../../services/sync/webdav_service.dart';
import '../movies/movie_tab_page.dart';
import '../book/book_tab_page.dart';
import '../note/note_tab_page.dart';
import '../game/game_tab_page.dart';
import '../online_search/search_page.dart';
import '../online_search/online_search_page.dart';
import '../sync/webdav_sync_page.dart';

/// 主内容页 - 观影/阅读/笔记标签页（PageView 滑动切换）
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
  bool _showGameTab = true;

  late PageController _pageController;
  bool _isTabTap = false;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadTabSettings();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadTabSettings() {
    final newMovie = _userPrefs.showMovieTab;
    final newBook = _userPrefs.showBookTab;
    final newNote = _userPrefs.showNoteTab;
    final newGame = _userPrefs.showGameTab;
    if (newMovie != _showMovieTab || newBook != _showBookTab ||
        newNote != _showNoteTab || newGame != _showGameTab) {
      setState(() {
        _showMovieTab = newMovie;
        _showBookTab = newBook;
        _showNoteTab = newNote;
        _showGameTab = newGame;
      });
    }
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
    if (_showGameTab) tabs.add(_TabItem('游戏', 3));
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
        if (!Breakpoint.isDesktop(context)) ...[
          _buildAppBar(context),
          _buildTabBar(context),
        ],
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  // ─── AppBar ──────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        return AppBar(
          titleSpacing: 8,
          leadingWidth: 44,
          title: Text(_getAppBarTitle(provider)),
          actionsPadding: const EdgeInsets.only(right: 4),
          actions: [
            _buildCloudSyncButton(context),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
            ),
            if (UserPrefs().enhancedSearchEnabled)
              IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.search, size: 22),
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, size: 10, color: colors.onSurface),
                    ),
                  ),
                ],
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineSearchPage())),
            ),
          ],
        );
      },
    );
  }

  String _getAppBarTitle(AppProvider provider) {
    switch (provider.mainTabIndex) {
      case -1: return '主页';
      case 0: return '影视';
      case 1: return '阅读';
      case 2: return '笔记';
      case 3: return '游戏';
      default: return 'MookNote';
    }
  }


  // ─── 云备份 ──────────────────────────────────────────

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
        return _CloudSheetContent(hasConfig: hasConfig);
      },
    );
  }

  // ─── Tab 栏 + 指示条 ─────────────────────────────────

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
                      onTap: () {
                        _isTabTap = true;
                        _pageController.animateToPage(idx, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                        provider.setMainTabIndex(tab.originalIndex);
                        Future.delayed(const Duration(milliseconds: 400), () => _isTabTap = false);
                      },
                      onLongPress: tab.label == '影视'
                          ? () {
                              final isWallMode = UserPrefs().movieWallMode;
                              _showSortMenu(context, isWallMode ? '影视墙排序' : '影视排序', UserPrefs().movieSortMode, [
                                (0, '按更新时间排序', Icons.update),
                                (1, '按创建时间排序', Icons.calendar_today_outlined),
                                (2, '按评分排序', Icons.star_outline),
                              ], (v) { UserPrefs().setMovieSortMode(v); context.read<AppProvider>().loadMovies(); });
                            }
                          : tab.label == '阅读'
                              ? () {
                                  final isWallMode = UserPrefs().bookshelfMode;
                                  _showSortMenu(context, isWallMode ? '书架排序' : '书籍排序', UserPrefs().bookSortMode, [
                                    (0, '按更新时间排序', Icons.update),
                                    (1, '按创建时间排序', Icons.calendar_today_outlined),
                                    (2, '按评分排序', Icons.star_outline),
                                  ], (v) { UserPrefs().setBookSortMode(v); context.read<AppProvider>().loadBooks(); });
                                }
                              : tab.label == '笔记'
                                  ? () => _showSortMenu(context, '笔记排序', UserPrefs().noteSortMode, [
                                      (0, '按更新时间排序', Icons.update),
                                      (1, '按创建时间排序', Icons.calendar_today_outlined),
                                    ], (v) { UserPrefs().setNoteSortMode(v); context.read<AppProvider>().loadNotes(); })
                                  : tab.label == '游戏'
                                      ? () {
                                          final isWallMode = UserPrefs().gameWallMode;
                                          _showSortMenu(context, isWallMode ? '游戏墙排序' : '游戏排序', UserPrefs().gameSortMode, [
                                            (0, '按更新时间排序', Icons.update),
                                            (1, '按创建时间排序', Icons.calendar_today_outlined),
                                            (2, '按评分排序', Icons.star_outline),
                                          ], (v) { UserPrefs().setGameSortMode(v); context.read<AppProvider>().loadGames(); });
                                        }
                                      : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                          Icon(_tabIcon(tab.label), size: 18, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3)),
                          const SizedBox(width: 5),
                          Text(tab.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3))),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            AnimatedBuilder(
              animation: _pageController,
              builder: (context, _) {
                final page = _pageController.hasClients ? _pageController.page ?? 0.0 : safeIndex.toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabWidth = tabs.isNotEmpty ? constraints.maxWidth / tabs.length : 0.0;
                      return SizedBox(height: 2.5, child: Stack(children: [
                        Positioned(
                          left: page * tabWidth,
                          top: 0,
                          width: tabWidth,
                          child: Container(height: 2.5, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2))),
                        ),
                      ]));
                    },
                  ),
                );
              },
            ),
          ]),
        );
      },
    );
  }

  void _showSortMenu(BuildContext context, String title, int current, List<(int, String, IconData)> options, ValueChanged<int> onSelected) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
          const SizedBox(height: 8),
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant),
            _sortOption(ctx, options[i].$1, options[i].$2, options[i].$3, current, colors, onSelected),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _sortOption(BuildContext ctx, int value, String label, IconData icon, int current, ColorScheme colors, ValueChanged<int> onSelected) {
    final selected = current == value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: colors.onSurface)),
      trailing: selected ? Icon(Icons.check, size: 20, color: colors.primary) : null,
      onTap: () {
        Navigator.pop(ctx);
        onSelected(value);
      },
    );
  }

  // ─── PageView 内容区 ───

  Widget _buildTabContent() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final tabs = _enabledTabs;
        final safeIndex = _mapToEnabledTabIndex(provider.mainTabIndex).clamp(0, tabs.length - 1);

        // 从其他页面返回时，修正 PageView 页面与 tab 的一致性
        if (!_syncScheduled) {
          _syncScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncScheduled = false;
            if (!mounted || !_pageController.hasClients) return;
            final currentPage = _pageController.page?.round() ?? 0;
            if (currentPage != safeIndex) {
              _pageController.jumpToPage(safeIndex);
            }
          });
        }

        if (_isTabTap && _pageController.hasClients) {
          _isTabTap = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            _pageController.animateToPage(safeIndex, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
          });
        }

        return PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // 仅点击标签栏切换，禁止滑动切换
          onPageChanged: (index) {
            if (!_isTabTap && index < tabs.length) {
              provider.setMainTabIndex(tabs[index].originalIndex);
            }
          },
          children: [
            if (_showMovieTab) const MovieTabPage(),
            if (_showBookTab) const BookTabPage(),
            if (_showNoteTab) const NoteTabPage(),
            if (_showGameTab) const GameTabPage(),
          ],
        );
      },
    );
  }

  IconData _tabIcon(String label) {
    switch (label) {
      case '影视': return Icons.movie_outlined;
      case '阅读': return Icons.menu_book_outlined;
      case '笔记': return Icons.note_outlined;
      case '游戏': return Icons.sports_esports_outlined;
      default: return Icons.circle;
    }
  }
}

class _TabItem {
  final String label;
  final int originalIndex;
  _TabItem(this.label, this.originalIndex);
}

/// 云备份弹窗内容（异步加载远程信息，避免阻塞弹窗弹出）
class _CloudSheetContent extends StatefulWidget {
  final bool hasConfig;
  const _CloudSheetContent({required this.hasConfig});

  @override
  State<_CloudSheetContent> createState() => _CloudSheetContentState();
}

class _CloudSheetContentState extends State<_CloudSheetContent> {
  DateTime? _modifiedTime;
  int? _remoteSize;
  bool _loading = true;
  bool _syncing = false;
  String _syncStep = '';

  @override
  void initState() {
    super.initState();
    if (widget.hasConfig) {
      _loadRemoteInfo();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadRemoteInfo() async {
    setState(() => _loading = true);
    final info = await WebDAVService.instance.getRemoteBackupInfo();
    if (mounted) {
      setState(() {
        _modifiedTime = info?['modifiedTime'] as DateTime?;
        _remoteSize = info?['size'] as int?;
        _loading = false;
      });
    }
  }

  Future<void> _performSync(SyncDirection direction) async {
    // 保存外层 navigator，pop bottom sheet 后还能用它弹 dialog
    final navigator = Navigator.of(context);

    if (direction == SyncDirection.upload) {
      // 上传：先打包，再上传
      setState(() => _syncStep = '正在打包数据...');
      await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
      final exportResult = await WebDAVService.instance.exportLocalData();
      if (!exportResult.success || exportResult.zipPath == null) {
        if (mounted) {
          Navigator.pop(context); // 关闭 bottom sheet
          _showResultDialog(navigator, title: '同步失败', message: exportResult.errorMessage ?? '创建备份失败', isSuccess: false);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _syncStep = '正在上传到云端...');
      await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
      final result = await WebDAVService.instance.uploadExportedData(exportResult);
      if (result.success && result.needReload && mounted) {
        final provider = context.read<AppProvider>();
        await provider.loadMovies();
        await provider.loadBooks();
        await provider.loadNotes();
        await provider.loadGames();
      }
      if (mounted) {
        setState(() => _syncing = false);
        Navigator.pop(context); // 关闭 bottom sheet
      }
      _showResultDialog(navigator,
        title: result.success ? '同步成功' : '同步失败',
        message: result.message.isNotEmpty ? result.message : (result.success ? '同步成功' : '同步失败'),
        isSuccess: result.success,
        details: {'uploaded': result.uploadedFiles + result.uploadedImages, 'downloaded': result.downloadedFiles + result.downloadedImages},
      );
    } else {
      // 下载
      setState(() => _syncStep = '正在从云端下载...');
      await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
      final config = await WebDAVService.instance.getConfig();
      if (config == null) {
        if (mounted) {
          Navigator.pop(context);
          _showResultDialog(navigator, title: '同步失败', message: '请先配置 WebDAV 服务器', isSuccess: false);
        }
        return;
      }
      final result = await WebDAVService.instance.syncData(direction: SyncDirection.download);
      if (result.success && result.needReload && mounted) {
        final provider = context.read<AppProvider>();
        await provider.loadMovies();
        await provider.loadBooks();
        await provider.loadNotes();
        await provider.loadGames();
      }
      if (mounted) {
        setState(() => _syncing = false);
        Navigator.pop(context); // 关闭 bottom sheet
      }
      _showResultDialog(navigator,
        title: result.success ? '同步成功' : '同步失败',
        message: result.message.isNotEmpty ? result.message : (result.success ? '同步成功' : '同步失败'),
        isSuccess: result.success,
        details: {'uploaded': result.uploadedFiles + result.uploadedImages, 'downloaded': result.downloadedFiles + result.downloadedImages},
      );
    }
  }

  void _startSync(SyncDirection direction) {
    setState(() {
      _syncing = true;
      _syncStep = '';
    });
    _performSync(direction);
  }

  @override
  Widget build(BuildContext context) {
    final bc = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(
            width: 36, height: 4, margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: bc.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
          )),
          Text('云备份', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: bc.onSurface)),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: bc.primary)),
            )
          else if (_modifiedTime != null || _remoteSize != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bc.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.info_outline, size: 14, color: bc.onSurface.withValues(alpha: 0.3)),
                const SizedBox(width: 6),
                Text('云端备份', style: TextStyle(fontSize: 11, color: bc.onSurface.withValues(alpha: 0.4))),
                const Spacer(),
                if (_modifiedTime != null) Text(_formatDateTime(_modifiedTime!), style: TextStyle(fontSize: 11, color: bc.onSurface.withValues(alpha: 0.5))),
                if (_modifiedTime != null && _remoteSize != null) Text('  ·  ', style: TextStyle(fontSize: 11, color: bc.onSurface.withValues(alpha: 0.2))),
                if (_remoteSize != null) Text(_formatFileSize(_remoteSize!), style: TextStyle(fontSize: 11, color: bc.onSurface.withValues(alpha: 0.5))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          if (_syncing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(children: [
                SizedBox(
                  width: 180,
                  child: LinearProgressIndicator(
                    backgroundColor: bc.surfaceContainerHighest,
                    color: bc.primary,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(height: 12),
                Text(_syncStep, style: TextStyle(fontSize: 13, color: bc.onSurface.withValues(alpha: 0.6))),
              ]),
            ),
          ] else ...[
            _cloudCard(icon: Icons.cloud_upload_outlined, title: '上传数据', desc: widget.hasConfig ? '将本地数据同步到云端' : '请先配置 WebDAV 服务器', enabled: widget.hasConfig, onTap: widget.hasConfig ? () => _startSync(SyncDirection.upload) : null, colors: bc),
            const SizedBox(height: 8),
            _cloudCard(icon: Icons.cloud_download_outlined, title: '下载数据', desc: widget.hasConfig ? '从云端恢复数据到本地' : '请先配置 WebDAV 服务器', enabled: widget.hasConfig, onTap: widget.hasConfig ? () => _startSync(SyncDirection.download) : null, colors: bc),
            const SizedBox(height: 8),
            _cloudCard(icon: Icons.settings_outlined, title: 'WebDAV 设置', desc: '配置服务器地址与认证信息', enabled: true, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSyncPage())); }, colors: bc),
          ],
        ]),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _cloudCard({required IconData icon, required String title, required String desc, required bool enabled, required VoidCallback? onTap, required ColorScheme colors}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: enabled ? colors.primary.withValues(alpha: 0.04) : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: enabled ? colors.primary.withValues(alpha: 0.1) : colors.outlineVariant, width: 0.5),
        ),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: enabled ? colors.primary.withValues(alpha: 0.08) : colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 20, color: enabled ? colors.primary : colors.onSurface.withValues(alpha: 0.18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: enabled ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25))),
            const SizedBox(height: 1),
            Text(desc, style: TextStyle(fontSize: 11, color: enabled ? colors.onSurface.withValues(alpha: 0.4) : colors.onSurface.withValues(alpha: 0.2))),
          ])),
          Icon(Icons.chevron_right, size: 20, color: enabled ? colors.onSurface.withValues(alpha: 0.15) : colors.onSurface.withValues(alpha: 0.08)),
        ]),
      ),
    );
  }

  void _showResultDialog(NavigatorState navigator, {required String title, required String message, required bool isSuccess, Map<String, dynamic>? details}) {
    // 使用保存的 navigator context，而非 state context（bottom sheet 已 pop）
    final overlayCtx = navigator.context;
    final colors = Theme.of(overlayCtx).colorScheme;
    showDialog(
      context: overlayCtx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)), child: Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373), size: 24)),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          if (details != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (details['uploaded'] != null) _detailRow('上传文件', '${details['uploaded']} 个', colors),
            if (details['downloaded'] != null) _detailRow('下载文件', '${details['downloaded']} 个', colors),
          ]))],
        ]),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(dialogCtx), style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: const Text('确定'))],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
    ]),
  );
}
