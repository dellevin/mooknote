import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../widgets/fade_in_local_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import 'movie_reviews_page.dart';
import 'movie_posters_page.dart';
import 'movie_share_page.dart';

/// 影视详情页 - 极简主义设计
class MovieDetailPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailPage({super.key, required this.movie});

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

  @override
  void initState() {
    super.initState();
    _showExactDate = UserPrefs().showExactReleaseDate;
    _detailStyle = UserPrefs().detailPageStyle;
    _posterOffset.value = UserPrefs().getCoverOffset(widget.movie.id);
  }

  @override
  void dispose() {
    _posterOffset.dispose();
    _draggingPoster.dispose();
    super.dispose();
  }

  void _toggleDateDisplay() {
    setState(() => _showExactDate = !_showExactDate);
    UserPrefs().setShowExactReleaseDate(_showExactDate);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final movie = context.watch<AppProvider>().movies
        .where((m) => m.id == widget.movie.id)
        .firstOrNull ?? widget.movie;

    return _detailStyle == 1
        ? _buildOverlayStyle(movie, colors)
        : _buildStandardStyle(movie, colors);
  }

  /// 标准样式
  Widget _buildStandardStyle(Movie movie, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          // 图片从导航栏下方开始，固定在顶部
          Column(
            children: [
              SizedBox(height: topSafe + 48),
              SizedBox(
                height: 320,
                width: double.infinity,
                child: _buildPosterSection(movie),
              ),
            ],
          ),
          // 可滚动内容区域从图片底部开始
          Positioned(
            top: topSafe + 48 + 320,
            left: 0, right: 0, bottom: 0,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfo(movie),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  if (movie.directors.isNotEmpty)
                    _buildDirectorsSection(movie),
                  if (movie.writers.isNotEmpty)
                    _buildWritersSection(movie),
                  if (movie.actors.isNotEmpty)
                    _buildActorsSection(movie),
                  if (movie.genres.isNotEmpty)
                    _buildGenresSection(movie),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  if (movie.summary != null && movie.summary!.isNotEmpty)
                    _buildSummarySection(movie),
                  Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                  _buildExtraSections(movie),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
          // 导航栏
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
                    icon: Icon(Icons.arrow_back_ios_new, color: colors.onSurface, size: 18),
                    onPressed: () => Navigator.pop(context),
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

    return Scaffold(
      body: Stack(
        children: [
          // 海报背景
          if (hasPoster)
            Positioned.fill(
              child: Image(
                image: FileImage(File(movie.posterPath!)),
                fit: BoxFit.cover, width: double.infinity, height: screenH,
                repeat: ImageRepeat.repeatY,
              ),
            )
          else
            Container(color: colors.surfaceContainerHighest),

          // 毛玻璃
          ClipRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),

          // 内容
          SafeArea(
            child: Column(children: [
              SizedBox(
                height: 48,
                child: Row(children: [
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Text(movie.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  _buildStyleButton(),
                ]),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildOverlayHeader(movie),
                    const SizedBox(height: 20),
                    // 信息区块：无毛玻璃
                    if (movie.directors.isNotEmpty) _buildDirectorsSection(movie),
                    if (movie.writers.isNotEmpty) _buildWritersSection(movie),
                    if (movie.actors.isNotEmpty) _buildActorsSection(movie),
                    // 类型标签毛玻璃
                    if (movie.genres.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildGenresSection(movie),
                    ],
                    // 简介：内部已有毛玻璃卡片
                    if (movie.summary != null && movie.summary!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildSummarySection(movie),
                    ],
                    const SizedBox(height: 12),
                    // 影评、海报墙毛玻璃
                    _buildExtraSectionsOverlay(movie),
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
              Text('导演：${movie.directors.join(' / ')}', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6))),
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
    final (label, bg, fg) = switch (status) {
      'watched' => ('已看', const Color(0xFF1A1A1A), Colors.white),
      'watching' => ('在看', const Color(0xFF666666), Colors.white),
      'want_to_watch' => ('想看', const Color(0xFF999999), Colors.white),
      _ => ('', const Color(0xFF999999), Colors.white),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildStyleButton({Color color = Colors.white}) {
    return IconButton(
      icon: Icon(Icons.tune, color: color, size: 20),
      tooltip: '切换样式',
      onPressed: _showStylePicker,
    );
  }

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    const names = ['默认样式', '毛玻璃层叠'];
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('详情页样式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: List.generate(names.length, (i) {
            final selected = _detailStyle == i;
            return GestureDetector(
              onTap: () { setState(() => _detailStyle = i); UserPrefs().setDetailPageStyle(i); Navigator.pop(ctx); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? colors.primary : colors.outline, width: 0.5),
                ),
                child: Text(names[i], style: TextStyle(
                  fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
                )),
              ),
            );
          })),
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
    return Material(
      color: Colors.transparent,
      child: Ink(
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
        child: IconButton(
          icon: Icon(icon, size: 18, color: foregroundColor),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: tooltip,
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
            '暂无海报',
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
                        ? '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月${movie.releaseDate!.day.toString().padLeft(2, '0')}日上映'
                        : '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月上映',
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
              '观看于 ${_formatDate(movie.watchDate!)}',
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
        label = '已看';
        bgColor = colors.primary;
        textColor = colors.onPrimary;
        break;
      case 'watching':
        label = '在看';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.6);
        break;
      case 'want_to_watch':
        label = '想看';
        bgColor = colors.surfaceContainerHighest;
        textColor = colors.onSurface.withValues(alpha: 0.4);
        break;
      default:
        label = '未知';
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
              '导演',
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
              '编剧',
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
              '主演',
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
            child: Text('类型', style: TextStyle(fontSize: 13,
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
                '简介',
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
                '更多',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    title,
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
                        count > 0 ? '$count $unit' : emptyText,
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    final provider = context.read<AppProvider>();
    Navigator.pushNamed(context, '/movie-form', arguments: widget.movie).then((_) {
      provider.loadMovies();
    });
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          '确定要删除"${widget.movie.title}"吗？删除后可在回收站恢复。',
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
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(widget.movie.id);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
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
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        var status = await Permission.storage.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true;
  }

  Future<int> _getAndroidSdkInt() async {
    return 30;
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
