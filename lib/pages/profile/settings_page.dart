import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../services/media_scan_channel.dart';
import '../../services/log_service.dart';
import '../online_search/online_search_api_settings_page.dart';
import '../settings/debug_log_page.dart';
import '../settings/prefs_editor_page.dart';
import '../settings/db_viewer_page.dart';
import 'app_icon_picker_page.dart';
import 'appearance_settings_page.dart';
import 'feature_settings_page.dart';
import 'layout_settings_page.dart';
import 'changelog_page.dart';
import 'cache_cleaner_page.dart';
import 'permissions_page.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../utils/avatar_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _hideBottomNavOnScroll = _userPrefs.hideBottomNavOnScroll;
    _debugMode = _userPrefs.debugMode;
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
          _buildNavigationItem(
            icon: Icons.palette_outlined,
            title: '界面设置'.tr,
            subtitle: '主题、配色与字体'.tr,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AppearanceSettingsPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildLanguageSelector(),
          _buildSectionHeader('其他设置'.tr),
          _buildActionItem(
            icon: Icons.travel_explore_outlined,
            title: '在线搜索 API'.tr,
            subtitle: '增强搜索、TMDB、Bangumi 数据源配置'.tr,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const OnlineSearchApiSettingsPage())),
          ),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
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
            _buildNavigationItem(
              icon: Icons.tune,
              title: '偏好设置编辑器'.tr,
              subtitle: '查看和修改 SharedPreferences 数据'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PrefsEditorPage())),
            ),
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
            _buildNavigationItem(
              icon: Icons.storage,
              title: '数据库查看器'.tr,
              subtitle: '浏览表数据，执行 SELECT 查询'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DbViewerPage())),
            ),
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
            onTap: () => launchUrl(
                Uri.parse(
                    'https://mooknote.iletter.top/info/user_agreement.html'),
                mode: LaunchMode.externalApplication),
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
            onTap: () => launchUrl(
                Uri.parse(
                    'https://mooknote.iletter.top/info/privacy_policy.html'),
                mode: LaunchMode.externalApplication),
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
              // 头像：点击更换 / 移除
              StatefulBuilder(
                builder: (sheetCtx, sheetSetState) {
                  final avatar = _userPrefs.avatarPath;
                  return Center(
                    child: GestureDetector(
                      onTap: () => AvatarHelper.showActionSheet(sheetCtx, onChanged: () {
                        sheetSetState(() {});
                        sheetCtx.read<AppProvider>().notifyUserInfoChanged();
                      }),
                      child: Stack(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.surfaceContainerHighest,
                              border: Border.all(color: colors.outlineVariant, width: 0.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: avatar != null && avatar.isNotEmpty
                                ? FadeInLocalImage(
                                    path: avatar,
                                    fit: BoxFit.cover,
                                    errorWidget: Icon(Icons.person_outline,
                                        size: 34,
                                        color: colors.onSurface.withValues(alpha: 0.3)))
                                : Icon(Icons.person_outline,
                                    size: 34,
                                    color: colors.onSurface.withValues(alpha: 0.3)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.surface, width: 2),
                              ),
                              child: Icon(Icons.camera_alt, size: 13, color: colors.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                activeThumbColor: colors.primary,
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
