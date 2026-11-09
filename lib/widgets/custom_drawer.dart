import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/avatar_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../pages/explore/encounter_page.dart';
import '../pages/explore/stroll_page.dart';
import '../pages/explore/reviewed_page.dart';
import '../pages/explore/gallery_page.dart';
import '../pages/playlist/playlist_list_page.dart';
import '../pages/explore/media_calendar_page.dart';
import '../pages/people/person_list_page.dart';
import '../pages/settings/tag_management_page.dart';
import '../pages/custom_module/custom_module_manage_page.dart';
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
import '../l10n/app_strings.dart';

/// assets/svg 实心图标，按给定颜色着色（与底部 dock 同一套资源）
Widget _assetSvgIcon(String asset, double size, Color color) => SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

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
    // 抽屉可能以已打开状态被重建，此时也延迟构建重内容；
    // embedded（平板常驻侧边栏）始终可见，同样需要调度
    if (widget.isOpen || widget.embedded) _scheduleDefer();
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
        userPrefs.showSidebarTags;

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
                  GestureDetector(
                    onTap: () => AvatarHelper.showActionSheet(context,
                        onChanged: provider.notifyUserInfoChanged),
                    child: Container(
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
                              errorWidget: _assetSvgIcon('assets/svg/rcd-user-f.svg', 22, colors.onSurface.withValues(alpha: 0.3)))
                          : _assetSvgIcon('assets/svg/rcd-user-f.svg', 22, colors.onSurface.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(nickname, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text(motto.tr, maxLines: 2, overflow: TextOverflow.ellipsis,
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
                              Text(label.tr, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
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
    if (count >= 10000) return '{n}万'.trf({'n': (count / 10000).toStringAsFixed(1)});
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 快捷操作 ──────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();

    final actions = <(IconData, String, Color, VoidCallback)>[];
    if (userPrefs.showMovieTab) {
      actions.add((
      Icons.movie_outlined, '影视', const Color(0xFF2563EB),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const MovieFormPage())); },
    ));
    }
    if (userPrefs.showBookTab) {
      actions.add((
      Icons.menu_book_outlined, '阅读', const Color(0xFF16A34A),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const BookFormPage())); },
    ));
    }
    if (userPrefs.showGameTab) {
      actions.add((
      Icons.sports_esports_outlined, '游戏', const Color(0xFFEA580C),
      () { if (!widget.embedded) { Navigator.pop(context); } Navigator.push(context, MaterialPageRoute(builder: (_) => const GameFormPage())); },
    ));
    }

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
                    Text(label.tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
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
    if (userPrefs.showSidebarEncounter) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M518.217143 432.64V73.142857A73.142857 73.142857 0 0 1 603.428571 1.097143 512 512 0 0 1 1022.902857 420.571429 73.142857 73.142857 0 0 1 950.857143 505.782857H591.36a73.142857 73.142857 0 0 1-73.142857-73.142857z" fill="currentColor"/><path d="M493.714286 566.857143h340.297143a73.142857 73.142857 0 0 1 73.142857 85.577143A457.142857 457.142857 0 1 1 371.565714 117.76a73.142857 73.142857 0 0 1 85.577143 73.142857V530.285714a36.571429 36.571429 0 0 0 36.571429 36.571429z" fill="currentColor"/></svg>', colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn)), '统计', const EncounterPage()));
    if (userPrefs.showSidebarStroll) exploreItems.add((SvgPicture.string('<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M261.156045 240.64C117.796045 240.64 0.036045 358.4 0.036045 505.856a219.648 219.648 0 0 0 16.8448 88.4224C37.924045 657.408 113.700045 771.072 244.208845 922.624l4.1984 4.1984c8.3968 8.448 21.0432 8.448 29.44-4.1984 130.5088-155.7504 202.0864-265.216 227.328-328.3456 8.448-29.4912 16.8448-58.9312 16.8448-88.4224 0-147.3024-117.76-265.216-261.12-265.216z m0 349.44A88.9344 88.9344 0 0 1 172.631245 501.76 86.272 86.272 0 0 1 261.156045 413.3888a88.4224 88.4224 0 0 1 0 176.7936zM724.106445 47.104c-96.8192 0-172.5952 80.0256-172.5952 176.8448a249.1392 249.1392 0 0 0 8.3968 58.9312c16.8448 42.0864 67.3792 117.76 151.552 223.0784a18.944 18.944 0 0 0 21.0432 0c88.4224-105.216 138.9568-176.7936 151.552-223.0784 8.448-16.8448 8.448-37.888 8.448-58.9312A168.2944 168.2944 0 0 0 724.106445 47.104z m0 235.776a57.5488 57.5488 0 0 1-58.9312-58.9312 58.9312 58.9312 0 0 1 117.76 0 60.2624 60.2624 0 0 1-58.9312 58.9312z m-8.448 698.7776c-155.7504 0-311.5008-54.7328-324.1472-58.9312a19.968 19.968 0 0 1 12.6464-37.888c4.1984 0 416.768 143.36 555.6736-37.888 12.6464-16.8448 21.0432-42.0864 16.8448-63.1296s-12.6464-37.888-29.4912-50.5344c-33.6384-25.2416-79.9744-42.0864-143.36-50.4832-46.08-8.448-84.1728-37.888-96.8192-75.776a93.1328 93.1328 0 0 1-4.1984-33.6896 21.0432 21.0432 0 0 1 42.0864 0 38.0928 38.0928 0 0 0 4.1984 21.0432 79.36 79.36 0 0 0 63.3856 50.7392c67.3792 12.5952 122.112 29.44 160 58.9312 25.2416 16.8448 42.0864 46.08 50.4832 79.9744a120.4224 120.4224 0 0 1-25.2416 92.6208c-67.328 79.9744-172.5952 105.216-282.0608 105.216z m0 0" fill="currentColor"/></svg>', colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn)), '漫步', const StrollPage()));
    if (userPrefs.showSidebarReviewed) exploreItems.add((_assetSvgIcon('assets/svg/yi_yue.svg', 20, colors.onSurface), '已阅', const ReviewedPage()));
    if (userPrefs.showSidebarPlaylist) exploreItems.add((_assetSvgIcon('assets/svg/shu_ying_pian_dan.svg', 20, colors.onSurface), '书影片单', const PlaylistListPage()));
    if (userPrefs.showSidebarCalendar) exploreItems.add((_assetSvgIcon('assets/svg/ri_li.svg', 20, colors.onSurface), '书影日历', const MediaCalendarPage()));

    final toolItems = <(Widget, String, Widget)>[];
    if (userPrefs.showSidebarTags) toolItems.add((_assetSvgIcon('assets/svg/biao_qian.svg', 20, colors.onSurface), '标签', const TagManagementPage()));
    if (userPrefs.showSidebarPerson) toolItems.add((_assetSvgIcon('assets/svg/ren_wu.svg', 20, colors.onSurface), '人物', const PersonListPage()));
    if (userPrefs.showSidebarGallery) toolItems.add((SvgPicture.string('<svg viewBox="0 0 1064 1024" xmlns="http://www.w3.org/2000/svg" width="20" height="20"><path d="M71.68 348.16A296.96 296.96 0 0 1 368.64 51.2h327.68a296.96 296.96 0 0 1 296.96 296.96v327.68A296.96 296.96 0 0 1 696.32 972.8H368.64a296.96 296.96 0 0 1-296.96-296.96v-327.68zM368.64 153.6A194.56 194.56 0 0 0 174.08 348.16v327.68A194.56 194.56 0 0 0 368.64 870.4h327.68a194.56 194.56 0 0 0 194.56-194.56v-327.68A194.56 194.56 0 0 0 696.32 153.6H368.64z" fill="currentColor"/><path d="M947.69152 606.08512a317.80864 317.80864 0 0 0-264.02816 209.7152l-96.54272-34.16064a420.20864 420.20864 0 0 1 349.34784-277.2992l11.22304 101.74464z" fill="currentColor"/><path d="M798.72 327.68a81.92 81.92 0 1 1-163.84 0 81.92 81.92 0 0 1 163.84 0z" fill="currentColor"/><path d="M163.84 542.72c-12.4928 0-24.86272 0.49152-37.0688 1.39264l-7.7824-102.11328c14.82752-1.10592 29.77792-1.67936 44.8512-1.67936 284.01664 0 520.6016 202.79296 572.90752 471.49056l-100.51584 19.57888C593.1008 709.87776 397.9264 542.72 163.84 542.72z" fill="currentColor"/></svg>', colorFilter: ColorFilter.mode(colors.onSurface, BlendMode.srcIn)), '图库', const GalleryPage()));

    if (userPrefs.showSidebarCustomModule) toolItems.add((_assetSvgIcon('assets/svg/zi_ding_yi_fen_lei.svg', 20, colors.onSurface), '自定义分类', const CustomModuleManagePage()));

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
      child: Text(title.tr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.3), letterSpacing: 1)),
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
            Expanded(child: Text(title.tr, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: textOpacity)))),
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
      items.add(_RecentItem(type: 'note', title: n.title.isNotEmpty ? n.title : '随手记'.tr, date: n.createdAt, data: n));
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
            monthLabels[week] = '{n}月'.trf({'n': date.month});
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
                  _assetSvgIcon('assets/svg/calender.svg', 14, colors.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 8),
                  Text('热力图'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
                  const Spacer(),
                  if (streak > 0) ...[
                    const Icon(Icons.local_fire_department, size: 14, color: Color(0xFFFF6D00)),
                    const SizedBox(width: 3),
                    Text('连续 {n} 天'.trf({'n': streak}), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFFF6D00))),
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
                            message: '{m}月{d}日'.trf({'m': date.month, 'd': date.day}) +
                                (count > 0 ? ' · {n}条'.trf({'n': count}) : ''),
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
                  Text('少'.tr, style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
                  const SizedBox(width: 3),
                  _legendCell(const Color(0xFFF0F0F0)),
                  _legendCell(const Color(0xFFC8E6C9)),
                  _legendCell(const Color(0xFF66BB6A)),
                  _legendCell(const Color(0xFF2E7D32)),
                  _legendCell(const Color(0xFF1B5E20)),
                  const SizedBox(width: 3),
                  Text('多'.tr, style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
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
                  Text('{m}月{d}日'.trf({'m': date.month, 'd': date.day}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(width: 8),
                  Text('{n}条记录'.trf({'n': count}), style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.45))),
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
                    for (final n in dayNotes) _dayDetailItem(ctx, Icons.sticky_note_2_outlined, n.title.isNotEmpty ? n.title : '随手记'.tr, const Color(0xFF9333EA)),
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
              Text('最近添加'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
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
    if (diff.inDays >= 365) return '{n}年前'.trf({'n': (diff.inDays / 365).floor()});
    if (diff.inDays >= 30) return '{n}月前'.trf({'n': (diff.inDays / 30).floor()});
    if (diff.inDays > 0) return '{n}天前'.trf({'n': diff.inDays});
    if (diff.inHours > 0) return '{n}小时前'.trf({'n': diff.inHours});
    return '刚刚'.tr;
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

// ─── 抽屉骨架屏（与真实区块同构：同款卡片容器 + 同位占位，切换不跳动） ────────

/// 热力图骨架屏：与 _buildCalendarSection 同构（卡片 + 头部 + 月份行 + 7×20 格子 + 图例）
class _HeatmapSkeleton extends StatelessWidget {
  const _HeatmapSkeleton();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = colors.outlineVariant;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：图标 + 标题
          Row(children: [
            ShimmerSkeleton(width: 14, height: 14, borderRadius: 3, color: c),
            const SizedBox(width: 8),
            ShimmerSkeleton(width: 44, height: 13, borderRadius: 4, color: c),
          ]),
          const SizedBox(height: 14),
          // 月份标签行（真实为首/中/尾三个稀疏 9px 文字）
          SizedBox(
            height: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ShimmerSkeleton(width: 18, height: 9, borderRadius: 2, color: c),
                ShimmerSkeleton(width: 18, height: 9, borderRadius: 2, color: c),
                ShimmerSkeleton(width: 18, height: 9, borderRadius: 2, color: c),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // 7×20 格子：尺寸公式与真实热力图一致
          LayoutBuilder(
            builder: (context, constraints) {
              const totalWeeks = 20;
              const cellGap = 1.5;
              final cellSize = ((constraints.maxWidth - (totalWeeks - 1) * cellGap) / totalWeeks).clamp(6.0, 10.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (day) => Row(
                  children: List.generate(totalWeeks, (week) => Padding(
                    padding: EdgeInsets.only(right: week < totalWeeks - 1 ? cellGap : 0, bottom: day < 6 ? cellGap : 0),
                    child: ShimmerSkeleton(width: cellSize, height: cellSize, borderRadius: 2, color: c),
                  )),
                )),
              );
            },
          ),
          const SizedBox(height: 8),
          // 图例行（右对齐：少 + 5 格 + 多）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ShimmerSkeleton(width: 12, height: 9, borderRadius: 2, color: c),
              const SizedBox(width: 3),
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: ShimmerSkeleton(width: 12, height: 12, borderRadius: 2, color: c),
                ),
              ShimmerSkeleton(width: 12, height: 9, borderRadius: 2, color: c),
            ],
          ),
        ],
      ),
    );
  }
}

/// 最近添加骨架屏：与 _buildRecentSection 同构（卡片 + 头部 + 6 行 图标+标题+时间）
class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = colors.outlineVariant;
    // 标题条宽度错落，贴近真实条目长度分布
    const titleWidths = [150.0, 110.0, 170.0, 90.0, 130.0, 100.0];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ShimmerSkeleton(width: 14, height: 14, borderRadius: 3, color: c),
            const SizedBox(width: 8),
            ShimmerSkeleton(width: 56, height: 13, borderRadius: 4, color: c),
          ]),
          const SizedBox(height: 14),
          for (var i = 0; i < 6; i++)
            Padding(
              padding: EdgeInsets.only(top: 2, bottom: i < 5 ? 10 : 0),
              child: Row(
                children: [
                  ShimmerSkeleton(width: 22, height: 22, borderRadius: 5, color: c),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ShimmerSkeleton(width: titleWidths[i], height: 13, borderRadius: 4, color: c),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShimmerSkeleton(width: 28, height: 10, borderRadius: 3, color: c),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 工具骨架屏：与 _buildToolsCard 同构（组标题 + 列表卡，探索/工具两组）
class _ToolsSkeleton extends StatelessWidget {
  const _ToolsSkeleton();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = colors.outlineVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _groupTitleBone(c),
        const SizedBox(height: 6),
        _groupCardBone(colors, c, 4),
        const SizedBox(height: 16),
        _groupTitleBone(c),
        const SizedBox(height: 6),
        _groupCardBone(colors, c, 3),
      ],
    );
  }

  Widget _groupTitleBone(Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ShimmerSkeleton(width: 26, height: 11, borderRadius: 3, color: c),
    );
  }

  Widget _groupCardBone(ColorScheme colors, Color c, int rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: List.generate(rows * 2 - 1, (i) {
          if (i.isOdd) return Divider(height: 1, indent: 52, endIndent: 20, color: colors.outlineVariant);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              children: [
                ShimmerSkeleton(width: 20, height: 20, borderRadius: 5, color: c),
                const SizedBox(width: 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ShimmerSkeleton(width: 64, height: 14, borderRadius: 4, color: c),
                  ),
                ),
                ShimmerSkeleton(width: 16, height: 16, borderRadius: 4, color: c),
              ],
            ),
          );
        }),
      ),
    );
  }
}
