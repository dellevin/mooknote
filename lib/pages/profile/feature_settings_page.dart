import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_overlay.dart';

class FeatureSettingsPage extends StatefulWidget {
  const FeatureSettingsPage({super.key});

  @override
  State<FeatureSettingsPage> createState() => _FeatureSettingsPageState();
}

class _FeatureSettingsPageState extends State<FeatureSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();

  // 主界面
  bool _showDesktopHomeTab = true;
  bool _showMovieTab = true;
  bool _showBookTab = true;
  bool _showNoteTab = true;
  bool _showGameTab = true;
  int _defaultTabIndex = 0;

  // 侧边栏
  bool _showHeatmap = true;
  bool _showRecent = true;
  bool _showEncounter = true;
  bool _showStroll = true;
  bool _showReviewed = true;
  bool _showPlaylist = true;
  bool _showCalendar = true;
  bool _showPerson = true;
  bool _showGallery = true;
  bool _showTags = true;
  bool _showQuickActions = true;

  // 笔记编辑器
  String _editorMode = 'vditor';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _showDesktopHomeTab = _userPrefs.showDesktopHomeTab;
      _showMovieTab = _userPrefs.showMovieTab;
      _showBookTab = _userPrefs.showBookTab;
      _showNoteTab = _userPrefs.showNoteTab;
      _showGameTab = _userPrefs.showGameTab;
      _defaultTabIndex = _userPrefs.defaultMainTabIndex;
      _showHeatmap = _userPrefs.showSidebarHeatmap;
      _showRecent = _userPrefs.showSidebarRecent;
      _showEncounter = _userPrefs.showSidebarEncounter;
      _showStroll = _userPrefs.showSidebarStroll;
      _showReviewed = _userPrefs.showSidebarReviewed;
      _showPlaylist = _userPrefs.showSidebarPlaylist;
      _showCalendar = _userPrefs.showSidebarCalendar;
      _showPerson = _userPrefs.showSidebarPerson;
      _showGallery = _userPrefs.showSidebarGallery;
      _showTags = _userPrefs.showSidebarTags;
      _showQuickActions = _userPrefs.showSidebarQuickActions;
      _editorMode = _userPrefs.editorMode;
    });
  }

  int get _enabledTabCount {
    int count = 0;
    if (_showDesktopHomeTab && Platform.isWindows) count++;
    if (_showMovieTab) count++;
    if (_showBookTab) count++;
    if (_showNoteTab) count++;
    if (_showGameTab) count++;
    return count;
  }

  List<(int, String, IconData)> get _enabledTabs {
    final all = <(int, String, IconData)>[];
    if (_showDesktopHomeTab && Platform.isWindows) all.add((-1, '主页'.tr, Icons.dashboard_outlined));
    all.addAll([
      (0, '影视'.tr, Icons.movie_outlined),
      (1, '阅读'.tr, Icons.menu_book_outlined),
      (2, '笔记'.tr, Icons.sticky_note_2_outlined),
      (3, '游戏'.tr, Icons.sports_esports_outlined),
    ].where((t) {
      return switch (t.$1) {
        0 => _showMovieTab,
        1 => _showBookTab,
        2 => _showNoteTab,
        3 => _showGameTab,
        _ => false,
      };
    }));
    return all;
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
      ToastUtil.show(context, '至少保留一个标签页'.tr);
      return;
    }
    await _userPrefs.setShowMovieTab(value);
    setState(() {
      _showMovieTab = value;
      _fixDefaultTabIndex();
    });
    if (mounted) context.read<AppProvider>().refreshTabSettings();
  }

  Future<void> _toggleBookTab(bool value) async {
    if (!value && _enabledTabCount <= 1) {
      ToastUtil.show(context, '至少保留一个标签页'.tr);
      return;
    }
    await _userPrefs.setShowBookTab(value);
    setState(() {
      _showBookTab = value;
      _fixDefaultTabIndex();
    });
    if (mounted) context.read<AppProvider>().refreshTabSettings();
  }

  Future<void> _toggleNoteTab(bool value) async {
    if (!value && _enabledTabCount <= 1) {
      ToastUtil.show(context, '至少保留一个标签页'.tr);
      return;
    }
    await _userPrefs.setShowNoteTab(value);
    setState(() {
      _showNoteTab = value;
      _fixDefaultTabIndex();
    });
    if (mounted) context.read<AppProvider>().refreshTabSettings();
  }

  Future<void> _toggleGameTab(bool value) async {
    if (!value && _enabledTabCount <= 1) {
      ToastUtil.show(context, '至少保留一个标签页'.tr);
      return;
    }
    await _userPrefs.setShowGameTab(value);
    setState(() {
      _showGameTab = value;
      _fixDefaultTabIndex();
    });
    if (mounted) context.read<AppProvider>().refreshTabSettings();
  }


  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('功能设置'.tr)),
      body: ListView(
        children: [
          // ── 启动设置 ──
          _buildSectionHeader('启动设置'.tr),
          _buildDefaultTabSelector(),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),

          // ── 笔记编辑器 ──
          _buildSectionHeader('笔记编辑器'.tr),
          _buildEditorModeSelector(),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),

          // ── 模块开关 ──
          _buildSectionHeader('模块开关'.tr),
          if (Platform.isWindows) ...[
            _buildSwitchItem(Icons.dashboard_outlined, '主页'.tr, '桌面端数据概览与分析'.tr, _showDesktopHomeTab, (v) async {
              await _userPrefs.setShowDesktopHomeTab(v);
              setState(() {
                _showDesktopHomeTab = v;
                _fixDefaultTabIndex();
              });
            }),
            Divider(height: 0.5, indent: 24, endIndent: 24, color: colors.outlineVariant),
          ],
          _buildSwitchItem(Icons.movie_outlined, '观影'.tr, '记录和管理观影记录'.tr,
              _showMovieTab, _toggleMovieTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.menu_book_outlined, '阅读'.tr, '记录和管理阅读记录'.tr,
              _showBookTab, _toggleBookTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.sticky_note_2_outlined, '笔记'.tr, '记录和管理笔记'.tr, _showNoteTab,
              _toggleNoteTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.sports_esports_outlined, '游戏'.tr, '记录和管理游戏记录'.tr, _showGameTab,
              _toggleGameTab),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          // ── 侧边栏：信息模块 ──
          _buildSectionHeader('侧边栏 · 信息模块'.tr),
          _buildSwitchItem(
              Icons.calendar_today, '热力图'.tr, '显示创作活跃度热力图'.tr, _showHeatmap,
              (v) async {
            await _userPrefs.setShowSidebarHeatmap(v);
            setState(() => _showHeatmap = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.schedule, '最近添加'.tr, '显示最近添加的记录'.tr, _showRecent,
              (v) async {
            await _userPrefs.setShowSidebarRecent(v);
            setState(() => _showRecent = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.bolt_outlined, '快捷操作'.tr, '快速新建笔记/影视'.tr, _showQuickActions,
              (v) async {
            await _userPrefs.setShowSidebarQuickActions(v);
            setState(() => _showQuickActions = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.favorite_border, '统计'.tr, '与应用相遇的天数和数据概览'.tr, _showEncounter,
              (v) async {
            await _userPrefs.setShowSidebarEncounter(v);
            setState(() => _showEncounter = v);
          }),

          // ── 侧边栏：快捷功能 ──
          _buildSectionHeader('侧边栏 · 快捷功能'.tr),
          _buildSwitchItem(Icons.explore_outlined, '漫步'.tr, '随机发现内容'.tr, _showStroll,
              (v) async {
            await _userPrefs.setShowSidebarStroll(v);
            setState(() => _showStroll = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.done_all, '已阅'.tr, '查看已看/已读/已通关记录'.tr, _showReviewed,
              (v) async {
            await _userPrefs.setShowSidebarReviewed(v);
            setState(() => _showReviewed = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.playlist_play, '书影片单'.tr, '创建和管理自定义片单'.tr, _showPlaylist,
              (v) async {
            await _userPrefs.setShowSidebarPlaylist(v);
            setState(() => _showPlaylist = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.calendar_month_outlined, '书影日历'.tr, '按日历查看记录'.tr, _showCalendar,
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
              Icons.people_outline, '人物'.tr, '管理影视、书籍和游戏中的人物'.tr, _showPerson,
              (v) async {
            await _userPrefs.setShowSidebarPerson(v);
            setState(() => _showPerson = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(
              Icons.photo_library_outlined, '图库'.tr, '浏览所有保存过的图片'.tr, _showGallery,
              (v) async {
            await _userPrefs.setShowSidebarGallery(v);
            setState(() => _showGallery = v);
          }),
          Divider(
              height: 0.5,
              indent: 24,
              endIndent: 24,
              color: colors.outlineVariant),
          _buildSwitchItem(Icons.label_outline, '标签管理'.tr, '管理所有标签'.tr, _showTags,
              (v) async {
            await _userPrefs.setShowSidebarTags(v);
            setState(() => _showTags = v);
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Text('关闭后对应功能将从界面中隐藏。'.tr,
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
              child: Text('默认启动标签'.tr,
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

  Widget _buildEditorModeSelector() {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _showEditorModePicker,
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
                child: Icon(Icons.edit_note_outlined,
                    color: colors.onSurface.withValues(alpha: 0.6), size: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('笔记编辑器'.tr,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface)),
                  Text(_editorMode == 'native' ? '纯文本（轻量快速）'.tr : '富文本（所见即所得）'.tr,
                      style: TextStyle(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
            Text(_editorMode == 'native' ? '纯文本'.tr : '富文本'.tr,
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

  void _showEditorModePicker() {
    final colors = Theme.of(context).colorScheme;
    final modes = [
      ('vditor', '富文本'.tr, 'Vditor 所见即所得，支持图文混排、加载稍慢'.tr),
      ('native', '纯文本'.tr, '轻量快速，无加载等待，支持 Markdown 语法'.tr),
    ];
    appModalBottomSheet(
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
                    child: Text('笔记编辑器'.tr,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)))),
            const SizedBox(height: 16),
            for (final (mode, name, desc) in modes)
              InkWell(
                onTap: () async {
                  await _userPrefs.setEditorMode(mode);
                  setState(() => _editorMode = mode);
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(children: [
                    Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(mode == 'native'
                            ? Icons.edit_note_outlined
                            : Icons.notes_outlined,
                            size: 16,
                            color: colors.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface)),
                          Text(desc,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurface.withValues(alpha: 0.4))),
                        ],
                      ),
                    ),
                    if (_editorMode == mode)
                      Icon(Icons.check_circle, size: 20, color: colors.primary),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showDefaultTabPicker() {
    final colors = Theme.of(context).colorScheme;
    final enabled = _enabledTabs;
    appModalBottomSheet(
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
                    child: Text('默认启动标签'.tr,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)))),
            const SizedBox(height: 16),
            for (final t in enabled)
              InkWell(
                onTap: () async {
                  await _userPrefs.setDefaultMainTabIndex(t.$1);
                  setState(() => _defaultTabIndex = t.$1);
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(children: [
                    Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8)),
                        child: Icon(t.$3, size: 16,
                            color: colors.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(width: 12),
                    Text(t.$2,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colors.onSurface)),
                    const Spacer(),
                    if (_defaultTabIndex == t.$1)
                      Icon(Icons.check_circle, size: 20, color: colors.primary),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
