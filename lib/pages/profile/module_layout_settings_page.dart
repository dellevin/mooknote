import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';

/// 单个模块（影视 / 阅读 / 游戏 / 笔记）的布局设置页
///
/// 扁平分区风格（与界面设置页一致）：无分组卡片，section 小标题 + 行内选项，
/// [type] 取值：movie / book / game / note。
class ModuleLayoutSettingsPage extends StatefulWidget {
  final String type;
  const ModuleLayoutSettingsPage({super.key, required this.type});

  @override
  State<ModuleLayoutSettingsPage> createState() =>
      _ModuleLayoutSettingsPageState();
}

class _ModuleLayoutSettingsPageState extends State<ModuleLayoutSettingsPage> {
  final UserPrefs _userPrefs = UserPrefs();
  int _detailPageStyle = 0;
  int _noteLayout = 0;
  int _movieLayout = 0;
  int _bookLayout = 0;
  int _gameLayout = 0;
  int _movieGridCount = 0;
  int _bookGridCount = 0;
  int _gameGridCount = 0;
  bool _movieWallMode = false;
  int _movieDisplayMode = 0;
  int _movieStatusBarStyle = 0;
  bool _bookshelfMode = false;
  int _bookDisplayMode = 0;
  int _bookStatusBarStyle = 0;
  bool _gameWallMode = false;
  int _gameStatusBarStyle = 0;
  int _movieSortMode = 0;
  int _bookSortMode = 0;
  int _noteSortMode = 0;
  int _gameSortMode = 0;
  bool _showMovieCardDate = false;
  bool _showBookCardDate = false;
  bool _showGameCardDate = false;
  bool _showMovieTitle = true;
  bool _showMovieRating = true;
  bool _showBookTitle = true;
  bool _showBookRating = true;
  bool _showGameTitle = true;
  bool _showGameRating = true;
  late List<({String id, bool visible})> _detailModules = [];
  late List<({String id, bool visible})> _detailExtraItems = [];

  static const _titles = {
    'movie': '影视布局',
    'book': '阅读布局',
    'game': '游戏布局',
    'note': '笔记布局',
  };

  @override
  void initState() {
    super.initState();
    _detailPageStyle = _userPrefs.detailPageStyleForType(widget.type);
    _noteLayout = _userPrefs.noteLayoutStyle;
    _movieLayout = _userPrefs.movieLayoutStyle;
    _bookLayout = _userPrefs.bookLayoutStyle;
    _gameLayout = _userPrefs.gameLayoutStyle;
    _movieGridCount = _userPrefs.movieGridCount;
    _bookGridCount = _userPrefs.bookGridCount;
    _gameGridCount = _userPrefs.gameGridCount;
    _movieWallMode = _userPrefs.movieWallMode;
    _movieDisplayMode = _userPrefs.movieDisplayMode;
    _movieStatusBarStyle = _userPrefs.movieStatusBarStyle;
    _bookshelfMode = _userPrefs.bookshelfMode;
    _bookDisplayMode = _userPrefs.bookDisplayMode;
    _bookStatusBarStyle = _userPrefs.bookStatusBarStyle;
    _gameWallMode = _userPrefs.gameWallMode;
    _gameStatusBarStyle = _userPrefs.gameStatusBarStyle;
    _movieSortMode = _userPrefs.movieSortMode;
    _bookSortMode = _userPrefs.bookSortMode;
    _noteSortMode = _userPrefs.noteSortMode;
    _gameSortMode = _userPrefs.gameSortMode;
    _showMovieCardDate = _userPrefs.showMovieCardDate;
    _showBookCardDate = _userPrefs.showBookCardDate;
    _showGameCardDate = _userPrefs.showGameCardDate;
    _showMovieTitle = _userPrefs.showMovieTitle;
    _showMovieRating = _userPrefs.showMovieRating;
    _showBookTitle = _userPrefs.showBookTitle;
    _showBookRating = _userPrefs.showBookRating;
    _showGameTitle = _userPrefs.showGameTitle;
    _showGameRating = _userPrefs.showGameRating;
    if (widget.type != 'note') {
      _detailModules = _userPrefs.getDetailModules(widget.type);
      _detailExtraItems = _userPrefs.getDetailExtraItems(widget.type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text((_titles[widget.type] ?? '').tr),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: switch (widget.type) {
          'movie' => _buildMovieSections(colors),
          'book' => _buildBookSections(colors),
          'game' => _buildGameSections(colors),
          _ => _buildNoteSections(colors),
        },
      ),
    );
  }

  // ─── 分区内容 ─────────────────────────────────────────────────

  List<Widget> _buildMovieSections(ColorScheme colors) {
    return [
      _sectionHeader('卡片显示'.tr, colors),
      _switchRow(
        title: '海报显示日期'.tr, subtitle: '海报右下角显示上映日期'.tr,
        value: _showMovieCardDate, onChanged: _setShowMovieCardDate, colors: colors,
      ),
      _switchRow(
        title: '显示标题'.tr, subtitle: '卡片上显示影视名称'.tr,
        value: _showMovieTitle, onChanged: _setShowMovieTitle, colors: colors,
      ),
      _switchRow(
        title: '显示评分'.tr, subtitle: '卡片上显示评分'.tr,
        value: _showMovieRating, onChanged: _setShowMovieRating, colors: colors,
      ),
      _optionRow(
        label: '显示模式'.tr, selected: _movieWallMode ? 2 : _movieDisplayMode,
        options: [
          (0, Icons.visibility_outlined, '观看状态'.tr),
          (1, Icons.category_outlined, '分类状态'.tr),
          (2, Icons.movie_outlined, '影视墙'.tr),
        ],
        onChanged: (v) {
          if (v == 2) {
            _setWallMode('movie', true);
          } else {
            if (_movieWallMode) _setWallMode('movie', false);
            _setDisplayMode('movie', v);
          }
        },
        colors: colors,
      ),
      if (!_movieWallMode && _movieDisplayMode == 0)
        _optionRow(
          label: '状态栏样式'.tr, selected: _movieStatusBarStyle,
          options: [
            (0, Icons.circle, '胶囊'.tr),
            (1, Icons.format_underlined, '下划线'.tr),
            (2, Icons.square_outlined, '芯片'.tr),
            (3, Icons.arrow_drop_down_circle_outlined, '下拉'.tr),
          ],
          onChanged: (v) => _setStatusBarStyle('movie', v), colors: colors,
        ),
      _optionRow(
        label: '布局样式'.tr, selected: _movieLayout,
        options: [
          (0, Icons.grid_view_outlined, '海报网格'.tr),
          (1, Icons.view_list_outlined, '列表'.tr),
          (2, Icons.crop_landscape_outlined, '大图卡片'.tr),
          (3, Icons.date_range_outlined, '年份网格'.tr)
        ],
        onChanged: (v) => _setLayout('movie', v), colors: colors,
      ),
      if (_movieLayout == 0 || _movieLayout == 3)
        _optionRow(
          label: '每行数量'.tr, selected: _movieGridCount,
          options: [
            (0, Icons.auto_awesome_mosaic_outlined, '自动'.tr),
            (3, Icons.looks_3_outlined, '3'),
            (4, Icons.looks_4_outlined, '4'),
            (5, Icons.looks_5_outlined, '5'),
          ],
          onChanged: (v) => _setGridCount('movie', v), colors: colors,
        ),
      if (_movieLayout == 3)
        _sortLocked('年份网格布局固定按上映时间排序'.tr, colors)
      else
        _optionRow(
          label: '排序方式'.tr, selected: _movieSortMode,
          options: [
            (0, Icons.update, '更新时间'.tr),
            (1, Icons.calendar_today_outlined, '创建时间'.tr),
            (2, Icons.star_outline, '评分'.tr),
            (3, Icons.visibility_outlined, '观看日期'.tr),
            (4, Icons.movie_creation_outlined, '上映时间'.tr),
          ],
          onChanged: (v) => _setSortMode('movie', v), colors: colors,
        ),
      if (widget.type != 'note') ..._buildDetailSection(colors),
    ];
  }

  List<Widget> _buildBookSections(ColorScheme colors) {
    return [
      _sectionHeader('卡片显示'.tr, colors),
      _switchRow(
        title: '封面显示日期'.tr, subtitle: '封面右下角显示出版日期'.tr,
        value: _showBookCardDate, onChanged: _setShowBookCardDate, colors: colors,
      ),
      _switchRow(
        title: '显示标题'.tr, subtitle: '卡片上显示书籍名称'.tr,
        value: _showBookTitle, onChanged: _setShowBookTitle, colors: colors,
      ),
      _switchRow(
        title: '显示评分'.tr, subtitle: '卡片上显示评分'.tr,
        value: _showBookRating, onChanged: _setShowBookRating, colors: colors,
      ),
      _optionRow(
        label: '显示模式'.tr, selected: _bookshelfMode ? 2 : _bookDisplayMode,
        options: [
          (0, Icons.auto_stories_outlined, '阅读状态'.tr),
          (1, Icons.category_outlined, '分类状态'.tr),
          (2, Icons.menu_book_outlined, '书架'.tr),
        ],
        onChanged: (v) {
          if (v == 2) {
            _setWallMode('book', true);
          } else {
            if (_bookshelfMode) _setWallMode('book', false);
            _setDisplayMode('book', v);
          }
        },
        colors: colors,
      ),
      if (!_bookshelfMode && _bookDisplayMode == 0)
        _optionRow(
          label: '状态栏样式'.tr, selected: _bookStatusBarStyle,
          options: [
            (0, Icons.circle, '胶囊'.tr),
            (1, Icons.format_underlined, '下划线'.tr),
            (2, Icons.square_outlined, '芯片'.tr),
            (3, Icons.arrow_drop_down_circle_outlined, '下拉'.tr),
          ],
          onChanged: (v) => _setStatusBarStyle('book', v), colors: colors,
        ),
      _optionRow(
        label: '布局样式'.tr, selected: _bookLayout,
        options: [
          (0, Icons.grid_view_outlined, '海报网格'.tr),
          (1, Icons.view_list_outlined, '列表'.tr),
          (3, Icons.crop_landscape_outlined, '大图卡片'.tr),
          (2, Icons.date_range_outlined, '年份网格'.tr)
        ],
        onChanged: (v) => _setLayout('book', v), colors: colors,
      ),
      if (_bookLayout == 0 || _bookLayout == 2)
        _optionRow(
          label: '每行数量'.tr, selected: _bookGridCount,
          options: [
            (0, Icons.auto_awesome_mosaic_outlined, '自动'.tr),
            (3, Icons.looks_3_outlined, '3'),
            (4, Icons.looks_4_outlined, '4'),
            (5, Icons.looks_5_outlined, '5'),
          ],
          onChanged: (v) => _setGridCount('book', v), colors: colors,
        ),
      if (_bookLayout == 2)
        _sortLocked('年份网格布局固定按出版时间排序'.tr, colors)
      else
        _optionRow(
          label: '排序方式'.tr, selected: _bookSortMode,
          options: [
            (0, Icons.update, '更新时间'.tr),
            (1, Icons.calendar_today_outlined, '创建时间'.tr),
            (2, Icons.star_outline, '评分'.tr),
            (3, Icons.auto_stories_outlined, '开始阅读'.tr),
            (4, Icons.auto_stories_outlined, '出版时间'.tr),
          ],
          onChanged: (v) => _setSortMode('book', v), colors: colors,
        ),
      ..._buildDetailSection(colors),
    ];
  }

  List<Widget> _buildGameSections(ColorScheme colors) {
    return [
      _sectionHeader('卡片显示'.tr, colors),
      _switchRow(
        title: '封面显示日期'.tr, subtitle: '封面右下角显示发售日期'.tr,
        value: _showGameCardDate, onChanged: _setShowGameCardDate, colors: colors,
      ),
      _switchRow(
        title: '显示标题'.tr, subtitle: '卡片上显示游戏名称'.tr,
        value: _showGameTitle, onChanged: _setShowGameTitle, colors: colors,
      ),
      _switchRow(
        title: '显示评分'.tr, subtitle: '卡片上显示评分'.tr,
        value: _showGameRating, onChanged: _setShowGameRating, colors: colors,
      ),
      _optionRow(
        label: '显示模式'.tr, selected: _gameWallMode ? 1 : 0,
        options: [
          (0, Icons.sports_esports_outlined, '游玩状态'.tr),
          (1, Icons.grid_view_outlined, '游戏墙'.tr),
        ],
        onChanged: (v) => _setWallMode('game', v == 1), colors: colors,
      ),
      if (!_gameWallMode)
        _optionRow(
          label: '状态栏样式'.tr, selected: _gameStatusBarStyle,
          options: [
            (0, Icons.circle, '胶囊'.tr),
            (1, Icons.format_underlined, '下划线'.tr),
            (2, Icons.square_outlined, '芯片'.tr),
            (3, Icons.arrow_drop_down_circle_outlined, '下拉'.tr),
          ],
          onChanged: (v) => _setStatusBarStyle('game', v), colors: colors,
        ),
      _optionRow(
        label: '布局样式'.tr, selected: _gameLayout,
        options: [
          (0, Icons.grid_view_outlined, '海报网格'.tr),
          (1, Icons.view_list_outlined, '列表'.tr),
          (2, Icons.crop_landscape_outlined, '大图卡片'.tr),
          (3, Icons.date_range_outlined, '年份网格'.tr)
        ],
        onChanged: (v) => _setLayout('game', v), colors: colors,
      ),
      if (_gameLayout == 0 || _gameLayout == 3)
        _optionRow(
          label: '每行数量'.tr, selected: _gameGridCount,
          options: [
            (0, Icons.auto_awesome_mosaic_outlined, '自动'.tr),
            (3, Icons.looks_3_outlined, '3'),
            (4, Icons.looks_4_outlined, '4'),
            (5, Icons.looks_5_outlined, '5'),
          ],
          onChanged: (v) => _setGridCount('game', v), colors: colors,
        ),
      if (_gameLayout == 3)
        _sortLocked('年份网格布局固定按发售时间排序'.tr, colors)
      else
        _optionRow(
          label: '排序方式'.tr, selected: _gameSortMode,
          options: [
            (0, Icons.update, '更新时间'.tr),
            (1, Icons.calendar_today_outlined, '创建时间'.tr),
            (2, Icons.star_outline, '评分'.tr),
            (3, Icons.event_outlined, '发售时间'.tr),
            (4, Icons.emoji_events_outlined, '通关时间'.tr),
          ],
          onChanged: (v) => _setSortMode('game', v), colors: colors,
        ),
      ..._buildDetailSection(colors),
    ];
  }

  List<Widget> _buildNoteSections(ColorScheme colors) {
    return [
      _optionRow(
        label: '布局样式'.tr, selected: _noteLayout,
        options: [
          (0, Icons.view_list_outlined, '列表'.tr),
          (1, Icons.grid_view_outlined, '瀑布流'.tr),
          (2, Icons.timeline_outlined, '时间线'.tr)
        ],
        onChanged: (v) => _setLayout('note', v), colors: colors,
      ),
      _optionRow(
        label: '排序方式'.tr, selected: _noteSortMode,
        options: [
          (0, Icons.update, '更新时间'.tr),
          (1, Icons.calendar_today_outlined, '创建时间'.tr),
        ],
        onChanged: (v) => _setSortMode('note', v), colors: colors,
      ),
    ];
  }

  /// 详情页分区：样式 4 选 1（按模块独立保存）+ 模块/更多入口子项排序显隐（内联）
  List<Widget> _buildDetailSection(ColorScheme colors) {
    final visible = _detailModules.where((m) => m.visible).length;
    final extraVisible = _detailExtraItems.where((m) => m.visible).length;
    return [
      _optionRow(
        label: '详情页样式'.tr, selected: _detailPageStyle,
        options: [
          (0, Icons.article_outlined, '默认样式'.tr),
          (1, Icons.blur_on_outlined, '毛玻璃层叠'.tr),
          (2, Icons.layers_outlined, '浅色极简'.tr),
          (3, Icons.art_track_outlined, '豆瓣风格'.tr),
        ],
        colors: colors,
        onChanged: (v) async {
          await _userPrefs.setDetailPageStyleForType(widget.type, v);
          setState(() => _detailPageStyle = v);
        },
      ),
      _reorderHeader(
        '详情页模块（显示 {a}/{b}）'.trf({
          'a': '$visible',
          'b': '${_detailModules.length}'
        }),
        _resetDetailModules,
        colors,
      ),
      _buildReorderList(
        items: _detailModules,
        labelOf: _detailModuleLabel,
        onReorder: _onReorderDetailModules,
        onToggle: _toggleDetailModule,
        colors: colors,
      ),
      _reorderHeader(
        '更多入口内容（显示 {a}/{b}）'.trf({
          'a': '$extraVisible',
          'b': '${_detailExtraItems.length}'
        }),
        _resetExtraItems,
        colors,
      ),
      _buildReorderList(
        items: _detailExtraItems,
        labelOf: _extraItemLabel,
        onReorder: _onReorderExtraItems,
        onToggle: _toggleExtraItem,
        colors: colors,
      ),
    ];
  }

  /// 排序显隐列表的小标题 + 右侧重置
  Widget _reorderHeader(String title, VoidCallback onReset, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          GestureDetector(
            onTap: onReset,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('重置'.tr,
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.5))),
            ),
          ),
        ],
      ),
    );
  }

  /// 可拖拽排序 + 开关显隐的扁平列表
  Widget _buildReorderList({
    required List<({String id, bool visible})> items,
    required String Function(String id) labelOf,
    required void Function(int oldIndex, int newIndex) onReorder,
    required void Function(int index, bool visible) onToggle,
    required ColorScheme colors,
  }) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: onReorder,
      itemBuilder: (_, i) {
        final m = items[i];
        return Row(
          key: ValueKey(m.id),
          children: [
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Icon(Icons.drag_indicator,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: 0.3)),
              ),
            ),
            Expanded(
              child: Text(labelOf(m.id).tr,
                  style: TextStyle(
                      fontSize: 14,
                      color: m.visible
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.35))),
            ),
            Switch(
              value: m.visible,
              onChanged: (v) => onToggle(i, v),
            ),
          ],
        );
      },
    );
  }

  /// 详情页模块 id → 显示名（按当前模块区分文案）
  String _detailModuleLabel(String id) {
    return switch (id) {
      'credits' => switch (widget.type) {
          'book' => '书籍信息',
          'game' => '游戏信息',
          _ => '演职员信息',
        },
      'genres' => '类型标签',
      'characters' => '角色',
      'people' => '关联人物',
      'summary' => '简介',
      'reviews' => switch (widget.type) {
          'book' => '书评预览',
          'game' => '评价预览',
          _ => '影评预览',
        },
      'extra' => '更多入口',
      _ => id,
    };
  }

  /// 「更多入口」子项 id → 显示名（按当前模块区分文案）
  String _extraItemLabel(String id) {
    return switch (id) {
      'progress' => switch (widget.type) {
          'book' => '阅读进度',
          'game' => '游戏进度',
          _ => '观看进度',
        },
      'reviews' => switch (widget.type) {
          'book' => '书评',
          'game' => '游戏评价',
          _ => '影评',
        },
      'posters' => '海报墙',
      'excerpts' => '摘抄',
      'screenshots' => '游戏截图',
      'characters' => '角色',
      _ => id,
    };
  }

  void _onReorderDetailModules(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      _detailModules.insert(newIndex, _detailModules.removeAt(oldIndex));
    });
    _userPrefs.setDetailModules(widget.type, _detailModules);
  }

  void _toggleDetailModule(int index, bool visible) {
    setState(() {
      _detailModules[index] =
          (id: _detailModules[index].id, visible: visible);
    });
    _userPrefs.setDetailModules(widget.type, _detailModules);
  }

  void _resetDetailModules() {
    setState(() {
      _detailModules = [
        for (final id in UserPrefs.detailModuleIds) (id: id, visible: true)
      ];
    });
    _userPrefs.setDetailModules(widget.type, _detailModules);
    ToastUtil.show(context, '已恢复默认'.tr);
  }

  void _onReorderExtraItems(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      _detailExtraItems.insert(newIndex, _detailExtraItems.removeAt(oldIndex));
    });
    _userPrefs.setDetailExtraItems(widget.type, _detailExtraItems);
  }

  void _toggleExtraItem(int index, bool visible) {
    setState(() {
      _detailExtraItems[index] =
          (id: _detailExtraItems[index].id, visible: visible);
    });
    _userPrefs.setDetailExtraItems(widget.type, _detailExtraItems);
  }

  void _resetExtraItems() {
    setState(() {
      _detailExtraItems = [
        for (final id in UserPrefs.detailExtraItemIds[widget.type] ?? const [])
          (id: id, visible: true)
      ];
    });
    _userPrefs.setDetailExtraItems(widget.type, _detailExtraItems);
    ToastUtil.show(context, '已恢复默认'.tr);
  }

  // ─── 扁平分区组件 ─────────────────────────────────────────────

  /// 分区小标题：与界面设置页同一风格，无背景
  Widget _sectionHeader(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(alpha: 0.6))),
    );
  }

  Widget _switchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ColorScheme colors,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 选项组：label 作小标题，每个选项一行（图标盒 + 文字 + 选中勾），行间细分隔线
  Widget _optionRow({
    required String label,
    required int selected,
    required List<(int, IconData, String)> options,
    required ValueChanged<int> onChanged,
    required ColorScheme colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface.withValues(alpha: 0.6))),
        ),
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0)
            Divider(
                height: 0.5,
                indent: 48,
                endIndent: 4,
                color: colors.outlineVariant.withValues(alpha: 0.4)),
          _optionLine(options[i], selected, colors, onChanged),
        ],
      ],
    );
  }

  Widget _optionLine((int, IconData, String) option, int selected,
      ColorScheme colors, ValueChanged<int> onChanged) {
    final isSelected = selected == option.$1;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(option.$1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(option.$2,
                size: 18,
                color: isSelected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(option.$3,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: colors.onSurface)),
          ),
          if (isSelected) Icon(Icons.check, size: 18, color: colors.primary),
        ]),
      ),
    );
  }

  /// 年份网格布局下排序被锁定时的提示行
  Widget _sortLocked(String text, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 15, color: colors.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)))),
      ]),
    );
  }

  // ─── 状态更新 ──────────────────────────────────────────────────

  void _setShowMovieCardDate(bool value) async {
    await _userPrefs.setShowMovieCardDate(value);
    setState(() => _showMovieCardDate = value);
    if (mounted) context.read<AppProvider>().setShowMovieCardDate(value);
  }

  void _setShowBookCardDate(bool value) async {
    await _userPrefs.setShowBookCardDate(value);
    setState(() => _showBookCardDate = value);
    if (mounted) context.read<AppProvider>().setShowBookCardDate(value);
  }

  void _setShowGameCardDate(bool value) async {
    await _userPrefs.setShowGameCardDate(value);
    setState(() => _showGameCardDate = value);
    if (mounted) context.read<AppProvider>().setShowGameCardDate(value);
  }

  void _setShowMovieTitle(bool value) async {
    await _userPrefs.setShowMovieTitle(value);
    setState(() => _showMovieTitle = value);
    if (mounted) context.read<AppProvider>().setShowMovieTitle(value);
  }

  void _setShowMovieRating(bool value) async {
    await _userPrefs.setShowMovieRating(value);
    setState(() => _showMovieRating = value);
    if (mounted) context.read<AppProvider>().setShowMovieRating(value);
  }

  void _setShowBookTitle(bool value) async {
    await _userPrefs.setShowBookTitle(value);
    setState(() => _showBookTitle = value);
    if (mounted) context.read<AppProvider>().setShowBookTitle(value);
  }

  void _setShowBookRating(bool value) async {
    await _userPrefs.setShowBookRating(value);
    setState(() => _showBookRating = value);
    if (mounted) context.read<AppProvider>().setShowBookRating(value);
  }

  void _setShowGameTitle(bool value) async {
    await _userPrefs.setShowGameTitle(value);
    setState(() => _showGameTitle = value);
    if (mounted) context.read<AppProvider>().setShowGameTitle(value);
  }

  void _setShowGameRating(bool value) async {
    await _userPrefs.setShowGameRating(value);
    setState(() => _showGameRating = value);
    if (mounted) context.read<AppProvider>().setShowGameRating(value);
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

  void _setDisplayMode(String type, int value) async {
    switch (type) {
      case 'movie':
        await _userPrefs.setMovieDisplayMode(value);
        setState(() => _movieDisplayMode = value);
        if (mounted) context.read<AppProvider>().setMovieDisplayMode(value);
      case 'book':
        await _userPrefs.setBookDisplayMode(value);
        setState(() => _bookDisplayMode = value);
        if (mounted) context.read<AppProvider>().setBookDisplayMode(value);
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

  void _setGridCount(String type, int value) async {
    final provider = context.read<AppProvider>();
    switch (type) {
      case 'movie':
        setState(() => _movieGridCount = value);
        provider.setMovieGridCount(value);
      case 'book':
        setState(() => _bookGridCount = value);
        provider.setBookGridCount(value);
      case 'game':
        setState(() => _gameGridCount = value);
        provider.setGameGridCount(value);
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
        if (mounted) context.read<AppProvider>().setBookLayoutStyle(value);
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
