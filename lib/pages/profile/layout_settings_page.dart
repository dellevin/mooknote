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
  int _homeModuleSwitchMode = 0;
  int _noteLayout = 0;
  int _movieLayout = 0;
  int _bookLayout = 0;
  int _gameLayout = 0;
  bool _movieWallMode = false;
  int _movieDisplayMode = 0;
  int _movieStatusBarStyle = 0;
  bool _bookshelfMode = false;
  int _bookStatusBarStyle = 0;
  bool _gameWallMode = false;
  int _gameStatusBarStyle = 0;
  int _movieSortMode = 0;
  int _bookSortMode = 0;
  int _noteSortMode = 0;
  int _gameSortMode = 0;

  @override
  void initState() {
    super.initState();
    _homeModuleSwitchMode = _userPrefs.homeModuleSwitchMode;
    _noteLayout = _userPrefs.noteLayoutStyle;
    _movieLayout = _userPrefs.movieLayoutStyle;
    _bookLayout = _userPrefs.bookLayoutStyle;
    _gameLayout = _userPrefs.gameLayoutStyle;
    _movieWallMode = _userPrefs.movieWallMode;
    _movieDisplayMode = _userPrefs.movieDisplayMode;
    _movieStatusBarStyle = _userPrefs.movieStatusBarStyle;
    _bookshelfMode = _userPrefs.bookshelfMode;
    _bookStatusBarStyle = _userPrefs.bookStatusBarStyle;
    _gameWallMode = _userPrefs.gameWallMode;
    _gameStatusBarStyle = _userPrefs.gameStatusBarStyle;
    _movieSortMode = _userPrefs.movieSortMode;
    _bookSortMode = _userPrefs.bookSortMode;
    _noteSortMode = _userPrefs.noteSortMode;
    _gameSortMode = _userPrefs.gameSortMode;
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
            icon: Icons.dashboard_outlined,
            title: '主页模块显示方式',
            color: colors.primary,
            subtitle: _homeModuleSubtitle,
            onTap: _showHomeModuleSheet,
          ),
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
            icon: Icons.sticky_note_2_outlined,
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

  String get _homeModuleSubtitle {
    return _homeModuleSwitchMode == 1 ? '顶部下拉切换' : '模块标签切换';
  }

  String get _movieSubtitle {
    final parts = <String>[];
    if (_movieWallMode) {
      parts.add('影视墙');
    } else {
      parts.add(_movieDisplayMode == 1 ? '分类状态' : '观看状态');
      if (_movieDisplayMode == 0) {
        parts.add(['胶囊', '下划线', '芯片', '下拉'][_movieStatusBarStyle]);
      }
    }
    parts.add(['海报网格', '列表', '大图卡片'][_movieLayout]);
    parts.add(['更新时间', '创建时间', '评分', '观看日期', '上映时间'][_movieSortMode]);
    return parts.join(' · ');
  }

  String get _bookSubtitle {
    final parts = <String>[];
    if (_bookshelfMode) {
      parts.add('书架模式');
    } else {
      parts.add(['胶囊', '下划线', '芯片', '下拉'][_bookStatusBarStyle]);
    }
    parts.add(['海报网格', '列表'][_bookLayout]);
    parts.add(['更新时间', '创建时间', '评分', '开始阅读', '出版时间'][_bookSortMode]);
    return parts.join(' · ');
  }

  String get _noteSubtitle {
    final parts = <String>[];
    parts.add(['列表', '瀑布流', '时间线'][_noteLayout]);
    parts.add(['更新时间', '创建时间'][_noteSortMode]);
    return parts.join(' · ');
  }

  String get _gameSubtitle {
    final parts = <String>[];
    if (_gameWallMode) {
      parts.add('游戏墙');
    } else {
      parts.add(['胶囊', '下划线', '芯片', '下拉'][_gameStatusBarStyle]);
    }
    parts.add(['海报网格', '列表', '大图卡片'][_gameLayout]);
    parts.add(['更新时间', '创建时间', '评分', '发售时间'][_gameSortMode]);
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

  Widget _sheetSortSection({
    required String title,
    required int current,
    required List<(int, String, IconData)> options,
    required ColorScheme colors,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.6))),
        ),
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant.withValues(alpha: 0.4)),
          _sheetSortItem(options[i], current, colors, onChanged),
        ],
      ]),
    );
  }

  Widget _sheetSortItem((int, String, IconData) option, int current, ColorScheme colors, ValueChanged<int> onChanged) {
    final selected = current == option.$1;
    return InkWell(
      onTap: () => onChanged(option.$1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Icon(option.$3, size: 18, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(option.$2, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: colors.onSurface))),
          if (selected) Icon(Icons.check, size: 18, color: colors.primary),
        ]),
      ),
    );
  }

  // ─── 弹窗 ────────────────────────────────────────────────────────

  void _showHomeModuleSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(colors),
              _sheetTitle('主页模块显示方式', colors),
              _sheetOptionRow(
                label: '切换方式',
                selected: _homeModuleSwitchMode,
                options: const [
                  (0, Icons.tab_outlined, '模块标签'),
                  (1, Icons.arrow_drop_down_outlined, '顶部下拉'),
                ],
                onChanged: (v) {
                  _userPrefs.setHomeModuleSwitchMode(v);
                  setState(() => _homeModuleSwitchMode = v);
                  if (mounted) context.read<AppProvider>().setHomeModuleSwitchMode(v);
                  setSheetState(() {});
                },
                colors: colors,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  _homeModuleSwitchMode == 1
                      ? 'AppBar 标题显示当前模块，点击弹出选择菜单。'
                      : '底部显示模块标签栏，点击切换。',
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showMovieSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: SingleChildScrollView(
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
              if (_movieDisplayMode == 0) ...[
                _sheetDivider(colors),
                _sheetOptionRow(
                  label: '状态栏样式', selected: _movieStatusBarStyle,
                  options: const [
                    (0, Icons.circle, '胶囊'),
                    (1, Icons.format_underlined, '下划线'),
                    (2, Icons.square_outlined, '芯片'),
                    (3, Icons.arrow_drop_down_circle_outlined, '下拉'),
                  ],
                  onChanged: (v) { _setStatusBarStyle('movie', v); setSheetState(() {}); }, colors: colors,
                ),
              ],
            ],
            _sheetDivider(colors),
            _sheetOptionRow(
              label: '布局样式', selected: _movieLayout,
              options: const [(0, Icons.grid_view_outlined, '海报网格'), (1, Icons.view_list_outlined, '列表'), (2, Icons.crop_landscape_outlined, '大图卡片')],
              onChanged: (v) { _setLayout('movie', v); setSheetState(() {}); }, colors: colors,
            ),
            _sheetDivider(colors),
            _sheetSortSection(
              title: '排序方式',
              current: _movieSortMode,
              options: const [
                (0, '按更新时间排序', Icons.update),
                (1, '按创建时间排序', Icons.calendar_today_outlined),
                (2, '按影视评分排序', Icons.star_outline),
                (3, '按观看日期排序', Icons.visibility_outlined),
                (4, '按上映时间排序', Icons.movie_creation_outlined),
              ],
              colors: colors,
              onChanged: (v) { _setSortMode('movie', v); setSheetState(() {}); },
            ),
            const SizedBox(height: 16),
          ]),
          ),
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
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('阅读布局', colors),
            _sheetSwitchRow(
              title: '书架模式', subtitle: '显示全部书籍，不区分状态',
              value: _bookshelfMode, onChanged: (v) { _setWallMode('book', v); setSheetState(() {}); }, colors: colors,
            ),
            if (!_bookshelfMode) ...[
              _sheetDivider(colors),
              _sheetOptionRow(
                label: '状态栏样式', selected: _bookStatusBarStyle,
                options: const [
                  (0, Icons.circle, '胶囊'),
                  (1, Icons.format_underlined, '下划线'),
                  (2, Icons.square_outlined, '芯片'),
                  (3, Icons.arrow_drop_down_circle_outlined, '下拉'),
                ],
                onChanged: (v) { _setStatusBarStyle('book', v); setSheetState(() {}); }, colors: colors,
              ),
            ],
            _sheetDivider(colors),
            _sheetOptionRow(
              label: '布局样式', selected: _bookLayout,
              options: const [(0, Icons.grid_view_outlined, '海报网格'), (1, Icons.view_list_outlined, '列表')],
              onChanged: (v) { _setLayout('book', v); setSheetState(() {}); }, colors: colors,
            ),
            _sheetDivider(colors),
            _sheetSortSection(
              title: '排序方式',
              current: _bookSortMode,
              options: const [
                (0, '按更新时间排序', Icons.update),
                (1, '按创建时间排序', Icons.calendar_today_outlined),
                (2, '按书籍评分排序', Icons.star_outline),
                (3, '按开始阅读时间排序', Icons.auto_stories_outlined),
                (4, '按出版时间排序', Icons.auto_stories_outlined),
              ],
              colors: colors,
              onChanged: (v) { _setSortMode('book', v); setSheetState(() {}); },
            ),
            const SizedBox(height: 16),
          ]),
          ),
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
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('笔记布局', colors),
            _sheetOptionRow(
              label: '布局样式', selected: _noteLayout,
              options: const [(0, Icons.view_list_outlined, '列表'), (1, Icons.grid_view_outlined, '瀑布流'), (2, Icons.timeline_outlined, '时间线')],
              onChanged: (v) { _setLayout('note', v); setSheetState(() {}); }, colors: colors,
            ),
            _sheetDivider(colors),
            _sheetSortSection(
              title: '排序方式',
              current: _noteSortMode,
              options: const [
                (0, '按更新时间排序', Icons.update),
                (1, '按创建时间排序', Icons.calendar_today_outlined),
              ],
              colors: colors,
              onChanged: (v) { _setSortMode('note', v); setSheetState(() {}); },
            ),
            const SizedBox(height: 16),
          ]),
          ),
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
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            _sheetHandle(colors),
            _sheetTitle('游戏布局', colors),
            _sheetSwitchRow(
              title: '游戏墙模式', subtitle: '显示全部游戏，不区分状态',
              value: _gameWallMode, onChanged: (v) { _setWallMode('game', v); setSheetState(() {}); }, colors: colors,
            ),
            if (!_gameWallMode) ...[
              _sheetDivider(colors),
              _sheetOptionRow(
                label: '状态栏样式', selected: _gameStatusBarStyle,
                options: const [
                  (0, Icons.circle, '胶囊'),
                  (1, Icons.format_underlined, '下划线'),
                  (2, Icons.square_outlined, '芯片'),
                  (3, Icons.arrow_drop_down_circle_outlined, '下拉'),
                ],
                onChanged: (v) { _setStatusBarStyle('game', v); setSheetState(() {}); }, colors: colors,
              ),
            ],
            _sheetDivider(colors),
            _sheetOptionRow(
              label: '布局样式', selected: _gameLayout,
              options: const [(0, Icons.grid_view_outlined, '海报网格'), (1, Icons.view_list_outlined, '列表'), (2, Icons.crop_landscape_outlined, '大图卡片')],
              onChanged: (v) { _setLayout('game', v); setSheetState(() {}); }, colors: colors,
            ),
            _sheetDivider(colors),
            _sheetSortSection(
              title: '排序方式',
              current: _gameSortMode,
              options: const [
                (0, '按更新时间排序', Icons.update),
                (1, '按创建时间排序', Icons.calendar_today_outlined),
                (2, '按游戏评分排序', Icons.star_outline),
                (3, '按发售时间排序', Icons.event_outlined),
              ],
              colors: colors,
              onChanged: (v) { _setSortMode('game', v); setSheetState(() {}); },
            ),
            const SizedBox(height: 16),
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

  void _setStatusBarStyle(String type, int value) async {
    switch (type) {
      case 'movie':
        await _userPrefs.setMovieStatusBarStyle(value);
        setState(() => _movieStatusBarStyle = value);
        if (mounted) context.read<AppProvider>().setMovieStatusBarStyle(value);
      case 'book':
        await _userPrefs.setBookStatusBarStyle(value);
        setState(() => _bookStatusBarStyle = value);
        if (mounted) context.read<AppProvider>().setBookStatusBarStyle(value);
      case 'game':
        await _userPrefs.setGameStatusBarStyle(value);
        setState(() => _gameStatusBarStyle = value);
        if (mounted) context.read<AppProvider>().setGameStatusBarStyle(value);
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

  void _setSortMode(String type, int value) async {
    final provider = context.read<AppProvider>();
    switch (type) {
      case 'movie':
        await _userPrefs.setMovieSortMode(value);
        setState(() => _movieSortMode = value);
        if (mounted) provider.loadMovies();
      case 'book':
        await _userPrefs.setBookSortMode(value);
        setState(() => _bookSortMode = value);
        if (mounted) provider.loadBooks();
      case 'note':
        await _userPrefs.setNoteSortMode(value);
        setState(() => _noteSortMode = value);
        if (mounted) provider.loadNotes();
      case 'game':
        await _userPrefs.setGameSortMode(value);
        setState(() => _gameSortMode = value);
        if (mounted) provider.loadGames();
    }
  }
}
