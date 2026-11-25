import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_overlay.dart';
import 'detail_items_settings_page.dart';

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
  int _noteContentAlign = 0;
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
  int _movieYearGridBasis = 0;
  int _bookYearGridBasis = 0;
  int _gameYearGridBasis = 0;
  bool _showMovieCardDate = false;
  bool _showBookCardDate = false;
  bool _showGameCardDate = false;
  int _movieCardDateType = 0;
  int _bookCardDateType = 0;
  int _gameCardDateType = 0;
  int _movieCardTitleAlign = 0;
  int _movieCardRatingAlign = 0;
  int _bookCardTitleAlign = 0;
  int _bookCardRatingAlign = 0;
  int _gameCardTitleAlign = 0;
  int _gameCardRatingAlign = 0;
  bool _showMovieTitle = true;
  bool _showMovieRating = true;
  bool _showBookTitle = true;
  bool _showBookRating = true;
  bool _showGameTitle = true;
  bool _showGameRating = true;

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
    _noteContentAlign = _userPrefs.noteContentAlign;
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
    _movieYearGridBasis = _userPrefs.movieYearGridBasis;
    _bookYearGridBasis = _userPrefs.bookYearGridBasis;
    _gameYearGridBasis = _userPrefs.gameYearGridBasis;
    _showMovieCardDate = _userPrefs.showMovieCardDate;
    _showBookCardDate = _userPrefs.showBookCardDate;
    _showGameCardDate = _userPrefs.showGameCardDate;
    _movieCardDateType = _userPrefs.movieCardDateType;
    _bookCardDateType = _userPrefs.bookCardDateType;
    _gameCardDateType = _userPrefs.gameCardDateType;
    _movieCardTitleAlign = _userPrefs.movieCardTitleAlign;
    _movieCardRatingAlign = _userPrefs.movieCardRatingAlign;
    _bookCardTitleAlign = _userPrefs.bookCardTitleAlign;
    _bookCardRatingAlign = _userPrefs.bookCardRatingAlign;
    _gameCardTitleAlign = _userPrefs.gameCardTitleAlign;
    _gameCardRatingAlign = _userPrefs.gameCardRatingAlign;
    _showMovieTitle = _userPrefs.showMovieTitle;
    _showMovieRating = _userPrefs.showMovieRating;
    _showBookTitle = _userPrefs.showBookTitle;
    _showBookRating = _userPrefs.showBookRating;
    _showGameTitle = _userPrefs.showGameTitle;
    _showGameRating = _userPrefs.showGameRating;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
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
        title: '海报显示日期'.tr,
        subtitle: '海报右下角显示所选日期'.tr,
        value: _showMovieCardDate,
        onChanged: _setShowMovieCardDate,
        colors: colors,
      ),
      _switchRow(
        title: '显示标题'.tr,
        subtitle: '卡片上显示影视名称'.tr,
        value: _showMovieTitle,
        onChanged: _setShowMovieTitle,
        colors: colors,
      ),
      _switchRow(
        title: '显示评分'.tr,
        subtitle: '卡片上显示评分'.tr,
        value: _showMovieRating,
        onChanged: _setShowMovieRating,
        colors: colors,
      ),
      if (_showMovieCardDate)
        _optionRow(
          label: '日期内容'.tr,
          selected: _movieCardDateType,
          options: [
            (0, Icons.movie_creation_outlined, '上映日期'.tr),
            (1, Icons.visibility_outlined, '观看日期'.tr),
          ],
          onChanged: (v) {
            context.read<AppProvider>().setMovieCardDateType(v);
            setState(() => _movieCardDateType = v);
          },
          colors: colors,
        ),
      _optionRow(
        label: '标题对齐'.tr,
        selected: _movieCardTitleAlign,
        options: [
          (0, Icons.format_align_left, '靠左'.tr),
          (1, Icons.format_align_center, '居中'.tr),
          (2, Icons.format_align_right, '靠右'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setMovieCardTitleAlign(v);
          setState(() => _movieCardTitleAlign = v);
        },
        colors: colors,
      ),
      _optionRow(
        label: '评分对齐'.tr,
        selected: _movieCardRatingAlign,
        options: [
          (0, Icons.format_align_left, '靠左'.tr),
          (1, Icons.format_align_center, '居中'.tr),
          (2, Icons.format_align_right, '靠右'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setMovieCardRatingAlign(v);
          setState(() => _movieCardRatingAlign = v);
        },
        colors: colors,
      ),
      _optionRow(
        label: '显示模式'.tr,
        selected: _movieWallMode ? 2 : _movieDisplayMode,
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
          label: '状态栏样式'.tr,
          selected: _movieStatusBarStyle,
          options: [
            (0, Icons.circle, '胶囊'.tr),
            (1, Icons.format_underlined, '下划线'.tr),
            (2, Icons.square_outlined, '芯片'.tr),
            (3, Icons.arrow_drop_down_circle_outlined, '下拉'.tr),
            (4, Icons.touch_app_outlined, '模块内点击'.tr),
          ],
          onChanged: (v) => _setStatusBarStyle('movie', v),
          colors: colors,
        ),
      _optionRow(
        label: '布局样式'.tr,
        selected: _movieLayout,
        options: [
          (0, Icons.grid_view_outlined, '海报网格'.tr),
          (1, Icons.view_list_outlined, '列表'.tr),
          (2, Icons.crop_landscape_outlined, '大图卡片'.tr),
          (3, Icons.date_range_outlined, '年份网格'.tr)
        ],
        onChanged: (v) => _setLayout('movie', v),
        colors: colors,
      ),
      if (_movieLayout == 0 || _movieLayout == 3)
        _optionRow(
          label: '每行数量'.tr,
          selected: _movieGridCount,
          options: [
            (0, Icons.auto_awesome_mosaic_outlined, '自动'.tr),
            (3, Icons.looks_3_outlined, '3'),
            (4, Icons.looks_4_outlined, '4'),
            (5, Icons.looks_5_outlined, '5'),
          ],
          onChanged: (v) => _setGridCount('movie', v),
          colors: colors,
        ),
      if (_movieLayout == 3)
        _optionRow(
          label: '年份依据'.tr,
          selected: _movieYearGridBasis,
          options: [
            (0, Icons.movie_creation_outlined, '上映时间'.tr),
            (1, Icons.visibility_outlined, '观看日期'.tr),
          ],
          onChanged: (v) => _setYearGridBasis('movie', v),
          colors: colors,
        )
      else
        _optionRow(
          label: '排序方式'.tr,
          selected: _movieSortMode,
          options: [
            (0, Icons.update, '更新时间'.tr),
            (1, Icons.calendar_today_outlined, '创建时间'.tr),
            (2, Icons.star_outline, '评分'.tr),
            (3, Icons.visibility_outlined, '观看日期'.tr),
            (4, Icons.movie_creation_outlined, '上映时间'.tr),
          ],
          onChanged: (v) => _setSortMode('movie', v),
          colors: colors,
        ),
      if (widget.type != 'note') ..._buildDetailSection(colors),
    ];
  }

  List<Widget> _buildBookSections(ColorScheme colors) {
    return [
      _sectionHeader('卡片显示'.tr, colors),
      _switchRow(
        title: '封面显示日期'.tr,
        subtitle: '封面右下角显示所选日期'.tr,
        value: _showBookCardDate,
        onChanged: _setShowBookCardDate,
        colors: colors,
      ),
      _switchRow(
        title: '显示标题'.tr,
        subtitle: '卡片上显示书籍名称'.tr,
        value: _showBookTitle,
        onChanged: _setShowBookTitle,
        colors: colors,
      ),
      _switchRow(
        title: '显示评分'.tr,
        subtitle: '卡片上显示评分'.tr,
        value: _showBookRating,
        onChanged: _setShowBookRating,
        colors: colors,
      ),
      if (_showBookCardDate)
        _optionRow(
          label: '日期内容'.tr,
          selected: _bookCardDateType,
          options: [
            (0, Icons.menu_book_outlined, '出版时间'.tr),
            (1, Icons.play_arrow_outlined, '开始阅读时间'.tr),
            (2, Icons.check_circle_outline, '结束阅读时间'.tr),
          ],
          onChanged: (v) {
            context.read<AppProvider>().setBookCardDateType(v);
            setState(() => _bookCardDateType = v);
          },
          colors: colors,
        ),
      _optionRow(
        label: '标题对齐'.tr,
        selected: _bookCardTitleAlign,
        options: [
          (0, Icons.format_align_left, '靠左'.tr),
          (1, Icons.format_align_center, '居中'.tr),
          (2, Icons.format_align_right, '靠右'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setBookCardTitleAlign(v);
          setState(() => _bookCardTitleAlign = v);
        },
        colors: colors,
      ),
      _optionRow(
        label: '评分对齐'.tr,
        selected: _bookCardRatingAlign,
        options: [
          (0, Icons.format_align_left, '靠左'.tr),
          (1, Icons.format_align_center, '居中'.tr),
          (2, Icons.format_align_right, '靠右'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setBookCardRatingAlign(v);
          setState(() => _bookCardRatingAlign = v);
        },
        colors: colors,
      ),
      _optionRow(
        label: '显示模式'.tr,
        selected: _bookshelfMode ? 2 : _bookDisplayMode,
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
          label: '状态栏样式'.tr,
          selected: _bookStatusBarStyle,
          options: [
            (0, Icons.circle, '胶囊'.tr),
            (1, Icons.format_underlined, '下划线'.tr),
            (2, Icons.square_outlined, '芯片'.tr),
            (3, Icons.arrow_drop_down_circle_outlined, '下拉'.tr),
            (4, Icons.touch_app_outlined, '模块内点击'.tr),
          ],
          onChanged: (v) => _setStatusBarStyle('book', v),
          colors: colors,
        ),
      _optionRow(
        label: '布局样式'.tr,
        selected: _bookLayout,
        options: [
          (0, Icons.grid_view_outlined, '海报网格'.tr),
          (1, Icons.view_list_outlined, '列表'.tr),
          (3, Icons.crop_landscape_outlined, '大图卡片'.tr),
          (2, Icons.date_range_outlined, '年份网格'.tr)
        ],
        onChanged: (v) => _setLayout('book', v),
        colors: colors,
      ),
      if (_bookLayout == 0 || _bookLayout == 2)
        _optionRow(
          label: '每行数量'.tr,
          selected: _bookGridCount,
          options: [
            (0, Icons.auto_awesome_mosaic_outlined, '自动'.tr),
            (3, Icons.looks_3_outlined, '3'),
            (4, Icons.looks_4_outlined, '4'),
            (5, Icons.looks_5_outlined, '5'),
          ],
          onChanged: (v) => _setGridCount('book', v),
          colors: colors,
        ),
      if (_bookLayout == 2)
        _optionRow(
          label: '年份依据'.tr,
          selected: _bookYearGridBasis,
          options: [
            (0, Icons.auto_stories_outlined, '出版时间'.tr),
            (1, Icons.auto_stories_outlined, '开始阅读'.tr),
            (2, Icons.done_all_outlined, '读完时间'.tr),
          ],
          onChanged: (v) => _setYearGridBasis('book', v),
          colors: colors,
        )
      else
        _optionRow(
          label: '排序方式'.tr,
          selected: _bookSortMode,
          options: [
            (0, Icons.update, '更新时间'.tr),
            (1, Icons.calendar_today_outlined, '创建时间'.tr),
            (2, Icons.star_outline, '评分'.tr),
            (3, Icons.auto_stories_outlined, '开始阅读'.tr),
            (4, Icons.auto_stories_outlined, '出版时间'.tr),
          ],
          onChanged: (v) => _setSortMode('book', v),
          colors: colors,
        ),
      ..._buildDetailSection(colors),
    ];
  }

  List<Widget> _buildGameSections(ColorScheme colors) {
    return [
      _sectionHeader('卡片显示'.tr, colors),
      _switchRow(
        title: '封面显示日期'.tr,
        subtitle: '封面右下角显示所选日期'.tr,
        value: _showGameCardDate,
        onChanged: _setShowGameCardDate,
        colors: colors,
      ),
      _switchRow(
        title: '显示标题'.tr,
        subtitle: '卡片上显示游戏名称'.tr,
        value: _showGameTitle,
        onChanged: _setShowGameTitle,
        colors: colors,
      ),
      _switchRow(
        title: '显示评分'.tr,
        subtitle: '卡片上显示评分'.tr,
        value: _showGameRating,
        onChanged: _setShowGameRating,
        colors: colors,
      ),
      if (_showGameCardDate)
        _optionRow(
          label: '日期内容'.tr,
          selected: _gameCardDateType,
          options: [
            (0, Icons.event_outlined, '发售时间'.tr),
            (1, Icons.shopping_bag_outlined, '购买时间'.tr),
          ],
          onChanged: (v) {
            context.read<AppProvider>().setGameCardDateType(v);
            setState(() => _gameCardDateType = v);
          },
          colors: colors,
        ),
      _optionRow(
        label: '标题对齐'.tr,
        selected: _gameCardTitleAlign,
        options: [
          (0, Icons.format_align_left, '靠左'.tr),
          (1, Icons.format_align_center, '居中'.tr),
          (2, Icons.format_align_right, '靠右'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setGameCardTitleAlign(v);
          setState(() => _gameCardTitleAlign = v);
        },
        colors: colors,
      ),
      _optionRow(
        label: '评分对齐'.tr,
        selected: _gameCardRatingAlign,
        options: [
          (0, Icons.format_align_left, '靠左'.tr),
          (1, Icons.format_align_center, '居中'.tr),
          (2, Icons.format_align_right, '靠右'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setGameCardRatingAlign(v);
          setState(() => _gameCardRatingAlign = v);
        },
        colors: colors,
      ),
      _optionRow(
        label: '显示模式'.tr,
        selected: _gameWallMode ? 1 : 0,
        options: [
          (0, Icons.sports_esports_outlined, '游玩状态'.tr),
          (1, Icons.grid_view_outlined, '游戏墙'.tr),
        ],
        onChanged: (v) => _setWallMode('game', v == 1),
        colors: colors,
      ),
      if (!_gameWallMode)
        _optionRow(
          label: '状态栏样式'.tr,
          selected: _gameStatusBarStyle,
          options: [
            (0, Icons.circle, '胶囊'.tr),
            (1, Icons.format_underlined, '下划线'.tr),
            (2, Icons.square_outlined, '芯片'.tr),
            (3, Icons.arrow_drop_down_circle_outlined, '下拉'.tr),
            (4, Icons.touch_app_outlined, '模块内点击'.tr),
          ],
          onChanged: (v) => _setStatusBarStyle('game', v),
          colors: colors,
        ),
      _optionRow(
        label: '布局样式'.tr,
        selected: _gameLayout,
        options: [
          (0, Icons.grid_view_outlined, '海报网格'.tr),
          (1, Icons.view_list_outlined, '列表'.tr),
          (2, Icons.crop_landscape_outlined, '大图卡片'.tr),
          (3, Icons.date_range_outlined, '年份网格'.tr)
        ],
        onChanged: (v) => _setLayout('game', v),
        colors: colors,
      ),
      if (_gameLayout == 0 || _gameLayout == 3)
        _optionRow(
          label: '每行数量'.tr,
          selected: _gameGridCount,
          options: [
            (0, Icons.auto_awesome_mosaic_outlined, '自动'.tr),
            (3, Icons.looks_3_outlined, '3'),
            (4, Icons.looks_4_outlined, '4'),
            (5, Icons.looks_5_outlined, '5'),
          ],
          onChanged: (v) => _setGridCount('game', v),
          colors: colors,
        ),
      if (_gameLayout == 3)
        _optionRow(
          label: '年份依据'.tr,
          selected: _gameYearGridBasis,
          options: [
            (0, Icons.event_outlined, '发售时间'.tr),
            (1, Icons.sports_esports_outlined, '游玩时间'.tr),
          ],
          onChanged: (v) => _setYearGridBasis('game', v),
          colors: colors,
        )
      else
        _optionRow(
          label: '排序方式'.tr,
          selected: _gameSortMode,
          options: [
            (0, Icons.update, '更新时间'.tr),
            (1, Icons.calendar_today_outlined, '创建时间'.tr),
            (2, Icons.star_outline, '评分'.tr),
            (3, Icons.event_outlined, '发售时间'.tr),
            (4, Icons.emoji_events_outlined, '通关时间'.tr),
          ],
          onChanged: (v) => _setSortMode('game', v),
          colors: colors,
        ),
      ..._buildDetailSection(colors),
    ];
  }

  List<Widget> _buildNoteSections(ColorScheme colors) {
    return [
      _optionRow(
        label: '布局样式'.tr,
        selected: _noteLayout,
        options: [
          (0, Icons.view_list_outlined, '列表'.tr),
          (1, Icons.grid_view_outlined, '瀑布流'.tr),
          (2, Icons.timeline_outlined, '时间线'.tr)
        ],
        onChanged: (v) => _setLayout('note', v),
        colors: colors,
      ),
      _optionRow(
        label: '排序方式'.tr,
        selected: _noteSortMode,
        options: [
          (0, Icons.update, '更新时间'.tr),
          (1, Icons.calendar_today_outlined, '创建时间'.tr),
        ],
        onChanged: (v) => _setSortMode('note', v),
        colors: colors,
      ),
      _optionRow(
        label: '正文对齐'.tr,
        selected: _noteContentAlign,
        options: [
          (0, Icons.format_align_left_outlined, '左对齐'.tr),
          (1, Icons.format_align_justify_outlined, '两侧对齐'.tr),
          (2, Icons.format_align_right_outlined, '右对齐'.tr),
        ],
        onChanged: (v) {
          context.read<AppProvider>().setNoteContentAlign(v);
          setState(() => _noteContentAlign = v);
        },
        colors: colors,
      ),
    ];
  }

  /// 详情页分区：样式 4 选 1（按模块独立保存）+ 模块/更多入口入口行
  /// （排序与显隐跳转到独立页面设置）
  List<Widget> _buildDetailSection(ColorScheme colors) {
    return [
      _optionRow(
        label: '详情页样式'.tr,
        selected: _detailPageStyle,
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
      _detailItemsEntry(colors, isExtra: false),
      _detailItemsEntry(colors, isExtra: true),
    ];
  }

  /// 详情页模块 / 更多入口内容 入口行：右侧显示已开启数量，点击跳转设置页
  Widget _detailItemsEntry(ColorScheme colors, {required bool isExtra}) {
    final items = isExtra
        ? _userPrefs.getDetailExtraItems(widget.type)
        : _userPrefs.getDetailModules(widget.type);
    final visible = items.where((m) => m.visible).length;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  DetailItemsSettingsPage(type: widget.type, isExtra: isExtra)),
        );
        if (mounted) setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Text(isExtra ? '更多入口内容'.tr : '详情页模块'.tr,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
          ),
          Text('$visible/${items.length}',
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.45))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
        ]),
      ),
    );
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
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.45))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 选项组：一行显示当前选中项，点击从底部弹出固定高度的选择弹窗
  Widget _optionRow({
    required String label,
    required int selected,
    required List<(int, IconData, String)> options,
    required ValueChanged<int> onChanged,
    required ColorScheme colors,
  }) {
    final current = options.firstWhere((o) => o.$1 == selected,
        orElse: () => options.first);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showOptionSheet(
        label: label,
        selected: selected,
        options: options,
        onChanged: onChanged,
        colors: colors,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
          ),
          Text(current.$3,
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.45))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right,
              size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
        ]),
      ),
    );
  }

  /// 底部选择弹窗：固定高度，选项超出可上下滚动，点选后自动关闭
  void _showOptionSheet({
    required String label,
    required int selected,
    required List<(int, IconData, String)> options,
    required ValueChanged<int> onChanged,
    required ColorScheme colors,
  }) {
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 360,
          child: Column(children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: options.length,
                separatorBuilder: (_, __) => Divider(
                    height: 0.5,
                    indent: 48,
                    endIndent: 4,
                    color: colors.outlineVariant.withValues(alpha: 0.4)),
                itemBuilder: (_, i) =>
                    _optionLine(options[i], selected, colors, (v) {
                  onChanged(v);
                  Navigator.pop(ctx);
                }),
              ),
            ),
          ]),
        ),
      ),
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

  /// 年份网格分组依据：会改变实际生效的排序，需重载列表
  /// （tab 页监听生效排序变化后自行重置分页）
  void _setYearGridBasis(String type, int value) async {
    final provider = context.read<AppProvider>();
    switch (type) {
      case 'movie':
        await _userPrefs.setMovieYearGridBasis(value);
        setState(() => _movieYearGridBasis = value);
        if (mounted) provider.loadMovies();
      case 'book':
        await _userPrefs.setBookYearGridBasis(value);
        setState(() => _bookYearGridBasis = value);
        if (mounted) provider.loadBooks();
      case 'game':
        await _userPrefs.setGameYearGridBasis(value);
        setState(() => _gameYearGridBasis = value);
        if (mounted) provider.loadGames();
    }
  }
}
