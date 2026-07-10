import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';

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
  int _gameLayout = 0;
  bool _movieWallMode = false;
  int _movieDisplayMode = 0;
  bool _bookshelfMode = false;
  bool _gameWallMode = false;

  @override
  void initState() {
    super.initState();
    _noteLayout = _userPrefs.noteLayoutStyle;
    _movieLayout = _userPrefs.movieLayoutStyle;
    _bookLayout = _userPrefs.bookLayoutStyle;
    _gameLayout = _userPrefs.gameLayoutStyle;
    _movieWallMode = _userPrefs.movieWallMode;
    _movieDisplayMode = _userPrefs.movieDisplayMode;
    _bookshelfMode = _userPrefs.bookshelfMode;
    _gameWallMode = _userPrefs.gameWallMode;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('布局设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildCategoryTile(
            icon: Icons.movie_outlined,
            title: '影视',
            color: colors.primary,
            subtitle: _movieSubtitle,
            onTap: _showMovieSheet,
          ),
          _buildCategoryTile(
            icon: Icons.menu_book_outlined,
            title: '阅读',
            color: colors.primary,
            subtitle: _bookSubtitle,
            onTap: _showBookSheet,
          ),
          _buildCategoryTile(
            icon: Icons.note_outlined,
            title: '笔记',
            color: colors.primary,
            subtitle: _noteSubtitle,
            onTap: _showNoteSheet,
          ),
          _buildCategoryTile(
            icon: Icons.sports_esports_outlined,
            title: '游戏',
            color: colors.primary,
            subtitle: _gameSubtitle,
            onTap: _showGameSheet,
          ),
        ],
      ),
    );
  }

  String get _movieSubtitle {
    final parts = <String>[];
    if (_movieWallMode) {
      parts.add('影视墙');
    } else {
      parts.add(_movieDisplayMode == 1 ? '分类状态' : '观看状态');
    }
    parts.add(['海报网格', '列表', '大图卡片'][_movieLayout]);
    return parts.join(' · ');
  }

  String get _bookSubtitle {
    final parts = <String>[];
    if (_bookshelfMode) parts.add('书架模式');
    parts.add(['海报网格', '列表'][_bookLayout]);
    return parts.join(' · ');
  }

  String get _noteSubtitle => ['列表', '瀑布流', '时间线'][_noteLayout];

  String get _gameSubtitle {
    final parts = <String>[];
    if (_gameWallMode) parts.add('游戏墙');
    parts.add(['海报网格', '列表', '大图卡片'][_gameLayout]);
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

  // ─── 弹窗内组件 ──────────────────────────────────────────────────

  Widget _sheetSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: colors.primary),
        ],
      ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: options.map((opt) {
                final isSelected = selected == opt.$1;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
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
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetDivider(ColorScheme colors) {
    return Divider(height: 1, indent: 20, endIndent: 20, color: colors.outlineVariant.withValues(alpha: 0.4));
  }

  // ─── 弹窗 ────────────────────────────────────────────────────────

  void _showMovieSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('影视布局', colors),
            _sheetSwitchRow(
              title: '影视墙模式', subtitle: '显示全部影片，不区分状态',
              value: _movieWallMode, onChanged: (v) { _setWallMode('movie', v); setSheetState(() {}); }, colors: colors,
            ),
            if (!_movieWallMode) ...[
              _sheetDivider(colors),
              _sheetOptionRow(
                label: '显示模式', selected: _movieDisplayMode,
                options: const [(0, Icons.check_circle_outline, '观看状态'), (1, Icons.category_outlined, '分类状态')],
                onChanged: (v) { _setDisplayMode('movie', v); setSheetState(() {}); }, colors: colors,
              ),
            ],
            _sheetDivider(colors),
            _sheetOptionRow(
              label: '布局样式', selected: _movieLayout,
              options: const [(0, Icons.grid_view_outlined, '海报网格'), (1, Icons.view_list_outlined, '列表'), (2, Icons.crop_landscape_outlined, '大图卡片')],
              onChanged: (v) { _setLayout('movie', v); setSheetState(() {}); }, colors: colors,
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _showBookSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('阅读布局', colors),
            _sheetSwitchRow(
              title: '书架模式', subtitle: '显示全部书籍，不区分状态',
              value: _bookshelfMode, onChanged: (v) { _setWallMode('book', v); setSheetState(() {}); }, colors: colors,
            ),
            _sheetDivider(colors),
            _sheetOptionRow(
              label: '布局样式', selected: _bookLayout,
              options: const [(0, Icons.grid_view_outlined, '海报网格'), (1, Icons.view_list_outlined, '列表')],
              onChanged: (v) { _setLayout('book', v); setSheetState(() {}); }, colors: colors,
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _showNoteSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('笔记布局', colors),
            _sheetOptionRow(
              label: '布局样式', selected: _noteLayout,
              options: const [(0, Icons.view_list_outlined, '列表'), (1, Icons.grid_view_outlined, '瀑布流'), (2, Icons.timeline_outlined, '时间线')],
              onChanged: (v) { _setLayout('note', v); setSheetState(() {}); }, colors: colors,
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  void _showGameSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('游戏布局', colors),
            _sheetSwitchRow(
              title: '游戏墙模式', subtitle: '显示全部游戏，不区分状态',
              value: _gameWallMode, onChanged: (v) { _setWallMode('game', v); setSheetState(() {}); }, colors: colors,
            ),
            _sheetDivider(colors),
            _sheetOptionRow(
              label: '布局样式', selected: _gameLayout,
              options: const [(0, Icons.grid_view_outlined, '海报网格'), (1, Icons.view_list_outlined, '列表'), (2, Icons.crop_landscape_outlined, '大图卡片')],
              onChanged: (v) { _setLayout('game', v); setSheetState(() {}); }, colors: colors,
            ),
            const SizedBox(height: 16),
          ]),
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

  // ─── 状态更新 ──────────────────────────────────────────────────

  void _setWallMode(String type, bool value) async {
    switch (type) {
      case 'movie':
        await _userPrefs.setMovieWallMode(value);
        setState(() => _movieWallMode = value);
        if (mounted) context.read<AppProvider>().setMovieWallMode(value);
      case 'book':
        await _userPrefs.setBookshelfMode(value);
        setState(() => _bookshelfMode = value);
        if (mounted) context.read<AppProvider>().setBookshelfMode(value);
      case 'game':
        await _userPrefs.setGameWallMode(value);
        setState(() => _gameWallMode = value);
        if (mounted) context.read<AppProvider>().setGameWallMode(value);
    }
  }

  void _setDisplayMode(String type, int value) async {
    switch (type) {
      case 'movie':
        await _userPrefs.setMovieDisplayMode(value);
        setState(() => _movieDisplayMode = value);
        if (mounted) context.read<AppProvider>().setMovieDisplayMode(value);
    }
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
      case 'game':
        await _userPrefs.setGameLayoutStyle(value);
        setState(() => _gameLayout = value);
        if (mounted) context.read<AppProvider>().setGameLayoutStyle(value);
    }
  }
}
