import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../main.dart' show routeObserver;
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../settings/recycle_bin_page.dart';
import '../sync/backup_page.dart';
import '../../widgets/fade_in_local_image.dart';
import '../explore/statistics_page.dart';
import '../settings/tag_management_page.dart';
import '../explore/stroll_page.dart';
import '../sync/cloud_sync_page.dart';
import 'settings_page.dart';

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

  @override
  void initState() {
    super.initState();
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
    // 从其他页面返回时刷新用户数据（头像、昵称等）
    _loadUserData();
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
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: colors.onSurface),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('我的'),
        ),
        Expanded(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              final movies =
                  provider.movies.where((m) => !m.isDeleted).toList();
              final books = provider.books.where((b) => !b.isDeleted).toList();
              final notes = provider.notes.where((n) => !n.isDeleted).toList();
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(movies, books, notes),
                    const SizedBox(height: 20),
                    if (_userPrefs.showMovieTab) ...[
                      _buildModuleHeader('影视'),
                      _buildMovieModule(movies),
                      const SizedBox(height: 20),
                    ],
                    if (_userPrefs.showBookTab) ...[
                      _buildModuleHeader('阅读'),
                      _buildBookModule(books),
                      const SizedBox(height: 20),
                    ],
                    if (_userPrefs.showNoteTab) ...[
                      _buildModuleHeader('笔记'),
                      _buildNoteModule(notes),
                      const SizedBox(height: 20),
                    ],
                    _buildTagsSection(movies, books, notes),
                    const SizedBox(height: 20),
                    _buildToolsGrid(context),
                    const SizedBox(height: 120),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Hero 区域 ──────────────────────────────────────────────────────

  Widget _buildHero(List<Movie> movies, List<Book> books, List<Note> notes) {
    final colors = Theme.of(context).colorScheme;
    final coverPaths = [
      ...movies
          .where((m) => m.posterPath != null && m.posterPath!.isNotEmpty)
          .map((m) => m.posterPath!),
      ...books
          .where((b) => b.coverPath != null && b.coverPath!.isNotEmpty)
          .map((b) => b.coverPath!),
    ]..shuffle();

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
                          Text(_motto,
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
                    _buildHeroStat(_formatCount(movies.length), '观影', hasData),
                    _buildHeroStat(_formatCount(books.length), '阅读', hasData),
                    _buildHeroStat(_formatCount(notes.length), '笔记', hasData),
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
    final posters = paths.take(12).toList();
    while (posters.length < 12)
      posters.add(posters[posters.length % paths.length]);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: 12,
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

  // ─── 模块标题 ──────────────────────────────────────────────────────

  Widget _buildModuleHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.onSurface)),
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
            _buildStatusTag('已看', watched, true, colors),
            const SizedBox(width: 10),
            _buildStatusTag('在看', watching, false, colors),
            const SizedBox(width: 10),
            _buildStatusTag('想看', wantTo, false, colors),
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
          _buildEmptyHint('暂无影视记录'),
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
            _buildStatusTag('已读', read, true, colors),
            const SizedBox(width: 10),
            _buildStatusTag('在读', reading, false, colors),
            const SizedBox(width: 10),
            _buildStatusTag('想读', wantTo, false, colors),
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
          _buildEmptyHint('暂无阅读记录'),
      ],
    );
  }

  // ─── 笔记模块 ──────────────────────────────────────────────────────

  Widget _buildNoteModule(List<Note> notes) {
    final recent = notes.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (recent.isEmpty) return _buildEmptyHint('暂无笔记记录');

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
              Text('常用标签',
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
                    Text('管理',
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
        '漫步',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StrollPage()))
      ),
      (
        Icons.analytics_outlined,
        '统计',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StatisticsPage()))
      ),
      (Icons.backup_outlined, '备份', () => _showBackupOptions(context)),
      (
        Icons.delete_outline,
        '回收',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RecycleBinPage()))
      ),
      (
        Icons.settings_outlined,
        '设置',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsPage()))
      ),
      (Icons.feedback_outlined, '反馈', () => _showFeedbackDialog(context)),
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
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 反馈弹窗 ────────────────────────────────────────────────────────

  void _showFeedbackDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final email = 'dellevin99@gmail.com';
    showModalBottomSheet(
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
                  child: Text('反馈',
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
                        Text('作者邮箱',
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
                      ToastUtil.show(context, '已复制到剪贴板');
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
                          Text('复制',
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
                        Text('QQ 群',
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
                      ToastUtil.show(context, '已复制到剪贴板');
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
                          Text('复制',
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
    await showModalBottomSheet(
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
                  child: Text('更换头像',
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
            title: Text('从文件管理器选择',
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
              title: Text('移除头像',
                  style: TextStyle(fontSize: 14, color: colors.error)),
              trailing: Icon(Icons.chevron_right,
                  color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () async {
                Navigator.pop(ctx);
                await _userPrefs.clearAvatarPath();
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
      final pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 400,
          maxHeight: 400,
          imageQuality: 85);
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'avatars', fileName);
        final avatarDir = Directory(path.join(appDir.path, 'avatars'));
        if (!await avatarDir.exists()) await avatarDir.create(recursive: true);
        await File(pickedFile.path).copy(savedPath);
        await _userPrefs.setAvatarPath(savedPath);
        setState(() => _avatarPath = savedPath);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择头像失败');
    }
  }

  // ─── 备份弹窗 ────────────────────────────────────────────────────────

  void _showBackupOptions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
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
                child: Text('选择备份方式',
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
              title: Text('本地备份',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
              subtitle: Text('备份到本地文件夹，支持恢复',
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
              title: Text('云备份',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
              subtitle: Text('通过 WebDAV 同步到云端',
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
}
