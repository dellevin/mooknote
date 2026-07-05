import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/genre_selector_page.dart';
import '../../widgets/text_input_panel.dart';

/// 从多值字段列表中提取去重排序的唯一值（供 compute 使用）
List<String> _collectUnique(List<List<String>> lists) {
  final s = <String>{};
  for (final l in lists) { s.addAll(l); }
  return s.toList()..sort();
}

/// 添加/编辑游戏页面
class GameFormPage extends StatefulWidget {
  final Game? game;
  final String? initialStatus;

  const GameFormPage({super.key, this.game, this.initialStatus});

  @override
  State<GameFormPage> createState() => _GameFormPageState();
}

class _GameFormPageState extends State<GameFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _titleController;
  late TextEditingController _ratingController;
  late TextEditingController _playTimeHoursController;
  late TextEditingController _playTimeMinutesController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _summaryController;

  List<String> _platforms = [];
  List<String> _versions = [];
  List<String> _genres = [];
  List<String> _purchasePlatforms = [];
  String? _coverPath;
  String _status = 'want_to_play';
  String _category = 'digital';
  DateTime? _purchaseDate;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    Game? game = widget.game;
    if (game != null) {
      final appProvider = context.read<AppProvider>();
      final latestGame = appProvider.games
          .where((g) => g.id == game!.id)
          .firstOrNull;
      if (latestGame != null) {
        game = latestGame;
      }
    }

    _titleController = TextEditingController(text: game?.title ?? '');
    _ratingController = TextEditingController(text: game?.rating?.toString() ?? '');
    _playTimeHoursController = TextEditingController(text: game?.playTimeHours.toString() ?? '0');
    _playTimeMinutesController = TextEditingController(text: game?.playTimeMinutes.toString() ?? '0');
    _purchasePriceController = TextEditingController(text: game?.purchasePrice ?? '');
    _summaryController = TextEditingController(text: game?.summary ?? '');

    if (game != null) {
      _platforms = List.from(game.platforms);
      _versions = List.from(game.versions);
      _genres = List.from(game.genres);
      _purchasePlatforms = List.from(game.purchasePlatforms);
      _coverPath = game.coverPath;
      _status = game.status;
      _category = game.category;
      _purchaseDate = game.purchaseDate;
    } else if (widget.initialStatus != null) {
      _status = widget.initialStatus!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ratingController.dispose();
    _playTimeHoursController.dispose();
    _playTimeMinutesController.dispose();
    _purchasePriceController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = color ?? colors.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.game != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmLeave();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          title: Text(isEdit ? '编辑游戏' : '添加游戏'),
          actions: [
            _buildActionButton(
              icon: Icons.save_outlined,
              onPressed: _saveGame,
              tooltip: '保存',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Center(child: _buildCoverPicker()),
              const SizedBox(height: 20),
              _buildStatusRatingRow(),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // 名称
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '名称',
                      value: _titleController.text,
                      required: true,
                      icon: Icons.sports_esports_outlined,
                      onTap: () async {
                        final result = await TextInputPanel.show(
                          context: context,
                          title: '游戏名称',
                          initialValue: _titleController.text,
                          hint: '请输入游戏名称',
                        );
                        if (!mounted) return;
                        if (result != null) setState(() => _titleController.text = result);
                      },
                    ),
                  ),
                  // 平台
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '平台',
                      value: _platforms.isEmpty
                          ? ''
                          : '${_platforms.length}个：${_platforms.join('、')}',
                      icon: Icons.devices_outlined,
                      scrollHorizontal: true,
                      onTap: () async {
                        final provider = context.read<AppProvider>();
                        final data = provider.games.map((g) => g.platforms).toList();
                        final result = await GenreSelectorPage.show(
                          context: context,
                          title: '选择平台',
                          existingTagsFuture: compute(_collectUnique, data),
                          initialSelected: _platforms,
                          hint: '如：PS5、Switch、Steam',
                        );
                        if (!mounted) return;
                        if (result != null) setState(() => _platforms = result);
                      },
                    ),
                  ),
                  // 版本
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '版本',
                      value: _versions.isEmpty
                          ? ''
                          : '${_versions.length}个：${_versions.join('、')}',
                      icon: Icons.library_books_outlined,
                      scrollHorizontal: true,
                      onTap: () async {
                        final provider = context.read<AppProvider>();
                        final data = provider.games.map((g) => g.versions).toList();
                        final result = await GenreSelectorPage.show(
                          context: context,
                          title: '选择版本',
                          existingTagsFuture: compute(_collectUnique, data),
                          initialSelected: _versions,
                          hint: '如：标准版、豪华版',
                        );
                        if (!mounted) return;
                        if (result != null) setState(() => _versions = result);
                      },
                    ),
                  ),
                  // 类型
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '类型',
                      value: _genres.isEmpty
                          ? ''
                          : '${_genres.length}个：${_genres.join('、')}',
                      icon: Icons.style_outlined,
                      onTap: () async {
                        final provider = context.read<AppProvider>();
                        final tags = await provider.getTags('game_genre', excludeHidden: true);
                        final existingNames = tags.map((t) => t['name'] as String).toList();
                        // 补充已有游戏中使用过的类型
                        final gameGenres = provider.games
                            .expand((g) => g.genres)
                            .toSet()
                            .toList();
                        for (final g in gameGenres) {
                          if (!existingNames.contains(g)) existingNames.add(g);
                        }
                        if (!mounted) return;
                        final result = await GenreSelectorPage.show(
                          context: context,
                          title: '选择类型',
                          existingTags: existingNames,
                          initialSelected: _genres,
                          hint: '如：RPG、动作、冒险',
                        );
                        if (!mounted) return;
                        if (result != null) setState(() => _genres = result);
                      },
                    ),
                  ),
                  // 游玩时长
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '游玩时长',
                      value: _buildPlayTimeText(),
                      icon: Icons.timer_outlined,
                      onTap: () => _showPlayTimePicker(),
                    ),
                  ),
                  // 购买平台
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '购买平台',
                      value: _purchasePlatforms.isEmpty
                          ? ''
                          : '${_purchasePlatforms.length}个：${_purchasePlatforms.join('、')}',
                      icon: Icons.store_outlined,
                      scrollHorizontal: true,
                      onTap: () async {
                        final provider = context.read<AppProvider>();
                        final data = provider.games.map((g) => g.purchasePlatforms).toList();
                        final result = await GenreSelectorPage.show(
                          context: context,
                          title: '选择购买平台',
                          existingTagsFuture: compute(_collectUnique, data),
                          initialSelected: _purchasePlatforms,
                          hint: '如：Steam、eShop、PlayStation Store',
                        );
                        if (!mounted) return;
                        if (result != null) setState(() => _purchasePlatforms = result);
                      },
                    ),
                  ),
                  // 购买时间
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '购买时间',
                      value: _purchaseDate != null
                          ? '${_purchaseDate!.year}.${_purchaseDate!.month.toString().padLeft(2, '0')}.${_purchaseDate!.day.toString().padLeft(2, '0')}'
                          : '',
                      icon: Icons.calendar_today_outlined,
                      trailing: _purchaseDate != null
                          ? GestureDetector(
                              onTap: () => setState(() => _purchaseDate = null),
                              child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                            )
                          : null,
                      onTap: () => _selectPurchaseDate(),
                    ),
                  ),
                  // 购买价格
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    height: 90,
                    child: _buildInfoCard(
                      label: '购买价格',
                      value: _purchasePriceController.text.isNotEmpty ? _purchasePriceController.text : '',
                      icon: Icons.payments_outlined,
                      onTap: () async {
                        final result = await TextInputPanel.show(
                          context: context,
                          title: '购买价格',
                          initialValue: _purchasePriceController.text,
                          hint: '如：298元、49.99美元',
                          keyboardType: TextInputType.text,
                        );
                        if (!mounted) return;
                        if (result != null) setState(() => _purchasePriceController.text = result);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 游戏简介（独占一行）
              SizedBox(
                width: double.infinity,
                child: _buildInfoCard(
                  label: '游戏简介',
                  value: _summaryController.text,
                  icon: Icons.description_outlined,
                  height: 160,
                  scrollable: true,
                  onTap: () => _editSummary(),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  static const _categoryLabels = {'digital': '数字版', 'cartridge': '卡带', 'disc': '光盘'};

  String _buildPlayTimeText() {
    final h = int.tryParse(_playTimeHoursController.text) ?? 0;
    final m = int.tryParse(_playTimeMinutesController.text) ?? 0;
    if (h == 0 && m == 0) return '';
    final parts = <String>[];
    if (h > 0) parts.add('$h小时');
    if (m > 0) parts.add('$m分钟');
    return parts.join('');
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool required = false,
    IconData? icon,
    Widget? trailing,
    double? height,
    bool scrollable = false,
    bool scrollHorizontal = false,
  }) {
    final hasValue = value.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    Widget buildContent() {
      if (scrollable && height != null) {
        return Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              hasValue ? value : '点击填写',
              style: TextStyle(
                fontSize: 15,
                color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      } else if (scrollHorizontal) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Text(
            hasValue ? value : '点击填写',
            style: TextStyle(
              fontSize: 15,
              color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        );
      } else {
        return Text(
          hasValue ? value : '点击填写',
          style: TextStyle(
            fontSize: 15,
            color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
            fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
          boxShadow: [
            BoxShadow(
              color: colors.onSurface.withValues(alpha: 0.018),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                ],
                Text(
                  required ? '$label *' : label,
                  style: TextStyle(
                    fontSize: 12,
                    color: required ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: required ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const SizedBox(height: 8),
            buildContent(),
          ],
        ),
      ),
    );
  }

  /// 全屏编辑游戏简介
  Future<void> _editSummary() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _SummaryEditorPage(initialText: _summaryController.text),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _summaryController.text = result);
    }
  }

  /// 状态 + 评分 + 类别合并行
  Widget _buildStatusRatingRow() {
    final colors = Theme.of(context).colorScheme;
    final currentRating = double.tryParse(_ratingController.text) ?? 0;
    final starRating = currentRating / 2;
    final hasRating = _ratingController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // 状态
          Row(
            children: [
              Text('状态', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusOption('想玩', 'want_to_play'),
                    _buildStatusOption('在玩', 'playing'),
                    _buildStatusOption('已通关', 'completed'),
                    _buildStatusOption('弃游', 'abandoned'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 评分
          Row(
            children: [
              Text('评分', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 12),
              ...List.generate(5, (index) {
                final starValue = index + 1;
                final isFilled = starValue <= starRating;
                final isHalf = starValue == starRating.ceil() && starRating % 1 != 0;
                return GestureDetector(
                  onTap: () => setState(() => _ratingController.text = (starValue * 2).toString()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      isHalf ? Icons.star_half : (isFilled ? Icons.star : Icons.star_border),
                      size: 22,
                      color: (isFilled || isHalf) ? const Color(0xFFFFB800) : colors.outline,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Container(
                width: 48, height: 28,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextFormField(
                  controller: _ratingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  inputFormatters: [GameRatingInputFormatter()],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: '0-10',
                    hintStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (hasRating) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _ratingController.clear()),
                  child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 类别
          Row(
            children: [
              Text('类别', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _categoryLabels.entries.map((e) {
                      final isSelected = _category == e.key;
                      return GestureDetector(
                        onTap: () => setState(() => _category = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String label, String value) {
    final isSelected = _status == value;
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.onSurface.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            color: isSelected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    final hasCover = _coverPath != null && _coverPath!.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _showCoverOptions,
          child: Container(
            width: 120,
            height: 170,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasCover)
                  FadeInLocalImage(path: _coverPath, fit: BoxFit.cover)
                else
                  _buildCoverPlaceholder(),
                if (_isDownloading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        if (hasCover)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () => setState(() => _coverPath = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 14, color: colors.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 4),
                    Text('移除封面', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
        const SizedBox(height: 8),
        Text('封面', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
      ],
    );
  }

  Future<void> _pickCover() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final gameId = widget.game?.id ?? const Uuid().v4();
        final targetPath = await ImagePathHelper.instance.getGameCoverPath(gameId, fileName);
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
        await File(pickedFile.path).copy(targetPath);
        if (!mounted) return;
        setState(() => _coverPath = targetPath);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '选择封面失败: $e');
      }
    }
  }

  /// 显示封面选择选项
  void _showCoverOptions() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: colors.outline, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('添加封面', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCoverOption(
                  icon: Icons.photo_library_outlined,
                  title: '从相册选择',
                  onTap: () { Navigator.pop(context); _pickCover(); },
                ),
                _buildCoverOption(
                  icon: Icons.link_outlined,
                  title: '网络链接',
                  onTap: () { Navigator.pop(context); _pickCoverFromUrl(); },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCoverOption({required IconData icon, required String title, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 22, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontSize: 16, color: colors.onSurface)),
            const Spacer(),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }

  /// 从网络链接选择封面
  Future<void> _pickCoverFromUrl() async {
    final urlController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('添加网络图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请输入图片链接地址', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    final url = urlController.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      urlController.dispose();
    });

    if (confirmed != true || url.isEmpty) return;
    await _downloadCoverFromUrl(url);
  }

  /// 从URL下载封面图
  Future<void> _downloadCoverFromUrl(String url) async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );

      if (response.statusCode != 200) throw Exception('下载失败: HTTP ${response.statusCode}');

      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) throw Exception('链接返回的不是图片');
      if (response.bodyBytes.length > 10 * 1024 * 1024) throw Exception('图片太大');

      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final gameId = widget.game?.id ?? const Uuid().v4();
      final targetPath = await ImagePathHelper.instance.getGameCoverPath(gameId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);

      if (!mounted) return;
      setState(() => _coverPath = targetPath);
    } catch (e) {
      debugPrint('封面下载失败: $e');
      if (mounted) ToastUtil.show(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showPlayTimePicker() {
    final colors = Theme.of(context).colorScheme;
    final hoursController = TextEditingController(text: _playTimeHoursController.text);
    final minutesController = TextEditingController(text: _playTimeMinutesController.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('游玩时长', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hoursController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '小时',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: minutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '分钟',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _playTimeHoursController.text = hoursController.text;
                _playTimeMinutesController.text = minutesController.text;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('确定'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ).then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        hoursController.dispose();
        minutesController.dispose();
      });
    });
  }

  Future<void> _selectPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => child!,
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  bool _hasContent() {
    if (widget.game != null) return true;
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_ratingController.text.trim().isNotEmpty) return true;
    if (_coverPath != null) return true;
    if (_platforms.isNotEmpty || _versions.isNotEmpty || _genres.isNotEmpty) return true;
    if (_purchasePlatforms.isNotEmpty) return true;
    if (_purchaseDate != null) return true;
    if (_purchasePriceController.text.trim().isNotEmpty) return true;
    if (_summaryController.text.trim().isNotEmpty) return true;
    if (int.tryParse(_playTimeHoursController.text) != null && int.parse(_playTimeHoursController.text) > 0) return true;
    if (int.tryParse(_playTimeMinutesController.text) != null && int.parse(_playTimeMinutesController.text) > 0) return true;
    return false;
  }

  Future<bool> _confirmLeave() async {
    if (!_hasContent()) return true;
    final colors = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('未保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('当前内容未保存，确定要离开吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('离开'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return result ?? false;
  }

  Future<void> _saveGame() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final rating = _ratingController.text.isNotEmpty
          ? double.tryParse(_ratingController.text)
          : null;
      final playTimeHours = int.tryParse(_playTimeHoursController.text) ?? 0;
      final playTimeMinutes = int.tryParse(_playTimeMinutesController.text) ?? 0;
      final now = DateTime.now();

      if (widget.game == null) {
        final newGameId = const Uuid().v4();
        String? finalCoverPath;
        if (_coverPath != null && _coverPath!.isNotEmpty) {
          finalCoverPath = await _moveCoverToNewId(_coverPath!, newGameId);
        }

        final newGame = Game(
          id: newGameId,
          title: _titleController.text.trim(),
          coverPath: finalCoverPath,
          rating: rating,
          status: _status,
          category: _category,
          platforms: _platforms,
          versions: _versions,
          genres: _genres,
          playTimeHours: playTimeHours,
          playTimeMinutes: playTimeMinutes,
          purchasePlatforms: _purchasePlatforms,
          purchaseDate: _purchaseDate,
          purchasePrice: _purchasePriceController.text.trim().isNotEmpty
              ? _purchasePriceController.text.trim()
              : null,
          summary: _summaryController.text.trim().isNotEmpty
              ? _summaryController.text.trim()
              : null,
          createdAt: now,
          updatedAt: now,
        );

        await context.read<AppProvider>().addGame(newGame);
      } else {
        final updatedGame = widget.game!.copyWith(
          title: _titleController.text.trim(),
          coverPath: _coverPath,
          rating: rating,
          status: _status,
          category: _category,
          platforms: _platforms,
          versions: _versions,
          genres: _genres,
          playTimeHours: playTimeHours,
          playTimeMinutes: playTimeMinutes,
          purchasePlatforms: _purchasePlatforms,
          purchaseDate: _purchaseDate,
          purchasePrice: _purchasePriceController.text.trim().isNotEmpty
              ? _purchasePriceController.text.trim()
              : null,
          summary: _summaryController.text.trim().isNotEmpty
              ? _summaryController.text.trim()
              : null,
          updatedAt: now,
        );

        await context.read<AppProvider>().updateGame(updatedGame);
      }

      if (!mounted) return;
      ToastUtil.show(context, widget.game == null ? '添加成功' : '更新成功');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: $e');
    }
  }

  Future<String?> _moveCoverToNewId(String currentPath, String newGameId) async {
    final normalizedPath = currentPath.replaceAll('\\', '/');
    if (normalizedPath.contains('/games/$newGameId/')) {
      return currentPath;
    }

    final fileName = p.basename(currentPath);
    final newPath = await ImagePathHelper.instance.getGameCoverPath(newGameId, fileName);
    await ImagePathHelper.instance.ensureDirExists(p.dirname(newPath));

    final currentFile = File(currentPath);
    if (await currentFile.exists()) {
      await currentFile.rename(newPath);
      final tempDir = Directory(p.dirname(currentPath));
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
      return newPath;
    }

    return null;
  }
}

/// 评分输入格式化器：只允许 0-10，最多1位小数
class GameRatingInputFormatter extends TextInputFormatter {
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

/// 游戏简介全屏编辑页
class _SummaryEditorPage extends StatefulWidget {
  final String initialText;
  const _SummaryEditorPage({required this.initialText});

  @override
  State<_SummaryEditorPage> createState() => _SummaryEditorPageState();
}

class _SummaryEditorPageState extends State<_SummaryEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('游戏简介'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: Text('完成', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary,
            )),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.6),
        decoration: InputDecoration(
          hintText: '写下游戏简介...',
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
