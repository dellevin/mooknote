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
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildGroup('显示设置'.tr, [
            _buildRow(
              icon: Icons.person_outline,
              title: '个人信息'.tr,
              subtitle: '修改昵称和座右铭'.tr,
              onTap: () => _showProfileEditDialog(context),
            ),
            // 应用图标仅 Android 有原生实现（app_icon_channel）
            if (Platform.isAndroid)
              _buildRow(
                icon: Icons.apps_outlined,
                title: '应用图标'.tr,
                subtitle: '更换桌面应用图标'.tr,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AppIconPickerPage())),
              ),
            _buildRow(
              icon: Icons.tune_outlined,
              title: '功能设置'.tr,
              subtitle: '启动标签、模块开关、侧边栏功能'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const FeatureSettingsPage())),
            ),
            _buildRow(
              icon: Icons.dashboard_outlined,
              title: '布局设置'.tr,
              subtitle: '影视、阅读、笔记的展示样式'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LayoutSettingsPage())),
            ),
            _buildRow(
              icon: Icons.palette_outlined,
              title: '界面设置'.tr,
              subtitle: '主题、配色与字体'.tr,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AppearanceSettingsPage())),
            ),
            _buildLanguageRow(),
          ]),
          _buildGroup('其他设置'.tr, [
            _buildRow(
              icon: Icons.travel_explore_outlined,
              title: '在线搜索 API'.tr,
              subtitle: '增强搜索、TMDB、Bangumi 数据源配置'.tr,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const OnlineSearchApiSettingsPage())),
            ),
            _buildSwitchRow(
              icon: Icons.swipe_vertical_outlined,
              title: '底部导航栏滚动隐藏'.tr,
              subtitle: '下滑时自动隐藏底部导航栏'.tr,
              value: _hideBottomNavOnScroll,
              onChanged: _toggleHideBottomNavOnScroll,
            ),
            _buildSwitchRow(
              icon: Icons.bug_report_outlined,
              title: '调试模式'.tr,
              subtitle: '记录应用运行日志'.tr,
              value: _debugMode,
              onChanged: _toggleDebugMode,
            ),
            if (_debugMode) ...[
              _buildRow(
                icon: Icons.article_outlined,
                title: '运行日志'.tr,
                subtitle: '查看、按时间筛选和保存日志'.tr,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DebugLogPage())),
              ),
              _buildRow(
                icon: Icons.tune,
                title: '偏好设置编辑器'.tr,
                subtitle: '查看和修改 SharedPreferences 数据'.tr,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrefsEditorPage())),
              ),
              _buildRow(
                icon: Icons.storage,
                title: '数据库查看器'.tr,
                subtitle: '浏览表数据，执行 SELECT 查询'.tr,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DbViewerPage())),
              ),
            ],
          ]),
          _buildGroup('数据管理'.tr, [
            _buildRow(
              icon: Icons.cleaning_services_outlined,
              title: '清除缓存数据'.tr,
              subtitle: '清理未在数据库中引用的文件'.tr,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CacheCleanerPage())),
            ),
            // 存储权限仅 Android 需要（permission_handler 无桌面实现）
            if (Platform.isAndroid)
              _buildRow(
                icon: Icons.folder_outlined,
                title: '获取系统权限'.tr,
                subtitle: '查看并开启存储、照片等媒体权限'.tr,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PermissionsPage())),
              ),
            if (Platform.isAndroid)
              _buildRow(
                icon: Icons.image_search_outlined,
                title: '扫描系统媒体库'.tr,
                subtitle: '图片存在但相册/图片选择器里看不到时，触发系统重新索引'.tr,
                onTap: _scanSystemMedia,
              ),
          ]),
          _buildGroup('帮助'.tr, [
            _buildRow(
              icon: Icons.language_outlined,
              title: '查看官网'.tr,
              subtitle: '在浏览器中打开官方网站'.tr,
              onTap: () =>
                  launchUrl(Uri.parse('https://mooknote.iletter.top/#/')),
            ),
            _buildRow(
              icon: Icons.open_in_new_outlined,
              title: '项目源码'.tr,
              subtitle: '查看 GitHub 项目仓库'.tr,
              onTap: () =>
                  launchUrl(Uri.parse('https://github.com/dellevin/mooknote')),
            ),
            _buildRow(
              icon: Icons.update_outlined,
              title: '更新日志'.tr,
              subtitle: '查看版本更新内容'.tr,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ChangelogPage())),
            ),
            _buildRow(
              icon: Icons.description_outlined,
              title: '用户服务协议'.tr,
              subtitle: '查看用户服务协议'.tr,
              onTap: () => launchUrl(
                  Uri.parse(
                      'https://mooknote.iletter.top/info/user_agreement.html'),
                  mode: LaunchMode.externalApplication),
            ),
            _buildRow(
              icon: Icons.shield_outlined,
              title: '隐私政策'.tr,
              subtitle: '查看隐私政策'.tr,
              onTap: () => launchUrl(
                  Uri.parse(
                      'https://mooknote.iletter.top/info/privacy_policy.html'),
                  mode: LaunchMode.externalApplication),
            ),
          ]),
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
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text('个人信息'.tr,
                    style: TextStyle(
                        fontSize: 16,
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
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text('保存'.tr,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
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

  /// 分组圆角容器：小标题 + 圆角分组，内部分隔线缩进至标题列（56）
  Widget _buildGroup(String title, List<Widget> rows) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    indent: 56,
                    color: colors.outlineVariant.withValues(alpha: 0.3),
                  ),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 分组内通用行：30×30 主色图标块 + 标题/副标题 + 右侧尾控件
  Widget _buildRow(
      {required IconData icon,
      required String title,
      required String subtitle,
      Widget? trailing,
      VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    final colors = Theme.of(context).colorScheme;
    return _buildRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: colors.primary,
          activeTrackColor: colors.primary.withValues(alpha: 0.3),
          inactiveThumbColor: colors.surface,
          inactiveTrackColor: colors.outline),
    );
  }

  Widget _buildLanguageRow() {
    final colors = Theme.of(context).colorScheme;
    final languageMode = context.watch<AppProvider>().languageMode;
    return _buildRow(
      icon: Icons.language_outlined,
      title: '语言'.tr,
      subtitle: _languageLabels[languageMode],
      onTap: () => _showLanguagePicker(languageMode),
      trailing: Icon(Icons.chevron_right,
          color: colors.onSurface.withValues(alpha: 0.25), size: 20),
    );
  }

  void _showLanguagePicker(int current) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 28,
                height: 3,
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('语言'.tr,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (int i = 0; i < _languageLabels.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 56,
                        color: colors.outlineVariant.withValues(alpha: 0.3),
                      ),
                    InkWell(
                      onTap: () {
                        context.read<AppProvider>().setLanguageMode(i);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_languageIcons[i],
                                  size: 17, color: colors.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(_languageLabels[i],
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onSurface))),
                            if (current == i)
                              Icon(Icons.check,
                                  color: colors.primary, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
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
