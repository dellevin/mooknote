import 'package:flutter/material.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';

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
