import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../l10n/app_strings.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../widgets/work_people_section.dart';
import '../../widgets/character_preview_section.dart';
import '../../widgets/character_info_sheet.dart';
import '../../widgets/review_preview_section.dart';
import 'game_reviews_page.dart';
import 'game_screenshots_page.dart';
import 'game_share_page.dart';
import '../character/character_list_page.dart';
import '../progress/progress_pages.dart';
import '../../widgets/app_overlay.dart';

/// 游戏详情页 - 极简主义设计
class GameDetailPage extends StatefulWidget {
  final Game game;
  final bool embedded;

  const GameDetailPage({super.key, required this.game, this.embedded = false});

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final ValueNotifier<double> _coverOffset = ValueNotifier(0.0);
  double _coverDragStartOffset = 0.0;
  final ValueNotifier<bool> _draggingCover = ValueNotifier(false);
  final GlobalKey _coverImageKey = GlobalKey();
  double _coverImageHeight = 0.0;
  bool _isLandscapeCover = false;
  late int _detailStyle;
  final ValueNotifier<bool> _showTitle = ValueNotifier(false);
  ScrollController? _overlayScrollController;

  // ─── 角色预览 ───
  List<dynamic> _characters = [];

  // ─── 通关记录 ───
  List<GameCompletion> _completions = [];

  // ─── 编辑模式 ───
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _ratingCtrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _playTimeHoursCtrl;
  late TextEditingController _playTimeMinutesCtrl;

  @override
  void initState() {
    super.initState();
    _detailStyle = UserPrefs().detailPageStyle;
    _coverOffset.value = UserPrefs().getCoverOffset(widget.game.id);
    _initEditControllers();
    _detectCoverAspect();
    _loadCharacters();
    _loadCompletions();
  }

  Future<void> _loadCharacters() async {
    final list = await context.read<AppProvider>().getGameCharacters(widget.game.id);
    if (!mounted) return;
    setState(() => _characters = list);
  }

  Future<void> _loadCompletions() async {
    final list = await context.read<AppProvider>().getGameCompletions(widget.game.id);
    if (!mounted) return;
    setState(() => _completions = list);
  }

  void _initEditControllers() {
    final g = widget.game;
    _titleCtrl = TextEditingController(text: g.title);
    _summaryCtrl = TextEditingController(text: g.summary ?? '');
    _ratingCtrl = TextEditingController(text: g.rating?.toString() ?? '');
    _purchasePriceCtrl = TextEditingController(text: g.purchasePrice ?? '');
    _playTimeHoursCtrl = TextEditingController(text: g.playTimeHours > 0 ? g.playTimeHours.toString() : '');
    _playTimeMinutesCtrl = TextEditingController(text: g.playTimeMinutes > 0 ? g.playTimeMinutes.toString() : '');
  }

  Future<void> _detectCoverAspect() async {
    final path = widget.game.coverPath;
    if (path == null || path.isEmpty || path.startsWith('http')) return;
    final file = File(path);
    if (!file.existsSync()) return;
    final bytes = await file.readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width;
    final h = frame.image.height;
    frame.image.dispose();
    codec.dispose();
    if (w > h && mounted) {
      setState(() => _isLandscapeCover = true);
    }
  }

  @override
  void dispose() {
    _coverOffset.dispose();
    _draggingCover.dispose();
    _showTitle.dispose();
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _ratingCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _playTimeHoursCtrl.dispose();
    _playTimeMinutesCtrl.dispose();
    _overlayScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 只订阅当前这一条：无关的 provider 变更不再重建整个详情页
    final game = context.select<AppProvider, Game?>(
      (p) => p.games.where((g) => g.id == widget.game.id).firstOrNull,
    ) ?? widget.game;

    return switch (_detailStyle) {
      1 => _buildOverlayStyle(game, colors),
      2 => _buildMinimalLayeredStyle(game, colors),
      3 => _buildDoubanStyle(game, colors),
      _ => _buildStandardStyle(game, colors),
    };
  }

  /// 按用户配置（设置-详情页模块）生成内容模块列表。
  /// layout: 0=标准, 1=叠层毛玻璃, 2=浅色极简
  List<Widget> _orderedModules(Game game, ColorScheme colors, int layout) {
    final result = <Widget>[];
    for (final m in UserPrefs().getDetailModules('game')) {
      if (!m.visible) continue;
      final isFirst = result.isEmpty;
      switch (m.id) {
        case 'credits':
          result.addAll(_creditsRows(game, colors, layout));
        case 'genres':
          if (game.genres.isNotEmpty) {
            if (layout == 1 && !isFirst) result.add(const SizedBox(height: 12));
            result.add(switch (layout) {
              1 => _buildOverlayGenres(game),
              2 => _buildLayeredGenres(game),
              _ => _buildGenresSection(game),
            });
          }
        case 'characters':
          result.add(CharacterPreviewSection(
            characters: _characters,
            onTap: _openCharacterSheet,
            isOverlay: layout == 1,
          ));
        case 'people':
          result.add(WorkPeopleSection(workId: game.id, workType: 'game', isOverlay: layout == 1));
        case 'summary':
          if (game.summary != null && game.summary!.isNotEmpty) {
            if (layout == 1 && !isFirst) result.add(const SizedBox(height: 12));
            result.add(switch (layout) {
              1 => _buildOverlaySummary(game),
              2 => _buildLayeredSummary(game),
              _ => _buildInfoSection('游戏简介', game.summary!),
            });
          }
        case 'reviews':
          if (layout == 1 && !isFirst) result.add(const SizedBox(height: 12));
          result.add(ReviewPreviewSection(
            workId: game.id,
            workType: 'game',
            isOverlay: layout == 1,
            padding: switch (layout) {
              0 => const EdgeInsets.fromLTRB(24, 0, 24, 8),
              1 => const EdgeInsets.symmetric(horizontal: 24),
              _ => EdgeInsets.zero,
            },
          ));
        case 'extra':
          if (!isFirst) {
            if (layout == 1) result.add(const SizedBox(height: 12));
            if (layout == 2) result.add(const SizedBox(height: 20));
            if (layout == 0) result.add(Divider(height: 0.5, thickness: 0.5, color: colors.outline));
          }
          result.add(switch (layout) {
            1 => _buildExtraSectionsOverlay(game),
            2 => _buildLayeredExtraSections(game),
            _ => _buildExtraSections(game),
          });
      }
    }
    return result;
  }

  /// 游戏信息行（平台/版本/开发者/发售/时长/购买信息），按布局选用不同构造器
  List<Widget> _creditsRows(Game game, ColorScheme colors, int layout) {
    Widget row(String label, String value) => switch (layout) {
          1 => _buildOverlayInfoRow(label, value),
          2 => _buildLayeredInfoRow(label, value, colors),
          _ => _buildInfoSection(label, value),
        };
    return [
      if (game.platforms.isNotEmpty) row('平台', game.platforms.join('、')),
      if (game.versions.isNotEmpty) row('版本', game.versions.join('、')),
      if (game.developer.isNotEmpty) row('开发者', game.developer.join('、')),
      if (game.releaseDate != null) row('发售时间', _formatDate(game.releaseDate!)),
      if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
        row('游玩时长', '{h}小时{m}分钟'.trf({'h': game.playTimeHours, 'm': game.playTimeMinutes})),
      if (game.playCount > 0) row('游玩次数', '{n} 次'.trf({'n': game.playCount})),
      if (game.purchasePlatforms.isNotEmpty) row('购买平台', game.purchasePlatforms.join('、')),
      if (game.purchaseDate != null) row('购买时间', _formatDate(game.purchaseDate!)),
      if (game.purchasePrice != null && game.purchasePrice!.isNotEmpty) row('购买价格', game.purchasePrice!),
      if (_completions.isNotEmpty) _buildCompletionRow(colors, layout),
    ];
  }

  /// 通关时间：多条横向排列、左右滑动
  Widget _buildCompletionRow(ColorScheme colors, int layout) {
    final cards = _completions.map((c) {
      return switch (layout) {
        1 => _overlayCompletionChip(c),
        2 => _layeredCompletionChip(c, colors),
        _ => _standardCompletionChip(c, colors),
      };
    }).toList();

    final list = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          cards[i],
        ],
      ]),
    );

    final labelColor = layout == 1
        ? Colors.white.withValues(alpha: 0.5)
        : colors.onSurface.withValues(alpha: 0.4);
    final pad = layout == 1
        ? const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    return Padding(
      padding: pad,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text('通关时间'.tr, style: TextStyle(fontSize: 13, color: labelColor))),
        Expanded(child: list),
      ]),
    );
  }

  Widget _completionCardContent(GameCompletion c, Color dateColor, Color noteColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_formatDate(c.completionDate),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dateColor, height: 1.3)),
        if (c.note.isNotEmpty) ...[
          const SizedBox(height: 2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(c.note,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: noteColor, height: 1.3)),
          ),
        ],
      ],
    );
  }

  Widget _standardCompletionChip(GameCompletion c, ColorScheme colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: _completionCardContent(
          c, colors.onSurface, colors.onSurface.withValues(alpha: 0.55)),
      );

  Widget _overlayCompletionChip(GameCompletion c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _completionCardContent(
          c, Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.6)),
      );

  Widget _layeredCompletionChip(GameCompletion c, ColorScheme colors) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: _completionCardContent(
          c, colors.onSurface, colors.onSurface.withValues(alpha: 0.55)),
      );

  Widget _buildStandardStyle(Game game, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        // expand：内容少时 Stack 也撑满屏幕，右下角浮动按钮位置固定
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(top: topSafe + 48),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: _buildCoverSection(game),
                  ),
                  _buildBasicInfo(game),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  // 内容模块（顺序/显隐可在设置中调整）
                  ..._orderedModules(game, colors, 0),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(top: topSafe),
              color: colors.surface,
              child: SizedBox(
                height: 48,
                child: Row(children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: widget.embedded
                        ? Icon(Icons.arrow_back, color: colors.onSurface, size: 18)
                        : Icon(Icons.arrow_back_ios_new, color: colors.onSurface, size: 18),
                    onPressed: widget.embedded
                        ? () => Navigator.pop(context)
                        : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(game.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune, color: colors.onSurface, size: 20),
                    tooltip: '切换样式'.tr,
                    onPressed: _showStylePicker,
                  ),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(game),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayStyle(Game game, ColorScheme colors) {
    final screenH = MediaQuery.of(context).size.height;
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;

    _overlayScrollController ??= ScrollController()..addListener(() {
      final show = (_overlayScrollController?.offset ?? 0) > 10;
      if (_showTitle.value != show) _showTitle.value = show;
    });

    return Scaffold(
      body: Stack(
        // expand：内容少时 Stack 也撑满屏幕，右下角浮动按钮位置固定
        fit: StackFit.expand,
        children: [
          // 兜底色：封面解码完成前也保持深色，不透明（避免转场中"先透明后磨砂"）
          const Positioned.fill(child: ColoredBox(color: Color(0xFF121418))),
          // 封面背景（静态模糊，转场动画期间即生效，不依赖 BackdropFilter）
          if (hasCover)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Image(
                  image: ResizeImage(FileImage(File(game.coverPath!)), width: 1080),
                  fit: BoxFit.cover, width: double.infinity, height: screenH,
                  repeat: ImageRepeat.repeatY,
                ),
              ),
            ),

          // 深色遮罩
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
          ),

          // 内容
          SafeArea(
            child: Column(children: [
              // 顶部栏
              SizedBox(
                height: 48,
                child: Row(children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: widget.embedded
                        ? const Icon(Icons.arrow_back, color: Colors.white, size: 18)
                        : const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: widget.embedded
                        ? () => Navigator.pop(context)
                        : () => Navigator.pop(context),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: _showTitle,
                    builder: (_, show, __) => AnimatedOpacity(
                      opacity: show ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                        child: Text(game.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.tune, color: Colors.white, size: 20),
                    tooltip: '切换样式'.tr,
                    onPressed: _showStylePicker,
                  ),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _overlayScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildOverlayHeader(game),
                    const SizedBox(height: 20),
                    // 内容模块（顺序/显隐可在设置中调整）
                    ..._orderedModules(game, colors, 1),
                  ]),
                ),
              ),
            ]),
          ),

          Positioned(right: 16, bottom: 24, child: _buildFloatingActionButtons(game)),
        ],
      ),
    );
  }

  /// 浅色极简层叠样式：封面卡片 + 浅色信息卡片层叠（无毛玻璃）
  Widget _buildMinimalLayeredStyle(Game game, ColorScheme colors) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        // expand：内容少时 Stack 也撑满屏幕，右下角浮动按钮位置固定
        fit: StackFit.expand,
        children: [
          // 整体可滚动（封面卡片 + 内容一起滑动）
          Padding(
            padding: EdgeInsets.only(top: safeTop + 48),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildLayeredCover(game)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: _buildLayeredHeader(game)),
                  const SizedBox(height: 20),
                  // 内容模块（顺序/显隐可在设置中调整）
                  ..._orderedModules(game, colors, 2),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(top: safeTop),
              color: colors.surface,
              child: SizedBox(
                height: 48,
                child: Row(children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: widget.embedded
                        ? Icon(Icons.arrow_back, color: colors.onSurface, size: 18)
                        : Icon(Icons.arrow_back_ios_new, color: colors.onSurface, size: 18),
                    onPressed: widget.embedded
                        ? () => Navigator.pop(context)
                        : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(game.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: Icon(Icons.tune, color: colors.onSurface, size: 20),
                    tooltip: '切换样式'.tr,
                    onPressed: _showStylePicker,
                  ),
                ]),
              ),
            ),
          ),
          Positioned(right: 16, bottom: 24, child: _buildFloatingActionButtons(game)),
        ],
      ),
    );
  }

  /// 豆瓣样式：模糊封面背景头 + 封面左/信息右 + 圆角内容区
  Widget _buildDoubanStyle(Game game, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;

    // 复用毛玻璃样式的滚动控制器（同一时刻只会有一个样式生效）
    _overlayScrollController ??= ScrollController()..addListener(() {
      final show = (_overlayScrollController?.offset ?? 0) > 10;
      if (_showTitle.value != show) _showTitle.value = show;
    });

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            controller: _overlayScrollController,
            child: Column(children: [
              // 头部：模糊封面背景 + 信息头
              Stack(children: [
                Positioned.fill(
                  child: hasCover
                      ? Image(
                          image: ResizeImage(FileImage(File(game.coverPath!)), width: 1080),
                          fit: BoxFit.cover)
                      : Container(color: colors.surfaceContainerHighest),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                          color: Colors.black.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, topSafe + 56, 20, 40),
                  child: _buildDoubanHeader(game),
                ),
              ]),
              // 圆角内容区（上叠 16px 盖住背景边缘）
              Transform.translate(
                offset: const Offset(0, -16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      ..._orderedModules(game, colors, 0),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          // 顶部导航栏：滚动后变为 surface 底并显示标题
          Positioned(
            top: 0, left: 0, right: 0,
            child: ValueListenableBuilder<bool>(
              valueListenable: _showTitle,
              builder: (_, show, __) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(top: topSafe),
                color: show ? colors.surface : Colors.transparent,
                child: SizedBox(
                  height: 48,
                  child: Row(children: [
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        widget.embedded
                            ? Icons.arrow_back
                            : Icons.arrow_back_ios_new,
                        color: show ? colors.onSurface : Colors.white,
                        size: 18),
                      onPressed: widget.embedded
                          ? () => Navigator.pop(context)
                          : () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: show ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(game.title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.tune,
                          color: show ? colors.onSurface : Colors.white,
                          size: 20),
                      tooltip: '切换样式'.tr,
                      onPressed: _showStylePicker,
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(game),
          ),
        ],
      ),
    );
  }

  /// 豆瓣信息头：封面在左，标题/开发者/平台类型/评分在右
  Widget _buildDoubanHeader(Game game) {
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;
    final meta = <String>[
      if (game.releaseDate != null) '${game.releaseDate!.year}',
      ...game.platforms,
      ...game.genres,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 104, height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: hasCover
              ? FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover)
              : Container(color: Colors.white24, child: const Icon(Icons.sports_esports_outlined, color: Colors.white38, size: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text(game.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
            if (game.developer.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(game.developer.join(' / '),
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(meta,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(children: [
              if (game.rating != null && game.rating! > 0) ...[
                const Icon(Icons.star, size: 18, color: Color(0xFFFFB800)),
                const SizedBox(width: 4),
                Text(game.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFFFB800))),
                const SizedBox(width: 12),
              ],
              _buildOverlayStatusChip(game.status),
            ]),
            if (game.playTimeHours > 0 || game.playTimeMinutes > 0 || game.playCount > 0) ...[
              const SizedBox(height: 8),
              Text([
                if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
                  '{h}小时{m}分钟'.trf({'h': game.playTimeHours, 'm': game.playTimeMinutes}),
                if (game.playCount > 0)
                  '{n} 次'.trf({'n': game.playCount}),
              ].join(' · '),
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
            ],
          ]),
        ),
      ],
    );
  }

  /// 浅色极简：居中封面卡片
  Widget _buildLayeredCover(Game game) {
    final colors = Theme.of(context).colorScheme;
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;
    return Container(
      width: 160, height: 230,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasCover
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasCover
          ? FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover)
          : Center(child: Icon(Icons.sports_esports_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.25))),
    );
  }

  /// 浅色极简：居中标题 + 评分/状态/分类
  Widget _buildLayeredHeader(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(game.title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface, height: 1.3)),
        if (game.genres.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(game.genres.join(' / '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4), height: 1.4)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (game.rating != null) ...[
            const Icon(Icons.star, size: 20, color: Colors.amber),
            const SizedBox(width: 4),
            Text(game.rating!.toStringAsFixed(1),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ],
          _buildStatusTag(game),
          _buildCategoryTag(game),
        ]),
      ],
    );
  }

  /// 浅色极简：信息卡片（平台/版本/开发者/发售时间等）
  Widget _buildLayeredInfoRow(String label, String value, ColorScheme colors) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.5))),
        ],
      ),
    );
  }

  /// 浅色极简：类型卡片
  Widget _buildLayeredGenres(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text('类型'.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8,
            children: game.genres.map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16)),
              child: Text(g, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
            )).toList(),
          )),
        ],
      ),
    );
  }

  /// 浅色极简：简介卡片
  Widget _buildLayeredSummary(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 4, height: 14, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text('游戏简介'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]),
        const SizedBox(height: 12),
        Text(game.summary!, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.8)),
      ]),
    );
  }

  /// 浅色极简：更多（评价/截图/角色）
  Widget _buildLayeredExtraSections(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('更多'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ]),
      const SizedBox(height: 12),
      ProgressEntryCard(
        parentId: game.id,
        parentTitle: game.title,
        config: ProgressConfig.game,
        icon: Icons.flag_outlined,
      ),
      const SizedBox(height: 10),
      _buildExtraSectionItem(
        icon: Icons.rate_review_outlined,
        title: '游戏评价',
        subtitleFuture: context.read<AppProvider>().getGameReviewCount(game.id),
        emptyText: '暂无评价',
        unit: '条评价',
        onTap: () => _navigateToReviews(game),
      ),
      const SizedBox(height: 10),
      _buildExtraSectionItem(
        icon: Icons.photo_library_outlined,
        title: '游戏截图',
        subtitleFuture: context.read<AppProvider>().getGameScreenshotCount(game.id),
        emptyText: '暂无截图',
        unit: '张截图',
        onTap: () => _navigateToScreenshots(game),
      ),
      const SizedBox(height: 10),
      _buildExtraSectionItem(
        icon: Icons.people_outline,
        title: '角色',
        subtitleFuture: context.read<AppProvider>().getGameCharacterCount(game.id),
        emptyText: '暂无角色',
        unit: '个角色',
        onTap: () => _navigateToCharacters(game),
      ),
    ]);
  }

  Widget _buildOverlayHeader(Game game) {
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 100, height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: hasCover
              ? FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover)
              : Container(color: Colors.white24, child: const Icon(Icons.sports_esports_outlined, color: Colors.white38, size: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(game.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            if (game.genres.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(game.genres.join(' / '), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              if (game.rating != null && game.rating! > 0) ...[
                const Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                const SizedBox(width: 4),
                Text(game.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
                const SizedBox(width: 16),
              ],
              _buildOverlayStatusChip(game.status),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _buildOverlayStatusChip(String status) {
    final label = switch (status) {
      'completed' => '已通关',
      'playing' => '在玩',
      'want_to_play' => '想玩',
      'abandoned' => '弃游',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    final c = AppTheme.statusOverlayColors(Theme.of(context).colorScheme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.fg)),
    );
  }

  Widget _buildOverlayInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text(label.tr, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9), height: 1.5))),
      ]),
    );
  }

  Widget _buildOverlayGenres(Game game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text('类型'.tr, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)))),
        Expanded(
          child: Wrap(
            spacing: 8, runSpacing: 8,
            children: game.genres.map((g) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
              child: Text(g, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildOverlaySummary(Game game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('游戏简介'.tr, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        Text(game.summary!, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9), height: 1.6)),
      ]),
    );
  }

  Widget _buildExtraSectionsOverlay(Game game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ProgressEntryCard(
            parentId: game.id,
            parentTitle: game.title,
            config: ProgressConfig.game,
            icon: Icons.flag_outlined,
            frosted: true,
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.rate_review_outlined,
            title: '游戏评价',
            subtitleFuture: context.read<AppProvider>().getGameReviewCount(game.id),
            emptyText: '暂无评价',
            unit: '条评价',
            onTap: () => _navigateToReviews(game),
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.photo_library_outlined,
            title: '游戏截图',
            subtitleFuture: context.read<AppProvider>().getGameScreenshotCount(game.id),
            emptyText: '暂无截图',
            unit: '张截图',
            onTap: () => _navigateToScreenshots(game),
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.people_outline,
            title: '角色',
            subtitleFuture: context.read<AppProvider>().getGameCharacterCount(game.id),
            emptyText: '暂无角色',
            unit: '个角色',
            onTap: () => _navigateToCharacters(game),
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedExtraItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.7)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      FutureBuilder<int>(
                        future: subtitleFuture,
                        builder: (ctx, snap) {
                          final count = snap.data ?? 0;
                          return Text(count > 0 ? '$count $unit' : emptyText,
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)));
                        },
                      ),
                    ]),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: Colors.white.withValues(alpha: 0.3)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.people_outline,
          onPressed: () => _navigateToCharacters(game),
          tooltip: '角色',
          backgroundColor: colors.secondaryContainer,
          foregroundColor: colors.onSecondaryContainer,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.share_outlined,
          onPressed: () => _showSharePoster(game),
          tooltip: '分享海报',
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Tooltip(
      message: tooltip.tr,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: foregroundColor),
        ),
      ),
    );
  }

  Widget _buildCoverSection(Game game) {
    final colors = Theme.of(context).colorScheme;
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;

    // 横图：直接居中裁剪填满，无需拖拽偏移
    if (_isLandscapeCover && hasCover) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.surface.withValues(alpha: 0), colors.surface],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 竖图：原有逻辑，支持上下拖拽调整偏移
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerH = constraints.maxHeight;
        return GestureDetector(
          onLongPressStart: hasCover ? (_) {
            HapticFeedback.mediumImpact();
            final ctx = _coverImageKey.currentContext;
            if (ctx != null) {
              final box = ctx.findRenderObject() as RenderBox?;
              if (box != null) _coverImageHeight = box.size.height;
            }
            _draggingCover.value = true;
            _coverDragStartOffset = _coverOffset.value;
          } : null,
          onLongPressMoveUpdate: hasCover ? (d) {
            final raw = _coverDragStartOffset + d.offsetFromOrigin.dy;
            final imgH = _coverImageHeight > 0 ? _coverImageHeight : containerH;
            final minOffset = -(imgH - containerH).clamp(0, double.infinity);
            _coverOffset.value = raw.clamp(minOffset, 0.0) as double;
          } : null,
          onLongPressEnd: hasCover ? (_) {
            _draggingCover.value = false;
            final offset = _coverOffset.value;
            UserPrefs().setCoverOffset(widget.game.id, offset);
            context.read<AppProvider>().updateGameCoverOffset(widget.game.id, offset);
          } : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _coverOffset,
            builder: (context, offset, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (hasCover)
                    ClipRect(
                      child: Stack(
                        children: [
                          Positioned(
                            top: offset,
                            left: 0, right: 0,
                            child: FadeInLocalImage(
                              key: _coverImageKey,
                              path: game.coverPath,
                              fit: BoxFit.fitWidth,
                              width: constraints.maxWidth,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildCoverPlaceholder(),
                  ValueListenableBuilder<bool>(
                    valueListenable: _draggingCover,
                    builder: (context, dragging, _) {
                      return Stack(
                        children: [
                          if (!dragging)
                            Positioned(
                              left: 0, right: 0, bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        colors.surface.withValues(alpha: 0),
                                        colors.surface,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (dragging) ...[
                            Positioned.fill(
                              child: Container(color: Colors.black.withValues(alpha: 0.3)),
                            ),
                            Positioned(
                              left: 0, right: 0, bottom: 20,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('上下滑动调整图片位置'.tr,
                                      style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCoverPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_esports_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text('暂无封面'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            game.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (game.rating != null) ...[
                const Icon(Icons.star, size: 20, color: Colors.amber),
                const SizedBox(width: 4),
                Text(game.rating!.toStringAsFixed(1),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(game),
              const SizedBox(width: 6),
              _buildCategoryTag(game),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(Game game) {
    final colors = Theme.of(context).colorScheme;
    String label;
    Color bgColor;
    Color textColor;
    switch (game.status) {
      case 'completed':
        label = '已通关';
        bgColor = colors.primary;
        textColor = colors.onPrimary;
      case 'playing':
        label = '在玩';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.6);
      case 'want_to_play':
        label = '想玩';
        bgColor = colors.surfaceContainerHighest;
        textColor = colors.onSurface.withValues(alpha: 0.4);
      case 'abandoned':
        label = '弃游';
        bgColor = colors.errorContainer;
        textColor = colors.onError;
      default:
        label = '未知';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.25);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label.tr, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildCategoryTag(Game game) {
    final colors = Theme.of(context).colorScheme;
    const labels = {'digital': '数字版', 'cartridge': '卡带', 'disc': '光盘'};
    final label = labels[game.category];
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
      child: Text(label.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresSection(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('类型'.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: game.genres.map((g) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                child: Text(g, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildExtraSections(Game game) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text('更多'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
          ProgressEntryCard(
            parentId: game.id,
            parentTitle: game.title,
            config: ProgressConfig.game,
            icon: Icons.flag_outlined,
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.rate_review_outlined,
            title: '游戏评价',
            subtitleFuture: context.read<AppProvider>().getGameReviewCount(game.id),
            emptyText: '暂无评价',
            unit: '条评价',
            onTap: () => _navigateToReviews(game),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.photo_library_outlined,
            title: '游戏截图',
            subtitleFuture: context.read<AppProvider>().getGameScreenshotCount(game.id),
            emptyText: '暂无截图',
            unit: '张截图',
            onTap: () => _navigateToScreenshots(game),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.people_outline,
            title: '角色',
            subtitleFuture: context.read<AppProvider>().getGameCharacterCount(game.id),
            emptyText: '暂无角色',
            unit: '个角色',
            onTap: () => _navigateToCharacters(game),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSectionItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              child: Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '{n} {unit}'.trf({'n': count, 'unit': unit.tr}) : emptyText.tr,
                        style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }

  void _navigateToReviews(Game game) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameReviewsPage(game: game)));
  }

  void _navigateToScreenshots(Game game) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreenshotsPage(game: game)));
  }

  void _navigateToCharacters(Game game) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameCharactersPage(game: game)))
        .then((_) => _loadCharacters());
  }

  Future<void> _openCharacterSheet(dynamic character) async {
    final needRefresh = await CharacterInfoSheet.show(
      context,
      entityType: 'game',
      entityId: widget.game.id,
      character: character,
    );
    if (needRefresh == true) _loadCharacters();
  }

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    final currentStyle = UserPrefs().detailPageStyle;
    const names = ['默认样式', '毛玻璃层叠', '浅色极简', '豆瓣风格'];
    const icons = [Icons.article_outlined, Icons.blur_on_outlined, Icons.layers_outlined, Icons.art_track_outlined];
    const subtitles = ['标准封面顶部布局', '封面背景 + 毛玻璃卡片', '封面卡片 + 浅色信息卡片层叠', '封面左置 + 模糊背景信息头'];
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Text('详情页样式'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          const SizedBox(height: 12),
          for (int i = 0; i < names.length; i++) ...[
            if (i > 0) Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icons[i], size: 20, color: currentStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(names[i].tr, style: TextStyle(fontSize: 13, fontWeight: currentStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i].tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: currentStyle == i
                  ? Icon(Icons.check_circle, size: 20, color: colors.primary)
                  : Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () { setState(() => _detailStyle = i); UserPrefs().setDetailPageStyle(i); Navigator.pop(ctx); },
            ),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _showSharePoster(Game game) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GameSharePage(game: game)));
  }

  void _navigateToEdit(BuildContext context) {
    final provider = context.read<AppProvider>();
    Navigator.pushNamed(context, '/game-form', arguments: widget.game).then((_) {
      provider.setEditRefresh(widget.game.id);
      provider.loadGames();
      _loadCompletions();
    });
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除"{title}"吗？删除后可在回收站恢复。'.trf({'title': widget.game.title}),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<AppProvider>();
              await provider.removeGame(widget.game.id);
              if (!mounted || !context.mounted) return;
              if (widget.embedded) {
                Navigator.of(context).pop();
                provider.selectGame(null);
              } else {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pop();
              }
              if (mounted && context.mounted) {
                ToastUtil.show(context, '已删除'.tr);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: Text('删除'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
