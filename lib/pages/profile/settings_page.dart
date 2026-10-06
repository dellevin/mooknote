import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/platform_utils.dart';
import '../../utils/theme/app_theme.dart';
import '../../utils/toast_util.dart';
import '../../services/media_scan_channel.dart';
import '../../services/log_service.dart';
import '../online_search/enhanced_search_settings_page.dart';
import '../settings/legal_page.dart';
import '../settings/debug_log_page.dart';
import 'app_icon_picker_page.dart';
import 'feature_settings_page.dart';
import 'layout_settings_page.dart';
import 'detail_module_settings_page.dart';
import 'changelog_page.dart';
import 'font_picker_page.dart';
import 'cache_cleaner_page.dart';
import 'permissions_page.dart';
import '../../widgets/app_overlay.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  bool _hideBottomNavOnScroll = true;
  bool _debugMode = false;
  int _themeMode = 0; // 0=系统, 1=浅色, 2=深色
  String _fontFamily = '';

  @override
  void initState() {
    super.initState();
    _hideBottomNavOnScroll = _userPrefs.hideBottomNavOnScroll;
    _debugMode = _userPrefs.debugMode;
    _themeMode = _userPrefs.themeMode;
    _fontFamily = _userPrefs.fontFamily;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('设置'.tr)),
      body: ListView(
        children: [
          _buildSectionHeader('显示设置'.tr),
          // 应用图标仅 Android 有原生实现（app_icon_channel）
          if (Platform.isAndroid)
            _buildNavigationItem(
              icon: Icons.apps_outlined,
              title: '应用图标'.tr,
              subtitle: '更换桌面应用图标'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AppIconPickerPage())),
            ),
          if (Platform.isAndroid)
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          if (!PlatformUtils.isDesktop) ...[
            _buildNavigationItem(
              icon: Icons.tune_outlined,
              title: '功能设置'.tr,
              subtitle: '启动标签、模块开关、侧边栏功能'.tr,
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
              title: '布局设置'.tr,
              subtitle: '影视、阅读、笔记的展示样式'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LayoutSettingsPage())),
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          ],
          _buildNavigationItem(
            icon: Icons.view_agenda_outlined,
            title: '详情页设置'.tr,
            subtitle: '详情页各模块的显示与排序'.tr,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DetailModuleSettingsPage())),
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
          if (!PlatformUtils.isDesktop) _buildFontSelector(),
          if (!PlatformUtils.isDesktop)
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          _buildLanguageSelector(),
          _buildSectionHeader('其他设置'.tr),
          _buildActionItem(
            icon: Icons.person_outline,
            title: '个人信息'.tr,
            subtitle: '修改昵称和座右铭'.tr,
            onTap: () => _showProfileEditDialog(context),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildActionItem(
            icon: Icons.manage_search,
            title: '增强搜索'.tr,
            subtitle: '在线搜索影视和书籍信息'.tr,
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
          if (!PlatformUtils.isDesktop) ...[
            _buildSwitchItem(
              icon: Icons.swipe_vertical_outlined,
              title: '底部导航栏滚动隐藏'.tr,
              subtitle: '下滑时自动隐藏底部导航栏'.tr,
              value: _hideBottomNavOnScroll,
              onChanged: _toggleHideBottomNavOnScroll,
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          ],
          _buildSwitchItem(
            icon: Icons.bug_report_outlined,
            title: '调试模式'.tr,
            subtitle: '记录应用运行日志'.tr,
            value: _debugMode,
            onChanged: _toggleDebugMode,
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          if (_debugMode) ...[
            _buildNavigationItem(
              icon: Icons.article_outlined,
              title: '运行日志'.tr,
              subtitle: '查看、按时间筛选和保存日志'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DebugLogPage())),
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          ],
          _buildSectionHeader('数据管理'.tr),
          _buildActionItem(
            icon: Icons.cleaning_services_outlined,
            title: '清除缓存数据'.tr,
            subtitle: '清理未在数据库中引用的文件'.tr,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CacheCleanerPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          // 存储权限仅 Android 需要（permission_handler 无桌面实现）
          if (Platform.isAndroid) ...[
            _buildActionItem(
              icon: Icons.folder_outlined,
              title: '获取系统权限'.tr,
              subtitle: '查看并开启存储、照片等媒体权限'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PermissionsPage())),
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          ],
          if (Platform.isAndroid) ...[
            _buildActionItem(
              icon: Icons.image_search_outlined,
              title: '扫描系统媒体库'.tr,
              subtitle: '图片存在但相册/图片选择器里看不到时，触发系统重新索引'.tr,
              onTap: _scanSystemMedia,
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
          ],
          _buildSectionHeader('帮助'.tr),
          _buildActionItem(
            icon: Icons.language_outlined,
            title: '查看官网'.tr,
            subtitle: '在浏览器中打开官方网站'.tr,
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
            title: '项目源码'.tr,
            subtitle: '查看 GitHub 项目仓库'.tr,
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
            title: '开发日志'.tr,
            subtitle: '在浏览器中查看项目开发记录'.tr,
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
            title: '更新日志'.tr,
            subtitle: '查看版本更新内容'.tr,
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
            title: '用户服务协议'.tr,
            subtitle: '查看用户服务协议'.tr,
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
            title: '隐私政策'.tr,
            subtitle: '查看隐私政策'.tr,
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

  Future<void> _toggleDebugMode(bool value) async {
    await _userPrefs.setDebugMode(value);
    if (value) LogService.instance.install();
    setState(() => _debugMode = value);
  }

  void _showProfileEditDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nicknameController = TextEditingController(text: _userPrefs.nickname);
    final mottoController = TextEditingController(text: _userPrefs.motto);
    // 控制器不手动 dispose：底部弹层关闭动画期间 TextField 仍在树中
    appModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽手柄
              Center(
                child: Container(
                  width: 28,
                  height: 3,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('个人信息'.tr,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: nicknameController,
                  style: TextStyle(fontSize: 14, color: colors.onSurface),
                  decoration: InputDecoration(
                    labelText: '昵称'.tr,
                    labelStyle: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.person_outline,
                        size: 20,
                        color: colors.onSurface.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: mottoController,
                  maxLines: 2,
                  style: TextStyle(fontSize: 14, color: colors.onSurface),
                  decoration: InputDecoration(
                    labelText: '座右铭'.tr,
                    labelStyle: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.format_quote,
                          size: 20,
                          color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: () async {
                    final nickname = nicknameController.text.trim();
                    final motto = mottoController.text.trim();
                    if (nickname.isNotEmpty) {
                      await _userPrefs.setNickname(nickname);
                    }
                    if (motto.isNotEmpty) await _userPrefs.setMotto(motto);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) ToastUtil.show(context, '已保存'.tr);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('保存'.tr,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> get _themeModeLabels => ['跟随系统'.tr, '浅色模式'.tr, '深色模式'.tr, '毛玻璃'.tr];
  static const _themeModeIcons = [
    Icons.brightness_auto,
    Icons.light_mode,
    Icons.dark_mode,
    Icons.blur_on
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
                    Text('主题模式'.tr,
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
    appModalBottomSheet(
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
                  child: Text('主题模式'.tr,
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
                  if (!ctx.mounted) return;
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
    if (mode == 3) {
      if (mounted) {
        context.read<AppProvider>().enableFrosted();
        setState(() => _themeMode = mode);
      }
      return;
    }
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
        currentIndex == -1 ? '莫奈取色'.tr : AppTheme.colorSchemeNames[currentIndex].tr;
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
                    Text('配色方案'.tr,
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
    appModalBottomSheet(
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
                  child: Text('配色方案'.tr,
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
                          Text(AppTheme.colorSchemeNames[i].tr,
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
                    Text('莫奈取色'.tr,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: available
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.35))),
                    Text(available ? '从系统壁纸自动提取配色'.tr : '此设备不支持'.tr,
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
    final label = _fontFamily.isEmpty ? '系统默认'.tr : _fontFamily;
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
                Text('字体'.tr,
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

  // ─── 语言选择器 ───

  static List<String> get _languageLabels => ['跟随系统'.tr, '中文', 'English'];
  static const _languageIcons = [
    Icons.settings_suggest_outlined,
    Icons.translate,
    Icons.abc,
  ];

  Widget _buildLanguageSelector() {
    final colors = Theme.of(context).colorScheme;
    final languageMode = context.watch<AppProvider>().languageMode;
    return InkWell(
      onTap: () => _showLanguagePicker(languageMode),
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
                child: Icon(Icons.language_outlined,
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('语言'.tr,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(_languageLabels[languageMode],
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

  void _showLanguagePicker(int current) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
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
                  child: Text('语言'.tr,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface))),
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _languageLabels.length; i++)
              InkWell(
                onTap: () {
                  context.read<AppProvider>().setLanguageMode(i);
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      Icon(_languageIcons[i],
                          size: 18,
                          color: colors.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(_languageLabels[i],
                              style: TextStyle(
                                  fontSize: 13, color: colors.onSurface))),
                      if (current == i)
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

  /// 触发系统媒体扫描（解决图片已在存储中但系统相册/图片选择器看不到的问题）
  Future<void> _scanSystemMedia() async {
    // 先确保有图片读取权限（Android 13+ 为 READ_MEDIA_IMAGES）
    await Permission.photos.request();
    if (!mounted) return;

    int done = 0;
    int total = 0;
    StateSetter? dialogSetState;
    BuildContext? dialogCtx;
    bool scanFinished = false;

    final scanFuture = MediaScanChannel.scanMedia(
      onProgress: (d, t) {
        done = d;
        total = t;
        dialogSetState?.call(() {});
      },
    );
    // 扫描结束时自动关闭进度弹窗
    scanFuture.then((_) {
      scanFinished = true;
      final ctx = dialogCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.pop(ctx, true);
      }
    });

    final completed = await appDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogCtx = ctx;
        // 扫描在弹窗打开前就已结束（目录为空等情况），直接关掉
        if (scanFinished) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) Navigator.pop(ctx, true);
          });
        }
        return StatefulBuilder(
          builder: (ctx, setState) {
            dialogSetState = setState;
            final colors = Theme.of(ctx).colorScheme;
            return AlertDialog(
              backgroundColor: colors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('扫描系统媒体库'.tr,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: total > 0 ? done / total : null,
                    minHeight: 4,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    total > 0
                        ? '已扫描 {done}/{total}'
                            .trf({'done': done, 'total': total})
                        : '正在查找图片...'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('后台运行'.tr,
                      style: TextStyle(
                          color: colors.onSurface.withValues(alpha: 0.6))),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    final count = await scanFuture;
    if (!mounted) return;
    // 用户点了"后台运行"则静默，扫描仍在系统侧继续
    if (completed == true) {
      if (count > 0) {
        ToastUtil.show(
            context, '扫描完成，共 {n} 个文件，稍后可在系统相册查看'.trf({'n': count}));
      } else if (count == 0) {
        ToastUtil.show(context, '未在公共图片目录发现图片，请检查存储权限'.tr);
      } else {
        ToastUtil.show(context, '扫描失败'.tr);
      }
    }
  }
}
