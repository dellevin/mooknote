import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../utils/responsive.dart';
import '../../utils/toast_util.dart';
import '../../widgets/custom_drawer.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/add_sheet.dart';
import '../../widgets/add_type_selector.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../pages/epub_reader/epub_library_page.dart';
import 'desktop_home_page.dart';
import '../../pages/movies/movie_detail_page.dart';
import '../../pages/book/book_detail_page.dart';
import '../../pages/note/note_detail_page.dart';
import '../../services/sync/backup_service.dart';
import '../../services/sync/webdav_service.dart';
import '../../pages/profile/settings_page.dart';
import 'main_content_page.dart';
import '../online_search/search_page.dart';
import '../online_search/online_search_page.dart';
import '../profile/profile_page.dart';

/// 主页 - 包含底部导航，可切换主页/我的
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  bool _isSwitchingPage = false;
  int _lastNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _lastNavIndex = context.read<AppProvider>().bottomNavIndex;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavIndexChanged(AppProvider provider) {
    final currentPage = provider.bottomNavIndex == 0 ? 0 : 1;
    if (currentPage == _lastNavIndex) return;
    _lastNavIndex = currentPage;

    if (!_pageController.hasClients) return;
    if (_pageController.page?.round() == currentPage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isSwitchingPage = true;
      _pageController.jumpToPage(currentPage);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isSwitchingPage = false;
          provider.setBottomNavVisible(true);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (Breakpoint.isDesktop(context)) {
      return _buildDesktopLayout(context);
    }
    if (Breakpoint.isTablet(context)) {
      return _buildTabletLayout(context);
    }
    return _buildPhoneLayout(context);
  }

  // ─── 桌面布局（三栏：图标导航 | 列表面板 | 内容区） ──────

  Widget _buildDesktopLayout(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        _onNavIndexChanged(provider);
        final isHomeTab = provider.mainTabIndex == -1;
        return Scaffold(
          body: Row(
            children: [
              // 第一栏：图标导航
              _DesktopIconRail(
                mainTabIndex: provider.mainTabIndex,
                onTabSelected: (index) {
                  provider.setMainTabIndex(index);
                },
              ),
              VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
              // 第二栏：列表面板（主页时隐藏）
              if (!isHomeTab) ...[
                SizedBox(
                  width: 300,
                  child: _DesktopListPanel(
                    mainTabIndex: provider.mainTabIndex,
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
              ],
              // 第三栏：内容区
              Expanded(
                child: isHomeTab
                    ? const DesktopHomePage()
                    : _buildPageView(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 平板布局 ──────────────────────────────────────────

  Widget _buildTabletLayout(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        _onNavIndexChanged(provider);
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 260,
                child: Material(
                  color: colors.surfaceContainerHigh,
                  child: const CustomDrawer(embedded: true),
                ),
              ),
              NavigationRail(
                selectedIndex: provider.bottomNavIndex == 0 ? 0 : 1,
                backgroundColor: colors.surface,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: FloatingActionButton.small(
                    onPressed: () => showAddSheet(context, provider),
                    child: const Icon(Icons.add),
                  ),
                ),
                onDestinationSelected: (index) {
                  provider.setBottomNavIndex(index == 0 ? 0 : 2);
                },
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('首页'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon: Icon(Icons.person),
                    label: Text('我的'),
                  ),
                ],
              ),
              Expanded(child: _buildPageView(provider)),
            ],
          ),
        );
      },
    );
  }

  // ─── 手机布局 ──────────────────────────────────────────

  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      drawer: context.watch<AppProvider>().bottomNavIndex != 1
          ? const CustomDrawer()
          : null,

      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          _onNavIndexChanged(provider);

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (_isSwitchingPage) return false;
              if (notification is ScrollUpdateNotification) {
                final delta = notification.scrollDelta;
                if (delta != null && delta.abs() > 2) {
                  final userPrefs = UserPrefs();
                  if (!userPrefs.hideBottomNavOnScroll) return false;
                  if (delta < 0) {
                    provider.setBottomNavVisible(true);
                  } else {
                    provider.setBottomNavVisible(false);
                  }
                }
              }
              return false;
            },
            child: Stack(
              children: [
                _buildPageView(provider),

                // 底部导航栏区域
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSlide(
                    offset: provider.bottomNavVisible
                        ? Offset.zero
                        : const Offset(-1, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: const CustomBottomNavBar(),
                  ),
                ),

                if (!provider.bottomNavVisible)
                  Positioned(
                    left: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                    child: GestureDetector(
                      onTap: () => provider.setBottomNavVisible(true),
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null &&
                            details.primaryVelocity! > 0) {
                          provider.setBottomNavVisible(true);
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(28)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageView(AppProvider provider) {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (index == 0) {
          provider.setBottomNavIndex(0);
        } else if (index == 1) {
          provider.setBottomNavIndex(2);
        }
      },
      children: [
        const MainContentPage(),
        const ProfilePage(),
      ],
    );
  }
}

// ─── 第一栏：图标导航栏 ──────────────────────────────────

class _DesktopIconRail extends StatelessWidget {
  final int mainTabIndex;
  final ValueChanged<int> onTabSelected;

  const _DesktopIconRail({
    required this.mainTabIndex,
    required this.onTabSelected,
  });

  static const _categoryMeta = [
    (Icons.movie_outlined, Icons.movie, '影视', 0, Color(0xFF2563EB)),
    (Icons.menu_book_outlined, Icons.menu_book, '阅读', 1, Color(0xFF16A34A)),
    (Icons.note_outlined, Icons.note, '笔记', 2, Color(0xFF9333EA)),
    (Icons.sports_esports_outlined, Icons.sports_esports, '游戏', 3, Color(0xFFEA580C)),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();

    final tabs = _categoryMeta.where((t) {
      switch (t.$4) {
        case 0: return userPrefs.showMovieTab;
        case 1: return userPrefs.showBookTab;
        case 2: return userPrefs.showNoteTab;
        case 3: return userPrefs.showGameTab;
        default: return false;
      }
    }).toList();

    return Material(
      color: colors.surface,
      child: SizedBox(
        width: 160,
        child: Column(
          children: [
            SizedBox(height: (Platform.isWindows ? 0 : MediaQuery.of(context).padding.top) + 8),
            // 头像 + 昵称 + 座右铭
            _buildProfileHeader(context),
            const SizedBox(height: 10),
            // 添加 + 搜索
            _IconRailItem(icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: '添加', accentColor: colors.primary, selected: false, onTap: () {
              final provider = context.read<AppProvider>();
              if (Breakpoint.isDesktop(context)) {
                showAddTypeSelector(context).then((type) {
                  if (type != null) provider.startAddingType(type);
                });
              } else {
                showAddSheet(context, provider);
              }
            }),
            _IconRailItem(icon: Icons.search, activeIcon: Icons.search, label: '搜索', accentColor: colors.primary, selected: false, onTap: () => _showSearchDialog(context)),
            const SizedBox(height: 2),
            // 主页标签
            if (userPrefs.showDesktopHomeTab)
              _IconRailItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: '主页', accentColor: colors.primary, selected: mainTabIndex == -1, onTap: () => onTabSelected(-1)),
            // 分类图标
            ...tabs.map((t) {
              final selected = mainTabIndex == t.$4;
              return _IconRailItem(
                icon: t.$1,
                activeIcon: t.$2,
                label: t.$3,
                accentColor: t.$5,
                selected: selected,
                onTap: () => onTabSelected(t.$4),
              );
            }),
            const Divider(height: 24, indent: 12, endIndent: 12),
            // 探索 + 工具（可滚动）
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _IconRailItem(icon: Icons.favorite_border, activeIcon: Icons.favorite, label: '统计', accentColor: colors.primary, selected: false, onTap: () => _showEncounterDialog(context)),
                    _IconRailItem(icon: Icons.explore_outlined, activeIcon: Icons.explore, label: '漫步', accentColor: colors.primary, selected: false, onTap: () => _showStrollDialog(context)),
                    _IconRailItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: '日历', accentColor: colors.primary, selected: false, onTap: () => _showCalendarDialog(context)),
                    const Divider(height: 24, indent: 12, endIndent: 12),
                    _IconRailItem(icon: Icons.people_outline, activeIcon: Icons.people, label: '角色', accentColor: colors.primary, selected: false, onTap: () => _showPersonDialog(context)),
                    _IconRailItem(icon: Icons.label_outline, activeIcon: Icons.label, label: '标签', accentColor: colors.primary, selected: false, onTap: () => _showTagDialog(context)),
                    _IconRailItem(icon: Icons.auto_stories_outlined, activeIcon: Icons.auto_stories, label: 'EPUB', accentColor: colors.primary, selected: false, onTap: () => _push(context, const EpubLibraryPage())),
                    _IconRailItem(icon: Icons.backup_outlined, activeIcon: Icons.backup, label: '备份', accentColor: colors.primary, selected: false, onTap: () => _showBackupDialog(context)),
                    _IconRailItem(icon: Icons.delete_outline, activeIcon: Icons.delete, label: '回收', accentColor: colors.primary, selected: false, onTap: () => _showRecycleBinDialog(context)),
                    _IconRailItem(icon: Icons.feedback_outlined, activeIcon: Icons.feedback, label: '反馈', accentColor: colors.primary, selected: false, onTap: () => _showFeedbackDialog(context)),
                  ],
                ),
              ),
            ),
            // 设置（固定底部）
            _IconRailItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '设置', accentColor: colors.primary, selected: false, onTap: () => _push(context, const SettingsPage())),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();
    final avatarPath = userPrefs.avatarPath;
    final nickname = userPrefs.nickname;
    final motto = userPrefs.motto;
    return GestureDetector(
      onTap: () => _push(context, const SettingsPage()),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceContainerHighest,
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: avatarPath != null && avatarPath.isNotEmpty
                  ? FadeInLocalImage(path: avatarPath, fit: BoxFit.cover,
                      errorWidget: Icon(Icons.person_outline, size: 16, color: colors.onSurface.withValues(alpha: 0.3)))
                  : Icon(Icons.person_outline, size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(nickname, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(height: 1),
                  Text(motto, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showSearchDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dialogHeight = (MediaQuery.of(context).size.height * 0.82).clamp(560.0, 820.0);
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 640,
          height: dialogHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _SearchDialog(dialogContext: dialogCtx),
          ),
        ),
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = 'dellevin99@gmail.com';
    final qqGroup = '1087203310';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('BUG反馈', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _feedbackRow(ctx, Icons.email_outlined, '作者邮箱', email, colors),
              const SizedBox(height: 12),
              _feedbackRow(ctx, Icons.group_outlined, 'QQ 群', qqGroup, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedbackRow(BuildContext ctx, IconData icon, String title, String value, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 1),
                Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ToastUtil.show(ctx, '已复制');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('复制', style: TextStyle(fontSize: 12, color: colors.primary, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
  void _showBackupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _BackupChoiceDialog(),
    );
  }

  void _showEncounterDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _EncounterDialog());
  }

  void _showStrollDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _StrollDialog());
  }

  void _showCalendarDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _CalendarDialog());
  }

  void _showPersonDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _PersonListDialog(),
    );
  }

  void _showTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _TagManagementDialog(),
    );
  }

  void _showRecycleBinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _RecycleBinDialog(),
    );
  }
}

// ─── 统计弹窗 ──────────────────────────────────────────

class _EncounterDialog extends StatelessWidget {
  const _EncounterDialog();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();
    final firstUse = userPrefs.firstUseDate;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(firstUse.year, firstUse.month, firstUse.day))
        .inDays + 1;

    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: const Text('统计'),
      content: SizedBox(
        width: 420,
        height: 620,
        child: Consumer<AppProvider>(
          builder: (context, provider, child) {
            final movies = provider.movies.where((m) => !m.isDeleted).toList();
            final books = provider.books.where((b) => !b.isDeleted).toList();
            final notes = provider.notes.where((n) => !n.isDeleted).toList();

            final noteWords = notes.fold<int>(0, (sum, n) => sum + n.content.length);
            int imageCount = 0;
            for (final m in movies) { if (m.posterPath != null && m.posterPath!.isNotEmpty) imageCount++; }
            for (final b in books) { if (b.coverPath != null && b.coverPath!.isNotEmpty) imageCount++; }
            for (final n in notes) { imageCount += n.images.length; }
            final totalRecords = movies.length + books.length + notes.length;

            return Column(
              children: [
                // 相遇天数
                const SizedBox(height: 16),
                Text('与你', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: colors.onSurface, letterSpacing: 4)),
                const SizedBox(height: 8),
                RichText(text: TextSpan(children: [
                  TextSpan(text: '相遇的第', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: colors.onSurface.withValues(alpha: 0.5))),
                  TextSpan(text: '$days', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: colors.primary)),
                  TextSpan(text: '天', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: colors.onSurface.withValues(alpha: 0.5))),
                ]), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('${firstUse.year}年${firstUse.month}月${firstUse.day}日 — ${now.year}年${now.month}月${now.day}日',
                    style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                const Spacer(),
                Divider(color: colors.outlineVariant, thickness: 0.5),
                const SizedBox(height: 16),
                Text('已记录', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5), letterSpacing: 2)),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _recordItem(context, '$totalRecords', '条记录', colors),
                  _recordItem(context, _formatCount(noteWords), '文字', colors),
                  _recordItem(context, '$imageCount', '张图片', colors),
                ]),
                const SizedBox(height: 16),
                Divider(color: colors.outlineVariant, thickness: 0.5),
                const SizedBox(height: 16),
                // 城市天际线动画
                SizedBox(height: 52, child: _CityScape(colors: colors)),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }

  Widget _recordItem(BuildContext context, String value, String label, ColorScheme colors) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.primary)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
    ]);
  }
}

// ─── 城市天际线动画 ──────────────────────────────────────

class _CityScape extends StatefulWidget {
  final ColorScheme colors;
  const _CityScape({required this.colors});

  @override
  State<_CityScape> createState() => _CityScapeState();
}

class _CityScapeState extends State<_CityScape> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(size: const Size(double.infinity, 52), painter: _CityPainter(_controller.value, widget.colors)),
    );
  }
}

class _CityPainter extends CustomPainter {
  final double t;
  final ColorScheme colors;
  _CityPainter(this.t, this.colors);

  static const _buildings = <(double, double, bool)>[
    (0.30, 16, false), (0.48, 10, true), (0.22, 20, false), (0.55, 10, true),
    (0.35, 14, false), (0.42, 10, true), (0.25, 18, false),
  ];
  static const _plants = <(double, double, int)>[
    (0.35, 10, 0), (0.50, 8, 1), (0.22, 14, 2), (0.45, 8, 0),
    (0.30, 12, 1), (0.20, 10, 2), (0.52, 8, 1), (0.28, 14, 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final groundY = size.height - 2;
    _drawStars(canvas, paint, size, t);
    _drawBuildings(canvas, paint, size, groundY, t * 0.6);
    _drawPlants(canvas, paint, size, groundY, t * 1.0);
    paint.color = colors.onSurface.withValues(alpha: 0.10);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, 1), paint);
  }

  void _drawBuildings(Canvas canvas, Paint paint, Size size, double groundY, double scrollT) {
    double totalW = 0;
    for (final b in _buildings) { totalW += b.$2 + 4; }
    final offset = (scrollT * totalW) % totalW;
    double x = -offset;
    int i = 0;
    while (x < size.width + 20) {
      final (hR, w, spire) = _buildings[i % _buildings.length];
      final h = hR * (size.height - 8);
      final bx = x;
      final by = groundY - h;
      if (bx + w > -10 && bx < size.width + 10) {
        final a = 0.06 + hR * 0.05;
        paint.color = colors.onSurface.withValues(alpha: a);
        canvas.drawRect(Rect.fromLTWH(bx, by, w, h), paint);
        if (h > 18) {
          paint.color = colors.onSurface.withValues(alpha: 0.04);
          for (int r = 0; r < ((h - 6) / 5).floor(); r++) {
            for (int c = 0; c < ((w - 4) / 4).floor(); c++) {
              if ((i * 13 + r * 7 + c * 11) % 4 == 0) continue;
              canvas.drawRect(Rect.fromLTWH(bx + 3 + c * 4.0, by + 4 + r * 5.0, 2, 2), paint);
            }
          }
        }
        if (spire) {
          paint.color = colors.onSurface.withValues(alpha: a);
          final sh = h * 0.18;
          canvas.drawPath(Path()..moveTo(bx + w / 2 - 2, by)..lineTo(bx + w / 2, by - sh)..lineTo(bx + w / 2 + 2, by)..close(), paint);
        }
        if (!spire && hR > 0.4 && i % 3 == 0) {
          paint.color = colors.onSurface.withValues(alpha: a * 0.5);
          canvas.drawRect(Rect.fromLTWH(bx + w / 2 - 0.5, by - 6, 1, 6), paint);
          canvas.drawCircle(Offset(bx + w / 2, by - 6), 1.2, paint);
        }
      }
      x += w + 16;
      i++;
    }
  }

  void _drawPlants(Canvas canvas, Paint paint, Size size, double groundY, double scrollT) {
    double totalW = 0;
    for (final p in _plants) { totalW += p.$2 + 6; }
    final offset = (scrollT * totalW) % totalW;
    double x = -offset;
    int i = 0;
    while (x < size.width + 20) {
      final (hR, w, type) = _plants[i % _plants.length];
      final h = hR * (size.height - 10);
      final bx = x;
      final by = groundY;
      if (bx + w > -10 && bx < size.width + 10) {
        final alpha = 0.18 + hR * 0.10;
        if (type == 0) {
          final trunkH = h * 0.4;
          final crownR = w * 0.45;
          paint.color = colors.onSurface.withValues(alpha: alpha * 0.7);
          canvas.drawRect(Rect.fromLTWH(bx + w / 2 - 1.5, by - trunkH, 3, trunkH), paint);
          paint.color = colors.onSurface.withValues(alpha: alpha);
          canvas.drawOval(Rect.fromCenter(center: Offset(bx + w / 2, by - trunkH - crownR * 0.6), width: crownR * 2, height: crownR * 1.6), paint);
        } else if (type == 1) {
          final trunkH = h * 0.25;
          paint.color = colors.onSurface.withValues(alpha: alpha * 0.7);
          canvas.drawRect(Rect.fromLTWH(bx + w / 2 - 1.5, by - trunkH, 3, trunkH), paint);
          paint.color = colors.onSurface.withValues(alpha: alpha);
          for (int layer = 0; layer < 3; layer++) {
            final layerW = w * (1.0 - layer * 0.2);
            final layerBottom = by - trunkH - layer * (h * 0.2);
            final layerTop = layerBottom - h * 0.28;
            canvas.drawPath(Path()..moveTo(bx + w / 2 - layerW / 2, layerBottom)..lineTo(bx + w / 2, layerTop)..lineTo(bx + w / 2 + layerW / 2, layerBottom)..close(), paint);
          }
        } else {
          paint.color = colors.onSurface.withValues(alpha: alpha);
          canvas.drawOval(Rect.fromLTWH(bx, by - h, w, h), paint);
          paint.color = colors.onSurface.withValues(alpha: alpha * 0.8);
          canvas.drawOval(Rect.fromLTWH(bx + w * 0.2, by - h * 0.7, w * 0.6, h * 0.6), paint);
        }
      }
      x += w + 14;
      i++;
    }
  }

  void _drawStars(Canvas canvas, Paint paint, Size size, double t) {
    const stars = [
      (12.0, 5.0, 1.2), (38.0, 12.0, 0.8), (65.0, 3.0, 1.0),
      (95.0, 16.0, 1.4), (130.0, 7.0, 0.9), (165.0, 14.0, 1.1),
      (200.0, 4.0, 1.3), (235.0, 18.0, 0.7), (270.0, 9.0, 1.0),
      (310.0, 2.0, 1.2), (345.0, 15.0, 0.9), (380.0, 6.0, 1.1),
      (420.0, 11.0, 0.8), (460.0, 3.0, 1.0), (500.0, 17.0, 1.3),
    ];
    for (int i = 0; i < stars.length; i++) {
      final (sx, sy, r) = stars[i];
      if (sx > size.width) continue;
      final flicker = 0.15 + 0.12 * sin(t * 2 * pi + i * 1.1);
      paint.color = colors.onSurface.withValues(alpha: flicker);
      canvas.drawCircle(Offset(sx, sy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) => old.t != t;
}

// ─── 不拦截滑动手势的弹窗路由 ──────────────────────────────

class _NoSwipeDialogRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  _NoSwipeDialogRoute({required this.builder});

  @override
  bool get popGestureEnabled => false; // 关键：禁止拖拽关闭，不拦截水平手势

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return builder(context);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(opacity: animation, child: child);
  }

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;
}

// ─── 漫步弹窗 ──────────────────────────────────────────

class _StrollDialog extends StatefulWidget {
  const _StrollDialog();

  @override
  State<_StrollDialog> createState() => _StrollDialogState();
}

class _StrollDialogState extends State<_StrollDialog> {
  final _random = Random();
  final List<_StrollItem> _items = [];
  final Set<String> _seenIds = {};
  late PageController _pageController;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadBatch(5);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadBatch(int count) {
    final provider = context.read<AppProvider>();
    final moviePool = <_StrollItem>[];
    final bookPool = <_StrollItem>[];
    final notePool = <_StrollItem>[];
    if (_filter == 'all' || _filter == 'movie') {
      for (final m in provider.movies.where((m) => !m.isDeleted)) {
        moviePool.add(_StrollItem(type: 'movie', data: m, id: 'm_${m.id}', title: m.title,
          subtitle: m.alternateTitles.take(2).join(' / '), detail: _movieDetail(m), imagePath: m.posterPath,
          icon: Icons.movie_outlined, label: '影视', rating: m.rating, createdAt: m.createdAt,
          tags: m.genres.take(3).toList(), color: const Color(0xFF4A90D9)));
      }
    }
    if (_filter == 'all' || _filter == 'book') {
      for (final b in provider.books.where((b) => !b.isDeleted)) {
        bookPool.add(_StrollItem(type: 'book', data: b, id: 'b_${b.id}', title: b.title,
          subtitle: b.authors.take(2).join(' / '), detail: _bookDetail(b), imagePath: b.coverPath,
          icon: Icons.menu_book_outlined, label: '书籍', rating: b.rating, createdAt: b.createdAt,
          tags: b.genres.take(3).toList(), color: const Color(0xFF7E57C2)));
      }
    }
    if (_filter == 'all' || _filter == 'note') {
      for (final n in provider.notes.where((n) => !n.isDeleted)) {
        notePool.add(_StrollItem(type: 'note', data: n, id: 'n_${n.id}', title: n.title.isNotEmpty ? n.title : '随手记',
          subtitle: n.tags.take(3).join(' · '), detail: n.content, imagePath: n.images.isNotEmpty ? n.images.first : null,
          icon: Icons.note_outlined, label: '笔记', createdAt: n.createdAt,
          tags: n.tags.take(3).toList(), color: const Color(0xFF66BB6A)));
      }
    }
    final pools = <List<_StrollItem>>[];
    if (moviePool.isNotEmpty) pools.add(moviePool);
    if (bookPool.isNotEmpty) pools.add(bookPool);
    if (notePool.isNotEmpty) pools.add(notePool);
    if (pools.isEmpty) return;
    final target = _items.length + count;
    int attempts = 0;
    while (_items.length < target && attempts < count * 20) {
      attempts++;
      final pool = _filter == 'all' ? pools[_random.nextInt(pools.length)] : pools.first;
      final item = _weightedPick(pool);
      if (item != null && !_seenIds.contains(item.id)) { _seenIds.add(item.id); _items.add(item); }
    }
  }

  _StrollItem? _weightedPick(List<_StrollItem> pool) {
    if (pool.isEmpty) return null;
    final weights = pool.map((item) => (item.rating ?? 5.0).clamp(1.0, 10.0)).toList();
    final total = weights.reduce((a, b) => a + b);
    var roll = _random.nextDouble() * total;
    for (int i = 0; i < pool.length; i++) { roll -= weights[i]; if (roll <= 0) return pool[i]; }
    return pool.last;
  }

  void _reshuffle() { setState(() { _items.clear(); _seenIds.clear(); _loadBatch(5); }); }

  String _movieDetail(Movie m) {
    if (m.summary != null && m.summary!.isNotEmpty) return m.summary!.length > 100 ? '${m.summary!.substring(0, 100)}...' : m.summary!;
    return '';
  }

  String _bookDetail(Book b) {
    final parts = <String>[];
    if (b.publisher != null && b.publisher!.isNotEmpty) parts.add(b.publisher!);
    if (b.summary != null && b.summary!.isNotEmpty) parts.add(b.summary!.length > 100 ? '${b.summary!.substring(0, 100)}...' : b.summary!);
    return parts.join('\n');
  }

  String _timeAgoText(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}年前';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}个月前';
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    return '刚刚';
  }

  String _actionVerb(String type) {
    switch (type) {
      case 'movie': return '看过';
      case 'book': return '读过';
      case 'note': return '写下';
      default: return '';
    }
  }

  void _openDetail(_StrollItem item) {
    // 先 pop 弹窗，再 push 详情页
    final navigator = Navigator.of(context);
    navigator.pop();
    switch (item.type) {
      case 'movie': navigator.push(MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
      case 'book': navigator.push(MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
      case 'note': navigator.push(MaterialPageRoute(builder: (_) => NoteDetailPage(note: item.data as Note)));
    }
  }

  void _deleteItem(_StrollItem item) async {
    final provider = context.read<AppProvider>();
    switch (item.type) {
      case 'movie': await provider.removeMovie(item.data.id);
      case 'book': await provider.removeBook(item.data.id);
      case 'note': await provider.removeNote(item.data.id);
    }
    setState(() => _items.remove(item));
    if (mounted) ToastUtil.show(context, '已删除');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(children: [
        const Text('漫步'),
        const Spacer(),
        ...[('all', '全部'), ('movie', '影视'), ('book', '书籍'), ('note', '笔记')].map((f) => Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            onTap: () { if (_filter != f.$1) setState(() { _filter = f.$1; _items.clear(); _seenIds.clear(); _loadBatch(5); }); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _filter == f.$1 ? colors.primary : colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Text(f.$2, style: TextStyle(fontSize: 11, fontWeight: _filter == f.$1 ? FontWeight.w600 : FontWeight.normal,
                  color: _filter == f.$1 ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
            ),
          ),
        )),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _reshuffle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.casino_outlined, size: 13, color: colors.onPrimary),
              const SizedBox(width: 3),
              Text('随机', style: TextStyle(fontSize: 11, color: colors.onPrimary, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ]),
      content: SizedBox(
        width: 420,
        height: 620,
        child: _items.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.explore_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text('还没有内容', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
              ]))
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) { if (index >= _items.length - 2) setState(() => _loadBatch(3)); },
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    return _buildCard(_items[index], colors);
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildCard(_StrollItem item, ColorScheme colors) {
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;
    return GestureDetector(
      onTap: () => _openDetail(item),
      child: hasImage ? _buildImmersiveCard(item, colors) : _buildContentCard(item, colors),
    );
  }

  Widget _buildImmersiveCard(_StrollItem item, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))]),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        FadeInLocalImage(path: item.imagePath, fit: BoxFit.cover),
        Positioned.fill(child: Container(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.3, 0.7])))),
        Positioned(top: 12, left: 12, right: 12, child: _buildTopBadges(item)),
        Positioned(left: 16, right: 16, bottom: 16, child: _buildBottomContent(item, Colors.white)),
      ]),
    );
  }

  Widget _buildContentCard(_StrollItem item, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopBadges(item, textColor: colors.onSurface, bgColor: item.color.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          if (item.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 6, children: item.tags.take(3).map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: item.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text(tag, style: TextStyle(fontSize: 11, color: item.color)),
            )).toList())),
          Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface, height: 1.3)),
          if (item.subtitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
          ],
          if (item.detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Expanded(child: SingleChildScrollView(child: Text(item.detail, maxLines: 5, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.55), height: 1.6)))),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Text('${_timeAgoText(item.createdAt)} ${_actionVerb(item.type)}',
                style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
            const Spacer(),
            _actionBtn(Icons.visibility_outlined, '查看', () => _openDetail(item), colors: colors),
            const SizedBox(width: 6),
            _actionBtn(Icons.delete_outline, '删除', () => _showDeleteConfirm(item), colors: colors),
          ]),
        ],
      )),
    );
  }

  Widget _buildTopBadges(_StrollItem item, {Color? textColor, Color? bgColor}) {
    final fg = textColor ?? Colors.white;
    final bg = bgColor ?? Colors.black.withValues(alpha: 0.3);
    return Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(item.icon, size: 13, color: fg), const SizedBox(width: 3),
          Text(item.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ])),
      const Spacer(),
      if (item.rating != null) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star, size: 13, color: Color(0xFFFFB800)), const SizedBox(width: 2),
          Text(item.rating!.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ])),
    ]);
  }

  Widget _buildBottomContent(_StrollItem item, Color textColor) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (item.tags.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(spacing: 6, children: item.tags.take(3).map((tag) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5)),
          child: Text(tag, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
        )).toList())),
      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor, height: 1.3)),
      if (item.subtitle.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.6))),
      ],
      if (item.detail.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(item.detail, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.5), height: 1.5)),
      ],
      const SizedBox(height: 12),
      Row(children: [
        Text('${_timeAgoText(item.createdAt)} ${_actionVerb(item.type)}',
            style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.4))),
        const Spacer(),
        _actionBtn(Icons.visibility_outlined, '查看', () => _openDetail(item)),
        const SizedBox(width: 8),
        _actionBtn(Icons.delete_outline, '删除', () => _showDeleteConfirm(item)),
      ]),
    ]);
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {ColorScheme? colors}) {
    final fg = colors?.onSurface ?? Colors.white;
    final bg = colors != null ? colors.surfaceContainerHighest : Colors.white.withValues(alpha: 0.12);
    final border = colors != null ? colors.outlineVariant : Colors.white.withValues(alpha: 0.15);
    return GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border, width: 0.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: fg.withValues(alpha: 0.8)), const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8))),
        ])),
    );
  }

  void _showDeleteConfirm(_StrollItem item) {
    final colors = Theme.of(context).colorScheme;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
      content: Text('确定要删除"${item.title}"吗？删除后可在回收站恢复。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _deleteItem(item); },
          style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('删除')),
      ],
    ));
  }
}

class _StrollItem {
  final String type;
  final dynamic data;
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final String? imagePath;
  final IconData icon;
  final String label;
  final double? rating;
  final DateTime createdAt;
  final List<String> tags;
  final Color color;

  _StrollItem({required this.type, required this.data, required this.id, required this.title,
    required this.subtitle, required this.detail, this.imagePath, required this.icon,
    required this.label, this.rating, required this.createdAt, this.tags = const [], required this.color});
}

// ─── 书影日历弹窗 ──────────────────────────────────────────

class _CalendarDialog extends StatefulWidget {
  const _CalendarDialog();

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;
  late Map<DateTime, List<_CalendarItem>> _dayItems;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _buildDayMap();
  }

  void _buildDayMap() {
    final provider = context.read<AppProvider>();
    final map = <DateTime, List<_CalendarItem>>{};
    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      if (m.posterPath == null || m.posterPath!.isEmpty) continue;
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      map.putIfAbsent(day, () => []).add(_CalendarItem(path: m.posterPath!, title: m.title, type: 'movie', data: m));
    }
    for (final b in provider.books.where((b) => !b.isDeleted)) {
      if (b.coverPath == null || b.coverPath!.isEmpty) continue;
      final day = DateTime(b.createdAt.year, b.createdAt.month, b.createdAt.day);
      map.putIfAbsent(day, () => []).add(_CalendarItem(path: b.coverPath!, title: b.title, type: 'book', data: b));
    }
    _dayItems = map;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(children: [
        const Text('书影日历'),
        const Spacer(),
        IconButton(onPressed: () => setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1); _selectedDay = null; }),
          icon: Icon(Icons.chevron_left, size: 20, color: colors.onSurface.withValues(alpha: 0.6)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        Text('${_currentMonth.year}.${_currentMonth.month.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
        IconButton(onPressed: () => setState(() { _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1); _selectedDay = null; }),
          icon: Icon(Icons.chevron_right, size: 20, color: colors.onSurface.withValues(alpha: 0.6)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
      content: SizedBox(
        width: 420,
        height: 620,
        child: Column(
          children: [
            // 星期头
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: ['一', '二', '三', '四', '五', '六', '日'].map((d) =>
                Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.35))))),
              ).toList())),
            // 日历网格
            _buildCalendarGrid(colors, today),
            // 选中日期详情
            if (_selectedDay != null) ...[
              Divider(height: 0.5, color: colors.outlineVariant),
              Expanded(child: _buildSelectedDayDetail(colors)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(ColorScheme colors, DateTime today) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startOffset = firstDay.weekday - 1;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(children: List.generate(rows, (row) => SizedBox(
        height: 52,
        child: Row(children: List.generate(7, (col) {
          final index = row * 7 + col;
          if (index < startOffset || index >= startOffset + totalDays) return const Expanded(child: SizedBox());
          final day = index - startOffset + 1;
          final date = DateTime(_currentMonth.year, _currentMonth.month, day);
          final isToday = date == today;
          final isSelected = _selectedDay == date;
          final items = _dayItems[date] ?? [];
          return Expanded(child: _buildDayCell(colors, date, day, isToday, isSelected, items));
        })),
      ))),
    );
  }

  Widget _buildDayCell(ColorScheme colors, DateTime date, int day, bool isToday, bool isSelected, List<_CalendarItem> items) {
    final hasItems = items.isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary.withValues(alpha: 0.08) : hasItems ? colors.surfaceContainerHigh : null,
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: colors.primary, width: 1.5) : isSelected ? Border.all(color: colors.primary.withValues(alpha: 0.3), width: 1) : null,
        ),
        child: hasItems
            ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Stack(fit: StackFit.expand, children: [
                Image(image: FileImage(File(items.first.path)), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest,
                    child: Icon(Icons.image_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)))),
                Positioned(left: 0, right: 0, bottom: 0,
                  child: Container(padding: const EdgeInsets.fromLTRB(3, 10, 3, 2),
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)])),
                    child: Text('$day', style: TextStyle(fontSize: 9, fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isToday ? const Color(0xFFFFD54F) : Colors.white)))),
                if (items.length > 1) Positioned(top: 2, right: 2,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                    child: Text('+${items.length - 1}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: Colors.white)))),
              ]))
            : Center(child: Text('$day', style: TextStyle(fontSize: 12,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                color: isToday ? colors.primary : colors.onSurface.withValues(alpha: 0.35)))),
      ),
    );
  }

  Widget _buildSelectedDayDetail(ColorScheme colors) {
    final items = _dayItems[_selectedDay] ?? [];
    if (items.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16),
        child: Text('${_selectedDay!.month}月${_selectedDay!.day}日  暂无记录',
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(children: [
          Text('${_selectedDay!.month}月${_selectedDay!.day}日', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(width: 6),
          Text('${items.length}条记录', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
        ])),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 0.5, color: colors.outlineVariant),
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 36, height: 36,
                child: Image(image: FileImage(File(item.path)), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest,
                    child: Icon(Icons.image_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2)))))),
            title: Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: item.type == 'movie' ? const Color(0xFF4A90D9).withValues(alpha: 0.1) : const Color(0xFF7E57C2).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4)),
              child: Text(item.type == 'movie' ? '影视' : '书籍',
                style: TextStyle(fontSize: 10, color: item.type == 'movie' ? const Color(0xFF4A90D9) : const Color(0xFF7E57C2)))),
            onTap: () {
              final nav = Navigator.of(context);
              nav.pop();
              if (item.type == 'movie') {
                nav.push(MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
              } else {
                nav.push(MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
              }
            },
          );
        },
      )),
    ]);
  }
}

class _CalendarItem {
  final String path;
  final String title;
  final String type;
  final dynamic data;
  _CalendarItem({required this.path, required this.title, required this.type, required this.data});
}

// ─── 角色信息弹窗 ──────────────────────────────────────────

class _PersonListDialog extends StatefulWidget {
  const _PersonListDialog();

  @override
  State<_PersonListDialog> createState() => _PersonListDialogState();
}

class _PersonListDialogState extends State<_PersonListDialog> {
  String _filter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _loading = false;
  _PersonEntry? _selectedPerson;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    await Future.wait([provider.loadMovies(), provider.loadBooks()]);
    if (mounted) setState(() => _loading = false);
  }

  List<_PersonEntry> _buildPersons() {
    final provider = context.read<AppProvider>();
    final map = <String, _PersonEntry>{};

    void addRole(String name, String role, {Movie? movie, Book? book}) {
      if (name.trim().isEmpty) return;
      final key = name.trim();
      map.putIfAbsent(key, () => _PersonEntry(name: key));
      map[key]!.roles.add(role);
      if (movie != null && !map[key]!.movies.any((m) => m.id == movie.id)) map[key]!.movies.add(movie);
      if (book != null && !map[key]!.books.any((b) => b.id == book.id)) map[key]!.books.add(book);
    }

    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      for (final d in m.directors) addRole(d, '导演', movie: m);
      for (final w in m.writers) addRole(w, '编剧', movie: m);
      for (final a in m.actors) addRole(a, '主演', movie: m);
    }
    for (final b in provider.books.where((b) => !b.isDeleted)) {
      for (final a in b.authors) addRole(a, '作者', book: b);
      for (final t in b.translators) addRole(t, '译者', book: b);
    }

    var list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allPersons = _buildPersons();

    var filtered = allPersons.where((p) {
      if (_filter != 'all' && !p.roles.contains(_filter)) return false;
      if (_searchQuery.isNotEmpty && !p.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(children: [
        const Text('角色信息'),
        const Spacer(),
        if (_loading)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
        else
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _refresh, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
      content: SizedBox(
        width: 420,
        height: 620,
        child: _selectedPerson != null
            ? _buildPersonDetail(_selectedPerson!, colors)
            : Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(19)),
                child: Row(children: [
                  const SizedBox(width: 14),
                  Icon(Icons.search, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      hintText: '搜索导演、编剧、演员、作者、译者',
                      hintStyle: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  )),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); FocusManager.instance.primaryFocus?.unfocus(); },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle),
                        child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                ]),
              ),
            ),
            // 角色筛选
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(children: [
                for (final f in ['all', '导演', '编剧', '主演', '作者', '译者'])
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _filter == f ? colors.primary : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(f == 'all' ? '全部' : f,
                            style: TextStyle(fontSize: 11, fontWeight: _filter == f ? FontWeight.w600 : FontWeight.normal,
                                color: _filter == f ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
                      ),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('共 ${filtered.length} 人', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)))),
            ),
            // 列表
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text('暂无数据', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 0.5, color: colors.outlineVariant),
                      itemBuilder: (_, i) => _buildPersonTile(filtered[i], colors),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonTile(_PersonEntry person, ColorScheme colors) {
    final roleColors = {
      '导演': const Color(0xFF4A90D9),
      '编剧': const Color(0xFF009688),
      '主演': const Color(0xFFE91E63),
      '作者': const Color(0xFF7E57C2),
      '译者': const Color(0xFFFF7043),
    };
    final totalWorks = person.movies.length + person.books.length;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: colors.surfaceContainerHighest,
        child: Text(person.name.isNotEmpty ? person.name[0] : '?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
      ),
      title: Text(person.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(spacing: 4, runSpacing: 3, children: [
          for (final role in person.roles.toSet())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: (roleColors[role] ?? colors.outline).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
              child: Text(role, style: TextStyle(fontSize: 9, color: roleColors[role] ?? colors.onSurface)),
            ),
          Text('$totalWorks 部作品', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.35))),
        ]),
      ),
      trailing: Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.25)),
      onTap: () => setState(() => _selectedPerson = person),
    );
  }

  Widget _buildPersonDetail(_PersonEntry person, ColorScheme colors) {
    final roleColors = {
      '导演': const Color(0xFF4A90D9),
      '编剧': const Color(0xFF009688),
      '主演': const Color(0xFFE91E63),
      '作者': const Color(0xFF7E57C2),
      '译者': const Color(0xFFFF7043),
    };

    final movieItems = <_WorkItem>[];
    final bookItems = <_WorkItem>[];

    for (final m in person.movies) {
      final roles = <String>[];
      if (m.directors.contains(person.name)) roles.add('导演');
      if (m.writers.contains(person.name)) roles.add('编剧');
      if (m.actors.contains(person.name)) roles.add('主演');
      movieItems.add(_WorkItem(title: m.title, roles: roles, path: m.posterPath, data: m));
    }
    for (final b in person.books) {
      final roles = <String>[];
      if (b.authors.contains(person.name)) roles.add('作者');
      if (b.translators.contains(person.name)) roles.add('译者');
      bookItems.add(_WorkItem(title: b.title, roles: roles, path: b.coverPath, data: b));
    }

    return Column(
      children: [
        // 返回按钮 + 标题
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => setState(() => _selectedPerson = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Text(person.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final role in person.roles.toSet())
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: (roleColors[role] ?? colors.outline).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: roleColors[role] ?? colors.onSurface)),
                  ),
              ]),
              const SizedBox(height: 20),
              if (movieItems.isNotEmpty) ...[
                Text('影视作品（${movieItems.length}）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                for (final item in movieItems) _buildWorkTile(item, colors, isMovie: true),
                const SizedBox(height: 16),
              ],
              if (bookItems.isNotEmpty) ...[
                Text('书籍作品（${bookItems.length}）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                for (final item in bookItems) _buildWorkTile(item, colors, isMovie: false),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkTile(_WorkItem item, ColorScheme colors, {required bool isMovie}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (isMovie) {
            Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
          } else {
            Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(10), border: Border.all(color: colors.outlineVariant, width: 0.5)),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(width: 44, height: 44,
                child: item.path != null && item.path!.isNotEmpty
                    ? FadeInLocalImage(path: item.path!, fit: BoxFit.cover,
                        errorWidget: Container(color: colors.surfaceContainerHighest, child: Icon(Icons.image_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.2))))
                    : Container(color: colors.surfaceContainerHighest,
                        child: Icon(isMovie ? Icons.movie_outlined : Icons.menu_book_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.3))),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(item.roles.join(' · '), style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            ])),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
          ]),
        ),
      ),
    );
  }
}

class _PersonEntry {
  final String name;
  final Set<String> roles = {};
  final List<Movie> movies = [];
  final List<Book> books = [];
  _PersonEntry({required this.name});
}

class _WorkItem {
  final String title;
  final List<String> roles;
  final String? path;
  final dynamic data;
  _WorkItem({required this.title, required this.roles, this.path, required this.data});
}

// ─── 标签管理弹窗 ──────────────────────────────────────────

class _TagManagementDialog extends StatefulWidget {
  const _TagManagementDialog();

  @override
  State<_TagManagementDialog> createState() => _TagManagementDialogState();
}

class _TagManagementDialogState extends State<_TagManagementDialog> {
  int _currentIndex = 0;
  bool _isSyncing = false;

  static const _tabTypes = ['movie_genre', 'book_genre', 'note_tag', 'game_genre'];
  static const _typeLabels = ['影视类型', '书籍类型', '笔记标签', '游戏类型'];
  static const _typeIcons = [Icons.movie_outlined, Icons.menu_book_outlined, Icons.note_outlined, Icons.sports_esports_outlined];

  final Map<String, List<Map<String, dynamic>>> _tagCache = {};
  Map<String, int> _usageCounts = {};
  String? _newlyAddedTagId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTags(_tabTypes[0]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateUsageCounts();
  }

  void _updateUsageCounts() {
    final provider = context.read<AppProvider>();
    final counts = <String, int>{};
    for (final m in provider.movies.where((m) => !m.isDeleted)) { for (final g in m.genres) counts[g] = (counts[g] ?? 0) + 1; }
    for (final b in provider.books.where((b) => !b.isDeleted)) { for (final g in b.genres) counts[g] = (counts[g] ?? 0) + 1; }
    for (final n in provider.notes.where((n) => !n.isDeleted)) { for (final t in n.tags) counts[t] = (counts[t] ?? 0) + 1; }
    for (final g in provider.games.where((g) => !g.isDeleted)) { for (final genre in g.genres) counts[genre] = (counts[genre] ?? 0) + 1; }
    _usageCounts = counts;
  }

  Future<void> _loadTags(String type) async {
    final provider = context.read<AppProvider>();
    final tags = await provider.getTags(type);
    if (mounted) setState(() => _tagCache[type] = tags);
  }

  Future<void> _syncTags() async {
    setState(() => _isSyncing = true);
    try {
      final provider = context.read<AppProvider>();
      final count = await provider.syncTagsFromData();
      if (mounted) {
        ToastUtil.show(context, count > 0 ? '已同步 $count 个新标签' : '标签已是最新');
        await _loadTags(_currentType);
        _updateUsageCounts();
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String get _currentType => _tabTypes[_currentIndex];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(children: [
        const Text('标签管理'),
        const Spacer(),
        // Tab 切换
        Container(
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            for (int i = 0; i < _tabTypes.length; i++)
              _tabButton(colors, _typeLabels[i], i),
          ]),
        ),
        const SizedBox(width: 4),
        if (_isSyncing)
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
        else
          IconButton(icon: const Icon(Icons.sync, size: 20), tooltip: '从数据中同步标签', onPressed: _syncTags, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
      ]),
      content: SizedBox(
        width: 420,
        height: 620,
        child: Column(
          children: [
            // 搜索栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.outlineVariant, width: 0.5)),
                child: Row(children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search_rounded, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      hintText: '搜索标签...',
                      hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  )),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); FocusManager.instance.primaryFocus?.unfocus(); },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: colors.surfaceContainerHighest, shape: BoxShape.circle),
                        child: Icon(Icons.close_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ]),
              ),
            ),
            // 标签列表
            Expanded(child: _buildTagList(_currentType)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        ElevatedButton(
          onPressed: _showAddDialog,
          style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          child: Text('添加${_typeLabels[_currentIndex]}', style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _tabButton(ColorScheme colors, String label, int index) {
    final active = _currentIndex == index;
    return GestureDetector(
      onTap: () { setState(() => _currentIndex = index); _loadTags(_tabTypes[index]); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: active ? colors.primary : Colors.transparent, borderRadius: BorderRadius.circular(6)),
        child: Text(label.replaceAll('类型', '').replaceAll('标签', ''),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _buildTagList(String type) {
    final tags = _tagCache[type] ?? [];
    final colors = Theme.of(context).colorScheme;
    final isSearching = _searchQuery.isNotEmpty;

    if (tags.isEmpty && !isSearching) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_typeIcons[_currentIndex], size: 28, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          Text('暂无${_typeLabels[_currentIndex]}', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
        ]),
      );
    }

    if (isSearching) {
      final filtered = tags.where((t) => (t['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList()
        ..sort((a, b) => (_usageCounts[b['name']] ?? 0).compareTo(_usageCounts[a['name']] ?? 0));
      if (filtered.isEmpty) {
        return Center(child: Text('没有找到"$_searchQuery"相关标签', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))));
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Wrap(spacing: 8, runSpacing: 6, children: filtered.map(_buildTagChip).toList()),
      );
    }

    // 分组模式
    final used = <Map<String, dynamic>>[];
    final unused = <Map<String, dynamic>>[];
    final hidden = <Map<String, dynamic>>[];
    for (final t in tags) {
      if ((t['is_hidden'] as int?) == 1) { hidden.add(t); continue; }
      if ((_usageCounts[t['name']] ?? 0) > 0) { used.add(t); continue; }
      unused.add(t);
    }
    used.sort((a, b) => (_usageCounts[b['name']] ?? 0).compareTo(_usageCounts[a['name']] ?? 0));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 统计
        Row(children: [
          _statChip(Icons.check_circle_outline, '已使用', used.length, colors),
          const SizedBox(width: 8),
          _statChip(Icons.radio_button_unchecked, '未使用', unused.length, colors),
          const SizedBox(width: 8),
          _statChip(Icons.visibility_off_outlined, '隐藏', hidden.length, colors),
        ]),
        const SizedBox(height: 10),
        _groupHeader('已使用', used.length, colors),
        const SizedBox(height: 4),
        used.isNotEmpty ? Wrap(spacing: 8, runSpacing: 6, children: used.map(_buildTagChip).toList()) : _emptyGroup('暂无', colors),
        const SizedBox(height: 12),
        _groupHeader('未使用', unused.length, colors),
        const SizedBox(height: 4),
        unused.isNotEmpty ? Wrap(spacing: 8, runSpacing: 6, children: unused.map(_buildTagChip).toList()) : _emptyGroup('暂无', colors),
        const SizedBox(height: 12),
        _groupHeader('隐藏', hidden.length, colors),
        const SizedBox(height: 4),
        hidden.isNotEmpty ? Wrap(spacing: 8, runSpacing: 6, children: hidden.map(_buildTagChip).toList()) : _emptyGroup('暂无', colors),
      ]),
    );
  }

  Widget _statChip(IconData icon, String label, int count, ColorScheme colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 12, color: colors.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface)),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }

  Widget _groupHeader(String label, int count, ColorScheme colors) {
    return Row(children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
      const SizedBox(width: 4),
      Text('$count', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
    ]);
  }

  Widget _emptyGroup(String text, ColorScheme colors) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(text, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))));
  }

  Widget _buildTagChip(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final name = tag['name'] as String;
    final count = _usageCounts[name] ?? 0;
    final tagId = tag['id'] as String;
    final isNew = tagId == _newlyAddedTagId;
    final isHidden = (tag['is_hidden'] as int?) == 1;

    return GestureDetector(
      onTap: () => _showTagMenu(tag),
      onLongPress: () => _showTagMenu(tag),
      child: Opacity(
        opacity: isHidden ? 0.4 : 1.0,
        child: isNew
            ? _NewTagHighlight(child: _tagChipContent(name, count, colors, isHidden: isHidden))
            : _tagChipContent(name, count, colors, isHidden: isHidden),
      ),
    );
  }

  Widget _tagChipContent(String name, int count, ColorScheme colors, {bool isHidden = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface, decoration: isHidden ? TextDecoration.lineThrough : null)),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ]),
    );
  }

  void _showTagMenu(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final name = tag['name'] as String;
    final isHidden = (tag['is_hidden'] as int?) == 1;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)))),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface))),
                if (isHidden) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(4)),
                  child: Text('已隐藏', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            _menuAction(isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined, isHidden ? '取消隐藏' : '隐藏', colors, () async {
              Navigator.pop(ctx);
              await context.read<AppProvider>().toggleTagHidden(tag['id'] as String);
              await _loadTags(_currentType);
            }),
            _menuAction(Icons.open_in_new_outlined, '查看相关${_typeLabels[_currentIndex].replaceAll('类型', '').replaceAll('标签', '')}', colors, () {
              Navigator.pop(ctx);
              _showTagItems(name);
            }),
            _menuAction(Icons.edit_outlined, '重命名', colors, () { Navigator.pop(ctx); _showRenameDialog(tag); }),
            _menuAction(Icons.delete_outline, '删除', colors, () { Navigator.pop(ctx); _showDeleteDialog(tag); }, isDestructive: true),
          ]),
        ),
      ),
    );
  }

  Widget _menuAction(IconData icon, String title, ColorScheme colors, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 20, color: isDestructive ? const Color(0xFFE53935) : colors.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 14),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDestructive ? const Color(0xFFE53935) : colors.onSurface)),
        ]),
      ),
    );
  }

  void _showTagItems(String tagName) {
    final provider = context.read<AppProvider>();
    final colors = Theme.of(context).colorScheme;
    List<({String title, String? subtitle, String type})> items = [];
    if (_currentType == 'movie_genre') {
      for (final m in provider.movies.where((m) => !m.isDeleted && m.genres.contains(tagName))) items.add((title: m.title, subtitle: m.directors.take(2).join(' / '), type: '影视'));
    } else if (_currentType == 'book_genre') {
      for (final b in provider.books.where((b) => !b.isDeleted && b.genres.contains(tagName))) items.add((title: b.title, subtitle: b.authors.take(2).join(' / '), type: '书籍'));
    } else if (_currentType == 'game_genre') {
      for (final g in provider.games.where((g) => !g.isDeleted && g.genres.contains(tagName))) items.add((title: g.title, subtitle: g.platforms.take(2).join(' / '), type: '游戏'));
    } else {
      for (final n in provider.notes.where((n) => !n.isDeleted && n.tags.contains(tagName))) items.add((title: n.title.isNotEmpty ? n.title : '随手记', subtitle: null, type: '笔记'));
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 24), children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('$tagName（${items.length}）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('暂无相关内容', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))))
          else
            ...items.asMap().entries.map((entry) {
              final item = entry.value;
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (entry.key > 0) Divider(height: 0.5, color: colors.outlineVariant),
                ListTile(contentPadding: EdgeInsets.zero, title: Text(item.title, style: TextStyle(fontSize: 14, color: colors.onSurface)),
                  subtitle: item.subtitle != null && item.subtitle!.isNotEmpty ? Text(item.subtitle!, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))) : null,
                  trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                    child: Text(item.type, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5)))),
                ),
              ]));
            }),
        ]),
      ),
    );
  }

  void _showAddDialog() {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final type = _currentType;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('添加${_typeLabels[_currentIndex]}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true, style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入标签名称', hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            filled: true, fillColor: colors.surfaceContainerHigh, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
          onSubmitted: (value) => _doAddTag(ctx, controller.text.trim(), type),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          ElevatedButton(onPressed: () => _doAddTag(ctx, controller.text.trim(), type),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('添加')),
        ],
      ),
    );
  }

  Future<void> _doAddTag(BuildContext ctx, String name, String type) async {
    if (name.isEmpty) return;
    try {
      final provider = context.read<AppProvider>();
      final newId = await provider.addTag(name, type);
      if (!mounted) return;
      if (ctx.mounted) { Navigator.pop(ctx); ToastUtil.show(context, '添加成功'); }
      setState(() => _newlyAddedTagId = newId);
      Timer(const Duration(milliseconds: 1500), () { if (mounted) setState(() => _newlyAddedTagId = null); });
      await _loadTags(type);
    } catch (e) {
      if (ctx.mounted) ToastUtil.show(ctx, '添加失败：该标签已存在');
    }
  }

  void _showRenameDialog(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: tag['name'] as String);
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final oldName = tag['name'] as String;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重命名标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true, style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入新名称', hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            filled: true, fillColor: colors.surfaceContainerHigh, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
          onSubmitted: (value) => _doRenameTag(ctx, tagId, value.trim(), type, oldName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          ElevatedButton(onPressed: () => _doRenameTag(ctx, tagId, controller.text.trim(), type, oldName),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _doRenameTag(BuildContext ctx, String tagId, String newName, String type, String oldName) async {
    if (newName.isEmpty || newName == oldName) { if (ctx.mounted) Navigator.pop(ctx); return; }
    final success = await context.read<AppProvider>().renameTag(tagId, newName, type);
    if (ctx.mounted) { Navigator.pop(ctx); ToastUtil.show(context, success ? '重命名成功' : '重命名失败：标签名已存在'); }
    if (success) await _loadTags(type);
  }

  void _showDeleteDialog(Map<String, dynamic> tag) {
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final name = tag['name'] as String;
    String? selectedAction = 'deleteOnly';
    String? selectedReplacement;
    bool showAdvanced = false;
    final otherTags = (_tagCache[type] ?? []).where((t) => t['id'] != tagId).map((t) => t['name'] as String).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        final bc = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: bc.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: bc.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
              child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: bc.onSurface.withValues(alpha: 0.6)))),
            const SizedBox(width: 10),
            Text('删除标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: bc.onSurface)),
          ]),
          content: SizedBox(width: double.maxFinite, child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 4),
              _buildDeleteOption(value: 'deleteOnly', groupValue: selectedAction, onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                title: '仅删除标签', subtitle: '保留已有条目上的标签名，不影响数据', colors: bc),
              const SizedBox(height: 8),
              GestureDetector(onTap: () => setDialogState(() => showAdvanced = !showAdvanced),
                child: Row(children: [Text('更多选项', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: bc.primary)),
                  Icon(showAdvanced ? Icons.expand_less : Icons.expand_more, size: 16, color: bc.primary)])),
              if (showAdvanced) ...[
                const SizedBox(height: 10),
                _buildDeleteOption(value: 'remove', groupValue: selectedAction, onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                  title: '从所有条目中移除', subtitle: '彻底清除该标签在所有条目中的记录', colors: bc),
                const SizedBox(height: 4),
                _buildDeleteOption(value: 'replace', groupValue: selectedAction, onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                  title: '替换为其他标签', subtitle: '选择一个已有标签替代', colors: bc),
                if (selectedAction == 'replace')
                  Padding(padding: const EdgeInsets.only(left: 40, top: 10),
                    child: otherTags.isNotEmpty
                      ? Wrap(spacing: 8, runSpacing: 8, children: otherTags.map((t) {
                          final isSelected = selectedReplacement == t;
                          return GestureDetector(onTap: () => setDialogState(() => selectedReplacement = isSelected ? null : t),
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: isSelected ? bc.primary : bc.surfaceContainerHighest, borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? bc.primary : bc.outlineVariant, width: 0.5)),
                              child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? bc.onPrimary : bc.onSurface.withValues(alpha: 0.7)))));
                        }).toList())
                      : Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: bc.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                          child: Text('无其他标签可替换', style: TextStyle(fontSize: 13, color: bc.onSurface.withValues(alpha: 0.35)))),
                  ),
              ],
            ])),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: bc.onSurface.withValues(alpha: 0.4)))),
            ElevatedButton(onPressed: () {
              if (selectedAction == 'replace' && (selectedReplacement == null || selectedReplacement!.isEmpty)) return;
              Navigator.pop(ctx, {'action': selectedAction, 'replacement': selectedReplacement});
            }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('删除')),
          ],
        );
      }),
    ).then((result) async {
      if (result == null) return;
      final action = result['action'] as String;
      final replacement = result['replacement'] as String?;
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (action == 'deleteOnly') { await provider.deleteTagOnly(tagId, type); }
      else { await provider.deleteTag(tagId, type, replacementName: replacement); }
      if (!mounted) return;
      ToastUtil.show(context, '删除成功');
      await _loadTags(type);
    });
  }

  Widget _buildDeleteOption({required String value, required String? groupValue, required ValueChanged<String?> onChanged,
      required String title, String? subtitle, required ColorScheme colors}) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: selected ? colors.surfaceContainerHigh : colors.surface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 1 : 0.5)),
        child: Row(children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.25), width: selected ? 5 : 1.5))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w500 : FontWeight.normal, color: selected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.6))),
            if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)))),
          ])),
        ]),
      ),
    );
  }
}

// ─── 新标签高亮动画 ──────────────────────────────────────────

class _NewTagHighlight extends StatefulWidget {
  final Widget child;
  const _NewTagHighlight({required this.child});

  @override
  State<_NewTagHighlight> createState() => _NewTagHighlightState();
}

class _NewTagHighlightState extends State<_NewTagHighlight> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _controller.value < 0.3
            ? (_controller.value / 0.3).clamp(0.0, 1.0)
            : (1.0 - (_controller.value - 0.3) / 0.7).clamp(0.0, 1.0);
        final scale = 1.0 + 0.06 * (1.0 - _controller.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: colors.primary.withValues(alpha: 0.12 * opacity),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3 * opacity), width: 1),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

// ─── 备份选择弹窗 ──────────────────────────────────────────

class _BackupChoiceDialog extends StatefulWidget {
  const _BackupChoiceDialog();

  @override
  State<_BackupChoiceDialog> createState() => _BackupChoiceDialogState();
}

class _BackupChoiceDialogState extends State<_BackupChoiceDialog> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(children: [
        const Text('备份'),
        const Spacer(),
        // Tab 切换
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            _tabButton(colors, '本地备份', 0),
            _tabButton(colors, 'WebDAV', 1),
          ]),
        ),
      ]),
      content: SizedBox(
        width: 420,
        height: 620,
        child: _tabIndex == 0
            ? const _LocalBackupContent()
            : const _WebDAVBackupContent(),
      ),
    );
  }

  Widget _tabButton(ColorScheme colors, String label, int index) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ─── 本地备份内容（嵌入弹窗） ──────────────────────────────

class _LocalBackupContent extends StatefulWidget {
  const _LocalBackupContent();

  @override
  State<_LocalBackupContent> createState() => _LocalBackupContentState();
}

class _LocalBackupContentState extends State<_LocalBackupContent> {
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      children: [
        _buildActionCard(
          colors: colors,
          title: '导出数据',
          description: '将所有数据导出为 zip 文件，可用于备份或迁移到其他设备',
          icon: Icons.upload_outlined,
          buttonText: '导出',
          isLoading: _isExporting,
          onTap: _exportData,
        ),
        const SizedBox(height: 8),
        _buildActionCard(
          colors: colors,
          title: '导入数据',
          description: '从备份文件导入数据，将覆盖当前所有数据',
          icon: Icons.download_outlined,
          buttonText: '导入',
          isLoading: _isImporting,
          onTap: _importData,
          isDestructive: true,
        ),
        const SizedBox(height: 20),
        _buildInfoSection(colors),
      ],
    );
  }

  Widget _buildActionCard({
    required ColorScheme colors,
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required bool isLoading,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: isDestructive ? Colors.red : colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 1),
                Text(description, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4), height: 1.3)),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: isLoading ? null : onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isLoading ? colors.onSurface.withValues(alpha: 0.25) : colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isLoading
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(colors.onPrimary)))
                    : Text(buttonText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onPrimary)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.info_outline, size: 18, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(width: 10),
            Text('使用说明', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
          ]),
          const SizedBox(height: 12),
          _infoItem(colors, '导出数据会生成一个 .zip 文件，包含所有数据和图片'),
          const SizedBox(height: 8),
          _infoItem(colors, '选择保存路径后，可以通过微信、邮件等方式发送备份文件'),
          const SizedBox(height: 8),
          _infoItem(colors, '在新设备上选择导入数据，选择备份文件即可恢复'),
          const SizedBox(height: 8),
          _infoItem(colors, '导入数据会完全覆盖当前设备的数据，请谨慎操作'),
        ],
      ),
    );
  }

  Widget _infoItem(ColorScheme colors, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(top: 8), child: Icon(Icons.circle, size: 4, color: colors.onSurface.withValues(alpha: 0.25))),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5))),
      ],
    );
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final result = await BackupService.instance.exportDataWithImages();
      if (!mounted) return;
      if (result.cancelled) {
        ToastUtil.show(context, '已取消导出');
      } else if (result.success) {
        ToastUtil.show(context,'导出成功');
      } else {
        ToastUtil.show(context,result.errorMessage ?? '导出失败');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context,'导出失败: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22)),
            const SizedBox(width: 12),
            Text('确认导入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ]),
          content: Padding(padding: const EdgeInsets.only(top: 16),
            child: Text('导入数据将覆盖当前所有数据，此操作不可恢复。',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('确认导入', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _isImporting = true);
    try {
      final result = await BackupService.instance.importData();
      if (!mounted) return;
      if (result.cancelled) {
        ToastUtil.show(context,'已取消导入');
      } else if (result.success) {
        await context.read<AppProvider>().loadMovies();
        await context.read<AppProvider>().loadBooks();
        await context.read<AppProvider>().loadNotes();
        await context.read<AppProvider>().loadGames();
        if (!mounted) return;
        ToastUtil.show(context,'导入成功');
      } else {
        ToastUtil.show(context,result.errorMessage ?? '导入失败');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context,'导入失败: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }
}

// ─── WebDAV 备份内容（嵌入弹窗） ──────────────────────────

class _WebDAVBackupContent extends StatefulWidget {
  const _WebDAVBackupContent();

  @override
  State<_WebDAVBackupContent> createState() => _WebDAVBackupContentState();
}

class _WebDAVBackupContentState extends State<_WebDAVBackupContent> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pathController = TextEditingController(text: '/mooknote');

  bool _isLoading = false;
  bool _isConfigured = false;
  bool _obscurePassword = true;
  String _syncStep = '';

  DateTime? _remoteModifiedTime;
  int? _remoteFileSize;
  bool _isLoadingRemoteInfo = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await WebDAVService.instance.getConfig();
    if (config != null) {
      setState(() {
        _urlController.text = config['url'] ?? '';
        _usernameController.text = config['username'] ?? '';
        _passwordController.text = config['password'] ?? '';
        _pathController.text = config['path'] ?? '/mooknote';
        _isConfigured = true;
      });
      _loadRemoteInfo();
    }
  }

  Future<void> _loadRemoteInfo() async {
    setState(() => _isLoadingRemoteInfo = true);
    final info = await WebDAVService.instance.getRemoteBackupInfo();
    if (mounted) {
      setState(() {
        _remoteModifiedTime = info?['modifiedTime'] as DateTime?;
        _remoteFileSize = info?['size'] as int?;
        _isLoadingRemoteInfo = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    final url = _urlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final path = _pathController.text.trim();

    if (url.isEmpty) { ToastUtil.show(context,'请输入服务器地址'); return; }
    if (username.isEmpty) { ToastUtil.show(context,'请输入用户名'); return; }
    if (password.isEmpty) { ToastUtil.show(context,'请输入密码'); return; }

    setState(() => _isLoading = true);
    try {
      final result = await WebDAVService.instance.testConnection(url: url, username: username, password: password, path: path);
      if (!mounted) return;
      if (result['success'] == true) {
        await WebDAVService.instance.saveConfig(url: url, username: username, password: password, path: path);
        setState(() => _isConfigured = true);
        _loadRemoteInfo();
        ToastUtil.show(context,result['message'] ?? '连接成功，配置已保存');
      } else {
        ToastUtil.show(context,result['message'] ?? '连接失败，请检查配置');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context,'连接失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData(SyncDirection direction) async {
    setState(() => _isLoading = true);
    try {
      SyncResult result;
      if (direction == SyncDirection.upload) {
        setState(() => _syncStep = '正在打包数据...');
        await Future.delayed(Duration.zero);
        final exportResult = await WebDAVService.instance.exportLocalData();
        if (!exportResult.success || exportResult.zipPath == null) {
          if (mounted) { setState(() { _isLoading = false; _syncStep = ''; }); ToastUtil.show(context,exportResult.errorMessage ?? '创建备份失败'); }
          return;
        }
        if (!mounted) return;
        setState(() => _syncStep = '正在上传到云端...');
        await Future.delayed(Duration.zero);
        result = await WebDAVService.instance.uploadExportedData(exportResult);
      } else {
        setState(() => _syncStep = '正在从云端下载...');
        await Future.delayed(Duration.zero);
        result = await WebDAVService.instance.syncData(direction: SyncDirection.download);
      }

      if (!mounted) return;
      if (result.success) {
        _loadRemoteInfo();
        if (result.needReload) {
          final provider = context.read<AppProvider>();
          await provider.loadMovies();
          await provider.loadBooks();
          await provider.loadNotes();
          await provider.loadGames();
        }
        ToastUtil.show(context,'同步成功');
      } else {
        ToastUtil.show(context,result.message);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context,'同步失败: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; _syncStep = ''; });
    }
  }

  Future<void> _confirmSync(SyncDirection direction) async {
    final isUpload = direction == SyncDirection.upload;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(isUpload ? '确认上传' : '确认下载', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text(isUpload ? '该操作会覆盖远程数据，请谨慎操作' : '该操作会拉取远程数据覆盖本地数据，请谨慎操作',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('确定')),
          ],
        );
      },
    );
    if (confirmed == true) _syncData(direction);
  }

  Future<void> _clearConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22)),
            const SizedBox(width: 12),
            Text('清除配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ]),
          content: Padding(padding: const EdgeInsets.only(top: 16),
            child: Text('确定要清除 WebDAV 配置吗？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('清除', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        );
      },
    );
    if (confirmed == true) {
      await WebDAVService.instance.clearConfig();
      setState(() {
        _urlController.clear();
        _usernameController.clear();
        _passwordController.clear();
        _pathController.text = '/mooknote';
        _isConfigured = false;
      });
      if (mounted) ToastUtil.show(context,'配置已清除');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      children: [
        if (_isConfigured) _buildConnectedBanner(colors),
        if (_isConfigured) ...[
          _buildRemoteInfoCard(colors),
          const SizedBox(height: 16),
        ],
        _buildSectionLabel(colors, '服务器配置'),
        const SizedBox(height: 10),
        _buildInput(colors: colors, controller: _urlController, hint: '服务器地址，如 https://dav.example.com', icon: Icons.link),
        const SizedBox(height: 8),
        _buildInput(colors: colors, controller: _usernameController, hint: '用户名', icon: Icons.person_outline),
        const SizedBox(height: 8),
        _buildInput(colors: colors, controller: _passwordController, hint: '密码', icon: Icons.lock_outline,
          obscure: _obscurePassword,
          suffix: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(height: 8),
        _buildInput(colors: colors, controller: _pathController, hint: '同步路径，如 /mooknote', icon: Icons.folder_outlined),
        const SizedBox(height: 14),
        _buildBtn(colors, '测试并保存', onTap: _isLoading ? null : _saveConfig),
        if (_isConfigured) ...[
          const SizedBox(height: 8),
          Center(child: GestureDetector(
            onTap: _isLoading ? null : _clearConfig,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('清除配置', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)))),
          )),
        ],
        const SizedBox(height: 20),
        _buildTips(colors),
      ],
    );
  }

  Widget _buildConnectedBanner(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(_urlController.text, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('已连接', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
      ]),
    );
  }

  Widget _buildSectionLabel(ColorScheme colors, String text) {
    return Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5));
  }

  Widget _buildInput({required ColorScheme colors, required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(fontSize: 14, color: colors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
        prefixIcon: Padding(padding: const EdgeInsets.only(left: 4, right: 8), child: Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.3))),
        prefixIconConstraints: const BoxConstraints(minWidth: 44),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 8), child: suffix) : null,
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _buildBtn(ColorScheme colors, String text, {VoidCallback? onTap}) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: disabled ? colors.onSurface.withValues(alpha: 0.15) : colors.primary, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onPrimary))),
      ),
    );
  }

  Widget _buildRemoteInfoCard(ColorScheme colors) {
    String timeText;
    String sizeText = '';
    if (_isLoadingRemoteInfo) {
      timeText = '加载中...';
    } else if (_remoteModifiedTime != null) {
      final dt = _remoteModifiedTime!;
      timeText = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (_remoteFileSize != null) sizeText = _formatFileSize(_remoteFileSize!);
    } else {
      timeText = '暂无备份文件';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.cloud_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 8),
            Text('云端备份', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const Spacer(),
            if (_isLoadingRemoteInfo)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
            else
              GestureDetector(onTap: _loadRemoteInfo, child: Icon(Icons.refresh, size: 18, color: colors.onSurface.withValues(alpha: 0.4))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('上传时间', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              const SizedBox(height: 3),
              Text(timeText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
            ])),
            if (sizeText.isNotEmpty)
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('文件大小', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                const SizedBox(height: 3),
                Text(sizeText, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
              ])),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 0.5, color: Color(0xFFE0E0E0)),
          const SizedBox(height: 10),
          if (_isLoading) ...[
            SizedBox(width: double.infinity, child: LinearProgressIndicator(backgroundColor: colors.surfaceContainerHighest, color: colors.primary, minHeight: 3, borderRadius: BorderRadius.circular(1.5))),
            const SizedBox(height: 8),
            Text(_syncStep, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
          ] else ...[
            Row(children: [
              Expanded(child: _buildBtn(colors, '上传', onTap: _isLoading ? null : () => _confirmSync(SyncDirection.upload))),
              const SizedBox(width: 12),
              Expanded(child: _buildBtn(colors, '下载', onTap: _isLoading ? null : () => _confirmSync(SyncDirection.download))),
            ]),
          ],
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  Widget _buildTips(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('支持的服务', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _tip(colors, '坚果云、Nextcloud、AList 等 WebDAV 服务'),
          _tip(colors, '服务器地址需包含 https://'),
          _tip(colors, '首次同步可能需要较长时间'),
        ],
      ),
    );
  }

  Widget _tip(ColorScheme colors, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 8), child: Icon(Icons.circle, size: 4, color: colors.onSurface.withValues(alpha: 0.25))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5))),
        ],
      ),
    );
  }
}

// ─── 回收站弹窗 ──────────────────────────────────────────

enum _BinItemType { movie, book, note, game, movieReview, bookReview, bookExcerpt, gameReview }

class _BinItem {
  final _BinItemType type;
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String typeLabel;

  _BinItem.movie(Movie m)
      : type = _BinItemType.movie, id = m.id, title = m.title,
        subtitle = '删除于 ${m.updatedAt.year}.${m.updatedAt.month.toString().padLeft(2, '0')}.${m.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.movie_outlined, typeLabel = '影视';

  _BinItem.book(Book b)
      : type = _BinItemType.book, id = b.id, title = b.title,
        subtitle = '删除于 ${b.updatedAt.year}.${b.updatedAt.month.toString().padLeft(2, '0')}.${b.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.menu_book_outlined, typeLabel = '书籍';

  _BinItem.note(Note n)
      : type = _BinItemType.note, id = n.id, title = n.title.isNotEmpty ? n.title : n.summary,
        subtitle = '删除于 ${n.updatedAt.year}.${n.updatedAt.month.toString().padLeft(2, '0')}.${n.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.description_outlined, typeLabel = '笔记';

  _BinItem.game(Game g)
      : type = _BinItemType.game, id = g.id, title = g.title,
        subtitle = '删除于 ${g.updatedAt.year}.${g.updatedAt.month.toString().padLeft(2, '0')}.${g.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.sports_esports_outlined, typeLabel = '游戏';

  _BinItem.movieReview(MovieReview r)
      : type = _BinItemType.movieReview, id = r.id, title = r.content.isNotEmpty ? r.content : '影评',
        subtitle = '删除于 ${r.updatedAt.year}.${r.updatedAt.month.toString().padLeft(2, '0')}.${r.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.rate_review_outlined, typeLabel = '影评';

  _BinItem.bookReview(BookReview r)
      : type = _BinItemType.bookReview, id = r.id, title = r.content.isNotEmpty ? r.content : '书评',
        subtitle = '删除于 ${r.updatedAt.year}.${r.updatedAt.month.toString().padLeft(2, '0')}.${r.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.rate_review_outlined, typeLabel = '书评';

  _BinItem.bookExcerpt(BookExcerpt e)
      : type = _BinItemType.bookExcerpt, id = e.id, title = e.content.isNotEmpty ? e.content : '摘抄',
        subtitle = '删除于 ${e.updatedAt.year}.${e.updatedAt.month.toString().padLeft(2, '0')}.${e.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.format_quote_outlined, typeLabel = '书摘';

  _BinItem.gameReview(GameReview r)
      : type = _BinItemType.gameReview, id = r.id, title = r.content.isNotEmpty ? r.content : '游戏评价',
        subtitle = '删除于 ${r.updatedAt.year}.${r.updatedAt.month.toString().padLeft(2, '0')}.${r.updatedAt.day.toString().padLeft(2, '0')}',
        icon = Icons.rate_review_outlined, typeLabel = '游戏评价';
}

class _RecycleBinDialog extends StatefulWidget {
  const _RecycleBinDialog();

  @override
  State<_RecycleBinDialog> createState() => _RecycleBinDialogState();
}

class _RecycleBinDialogState extends State<_RecycleBinDialog> {
  List<_BinItem> _allItems = [];
  _BinItemType? _filterType;
  bool _isLoading = true;

  List<_BinItem> get _filteredItems =>
      _filterType == null ? _allItems : _allItems.where((i) => i.type == _filterType).toList();

  @override
  void initState() {
    super.initState();
    _loadDeletedItems();
  }

  Future<void> _loadDeletedItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final movies = await provider.getDeletedMovies();
    final books = await provider.getDeletedBooks();
    final notes = await provider.getDeletedNotes();
    final games = await provider.getDeletedGames();
    final movieReviews = await provider.getDeletedMovieReviews();
    final bookReviews = await provider.getDeletedBookReviews();
    final bookExcerpts = await provider.getDeletedBookExcerpts();
    final gameReviews = await provider.getDeletedGameReviews();
    if (!mounted) return;
    setState(() {
      _allItems = [
        for (final m in movies) _BinItem.movie(m),
        for (final b in books) _BinItem.book(b),
        for (final n in notes) _BinItem.note(n),
        for (final g in games) _BinItem.game(g),
        for (final r in movieReviews) _BinItem.movieReview(r),
        for (final r in bookReviews) _BinItem.bookReview(r),
        for (final e in bookExcerpts) _BinItem.bookExcerpt(e),
        for (final r in gameReviews) _BinItem.gameReview(r),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
      title: Row(children: [
        const Text('回收站'),
        const Spacer(),
        if (_allItems.isNotEmpty)
          TextButton(
            onPressed: _showClearAllDialog,
            style: TextButton.styleFrom(
              foregroundColor: colors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text('清空', style: TextStyle(fontSize: 12)),
          ),
      ]),
      content: SizedBox(
        width: 420,
        height: 620,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
            : Column(children: [
                if (_allItems.isNotEmpty) _buildFilterRow(colors),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? _buildEmptyState(colors)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filteredItems.length,
                          itemBuilder: (_, i) => _buildItem(_filteredItems[i], colors),
                        ),
                ),
              ]),
      ),
    );
  }

  Widget _buildFilterRow(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        _filterChip('全部', null, colors),
        _filterChip('影视', _BinItemType.movie, colors),
        _filterChip('书籍', _BinItemType.book, colors),
        _filterChip('笔记', _BinItemType.note, colors),
        _filterChip('游戏', _BinItemType.game, colors),
        _filterChip('影评', _BinItemType.movieReview, colors),
        _filterChip('书评', _BinItemType.bookReview, colors),
        _filterChip('书摘', _BinItemType.bookExcerpt, colors),
        _filterChip('游戏评价', _BinItemType.gameReview, colors),
      ]),
    );
  }

  Widget _filterChip(String label, _BinItemType? type, ColorScheme colors) {
    final active = _filterType == type;
    final count = type == null ? _allItems.length : _allItems.where((i) => i.type == type).length;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text('$label · $count',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
            color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
      ),
    );
  }

  Widget _buildItem(_BinItem item, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.outlineVariant, width: 0.5)),
            child: Icon(item.icon, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(item.title,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface, height: 1.3),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: colors.outlineVariant, width: 0.5)),
                child: Text(item.typeLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
              ),
            ]),
            const SizedBox(height: 2),
            Text(item.subtitle, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.35))),
          ])),
          const SizedBox(width: 6),
          _actionBtn(Icons.restore, colors.primary, () => _restore(item)),
          const SizedBox(width: 4),
          _actionBtn(Icons.delete_outline, colors.error, () => _permanentDelete(item)),
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.outlineVariant, width: 0.5)),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.delete_outline, size: 40, color: colors.onSurface.withValues(alpha: 0.15)),
      const SizedBox(height: 12),
      Text(_filterType == null ? '回收站是空的' : '没有删除的项目',
        style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
    ]));
  }

  Future<void> _restore(_BinItem item) async {
    final provider = context.read<AppProvider>();
    switch (item.type) {
      case _BinItemType.movie: await provider.restoreMovie(item.id);
      case _BinItemType.book: await provider.restoreBook(item.id);
      case _BinItemType.note: await provider.restoreNote(item.id);
      case _BinItemType.game: await provider.restoreGame(item.id);
      case _BinItemType.movieReview: await provider.restoreMovieReview(item.id);
      case _BinItemType.bookReview: await provider.restoreBookReview(item.id);
      case _BinItemType.bookExcerpt: await provider.restoreBookExcerpt(item.id);
      case _BinItemType.gameReview: await provider.restoreGameReview(item.id);
    }
    if (mounted) {
      ToastUtil.show(context, '${item.typeLabel}已恢复');
      _loadDeletedItems();
    }
  }

  Future<void> _permanentDelete(_BinItem item) async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要彻底删除吗？此操作不可恢复。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6)),
            child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<AppProvider>();
    switch (item.type) {
      case _BinItemType.movie: await provider.permanentDeleteMovie(item.id);
      case _BinItemType.book: await provider.permanentDeleteBook(item.id);
      case _BinItemType.note: await provider.permanentDeleteNote(item.id);
      case _BinItemType.game: await provider.permanentDeleteGame(item.id);
      case _BinItemType.movieReview: await provider.permanentDeleteMovieReview(item.id);
      case _BinItemType.bookReview: await provider.permanentDeleteBookReview(item.id);
      case _BinItemType.bookExcerpt: await provider.permanentDeleteBookExcerpt(item.id);
      case _BinItemType.gameReview: await provider.permanentDeleteGameReview(item.id);
    }
    if (mounted) {
      ToastUtil.show(context, '已彻底删除');
      _loadDeletedItems();
    }
  }

  void _showClearAllDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text('清空回收站', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]),
        content: Text('所有项目将被彻底删除，此操作不可恢复。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6)),
            child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppProvider>().clearRecycleBin();
              if (mounted) {
                ToastUtil.show(context, '回收站已清空');
                _loadDeletedItems();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('清空')),
        ],
      ),
    );
  }
}

/// 搜索弹窗：本地搜索 / 增强搜索（在线）切换
class _SearchDialog extends StatefulWidget {
  final BuildContext dialogContext;
  const _SearchDialog({required this.dialogContext});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _localNavKey = GlobalKey<NavigatorState>();
  final _onlineNavKey = GlobalKey<NavigatorState>();
  bool _isOnline = false;

  NavigatorState? get _activeNav =>
      (_isOnline ? _onlineNavKey : _localNavKey).currentState;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showToggle = UserPrefs().enhancedSearchEnabled;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _activeNav;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else {
          Navigator.of(widget.dialogContext).pop();
        }
      },
      child: Column(
        children: [
          if (showToggle) _buildToggle(colors),
          Expanded(
            child: IndexedStack(
              index: _isOnline ? 1 : 0,
              children: [
                _buildNav(_localNavKey, const SearchPage()),
                _buildNav(_onlineNavKey, const OnlineSearchPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNav(Key key, Widget page) {
    return Navigator(
      key: key,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _buildToggle(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleBtn('本地搜索', !_isOnline, () {
              if (!mounted) return;
              setState(() => _isOnline = false);
            }, colors),
          ),
          Expanded(
            child: _toggleBtn('增强搜索', _isOnline, () {
              if (!mounted) return;
              setState(() => _isOnline = true);
            }, colors),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap, ColorScheme colors) {
    return Material(
      color: selected ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.search_rounded : Icons.search_outlined,
                size: 14,
                color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconRailItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _IconRailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: selected ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 18,
                  color: selected ? accentColor : colors.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? accentColor : colors.onSurface.withValues(alpha: 0.55),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 第二栏：列表面板（搜索 + 当前分类列表） ──────────────

class _DesktopListPanel extends StatefulWidget {
  final int mainTabIndex;

  const _DesktopListPanel({required this.mainTabIndex});

  @override
  State<_DesktopListPanel> createState() => _DesktopListPanelState();
}

class _DesktopListPanelState extends State<_DesktopListPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _keyword = '';
  Timer? _debounce;
  /// 状态筛选：null=全部，否则按各实体 status 值过滤
  String? _statusFilter;

  @override
  void didUpdateWidget(covariant _DesktopListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mainTabIndex != widget.mainTabIndex) {
      _statusFilter = null;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _keyword = value.trim().toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 顶部搜索栏
        SizedBox(height: Platform.isWindows ? 0 : MediaQuery.of(context).padding.top),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    style: TextStyle(fontSize: 13, color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: '搜索...',
                      hintStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)),
                      prefixIcon: Icon(Icons.search, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                      suffixIcon: _keyword.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _keyword = '');
                              },
                              child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.3), width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSortButton(context),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // 列表
        Expanded(
          child: _keyword.isNotEmpty
              ? _buildSearchResults(context)
              : _buildCategoryList(context),
        ),
      ],
    );
  }

  // ─── 分类列表 ──────────────────────────────────────────

  Widget _buildCategoryList(BuildContext context) {
    switch (widget.mainTabIndex) {
      case -1: return const SizedBox.shrink(); // 主页 — 面板已隐藏
      case 0: return _buildMovieList(context);
      case 1: return _buildBookList(context);
      case 2: return _buildNoteList(context);
      case 3: return _buildGameList(context);
      default: return const SizedBox.shrink();
    }
  }

  // ─── 排序按钮（对应 Android 版长按 tab 弹出的排序菜单）────────────

  Widget _buildSortButton(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (currentSort, sortOptions, _, onSortSelected) = _sortConfig(context);
    final statusOptions = _statusFilterOptions();
    return PopupMenuButton<String>(
      tooltip: '排序与筛选',
      position: PopupMenuPosition.under,
      color: colors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (ctx) => [
        // 排序区
        PopupMenuItem<String>(
          value: '__sort_header__',
          enabled: false,
          height: 28,
          child: Text('排序', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
        ),
        for (final (value, text, icon) in sortOptions)
          PopupMenuItem<String>(
            value: 'sort:$value',
            child: Row(children: [
              Icon(icon, size: 16, color: currentSort == value ? colors.primary : colors.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 10),
              Text(text, style: TextStyle(fontSize: 13, color: currentSort == value ? colors.primary : colors.onSurface)),
              const Spacer(),
              if (currentSort == value)
                Icon(Icons.check, size: 14, color: colors.primary),
            ]),
          ),
        // 状态筛选区（仅影视/阅读/游戏）
        if (statusOptions != null) ...[
          const PopupMenuDivider(height: 8),
          PopupMenuItem<String>(
            value: '__filter_header__',
            enabled: false,
            height: 28,
            child: Text('状态筛选', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          for (final (value, text, icon) in statusOptions)
            PopupMenuItem<String>(
              value: 'filter:$value',
              child: Row(children: [
                Icon(icon, size: 16, color: _statusFilter == value ? colors.primary : colors.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 10),
                Text(text, style: TextStyle(fontSize: 13, color: _statusFilter == value ? colors.primary : colors.onSurface)),
                const Spacer(),
                if (_statusFilter == value)
                  Icon(Icons.check, size: 14, color: colors.primary),
              ]),
            ),
        ],
      ],
      onSelected: (v) {
        if (v.startsWith('sort:')) {
          final sortVal = int.parse(v.substring(5));
          if (sortVal != currentSort) onSortSelected(sortVal);
        } else if (v.startsWith('filter:')) {
          final filterVal = v.substring(7);
          setState(() => _statusFilter = filterVal.isEmpty ? null : filterVal);
        }
      },
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.sort, size: 18, color: colors.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }

  /// 各分类的状态筛选选项，笔记返回 null（无状态筛选）
  List<(String, String, IconData)>? _statusFilterOptions() {
    switch (widget.mainTabIndex) {
      case 0: // 影视
        return [
          ('', '全部', Icons.select_all),
          ('watched', '已看', Icons.visibility),
          ('watching', '在看', Icons.play_circle_outline),
          ('want_to_watch', '想看', Icons.bookmark_outline),
        ];
      case 1: // 阅读
        return [
          ('', '全部', Icons.select_all),
          ('read', '已读', Icons.visibility),
          ('reading', '在读', Icons.play_circle_outline),
          ('want_to_read', '想读', Icons.bookmark_outline),
          ('abandoned', '弃读', Icons.block),
        ];
      case 3: // 游戏
        return [
          ('', '全部', Icons.select_all),
          ('completed', '通关', Icons.visibility),
          ('playing', '在玩', Icons.play_circle_outline),
          ('want_to_play', '想玩', Icons.bookmark_outline),
          ('abandoned', '弃游', Icons.block),
        ];
      default:
        return null;
    }
  }

  (int, List<(int, String, IconData)>, String, ValueChanged<int>) _sortConfig(BuildContext context) {
    final provider = context.read<AppProvider>();
    switch (widget.mainTabIndex) {
      case 0:
        return (
          UserPrefs().movieSortMode,
          [(0, '按更新时间', Icons.update), (1, '按创建时间', Icons.calendar_today_outlined), (2, '按评分', Icons.star_outline)],
          '影视排序',
          (v) { UserPrefs().setMovieSortMode(v); provider.loadMovies(); },
        );
      case 1:
        return (
          UserPrefs().bookSortMode,
          [(0, '按更新时间', Icons.update), (1, '按创建时间', Icons.calendar_today_outlined), (2, '按评分', Icons.star_outline)],
          '书籍排序',
          (v) { UserPrefs().setBookSortMode(v); provider.loadBooks(); },
        );
      case 2:
        return (
          UserPrefs().noteSortMode,
          [(0, '按更新时间', Icons.update), (1, '按创建时间', Icons.calendar_today_outlined)],
          '笔记排序',
          (v) { UserPrefs().setNoteSortMode(v); provider.loadNotes(); },
        );
      case 3:
        return (
          UserPrefs().gameSortMode,
          [(0, '按更新时间', Icons.update), (1, '按创建时间', Icons.calendar_today_outlined), (2, '按评分', Icons.star_outline)],
          '游戏排序',
          (v) { UserPrefs().setGameSortMode(v); provider.loadGames(); },
        );
      default:
        return (0, <(int, String, IconData)>[], '', (_) {});
    }
  }

  Widget _buildMovieList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final items = provider.movies.where((m) => !m.isDeleted && (_statusFilter == null || m.status == _statusFilter)).toList();
        if (items.isEmpty) return _buildEmpty('暂无影视记录', Icons.movie_outlined);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final m = items[i];
            final (label, color) = _movieStatus(m.status);
            return _CompactListItem(
              title: m.title,
              subtitle: _movieSubtitle(m),
              imagePath: m.posterPath,
              accentColor: const Color(0xFF2563EB),
              icon: Icons.movie_outlined,
              selected: provider.selectedMovie?.id == m.id,
              statusLabel: label,
              statusColor: color,
              rating: m.rating,
              onTap: () => provider.selectMovie(m),
              onEdit: () => provider.selectMovie(m),
              onDelete: () => _deleteItem(context, 'movie', m.id, m.title),
            );
          },
        );
      },
    );
  }

  Widget _buildBookList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final items = provider.books.where((b) => !b.isDeleted && (_statusFilter == null || b.status == _statusFilter)).toList();
        if (items.isEmpty) return _buildEmpty('暂无阅读记录', Icons.menu_book_outlined);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final b = items[i];
            final (label, color) = _bookStatus(b.status);
            return _CompactListItem(
              title: b.title,
              subtitle: _bookSubtitle(b),
              imagePath: b.coverPath,
              accentColor: const Color(0xFF16A34A),
              icon: Icons.menu_book_outlined,
              selected: provider.selectedBook?.id == b.id,
              statusLabel: label,
              statusColor: color,
              rating: b.rating,
              onTap: () => provider.selectBook(b),
              onEdit: () => provider.selectBook(b),
              onDelete: () => _deleteItem(context, 'book', b.id, b.title),
            );
          },
        );
      },
    );
  }

  Widget _buildNoteList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        var items = provider.notes.where((n) => !n.isDeleted).toList();
        // 置顶排前面，同组内按创建时间倒序
        items.sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        if (items.isEmpty) return _buildEmpty('暂无笔记记录', Icons.note_outlined);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          itemBuilder: (_, i) => _DesktopNoteItem(
            note: items[i],
            selected: provider.selectedNote?.id == items[i].id,
            onTap: () => provider.selectNote(items[i]),
          ),
        );
      },
    );
  }

  Widget _buildGameList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        final items = provider.games.where((g) => !g.isDeleted && (_statusFilter == null || g.status == _statusFilter)).toList();
        if (items.isEmpty) return _buildEmpty('暂无游戏记录', Icons.sports_esports_outlined);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final g = items[i];
            final (label, color) = _gameStatus(g.status);
            return _CompactListItem(
              title: g.title,
              subtitle: _gameSubtitle(g),
              imagePath: g.coverPath,
              accentColor: const Color(0xFFEA580C),
              icon: Icons.sports_esports_outlined,
              selected: provider.selectedGame?.id == g.id,
              statusLabel: label,
              statusColor: color,
              rating: g.rating,
              onTap: () => provider.selectGame(g),
              onEdit: () => provider.selectGame(g),
              onDelete: () => _deleteItem(context, 'game', g.id, g.title),
            );
          },
        );
      },
    );
  }

  String? _movieSubtitle(Movie m) {
    if (m.directors.isEmpty) return null;
    return m.directors.join(', ');
  }

  String? _bookSubtitle(Book b) {
    if (b.authors.isEmpty) return null;
    return b.authors.join(', ');
  }

  String? _gameSubtitle(Game g) {
    if (g.platforms.isEmpty) return null;
    return g.platforms.join(', ');
  }

  (String, Color) _movieStatus(String status) => switch (status) {
    'watched'      => ('已看', const Color(0xFF16A34A)),
    'watching'     => ('在看', const Color(0xFF2563EB)),
    'want_to_watch'=> ('想看', const Color(0xFF9CA3AF)),
    _              => ('已看', const Color(0xFF16A34A)),
  };

  (String, Color) _bookStatus(String status) => switch (status) {
    'read'         => ('已读', const Color(0xFF16A34A)),
    'reading'      => ('在读', const Color(0xFF2563EB)),
    'want_to_read' => ('想读', const Color(0xFF9CA3AF)),
    'abandoned'    => ('弃读', const Color(0xFFEF4444)),
    _              => ('已读', const Color(0xFF16A34A)),
  };

  (String, Color) _gameStatus(String status) => switch (status) {
    'completed'    => ('通关', const Color(0xFF16A34A)),
    'playing'      => ('在玩', const Color(0xFF2563EB)),
    'want_to_play' => ('想玩', const Color(0xFF9CA3AF)),
    'abandoned'    => ('弃游', const Color(0xFFEF4444)),
    _              => ('通关', const Color(0xFF16A34A)),
  };

  Future<void> _deleteItem(BuildContext context, String type, String id, String title) async {
    final provider = context.read<AppProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: const Text('确认删除'),
        content: Text('确定要删除「$title」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      switch (type) {
        case 'movie': await provider.removeMovie(id);
        case 'book': await provider.removeBook(id);
        case 'game': await provider.removeGame(id);
      }
    }
  }

  // ─── 搜索结果 ──────────────────────────────────────────

  Widget _buildSearchResults(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();

    final movies = provider.movies.where((m) => !m.isDeleted && _matchMovie(m, _keyword)).toList();
    final books = provider.books.where((b) => !b.isDeleted && _matchBook(b, _keyword)).toList();
    final notes = provider.notes.where((n) => !n.isDeleted && _matchNote(n, _keyword)).toList();
    final games = provider.games.where((g) => !g.isDeleted && _matchGame(g, _keyword)).toList();

    final totalCount = movies.length + books.length + notes.length + games.length;

    if (totalCount == 0) {
      return Center(
        child: Text('未找到相关结果', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (movies.isNotEmpty) ...[
          _SearchGroupHeader(label: '影视', count: movies.length, color: const Color(0xFF2563EB)),
          ...movies.map((m) {
            final (label, color) = _movieStatus(m.status);
            return _CompactListItem(
              title: m.title,
              subtitle: _movieSubtitle(m),
              imagePath: m.posterPath,
              accentColor: const Color(0xFF2563EB),
              icon: Icons.movie_outlined,
              selected: provider.selectedMovie?.id == m.id,
              statusLabel: label,
              statusColor: color,
              rating: m.rating,
              onTap: () {
                provider.setMainTabIndex(0);
                provider.selectMovie(m);
              },
            );
          }),
        ],
        if (books.isNotEmpty) ...[
          _SearchGroupHeader(label: '阅读', count: books.length, color: const Color(0xFF16A34A)),
          ...books.map((b) {
            final (label, color) = _bookStatus(b.status);
            return _CompactListItem(
              title: b.title,
              subtitle: _bookSubtitle(b),
              imagePath: b.coverPath,
              accentColor: const Color(0xFF16A34A),
              icon: Icons.menu_book_outlined,
              selected: provider.selectedBook?.id == b.id,
              statusLabel: label,
              statusColor: color,
              rating: b.rating,
              onTap: () {
                provider.setMainTabIndex(1);
                provider.selectBook(b);
              },
            );
          }),
        ],
        if (notes.isNotEmpty) ...[
          _SearchGroupHeader(label: '笔记', count: notes.length, color: const Color(0xFF9333EA)),
          ...notes.map((n) => _CompactListItem(
            title: n.title.isNotEmpty ? n.title : '随手记',
            subtitle: n.content.length > 40 ? '${n.content.substring(0, 40)}...' : null,
            imagePath: null,
            accentColor: const Color(0xFF9333EA),
            icon: Icons.note_outlined,
            selected: provider.selectedNote?.id == n.id,
            onTap: () {
              provider.setMainTabIndex(2);
              provider.selectNote(n);
            },
          )),
        ],
        if (games.isNotEmpty) ...[
          _SearchGroupHeader(label: '游戏', count: games.length, color: const Color(0xFFEA580C)),
          ...games.map((g) {
            final (label, color) = _gameStatus(g.status);
            return _CompactListItem(
              title: g.title,
              subtitle: _gameSubtitle(g),
              imagePath: g.coverPath,
              accentColor: const Color(0xFFEA580C),
              icon: Icons.sports_esports_outlined,
              selected: provider.selectedGame?.id == g.id,
              statusLabel: label,
              statusColor: color,
              rating: g.rating,
              onTap: () {
                provider.setMainTabIndex(3);
                provider.selectGame(g);
              },
            );
          }),
        ],
      ],
    );
  }

  bool _matchMovie(Movie m, String kw) {
    return m.title.toLowerCase().contains(kw) ||
        (m.summary?.toLowerCase().contains(kw) ?? false) ||
        m.genres.any((g) => g.toLowerCase().contains(kw)) ||
        m.directors.any((d) => d.toLowerCase().contains(kw)) ||
        m.actors.any((a) => a.toLowerCase().contains(kw));
  }

  bool _matchBook(Book b, String kw) {
    return b.title.toLowerCase().contains(kw) ||
        (b.summary?.toLowerCase().contains(kw) ?? false) ||
        b.authors.any((a) => a.toLowerCase().contains(kw));
  }

  bool _matchNote(Note n, String kw) {
    return n.title.toLowerCase().contains(kw) ||
        n.content.toLowerCase().contains(kw) ||
        n.tags.any((t) => t.toLowerCase().contains(kw));
  }

  bool _matchGame(Game g, String kw) {
    return g.title.toLowerCase().contains(kw) ||
        g.genres.any((ge) => ge.toLowerCase().contains(kw)) ||
        g.platforms.any((p) => p.toLowerCase().contains(kw));
  }

  Widget _buildEmpty(String text, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: colors.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }
}

// ─── 紧凑列表项 ──────────────────────────────────────────

class _CompactListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imagePath;
  final Color accentColor;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final String? statusLabel; // 状态文字，如"已看""想看"
  final Color? statusColor;  // 状态颜色
  final double? rating;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CompactListItem({
    required this.title,
    this.subtitle,
    this.imagePath,
    required this.accentColor,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.statusLabel,
    this.statusColor,
    this.rating,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final effectiveStatusColor = statusColor ?? accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: selected
            ? accentColor.withValues(alpha: isDark ? 0.12 : 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          onSecondaryTapUp: (onEdit != null || onDelete != null) ? (details) => _showContextMenu(context, details) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                // 左侧状态指示条
                Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(
                    color: statusLabel != null ? effectiveStatusColor.withValues(alpha: 0.6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                // 缩略图 / 图标占位
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imagePath != null && imagePath!.isNotEmpty
                      ? FadeInLocalImage(
                          path: imagePath!,
                          fit: BoxFit.cover,
                          errorWidget: Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.5)),
                        )
                      : Icon(icon, size: 18, color: accentColor.withValues(alpha: 0.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected ? accentColor : colors.onSurface,
                          )),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                      ],
                    ],
                  ),
                ),
                // 评分
                if (rating != null && rating! > 0) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star, size: 12, color: Color(0xFFFFB800)),
                  const SizedBox(width: 1),
                  Text(rating!.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
                ],
                // 状态标签
                if (statusLabel != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: effectiveStatusColor.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(statusLabel!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: effectiveStatusColor)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    final colors = Theme.of(context).colorScheme;
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(details.localPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        if (onEdit != null)
          PopupMenuItem<String>(
            value: 'edit',
            height: 36,
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              const Text('编辑', style: TextStyle(fontSize: 13)),
            ]),
          ),
        if (onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            height: 36,
            child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: colors.error),
              const SizedBox(width: 8),
              Text('删除', style: TextStyle(color: colors.error, fontSize: 13)),
            ]),
          ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      if (value == 'edit') onEdit?.call();
      if (value == 'delete') onDelete?.call();
    });
  }
}

// ─── 桌面端笔记列表项 ──────────────────────────────────────

class _DesktopNoteItem extends StatelessWidget {
  final Note note;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopNoteItem({
    required this.note,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final title = note.title.isNotEmpty ? note.title : '随手记';
    final preview = note.content.length > 60 ? '${note.content.substring(0, 60)}...' : note.content;
    final dateStr = '${note.updatedAt.month}/${note.updatedAt.day}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: isDark ? 0.12 : 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          onSecondaryTapUp: (details) => _showContextMenu(context, details),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (note.isPinned) ...[
                    Icon(Icons.push_pin, size: 12, color: colors.primary),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? colors.primary : colors.onSurface))),
                  const SizedBox(width: 6),
                  Text(dateStr, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
                ]),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4), height: 1.4)),
                ],
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(spacing: 4, runSpacing: 2, children: [
                    for (final tag in note.tags.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tag, style: TextStyle(fontSize: 9, color: colors.onPrimaryContainer)),
                      ),
                    if (note.tags.length > 3)
                      Text('+${note.tags.length - 3}', style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3))),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    final provider = context.read<AppProvider>();
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(details.localPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        PopupMenuItem<String>(
          value: 'pin',
          height: 36,
          child: Row(children: [
            Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(note.isPinned ? '取消置顶' : '置顶', style: const TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          height: 36,
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            const Text('编辑', style: TextStyle(fontSize: 13)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          height: 36,
          child: Row(children: [
            Icon(Icons.delete_outline, size: 16, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('删除', style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
          ]),
        ),
      ],
    ).then((value) async {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'pin':
          await provider.toggleNotePin(note.id, !note.isPinned);
          break;
        case 'edit':
          provider.selectNote(note);
          // 进入编辑模式由 NoteDetailPage 处理
          break;
        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              title: const Text('确认删除'),
              content: Text('确定要删除「${note.title.isNotEmpty ? note.title : '随手记'}」吗？'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: Text('删除', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await provider.removeNote(note.id);
          }
          break;
      }
    });
  }
}

// ─── 搜索分组标题 ──────────────────────────────────────

class _SearchGroupHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SearchGroupHeader({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }
}
