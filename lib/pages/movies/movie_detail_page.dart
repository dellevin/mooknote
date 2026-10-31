import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../utils/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../utils/toast_util.dart';
import '../../widgets/work_people_section.dart';
import '../../widgets/character_preview_section.dart';
import '../../widgets/character_info_sheet.dart';
import '../../widgets/review_preview_section.dart';
import 'movie_reviews_page.dart';
import 'movie_posters_page.dart';
import 'movie_share_page.dart';
import '../character/character_list_page.dart';
import '../progress/progress_pages.dart';
import '../../widgets/app_overlay.dart';
import '../../l10n/app_strings.dart';

/// 影视详情页 - 极简主义设计
class MovieDetailPage extends StatefulWidget {
  final Movie movie;
  final bool embedded;

  const MovieDetailPage({super.key, required this.movie, this.embedded = false});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late bool _showExactDate;
  late int _detailStyle;
  final ValueNotifier<double> _posterOffset = ValueNotifier(0.0);
  double _posterDragStartOffset = 0.0;
  final ValueNotifier<bool> _draggingPoster = ValueNotifier(false);
  final GlobalKey _posterImageKey = GlobalKey();
  double _posterImageHeight = 0.0;
  final ValueNotifier<bool> _showTitle = ValueNotifier(false);
  ScrollController? _overlayScrollController;

  // ─── 角色预览 ───
  List<dynamic> _characters = [];

  // ─── 编辑模式 ───
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _ratingCtrl;

  @override
  void initState() {
    super.initState();
    _showExactDate = UserPrefs().showExactReleaseDate;
    _detailStyle = UserPrefs().detailPageStyle;
    _posterOffset.value = UserPrefs().getCoverOffset(widget.movie.id);
    _initEditControllers();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    final list = await context.read<AppProvider>().getMovieCharacters(widget.movie.id);
    if (!mounted) return;
    setState(() => _characters = list);
  }

  void _initEditControllers() {
    final m = widget.movie;
    _titleCtrl = TextEditingController(text: m.title);
    _summaryCtrl = TextEditingController(text: m.summary ?? '');
    _ratingCtrl = TextEditingController(text: m.rating?.toString() ?? '');
  }

  @override
  void dispose() {
    _posterOffset.dispose();
    _draggingPoster.dispose();
    _showTitle.dispose();
    _overlayScrollController?.dispose();
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _ratingCtrl.dispose();
    super.dispose();
  }

  void _toggleDateDisplay() {
    setState(() => _showExactDate = !_showExactDate);
    UserPrefs().setShowExactReleaseDate(_showExactDate);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 只订阅当前这一条：无关的 provider 变更不再重建整个详情页
    final movie = context.select<AppProvider, Movie?>(
      (p) => p.movies.where((m) => m.id == widget.movie.id).firstOrNull,
    ) ?? widget.movie;

    return switch (_detailStyle) {
      1 => _buildOverlayStyle(movie, colors),
      2 => _buildMinimalLayeredStyle(movie, colors),
      3 => _buildDoubanStyle(movie, colors),
      _ => _buildStandardStyle(movie, colors),
    };
  }

  /// 按用户配置（设置-详情页模块）生成内容模块列表。
  /// layout: 0=标准, 1=叠层毛玻璃, 2=浅色极简
  List<Widget> _orderedModules(Movie movie, ColorScheme colors, int layout) {
    final result = <Widget>[];
    for (final m in UserPrefs().getDetailModules('movie')) {
      if (!m.visible) continue;
      final isFirst = result.isEmpty;
      switch (m.id) {
        case 'credits':
          if (layout == 2) {
            if (movie.directors.isNotEmpty) result.add(_buildLayeredInfoRow('导演', movie.directors.join('，'), colors));
            if (movie.writers.isNotEmpty) result.add(_buildLayeredInfoRow('编剧', movie.writers.join('，'), colors));
            if (movie.actors.isNotEmpty) result.add(_buildLayeredInfoRow('主演', movie.actors.join('，'), colors));
          } else {
            if (movie.directors.isNotEmpty) result.add(_buildDirectorsSection(movie));
            if (movie.writers.isNotEmpty) result.add(_buildWritersSection(movie));
            if (movie.actors.isNotEmpty) result.add(_buildActorsSection(movie));
          }
        case 'genres':
          if (movie.genres.isNotEmpty) {
            if (layout == 1 && !isFirst) result.add(const SizedBox(height: 12));
            result.add(switch (layout) {
              2 => _buildLayeredGenres(movie),
              _ => _buildGenresSection(movie),
            });
          }
        case 'characters':
          result.add(CharacterPreviewSection(
            characters: _characters,
            onTap: _openCharacterSheet,
            isOverlay: layout == 1,
          ));
        case 'people':
          result.add(WorkPeopleSection(workId: movie.id, workType: 'movie', isOverlay: layout == 1));
        case 'summary':
          if (movie.summary != null && movie.summary!.isNotEmpty) {
            if (layout == 1 && !isFirst) result.add(const SizedBox(height: 12));
            result.add(switch (layout) {
              2 => _buildLayeredSummary(movie),
              _ => _buildSummarySection(movie),
            });
          }
        case 'reviews':
          if (layout == 1 && !isFirst) result.add(const SizedBox(height: 12));
          result.add(ReviewPreviewSection(
            workId: movie.id,
            workType: 'movie',
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
            1 => _buildExtraSectionsOverlay(movie),
            2 => _buildLayeredExtraSections(movie),
            _ => _buildExtraSections(movie),
          });
      }
    }
    return result;
  }

  /// 标准样式
  Widget _buildStandardStyle(Movie movie, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        // expand：内容少时 Stack 也撑满屏幕，右下角浮动按钮位置固定
        fit: StackFit.expand,
        children: [
          // 整体可滚动（图片 + 内容一起滑动）
          Padding(
            padding: EdgeInsets.only(top: topSafe + 48),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面图
                  SizedBox(
                    height: 320,
                    width: double.infinity,
                    child: _buildPosterSection(movie),
                  ),
                  // 详细信息
                  _buildBasicInfo(movie),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  // 内容模块（顺序/显隐可在设置中调整）
                  ..._orderedModules(movie, colors, 0),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          // 详情页面的标准顶部导航栏
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
                    child: Text(movie.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  _buildStyleButton(color: colors.onSurface),
                ]),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(movie),
          ),
        ],
      ),
    );
  }

  /// 毛玻璃层叠样式
  Widget _buildOverlayStyle(Movie movie, ColorScheme colors) {
    final screenH = MediaQuery.of(context).size.height;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;

    // 初始化滚动控制器（只创建一次）
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
          // 海报背景（静态模糊，转场动画期间即生效，不依赖 BackdropFilter）
          if (hasPoster)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Image(
                  image: ResizeImage(FileImage(File(movie.posterPath!)), width: 1080),
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
              // 顶部栏：只在滚动后显示标题
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
                        child: Text(movie.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStyleButton(),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _overlayScrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildOverlayHeader(movie),
                    const SizedBox(height: 20),
                    // 内容模块（顺序/显隐可在设置中调整）
                    ..._orderedModules(movie, colors, 1),
                  ]),
                ),
              ),
            ]),
          ),

          Positioned(right: 16, bottom: 24, child: _buildFloatingActionButtons(movie)),
        ],
      ),
    );
  }

  /// 浅色极简层叠样式：海报卡片 + 浅色信息卡片层叠（无毛玻璃）
  Widget _buildMinimalLayeredStyle(Movie movie, ColorScheme colors) {
    final safeTop = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        // expand：内容少时 Stack 也撑满屏幕，右下角浮动按钮位置固定
        fit: StackFit.expand,
        children: [
          // 整体可滚动（海报卡片 + 内容一起滑动）
          Padding(
            padding: EdgeInsets.only(top: safeTop + 48),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 居中海报卡片
                  Center(child: _buildLayeredPoster(movie)),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: _buildLayeredHeader(movie)),
                  const SizedBox(height: 20),
                  // 内容模块（顺序/显隐可在设置中调整）
                  ..._orderedModules(movie, colors, 2),
                ],
              ),
            ),
          ),
          // 顶部导航栏
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
                    child: Text(movie.title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  _buildStyleButton(color: colors.onSurface),
                ]),
              ),
            ),
          ),
          Positioned(right: 16, bottom: 24, child: _buildFloatingActionButtons(movie)),
        ],
      ),
    );
  }

  /// 豆瓣样式：模糊海报背景头 + 海报左/信息右 + 圆角内容区
  Widget _buildDoubanStyle(Movie movie, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;

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
              // 头部：模糊海报背景 + 信息头
              Stack(children: [
                Positioned.fill(
                  child: hasPoster
                      ? Image(
                          image: ResizeImage(FileImage(File(movie.posterPath!)), width: 1080),
                          fit: BoxFit.cover)
                      : Container(color: colors.surfaceContainerHighest),
                ),
                Positioned.fill(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                          color: Colors.black.withValues(alpha: 0.45)),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, topSafe + 56, 20, 40),
                  child: _buildDoubanHeader(movie),
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
                      ..._orderedModules(movie, colors, 0),
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
                        child: Text(movie.title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colors.onSurface),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    _buildStyleButton(
                        color: show ? colors.onSurface : Colors.white),
                  ]),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(movie),
          ),
        ],
      ),
    );
  }

  /// 豆瓣信息头：海报在左，标题/导演/年份类型/评分在右
  Widget _buildDoubanHeader(Movie movie) {
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
    final meta = <String>[
      if (movie.releaseDate != null) '${movie.releaseDate!.year}',
      ...movie.genres,
      if (movie.duration > 0) _formatDuration(movie.duration),
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
          child: hasPoster
              ? FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover)
              : Container(color: Colors.white24, child: const Icon(Icons.movie_outlined, color: Colors.white38, size: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text(movie.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3)),
            if (movie.alternateTitles.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(movie.alternateTitles.join(' / '),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5), height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            if (movie.directors.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('导演：{x}'.trf({'x': movie.directors.join(' / ')}),
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
              if (movie.rating != null && movie.rating! > 0) ...[
                const Icon(Icons.star, size: 18, color: Color(0xFFFFB800)),
                const SizedBox(width: 4),
                Text(movie.rating!.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFFFFB800))),
                const SizedBox(width: 12),
              ],
              _statusChip(movie.status),
            ]),
            if (movie.watchDate != null || movie.watchCount > 0) ...[
              const SizedBox(height: 8),
              Text([
                if (movie.watchDate != null)
                  '观看于 {date}'.trf({'date': _formatDate(movie.watchDate!)}),
                if (movie.watchCount > 0)
                  '已观看 {n} 次'.trf({'n': movie.watchCount}),
              ].join(' · '),
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45))),
            ],
          ]),
        ),
      ],
    );
  }

  /// 浅色极简：居中海报卡片
  Widget _buildLayeredPoster(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
    return Container(
      width: 160, height: 230,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasPoster
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPoster
          ? FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover)
          : Center(child: Icon(Icons.movie_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.25))),
    );
  }

  /// 浅色极简：居中标题 + 评分/状态/分类
  Widget _buildLayeredHeader(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(movie.title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface, height: 1.3)),
        if (movie.alternateTitles.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(movie.alternateTitles.join(' / '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4), height: 1.4)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (movie.rating != null) ...[
            Icon(Icons.star, size: 20, color: colors.onSurface),
            const SizedBox(width: 4),
            Text(movie.rating!.toStringAsFixed(1),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ],
          _buildStatusTag(movie),
          _buildCategoryTag(movie),
        ]),
        if (movie.releaseDate != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _toggleDateDisplay,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _showExactDate
                    ? '{y}年{m}月{d}日上映'.trf({'y': movie.releaseDate!.year, 'm': movie.releaseDate!.month.toString().padLeft(2, '0'), 'd': movie.releaseDate!.day.toString().padLeft(2, '0')})
                    : '{y}年{m}月上映'.trf({'y': movie.releaseDate!.year, 'm': movie.releaseDate!.month.toString().padLeft(2, '0')}),
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              ),
              const SizedBox(width: 4),
              Icon(Icons.tune, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
            ]),
          ),
        ],
        if (movie.watchDate != null) ...[
          const SizedBox(height: 4),
          Text('观看于 {date}'.trf({'date': _formatDate(movie.watchDate!)}),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
        if (movie.watchCount > 0) ...[
          const SizedBox(height: 4),
          Text('已观看 {n} 次'.trf({'n': movie.watchCount}),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
        if (movie.duration > 0) ...[
          const SizedBox(height: 4),
          Text(_formatDuration(movie.duration),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
        ],
      ],
    );
  }

  /// 浅色极简：信息卡片（导演/编剧/主演）
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
          SizedBox(width: 48, child: Text(label.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.5))),
        ],
      ),
    );
  }

  /// 浅色极简：类型卡片
  Widget _buildLayeredGenres(Movie movie) {
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
          SizedBox(width: 48, child: Text('类型'.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
          Expanded(child: Wrap(spacing: 8, runSpacing: 8,
            children: movie.genres.map((g) => Container(
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
  Widget _buildLayeredSummary(Movie movie) {
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
          Text('简介'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
        ]),
        const SizedBox(height: 12),
        Text(movie.summary!, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.8)),
      ]),
    );
  }

  /// 浅色极简：更多（影评/海报墙/角色）卡片标题
  Widget _buildLayeredExtraSections(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('更多'.tr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ]),
      const SizedBox(height: 12),
      ProgressEntryCard(
        parentId: movie.id,
        parentTitle: movie.title,
        config: ProgressConfig.movie,
        icon: Icons.video_library_outlined,
      ),
      const SizedBox(height: 10),
      _buildExtraSectionItem(
        icon: Icons.rate_review_outlined,
        title: '影评',
        subtitleFuture: context.read<AppProvider>().getMovieReviewCount(movie.id),
        emptyText: '暂无影评',
        unit: '条影评',
        onTap: () => _navigateToReviews(movie),
      ),
      const SizedBox(height: 10),
      _buildExtraSectionItem(
        icon: Icons.photo_library_outlined,
        title: '海报墙',
        subtitleFuture: context.read<AppProvider>().getMoviePosterCount(movie.id),
        emptyText: '暂无海报',
        unit: '张海报',
        onTap: () => _navigateToPosters(movie),
      ),
      const SizedBox(height: 10),
      _buildExtraSectionItem(
        icon: Icons.people_outline,
        title: '角色',
        subtitleFuture: context.read<AppProvider>().getMovieCharacterCount(movie.id),
        emptyText: '暂无角色',
        unit: '个角色',
        onTap: () => _navigateToCharacters(movie),
      ),
    ]);
  }

  /// 叠层模式：封面小图 + 标题/评分
  Widget _buildOverlayHeader(Movie movie) {
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
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
          child: hasPoster
              ? FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover)
              : Container(color: Colors.white24, child: const Icon(Icons.movie_outlined, color: Colors.white38, size: 32)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Text(movie.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            if (movie.directors.isNotEmpty) ...[
              const SizedBox(height: 6),
            Text('导演：{x}'.trf({'x': movie.directors.join(' / ')}), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
            ],
            const SizedBox(height: 12),
            Row(children: [
              if (movie.rating != null && movie.rating! > 0) ...[
                const Icon(Icons.star, size: 16, color: Color(0xFFFFB800)),
                const SizedBox(width: 4),
                Text(movie.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
                const SizedBox(width: 16),
              ],
              _statusChip(movie.status),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    final label = switch (status) {
      'watched' => '已看'.tr,
      'watching' => '在看'.tr,
      'want_to_watch' => '想看'.tr,
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final c = AppTheme.statusOverlayColors(colors, status);
    final bg = c.bg;
    final fg = c.fg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildStyleButton({Color color = Colors.white}) {
    return IconButton(
      icon: Icon(Icons.tune, color: color, size: 20),
      tooltip: '切换样式'.tr,
      onPressed: _showStylePicker,
    );
  }

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    const names = ['默认样式', '毛玻璃层叠', '浅色极简', '豆瓣风格'];
    const icons = [Icons.article_outlined, Icons.blur_on_outlined, Icons.layers_outlined, Icons.art_track_outlined];
    const subtitles = ['标准封面顶部布局', '封面背景 + 毛玻璃卡片', '海报卡片 + 浅色信息卡片层叠', '海报左置 + 模糊背景信息头'];
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
                  child: Icon(icons[i], size: 20, color: _detailStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(names[i].tr, style: TextStyle(fontSize: 13, fontWeight: _detailStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i].tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: _detailStyle == i
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

  Widget _buildFloatingActionButtons(Movie movie) {
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
          onPressed: () => _navigateToCharacters(movie),
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
          onPressed: () => _showSharePoster(movie),
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

  Widget _buildPosterSection(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerH = constraints.maxHeight;
        return GestureDetector(
          onLongPressStart: hasPoster ? (_) {
            HapticFeedback.mediumImpact();
            // 测量图片渲染高度
            final ctx = _posterImageKey.currentContext;
            if (ctx != null) {
              final box = ctx.findRenderObject() as RenderBox?;
              if (box != null) _posterImageHeight = box.size.height;
            }
            _draggingPoster.value = true;
            _posterDragStartOffset = _posterOffset.value;
          } : null,
          onLongPressMoveUpdate: hasPoster ? (d) {
            // 实时钳制：图片顶部不超过容器顶部(offset<=0)，图片底部不低于容器底部(offset+H>=containerH)
            final raw = _posterDragStartOffset + d.offsetFromOrigin.dy;
            final imgH = _posterImageHeight > 0 ? _posterImageHeight : containerH;
            final minOffset = -(imgH - containerH).clamp(0, double.infinity); // 图片底部不能高于容器底部
            _posterOffset.value = (raw.clamp(minOffset, 0.0) as double);
          } : null,
          onLongPressEnd: hasPoster ? (_) {
            _draggingPoster.value = false;
            final offset = _posterOffset.value;
            UserPrefs().setCoverOffset(widget.movie.id, offset);
            context.read<AppProvider>().updateMovieCoverOffset(widget.movie.id, offset);
          } : null,
          child: ValueListenableBuilder<double>(
            valueListenable: _posterOffset,
            builder: (context, offset, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPoster)
                    ClipRect(
                      child: Stack(
                        children: [
                          Positioned(
                            top: offset,
                            left: 0, right: 0,
                            child: FadeInLocalImage(
                              key: _posterImageKey,
                              path: movie.posterPath,
                              fit: BoxFit.fitWidth,
                              width: constraints.maxWidth,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildPosterPlaceholder(),
                  // 底部渐变 + 拖动遮罩
                  ValueListenableBuilder<bool>(
                    valueListenable: _draggingPoster,
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

  Widget _buildPosterPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无海报'.tr,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movie.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              height: 1.3,
            ),
          ),
          if (movie.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              movie.alternateTitles.join(' / '),
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (movie.rating != null) ...[
                Icon(
                  Icons.star,
                  size: 20,
                  color: colors.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  movie.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(movie),
              const SizedBox(width: 6),
              _buildCategoryTag(movie),
            ],
          ),
          const SizedBox(height: 8),
          if (movie.releaseDate != null)
            GestureDetector(
              onTap: _toggleDateDisplay,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showExactDate
                        ? '{y}年{m}月{d}日上映'.trf({'y': movie.releaseDate!.year, 'm': movie.releaseDate!.month.toString().padLeft(2, '0'), 'd': movie.releaseDate!.day.toString().padLeft(2, '0')})
                        : '{y}年{m}月上映'.trf({'y': movie.releaseDate!.year, 'm': movie.releaseDate!.month.toString().padLeft(2, '0')}),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.tune, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (movie.watchDate != null)
            Text(
              '观看于 {date}'.trf({'date': _formatDate(movie.watchDate!)}),
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          if (movie.watchCount > 0)
            Text(
              '已观看 {n} 次'.trf({'n': movie.watchCount}),
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          if (movie.duration > 0)
            Text(
              _formatDuration(movie.duration),
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    String label;
    Color bgColor;
    Color textColor;
    switch (movie.status) {
      case 'watched':
        label = '已看'.tr;
        bgColor = colors.primary;
        textColor = colors.onPrimary;
        break;
      case 'watching':
        label = '在看'.tr;
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.6);
        break;
      case 'want_to_watch':
        label = '想看'.tr;
        bgColor = colors.surfaceContainerHighest;
        textColor = colors.onSurface.withValues(alpha: 0.4);
        break;
      default:
        label = '未知'.tr;
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCategoryTag(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    const labels = {
      'movie': '电影',
      'tv': '电视剧',
      'anime': '动漫',
      'variety': '综艺',
      'documentary': '纪录片',
      'short': '微短剧',
    };
    final label = labels[movie.category];
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.tr,
        style: TextStyle(
          fontSize: 12,
          color: colors.onSurface.withValues(alpha: 0.5),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDirectorsSection(Movie movie) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '导演'.tr,
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.directors.join('，'),
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWritersSection(Movie movie) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '编剧'.tr,
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.writers.join('，'),
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActorsSection(Movie movie) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '主演'.tr,
              style: TextStyle(
                fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.actors.join('，'),
              style: TextStyle(
                fontSize: 15,
                color: isOverlay ? Colors.white : colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresSection(Movie movie) {
    final isOverlay = _detailStyle == 1;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isOverlay ? 5 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text('类型'.tr, style: TextStyle(fontSize: 13,
                color: isOverlay ? const Color(0x66FFFFFF) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: movie.genres.map((g) => _buildGenreChip(g, isOverlay)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String label, bool isOverlay) {
    if (isOverlay) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          ),
        ),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
    );
  }

  Widget _buildSummarySection(Movie movie) {
    final isOverlay = _detailStyle == 1;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: isOverlay ? Colors.white : colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '简介'.tr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isOverlay ? Colors.white : colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  movie.summary!,
                  style: TextStyle(
                    fontSize: 15,
                    color: isOverlay ? Colors.white : colors.onSurface,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSections(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '更多'.tr,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProgressEntryCard(
            parentId: movie.id,
            parentTitle: movie.title,
            config: ProgressConfig.movie,
            icon: Icons.video_library_outlined,
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.rate_review_outlined,
            title: '影评',
            subtitleFuture: context.read<AppProvider>().getMovieReviewCount(movie.id),
            emptyText: '暂无影评',
            unit: '条影评',
            onTap: () => _navigateToReviews(movie),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.photo_library_outlined,
            title: '海报墙',
            subtitleFuture: context.read<AppProvider>().getMoviePosterCount(movie.id),
            emptyText: '暂无海报',
            unit: '张海报',
            onTap: () => _navigateToPosters(movie),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.people_outline,
            title: '角色',
            subtitleFuture: context.read<AppProvider>().getMovieCharacterCount(movie.id),
            emptyText: '暂无角色',
            unit: '个角色',
            onTap: () => _navigateToCharacters(movie),
          ),
        ],
      ),
    );
  }

  /// 叠层模式：影评、海报墙各自独立毛玻璃卡片
  Widget _buildExtraSectionsOverlay(Movie movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ProgressEntryCard(
            parentId: movie.id,
            parentTitle: movie.title,
            config: ProgressConfig.movie,
            icon: Icons.video_library_outlined,
            frosted: true,
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.rate_review_outlined,
            title: '影评',
            subtitleFuture: context.read<AppProvider>().getMovieReviewCount(movie.id),
            emptyText: '暂无影评',
            unit: '条影评',
            onTap: () => _navigateToReviews(movie),
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.photo_library_outlined,
            title: '海报墙',
            subtitleFuture: context.read<AppProvider>().getMoviePosterCount(movie.id),
            emptyText: '暂无海报',
            unit: '张海报',
            onTap: () => _navigateToPosters(movie),
          ),
          const SizedBox(height: 12),
          _buildFrostedExtraItem(
            icon: Icons.people_outline,
            title: '角色',
            subtitleFuture: context.read<AppProvider>().getMovieCharacterCount(movie.id),
            emptyText: '暂无角色',
            unit: '个角色',
            onTap: () => _navigateToCharacters(movie),
          ),
        ],
      ),
    );
  }

  /// 毛玻璃影评/海报卡片
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
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
                      Text(title.tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      FutureBuilder<int>(
                        future: subtitleFuture,
                        builder: (ctx, snap) {
                          final count = snap.data ?? 0;
                          return Text(count > 0 ? '$count ${unit.tr}' : emptyText.tr,
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.tr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '$count ${unit.tr}' : emptyText.tr,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReviews(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieReviewsPage(movie: movie),
      ),
    );
  }

  void _navigateToPosters(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviePostersPage(movie: movie),
      ),
    );
  }

  void _navigateToCharacters(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieCharactersPage(movie: movie),
      ),
    ).then((_) => _loadCharacters());
  }

  Future<void> _openCharacterSheet(dynamic character) async {
    final needRefresh = await CharacterInfoSheet.show(
      context,
      entityType: 'movie',
      entityId: widget.movie.id,
      character: character,
    );
    if (needRefresh == true) _loadCharacters();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 格式化时长：120 -> "2小时0分"，0 -> ""
  String _formatDuration(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '时长 {h}小时{m}分'.trf({'h': h, 'm': m});
    if (h > 0) return '时长 {h}小时'.trf({'h': h});
    return '时长 {m}分'.trf({'m': m});
  }

  void _navigateToEdit(BuildContext context) {
    final provider = context.read<AppProvider>();
    Navigator.pushNamed(context, '/movie-form', arguments: widget.movie).then((_) {
      provider.setEditRefresh(widget.movie.id);
      provider.loadMovies();
    });
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除'.tr,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          '确定要删除《{title}》吗？删除后可在回收站恢复。'.trf({'title': widget.movie.title}),
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('取消'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<AppProvider>();
              await provider.removeMovie(widget.movie.id);
              if (!mounted || !context.mounted) return;
              if (widget.embedded) {
                Navigator.of(context).pop(); // close dialog
                provider.selectMovie(null);
              } else {
                // 先关 dialog，再关详情页；分两步避免连续 pop 导致的导航栈异常
                Navigator.of(context).pop(); // close dialog
                if (mounted) Navigator.of(context).pop(); // close detail page
              }
              if (mounted && context.mounted) {
                ToastUtil.show(context, '已删除'.tr);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('删除'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showSharePoster(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieSharePage(movie: movie),
      ),
    );
  }
}
