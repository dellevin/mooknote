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
import '../widgets/fade_in_local_image.dart';
import 'statistics_page.dart';
import 'changelog_page.dart';
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
          child: Container(
            color: colors.surfaceContainerHigh,
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
        final colors = Theme.of(context).colorScheme;
        final movieCount = provider.movies.where((m) => !m.isDeleted).length;
        final bookCount = provider.books.length;
        final noteCount = provider.notes.length;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.surface,
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
                        color: colors.surfaceContainerHighest,
                        border: Border.all(color: colors.outlineVariant, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _avatarPath != null && _avatarPath!.isNotEmpty
                          ? FadeInLocalImage(path: _avatarPath, fit: BoxFit.cover,
                              errorWidget: Icon(Icons.person_outline, size: 32, color: colors.onSurface.withValues(alpha: 0.25)))
                          : Icon(Icons.person_outline, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _editNickname(context),
                          child: Text(_nickname, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _editMotto(context),
                          child: Text(_motto, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: colors.onSurface.withValues(alpha: 0.4)),
                    onPressed: () => _showSettings(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.outlineVariant),
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
        const Spacer(),
        Text(count, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface)),
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
          const SizedBox(width: 10),
          Text('快捷入口', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
          const Spacer(),
          _buildQuickAction(Icons.explore_outlined, '漫步', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StrollPage()))),
          const SizedBox(width: 24),
          _buildQuickAction(Icons.label_outline, '标签', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TagManagementPage()))),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.7)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  // ─── 菜单 ────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.3))),
    );
  }

  Widget _buildMenuGroup(List<_MenuEntry> entries) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface,
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
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(e.value.icon, size: 18, color: colors.onSurface.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.value.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface))),
                      Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
                    ],
                  ),
                ),
              ),
              if (!isLast) Divider(height: 1, indent: 68, endIndent: 20, color: colors.outlineVariant),
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
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _nickname);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('修改昵称', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(controller: controller,
            style: TextStyle(fontSize: 14, color: colors.onSurface),
            decoration: InputDecoration(
              hintText: '输入昵称',
              hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1.5)),
            )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isNotEmpty) {
                await _userPrefs.setNickname(newNickname);
                setState(() => _nickname = newNickname);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('确定'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _editMotto(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _motto);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('修改座右铭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(controller: controller, maxLines: 2,
            style: TextStyle(fontSize: 14, color: colors.onSurface),
            decoration: InputDecoration(
              hintText: '输入座右铭',
              hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: colors.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1.5)),
            )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              final newMotto = controller.text.trim();
              await _userPrefs.setMotto(newMotto);
              setState(() => _motto = newMotto);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('确定'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // ─── 备份弹窗 ────────────────────────────────────────────────────────

  void _showBackupOptions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerLeft, child: Text('选择备份方式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.folder_outlined, color: colors.onSurface.withValues(alpha: 0.6))),
              title: Text('本地备份', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
              subtitle: Text('备份到本地文件夹，支持恢复', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () { Navigator.pop(ctx); _push(context, const BackupPage()); },
            ),
            Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.cloud_outlined, color: colors.onSurface.withValues(alpha: 0.6))),
              title: Text('云备份', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
              subtitle: Text('通过 WebDAV 同步到云端', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
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
  int _themeMode = 0; // 0=系统, 1=浅色, 2=深色

  @override
  void initState() {
    super.initState();
    _hideBottomNavOnScroll = _userPrefs.hideBottomNavOnScroll;
    _themeMode = _userPrefs.themeMode;
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
          _buildNavigationItem(
            icon: Icons.apps_outlined,
            title: '应用图标',
            subtitle: '更换桌面应用图标',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppIconPickerPage())),
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildNavigationItem(
            icon: Icons.view_list_outlined,
            title: '主界面设置',
            subtitle: '启动标签、模块显示开关',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainContentSettingsPage())),
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildNavigationItem(
            icon: Icons.dashboard_outlined,
            title: '布局设置',
            subtitle: '影视、阅读、笔记的展示样式',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LayoutSettingsPage())),
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildThemeModeSelector(),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildSectionHeader('其他设置'),
          _buildSwitchItem(
            icon: Icons.swipe_vertical_outlined,
            title: '底部导航栏滚动隐藏',
            subtitle: '下滑时自动隐藏底部导航栏',
            value: _hideBottomNavOnScroll,
            onChanged: _toggleHideBottomNavOnScroll,
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildSectionHeader('数据管理'),
          _buildActionItem(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存数据',
            subtitle: '清理未在数据库中引用的图片文件',
            onTap: () => _showClearCacheDialog(context),
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildSectionHeader('帮助'),
          _buildActionItem(
            icon: Icons.update_outlined,
            title: '更新日志',
            subtitle: '查看版本更新内容',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogPage())),
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildLinkItem(
            context: context,
            icon: Icons.help_outline,
            title: '使用说明',
            subtitle: '查看应用使用指南',
            url: 'https://mooknote.iletter.top/#/guide',
          ),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
        ],
      ),
    );
  }

  Future<void> _toggleHideBottomNavOnScroll(bool value) async {
    await _userPrefs.setHideBottomNavOnScroll(value);
    setState(() => _hideBottomNavOnScroll = value);
  }

  static const _themeModeLabels = ['跟随系统', '浅色模式', '深色模式'];
  static const _themeModeIcons = [Icons.brightness_auto, Icons.light_mode, Icons.dark_mode];

  Widget _buildThemeModeSelector() {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showThemeModePicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(_themeModeIcons[_themeMode], color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('主题模式', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(_themeModeLabels[_themeMode], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              ]),
            ),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25), size: 20),
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
        decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('主题模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
            const SizedBox(height: 16),
            for (int i = 0; i < _themeModeLabels.length; i++)
              ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(_themeModeIcons[i], color: colors.onSurface.withValues(alpha: 0.6))),
                title: Text(_themeModeLabels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                trailing: _themeMode == i ? Icon(Icons.check, color: colors.onSurface, size: 20) : null,
                onTap: () async { await _setThemeMode(i); Navigator.pop(ctx); },
              ),
            const SizedBox(height: 8),
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

  Widget _buildSwitchItem({required IconData icon, required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              ]),
            ),
            Switch(value: value, onChanged: onChanged, activeColor: colors.primary, activeTrackColor: colors.primary.withOpacity(0.3), inactiveThumbColor: colors.surface, inactiveTrackColor: colors.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface)),
    );
  }

  Widget _buildNavigationItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              ]),
            ),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkItem({required BuildContext context, required IconData icon, required String title, required String subtitle, required String url}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _launchUrl(context, url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              ]),
            ),
            Icon(Icons.open_in_new, color: colors.onSurface.withValues(alpha: 0.25), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
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
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('清除缓存数据', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('这将删除所有未在数据库中引用的图片文件。确定要继续吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _clearCacheData(pageContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('清除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        if (entity is File && !dbImagePaths.contains(entity.path) && !path.basename(entity.path).startsWith('avatar')) {
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('主界面设置')),
      body: ListView(
        children: [
          _buildSectionHeader('启动设置'),
          _buildDefaultTabSelector(),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildSectionHeader('模块开关'),
          _buildSwitchItem(Icons.movie_outlined, '观影', '记录和管理观影记录', _showMovieTab, _toggleMovieTab),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildSwitchItem(Icons.menu_book_outlined, '阅读', '记录和管理阅读记录', _showBookTab, _toggleBookTab),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          _buildSwitchItem(Icons.note_outlined, '笔记', '记录和管理笔记', _showNoteTab, _toggleNoteTab),
          Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Text('至少保留一个模块，关闭后对应标签页将不再显示。', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface)),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: colors.primary, activeTrackColor: colors.primary.withOpacity(0.3), inactiveThumbColor: colors.surface, inactiveTrackColor: colors.outline),
    );
  }

  Widget _buildDefaultTabSelector() {
    final colors = Theme.of(context).colorScheme;
    final labels = ['影视', '阅读', '笔记'];
    final icons = [Icons.movie_outlined, Icons.menu_book_outlined, Icons.note_outlined];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.home_outlined, color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
      title: Text('默认启动标签', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
      subtitle: Text('打开应用时默认显示的页面', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labels[_defaultTabIndex], style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25), size: 20),
        ],
      ),
      onTap: () => _showDefaultTabPicker(labels, icons),
    );
  }

  void _showDefaultTabPicker(List<String> labels, List<IconData> icons) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('默认启动标签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)))),
            const SizedBox(height: 16),
            for (int i = 0; i < labels.length; i++)
              ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(icons[i], color: colors.onSurface.withValues(alpha: 0.6))),
                title: Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                trailing: _defaultTabIndex == i ? Icon(Icons.check, color: colors.onSurface, size: 20) : null,
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('布局设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildSection('影视布局', [
            ButtonSegment(value: 0, icon: Icon(Icons.grid_view_outlined, size: 16), label: Text('海报网格', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 1, icon: Icon(Icons.view_list_outlined, size: 16), label: Text('列表', style: TextStyle(fontSize: 12))),
          ], _movieLayout, (v) => _setLayout('movie', v)),
          _buildSection('阅读布局', [
            ButtonSegment(value: 0, icon: Icon(Icons.grid_view_outlined, size: 16), label: Text('封面网格', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 1, icon: Icon(Icons.view_list_outlined, size: 16), label: Text('列表', style: TextStyle(fontSize: 12))),
          ], _bookLayout, (v) => _setLayout('book', v)),
          _buildSection('笔记布局', [
            ButtonSegment(value: 0, icon: Icon(Icons.view_list_outlined, size: 16), label: Text('列表', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 1, icon: Icon(Icons.grid_view_outlined, size: 16), label: Text('瀑布流', style: TextStyle(fontSize: 12))),
            ButtonSegment(value: 2, icon: Icon(Icons.timeline_outlined, size: 16), label: Text('时间线', style: TextStyle(fontSize: 12))),
          ], _noteLayout, (v) => _setLayout('note', v)),
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

  Widget _buildSection(String title, List<ButtonSegment<int>> segments, int selected, ValueChanged<int> onChanged) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ),
          SegmentedButton<int>(
            segments: segments,
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? colors.onSurface : colors.surfaceContainerHighest),
              foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? colors.surface : colors.onSurface.withValues(alpha: 0.6)),
              side: WidgetStateProperty.all(BorderSide.none),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 10)),
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
      appBar: AppBar(title: const Text(''), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => _controller.reload())]),
      body: Stack(children: [WebViewWidget(controller: _controller), if (_isLoading) Center(child: CircularProgressIndicator(color: colors.onSurface.withValues(alpha: 0.4)))]),
    );
  }
}
