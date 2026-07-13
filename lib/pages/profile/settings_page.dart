import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/theme/app_theme.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../data/database_helper.dart';
import '../../services/sync/cache_cleaner.dart';
import '../online_search/enhanced_search_settings_page.dart';
import '../settings/legal_page.dart';
import 'app_icon_picker_page.dart';
import 'feature_settings_page.dart';
import 'layout_settings_page.dart';
import 'changelog_page.dart';
import 'font_picker_page.dart';

/// 设置页面
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
          if (!Platform.isWindows) ...[
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
          ],
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
          if (!Platform.isWindows) _buildFontSelector(),
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
          if (!Platform.isWindows) ...[
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
          ],
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
          if (!Platform.isWindows) ...[
            _buildActionItem(
              icon: Icons.folder_outlined,
              title: '获取系统权限',
              subtitle: '前往系统设置开启存储权限',
              onTap: _showStoragePermissionDialog,
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          ],
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

  Widget _buildFontSelector() {
    final colors = Theme.of(context).colorScheme;
    final label = _fontFamily.isEmpty ? '系统默认' : _fontFamily;
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
              builder: (_) => const FontPickerPage(initialFamily: '')),
        );
        if (result != null && mounted) {
          _setFontFamily(result);
        }
      },
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

  void _showStoragePermissionDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('需要存储权限',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        content: Text(
          'Android 11+ 需要在系统设置中授予"所有文件访问权限"才能扫描字体文件。\n\n是否前往设置？',
          style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.6),
              height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消',
                style:
                    TextStyle(color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 跳转到应用设置页（用户可在权限中找到"所有文件访问"）
              openAppSettings();
            },
            child: Text('前往设置', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext pageContext) async {
    final colors = Theme.of(context).colorScheme;
    // 先扫描分析
    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: colors.primary)),
    );

    final dbImagePaths = await _getAllDbImagePaths();

    final imageInfo = await _scanImageDirectory(dbImagePaths);
    final epubInfo = await _scanOrphanedEpubBooks();
    final tempInfo = await _scanTempDirectory();
    final emptyDirInfo = await _scanEmptyDirectories();

    if (!pageContext.mounted) return;
    Navigator.pop(pageContext); // 关闭 loading

    final totalSize = imageInfo.$2 + epubInfo.$2 + tempInfo.$2 + emptyDirInfo.$2;
    final totalCount = imageInfo.$1 + epubInfo.$1 + tempInfo.$1 + emptyDirInfo.$1;
    if (totalCount == 0) {
      ToastUtil.show(pageContext, '没有需要清理的缓存');
      return;
    }

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('缓存分析',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('共发现 $totalCount 项可清理缓存，合计 ${_formatSize(totalSize)}',
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 14),
            if (imageInfo.$1 > 0) _buildCacheItem('孤立图片', imageInfo.$1, imageInfo.$2, Icons.image_outlined, colors),
            if (epubInfo.$1 > 0) _buildCacheItem('孤立电子书', epubInfo.$1, epubInfo.$2, Icons.menu_book_outlined, colors),
            if (tempInfo.$1 > 0) _buildCacheItem('临时文件', tempInfo.$1, tempInfo.$2, Icons.folder_outlined, colors),
            if (emptyDirInfo.$1 > 0) _buildCacheItem('空文件夹', emptyDirInfo.$1, emptyDirInfo.$2, Icons.folder_off_outlined, colors),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _clearCacheData(pageContext);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('确认清除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildCacheItem(String label, int count, int size, IconData icon, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
          ),
          Text('$count项  ${_formatSize(size)}',
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCacheData(BuildContext context) async {
    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));
      final result = await CacheCleaner.instance.clean();
      Navigator.pop(context);
      if (context.mounted) {
        if (result.total == 0) {
          ToastUtil.show(context, '没有需要清理的缓存');
        } else {
          ToastUtil.show(context, result.description);
        }
      }
    } catch (e) {
      Navigator.pop(context);
      if (context.mounted) ToastUtil.show(context, '清理失败: $e');
    }
  }

  /// 直接查 DB 收集所有图片路径（含软删除记录，与 CacheCleaner 保持一致）
  Future<Set<String>> _getAllDbImagePaths() async {
    final db = await DatabaseHelper.instance.database;
    final paths = <String>{};

    final movies = await db.query('movies', columns: ['poster_path']);
    for (final m in movies) {
      final p = m['poster_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    final books = await db.query('books', columns: ['cover_path']);
    for (final b in books) {
      final p = b['cover_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    final notes = await db.query('notes', columns: ['images']);
    for (final n in notes) {
      final imagesJson = n['images'] as String?;
      if (imagesJson != null && imagesJson.isNotEmpty) {
        try {
          for (final ip in jsonDecode(imagesJson) as List<dynamic>) {
            if (ip is String && ip.isNotEmpty) paths.add(ip);
          }
        } catch (_) {}
      }
    }

    final moviePosters = await db.query('movie_posters', columns: ['poster_path']);
    for (final p in moviePosters) {
      final pp = p['poster_path'] as String?;
      if (pp != null && pp.isNotEmpty) paths.add(pp);
    }

    final games = await db.query('games', columns: ['cover_path']);
    for (final g in games) {
      final p = g['cover_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    final gameScreenshots = await db.query('game_screenshots', columns: ['screenshot_path']);
    for (final s in gameScreenshots) {
      final p = s['screenshot_path'] as String?;
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    final userPrefs = UserPrefs();
    final avatarPath = userPrefs.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) paths.add(avatarPath);

    return paths;
  }

  /// 从绝对路径中提取 epub_books/ 下的目录名
  /// 兼容 Windows(\) 和 Unix(/) 分隔符
  void _collectEpubDirName(String? pathStr, Set<String> dirs) {
    if (pathStr == null || pathStr.isEmpty) return;
    final unified = pathStr.replaceAll('\\', '/');
    final marker = '/epub_books/';
    final idx = unified.indexOf(marker);
    if (idx < 0) return;
    final rest = unified.substring(idx + marker.length);
    final slashIdx = rest.indexOf('/');
    dirs.add(slashIdx >= 0 ? rest.substring(0, slashIdx) : rest);
  }

  // ─── 扫描方法（只统计不删除） ──────────────────────────────────────────────

  /// 返回 (文件数, 总字节数)
  Future<(int, int)> _scanImageDirectory(Set<String> dbImagePaths) async {
    int count = 0, totalSize = 0;
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final imagesDir = Directory(path.join(appDirPath, 'images'));
      if (!await imagesDir.exists()) return (0, 0);
      final normalizedDbPaths = dbImagePaths.map(_normalizePath).toSet();
      await for (final entity in imagesDir.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            !normalizedDbPaths.contains(_normalizePath(entity.path)) &&
            !path.basename(entity.path).startsWith('avatar')) {
          try {
            totalSize += await entity.length();
            count++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return (count, totalSize);
  }

  /// 规范化路径用于跨平台比较（统一分隔符）
  String _normalizePath(String p) {
    return path.normalize(p.replaceAll('\\', '/'));
  }

  Future<(int, int)> _scanOrphanedEpubBooks() async {
    int count = 0, totalSize = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('reader_books', columns: ['id', 'file_path', 'cover_path', 'is_deleted']);
      final usedDirs = <String>{};
      for (final r in rows) {
        final isDeleted = r['is_deleted'] == 1 || r['is_deleted'] == true;
        if (isDeleted) continue;
        final id = r['id'] as String?;
        if (id != null && id.isNotEmpty) usedDirs.add(id);
        _collectEpubDirName(r['file_path'] as String?, usedDirs);
        _collectEpubDirName(r['cover_path'] as String?, usedDirs);
      }
      final appDirPath = await ImagePathHelper.getAppDir();
      final possiblePaths = [
        path.join(appDirPath, 'epub_books'),
        '/data/user/0/top.iletter.mooknote/app_flutter/epub_books',
      ];
      for (final epubPath in possiblePaths) {
        final epubDir = Directory(epubPath);
        if (!await epubDir.exists()) continue;
        await for (final entity in epubDir.list(followLinks: false)) {
          if (entity is Directory) {
            final dirName = path.basename(entity.path);
            if (!usedDirs.contains(dirName)) {
              try {
                totalSize += await _dirSize(entity);
                count++;
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    return (count, totalSize);
  }

  Future<(int, int)> _scanTempDirectory() async {
    int count = 0, totalSize = 0;
    final now = DateTime.now();
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
                  totalSize += await entity.length();
                  count++;
                }
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    try {
      final cacheDir = await getApplicationCacheDirectory();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final name = path.basename(entity.path);
            if (name.startsWith('book_poster_') ||
                name.startsWith('movie_poster_') ||
                name.startsWith('note_share_') ||
                name.startsWith('mooknote_download') ||
                name.startsWith('mooknote_bidir')) {
              try {
                totalSize += await entity.length();
                count++;
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
    return (count, totalSize);
  }

  Future<(int, int)> _scanEmptyDirectories() async {
    int count = 0;
    try {
      final appDirPath = await ImagePathHelper.getAppDir();
      final cacheDir = await getApplicationCacheDirectory();
      final dirs = [
        Directory(path.join(appDirPath, 'images')),
        Directory(path.join(appDirPath, 'epub_books')),
        cacheDir,
      ];
      for (final dir in dirs) {
        if (!await dir.exists()) continue;
        count += await _countEmptyDirsRecursive(dir);
      }
    } catch (_) {}
    return (count, 0);
  }

  Future<int> _dirSize(Directory dir) async {
    int size = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try { size += await entity.length(); } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  Future<int> _countEmptyDirsRecursive(Directory dir) async {
    int count = 0;
    try {
      final children = await dir.list(followLinks: false).toList();
      for (final child in children) {
        if (child is Directory) {
          count += await _countEmptyDirsRecursive(child);
          final remaining = await child.list(followLinks: false).toList();
          if (remaining.isEmpty) count++;
        }
      }
    } catch (_) {}
    return count;
  }
}
