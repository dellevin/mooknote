import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../pages/explore/encounter_page.dart';
import '../pages/explore/stroll_page.dart';
import '../pages/explore/reviewed_page.dart';
import '../pages/explore/gallery_page.dart';
import '../pages/playlist/playlist_list_page.dart';
import '../pages/explore/media_calendar_page.dart';
import '../pages/people/person_list_page.dart';
import '../pages/markdown_reader/md_reader_tab_page.dart';
import '../pages/epub_reader/epub_library_page.dart';
import '../pages/settings/tag_management_page.dart';
import '../pages/movies/movie_detail_page.dart';
import '../pages/movies/movie_form_page.dart';
import '../pages/book/book_detail_page.dart';
import '../pages/book/book_form_page.dart';
import '../pages/note/note_detail_page.dart';
import '../pages/game/game_detail_page.dart';
import '../pages/game/game_form_page.dart';
import '../pages/profile/settings_page.dart';
import '../models/data_models.dart';
import 'fade_in_local_image.dart';
import 'shimmer_skeleton.dart';
import '../widgets/app_overlay.dart';

/// 自定义侧边栏
class CustomDrawer extends StatefulWidget {
  final bool embedded;

  /// 抽屉是否处于打开状态（用于延迟构建重内容，避免打开时卡顿）
  final bool isOpen;
  const CustomDrawer({super.key, this.embedded = false, this.isOpen = false});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _version = '0.1.5';

  // 热力图缓存
  int _cachedMoviesHash = 0;
  int _cachedBooksHash = 0;
  int _cachedNotesHash = 0;
  int _cachedGamesHash = 0;
  Map<DateTime, int>? _cachedDailyCounts;
  int? _cachedMaxCount;

  // 最近添加缓存
  List<_RecentItem>? _cachedRecentItems;

  /// 用列表长度 + 首末元素ID生成轻量哈希，避免 identical() 在 Provider 返回新实例时永远失败
  int _listHash<T>(List<T> list) {
    if (list.isEmpty) return 0;
    final first = list.first;
    final last = list.last;
    return Object.hash(list.length, first, last);
  }

  bool _isHeatmapCacheValid(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    return _cachedDailyCounts != null &&
        _cachedMoviesHash == _listHash(movies) &&
        _cachedBooksHash == _listHash(books) &&
        _cachedNotesHash == _listHash(notes) &&
        _cachedGamesHash == _listHash(games);
  }

  bool _isRecentCacheValid(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    return _cachedRecentItems != null &&
        _cachedMoviesHash == _listHash(movies) &&
        _cachedBooksHash == _listHash(books) &&
        _cachedNotesHash == _listHash(notes) &&
        _cachedGamesHash == _listHash(games);
  }

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
    // 抽屉可能以已打开状态被重建，此时也延迟构建重内容
    if (widget.isOpen) _scheduleDefer();
  }

  Timer? _deferTimer;

  /// 是否已延迟构建重内容（热力图/最近/工具）
  bool _deferReady = false;

  void _scheduleDefer() {
    _deferTimer?.cancel();
    _deferTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _deferReady = true);
    });
  }

  @override
  void didUpdateWidget(CustomDrawer old) {
    super.didUpdateWidget(old);
    if (widget.isOpen && !old.isOpen) {
      _deferReady = false;
      _scheduleDefer();
    } else if (!widget.isOpen && old.isOpen) {
      // 关闭时重置，下次打开重新延迟构建
      _deferTimer?.cancel();
      _deferReady = false;
    }
  }

  @override
  void dispose() {
    _deferTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _version = packageInfo.version);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();
    final showHeatmap = userPrefs.showSidebarHeatmap;
    final showRecent = userPrefs.showSidebarRecent;
    final showQuickActions = userPrefs.showSidebarQuickActions;
    final showTools = userPrefs.showSidebarEncounter ||
        userPrefs.showSidebarStroll ||
        userPrefs.showSidebarReviewed ||
        userPrefs.showSidebarPlaylist ||
        userPrefs.showSidebarCalendar ||
        userPrefs.showSidebarPerson ||
        userPrefs.showSidebarTags ||
        userPrefs.showSidebarMdReader ||
        userPrefs.showSidebarEpub;

    final content = SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(context),
            if (showQuickActions) ...[
              const SizedBox(height: 12),
              _buildQuickActions(context),
            ],
            if (showHeatmap) ...[
              const SizedBox(height: 16),
              if (_deferReady)
                _buildCalendarSection(context)
              else
                const _HeatmapSkeleton(),
            ],
            if (showRecent) ...[
              const SizedBox(height: 16),
              if (_deferReady)
                _buildRecentSection(context)
              else
                const _RecentSkeleton(),
            ],
            if (showTools) ...[
              const SizedBox(height: 16),
              if (_deferReady)
                _buildToolsCard(context)
              else
                const _ToolsSkeleton(),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('v$_version', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.2))),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      if (!widget.embedded) Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                    },
                    child: Icon(Icons.settings_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    final isFrosted = context.read<AppProvider>().frostedActive;
    if (isFrosted) {
      return Drawer(
        backgroundColor: Colors.transparent,
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: colors.surfaceContainerHigh, child: content),
          ),
        ),
      );
    }
    return Drawer(
      backgroundColor: colors.surfaceContainerHigh,
      child: content,
    );
  }

  // ─── 头像 + 统计卡片 ─────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final colors = Theme.of(context).colorScheme;
        final userPrefs = UserPrefs();
        final nickname = userPrefs.nickname;
        final motto = userPrefs.motto;
        final avatarPath = userPrefs.avatarPath;
        final movieCount = provider.movies.where((m) => !m.isDeleted).length;
        final bookCount = provider.books.length;
        final noteCount = provider.notes.length;
        final gameCount = provider.games.where((g) => !g.isDeleted).length;

        // 根据功能开关过滤显示的统计项
        final statItems = <(IconData, int, String, Color)>[];
        if (userPrefs.showMovieTab) statItems.add((Icons.movie_outlined, movieCount, '观影', const Color(0xFF2563EB)));
        if (userPrefs.showBookTab) statItems.add((Icons.menu_book_outlined, bookCount, '阅读', const Color(0xFF16A34A)));
        if (userPrefs.showGameTab) statItems.add((Icons.sports_esports_outlined, gameCount, '游戏', const Color(0xFFEA580C)));
        if (userPrefs.showNoteTab) statItems.add((Icons.sticky_note_2_outlined, noteCount, '笔记', const Color(0xFF9333EA)));

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfaceContainerHighest,
                      border: Border.all(color: colors.outlineVariant, width: 0.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarPath != null && avatarPath.isNotEmpty
                        ? FadeInLocalImage(path: avatarPath, fit: BoxFit.cover,
                            errorWidget: Icon(Icons.person_outline, size: 22, color: colors.onSurface.withValues(alpha: 0.3)))
                        : Icon(Icons.person_outline, size: 22, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nickname, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text(motto, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                      ],
                    ),
                  ),
                ],
              ),
              if (statItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: statItems.map((item) {
                    final (icon, count, label, color) = item;
                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_formatCount(count), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, size: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                              const SizedBox(width: 3),
                              Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 快捷操作 ──────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();

    final actions = <(IconData, String, Color, VoidCallback)>[];
    if (userPrefs.showMovieTab) actions.add((
      Icons.movie_outlined, '影视', const Color(0xFF2563EB),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieFormPage())); },
    ));
    if (userPrefs.showBookTab) actions.add((
      Icons.menu_book_outlined, '阅读', const Color(0xFF16A34A),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormPage())); },
    ));
    if (userPrefs.showGameTab) actions.add((
      Icons.sports_esports_outlined, '游戏', const Color(0xFFEA580C),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const GameFormPage())); },
    ));

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((action) {
          final (icon, label, color, onTap) = action;
          return Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, size: 18, color: color),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                              color: colors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add, size: 10, color: color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 功能入口卡片 ────────────────────────────────────────────────────

  Widget _buildToolsCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();

    final exploreItems = <(Widget, String, Widget)>[];
    if (userPrefs.showSidebarEncounter) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M518.217143 432.64V73.142857A73.142857 73.142857 0 0 1 603.428571 1.097143 512 512 0 0 1 1022.902857 420.571429 73.142857 73.142857 0 0 1 950.857143 505.782857H591.36a73.142857 73.142857 0 0 1-73.142857-73.142857z" fill="currentColor"/><path d="M493.714286 566.857143h340.297143a73.142857 73.142857 0 0 1 73.142857 85.577143A457.142857 457.142857 0 1 1 371.565714 117.76a73.142857 73.142857 0 0 1 85.577143 73.142857V530.285714a36.571429 36.571429 0 0 0 36.571429 36.571429z" fill="currentColor"/></svg>', color: colors.onSurface), '统计', const EncounterPage()));
    if (userPrefs.showSidebarStroll) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M261.156045 240.64C117.796045 240.64 0.036045 358.4 0.036045 505.856a219.648 219.648 0 0 0 16.8448 88.4224C37.924045 657.408 113.700045 771.072 244.208845 922.624l4.1984 4.1984c8.3968 8.448 21.0432 8.448 29.44-4.1984 130.5088-155.7504 202.0864-265.216 227.328-328.3456 8.448-29.4912 16.8448-58.9312 16.8448-88.4224 0-147.3024-117.76-265.216-261.12-265.216z m0 349.44A88.9344 88.9344 0 0 1 172.631245 501.76 86.272 86.272 0 0 1 261.156045 413.3888a88.4224 88.4224 0 0 1 0 176.7936zM724.106445 47.104c-96.8192 0-172.5952 80.0256-172.5952 176.8448a249.1392 249.1392 0 0 0 8.3968 58.9312c16.8448 42.0864 67.3792 117.76 151.552 223.0784a18.944 18.944 0 0 0 21.0432 0c88.4224-105.216 138.9568-176.7936 151.552-223.0784 8.448-16.8448 8.448-37.888 8.448-58.9312A168.2944 168.2944 0 0 0 724.106445 47.104z m0 235.776a57.5488 57.5488 0 0 1-58.9312-58.9312 58.9312 58.9312 0 0 1 117.76 0 60.2624 60.2624 0 0 1-58.9312 58.9312z m-8.448 698.7776c-155.7504 0-311.5008-54.7328-324.1472-58.9312a19.968 19.968 0 0 1 12.6464-37.888c4.1984 0 416.768 143.36 555.6736-37.888 12.6464-16.8448 21.0432-42.0864 16.8448-63.1296s-12.6464-37.888-29.4912-50.5344c-33.6384-25.2416-79.9744-42.0864-143.36-50.4832-46.08-8.448-84.1728-37.888-96.8192-75.776a93.1328 93.1328 0 0 1-4.1984-33.6896 21.0432 21.0432 0 0 1 42.0864 0 38.0928 38.0928 0 0 0 4.1984 21.0432 79.36 79.36 0 0 0 63.3856 50.7392c67.3792 12.5952 122.112 29.44 160 58.9312 25.2416 16.8448 42.0864 46.08 50.4832 79.9744a120.4224 120.4224 0 0 1-25.2416 92.6208c-67.328 79.9744-172.5952 105.216-282.0608 105.216z m0 0" fill="currentColor"/></svg>', color: colors.onSurface), '漫步', const StrollPage()));
    if (userPrefs.showSidebarReviewed) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M550.4 755.2V298.496c0-36.352 12.8-67.584 38.4-93.696 26.112-25.6 57.344-38.4 93.696-38.4h213.504L900.096 256c0 2.048 0 4.608 0.512 7.168 0.512 2.56 1.536 5.12 2.56 7.168 0.512 2.56 2.048 4.608 3.072 6.656 1.536 2.048 3.072 4.096 5.12 6.144 1.536 1.536 3.584 3.072 5.632 4.608 2.048 1.536 4.608 2.56 6.656 3.584 2.56 1.024 4.608 1.536 7.168 2.048 2.56 0.512 5.12 1.024 7.68 1.024 2.56 0 5.12-0.512 7.168-1.024 2.56-0.512 5.12-1.024 7.68-2.048 2.048-1.024 4.096-2.048 6.656-3.584 2.048-1.536 3.584-3.072 5.632-4.608l4.608-6.144c1.536-2.048 2.56-4.096 3.584-6.656 1.024-2.048 1.536-4.608 2.048-7.168 0.512-2.56 1.024-5.12 1.024-7.168V170.496c0-22.528-8.192-41.472-24.064-57.344-15.36-15.872-34.816-23.552-56.832-23.552h-213.504c-57.856 0-107.008 19.968-147.968 60.928-8.192 8.704-15.872 17.408-22.528 26.624-7.168-9.216-14.336-17.92-23.04-26.624-40.96-40.96-90.112-60.928-147.968-60.928H128c-22.528 0-41.984 7.68-57.344 23.552-15.872 15.872-24.064 34.816-24.064 57.344v554.496c0 22.528 8.192 41.472 24.064 57.344 15.36 15.872 34.816 24.064 57.344 24.064h256c24.576 0 45.568 8.704 62.976 26.112 17.408 17.408 26.112 38.4 26.624 62.976 0 2.048 0 5.12 0.512 7.68 0.512 2.56 1.024 5.12 2.048 7.168 1.024 2.56 2.048 4.608 3.584 6.656l4.608 6.144 6.144 4.608c2.048 1.536 4.096 2.56 6.656 3.584 2.048 1.024 4.608 1.536 7.168 2.048 2.56 0.512 5.12 1.024 7.68 1.024 2.048 0 4.096-0.512 6.656-1.024 2.048 0 4.096-1.024 6.144-1.536 2.048-1.024 4.096-1.536 6.144-3.072 2.048-1.024 3.584-2.048 5.632-3.584 1.536-2.048 7.168-8.192 8.704-10.24 1.024-2.048 2.048-4.096 2.56-6.144 1.024-2.048 1.536-4.096 1.536-6.656 0.512-1.024 1.024-5.12 1.024-6.144v-140.8z m-76.8 0c-26.624-17.408-56.32-25.6-89.6-25.6h-256L123.392 170.496l217.6-4.096c36.864 0 67.584 12.8 93.696 38.4 25.6 25.6 38.4 56.832 38.912 93.184v457.216z m503.296-328.704a38.5536 38.5536 0 0 1-11.264 27.136l-170.496 170.496c-2.048 2.048-4.096 3.584-6.144 5.12-2.048 1.024-4.096 2.56-6.656 3.072-2.048 1.024-4.608 2.048-7.168 2.56-2.56 0.512-5.12 0.512-7.168 0.512-2.56 0-5.12 0-7.68-0.512a29.5936 29.5936 0 0 1-7.168-2.56c-2.56-0.512-4.608-2.048-6.656-3.072a54.272 54.272 0 0 1-6.144-5.12l-84.992-84.992a34.2528 34.2528 0 0 1-8.192-12.8 36.1472 36.1472 0 0 1-3.072-14.336c0-2.56 0-5.12 0.512-7.68 0.512-2.56 1.536-5.12 2.56-7.168 0.512-2.56 2.048-4.608 3.072-6.656 1.536-2.048 3.072-4.096 5.12-6.144 1.536-1.536 3.584-3.072 5.632-4.608 2.048-1.536 4.608-2.56 6.656-3.584 2.56-1.024 4.608-1.536 7.168-2.048 2.56-0.512 5.12-0.512 7.68-0.512 5.12 0 9.728 0.512 14.848 2.56 4.608 2.048 8.704 4.608 12.288 8.192L768 542.72l143.36-143.36c3.584-3.584 7.68-6.656 12.288-8.192 4.608-2.048 9.728-3.072 14.848-3.072 2.56 0 5.12 0 7.168 0.512 2.56 0.512 5.12 1.536 7.68 2.56 2.048 0.512 4.096 2.048 6.656 3.072a50.9952 50.9952 0 0 1 10.24 10.752c1.536 2.048 2.56 4.608 3.584 6.656 1.024 2.56 1.536 4.608 2.048 7.168 0.512 2.56 1.024 5.12 1.024 7.68z m0 243.2v55.296c0 22.528-8.192 41.472-24.064 57.344-15.36 15.872-34.816 24.064-56.832 24.064h-256c-25.088 0-46.08 8.704-63.488 26.112-17.408 17.408-26.112 38.4-26.112 63.488v-140.8c26.112-17.408 55.808-25.6 89.6-25.6h256l4.096-59.904c0-2.56 0-5.12 0.512-7.68 0.512-2.56 1.536-4.608 2.56-7.168 0.512-2.048 2.048-4.608 3.072-6.656 1.536-2.048 3.072-4.096 5.12-5.632 1.536-2.048 3.584-3.584 5.632-5.12 2.048-1.024 4.608-2.56 6.656-3.072 2.56-1.024 4.608-2.048 7.168-2.56 2.56-0.512 5.12-0.512 7.68-0.512a31.488 31.488 0 0 1 14.848 3.072c2.048 0.512 4.096 2.048 6.656 3.072a50.9952 50.9952 0 0 1 10.24 10.752c1.536 2.048 2.56 4.608 3.584 6.656 1.024 2.56 1.536 4.608 2.048 7.168 0.512 2.56 1.024 5.12 1.024 7.68z" fill="currentColor"/></svg>', color: colors.onSurface), '已阅', const ReviewedPage()));
    if (userPrefs.showSidebarPlaylist) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M864 42.666667a32 32 0 0 1 31.850667 28.928L896 74.666667v874.666666a32 32 0 0 1-28.928 31.850667L864 981.333333h-704a32 32 0 0 1-31.850667-28.928L128 949.333333v-874.666666a32 32 0 0 1 28.928-31.850667L160 42.666667h704z m-533.333333 714.666666H192V917.333333h138.666667v-160z m298.666666-213.333333h-234.666666V917.333333h234.666666V544z m202.666667 213.333333h-138.666667V917.333333H832v-160z m0-213.333333h-138.666667v149.333333H832v-149.333333z m-501.333333 0H192v149.333333h138.666667v-149.333333z m0-213.333333H192v149.333333h138.666667v-149.333333zM629.333333 106.666667h-234.666666v373.333333h234.666666V106.666667zM832 330.666667h-138.666667v149.333333H832v-149.333333zM832 106.666667h-138.666667v160H832V106.666667zM330.666667 106.666667H192v160h138.666667V106.666667z" fill="currentColor"/></svg>', color: colors.onSurface), '书影片单', const PlaylistListPage()));
    if (userPrefs.showSidebarCalendar) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1099 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M1029.182186 148.469636a174.639676 174.639676 0 0 0-126.445344-53.246964 25.910931 25.910931 0 1 0 0 50.91498 126.963563 126.963563 0 0 1 126.704454 129.554656v544.129554c0 76.307692-50.396761 133.82996-116.599191 133.82996h-699.595141c-74.753036 0-142.510121-63.740891-142.510122-133.82996v-544.129554c0-70.348178 62.445344-129.554656 136.421053-129.554656a25.910931 25.910931 0 0 0 0-50.91498c-101.57085 0-187.336032 82.785425-187.336033 181.376518v544.129555a180.340081 180.340081 0 0 0 59.724697 129.554656 199.902834 199.902834 0 0 0 133.700405 54.283401h699.595141a159.222672 159.222672 0 0 0 122.688259-56.356276 196.793522 196.793522 0 0 0 45.214575-128.388664v-544.129554a181.376518 181.376518 0 0 0-51.562753-127.222672z" fill="currentColor"/><path d="M912.453441 1023.481781h-699.595141a219.206478 219.206478 0 0 1-146.526316-58.947368A200.161943 200.161943 0 0 1 0 819.821862v-544.129554C0 167.51417 94.704453 75.789474 207.287449 75.789474a44.955466 44.955466 0 0 1 0 89.781376c-63.481781 0-116.59919 50.526316-116.59919 110.380567v544.129555c0 58.817814 59.983806 114.396761 123.465587 114.396761h699.595142c55.578947 0 97.554656-49.230769 97.554656-114.396761v-544.129555a107.659919 107.659919 0 0 0-107.271255-110.380567 44.955466 44.955466 0 1 1 0-89.781376 194.331984 194.331984 0 0 1 140.437247 59.076923 201.587045 201.587045 0 0 1 55.319838 141.08502v544.129555A215.838057 215.838057 0 0 1 1049.392713 960.777328 178.137652 178.137652 0 0 1 912.453441 1023.481781zM207.287449 114.65587c-90.688259 0-168.421053 73.846154-168.421052 161.295547v544.129555a161.036437 161.036437 0 0 0 53.894737 116.59919 179.951417 179.951417 0 0 0 120.48583 47.935223h699.595141a139.789474 139.789474 0 0 0 107.919029-49.619434 176.712551 176.712551 0 0 0 40.550607-115.692307v-544.129555a162.461538 162.461538 0 0 0-45.603239-114.008097 155.465587 155.465587 0 0 0-112.582996-47.287449 6.089069 6.089069 0 1 0 0 12.048583A146.137652 146.137652 0 0 1 1049.392713 275.951417v544.129555c0 86.801619-59.206478 153.004049-136.939272 153.004048h-699.595141c-84.987854 0-162.331984-73.068826-162.331984-153.263158v-544.129554c0-80.842105 71.384615-149.246964 155.465587-149.246964a6.089069 6.089069 0 0 0 0-12.048583z" fill="currentColor"/><path d="M318.834008 378.688259h-75.789474a44.955466 44.955466 0 0 0 0 89.781377h75.789474a44.955466 44.955466 0 0 0 0-89.781377zM583.902834 378.688259h-75.659919a44.955466 44.955466 0 1 0 0 89.781377h75.659919a44.955466 44.955466 0 1 0 0-89.781377zM773.311741 468.469636h75.789474a44.955466 44.955466 0 0 0 0-89.781377h-75.789474a44.955466 44.955466 0 0 0 0 89.781377zM318.834008 530.267206h-75.789474a44.955466 44.955466 0 0 0 0 89.781377h75.789474a44.955466 44.955466 0 0 0 0-89.781377zM583.902834 530.267206h-75.659919a44.955466 44.955466 0 1 0 0 89.781377h75.659919a44.955466 44.955466 0 1 0 0-89.781377zM849.101215 530.267206h-75.789474a44.955466 44.955466 0 0 0 0 89.781377h75.789474a44.955466 44.955466 0 0 0 0-89.781377zM318.834008 681.716599h-75.789474a44.955466 44.955466 0 0 0 0 89.781377h75.789474a44.955466 44.955466 0 0 0 0-89.781377zM583.902834 681.716599h-75.659919a44.955466 44.955466 0 1 0 0 89.781377h75.659919a44.955466 44.955466 0 1 0 0-89.781377zM849.101215 681.716599h-75.789474a44.955466 44.955466 0 0 0 0 89.781377h75.789474a44.955466 44.955466 0 0 0 0-89.781377zM896.777328 95.222672H192.647773a25.910931 25.910931 0 1 0 0 50.91498h704.129555a25.910931 25.910931 0 0 0 0-50.91498z" fill="currentColor"/><path d="M896.777328 165.57085H192.647773a44.955466 44.955466 0 1 1 0-89.781376h704.129555a44.955466 44.955466 0 0 1 0 89.781376zM192.647773 114.65587a6.089069 6.089069 0 1 0 0 12.048583h704.129555a6.089069 6.089069 0 0 0 0-12.048583z" fill="currentColor"/><path d="M318.834008 19.433198a25.910931 25.910931 0 0 0-25.910931 25.910932v151.578947a25.910931 25.910931 0 0 0 50.785425 0V44.825911a25.910931 25.910931 0 0 0-24.874494-25.392713z" fill="currentColor"/><path d="M318.834008 241.230769a44.825911 44.825911 0 0 1-44.825911-44.825911V44.825911a44.825911 44.825911 0 0 1 89.651822 0v151.578947a44.825911 44.825911 0 0 1-44.825911 44.825911z m0-202.364372a5.959514 5.959514 0 0 0-5.959514 5.959514v151.578947a5.959514 5.959514 0 0 0 11.919028 0V44.825911a5.959514 5.959514 0 0 0-5.959514-5.959514zM773.311741 19.433198a25.910931 25.910931 0 0 0-25.910931 25.910932v151.578947a25.910931 25.910931 0 0 0 50.785425 0V44.825911a25.910931 25.910931 0 0 0-24.874494-25.392713z" fill="currentColor"/><path d="M773.311741 241.230769a44.825911 44.825911 0 0 1-44.825911-44.825911V44.825911a44.825911 44.825911 0 0 1 89.651822 0v151.578947a44.825911 44.825911 0 0 1-44.825911 44.825911z m0-202.364372a5.959514 5.959514 0 0 0-5.959514 5.959514v151.578947a5.959514 5.959514 0 1 0 11.919028 0V44.825911a5.959514 5.959514 0 0 0-5.959514-5.959514zM546.072874 19.433198a25.910931 25.910931 0 0 0-25.910931 25.910932v151.578947a25.910931 25.910931 0 1 0 50.785425 0V44.825911a25.910931 25.910931 0 0 0-24.874494-25.392713z" fill="currentColor"/><path d="M546.072874 241.230769a44.825911 44.825911 0 0 1-44.82591-44.825911V44.825911a44.825911 44.825911 0 1 1 89.651821 0v151.578947a44.825911 44.825911 0 0 1-44.825911 44.825911z m0-202.364372a5.959514 5.959514 0 0 0-5.959514 5.959514v151.578947a5.959514 5.959514 0 0 0 11.919029 0V44.825911a5.959514 5.959514 0 0 0-5.959515-5.959514z" fill="currentColor"/></svg>', color: colors.onSurface), '书影日历', const MediaCalendarPage()));

    final toolItems = <(Widget, String, Widget)>[];
    if (userPrefs.showSidebarPerson) toolItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M819.2 819.2h204.8v-102.4h-204.8zM716.8 307.2v102.4h307.2V307.2z m51.2 307.2h256v-102.4h-256z m-244.224-61.952a256 256 0 1 0-330.752 0A358.4 358.4 0 0 0 0 870.4a339.456 339.456 0 0 0 4.096 51.2h102.4A280.064 280.064 0 0 1 102.4 870.4a256 256 0 0 1 512 0 280.064 280.064 0 0 1-5.12 51.2h102.4a339.456 339.456 0 0 0 5.12-51.2 358.4 358.4 0 0 0-193.024-317.952zM358.4 512a153.6 153.6 0 1 1 153.6-153.6 153.6 153.6 0 0 1-153.6 153.6z" fill="currentColor"/></svg>', color: colors.onSurface), '人物', const PersonListPage()));
    if (userPrefs.showSidebarGallery) toolItems.add((SvgPicture.string('<svg viewBox="0 0 1064 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M71.68 348.16A296.96 296.96 0 0 1 368.64 51.2h327.68a296.96 296.96 0 0 1 296.96 296.96v327.68A296.96 296.96 0 0 1 696.32 972.8H368.64a296.96 296.96 0 0 1-296.96-296.96v-327.68zM368.64 153.6A194.56 194.56 0 0 0 174.08 348.16v327.68A194.56 194.56 0 0 0 368.64 870.4h327.68a194.56 194.56 0 0 0 194.56-194.56v-327.68A194.56 194.56 0 0 0 696.32 153.6H368.64z" fill="currentColor"/><path d="M947.69152 606.08512a317.80864 317.80864 0 0 0-264.02816 209.7152l-96.54272-34.16064a420.20864 420.20864 0 0 1 349.34784-277.2992l11.22304 101.74464z" fill="currentColor"/><path d="M798.72 327.68a81.92 81.92 0 1 1-163.84 0 81.92 81.92 0 0 1 163.84 0z" fill="currentColor"/><path d="M163.84 542.72c-12.4928 0-24.86272 0.49152-37.0688 1.39264l-7.7824-102.11328c14.82752-1.10592 29.77792-1.67936 44.8512-1.67936 284.01664 0 520.6016 202.79296 572.90752 471.49056l-100.51584 19.57888C593.1008 709.87776 397.9264 542.72 163.84 542.72z" fill="currentColor"/></svg>', color: colors.onSurface), '图库', const GalleryPage()));
    if (userPrefs.showSidebarTags) toolItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M687.012733 1024c-29.085211 0-55.161606-10.029383-74.217434-30.088149L104.305583 487.428012c-21.061704-21.061704-33.096964-50.146915-32.094026-79.232126l7.020568-242.711067a96.282076 96.282076 0 0 1 97.285015-94.2762h233.684623c28.082272 0 55.161606 12.03526 76.22331 32.094025l508.489716 508.489716c22.064643 22.064643 33.096964 54.158668 29.085211 87.255632s-18.052889 61.179236-42.123408 84.246817L784.297747 981.876592c-23.067581 23.067581-53.15573 38.111655-84.246817 42.123408zM176.51714 150.440744c-10.029383 0-17.049951 7.020568-17.049951 17.049951l-7.020568 242.711068c0 7.020568 3.008815 15.044074 9.026445 20.058766l507.486777 507.486778c11.032321 11.032321 37.108717 8.023506 58.170421-13.038198l197.578845-197.578845c21.061704-21.061704 23.067581-48.141038 13.038198-58.170421L429.257591 160.470127c-5.014691-5.014691-13.038198-9.026445-19.055828-9.026444H176.51714z m-57.167483 16.047013z" fill="currentColor"/><path d="M316.928501 442.295788a130.381978 130.381978 0 1 1 130.381979-130.381978 130.381978 130.381978 0 0 1-130.381979 130.381978z m0-180.528893a50.146915 50.146915 0 1 0 50.146915 50.146915 50.146915 50.146915 0 0 0-50.146915-50.146915z" fill="currentColor"/><path d="M258.75808 362.060725c-15.044074 0-32.094025-3.008815-49.143976-8.023507-42.123408-13.038198-86.252693-40.117532-124.364349-78.229187S21.061704 194.570029 8.023506 152.446621c-7.020568-23.067581-9.026445-44.129285-7.020568-64.188051s12.03526-44.129285 27.079334-59.173359S71.208619 1.002938 100.29383 1.002938a40.120541 40.120541 0 1 1 1.002938 80.235064c-5.014691 0-13.038198 1.002938-17.049951 5.014691s-7.020568 23.067581-1.002938 43.126347 30.088149 62.182174 58.170421 90.264447 61.179236 49.143976 90.264446 58.170421 37.108717 6.01763 43.126347-1.002938a40.423428 40.423428 0 0 1 57.167483 57.167482c-15.044074 15.044074-36.105779 25.073457-59.17336 28.082273z" fill="currentColor"/></svg>', color: colors.onSurface), '标签', const TagManagementPage()));
    if (userPrefs.showSidebarMdReader) toolItems.add((Icon(Icons.description_outlined, size: 20, color: colors.onSurface), 'MD阅读', const MdReaderTabPage()));
    if (userPrefs.showSidebarEpub) toolItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M900.829867 143.581867a34.133333 34.133333 0 0 1 43.690666 52.394666l-4.437333 3.6864a173.960533 173.960533 0 0 0-24.951467 27.6992C897.706667 251.460267 887.466667 278.254933 887.466667 307.2c0 28.945067 10.24 55.739733 27.648 79.854933 6.263467 8.635733 12.970667 16.247467 19.626666 22.715734l2.9696 2.833066c1.792 1.655467 3.191467 2.8672 4.096 3.584l0.5632 0.4608a34.133333 34.133333 0 0 1-41.540266 54.1696c-10.973867-8.3968-26.0608-23.074133-41.028267-43.776C834.56 392.123733 819.2 351.914667 819.2 307.2c0-44.714667 15.36-84.923733 40.618667-119.842133 14.9504-20.6848 30.037333-35.362133 41.0112-43.776zM75.3152 559.5136a34.133333 34.133333 0 0 1 47.854933-6.331733c10.9568 8.413867 26.0608 23.0912 41.028267 43.776C189.44 631.876267 204.8 672.085333 204.8 716.8c0 44.714667-15.36 84.923733-40.618667 119.842133-14.9504 20.701867-30.037333 35.3792-41.0112 43.776a34.133333 34.133333 0 0 1-43.690666-52.3776l4.437333-3.703466c1.365333-1.194667 3.191467-2.850133 5.358933-4.949334 6.656-6.485333 13.346133-14.097067 19.592534-22.7328C126.293333 772.539733 136.533333 745.745067 136.533333 716.8c0-28.945067-10.24-55.739733-27.648-79.837867a173.960533 173.960533 0 0 0-19.626666-22.715733l-4.232534-3.9936a77.858133 77.858133 0 0 0-2.816-2.440533l-0.580266-0.443734a34.133333 34.133333 0 0 1-6.314667-47.854933z" fill="currentColor"/><path d="M921.6 136.533333a34.133333 34.133333 0 0 1 2.56 68.181334L921.6 204.8H238.933333a102.4 102.4 0 0 0-3.84 204.731733L238.933333 409.6h682.666667a34.133333 34.133333 0 0 1 2.56 68.181333L921.6 477.866667H238.933333C144.674133 477.866667 68.266667 401.4592 68.266667 307.2c0-92.672 73.847467-168.072533 165.888-170.5984L238.933333 136.533333h682.666667zM785.066667 546.133333c94.2592 0 170.666667 76.407467 170.666666 170.666667 0 92.672-73.847467 168.072533-165.888 170.5984L785.066667 887.466667H102.4a34.133333 34.133333 0 0 1-2.56-68.164267L102.4 819.2h682.666667a102.4 102.4 0 0 0 3.84-204.731733L785.066667 614.4H102.4a34.133333 34.133333 0 0 1-2.56-68.164267L102.4 546.133333h682.666667z" fill="currentColor"/><path d="M375.466667 256v221.866667a34.133333 34.133333 0 1 1-68.266667 0V256h68.266667z" fill="#00B386"/></svg>', color: colors.onSurface), '阅读', const EpubLibraryPage()));

    if (exploreItems.isEmpty && toolItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (exploreItems.isNotEmpty) ...[
          _buildGroupTitle('探索', colors),
          const SizedBox(height: 6),
          _buildGroupCard(context, exploreItems),
        ],
        if (toolItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildGroupTitle('工具', colors),
          const SizedBox(height: 6),
          _buildGroupCard(context, toolItems),
        ],
      ],
    );
  }

  Widget _buildGroupTitle(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.3), letterSpacing: 1)),
    );
  }

  Widget _buildGroupCard(BuildContext context, List<(Widget, String, Widget)> items) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(items.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Divider(height: 1, indent: 52, endIndent: 20, color: colors.outlineVariant);
          }
          final idx = i ~/ 2;
          final (icon, title, page) = items[idx];
          return _buildToolItem(icon, title, () {
            if (!widget.embedded) Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          }, topRounded: idx == 0, bottomRounded: idx == items.length - 1);
        }),
      ),
    );
  }

  Widget _buildToolItem(Widget icon, String title, VoidCallback onTap, {bool topRounded = false, bool bottomRounded = false, bool enabled = true}) {
    final colors = Theme.of(context).colorScheme;
    final effectiveOnTap = enabled ? onTap : null;
    final iconOpacity = enabled ? 0.7 : 0.25;
    final textOpacity = enabled ? 1.0 : 0.35;
    return InkWell(
      onTap: effectiveOnTap,
      borderRadius: BorderRadius.only(
        topLeft: topRounded ? const Radius.circular(16) : Radius.zero,
        topRight: topRounded ? const Radius.circular(16) : Radius.zero,
        bottomLeft: bottomRounded ? const Radius.circular(16) : Radius.zero,
        bottomRight: bottomRounded ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            SizedBox(width: 20, height: 20, child: Opacity(opacity: iconOpacity, child: icon)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: textOpacity)))),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }

  // ─── 热力图 ──────────────────────────────────────────────────────────

  // ─── 热力图缓存计算 ───

  (int, Map<DateTime, int>) _computeDailyCounts(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    if (_isHeatmapCacheValid(movies, books, notes, games)) {
      return (_cachedMaxCount!, _cachedDailyCounts!);
    }

    final dailyCounts = <DateTime, int>{};
    for (final movie in movies.where((m) => !m.isDeleted)) {
      final date = DateTime(movie.createdAt.year, movie.createdAt.month, movie.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    for (final book in books.where((b) => !b.isDeleted)) {
      final date = DateTime(book.createdAt.year, book.createdAt.month, book.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    for (final note in notes.where((n) => !n.isDeleted)) {
      final date = DateTime(note.createdAt.year, note.createdAt.month, note.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }
    for (final game in games.where((g) => !g.isDeleted)) {
      final date = DateTime(game.createdAt.year, game.createdAt.month, game.createdAt.day);
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    int maxCount = 0;
    for (final c in dailyCounts.values) {
      if (c > maxCount) maxCount = c;
    }
    if (maxCount == 0) maxCount = 1;

    _cachedMoviesHash = _listHash(movies);
    _cachedBooksHash = _listHash(books);
    _cachedNotesHash = _listHash(notes);
    _cachedGamesHash = _listHash(games);
    _cachedDailyCounts = dailyCounts;
    _cachedMaxCount = maxCount;
    return (maxCount, dailyCounts);
  }

  List<_RecentItem> _computeRecentItems(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    if (_isRecentCacheValid(movies, books, notes, games)) {
      return _cachedRecentItems!;
    }

    final items = <_RecentItem>[];
    for (final m in movies.where((m) => !m.isDeleted)) {
      items.add(_RecentItem(type: 'movie', title: m.title, date: m.createdAt, data: m, imagePath: m.posterPath));
    }
    for (final b in books.where((b) => !b.isDeleted)) {
      items.add(_RecentItem(type: 'book', title: b.title, date: b.createdAt, data: b, imagePath: b.coverPath));
    }
    for (final n in notes.where((n) => !n.isDeleted)) {
      items.add(_RecentItem(type: 'note', title: n.title.isNotEmpty ? n.title : '随手记', date: n.createdAt, data: n));
    }
    for (final g in games.where((g) => !g.isDeleted)) {
      items.add(_RecentItem(type: 'game', title: g.title, date: g.createdAt, data: g, imagePath: g.coverPath));
    }
    items.sort((a, b) => b.date.compareTo(a.date));

    _cachedMoviesHash = _listHash(movies);
    _cachedBooksHash = _listHash(books);
    _cachedNotesHash = _listHash(notes);
    _cachedGamesHash = _listHash(games);
    _cachedRecentItems = items;
    return items;
  }

  Widget _buildCalendarSection(BuildContext context) {
    final movies = context.select<AppProvider, List<Movie>>((p) => p.movies);
    final books = context.select<AppProvider, List<Book>>((p) => p.books);
    final notes = context.select<AppProvider, List<Note>>((p) => p.notes);
    final games = context.select<AppProvider, List<Game>>((p) => p.games);
    final colors = Theme.of(context).colorScheme;

    final (maxCount, dailyCounts) = _computeDailyCounts(movies, books, notes, games);

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final daysSinceSunday = today.weekday % 7;
        final lastSunday = today.subtract(Duration(days: daysSinceSunday));

        const totalWeeks = 20;
        const weekDays = 7;
        const cellGap = 1.5;
        // 可用宽度 = drawer宽度 - margin(16*2) - container padding(18*2)
        final drawerWidth = widget.embedded ? 260.0 : MediaQuery.sizeOf(context).width;
        final availableWidth = drawerWidth - 32 - 36;
        final cellSize = ((availableWidth - (totalWeeks - 1) * cellGap) / totalWeeks).clamp(6.0, 10.0);

        final cells = List.generate(weekDays, (_) => List.generate(totalWeeks, (_) => 0));
        for (int week = 0; week < totalWeeks; week++) {
          for (int day = 0; day < weekDays; day++) {
            final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7 + (6 - day)));
            cells[day][week] = dailyCounts[date] ?? 0;
          }
        }

        // 连续打卡天数
        int streak = 0;
        for (int i = 0; i < 365; i++) {
          final date = today.subtract(Duration(days: i));
          if (dailyCounts[date] != null && dailyCounts[date]! > 0) {
            streak++;
          } else {
            break;
          }
        }

        final monthLabels = <int, String>{};
        for (int week = 0; week < totalWeeks; week++) {
          final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7));
          final key = date.month;
          if (!monthLabels.containsKey(key) || date.day <= 7) {
            monthLabels[week] = '${date.month}月';
          }
        }
        final sortedWeeks = monthLabels.keys.toList()..sort();
        final keepWeeks = {sortedWeeks.first, sortedWeeks[sortedWeeks.length ~/ 2], sortedWeeks.last};

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text('热力图', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
                  const Spacer(),
                  if (streak > 0) ...[
                    Icon(Icons.local_fire_department, size: 14, color: const Color(0xFFFF6D00)),
                    const SizedBox(width: 3),
                    Text('连续 $streak 天', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFFF6D00))),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    SizedBox(
                      height: 16,
                      child: Row(
                        children: List.generate(totalWeeks, (week) {
                          final label = keepWeeks.contains(week) ? monthLabels[week] : null;
                          return SizedBox(
                            width: week < totalWeeks - 1 ? cellSize + cellGap : cellSize,
                            child: label != null ? Text(label, style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))) : null,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ...List.generate(weekDays, (day) => Row(
                      children: List.generate(totalWeeks, (week) {
                        final count = cells[day][week];
                        final date = lastSunday.subtract(Duration(days: (totalWeeks - 1 - week) * 7 + (6 - day)));
                        return GestureDetector(
                          onTap: count > 0 ? () => _showDayDetail(context, date, dailyCounts[date] ?? 0, movies, books, notes, games) : null,
                          child: Tooltip(
                            message: '${date.month}月${date.day}日${count > 0 ? ' · $count条' : ''}',
                            child: Container(
                              width: cellSize, height: cellSize,
                              margin: EdgeInsets.only(right: week < totalWeeks - 1 ? cellGap : 0, bottom: day < weekDays - 1 ? cellGap : 0),
                              decoration: BoxDecoration(
                                color: _heatmapColor(count, maxCount),
                                borderRadius: BorderRadius.circular(2),
                                border: count > 0 ? null : Border.all(color: colors.outlineVariant.withValues(alpha: 0.3), width: 0.5),
                              ),
                            ),
                          ),
                        );
                      }),
                    )),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('少', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
                  const SizedBox(width: 3),
                  _legendCell(const Color(0xFFF0F0F0)),
                  _legendCell(const Color(0xFFC8E6C9)),
                  _legendCell(const Color(0xFF66BB6A)),
                  _legendCell(const Color(0xFF2E7D32)),
                  _legendCell(const Color(0xFF1B5E20)),
                  const SizedBox(width: 3),
                  Text('多', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
                ],
              ),
            ],
          ),
        );
  }

  void _showDayDetail(BuildContext context, DateTime date, int count, List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    final colors = Theme.of(context).colorScheme;
    final dayMovies = movies.where((m) => !m.isDeleted && DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day) == date).toList();
    final dayBooks = books.where((b) => !b.isDeleted && DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day) == date).toList();
    final dayNotes = notes.where((n) => !n.isDeleted && DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day) == date).toList();
    final dayGames = games.where((g) => !g.isDeleted && DateTime(g.createdAt.year, g.createdAt.month, g.createdAt.day) == date).toList();

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Text('${date.month}月${date.day}日', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(width: 8),
                  Text('$count条记录', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  if (dayMovies.isNotEmpty) ...[
                    for (final m in dayMovies) _dayDetailItem(ctx, Icons.movie_outlined, m.title, colors.primary),
                  ],
                  if (dayBooks.isNotEmpty) ...[
                    for (final b in dayBooks) _dayDetailItem(ctx, Icons.menu_book_outlined, b.title, const Color(0xFF16A34A)),
                  ],
                  if (dayNotes.isNotEmpty) ...[
                    for (final n in dayNotes) _dayDetailItem(ctx, Icons.sticky_note_2_outlined, n.title.isNotEmpty ? n.title : '随手记', const Color(0xFF9333EA)),
                  ],
                  if (dayGames.isNotEmpty) ...[
                    for (final g in dayGames) _dayDetailItem(ctx, Icons.sports_esports_outlined, g.title, const Color(0xFFEA580C)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayDetailItem(BuildContext ctx, IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Theme.of(ctx).colorScheme.onSurface))),
        ],
      ),
    );
  }

  Color _heatmapColor(int count, int maxCount) {
    if (count == 0) return const Color(0xFFF0F0F0);
    final ratio = count / maxCount;
    if (ratio <= 0.25) return const Color(0xFFC8E6C9);
    if (ratio <= 0.50) return const Color(0xFF66BB6A);
    if (ratio <= 0.75) return const Color(0xFF2E7D32);
    return const Color(0xFF1B5E20);
  }

  Widget _legendCell(Color color) {
    return Container(width: 10, height: 10, margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)));
  }

  // ─── 最近添加 ────────────────────────────────────────────────────────

  Widget _buildRecentSection(BuildContext context) {
    final movies = context.select<AppProvider, List<Movie>>((p) => p.movies);
    final books = context.select<AppProvider, List<Book>>((p) => p.books);
    final notes = context.select<AppProvider, List<Note>>((p) => p.notes);
    final games = context.select<AppProvider, List<Game>>((p) => p.games);
    final colors = Theme.of(context).colorScheme;
    final recent = _computeRecentItems(movies, books, notes, games);
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text('最近添加', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          const SizedBox(height: 14),
          ...recent.take(6).map((item) => InkWell(
            onTap: () => _openRecentItem(context, item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
              child: Row(
                children: [
                  _buildRecentLeading(item, colors),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75))),
                  ),
                  const SizedBox(width: 8),
                  Text(_recentTimeAgo(item.date), style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.25))),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  void _openRecentItem(BuildContext context, _RecentItem item) {
    if (!widget.embedded) Navigator.pop(context);
    switch (item.type) {
      case 'movie':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
      case 'book':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
      case 'note':
        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: item.data as Note)));
      case 'game':
        Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailPage(game: item.data as Game)));
    }
  }

  String _recentTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}年前';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}月前';
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    return '刚刚';
  }

  Widget _buildRecentLeading(_RecentItem item, ColorScheme colors) {
    final imagePath = item.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      return Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
        ),
        clipBehavior: Clip.antiAlias,
        child: FadeInLocalImage(
          path: imagePath,
          fit: BoxFit.cover,
          errorWidget: _buildRecentTypeIcon(item, colors),
        ),
      );
    }
    return _buildRecentTypeIcon(item, colors);
  }

  Widget _buildRecentTypeIcon(_RecentItem item, ColorScheme colors) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: _typeColor(item.type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Icon(
        item.type == 'movie' ? Icons.movie_outlined : item.type == 'book' ? Icons.menu_book_outlined : item.type == 'game' ? Icons.sports_esports_outlined : Icons.sticky_note_2_outlined,
        size: 12, color: _typeColor(item.type),
      ),
    );
  }

  Color _typeColor(String type) {
    return switch (type) {
      'movie' => const Color(0xFF2563EB),
      'book' => const Color(0xFF16A34A),
      'note' => const Color(0xFF9333EA),
      'game' => const Color(0xFFEA580C),
      _ => const Color(0xFF6B7280),
    };
  }
}

class _RecentItem {
  final String type;
  final String title;
  final DateTime date;
  final dynamic data;
  final String? imagePath;
  _RecentItem({required this.type, required this.title, required this.date, required this.data, this.imagePath});
}

// ─── 抽屉骨架屏 ────────────────────────────────────────────────────────

/// 热力图骨架屏（模拟月份标签 + 贡献格子）
class _HeatmapSkeleton extends StatelessWidget {
  const _HeatmapSkeleton();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(6, (i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ShimmerSkeleton(width: 22, height: 10, borderRadius: 3, color: c),
          )),
        ),
        const SizedBox(height: 10),
        for (var r = 0; r < 7; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: List.generate(6, (c2) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ShimmerSkeleton(width: 14, height: 14, borderRadius: 3, color: c),
              )),
            ),
          ),
      ],
    );
  }
}

/// 最近添加骨架屏（模拟缩略图 + 标题行）
class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: List.generate(4, (i) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            ShimmerSkeleton(width: 44, height: 44, borderRadius: 8, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 150, height: 13, borderRadius: 4, color: c),
                  const SizedBox(height: 6),
                  ShimmerSkeleton(width: 90, height: 11, borderRadius: 4, color: c),
                ],
              ),
            ),
          ],
        ),
      )),
    );
  }
}

/// 工具卡片骨架屏（模拟图标宫格）
class _ToolsSkeleton extends StatelessWidget {
  const _ToolsSkeleton();
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outlineVariant;
    return Wrap(
      spacing: 20,
      runSpacing: 14,
      children: List.generate(8, (i) => Column(
        children: [
          ShimmerSkeleton(width: 38, height: 38, borderRadius: 10, color: c),
          const SizedBox(height: 6),
          ShimmerSkeleton(width: 30, height: 10, borderRadius: 3, color: c),
        ],
      )),
    );
  }
}
