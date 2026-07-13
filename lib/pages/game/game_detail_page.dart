import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../widgets/fade_in_local_image.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/responsive.dart';
import '../../widgets/genre_selector_page.dart';
import 'game_reviews_page.dart';
import 'game_screenshots_page.dart';
import 'game_share_page.dart';

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

  // ─── 编辑模式 ───
  bool _isEditing = false;
  final _editFormKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _ratingCtrl;
  late TextEditingController _purchasePriceCtrl;
  late TextEditingController _playTimeHoursCtrl;
  late TextEditingController _playTimeMinutesCtrl;
  List<String> _editPlatforms = [];
  List<String> _editVersions = [];
  List<String> _editGenres = [];
  List<String> _editPurchasePlatforms = [];
  String? _editCoverPath;
  String _editStatus = 'want_to_play';
  String _editCategory = 'digital';
  DateTime? _editPurchaseDate;
  bool _editIsDownloading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _detailStyle = UserPrefs().detailPageStyle;
    _coverOffset.value = UserPrefs().getCoverOffset(widget.game.id);
    _initEditControllers();
    _detectCoverAspect();
  }

  void _initEditControllers() {
    final g = widget.game;
    _titleCtrl = TextEditingController(text: g.title);
    _summaryCtrl = TextEditingController(text: g.summary ?? '');
    _ratingCtrl = TextEditingController(text: g.rating?.toString() ?? '');
    _purchasePriceCtrl = TextEditingController(text: g.purchasePrice ?? '');
    _playTimeHoursCtrl = TextEditingController(text: g.playTimeHours > 0 ? g.playTimeHours.toString() : '');
    _playTimeMinutesCtrl = TextEditingController(text: g.playTimeMinutes > 0 ? g.playTimeMinutes.toString() : '');
    _editPlatforms = List.from(g.platforms);
    _editVersions = List.from(g.versions);
    _editGenres = List.from(g.genres);
    _editPurchasePlatforms = List.from(g.purchasePlatforms);
    _editCoverPath = g.coverPath;
    _editStatus = g.status;
    _editCategory = g.category;
    _editPurchaseDate = g.purchaseDate;
  }

  void _enterEditMode() {
    // 从 provider 获取最新数据
    final latest = context.read<AppProvider>().games
        .where((g) => g.id == widget.game.id).firstOrNull ?? widget.game;
    _titleCtrl.text = latest.title;
    _summaryCtrl.text = latest.summary ?? '';
    _ratingCtrl.text = latest.rating?.toString() ?? '';
    _purchasePriceCtrl.text = latest.purchasePrice ?? '';
    _playTimeHoursCtrl.text = latest.playTimeHours > 0 ? latest.playTimeHours.toString() : '';
    _playTimeMinutesCtrl.text = latest.playTimeMinutes > 0 ? latest.playTimeMinutes.toString() : '';
    _editPlatforms = List.from(latest.platforms);
    _editVersions = List.from(latest.versions);
    _editGenres = List.from(latest.genres);
    _editPurchasePlatforms = List.from(latest.purchasePlatforms);
    _editCoverPath = latest.coverPath;
    _editStatus = latest.status;
    _editCategory = latest.category;
    _editPurchaseDate = latest.purchaseDate;
    setState(() => _isEditing = true);
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
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _ratingCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _playTimeHoursCtrl.dispose();
    _playTimeMinutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final game = context.watch<AppProvider>().games
        .where((g) => g.id == widget.game.id)
        .firstOrNull ?? widget.game;

    if (Breakpoint.isDesktop(context)) {
      return _buildDesktopStyle(game, colors);
    }
    return _detailStyle == 1
        ? _buildOverlayStyle(game, colors)
        : _buildStandardStyle(game, colors);
  }

  /// 桌面端左右分栏布局
  Widget _buildDesktopStyle(Game game, ColorScheme colors) {
    if (_isEditing) return _buildDesktopEditStyle(game, colors);
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          // 顶栏
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
            ),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: colors.onSurface, size: 18),
                onPressed: widget.embedded
                    ? () => context.read<AppProvider>().selectGame(null)
                    : () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(game.title,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
            ]),
          ),
          // 主体：左封面 + 右信息
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧封面
                Container(
                  width: 240,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 280,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: hasCover
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasCover
                            ? FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover)
                            : Center(child: Icon(Icons.sports_esports_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.25))),
                      ),
                    ],
                  ),
                ),
                // 右侧信息（可滚动）
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 20, 24, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.title,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3)),
                        const SizedBox(height: 16),
                        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          if (game.rating != null) ...[
                            Icon(Icons.star, size: 20, color: colors.onSurface),
                            const SizedBox(width: 4),
                            Text(game.rating!.toStringAsFixed(1),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                          ],
                          _buildStatusTag(game),
                          _buildCategoryTag(game),
                        ]),
                        Divider(height: 32, thickness: 0.5, color: colors.outline),
                        // 详细信息
                        if (game.platforms.isNotEmpty)
                          _buildDesktopInfoRow('平台', game.platforms.join('、'), colors),
                        if (game.versions.isNotEmpty)
                          _buildDesktopInfoRow('版本', game.versions.join('、'), colors),
                        if (game.genres.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 56, child: Text('类型', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
                            Expanded(child: Wrap(spacing: 8, runSpacing: 8,
                              children: game.genres.map((g) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                                child: Text(g, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                              )).toList(),
                            )),
                          ]),
                        ],
                        if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
                          _buildDesktopInfoRow('游玩时长', '${game.playTimeHours}小时${game.playTimeMinutes}分钟', colors),
                        if (game.purchasePlatforms.isNotEmpty)
                          _buildDesktopInfoRow('购买平台', game.purchasePlatforms.join('、'), colors),
                        if (game.purchaseDate != null)
                          _buildDesktopInfoRow('购买时间', _formatDate(game.purchaseDate!), colors),
                        if (game.purchasePrice != null && game.purchasePrice!.isNotEmpty)
                          _buildDesktopInfoRow('购买价格', game.purchasePrice!, colors),
                        if (game.summary != null && game.summary!.isNotEmpty) ...[
                          Divider(height: 32, thickness: 0.5, color: colors.outline),
                          Row(children: [
                            Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text('游戏简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                          ]),
                          const SizedBox(height: 12),
                          Text(game.summary!, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.8)),
                        ],
                        Divider(height: 32, thickness: 0.5, color: colors.outline),
                        Row(children: [
                          Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('更多', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        ]),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 底部操作栏
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDeleteDialog(context),
                  icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
                  label: Text('删除', style: TextStyle(color: colors.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _enterEditMode,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 桌面端编辑模式 ──────────────────────────────────────────

  static const _gameStatuses = [
    ('通关', 'completed'), ('在玩', 'playing'), ('想玩', 'want_to_play'), ('弃游', 'abandoned'),
  ];

  static const _gameCategories = [
    ('数字版', 'digital'), ('卡带版', 'cartridge'), ('光盘版', 'disc'),
  ];

  Widget _buildDesktopEditStyle(Game game, ColorScheme colors) {
    final hasCover = _editCoverPath != null && _editCoverPath!.isNotEmpty;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Form(
        key: _editFormKey,
        child: Column(
          children: [
            // 顶栏
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
              ),
              child: Row(children: [
                IconButton(
                  icon: Icon(Icons.close, color: colors.onSurface, size: 18),
                  onPressed: () => setState(() => _isEditing = false),
                ),
                Expanded(
                  child: Text('编辑游戏',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                ),
                FilledButton.icon(
                  onPressed: _saveEdit,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('保存'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
              ]),
            ),
            // 主体：左封面+右表单
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧：封面 + 状态/评分/分类
                  Container(
                    width: 240,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // 封面
                        GestureDetector(
                          onTap: _showEditCoverOptions,
                          child: Container(
                            width: 200, height: 280,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(alignment: Alignment.center, children: [
                              hasCover
                                  ? FadeInLocalImage(path: _editCoverPath, fit: BoxFit.cover)
                                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.image_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
                                      const SizedBox(height: 8),
                                      Text('点击添加封面', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                                    ]),
                              if (_editIsDownloading)
                                Container(color: Colors.black.withValues(alpha: 0.4),
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            ]),
                          ),
                        ),
                        if (hasCover)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _editCoverPath = null),
                              child: Text('移除封面', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)))),
                          ),
                        const SizedBox(height: 20),
                        // 状态
                        _buildEditSectionLabel('状态', colors),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                          child: Wrap(
                            spacing: 0, runSpacing: 4,
                            children: _gameStatuses.map((s) => _buildEditStatusChip(s.$1, s.$2, colors)).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 评分
                        _buildEditSectionLabel('评分', colors),
                        const SizedBox(height: 6),
                        Row(children: [
                          ...List.generate(5, (i) {
                            final starVal = i + 1;
                            final currentRating = double.tryParse(_ratingCtrl.text) ?? 0;
                            final starRating = currentRating / 2;
                            final isFilled = starVal <= starRating;
                            final isHalf = starVal == starRating.ceil() && starRating % 1 != 0;
                            return GestureDetector(
                              onTap: () => setState(() => _ratingCtrl.text = (starVal * 2).toString()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: Icon(
                                  isHalf ? Icons.star_half : (isFilled ? Icons.star : Icons.star_border),
                                  size: 20, color: (isFilled || isHalf) ? const Color(0xFFFFB800) : colors.outline,
                                ),
                              ),
                            );
                          }),
                          const SizedBox(width: 8),
                          Container(
                            width: 48, height: 28,
                            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                            child: TextFormField(
                              controller: _ratingCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              inputFormatters: [_RatingInputFormatter()],
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                              decoration: InputDecoration(
                                hintText: '0-10', hintStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25)),
                                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 6), isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_ratingCtrl.text.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => setState(() => _ratingCtrl.clear()),
                              child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 16),
                        // 分类
                        _buildEditSectionLabel('分类', colors),
                        const SizedBox(height: 6),
                        Wrap(spacing: 4, runSpacing: 4, children: _gameCategories.map((c) {
                          final selected = _editCategory == c.$2;
                          return GestureDetector(
                            onTap: () => setState(() => _editCategory = c.$2),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: selected ? colors.primary : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(c.$1, style: TextStyle(
                                fontSize: 11, fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                                color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                              )),
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                  // 右侧：可滚动表单
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 20, 24, 80),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 名称
                          _buildEditField('名称', _titleCtrl, hint: '游戏名称', required: true),
                          const SizedBox(height: 16),
                          // 平台
                          _buildEditChipField('平台', _editPlatforms, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final data = provider.games.map((g) => g.platforms).toList();
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择平台',
                              existingTagsFuture: compute(_collectUnique, data),
                              initialSelected: _editPlatforms, hint: '如：Switch、PS5、Steam',
                            );
                            if (result != null) setState(() => _editPlatforms = result);
                          }),
                          const SizedBox(height: 16),
                          // 版本
                          _buildEditChipField('版本', _editVersions, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final data = provider.games.map((g) => g.versions).toList();
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择版本',
                              existingTagsFuture: compute(_collectUnique, data),
                              initialSelected: _editVersions, hint: '如：标准版、豪华版',
                            );
                            if (result != null) setState(() => _editVersions = result);
                          }),
                          const SizedBox(height: 16),
                          // 类型
                          _buildEditChipField('类型', _editGenres, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final tags = await provider.getTags('game_genre', excludeHidden: true);
                            final names = tags.map((t) => t['name'] as String).toList();
                            if (!mounted) return;
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择类型', existingTags: names,
                              initialSelected: _editGenres, hint: '如：RPG、动作、冒险',
                            );
                            if (result != null) setState(() => _editGenres = result);
                          }),
                          const SizedBox(height: 16),
                          // 购买平台
                          _buildEditChipField('购买平台', _editPurchasePlatforms, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final data = provider.games.map((g) => g.purchasePlatforms).toList();
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择购买平台',
                              existingTagsFuture: compute(_collectUnique, data),
                              initialSelected: _editPurchasePlatforms, hint: '如：eShop、Steam、PS Store',
                            );
                            if (result != null) setState(() => _editPurchasePlatforms = result);
                          }),
                          const SizedBox(height: 16),
                          // 购买价格
                          _buildEditField('购买价格', _purchasePriceCtrl, hint: '如：298'),
                          const SizedBox(height: 16),
                          // 游玩时长
                          _buildEditSectionLabel('游玩时长', colors),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(
                              width: 80,
                              child: TextFormField(
                                controller: _playTimeHoursCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(fontSize: 14, color: colors.onSurface),
                                decoration: InputDecoration(
                                  hintText: '小时', hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                                  filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('小时', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
                            const SizedBox(width: 12),
                            Container(
                              width: 80,
                              child: TextFormField(
                                controller: _playTimeMinutesCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(fontSize: 14, color: colors.onSurface),
                                decoration: InputDecoration(
                                  hintText: '分钟', hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                                  filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('分钟', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
                          ]),
                          const SizedBox(height: 16),
                          // 购买日期
                          _buildEditDateField('购买日期', _editPurchaseDate, (d) => setState(() => _editPurchaseDate = d), clearable: true),
                          const SizedBox(height: 16),
                          // 简介
                          _buildEditSectionLabel('游戏简介', colors),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            child: TextFormField(
                              controller: _summaryCtrl,
                              maxLines: null,
                              style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
                              decoration: InputDecoration(
                                hintText: '写下游戏简介...',
                                hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                                filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 底部操作栏
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteDialog(context),
                    icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
                    label: Text('删除', style: TextStyle(color: colors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSectionLabel(String label, ColorScheme colors) {
    return Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)));
  }

  Widget _buildEditStatusChip(String label, String value, ColorScheme colors) {
    final selected = _editStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _editStatus = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected ? [BoxShadow(color: colors.onSurface.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          color: selected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
        )),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController ctrl, {String hint = '', bool required = false}) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(required ? '$label *' : label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        style: TextStyle(fontSize: 14, color: colors.onSurface),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? '请输入$label' : null : null,
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
          filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    ]);
  }

  Widget _buildEditChipField(String label, List<String> chips, {required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: chips.isEmpty
              ? Text('点击选择$label', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)))
              : Wrap(spacing: 4, runSpacing: 4, children: chips.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(4)),
                  child: Text(c, style: TextStyle(fontSize: 12, color: colors.onSurface)),
                )).toList()),
        ),
      ),
    ]);
  }

  Widget _buildEditDateField(String label, DateTime? date, ValueChanged<DateTime?> onChanged, {bool clearable = false}) {
    final colors = Theme.of(context).colorScheme;
    final hasDate = date != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context, initialDate: date ?? DateTime.now(),
            firstDate: DateTime(1900), lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          );
          if (picked != null) onChanged(picked);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(hasDate ? '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}' : '选择日期',
              style: TextStyle(fontSize: 14, color: hasDate ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25))),
            const Spacer(),
            if (clearable && hasDate)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
              ),
          ]),
        ),
      ),
    ]);
  }

  void _showEditCoverOptions() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context, backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.outline, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft,
              child: Text('添加封面', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)))),
            const SizedBox(height: 16),
            ListTile(leading: Icon(Icons.photo_library_outlined, color: colors.onSurface.withValues(alpha: 0.6)),
              title: Text('从相册选择', style: TextStyle(color: colors.onSurface)),
              onTap: () { Navigator.pop(ctx); _pickEditCover(); }),
            ListTile(leading: Icon(Icons.link_outlined, color: colors.onSurface.withValues(alpha: 0.6)),
              title: Text('网络链接', style: TextStyle(color: colors.onSurface)),
              onTap: () { Navigator.pop(ctx); _pickEditCoverFromUrl(); }),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickEditCover() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 1200, imageQuality: 85);
      if (picked == null) return;
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getGameCoverPath(widget.game.id, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(picked.path).copy(targetPath);
      if (mounted) setState(() => _editCoverPath = targetPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择封面失败: $e');
    }
  }

  Future<void> _pickEditCoverFromUrl() async {
    final urlCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) {
      final colors = Theme.of(ctx).colorScheme;
      return AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('添加网络图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('请输入图片链接地址', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 12),
          TextField(controller: urlCtrl, keyboardType: TextInputType.url,
            style: TextStyle(fontSize: 14, color: colors.onSurface),
            decoration: InputDecoration(hintText: 'https://example.com/image.jpg',
              hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
              filled: true, fillColor: colors.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
            )),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('确定')),
        ],
      );
    });
    final url = urlCtrl.text.trim();
    urlCtrl.dispose();
    if (confirmed != true || url.isEmpty) return;
    await _downloadEditCoverFromUrl(url);
  }

  Future<void> _downloadEditCoverFromUrl(String url) async {
    setState(() => _editIsDownloading = true);
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15',
        'Accept': 'image/avif,image/webp,image/apng,*/*;q=0.8',
        'Referer': Uri.parse(url).replace(path: '/').toString(),
      });
      if (response.statusCode != 200) throw Exception('下载失败: HTTP ${response.statusCode}');
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) throw Exception('链接返回的不是图片');
      if (response.bodyBytes.length > 10 * 1024 * 1024) throw Exception('图片太大');
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getGameCoverPath(widget.game.id, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);
      if (mounted) setState(() => _editCoverPath = targetPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _editIsDownloading = false);
    }
  }

  Future<void> _saveEdit() async {
    if (!_editFormKey.currentState!.validate()) return;
    try {
      final rating = _ratingCtrl.text.isNotEmpty ? double.tryParse(_ratingCtrl.text) : null;
      final updated = widget.game.copyWith(
        title: _titleCtrl.text.trim(),
        coverPath: _editCoverPath,
        platforms: _editPlatforms,
        versions: _editVersions,
        genres: _editGenres,
        purchasePlatforms: _editPurchasePlatforms,
        purchasePrice: _purchasePriceCtrl.text.trim().isEmpty ? null : _purchasePriceCtrl.text.trim(),
        playTimeHours: int.tryParse(_playTimeHoursCtrl.text) ?? 0,
        playTimeMinutes: int.tryParse(_playTimeMinutesCtrl.text) ?? 0,
        summary: _summaryCtrl.text.trim(),
        rating: rating,
        status: _editStatus,
        category: _editCategory,
        purchaseDate: _editPurchaseDate,
        updatedAt: DateTime.now(),
      );
      await context.read<AppProvider>().updateGame(updated);
      if (!mounted) return;
      ToastUtil.show(context, '更新成功');
      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '保存失败: $e');
    }
  }

  /// 从多值字段列表中提取去重排序的唯一值（供 compute 使用）
  static List<String> _collectUnique(List<List<String>> lists) {
    final s = <String>{};
    for (final l in lists) { s.addAll(l); }
    return s.toList()..sort();
  }

  Widget _buildDesktopInfoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 56, child: Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.5))),
        ],
      ),
    );
  }

  Widget _buildStandardStyle(Game game, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
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
                  if (game.platforms.isNotEmpty)
                    _buildInfoSection('平台', game.platforms.join('、')),
                  if (game.versions.isNotEmpty)
                    _buildInfoSection('版本', game.versions.join('、')),
                  if (game.genres.isNotEmpty)
                    _buildGenresSection(game),
                  if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
                    _buildInfoSection('游玩时长', '${game.playTimeHours}小时${game.playTimeMinutes}分钟'),
                  if (game.purchasePlatforms.isNotEmpty)
                    _buildInfoSection('购买平台', game.purchasePlatforms.join('、')),
                  if (game.purchaseDate != null)
                    _buildInfoSection('购买时间', _formatDate(game.purchaseDate!)),
                  if (game.purchasePrice != null && game.purchasePrice!.isNotEmpty)
                    _buildInfoSection('购买价格', game.purchasePrice!),
                  if (game.summary != null && game.summary!.isNotEmpty)
                    _buildInfoSection('游戏简介', game.summary!),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  _buildExtraSections(game),
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
                        ? () => context.read<AppProvider>().selectGame(null)
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
                    tooltip: '切换样式',
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
        children: [
          // 封面背景
          if (hasCover)
            Positioned.fill(
              child: Image(
                image: FileImage(File(game.coverPath!)),
                fit: BoxFit.cover, width: double.infinity, height: screenH,
                repeat: ImageRepeat.repeatY,
              ),
            )
          else
            Container(color: colors.surfaceContainerHighest),

          // 毛玻璃
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
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
                        ? () => context.read<AppProvider>().selectGame(null)
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
                    tooltip: '切换样式',
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
                    if (game.platforms.isNotEmpty)
                      _buildOverlayInfoRow('平台', game.platforms.join('、')),
                    if (game.versions.isNotEmpty)
                      _buildOverlayInfoRow('版本', game.versions.join('、')),
                    if (game.genres.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildOverlayGenres(game),
                    ],
                    if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
                      _buildOverlayInfoRow('游玩时长', '${game.playTimeHours}小时${game.playTimeMinutes}分钟'),
                    if (game.purchasePlatforms.isNotEmpty)
                      _buildOverlayInfoRow('购买平台', game.purchasePlatforms.join('、')),
                    if (game.purchaseDate != null)
                      _buildOverlayInfoRow('购买时间', _formatDate(game.purchaseDate!)),
                    if (game.purchasePrice != null && game.purchasePrice!.isNotEmpty)
                      _buildOverlayInfoRow('购买价格', game.purchasePrice!),
                    if (game.summary != null && game.summary!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildOverlaySummary(game),
                    ],
                    const SizedBox(height: 12),
                    _buildExtraSectionsOverlay(game),
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
    final (label, bg) = switch (status) {
      'completed' => ('已通关', const Color(0xFF1A1A1A)),
      'playing' => ('在玩', const Color(0xFF666666)),
      'want_to_play' => ('想玩', const Color(0xFF999999)),
      'abandoned' => ('弃游', const Color(0xFF8B4513)),
      _ => ('', const Color(0xFF999999)),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }

  Widget _buildOverlayInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.9), height: 1.5))),
      ]),
    );
  }

  Widget _buildOverlayGenres(Game game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 72, child: Text('类型', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)))),
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
        Text('游戏简介', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
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
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        if (!Platform.isWindows) ...[
          const SizedBox(height: 12),
          _buildFloatingButton(
            icon: Icons.share_outlined,
            onPressed: () => _showSharePoster(game),
            tooltip: '分享海报',
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        ],
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
      message: tooltip,
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
                                  child: const Text('上下滑动调整图片位置',
                                      style: TextStyle(fontSize: 13, color: Colors.white70)),
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
          Text('暂无封面', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
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
      child: Text(label, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
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
      child: Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
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
            child: Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
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
            child: Text('类型', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
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
              Text('更多', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ],
          ),
          const SizedBox(height: 16),
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
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '$count $unit' : emptyText,
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

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    final currentStyle = UserPrefs().detailPageStyle;
    const names = ['默认样式', '毛玻璃层叠'];
    const icons = [Icons.article_outlined, Icons.blur_on_outlined];
    const subtitles = ['标准封面顶部布局', '封面背景 + 毛玻璃卡片'];
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Text('详情页样式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          const SizedBox(height: 12),
          for (int i = 0; i < names.length; i++) ...[
            if (i > 0) Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icons[i], size: 20, color: currentStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(names[i], style: TextStyle(fontSize: 13, fontWeight: currentStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
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
    });
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除"${widget.game.title}"吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('取消'),
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
                ToastUtil.show(context, '已删除');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

/// 评分输入格式化器：只允许 0-10，最多1位小数
class _RatingInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d{0,2}\.?\d{0,1}$').hasMatch(text)) return oldValue;
    final n = double.tryParse(text);
    if (n != null && n > 10) return oldValue;
    return newValue;
  }
}
