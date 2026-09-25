import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/responsive.dart';
import '../../services/sync/webdav_service.dart';
import '../../services/sync/incremental/inc_sync_service.dart';
import '../movies/movie_tab_page.dart';
import '../book/book_tab_page.dart';
import '../note/note_tab_page.dart';
import '../game/game_tab_page.dart';
import '../online_search/search_hub_page.dart';
import '../sync/webdav_sync_page.dart';
import '../../widgets/app_overlay.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';

/// 主内容页 - 影视/阅读/游戏/笔记标签页（Stack 常驻 + AnimatedOpacity 交叉淡化切换）
class MainContentPage extends StatefulWidget {
  const MainContentPage({super.key});

  @override
  State<MainContentPage> createState() => _MainContentPageState();
}

class _MainContentPageState extends State<MainContentPage> {
  final UserPrefs _userPrefs = UserPrefs();

  // 直接读取 UserPrefs，不缓存到 State——否则 AppProvider 通知重建时
  // 拿到的仍是旧值（Consumer 的依赖注册在内部 element 上，
  // 不会触发本 State 的 didChangeDependencies）
  bool get _showMovieTab => _userPrefs.showMovieTab;
  bool get _showBookTab => _userPrefs.showBookTab;
  bool get _showNoteTab => _userPrefs.showNoteTab;
  bool get _showGameTab => _userPrefs.showGameTab;

  /// 点击标签：内容区由 provider.mainTabIndex 声明式驱动（AnimatedOpacity 交叉淡化），
  /// 只需更新索引，无任何时序窗口，不会回跳
  void _switchToTab(int originalIndex) {
    final provider = context.read<AppProvider>();
    final target = _mapToEnabledTabIndex(originalIndex);
    if (target == _mapToEnabledTabIndex(provider.mainTabIndex)) return;
    provider.setMainTabIndex(originalIndex);
  }

  List<_TabItem> get _enabledTabs {
    final tabs = <_TabItem>[];
    if (_showMovieTab) tabs.add(_TabItem('影视', 0));
    if (_showBookTab) tabs.add(_TabItem('阅读', 1));
    if (_showGameTab) tabs.add(_TabItem('游戏', 3));
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
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final isDropdown = provider.homeModuleSwitchMode == 1;
        return Column(
          children: [
            if (!Breakpoint.isDesktop(context)) ...[
              _buildAppBar(context, isDropdown),
              // 只剩一个模块时，顶部模块分类栏没有显示必要
              if (!isDropdown && _enabledTabs.length > 1) _buildTabBar(context),
            ],
            Expanded(child: _buildTabContent()),
          ],
        );
      },
    );
  }

  // ─── AppBar ──────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, bool isDropdown) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        return AppBar(
          titleSpacing: 8,
          leadingWidth: 44,
          title: isDropdown && _enabledTabs.length > 1
              ? _buildDropdownTitle(context, provider, colors)
              : Text(_getAppBarTitle(provider)),
          actionsPadding: const EdgeInsets.only(right: 4),
          actions: [
            _buildCloudSyncButton(context),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchHubPage())),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDropdownTitle(BuildContext context, AppProvider provider, ColorScheme colors) {
    final tabs = _enabledTabs;
    final safeIndex = _mapToEnabledTabIndex(provider.mainTabIndex).clamp(0, tabs.length - 1);
    final currentLabel = tabs.isEmpty ? '主页' : tabs[safeIndex].label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showModulePicker(context, tabs, safeIndex),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_tabIcon(currentLabel), size: 20, color: colors.primary),
          const SizedBox(width: 6),
          Text(currentLabel.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 22, color: colors.onSurface.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  void _showModulePicker(BuildContext context, List<_TabItem> tabs, int currentIndex) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          for (int i = 0; i < tabs.length; i++) ...[
            if (i > 0) Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant),
            _modulePickerItem(ctx, tabs[i], i, i == currentIndex, colors),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _modulePickerItem(BuildContext ctx, _TabItem tab, int idx, bool selected, ColorScheme colors) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
          child: Icon(_tabIcon(tab.label), size: 20, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
      title: Text(tab.label.tr, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: colors.onSurface)),
      trailing: selected ? Icon(Icons.check, size: 20, color: colors.primary) : null,
      onTap: () {
        Navigator.pop(ctx);
        _switchToTab(tab.originalIndex);
      },
    );
  }

  String _getAppBarTitle(AppProvider provider) {
    switch (provider.mainTabIndex) {
      case -1: return '主页'.tr;
      case 0: case 1: case 2: case 3:
        // 只剩一个模块时，不显示模块分类名称
        if (_enabledTabs.length <= 1) return 'MookNote';
        return const ['影视', '阅读', '笔记', '游戏'][provider.mainTabIndex].tr;
      default: return 'MookNote';
    }
  }


  // ─── 云备份 ──────────────────────────────────────────

  Widget _buildCloudSyncButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.cloud_sync_outlined),
      tooltip: '云备份'.tr,
      onPressed: () => _showCloudSheet(context),
    );
  }

  void _showCloudSheet(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final hasConfig = (await WebDAVService.instance.getConfig()) != null;
    if (!mounted) return;
    appModalBottomSheet(
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
          // 每个分类固定为可用宽度的 1/4：≤4 个时排满不滚动，与原来一致；
          // 以后新增分类超过 4 个时横向滚动，指示器在滚动内容内随标签移动
          child: LayoutBuilder(
            builder: (context, outer) {
              const maxVisibleTabs = 4;
              // 宽度不足 48（热身帧/极窄窗口）时兜底为 0，避免负宽度约束崩溃
              final tabWidth = outer.maxWidth > 48 ? (outer.maxWidth - 48) / maxVisibleTabs : 0.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: tabs.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final tab = entry.value;
                          final selected = idx == safeIndex;
                          return SizedBox(
                            width: tabWidth,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _switchToTab(tab.originalIndex);
                              },
                              onLongPress: tab.label == '影视'
                                  ? () {
                                      // 年份网格布局锁定按上映时间排序
                                      if (UserPrefs().movieLayoutStyle == 3) {
                                        ToastUtil.show(context, '年份网格布局固定按上映时间排序'.tr);
                                        return;
                                      }
                                      final isWallMode = UserPrefs().movieWallMode;
                                      _showSortMenu(context, isWallMode ? '影视墙排序' : '影视排序', UserPrefs().effectiveMovieSortMode, [
                                        (0, '按更新时间排序', Icons.update),
                                        (1, '按创建时间排序', Icons.calendar_today_outlined),
                                        (2, '按影视评分排序', Icons.star_outline),
                                        (3, '按观看日期排序', Icons.visibility_outlined),
                                        (4, '按上映时间排序', Icons.movie_creation_outlined),
                                      ], (v) { UserPrefs().setMovieSortMode(v); context.read<AppProvider>().loadMovies(); });
                                    }
                                  : tab.label == '阅读'
                                      ? () {
                                          if (UserPrefs().bookLayoutStyle == 2) {
                                            ToastUtil.show(context, '年份网格布局固定按出版时间排序'.tr);
                                            return;
                                          }
                                          final isWallMode = UserPrefs().bookshelfMode;
                                          _showSortMenu(context, isWallMode ? '书架排序' : '书籍排序', UserPrefs().effectiveBookSortMode, [
                                            (0, '按更新时间排序', Icons.update),
                                            (1, '按创建时间排序', Icons.calendar_today_outlined),
                                            (2, '按书籍评分排序', Icons.star_outline),
                                            (3, '按开始阅读时间排序', Icons.auto_stories_outlined),
                                            (4, '按出版时间排序', Icons.auto_stories_outlined),
                                          ], (v) { UserPrefs().setBookSortMode(v); context.read<AppProvider>().loadBooks(); });
                                        }
                                      : tab.label == '笔记'
                                          ? () => _showSortMenu(context, '笔记排序', UserPrefs().noteSortMode, [
                                              (0, '按更新时间排序', Icons.update),
                                              (1, '按创建时间排序', Icons.calendar_today_outlined),
                                            ], (v) { UserPrefs().setNoteSortMode(v); context.read<AppProvider>().loadNotes(); })
                                          : tab.label == '游戏'
                                              ? () {
                                                  if (UserPrefs().gameLayoutStyle == 3) {
                                                    ToastUtil.show(context, '年份网格布局固定按发售时间排序'.tr);
                                                    return;
                                                  }
                                                  final isWallMode = UserPrefs().gameWallMode;
                                                  _showSortMenu(context, isWallMode ? '游戏墙排序' : '游戏排序', UserPrefs().effectiveGameSortMode, [
                                                    (0, '按更新时间排序', Icons.update),
                                                    (1, '按创建时间排序', Icons.calendar_today_outlined),
                                                    (2, '按游戏评分排序', Icons.star_outline),
                                                    (3, '按发售时间排序', Icons.event_outlined),
                                                  ], (v) { UserPrefs().setGameSortMode(v); context.read<AppProvider>().loadGames(); });
                                                }
                                              : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                                    Icon(_tabIcon(tab.label), size: 18, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3)),
                                    const SizedBox(width: 5),
                                    Text(tab.label.tr, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.3))),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: safeIndex.toDouble()),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (context, page, _) {
                        return SizedBox(
                          width: 48 + tabWidth * tabs.length,
                          height: 2.5,
                          child: Stack(children: [
                            Positioned(
                              left: 24 + page * tabWidth,
                              top: 0,
                              width: tabWidth,
                              child: Container(height: 2.5, decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(2))),
                            ),
                          ]),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showSortMenu(BuildContext context, String title, int current, List<(int, String, IconData)> options, ValueChanged<int> onSelected) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
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
      title: Text(label.tr, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: colors.onSurface)),
      trailing: selected ? Icon(Icons.check, size: 20, color: colors.primary) : null,
      onTap: () {
        Navigator.pop(ctx);
        onSelected(value);
      },
    );
  }

  // ─── 内容区（全部页面常驻 Stack，AnimatedOpacity 交叉淡化） ───

  Widget _buildTabContent() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final tabs = _enabledTabs;
        final safeIndex = _mapToEnabledTabIndex(provider.mainTabIndex).clamp(0, tabs.length - 1);

        final pages = <Widget>[
          if (_showMovieTab) const MovieTabPage(),
          if (_showBookTab) const BookTabPage(),
          if (_showGameTab) const GameTabPage(),
          if (_showNoteTab) const NoteTabPage(),
        ];

        // 所有页面常驻：状态（滚动位置、内部分页）永久保留。
        // 不透明度由 provider.mainTabIndex 声明式驱动——切换只是改索引，
        // 无控制器、无时序窗口，结构上不可能回跳或叠影。
        // 纯淡出淡入：进入页淡入(260ms)、离开页淡出稍慢(340ms)，过渡中背景几乎不透出。
        return Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < pages.length; i++)
              IgnorePointer(
                ignoring: i != safeIndex,
                child: AnimatedOpacity(
                  opacity: i == safeIndex ? 1.0 : 0.0,
                  duration: Duration(milliseconds: i == safeIndex ? 260 : 340),
                  curve: Curves.easeOut,
                  child: KeyedSubtree(
                    key: ValueKey('main-tab-${tabs[i].originalIndex}'),
                    child: pages[i],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _tabIcon(String label) {
    switch (label) {
      case '影视': return Icons.movie_outlined;
      case '阅读': return Icons.menu_book_outlined;
      case '笔记': return Icons.sticky_note_2_outlined;
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
  String _backupMode = 'full';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _backupMode = prefs.getString('webdav_backup_mode') ?? 'full');
    });
    if (widget.hasConfig) {
      _loadRemoteInfo();
    } else {
      _loading = false;
    }
  }

  Future<void> _loadRemoteInfo() async {
    if (!mounted) return;
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

    if (_backupMode == 'inc') {
      // ── 增量备份分支：双向同步（推本地变更 + 拉云端变更，LWW 合并）──
      setState(() => _syncStep = '正在同步数据...'.tr);
      await Future.delayed(Duration.zero);
      final result = await IncSyncService.instance.upload();
      if (result.success && result.needReload && mounted) {
        final provider = context.read<AppProvider>();
        await provider.loadMovies();
        await provider.loadBooks();
        await provider.loadNotes();
        await provider.loadGames();
        await provider.loadPlaylists();
        await provider.loadPeople();
      }
      if (mounted) {
        setState(() => _syncing = false);
        Navigator.pop(context); // 关闭 bottom sheet
      }
      _showResultDialog(navigator,
        title: (result.success ? '同步成功' : '同步失败').tr,
        message: result.message.isNotEmpty ? result.message : (result.success ? '同步成功' : '同步失败').tr,
        isSuccess: result.success,
        details: {
          'uploaded': result.uploadedRecords + result.uploadedImages,
          'downloaded': result.downloadedRecords + result.downloadedImages,
        },
      );
      return;
    }

    if (direction == SyncDirection.upload) {
      // 上传：先打包，再上传
      setState(() => _syncStep = '正在打包数据...'.tr);
      await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
      final exportResult = await WebDAVService.instance.exportLocalData();
      if (!exportResult.success || exportResult.zipPath == null) {
        if (mounted) {
          Navigator.pop(context); // 关闭 bottom sheet
          _showResultDialog(navigator, title: '同步失败'.tr, message: exportResult.errorMessage ?? '创建备份失败'.tr, isSuccess: false);
        }
        return;
      }
      if (!mounted) return;
      setState(() => _syncStep = '正在上传到云端...'.tr);
      await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
      final result = await WebDAVService.instance.uploadExportedData(exportResult);
      if (result.success && result.needReload && mounted) {
        final provider = context.read<AppProvider>();
        await provider.loadMovies();
        await provider.loadBooks();
        await provider.loadNotes();
        await provider.loadGames();
        await provider.loadPlaylists();
        await provider.loadPeople();
      }
      if (mounted) {
        setState(() => _syncing = false);
        Navigator.pop(context); // 关闭 bottom sheet
      }
      _showResultDialog(navigator,
        title: (result.success ? '同步成功' : '同步失败').tr,
        message: result.message.isNotEmpty ? result.message : (result.success ? '同步成功' : '同步失败').tr,
        isSuccess: result.success,
        details: {'uploaded': result.uploadedFiles + result.uploadedImages, 'downloaded': result.downloadedFiles + result.downloadedImages},
      );
    } else {
      // 下载
      setState(() => _syncStep = '正在从云端下载...'.tr);
      await Future.delayed(Duration.zero); // 让 UI 先渲染进度动画
      final config = await WebDAVService.instance.getConfig();
      if (config == null) {
        if (mounted) {
          Navigator.pop(context);
          _showResultDialog(navigator, title: '同步失败'.tr, message: '请先配置 WebDAV 服务器'.tr, isSuccess: false);
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
        await provider.loadPlaylists();
        await provider.loadPeople();
      }
      if (mounted) {
        setState(() => _syncing = false);
        Navigator.pop(context); // 关闭 bottom sheet
      }
      _showResultDialog(navigator,
        title: (result.success ? '同步成功' : '同步失败').tr,
        message: result.message.isNotEmpty ? result.message : (result.success ? '同步成功' : '同步失败').tr,
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
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('云备份'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: bc.onSurface)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: bc.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
              child: Text(_backupMode == 'inc' ? '增量备份'.tr : '全量备份'.tr, style: TextStyle(fontSize: 11, color: bc.primary)),
            ),
          ]),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: bc.primary)),
            )
          else if (_backupMode == 'full' && (_modifiedTime != null || _remoteSize != null)) ...[
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
                Text('云端备份'.tr, style: TextStyle(fontSize: 11, color: bc.onSurface.withValues(alpha: 0.4))),
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
            if (_backupMode == 'inc')
              _cloudCard(icon: Icons.sync, title: '同步数据'.tr, desc: widget.hasConfig ? '推送本地变更到云端，并拉取云端变更与本地合并（同一条记录以最后修改为准）'.tr : '请先配置 WebDAV 服务器'.tr, enabled: widget.hasConfig, onTap: widget.hasConfig ? () => _startSync(SyncDirection.upload) : null, colors: bc)
            else ...[
              _cloudCard(icon: Icons.cloud_upload_outlined, title: '上传数据'.tr, desc: widget.hasConfig ? '将本地数据打包上传到云端'.tr : '请先配置 WebDAV 服务器'.tr, enabled: widget.hasConfig, onTap: widget.hasConfig ? () => _startSync(SyncDirection.upload) : null, colors: bc),
              const SizedBox(height: 8),
              _cloudCard(icon: Icons.cloud_download_outlined, title: '下载数据'.tr, desc: widget.hasConfig ? '从云端恢复数据到本地'.tr : '请先配置 WebDAV 服务器'.tr, enabled: widget.hasConfig, onTap: widget.hasConfig ? () => _startSync(SyncDirection.download) : null, colors: bc),
            ],
            const SizedBox(height: 8),
            _cloudCard(icon: Icons.settings_outlined, title: 'WebDAV 设置'.tr, desc: '配置服务器地址与认证信息'.tr, enabled: true, onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDAVSyncPage())); }, colors: bc),
          ],
        ]),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚'.tr;
    if (diff.inHours < 1) return '{n}分钟前'.trf({'n': diff.inMinutes});
    if (diff.inDays < 1) return '{n}小时前'.trf({'n': diff.inHours});
    if (diff.inDays < 7) return '{n}天前'.trf({'n': diff.inDays});
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
    appDialog(
      context: overlayCtx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: isSuccess ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)), child: Icon(isSuccess ? Icons.check_circle : Icons.error, color: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373), size: 24)),
          const SizedBox(width: 12),
          Text(title.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          if (details != null) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (details['uploaded'] != null) _detailRow('上传文件', '{n} 个'.trf({'n': details['uploaded']}), colors),
            if (details['downloaded'] != null) _detailRow('下载文件', '{n} 个'.trf({'n': details['downloaded']}), colors),
          ]))],
        ]),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(dialogCtx), style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)), child: Text('确定'.tr))],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _detailRow(String label, String value, ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(label.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
      const Spacer(),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
    ]),
  );
}
