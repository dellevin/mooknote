import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';
import '../utils/toast_util.dart';
import 'recycle_bin_page.dart';
import 'sync/backup_page.dart';
import 'statistics_page.dart';
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

class _ProfilePageState extends State<ProfilePage> {
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

  Future<void> _loadUserData() async {
    try {
      await UserPrefs.init();
      setState(() {
        _nickname = _userPrefs.nickname;
        _motto = _userPrefs.motto;
        _avatarPath = _userPrefs.avatarPath;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF1A1A1A)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: const Text('我的'),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFF8F8F8),
            child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserCard(),
                const SizedBox(height: 8),
                _buildExploreRow(),
                const SizedBox(height: 20),
                _buildSectionHeader('数据'),
                _buildMenuGroup([
                  _MenuEntry(Icons.analytics_outlined, '数据统计', () => _push(context, const StatisticsPage())),
                  _MenuEntry(Icons.backup_outlined, '备份', () => _showBackupOptions(context)),
                  _MenuEntry(Icons.delete_outline, '回收站', () => _push(context, const RecycleBinPage())),
                ]),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      ],
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ─── 用户卡片 ────────────────────────────────────────────────────────

  Widget _buildUserCard() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final movieCount = provider.movies.where((m) => !m.isDeleted).length;
        final bookCount = provider.books.length;
        final noteCount = provider.notes.length;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF5F5F5),
                        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatarPath != null && _avatarPath!.isNotEmpty
                          ? Image.file(File(_avatarPath!), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person_outline, size: 32, color: Color(0xFFCCCCCC)))
                          : const Icon(Icons.person_outline, size: 32, color: Color(0xFFCCCCCC)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _editNickname(context),
                          child: Text(_nickname, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _editMotto(context),
                          child: Text(_motto, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: Color(0xFF999999)),
                    onPressed: () => _showSettings(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 12),
              _buildStatRow(Icons.movie_outlined, _formatCount(movieCount), '观影'),
              const SizedBox(height: 8),
              _buildStatRow(Icons.menu_book_outlined, _formatCount(bookCount), '阅读'),
              const SizedBox(height: 8),
              _buildStatRow(Icons.note_outlined, _formatCount(noteCount), '笔记'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(IconData icon, String count, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFFBBBBBB)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
        const Spacer(),
        Text(count, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  // ─── 探索行 ──────────────────────────────────────────────────────────

  Widget _buildExploreRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFBBBBBB)),
          const SizedBox(width: 10),
          const Text('快捷入口', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
          const Spacer(),
          _buildQuickAction(Icons.explore_outlined, '漫步', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrollPage()))),
          const SizedBox(width: 24),
          _buildQuickAction(Icons.label_outline, '标签', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TagManagementPage()))),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF555555)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  // ─── 菜单 ────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFBBBBBB))),
    );
  }

  Widget _buildMenuGroup(List<_MenuEntry> entries) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: entries.asMap().entries.map((e) {
          final isLast = e.key == entries.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: e.value.onTap,
                borderRadius: BorderRadius.only(
                  topLeft: e.key == 0 ? const Radius.circular(16) : Radius.zero,
                  topRight: e.key == 0 ? const Radius.circular(16) : Radius.zero,
                  bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(e.value.icon, size: 18, color: const Color(0xFF666666)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)))),
                      const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD0D0D0)),
                    ],
                  ),
                ),
              ),
              if (!isLast) const Divider(height: 1, indent: 68, endIndent: 20, color: Color(0xFFF0F0F0)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── 头像 ────────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 85);
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

  void _editNickname(BuildContext context) {
    final controller = TextEditingController(text: _nickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('修改昵称', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: '输入昵称', border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E5E5))))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Color(0xFF666666)))),
          TextButton(onPressed: () async {
            final newNickname = controller.text.trim();
            if (newNickname.isNotEmpty) {
              await _userPrefs.setNickname(newNickname);
              setState(() => _nickname = newNickname);
            }
            Navigator.pop(context);
          }, child: const Text('确定')),
        ],
      ),
    );
  }

  void _editMotto(BuildContext context) {
    final controller = TextEditingController(text: _motto);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('修改座右铭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        content: TextField(controller: controller, maxLines: 2, decoration: const InputDecoration(hintText: '输入座右铭', border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE5E5E5))))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Color(0xFF666666)))),
          TextButton(onPressed: () async {
            final newMotto = controller.text.trim();
            await _userPrefs.setMotto(newMotto);
            setState(() => _motto = newMotto);
            Navigator.pop(context);
          }, child: const Text('确定')),
        ],
      ),
    );
  }

  // ─── 备份弹窗 ────────────────────────────────────────────────────────

  void _showBackupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text('选择备份方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.folder_outlined, color: Color(0xFF666666))),
              title: const Text('本地备份', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
              subtitle: const Text('备份到本地文件夹，支持恢复', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
              onTap: () { Navigator.pop(ctx); _push(context, const BackupPage()); },
            ),
            const Divider(height: 0.5, color: Color(0xFFF0F0F0)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.cloud_outlined, color: Color(0xFF666666))),
              title: const Text('云备份', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
              subtitle: const Text('通过 WebDAV 同步到云端', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC)),
              onTap: () { Navigator.pop(ctx); _push(context, const CloudSyncPage()); },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    _push(context, const SettingsPage());
  }
}

// ─── 数据类 ────────────────────────────────────────────────────────────

class _MenuEntry {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  _MenuEntry(this.icon, this.title, this.onTap);
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

  @override
  void initState() {
    super.initState();
    _hideBottomNavOnScroll = _userPrefs.hideBottomNavOnScroll;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _buildSectionHeader('数据管理'),
          _buildActionItem(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存数据',
            subtitle: '清理未在数据库中引用的图片文件',
            onTap: () => _showClearCacheDialog(context),
          ),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSwitchItem(
            icon: Icons.swipe_vertical_outlined,
            title: '底部导航栏滚动隐藏',
            subtitle: '下滑时自动隐藏底部导航栏',
            value: _hideBottomNavOnScroll,
            onChanged: _toggleHideBottomNavOnScroll,
          ),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildNavigationItem(
            icon: Icons.apps_outlined,
            title: '应用图标',
            subtitle: '更换桌面应用图标',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppIconPickerPage())),
          ),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildNavigationItem(
            icon: Icons.view_list_outlined,
            title: '主界面设置',
            subtitle: '启动标签、模块显示开关',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainContentSettingsPage())),
          ),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildNavigationItem(
            icon: Icons.dashboard_outlined,
            title: '布局设置',
            subtitle: '笔记、影视、阅读的展示样式',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayoutSettingsPage())),
          ),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSectionHeader('帮助'),
          _buildLinkItem(
            context: context,
            icon: Icons.help_outline,
            title: '使用说明',
            subtitle: '查看应用使用指南',
            url: 'https://mooknote.iletter.top/#/guide',
          ),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
        ],
      ),
    );
  }

  Future<void> _toggleHideBottomNavOnScroll(bool value) async {
    await _userPrefs.setHideBottomNavOnScroll(value);
    setState(() => _hideBottomNavOnScroll = value);
  }

  Widget _buildSwitchItem({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF666666), size: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ]),
            ),
            Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF1A1A1A), activeTrackColor: const Color(0xFF1A1A1A).withOpacity(0.3), inactiveThumbColor: Colors.white, inactiveTrackColor: const Color(0xFFE5E5E5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
    );
  }

  Widget _buildNavigationItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF666666), size: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ]),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkItem({required BuildContext context, required IconData icon, required String title, required String subtitle, required String url}) {
    return InkWell(
      onTap: () => _launchUrl(context, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF666666), size: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ]),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFFCCCCCC), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF666666), size: 22)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearCacheDialog(BuildContext pageContext) {
    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('清除缓存数据'),
        content: const Text('这将删除所有未在数据库中引用的图片文件。确定要继续吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消', style: TextStyle(color: Color(0xFF666666)))),
          TextButton(onPressed: () async {
            Navigator.pop(dialogContext);
            await _clearCacheData(pageContext);
          }, child: const Text('确定', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  Future<void> _clearCacheData(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
      final appProvider = context.read<AppProvider>();
      final dbImagePaths = await _getAllDbImagePaths(appProvider);
      final deletedCount = await _cleanImageDirectory(dbImagePaths);
      Navigator.pop(context);
      if (context.mounted) ToastUtil.show(context, '已清理 $deletedCount 个缓存文件');
    } catch (e) {
      Navigator.pop(context);
      if (context.mounted) ToastUtil.show(context, '清理失败: $e');
    }
  }

  Future<Set<String>> _getAllDbImagePaths(AppProvider provider) async {
    final paths = <String>{};
    for (final movie in provider.movies) { if (movie.posterPath?.isNotEmpty == true) paths.add(movie.posterPath!); }
    for (final book in provider.books) { if (book.coverPath?.isNotEmpty == true) paths.add(book.coverPath!); }
    for (final note in provider.notes) { for (final p in note.images) { if (p.isNotEmpty) paths.add(p); } }
    for (final movieId in provider.movies.map((m) => m.id)) {
      for (final poster in await provider.getMoviePosters(movieId)) { if (poster.posterPath.isNotEmpty) paths.add(poster.posterPath); }
    }
    return paths;
  }

  Future<int> _cleanImageDirectory(Set<String> dbImagePaths) async {
    int deletedCount = 0;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/images');
      if (!await imagesDir.exists()) return 0;
      await for (final entity in imagesDir.list(recursive: true, followLinks: false)) {
        if (entity is File && !dbImagePaths.contains(entity.path)) {
          try { await entity.delete(); deletedCount++; } catch (_) {}
        }
      }
    } catch (e) { debugPrint('清理图片目录失败: $e'); }
    return deletedCount;
  }

  void _launchUrl(BuildContext context, String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => WebViewPage(url: url)));
  }
}

// ─── 主界面设置 ────────────────────────────────────────────────────────

class MainContentSettingsPage extends StatefulWidget {
  const MainContentSettingsPage({super.key});

  @override
  State<MainContentSettingsPage> createState() => _MainContentSettingsPageState();
}

class _MainContentSettingsPageState extends State<MainContentSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  bool _showMovieTab = true;
  bool _showBookTab = true;
  bool _showNoteTab = true;
  int _defaultTabIndex = 0;

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
      _defaultTabIndex = _userPrefs.defaultMainTabIndex;
    });
  }

  int get _enabledTabCount {
    int count = 0;
    if (_showMovieTab) count++;
    if (_showBookTab) count++;
    if (_showNoteTab) count++;
    return count;
  }

  Future<void> _toggleMovieTab(bool value) async {
    if (!value && _enabledTabCount <= 1) { ToastUtil.show(context, '至少保留一个标签页'); return; }
    await _userPrefs.setShowMovieTab(value);
    setState(() => _showMovieTab = value);
  }

  Future<void> _toggleBookTab(bool value) async {
    if (!value && _enabledTabCount <= 1) { ToastUtil.show(context, '至少保留一个标签页'); return; }
    await _userPrefs.setShowBookTab(value);
    setState(() => _showBookTab = value);
  }

  Future<void> _toggleNoteTab(bool value) async {
    if (!value && _enabledTabCount <= 1) { ToastUtil.show(context, '至少保留一个标签页'); return; }
    await _userPrefs.setShowNoteTab(value);
    setState(() => _showNoteTab = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('主界面设置')),
      body: ListView(
        children: [
          _buildSectionHeader('启动设置'),
          _buildDefaultTabSelector(),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSectionHeader('模块开关'),
          _buildSwitchItem(Icons.movie_outlined, '观影', '记录和管理观影记录', _showMovieTab, _toggleMovieTab),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSwitchItem(Icons.menu_book_outlined, '阅读', '记录和管理阅读记录', _showBookTab, _toggleBookTab),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSwitchItem(Icons.note_outlined, '笔记', '记录和管理笔记', _showNoteTab, _toggleNoteTab),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: const Text('至少保留一个模块，关闭后对应标签页将不再显示。', style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF666666), size: 22)),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF1A1A1A), activeTrackColor: const Color(0xFF1A1A1A).withOpacity(0.3), inactiveThumbColor: Colors.white, inactiveTrackColor: const Color(0xFFE5E5E5)),
    );
  }

  Widget _buildDefaultTabSelector() {
    final labels = ['影视', '阅读', '笔记'];
    final icons = [Icons.movie_outlined, Icons.menu_book_outlined, Icons.note_outlined];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.home_outlined, color: Color(0xFF666666), size: 22)),
      title: const Text('默认启动标签', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
      subtitle: const Text('打开应用时默认显示的页面', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labels[_defaultTabIndex], style: const TextStyle(fontSize: 14, color: Color(0xFF999999))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
        ],
      ),
      onTap: () => _showDefaultTabPicker(labels, icons),
    );
  }

  void _showDefaultTabPicker(List<String> labels, List<IconData> icons) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('默认启动标签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))))),
            const SizedBox(height: 16),
            for (int i = 0; i < labels.length; i++)
              ListTile(
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icons[i], color: const Color(0xFF666666))),
                title: Text(labels[i], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                trailing: _defaultTabIndex == i ? const Icon(Icons.check, color: Color(0xFF1A1A1A), size: 20) : null,
                onTap: () async { await _userPrefs.setDefaultMainTabIndex(i); setState(() => _defaultTabIndex = i); Navigator.pop(ctx); },
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('布局设置')),
      body: ListView(
        children: [
          _buildSectionHeader('笔记布局'),
          _buildLayoutOption(icon: Icons.view_list_outlined, title: '列表布局', subtitle: '单列列表，简洁清晰', value: 0, groupValue: _noteLayout, onTap: () => _setLayout('note', 0)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildLayoutOption(icon: Icons.grid_view_outlined, title: '瀑布流布局', subtitle: '双列卡片，图文并茂', value: 1, groupValue: _noteLayout, onTap: () => _setLayout('note', 1)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildLayoutOption(icon: Icons.timeline_outlined, title: '时间线布局', subtitle: '按时间排列，纵览全局', value: 2, groupValue: _noteLayout, onTap: () => _setLayout('note', 2)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSectionHeader('影视布局'),
          _buildLayoutOption(icon: Icons.grid_view_outlined, title: '海报网格', subtitle: '三列海报，赏心悦目', value: 0, groupValue: _movieLayout, onTap: () => _setLayout('movie', 0)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildLayoutOption(icon: Icons.view_list_outlined, title: '列表布局', subtitle: '单列卡片，信息一览', value: 1, groupValue: _movieLayout, onTap: () => _setLayout('movie', 1)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildSectionHeader('阅读布局'),
          _buildLayoutOption(icon: Icons.grid_view_outlined, title: '封面网格', subtitle: '三列封面，清新雅致', value: 0, groupValue: _bookLayout, onTap: () => _setLayout('book', 0)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
          _buildLayoutOption(icon: Icons.view_list_outlined, title: '列表布局', subtitle: '单列卡片，信息一览', value: 1, groupValue: _bookLayout, onTap: () => _setLayout('book', 1)),
          const Divider(height: 0.5, indent: 24, endIndent: 24),
        ],
      ),
    );
  }

  void _setLayout(String type, int value) async {
    switch (type) {
      case 'note': await _userPrefs.setNoteLayoutStyle(value); setState(() => _noteLayout = value);
      case 'movie': await _userPrefs.setMovieLayoutStyle(value); setState(() => _movieLayout = value);
      case 'book': await _userPrefs.setBookLayoutStyle(value); setState(() => _bookLayout = value);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
    );
  }

  Widget _buildLayoutOption({required IconData icon, required String title, required String subtitle, required int value, required int groupValue, required VoidCallback onTap}) {
    final selected = value == groupValue;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: const Color(0xFF666666), size: 22)),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
      trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF1A1A1A), size: 20) : const Icon(Icons.circle_outlined, color: Color(0xFFDDDDDD), size: 20),
      onTap: onTap,
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text(''), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload())]),
      body: Stack(children: [WebViewWidget(controller: _controller), if (_isLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF999999)))]),
    );
  }
}
