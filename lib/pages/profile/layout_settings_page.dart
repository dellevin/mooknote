import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';
import 'module_layout_settings_page.dart';
import 'status_rename_page.dart';

class LayoutSettingsPage extends StatefulWidget {
  const LayoutSettingsPage({super.key});

  @override
  State<LayoutSettingsPage> createState() => _LayoutSettingsPageState();
}

class _LayoutSettingsPageState extends State<LayoutSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  int _homeModuleSwitchMode = 0;
  int _homeLeadingStyle = 0;

  @override
  void initState() {
    super.initState();
    _homeModuleSwitchMode = _userPrefs.homeModuleSwitchMode;
    _homeLeadingStyle = _userPrefs.homeLeadingStyle;
  }

  /// 打开模块布局设置页，返回后刷新副标题
  Future<void> _openModuleSettings(String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ModuleLayoutSettingsPage(type: type)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: Text('布局设置'.tr)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildCategoryTile(
            icon: Icons.dashboard_outlined,
            title: '主页模块显示方式'.tr,
            color: colors.primary,
            subtitle: _homeModuleSubtitle,
            onTap: _showHomeModuleSheet,
          ),
          _buildCategoryTile(
            icon: Icons.drive_file_rename_outline,
            title: '主页模块状态自定义命名'.tr,
            color: colors.primary,
            subtitle: '影视、阅读、游戏状态名称'.tr,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatusRenamePage())),
          ),
          _buildCategoryTile(
            icon: Icons.movie_outlined,
            title: '影视'.tr,
            color: colors.primary,
            subtitle: _movieSubtitle,
            onTap: () => _openModuleSettings('movie'),
          ),
          _buildCategoryTile(
            icon: Icons.menu_book_outlined,
            title: '阅读'.tr,
            color: colors.primary,
            subtitle: _bookSubtitle,
            onTap: () => _openModuleSettings('book'),
          ),
          _buildCategoryTile(
            icon: Icons.sports_esports_outlined,
            title: '游戏'.tr,
            color: colors.primary,
            subtitle: _gameSubtitle,
            onTap: () => _openModuleSettings('game'),
          ),
          _buildCategoryTile(
            icon: Icons.sticky_note_2_outlined,
            title: '笔记'.tr,
            color: colors.primary,
            subtitle: _noteSubtitle,
            onTap: () => _openModuleSettings('note'),
          ),
        ],
      ),
    );
  }

  String get _homeModuleSubtitle {
    return _homeModuleSwitchMode == 1 ? '顶部下拉切换'.tr : '模块标签切换'.tr;
  }

  String get _movieSubtitle {
    final parts = <String>[];
    if (_userPrefs.movieWallMode) {
      parts.add('影视墙'.tr);
    } else {
      parts.add(_userPrefs.movieDisplayMode == 1 ? '分类状态'.tr : '观看状态'.tr);
      if (_userPrefs.movieDisplayMode == 0) {
        parts.add(['胶囊'.tr, '下划线'.tr, '芯片'.tr, '下拉'.tr, '模块内点击'.tr][_userPrefs.movieStatusBarStyle]);
      }
    }
    final layout = _userPrefs.movieLayoutStyle;
    parts.add(['海报网格'.tr, '列表'.tr, '大图卡片'.tr, '年份网格'.tr][layout]);
    if ((layout == 0 || layout == 3) && _userPrefs.movieGridCount > 0) {
      parts.add('每行{n}个'.trf({'n': '${_userPrefs.movieGridCount}'}));
    }
    parts.add(['更新时间'.tr, '创建时间'.tr, '评分'.tr, '观看日期'.tr, '上映时间'.tr][layout == 3 ? 4 : _userPrefs.movieSortMode]);
    return parts.join(' · ');
  }

  String get _bookSubtitle {
    final parts = <String>[];
    if (_userPrefs.bookshelfMode) {
      parts.add('书架'.tr);
    } else {
      parts.add(_userPrefs.bookDisplayMode == 1 ? '分类状态'.tr : '阅读状态'.tr);
      if (_userPrefs.bookDisplayMode == 0) {
        parts.add(['胶囊'.tr, '下划线'.tr, '芯片'.tr, '下拉'.tr, '模块内点击'.tr][_userPrefs.bookStatusBarStyle]);
      }
    }
    final layout = _userPrefs.bookLayoutStyle;
    parts.add(['海报网格'.tr, '列表'.tr, '年份网格'.tr, '大图卡片'.tr][layout]);
    if ((layout == 0 || layout == 2) && _userPrefs.bookGridCount > 0) {
      parts.add('每行{n}个'.trf({'n': '${_userPrefs.bookGridCount}'}));
    }
    parts.add(['更新时间'.tr, '创建时间'.tr, '评分'.tr, '开始阅读'.tr, '出版时间'.tr][layout == 2 ? 4 : _userPrefs.bookSortMode]);
    return parts.join(' · ');
  }

  String get _noteSubtitle {
    final parts = <String>[];
    parts.add(['列表'.tr, '瀑布流'.tr, '时间线'.tr][_userPrefs.noteLayoutStyle]);
    parts.add(['更新时间'.tr, '创建时间'.tr][_userPrefs.noteSortMode]);
    return parts.join(' · ');
  }

  String get _gameSubtitle {
    final parts = <String>[];
    if (_userPrefs.gameWallMode) {
      parts.add('游戏墙'.tr);
    } else {
      parts.add('游玩状态'.tr);
      parts.add(['胶囊'.tr, '下划线'.tr, '芯片'.tr, '下拉'.tr, '模块内点击'.tr][_userPrefs.gameStatusBarStyle]);
    }
    final layout = _userPrefs.gameLayoutStyle;
    parts.add(['海报网格'.tr, '列表'.tr, '大图卡片'.tr, '年份网格'.tr][layout]);
    if ((layout == 0 || layout == 3) && _userPrefs.gameGridCount > 0) {
      parts.add('每行{n}个'.trf({'n': '${_userPrefs.gameGridCount}'}));
    }
    parts.add(['更新时间'.tr, '创建时间'.tr, '评分'.tr, '发售时间'.tr, '通关时间'.tr][layout == 3 ? 3 : _userPrefs.gameSortMode]);
    return parts.join(' · ');
  }

  // ─── 分类行 ──────────────────────────────────────────────────────

  Widget _buildCategoryTile({
    required IconData icon,
    required String title,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 主页模块显示方式弹窗（仅此入口保留弹窗） ─────────────────────

  void _showHomeModuleSheet() {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(colors),
              _sheetTitle('主页模块显示方式'.tr, colors),
              _sheetOptionRow(
                label: '切换方式'.tr,
                selected: _homeModuleSwitchMode,
                options: [
                  (0, Icons.tab_outlined, '模块标签'.tr),
                  (1, Icons.arrow_drop_down_outlined, '顶部下拉'.tr),
                ],
                onChanged: (v) {
                  _userPrefs.setHomeModuleSwitchMode(v);
                  setState(() => _homeModuleSwitchMode = v);
                  if (mounted) context.read<AppProvider>().setHomeModuleSwitchMode(v);
                  setSheetState(() {});
                },
                colors: colors,
              ),
              if (_homeModuleSwitchMode == 0)
                _sheetOptionRow(
                  label: '左上角显示'.tr,
                  selected: _homeLeadingStyle,
                  options: [
                    (0, Icons.calendar_today_outlined, '日期印章'.tr),
                    (1, Icons.menu_outlined, '菜单+分类'.tr),
                  ],
                  onChanged: (v) {
                    _userPrefs.setHomeLeadingStyle(v);
                    setState(() => _homeLeadingStyle = v);
                    if (mounted) context.read<AppProvider>().setHomeLeadingStyle(v);
                    setSheetState(() {});
                  },
                  colors: colors,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  _homeModuleSwitchMode == 1
                      ? 'AppBar 标题显示当前模块，点击弹出选择菜单。'.tr
                      : _homeLeadingStyle == 1
                          ? '左上角显示菜单图标与当前分类名，点击图标展开侧边栏。'.tr
                          : '顶部显示模块标签栏，点击切换。'.tr,
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sheetHandle(ColorScheme colors) {
    return Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)));
  }

  Widget _sheetTitle(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Align(alignment: Alignment.centerLeft,
          child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
    );
  }

  Widget _sheetOptionRow({
    required String label,
    required int selected,
    required List<(int, IconData, String)> options,
    required ValueChanged<int> onChanged,
    required ColorScheme colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: options.map((opt) {
                final isSelected = selected == opt.$1;
                return GestureDetector(
                  onTap: () => onChanged(opt.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? colors.primary : colors.outlineVariant.withValues(alpha: 0.7),
                        width: isSelected ? 0 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(opt.$2, size: 14, color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(opt.$3,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
