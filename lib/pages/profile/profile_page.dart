import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../main.dart' show routeObserver;
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../l10n/app_strings.dart';
import '../../utils/user_prefs.dart';
import '../../utils/responsive.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/excel_exporter.dart';
import '../../services/server_export_service.dart';
import '../../widgets/float_badge_overlay.dart';
import '../settings/recycle_bin_page.dart';
import '../sync/backup_page.dart';
import '../../widgets/fade_in_local_image.dart';
import '../explore/statistics_page.dart';
import '../settings/tag_management_page.dart';
import '../explore/stroll_page.dart';
import '../sync/cloud_sync_page.dart';
import 'settings_page.dart';
import 'badges_page.dart';
import 'watchlist_page.dart';
import '../quick_add/quick_add_page.dart';
import '../../widgets/app_overlay.dart';
import 'avatar_crop_page.dart';

/// 个人中心页面
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  final ImagePicker _picker = ImagePicker();
  final UserPrefs _userPrefs = UserPrefs();

  String _nickname = 'Mook';
  String _motto = '好运不会眷顾一无所有之人。';
  String? _avatarPath;

  // 我的模块切换索引 (0=影视, 1=阅读, 2=游戏, 3=笔记)
  int _myModuleIndex = 0;

  // Hero 背景封面路径缓存，避免每次 build 都 shuffle 换图
  List<String> _heroCoverPaths = const [];

  @override
  void initState() {
    super.initState();
    _myModuleIndex = _userPrefs.profileModuleIndex;
    _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 从其他页面返回时刷新用户数据（头像、昵称等）+ 换一次背景图
    _loadUserData();
    _invalidateHeroCache();
  }

  void _invalidateHeroCache() {
    setState(() => _heroCoverPaths = const []);
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _nickname = _userPrefs.nickname;
        _motto = _userPrefs.motto;
        _avatarPath = _userPrefs.avatarPath;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AppBar(
          titleSpacing: 8,
          leadingWidth: 44,
          leading: Breakpoint.isDesktop(context)
              ? const SizedBox.shrink()
              : Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.menu, color: colors.onSurface),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
          title: Text('我的'.tr),
        ),
        Expanded(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              final movies =
                  provider.movies.where((m) => !m.isDeleted).toList();
              final books = provider.books.where((b) => !b.isDeleted).toList();
              final notes = provider.notes.where((n) => !n.isDeleted).toList();
              final games = provider.games.where((g) => !g.isDeleted).toList();
              return Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHero(movies, books, notes, games),
                        const SizedBox(height: 20),
                        _buildMyModule(movies, books, notes, games),
                        const SizedBox(height: 20),
                        _buildWatchlist(movies, books, games),
                        const SizedBox(height: 20),
                        _buildTagsSection(movies, books, notes),
                        const SizedBox(height: 20),
                        _buildToolsGrid(context),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                  // 浮动徽章图标层（与主页共享位置，可拖拽换位）
                  const FloatBadgeOverlay(page: 'profile'),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Hero 区域 ──────────────────────────────────────────────────────

  Widget _buildHero(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    final colors = Theme.of(context).colorScheme;
    // 仅在缓存为空时重新生成（进入页面 / 从其他页面返回），避免每次 build 都 shuffle 换图
    if (_heroCoverPaths.isEmpty) {
      _heroCoverPaths = [
        ...movies
            .where((m) => m.posterPath != null && m.posterPath!.isNotEmpty)
            .map((m) => m.posterPath!),
        ...books
            .where((b) => b.coverPath != null && b.coverPath!.isNotEmpty)
            .map((b) => b.coverPath!),
      ]..shuffle();
    }
    final coverPaths = _heroCoverPaths;

    final hasData = coverPaths.length >= 4;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          if (hasData)
            Positioned.fill(child: _buildPosterMosaic(coverPaths))
          else
            Positioned.fill(
                child: Container(
                    decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.primary, colors.primary.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ))),
          Positioned.fill(
              child: Container(
                  color: hasData
                      ? Colors.black.withValues(alpha: 0.35)
                      : colors.surface.withValues(alpha: 0.82))),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 20, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: hasData
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : colors.outlineVariant,
                              width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _avatarPath != null && _avatarPath!.isNotEmpty
                            ? FadeInLocalImage(
                                path: _avatarPath,
                                fit: BoxFit.cover,
                                errorWidget: Icon(Icons.person_outline,
                                    size: 28,
                                    color: hasData
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : colors.onSurface
                                            .withValues(alpha: 0.3)))
                            : Container(
                                color: hasData
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : colors.surfaceContainerHighest,
                                child: Icon(Icons.person_outline,
                                    size: 28,
                                    color: hasData
                                        ? Colors.white.withValues(alpha: 0.5)
                                        : colors.onSurface
                                            .withValues(alpha: 0.3))),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nickname,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: hasData
                                      ? Colors.white
                                      : colors.onSurface)),
                          const SizedBox(height: 4),
                          Text(_motto.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: hasData
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : colors.onSurface
                                          .withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (_userPrefs.showMovieTab) _buildHeroStat(_formatCount(movies.length), '观影'.tr, hasData),
                    if (_userPrefs.showBookTab) _buildHeroStat(_formatCount(books.length), '阅读'.tr, hasData),
                    if (_userPrefs.showGameTab) _buildHeroStat(_formatCount(games.length), '游戏'.tr, hasData),
                    if (_userPrefs.showNoteTab) _buildHeroStat(_formatCount(notes.length), '笔记'.tr, hasData),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterMosaic(List<String> paths) {
    const cellCount = 30;
    final posters = paths.take(cellCount).toList();
    while (posters.length < cellCount)
      posters.add(posters[posters.length % paths.length]);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
      ),
      itemCount: cellCount,
      itemBuilder: (_, i) =>
          FadeInLocalImage(path: posters[i], fit: BoxFit.cover),
    );
  }

  Widget _buildHeroStat(String value, String label, bool hasData) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: hasData
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: hasData
                      ? Colors.white.withValues(alpha: 0.85)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  // 我的模块数据
  static const _moduleDefs = <(String, IconData)>[
    ('影视', Icons.movie_outlined),
    ('阅读', Icons.menu_book_outlined),
    ('游戏', Icons.sports_esports_outlined),
    ('笔记', Icons.sticky_note_2_outlined),
  ];

  List<(String, IconData)> get _visibleModules {
    final result = <(String, IconData)>[];
    if (_userPrefs.showMovieTab) result.add(_moduleDefs[0]);
    if (_userPrefs.showBookTab) result.add(_moduleDefs[1]);
    if (_userPrefs.showGameTab) result.add(_moduleDefs[2]);
    if (_userPrefs.showNoteTab) result.add(_moduleDefs[3]);
    return result;
  }

  // 我的模块分发
  Widget _buildMyModule(List<Movie> movies, List<Book> books, List<Note> notes, List<Game> games) {
    final modules = _visibleModules;
    if (modules.isEmpty) return const SizedBox.shrink();
    // _myModuleIndex 是 _moduleDefs 下标（跨界面持久化），映射到当前可见下标；
    // 所选模块的标签被隐藏时回退到第一个可见模块
    var index = modules.indexOf(_moduleDefs[_myModuleIndex.clamp(0, _moduleDefs.length - 1)]);
    if (index < 0) index = 0;
    final (title, _) = modules[index];

    Widget content;
    switch (title) {
      case '阅读':
        content = _buildBookModule(books);
        break;
      case '笔记':
        content = _buildNoteModule(notes);
        break;
      case '游戏':
        content = _buildGameModule(games);
        break;
      default:
        content = _buildMovieModule(movies);
    }

    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(title.tr,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              const Spacer(),
              // 图标切换器
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < modules.length; i++) ...[
                    if (i != 0) const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() => _myModuleIndex = _moduleDefs.indexOf(modules[i]));
                        _userPrefs.setProfileModuleIndex(_myModuleIndex);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: i == index ? colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(modules[i].$2,
                            size: 16,
                            color: i == index
                                ? colors.onPrimary
                                : colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  // ─── 游戏模块 ──────────────────────────────────────────────────────

  Widget _buildGameModule(List<Game> games) {
    final colors = Theme.of(context).colorScheme;
    final completed = games.where((g) => g.status == 'completed').length;
    final playing = games.where((g) => g.status == 'playing').length;
    final wantTo = games.where((g) => g.status == 'want_to_play').length;
    final recent = games.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _buildStatusTag('已通关'.tr, completed, true, colors),
            const SizedBox(width: 10),
            _buildStatusTag('在玩'.tr, playing, false, colors),
            const SizedBox(width: 10),
            _buildStatusTag('想玩'.tr, wantTo, false, colors),
          ]),
        ),
        const SizedBox(height: 10),
        if (recent.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recent.take(15).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildCoverCard(
                title: recent[i].title,
                imagePath: recent[i].coverPath,
                onTap: () => Navigator.pushNamed(context, '/game-detail',
                    arguments: recent[i]),
              ),
            ),
          )
        else
          _buildEmptyHint('暂无游戏记录'.tr),
      ],
    );
  }

  // ─── 影视模块 ──────────────────────────────────────────────────────

  Widget _buildMovieModule(List<Movie> movies) {
    final colors = Theme.of(context).colorScheme;
    final watched = movies.where((m) => m.status == 'watched').length;
    final watching = movies.where((m) => m.status == 'watching').length;
    final wantTo = movies.where((m) => m.status == 'want_to_watch').length;
    final recent = movies.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _buildStatusTag('已看'.tr, watched, true, colors),
            const SizedBox(width: 10),
            _buildStatusTag('在看'.tr, watching, false, colors),
            const SizedBox(width: 10),
            _buildStatusTag('想看'.tr, wantTo, false, colors),
          ]),
        ),
        const SizedBox(height: 10),
        if (recent.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recent.take(15).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildCoverCard(
                title: recent[i].title,
                imagePath: recent[i].posterPath,
                onTap: () => Navigator.pushNamed(context, '/movie-detail',
                    arguments: recent[i]),
              ),
            ),
          )
        else
          _buildEmptyHint('暂无影视记录'.tr),
      ],
    );
  }

  // ─── 阅读模块 ──────────────────────────────────────────────────────

  Widget _buildBookModule(List<Book> books) {
    final colors = Theme.of(context).colorScheme;
    final read = books.where((b) => b.status == 'read').length;
    final reading = books.where((b) => b.status == 'reading').length;
    final wantTo = books.where((b) => b.status == 'want_to_read').length;
    final recent = books.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _buildStatusTag('已读'.tr, read, true, colors),
            const SizedBox(width: 10),
            _buildStatusTag('在读'.tr, reading, false, colors),
            const SizedBox(width: 10),
            _buildStatusTag('想读'.tr, wantTo, false, colors),
          ]),
        ),
        const SizedBox(height: 10),
        if (recent.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: recent.take(15).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _buildCoverCard(
                title: recent[i].title,
                imagePath: recent[i].coverPath,
                onTap: () => Navigator.pushNamed(context, '/book-detail',
                    arguments: recent[i]),
              ),
            ),
          )
        else
          _buildEmptyHint('暂无阅读记录'.tr),
      ],
    );
  }

  // ─── 笔记模块 ──────────────────────────────────────────────────────

  Widget _buildNoteModule(List<Note> notes) {
    final recent = notes.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (recent.isEmpty) return _buildEmptyHint('暂无笔记记录'.tr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recent.take(10).length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _buildNoteCard(
              title: recent[i].title,
              content: recent[i].content,
              onTap: () => Navigator.pushNamed(context, '/note-detail',
                  arguments: recent[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteCard({
    required String title,
    required String content,
    VoidCallback? onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 115,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              const SizedBox(height: 6),
            ],
            Expanded(
              child: Text(content,
                  maxLines: title.isNotEmpty ? 5 : 6,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: colors.onSurface.withValues(alpha: 0.55))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(
      String label, int count, bool active, ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.25),
          ),
        ),
        const SizedBox(width: 4),
        Text('$label $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: 0.5),
            )),
      ],
    );
  }

  Widget _buildCoverCard(
      {required String title, String? imagePath, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: 78,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: imagePath != null && imagePath.isNotEmpty
                    ? FadeInLocalImage(
                        path: imagePath,
                        fit: BoxFit.cover,
                        errorWidget: Icon(Icons.image_outlined,
                            size: 20,
                            color: colors.onSurface.withValues(alpha: 0.2)))
                    : Icon(Icons.image_outlined,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.2)),
              ),
            ),
            const SizedBox(height: 4),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  // ─── 想看清单 ──────────────────────────────────────────────────────

  Widget _buildWatchlist(List<Movie> movies, List<Book> books, List<Game> games) {
    final colors = Theme.of(context).colorScheme;

    final movieWantTo = _userPrefs.showMovieTab
        ? movies.where((m) => m.status == 'want_to_watch').length
        : 0;
    final bookWantTo = _userPrefs.showBookTab
        ? books.where((b) => b.status == 'want_to_read').length
        : 0;
    final gameWantTo = _userPrefs.showGameTab
        ? games.where((g) => g.status == 'want_to_play').length
        : 0;

    final items = <_WatchlistItem>[];
    if (_userPrefs.showMovieTab) {
      for (final m in movies.where((m) => m.status == 'want_to_watch')) {
        items.add(_WatchlistItem(
          title: m.title,
          imagePath: m.posterPath,
          type: 'movie',
          createdAt: m.createdAt,
          onTap: () => Navigator.pushNamed(context, '/movie-detail', arguments: m),
        ));
      }
    }
    if (_userPrefs.showBookTab) {
      for (final b in books.where((b) => b.status == 'want_to_read')) {
        items.add(_WatchlistItem(
          title: b.title,
          imagePath: b.coverPath,
          type: 'book',
          createdAt: b.createdAt,
          onTap: () => Navigator.pushNamed(context, '/book-detail', arguments: b),
        ));
      }
    }
    if (_userPrefs.showGameTab) {
      for (final g in games.where((g) => g.status == 'want_to_play')) {
        items.add(_WatchlistItem(
          title: g.title,
          imagePath: g.coverPath,
          type: 'game',
          createdAt: g.createdAt,
          onTap: () => Navigator.pushNamed(context, '/game-detail', arguments: g),
        ));
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('想看清单'.tr,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WatchlistPage())),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('全部'.tr,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                    Icon(Icons.chevron_right,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            if (_userPrefs.showMovieTab) ...[
              _buildStatusTag('影视'.tr, movieWantTo, true, colors),
              const SizedBox(width: 10),
            ],
            if (_userPrefs.showBookTab) ...[
              _buildStatusTag('书籍'.tr, bookWantTo, false, colors),
              const SizedBox(width: 10),
            ],
            if (_userPrefs.showGameTab)
              _buildStatusTag('游戏'.tr, gameWantTo, false, colors),
          ]),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
                child: Text('暂无想看记录'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.3)))),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: items.take(20).length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final item = items[i];
                return GestureDetector(
                  onTap: item.onTap,
                  child: SizedBox(
                    width: 78,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: 78,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.imagePath != null && item.imagePath!.isNotEmpty
                                ? FadeInLocalImage(
                                    path: item.imagePath,
                                    fit: BoxFit.cover,
                                    errorWidget: Icon(Icons.image_outlined,
                                        size: 20,
                                        color: colors.onSurface.withValues(alpha: 0.2)))
                                : Icon(Icons.image_outlined,
                                    size: 20,
                                    color: colors.onSurface.withValues(alpha: 0.2)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                color: colors.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyHint(String text) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.3)))),
    );
  }

  // ─── 标签模块 ──────────────────────────────────────────────────────

  Widget _buildTagsSection(
      List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final freq = <String, int>{};
    for (final m in movies) {
      for (final g in m.genres) {
        freq[g] = (freq[g] ?? 0) + 1;
      }
    }
    for (final b in books) {
      for (final g in b.genres) {
        freq[g] = (freq[g] ?? 0) + 1;
      }
    }
    for (final n in notes) {
      for (final t in n.tags) {
        freq[t] = (freq[t] ?? 0) + 1;
      }
    }
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTags = sorted.take(10).map((e) => e.key).toList();

    if (topTags.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('常用标签'.tr,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TagManagementPage())),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('管理'.tr,
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                    Icon(Icons.chevron_right,
                        size: 16,
                        color: colors.onSurface.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topTags
                .map((tag) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(tag,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.7))),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ─── 工具栏 ────────────────────────────────────────────────────────

  Widget _buildToolsGrid(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tools = [
      (
        Icons.explore_outlined,
        '漫步'.tr,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StrollPage()))
      ),
      (
        Icons.analytics_outlined,
        '数据统计'.tr,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StatisticsPage()))
      ),
      (
        Icons.add_circle_outline,
        '快捷添加'.tr,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const QuickAddPage()))
      ),
      (Icons.backup_outlined, '数据备份'.tr, () => _showBackupOptions(context)),
      (Icons.ios_share_outlined, 'EXCEL导出'.tr, () => _showExportOptions(context)),
      (
        Icons.emoji_events_outlined,
        '成就徽章'.tr,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BadgesPage()))
      ),
      (
        Icons.settings_outlined,
        '设置'.tr,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsPage()))
      ),
      (
        Icons.delete_outline,
        '回收站'.tr,
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RecycleBinPage()))
      ),
      (Icons.feedback_outlined, 'BUG反馈'.tr, () => _showFeedbackDialog(context)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: tools.asMap().entries.map((e) {
            final isLast = e.key == tools.length - 1;
            return Column(
              children: [
                InkWell(
                  onTap: e.value.$3,
                  borderRadius: BorderRadius.only(
                    topLeft:
                        e.key == 0 ? const Radius.circular(12) : Radius.zero,
                    topRight:
                        e.key == 0 ? const Radius.circular(12) : Radius.zero,
                    bottomLeft:
                        isLast ? const Radius.circular(12) : Radius.zero,
                    bottomRight:
                        isLast ? const Radius.circular(12) : Radius.zero,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(e.value.$1,
                            size: 18,
                            color: colors.onSurface.withValues(alpha: 0.6)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(e.value.$2,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurface
                                        .withValues(alpha: 0.7)))),
                        Icon(Icons.chevron_right,
                            size: 16,
                            color: colors.onSurface.withValues(alpha: 0.2)),
                      ],
                    ),
                  ),
                ),
                if (!isLast)
                  Divider(
                      height: 1,
                      indent: 46,
                      endIndent: 16,
                      color: colors.outlineVariant),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── 辅助方法 ──────────────────────────────────────────────────────

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return AppStrings.isEnglish
          ? '${(count / 1000000).toStringAsFixed(1)}M'
          : '${(count / 10000).toStringAsFixed(1)}万';
    }
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 反馈弹窗 ────────────────────────────────────────────────────────

  void _showFeedbackDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = 'dellevin99@gmail.com';
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('反馈'.tr,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)))),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.email_outlined,
                      size: 20, color: colors.primary.withValues(alpha: 0.8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('作者邮箱'.tr,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    colors.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(height: 2),
                        Text(email,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: email));
                      ToastUtil.show(context, '已复制到剪贴板'.tr);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Text('复制'.tr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.group_outlined,
                      size: 20, color: colors.primary.withValues(alpha: 0.8)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('QQ 群'.tr,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    colors.onSurface.withValues(alpha: 0.5))),
                        const SizedBox(height: 2),
                        Text('1087203310',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '1087203310'));
                      ToastUtil.show(context, '已复制到剪贴板'.tr);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, size: 14, color: colors.primary),
                          const SizedBox(width: 4),
                          Text('复制'.tr,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  // ─── 头像 ────────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final colors = Theme.of(context).colorScheme;
    await appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('更换头像'.tr,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)))),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.folder_outlined,
                    size: 20, color: colors.onSurface.withValues(alpha: 0.6))),
            title: Text('从文件管理器选择'.tr,
                style: TextStyle(fontSize: 14, color: colors.onSurface)),
            trailing: Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () async {
              Navigator.pop(ctx);
              await _pickAvatarFromFile();
            },
          ),
          if (_avatarPath != null && _avatarPath!.isNotEmpty) ...[
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.delete_outline,
                      size: 20, color: colors.error)),
              title: Text('移除头像'.tr,
                  style: TextStyle(fontSize: 14, color: colors.error)),
              trailing: Icon(Icons.chevron_right,
                  color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () async {
                Navigator.pop(ctx);
                await _userPrefs.clearAvatarPath();
                if (!mounted) return;
                setState(() => _avatarPath = null);
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickAvatarFromFile() async {
    try {
      final pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;
      // 先读取原图字节，进入裁剪页调整圆形区域
      final bytes = await File(pickedFile.path).readAsBytes();
      if (!mounted) return;
      final Uint8List? cropped = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
            builder: (_) => AvatarCropPage(imageBytes: bytes)),
      );
      if (cropped == null) return;
      final appDirPath = await ImagePathHelper.getAppDir();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedPath = path.join(appDirPath, 'avatars', fileName);
      final avatarDir = Directory(path.join(appDirPath, 'avatars'));
      if (!await avatarDir.exists()) await avatarDir.create(recursive: true);
      await File(savedPath).writeAsBytes(cropped);
      await _userPrefs.setAvatarPath(savedPath);
      if (!mounted) return;
      setState(() => _avatarPath = savedPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择头像失败'.tr);
    }
  }

  // ─── 备份弹窗 ────────────────────────────────────────────────────────

  void _showBackupOptions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('选择备份方式'.tr,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.folder_outlined,
                      color: colors.onSurface.withValues(alpha: 0.6))),
              title: Text('本地备份'.tr,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
              subtitle: Text('备份到本地文件夹，支持恢复'.tr,
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: Icon(Icons.chevron_right,
                  color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () {
                Navigator.pop(ctx);
                _push(context, const BackupPage());
              },
            ),
            Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.cloud_outlined,
                      color: colors.onSurface.withValues(alpha: 0.6))),
              title: Text('云备份'.tr,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
              subtitle: Text('通过 WebDAV 同步到云端'.tr,
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: Icon(Icons.chevron_right,
                  color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () {
                Navigator.pop(ctx);
                _push(context, const CloudSyncPage());
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<AppProvider>();
    final userPrefs = UserPrefs();

    final options = <(String, IconData, int)>[];
    if (userPrefs.showMovieTab) {
      options.add(('影视', Icons.movie_outlined, provider.movies.where((m) => !m.isDeleted).length));
    }
    if (userPrefs.showBookTab) {
      options.add(('阅读', Icons.menu_book_outlined, provider.books.where((b) => !b.isDeleted).length));
    }
    if (userPrefs.showGameTab) {
      options.add(('游戏', Icons.sports_esports_outlined, provider.games.where((g) => !g.isDeleted).length));
    }
    options.add(('笔记', Icons.sticky_note_2_outlined, provider.notes.where((n) => !n.isDeleted).length));

    bool withImages = userPrefs.exportWithImages;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('选择导出类型'.tr,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface))),
            const SizedBox(height: 4),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('导出为 Excel (.xlsx) 格式'.tr,
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4)))),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: withImages,
              onChanged: (v) async {
                if (v) {
                  final ok = await _confirmEnableOnlineExport(ctx);
                  if (!ok) return;
                }
                setSheetState(() => withImages = v);
                UserPrefs().setExportWithImages(v);
              },
              title: Text('附带封面图片（在线生成）'.tr,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
              subtitle: Text('需要增强搜索 Token，上传数据后由服务器生成'.tr,
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.4))),
            ),
            Divider(height: 0.5, color: colors.outlineVariant),
            for (final (label, icon, count) in options) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon,
                        size: 18,
                        color: colors.onSurface.withValues(alpha: 0.6))),
                title: Text(label.tr,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                subtitle: Text('{n} 条记录'.trf({'n': count}),
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
                trailing: Icon(Icons.chevron_right,
                    color: colors.onSurface.withValues(alpha: 0.25)),
                onTap: () async {
                  Navigator.pop(ctx);
                  const reviewLabels = {'影视': '影评', '阅读': '书评', '游戏': '游戏评价'};
                  final reviewLabel = reviewLabels[label];
                  var withReviews = false;
                  if (reviewLabel != null) {
                    final entityLabel = label == '阅读' ? '书籍' : label;
                    final r = await _askExportWithReviews(context, entityLabel, reviewLabel);
                    if (r == null) return; // 取消导出
                    withReviews = r;
                  }
                  if (!context.mounted) return;
                  _doExport(context, label, withImages: withImages, withReviews: withReviews);
                },
              ),
              if (label != options.last.$1)
                Divider(height: 0.5, color: colors.outlineVariant),
            ],
            const SizedBox(height: 20),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _doExport(BuildContext context, String type, {bool withImages = false, bool withReviews = false}) async {
    if (withImages) {
      return _doOnlineExport(context, type, withReviews: withReviews);
    }
    final provider = context.read<AppProvider>();
    try {
      File file;
      switch (type) {
        case '影视':
          file = await ExcelExporter.exportMovies(
            provider.movies.where((m) => !m.isDeleted).toList(),
            reviews: withReviews ? await provider.getAllMovieReviews() : null,
          );
          break;
        case '阅读':
          file = await ExcelExporter.exportBooks(
            provider.books.where((b) => !b.isDeleted).toList(),
            reviews: withReviews ? await provider.getAllBookReviews() : null,
          );
          break;
        case '游戏':
          file = await ExcelExporter.exportGames(
            provider.games.where((g) => !g.isDeleted).toList(),
            reviews: withReviews ? await provider.getAllGameReviews() : null,
          );
          break;
        default:
          file = await ExcelExporter.exportNotes(
              provider.notes.where((n) => !n.isDeleted).toList());
      }
      if (!context.mounted) return;
      _showExportResult(context, true, '已导出到 {path}'.trf({'path': file.path}));
    } catch (e) {
      if (!context.mounted) return;
      _showExportResult(context, false, '导出失败：{e}'.trf({'e': e}));
    }
  }

  /// 导出前询问是否连同评论一起导出（影视/阅读/游戏）；返回 null 表示取消
  Future<bool?> _askExportWithReviews(BuildContext context, String entityLabel, String reviewLabel) async {
    final colors = Theme.of(context).colorScheme;
    return appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('是否连同{reviewLabel}一起导出？'.trf({'reviewLabel': reviewLabel.tr}),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          '选择"是"时，Excel 中会额外附带一个{reviewLabel}工作表'
              .trf({'reviewLabel': reviewLabel.tr}),
          style: TextStyle(fontSize: 13, height: 1.6, color: colors.onSurface),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('仅导出{entity}'.trf({'entity': entityLabel.tr})),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('是'.tr),
          ),
        ],
      ),
    );
  }

  /// 打开"附带封面图片"开关前的告知确认（涉及数据上传云端）
  Future<bool> _confirmEnableOnlineExport(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    final ok = await appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('在线带图导出'.tr,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text(
          '开启后，导出时会将本地数据库与图片打包上传至服务器，由服务器生成附带封面图片的 Excel 后回传下载。请知悉：\n'
                  '· 需增强搜索的影视与书籍 Token 均有效\n'
                  '· 涉及本地数据上传云端，请酌情使用\n'
                  '· 数据仅用于生成文件，下载完成后服务器将立即删除'
              .tr,
          style: TextStyle(fontSize: 13, height: 1.6, color: colors.onSurface),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('开启'.tr),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  /// 在线带图导出：进度弹窗 → 打包/上传/排队/生成/下载 → 复用结果弹窗
  Future<void> _doOnlineExport(BuildContext context, String label, {bool withReviews = false}) async {
    const typeMap = {'影视': 'movies', '阅读': 'books', '游戏': 'games', '笔记': 'notes'};
    final type = typeMap[label] ?? 'movies';

    String statusText = '正在打包数据...'.tr;
    double? progressValue;
    StateSetter? dialogSetState;
    BuildContext? dialogCtx;
    bool exportFinished = false;

    final exportFuture = ServerExportService.export(
      type: type,
      withReviews: withReviews,
      onProgress: (stage, {percent = 0, position = 0}) {
        switch (stage) {
          case ServerExportStage.packing:
            statusText = '正在打包数据...'.tr;
            progressValue = null;
          case ServerExportStage.uploading:
            statusText = '正在上传 {p}%'.trf({'p': percent});
            progressValue = percent / 100;
          case ServerExportStage.queued:
            statusText = position > 0
                ? '排队中（第 {n} 位）...'.trf({'n': position})
                : '排队中...'.tr;
            progressValue = null;
          case ServerExportStage.processing:
            statusText = '服务器生成中...'.tr;
            progressValue = null;
          case ServerExportStage.downloading:
            statusText = '正在下载结果...'.tr;
            progressValue = null;
        }
        dialogSetState?.call(() {});
      },
    );

    File? resultFile;
    Object? exportError;
    exportFuture.then((file) {
      resultFile = file;
    }).catchError((e) {
      exportError = e;
    }).whenComplete(() {
      exportFinished = true;
      final ctx = dialogCtx;
      if (ctx != null && ctx.mounted) Navigator.pop(ctx);
    });

    await appDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        if (exportFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) Navigator.pop(ctx);
          });
        }
        return StatefulBuilder(
          builder: (ctx, setState) {
            dialogSetState = setState;
            final colors = Theme.of(ctx).colorScheme;
            return AlertDialog(
              backgroundColor: colors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text('带图导出'.tr,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 4,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    statusText,
                    style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!context.mounted) return;
    if (resultFile != null) {
      _showExportResult(context, true, '已导出到 {path}'.trf({'path': resultFile!.path}));
    } else {
      _showExportResult(context, false, '导出失败：{e}'.trf({'e': exportError ?? ''}));
    }
  }

  void _showExportResult(BuildContext context, bool success, String message) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          success ? Icons.check_circle_outline : Icons.error_outline,
          color: success ? colors.primary : colors.error,
          size: 32,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: colors.onSurface),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('确定'.tr),
          ),
        ],
      ),
    );
  }
}

class _WatchlistItem {
  final String title;
  final String? imagePath;
  final String type; // movie / book / game
  final DateTime createdAt;
  final VoidCallback onTap;

  const _WatchlistItem({
    required this.title,
    this.imagePath,
    required this.type,
    required this.createdAt,
    required this.onTap,
  });
}
