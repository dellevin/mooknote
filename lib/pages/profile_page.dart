import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show routeObserver;
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/theme/app_theme.dart';
import '../utils/toast_util.dart';
import '../utils/database_helper.dart';
import 'recycle_bin_page.dart';
import 'sync/backup_page.dart';
import '../widgets/fade_in_local_image.dart';
import 'statistics_page.dart';
import 'changelog_page.dart';
import 'legal_page.dart';
import 'online_search/enhanced_search_settings_page.dart';
import 'sync/cloud_sync_page.dart';
import 'app_icon_picker_page.dart';
import 'tag_management_page.dart';
import 'stroll_page.dart';

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
        Icons.settings_outlined,
        '设置',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SettingsPage()))
      ),
      (
        Icons.delete_outline,
        '回收',
        () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const RecycleBinPage()))
      ),
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

// ─── 设置页面 ──────────────────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  bool _hideBottomNavOnScroll = true;
  int _themeMode = 0; // 0=系统, 1=浅色, 2=深色
  String _fontFamily = '';

  @override
  void initState() {
    super.initState();
    _hideBottomNavOnScroll = _userPrefs.hideBottomNavOnScroll;
    _themeMode = _userPrefs.themeMode;
    _fontFamily = _userPrefs.fontFamily;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader('显示设置'),
          if (!Platform.isWindows)
            _buildNavigationItem(
              icon: Icons.apps_outlined,
              title: '应用图标',
              subtitle: '更换桌面应用图标',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AppIconPickerPage())),
            ),
          if (!Platform.isWindows)
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
              color: colors.outlineVariant),
          _buildNavigationItem(
            icon: Icons.tune_outlined,
            title: '功能设置',
            subtitle: '启动标签、模块开关、侧边栏功能',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const FeatureSettingsPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildNavigationItem(
            icon: Icons.dashboard_outlined,
            title: '布局设置',
            subtitle: '影视、阅读、笔记的展示样式',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LayoutSettingsPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildThemeModeSelector(),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildColorSchemeSelector(),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildFontSelector(),
          _buildSectionHeader('其他设置'),
          _buildActionItem(
            icon: Icons.person_outline,
            title: '个人信息',
            subtitle: '修改昵称和座右铭',
            onTap: () => _showProfileEditDialog(context),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.manage_search,
            title: '增强搜索',
            subtitle: '在线搜索影视和书籍信息',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EnhancedSearchSettingsPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
            icon: Icons.swipe_vertical_outlined,
            title: '底部导航栏滚动隐藏',
            subtitle: '下滑时自动隐藏底部导航栏',
            value: _hideBottomNavOnScroll,
            onChanged: _toggleHideBottomNavOnScroll,
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSectionHeader('数据管理'),
          _buildActionItem(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存数据',
            subtitle: '清理未在数据库中引用的文件',
            onTap: () => _showClearCacheDialog(context),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSectionHeader('帮助'),
          _buildActionItem(
            icon: Icons.language_outlined,
            title: '查看官网',
            subtitle: '在浏览器中打开官方网站',
            onTap: () =>
                launchUrl(Uri.parse('https://mooknote.iletter.top/#/')),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.open_in_new_outlined,
            title: '项目源码',
            subtitle: '查看 GitHub 项目仓库',
            onTap: () =>
                launchUrl(Uri.parse('https://github.com/dellevin/mooknote')),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.code_outlined,
            title: '开发日志',
            subtitle: '在浏览器中查看项目开发记录',
            onTap: () => launchUrl(Uri.parse(
                'http://docmost.iletter.top/share/ropwljpyvn/p/mook-note-lHmPTswdDC')),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.update_outlined,
            title: '更新日志',
            subtitle: '查看版本更新内容',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ChangelogPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.description_outlined,
            title: '用户服务协议',
            subtitle: '查看用户服务协议',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const LegalPage(slug: 'terms', title: '用户服务协议'))),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.shield_outlined,
            title: '隐私政策',
            subtitle: '查看隐私政策',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const LegalPage(slug: 'privacy', title: '隐私政策'))),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
        ],
      ),
    );
  }

  Future<void> _toggleHideBottomNavOnScroll(bool value) async {
    await _userPrefs.setHideBottomNavOnScroll(value);
    setState(() => _hideBottomNavOnScroll = value);
  }

  void _showProfileEditDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nicknameController = TextEditingController(text: _userPrefs.nickname);
    final mottoController = TextEditingController(text: _userPrefs.motto);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('个人信息',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameController,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: InputDecoration(
                labelText: '昵称',
                labelStyle: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5)),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: mottoController,
              maxLines: 2,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: InputDecoration(
                labelText: '座右铭',
                labelStyle: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5)),
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () async {
              final nickname = nicknameController.text.trim();
              final motto = mottoController.text.trim();
              if (nickname.isNotEmpty) await _userPrefs.setNickname(nickname);
              if (motto.isNotEmpty) await _userPrefs.setMotto(motto);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ToastUtil.show(context, '已保存');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('保存', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  static const _themeModeLabels = ['跟随系统', '浅色模式', '深色模式'];
  static const _themeModeIcons = [
    Icons.brightness_auto,
    Icons.light_mode,
    Icons.dark_mode
  ];

  Widget _buildThemeModeSelector() {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showThemeModePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(_themeModeIcons[_themeMode],
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('主题模式',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(_themeModeLabels[_themeMode],
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  void _showThemeModePicker() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('主题模式',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface))),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _themeModeLabels.length; i++)
              InkWell(
                onTap: () async {
                  await _setThemeMode(i);
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_themeModeIcons[i],
                          size: 18,
                          color: colors.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_themeModeLabels[i],
                              style: TextStyle(
                                  fontSize: 13, color: colors.onSurface))),
                      if (_themeMode == i)
                        Icon(Icons.check, color: colors.onSurface, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setThemeMode(int mode) async {
    await _userPrefs.setThemeMode(mode);
    final themeMode = switch (mode) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    if (mounted) {
      context.read<AppProvider>().setThemeMode(themeMode);
      setState(() => _themeMode = mode);
    }
  }

  Widget _buildColorSchemeSelector() {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();
    final currentIndex = provider.colorSchemeIndex;
    final label =
        currentIndex == -1 ? '莫奈取色' : AppTheme.colorSchemeNames[currentIndex];
    return InkWell(
      onTap: () => _showColorSchemePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    currentIndex == -1
                        ? Icons.auto_awesome
                        : Icons.palette_outlined,
                    color: colors.onSurface.withValues(alpha: 0.6),
                    size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('配色方案',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  void _showColorSchemePicker() {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<AppProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                  child: Text('配色方案',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface))),
            ),
            const SizedBox(height: 12),
            // 莫奈自动取色
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildMonetOption(provider, colors, ctx),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2),
                itemCount: AppTheme.seedColors.length,
                itemBuilder: (_, i) {
                  final selected = provider.colorSchemeIndex == i;
                  return GestureDetector(
                    onTap: () {
                      provider.setColorScheme(i);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.seedColors[i].withValues(alpha: 0.12)
                            : colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: selected
                                ? AppTheme.seedColors[i]
                                : Colors.transparent,
                            width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: AppTheme.seedColors[i],
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(AppTheme.colorSchemeNames[i],
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: colors.onSurface)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonetOption(
      AppProvider provider, ColorScheme colors, BuildContext ctx) {
    final selected = provider.colorSchemeIndex == -1;
    final monetColor = AppTheme.monetColor;
    final available = monetColor != null;
    return GestureDetector(
      onTap: available
          ? () {
              provider.setColorScheme(-1);
              Navigator.pop(ctx);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (monetColor ?? colors.primary).withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? (monetColor ?? colors.primary)
                  : available
                      ? colors.outlineVariant
                      : colors.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 1.5 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: monetColor != null
                    ? LinearGradient(
                        colors: [monetColor, monetColor.withValues(alpha: 0.6)])
                    : null,
                color: available ? null : colors.outlineVariant,
              ),
              child: available
                  ? null
                  : Icon(Icons.auto_awesome,
                      size: 12, color: colors.onSurface.withValues(alpha: 0.3)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('莫奈取色',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: available
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.35))),
                    Text(available ? '从系统壁纸自动提取配色' : '此设备不支持',
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.35))),
                  ]),
            ),
            if (selected)
              Icon(Icons.check_circle,
                  size: 18, color: monetColor ?? colors.primary),
          ],
        ),
      ),
    );
  }

  // ─── 字体选择器 ───

  static const _fontLabels = ['默认字体', '霞鹜文楷', 'OPPO Sans', '思源宋体', '得意黑'];
  static const _fontValues = [
    '',
    'LXGWWenKai',
    'OPPOSans',
    'NotoSerifSC',
    'SmileySans'
  ];
  static const _fontIcons = [
    Icons.font_download_outlined,
    Icons.brush_outlined,
    Icons.phone_android,
    Icons.text_fields,
    Icons.emoji_emotions_outlined
  ];

  Widget _buildFontSelector() {
    final colors = Theme.of(context).colorScheme;
    final idx = _fontValues.indexOf(_fontFamily);
    final label = idx >= 0 ? _fontLabels[idx] : '系统默认';
    return InkWell(
      onTap: _showFontPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.font_download_outlined,
                  size: 18, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('字体',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4))),
              ])),
          Icon(Icons.chevron_right,
              size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
        ]),
      ),
    );
  }

  void _showFontPicker() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.only(bottom: 20),
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
                  child: Text('字体',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)))),
          const SizedBox(height: 8),
          for (int i = 0; i < _fontLabels.length; i++) ...[
            if (i > 0)
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
                  child: Icon(_fontIcons[i],
                      size: 20,
                      color: _fontFamily == _fontValues[i]
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(_fontLabels[i],
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: _fontFamily == _fontValues[i]
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: colors.onSurface)),
              trailing: _fontFamily == _fontValues[i]
                  ? Icon(Icons.check, size: 20, color: colors.primary)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _setFontFamily(_fontValues[i]);
              },
            ),
          ],
        ]),
      ),
    );
  }

  void _setFontFamily(String family) {
    setState(() => _fontFamily = family);
    context.read<AppProvider>().setFontFamily(family);
  }

  Widget _buildSwitchItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon,
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
            Switch(
                value: value,
                onChanged: onChanged,
                activeColor: colors.primary,
                activeTrackColor: colors.primary.withValues(alpha: 0.3),
                inactiveThumbColor: colors.surface,
                inactiveTrackColor: colors.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurface)),
    );
  }

  Widget _buildNavigationItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon,
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon,
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext pageContext) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('清除缓存数据',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        content: Text('这将删除所有未在数据库中引用的文件。确定要继续吗？',
            style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消',
                  style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _clearCacheData(pageContext);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('清除'),
          ),
        ],
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _clearCacheData(BuildContext context) async {
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      final appProvider = context.read<AppProvider>();

      // 1. 清理未引用的图片文件
      final dbImagePaths = await _getAllDbImagePaths(appProvider);
      final deletedImages = await _cleanImageDirectory(dbImagePaths);

      // 2. 清理孤立的 epub_books 目录
      final deletedEpubs = await _cleanOrphanedEpubBooks(appProvider);

      // 3. 清理临时目录缓存（分享海报、备份ZIP等）
      final deletedTemp = await _cleanTempDirectory();

      // 4. 清理空文件夹
      final deletedEmptyDirs = await _cleanEmptyDirectories();

      Navigator.pop(context);
      if (context.mounted) {
        final total =
            deletedImages + deletedEpubs + deletedTemp + deletedEmptyDirs;
        if (total == 0) {
          ToastUtil.show(context, '没有需要清理的缓存');
        } else {
          ToastUtil.show(context,
              '已清理 $deletedImages 个孤立图片，$deletedEpubs 个孤立电子书，$deletedTemp 个临时文件，$deletedEmptyDirs 个空文件夹');
        }
      }
    } catch (e) {
      Navigator.pop(context);
      if (context.mounted) ToastUtil.show(context, '清理失败: $e');
    }
  }

  Future<Set<String>> _getAllDbImagePaths(AppProvider provider) async {
    final paths = <String>{};
    for (final movie in provider.movies) {
      if (movie.posterPath?.isNotEmpty == true) paths.add(movie.posterPath!);
    }
    for (final book in provider.books) {
      if (book.coverPath?.isNotEmpty == true) paths.add(book.coverPath!);
    }
    for (final note in provider.notes) {
      for (final p in note.images) {
        if (p.isNotEmpty) paths.add(p);
      }
    }
    for (final movieId in provider.movies.map((m) => m.id)) {
      for (final poster in await provider.getMoviePosters(movieId)) {
        if (poster.posterPath.isNotEmpty) paths.add(poster.posterPath);
      }
    }
    return paths;
  }

  Future<int> _cleanImageDirectory(Set<String> dbImagePaths) async {
    int deletedCount = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) return 0;
      await for (final entity
          in imagesDir.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            !dbImagePaths.contains(entity.path) &&
            !path.basename(entity.path).startsWith('avatar')) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('清理图片目录失败: $e');
    }
    return deletedCount;
  }

  /// 清理 epub_books 中孤立的目录（数据库中不存在的）
  Future<int> _cleanOrphanedEpubBooks(AppProvider provider) async {
    int deletedCount = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      // 收集数据库中所有引用的 epub_books 子目录名
      final rows = await db
          .query('reader_books', columns: ['id', 'file_path', 'cover_path']);
      final usedDirs = <String>{};
      for (final r in rows) {
        final id = r['id'] as String?;
        if (id != null && id.isNotEmpty) usedDirs.add(id);
        _collectEpubDirName(r['file_path'] as String?, usedDirs);
        _collectEpubDirName(r['cover_path'] as String?, usedDirs);
      }

      final appDir = await getApplicationDocumentsDirectory();
      final epubDir = Directory('${appDir.path}/epub_books');
      if (!await epubDir.exists()) return 0;

      await for (final entity in epubDir.list(followLinks: false)) {
        if (entity is Directory) {
          final dirName = path.basename(entity.path);
          if (!usedDirs.contains(dirName)) {
            try {
              await entity.delete(recursive: true);
              deletedCount++;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('清理 epub_books 目录失败: $e');
    }
    return deletedCount;
  }

  /// 从绝对路径中提取 epub_books/ 下的目录名
  void _collectEpubDirName(String? pathStr, Set<String> dirs) {
    if (pathStr == null || pathStr.isEmpty) return;
    final marker = '/epub_books/';
    final idx = pathStr.indexOf(marker);
    if (idx < 0) return;
    final rest = pathStr.substring(idx + marker.length);
    final slashIdx = rest.indexOf('/');
    dirs.add(slashIdx >= 0 ? rest.substring(0, slashIdx) : rest);
  }

  Future<int> _cleanTempDirectory() async {
    int deletedCount = 0;
    final now = DateTime.now();

    // 1. 清理临时目录中的分享海报（保留备份ZIP）
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          if (entity is File) {
            final name = path.basename(entity.path);
            if (name.startsWith('book_poster_') ||
                name.startsWith('movie_poster_') ||
                name.startsWith('note_share_') ||
                name.startsWith('mooknote_download') ||
                name.startsWith('mooknote_bidir')) {
              try {
                final stat = await entity.stat();
                if (now.difference(stat.modified).inHours >= 1) {
                  await entity.delete();
                  deletedCount++;
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('清理临时目录失败: $e');
    }

    // 2. 清理应用缓存目录 (/data/user/0/{package}/cache/)
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await for (final entity
            in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('清理缓存目录失败: $e');
    }

    return deletedCount;
  }

  /// 清理 images、epub_books、cache 下的空文件夹
  Future<int> _cleanEmptyDirectories() async {
    int deletedCount = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = await getApplicationCacheDirectory();
      final dirs = [
        Directory('${appDir.path}/images'),
        Directory('${appDir.path}/epub_books'),
        cacheDir,
      ];
      for (final dir in dirs) {
        if (!await dir.exists()) continue;
        deletedCount += await _removeEmptyDirsRecursive(dir);
      }
    } catch (e) {
      debugPrint('清理空文件夹失败: $e');
    }
    return deletedCount;
  }

  /// 递归删除空子文件夹（自底向上），不删除根目录本身
  Future<int> _removeEmptyDirsRecursive(Directory dir) async {
    int count = 0;
    try {
      final children = await dir.list(followLinks: false).toList();
      for (final child in children) {
        if (child is Directory) {
          count += await _removeEmptyDirsRecursive(child);
          final remaining = await child.list(followLinks: false).toList();
          if (remaining.isEmpty) {
            try {
              await child.delete();
              count++;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return count;
  }
}

// ─── 功能设置 ───

class FeatureSettingsPage extends StatefulWidget {
  const FeatureSettingsPage({super.key});

  @override
  State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();

  // 主界面
  bool _showMovieTab = true;
  bool _showBookTab = true;
  bool _showNoteTab = true;
  bool _showNotePlusTab = false;
  int _defaultTabIndex = 0;

  // 侧边栏
  bool _showHeatmap = true;
  bool _showRecent = true;
  bool _showEncounter = true;
  bool _showStroll = true;
  bool _showCalendar = true;
  bool _showPerson = true;
  bool _showTags = true;
  bool _showMdReader = true;
  bool _showEpub = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _showMovieTab = _userPrefs.showMovieTab;
      _showBookTab = _userPrefs.showBookTab;
      _showNoteTab = _userPrefs.showNoteTab;
      _showNotePlusTab = _userPrefs.showNotePlusTab;
      _defaultTabIndex = _userPrefs.defaultMainTabIndex;
      _showHeatmap = _userPrefs.showSidebarHeatmap;
      _showRecent = _userPrefs.showSidebarRecent;
      _showEncounter = _userPrefs.showSidebarEncounter;
      _showStroll = _userPrefs.showSidebarStroll;
      _showCalendar = _userPrefs.showSidebarCalendar;
      _showPerson = _userPrefs.showSidebarPerson;
      _showTags = _userPrefs.showSidebarTags;
      _showMdReader = _userPrefs.showSidebarMdReader;
      _showEpub = _userPrefs.showSidebarEpub;
    });
  }

  int get _enabledTabCount {
    int count = 0;
    if (_showMovieTab) count++;
    if (_showBookTab) count++;
    if (_showNoteTab) count++;
    return count;
  }

  List<(int, String, IconData)> get _enabledTabs {
    final all = [
      (0, '影视', Icons.movie_outlined),
      (1, '阅读', Icons.menu_book_outlined),
      (2, '笔记', Icons.note_outlined),
    ];
    return all.where((t) {
      return switch (t.$1) {
        0 => _showMovieTab,
        1 => _showBookTab,
        2 => _showNoteTab,
        _ => false,
      };
    }).toList();
  }

  void _fixDefaultTabIndex() {
    final enabled = _enabledTabs;
    if (!enabled.any((t) => t.$1 == _defaultTabIndex) && enabled.isNotEmpty) {
      _defaultTabIndex = enabled.first.$1;
      _userPrefs.setDefaultMainTabIndex(_defaultTabIndex);
    }
  }

  Future<void> _toggleMovieTab(bool value) async {
    if (!value && _enabledTabCount <= 1) {
      ToastUtil.show(context, '至少保留一个标签页');
      return;
    }
    await _userPrefs.setShowMovieTab(value);
    setState(() {
      _showMovieTab = value;
      _fixDefaultTabIndex();
    });
  }

  Future<void> _toggleBookTab(bool value) async {
    if (!value && _enabledTabCount <= 1) {
      ToastUtil.show(context, '至少保留一个标签页');
      return;
    }
    await _userPrefs.setShowBookTab(value);
    setState(() {
      _showBookTab = value;
      _fixDefaultTabIndex();
    });
  }

  Future<void> _toggleNoteTab(bool value) async {
    if (!value && _enabledTabCount <= 1) {
      ToastUtil.show(context, '至少保留一个标签页');
      return;
    }
    await _userPrefs.setShowNoteTab(value);
    setState(() {
      _showNoteTab = value;
      _fixDefaultTabIndex();
    });
  }

  Future<void> _toggleNotePlusTab(bool value) async {
    await _userPrefs.setShowNotePlusTab(value);
    setState(() => _showNotePlusTab = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('功能设置')),
      body: ListView(
        children: [
          // ── 启动设置 ──
          _buildSectionHeader('启动设置'),
          _buildDefaultTabSelector(),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),

          // ── 模块开关 ──
          _buildSectionHeader('模块开关'),
          _buildSwitchItem(Icons.movie_outlined, '观影', '记录和管理观影记录',
              _showMovieTab, _toggleMovieTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.menu_book_outlined, '阅读', '记录和管理阅读记录',
              _showBookTab, _toggleBookTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.note_outlined, '笔记', '记录和管理笔记', _showNoteTab,
              _toggleNoteTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.edit_note, 'Note Plus', '块编辑器，支持富文本文档',
              _showNotePlusTab, _toggleNotePlusTab),

          // ── 侧边栏：信息模块 ──
          _buildSectionHeader('侧边栏 · 信息模块'),
          _buildSwitchItem(
              Icons.calendar_today, '热力图', '显示创作活跃度热力图', _showHeatmap,
              (v) async {
            await _userPrefs.setShowSidebarHeatmap(v);
            setState(() => _showHeatmap = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.schedule, '最近添加', '显示最近添加的记录', _showRecent,
              (v) async {
            await _userPrefs.setShowSidebarRecent(v);
            setState(() => _showRecent = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.favorite_border, '统计', '与应用相遇的天数和数据概览', _showEncounter,
              (v) async {
            await _userPrefs.setShowSidebarEncounter(v);
            setState(() => _showEncounter = v);
          }),

          // ── 侧边栏：快捷功能 ──
          _buildSectionHeader('侧边栏 · 快捷功能'),
          _buildSwitchItem(Icons.explore_outlined, '漫步', '随机发现内容', _showStroll,
              (v) async {
            await _userPrefs.setShowSidebarStroll(v);
            setState(() => _showStroll = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.calendar_month_outlined, '书影日历', '按日历查看记录', _showCalendar,
              (v) async {
            await _userPrefs.setShowSidebarCalendar(v);
            setState(() => _showCalendar = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.people_outline, '角色信息', '管理影视和书籍中的角色', _showPerson,
              (v) async {
            await _userPrefs.setShowSidebarPerson(v);
            setState(() => _showPerson = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.label_outline, '标签管理', '管理所有标签', _showTags,
              (v) async {
            await _userPrefs.setShowSidebarTags(v);
            setState(() => _showTags = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.description_outlined, 'MD阅读', 'Markdown 文件阅读器',
              _showMdReader, (v) async {
            await _userPrefs.setShowSidebarMdReader(v);
            setState(() => _showMdReader = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.auto_stories_outlined, 'EPUB阅读', 'EPUB 电子书阅读器', _showEpub,
              (v) async {
            await _userPrefs.setShowSidebarEpub(v);
            setState(() => _showEpub = v);
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text('关闭后对应功能将从界面中隐藏。',
                style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.3))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colors.onSurface)),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon,
              color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
      title: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
      trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: colors.primary,
          activeTrackColor: colors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: colors.surface,
          inactiveTrackColor: colors.outline),
    );
  }

  Widget _buildDefaultTabSelector() {
    final colors = Theme.of(context).colorScheme;
    final enabled = _enabledTabs;
    final currentLabel = enabled
        .firstWhere((t) => t.$1 == _defaultTabIndex,
            orElse: () => enabled.first)
        .$2;

    return InkWell(
      onTap: _showDefaultTabPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.home_outlined,
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('默认启动标签',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colors.onSurface)),
            ),
            Text(currentLabel,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }

  void _showDefaultTabPicker() {
    final colors = Theme.of(context).colorScheme;
    final enabled = _enabledTabs;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('默认启动标签',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)))),
            const SizedBox(height: 16),
            for (final t in enabled)
              ListTile(
                leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(t.$3,
                        color: colors.onSurface.withValues(alpha: 0.6))),
                title: Text(t.$2,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface)),
                trailing: _defaultTabIndex == t.$1
                    ? Icon(Icons.check, color: colors.onSurface, size: 20)
                    : null,
                onTap: () async {
                  await _userPrefs.setDefaultMainTabIndex(t.$1);
                  setState(() => _defaultTabIndex = t.$1);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── 布局设置 ──────────────────────────────────────────────────────────

class LayoutSettingsPage extends StatefulWidget {
  const LayoutSettingsPage({super.key});

  @override
  State<LayoutSettingsPage> createState() => _LayoutSettingsPageState();
}

class _LayoutSettingsPageState extends State<LayoutSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  int _noteLayout = 0;
  int _movieLayout = 0;
  int _bookLayout = 0;

  @override
  void initState() {
    super.initState();
    _noteLayout = _userPrefs.noteLayoutStyle;
    _movieLayout = _userPrefs.movieLayoutStyle;
    _bookLayout = _userPrefs.bookLayoutStyle;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('布局设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSection(
              '影视布局',
              [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.grid_view_outlined, size: 16),
                    label: Text('海报网格', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                    label: Text('列表', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.crop_landscape_outlined, size: 16),
                    label: Text('大图卡片', style: TextStyle(fontSize: 12))),
              ],
              _movieLayout,
              (v) => _setLayout('movie', v)),
          _buildSection(
              '阅读布局',
              [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.grid_view_outlined, size: 16),
                    label: Text('封面网格', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                    label: Text('列表', style: TextStyle(fontSize: 12))),
              ],
              _bookLayout,
              (v) => _setLayout('book', v)),
          _buildSection(
              '笔记布局',
              [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.view_list_outlined, size: 16),
                    label: Text('列表', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.grid_view_outlined, size: 16),
                    label: Text('瀑布流', style: TextStyle(fontSize: 12))),
                ButtonSegment(
                    value: 2,
                    icon: Icon(Icons.timeline_outlined, size: 16),
                    label: Text('时间线', style: TextStyle(fontSize: 12))),
              ],
              _noteLayout,
              (v) => _setLayout('note', v)),
        ],
      ),
    );
  }

  void _setLayout(String type, int value) async {
    switch (type) {
      case 'note':
        await _userPrefs.setNoteLayoutStyle(value);
        setState(() => _noteLayout = value);
      case 'movie':
        await _userPrefs.setMovieLayoutStyle(value);
        setState(() => _movieLayout = value);
        if (mounted) context.read<AppProvider>().setMovieLayoutStyle(value);
      case 'book':
        await _userPrefs.setBookLayoutStyle(value);
        setState(() => _bookLayout = value);
    }
  }

  Widget _buildSection(String title, List<ButtonSegment<int>> segments,
      int selected, ValueChanged<int> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
          ),
          SegmentedButton<int>(
            segments: segments,
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? colors.onSurface
                      : colors.surfaceContainerHighest),
              foregroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? colors.surface
                      : colors.onSurface.withValues(alpha: 0.6)),
              side: WidgetStateProperty.all(BorderSide.none),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 10)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.standard,
            ),
          ),
        ],
      ),
    );
  }
}

/// WebView 页面
class WebViewPage extends StatefulWidget {
  final String url;
  const WebViewPage({super.key, required this.url});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text(''), actions: [
        IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload())
      ]),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Center(
              child: CircularProgressIndicator(
                  color: colors.onSurface.withValues(alpha: 0.4)))
      ]),
    );
  }
}
