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
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // ── 影视 ──
          _buildCategoryHeader(Icons.movie_outlined, '影视', colors.primary),
          _buildWallSwitch(
            icon: Icons.wallpaper_outlined,
            title: '影视墙模式',
            subtitle: '显示全部影片，不区分状态',
            value: _movieWallMode,
            onChanged: (v) => _setWallMode('movie', v),
          ),
          _buildLayoutSelector(
            selected: _movieLayout,
            options: [
              (0, Icons.grid_view_outlined, '海报网格'),
              (1, Icons.view_list_outlined, '列表'),
              (2, Icons.crop_landscape_outlined, '大图卡片'),
            ],
            onChanged: (v) => _setLayout('movie', v),
          ),
          const SizedBox(height: 8),
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: colors.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),

          // ── 阅读 ──
          _buildCategoryHeader(Icons.menu_book_outlined, '阅读', colors.primary),
          _buildWallSwitch(
            icon: Icons.auto_stories_outlined,
            title: '书架模式',
            subtitle: '显示全部书籍，不区分状态',
            value: _bookshelfMode,
            onChanged: (v) => _setWallMode('book', v),
          ),
          _buildLayoutSelector(
            selected: _bookLayout,
            options: [
              (0, Icons.grid_view_outlined, '海报网格'),
              (1, Icons.view_list_outlined, '列表'),
            ],
            onChanged: (v) => _setLayout('book', v),
          ),
          const SizedBox(height: 8),
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: colors.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),

          // ── 笔记 ──
          _buildCategoryHeader(Icons.note_outlined, '笔记', colors.primary),
          _buildLayoutSelector(
            selected: _noteLayout,
            options: [
              (0, Icons.view_list_outlined, '列表'),
              (1, Icons.grid_view_outlined, '瀑布流'),
              (2, Icons.timeline_outlined, '时间线'),
            ],
            onChanged: (v) => _setLayout('note', v),
          ),
          const SizedBox(height: 8),
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: colors.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 8),

          // ── 游戏 ──
          _buildCategoryHeader(Icons.sports_esports_outlined, '游戏', colors.primary),
          _buildWallSwitch(
            icon: Icons.wallpaper_outlined,
            title: '游戏墙模式',
            subtitle: '显示全部游戏，不区分状态',
            value: _gameWallMode,
            onChanged: (v) => _setWallMode('game', v),
          ),
          _buildLayoutSelector(
            selected: _gameLayout,
            options: [
              (0, Icons.grid_view_outlined, '海报网格'),
              (1, Icons.view_list_outlined, '列表'),
              (2, Icons.crop_landscape_outlined, '大图卡片'),
            ],
            onChanged: (v) => _setLayout('game', v),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildWallSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 20, color: colors.primary.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: colors.primary,
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildLayoutSelector({
    required int selected,
    required List<(int, IconData, String)> options,
    required ValueChanged<int> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: options.map((opt) {
          final isSelected = selected == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary
                      : colors.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.5),
                    width: isSelected ? 0 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.$2,
                      size: 22,
                      color: isSelected
                          ? colors.onPrimary
                          : colors.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      opt.$3,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? colors.onPrimary
                            : colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
