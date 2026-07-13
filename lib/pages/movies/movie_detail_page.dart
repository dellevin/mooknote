import 'dart:io';
import 'dart:ui' as ui;
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
import 'movie_reviews_page.dart';
import 'movie_posters_page.dart';
import 'movie_share_page.dart';

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

  // ─── 编辑模式 ───
  bool _isEditing = false;
  final _editFormKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _ratingCtrl;
  List<String> _editDirectors = [];
  List<String> _editWriters = [];
  List<String> _editActors = [];
  List<String> _editGenres = [];
  List<String> _editAlternateTitles = [];
  String? _editPosterPath;
  String _editStatus = 'want_to_watch';
  String _editCategory = 'movie';
  DateTime? _editReleaseDate;
  DateTime? _editWatchDate;
  bool _editIsDownloading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _showExactDate = UserPrefs().showExactReleaseDate;
    _detailStyle = UserPrefs().detailPageStyle;
    _posterOffset.value = UserPrefs().getCoverOffset(widget.movie.id);
    _initEditControllers();
  }

  void _initEditControllers() {
    final m = widget.movie;
    _titleCtrl = TextEditingController(text: m.title);
    _summaryCtrl = TextEditingController(text: m.summary ?? '');
    _ratingCtrl = TextEditingController(text: m.rating?.toString() ?? '');
    _editDirectors = List.from(m.directors);
    _editWriters = List.from(m.writers);
    _editActors = List.from(m.actors);
    _editGenres = List.from(m.genres);
    _editAlternateTitles = List.from(m.alternateTitles);
    _editPosterPath = m.posterPath;
    _editStatus = m.status;
    _editCategory = m.category;
    _editReleaseDate = m.releaseDate;
    _editWatchDate = m.watchDate;
  }

  void _enterEditMode() {
    // 从 provider 获取最新数据
    final latest = context.read<AppProvider>().movies
        .where((m) => m.id == widget.movie.id).firstOrNull ?? widget.movie;
    _titleCtrl.text = latest.title;
    _summaryCtrl.text = latest.summary ?? '';
    _ratingCtrl.text = latest.rating?.toString() ?? '';
    _editDirectors = List.from(latest.directors);
    _editWriters = List.from(latest.writers);
    _editActors = List.from(latest.actors);
    _editGenres = List.from(latest.genres);
    _editAlternateTitles = List.from(latest.alternateTitles);
    _editPosterPath = latest.posterPath;
    _editStatus = latest.status;
    _editCategory = latest.category;
    _editReleaseDate = latest.releaseDate;
    _editWatchDate = latest.watchDate;
    setState(() => _isEditing = true);
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
    final movie = context.watch<AppProvider>().movies
        .where((m) => m.id == widget.movie.id)
        .firstOrNull ?? widget.movie;

    if (Breakpoint.isDesktop(context)) {
      return _buildDesktopStyle(movie, colors);
    }
    return _detailStyle == 1
        ? _buildOverlayStyle(movie, colors)
        : _buildStandardStyle(movie, colors);
  }

  /// 桌面端左右分栏布局
  Widget _buildDesktopStyle(Movie movie, ColorScheme colors) {
    if (_isEditing) return _buildDesktopEditStyle(movie, colors);
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
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
                    ? () => context.read<AppProvider>().selectMovie(null)
                    : () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(movie.title,
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
                          boxShadow: hasPoster
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasPoster
                            ? FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover)
                            : Center(child: Icon(Icons.movie_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.25))),
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
                        // 标题
                        Text(movie.title,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3)),
                        if (movie.alternateTitles.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(movie.alternateTitles.join(' / '),
                            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4), height: 1.4)),
                        ],
                        const SizedBox(height: 16),
                        // 评分 + 状态 + 分类
                        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          if (movie.rating != null) ...[
                            Icon(Icons.star, size: 20, color: colors.onSurface),
                            const SizedBox(width: 4),
                            Text(movie.rating!.toStringAsFixed(1),
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                          ],
                          _buildStatusTag(movie),
                          _buildCategoryTag(movie),
                        ]),
                        const SizedBox(height: 8),
                        if (movie.releaseDate != null)
                          GestureDetector(
                            onTap: _toggleDateDisplay,
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(
                                _showExactDate
                                    ? '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月${movie.releaseDate!.day.toString().padLeft(2, '0')}日上映'
                                    : '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月上映',
                                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.tune, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
                            ]),
                          ),
                        if (movie.watchDate != null) ...[
                          const SizedBox(height: 4),
                          Text('观看于 ${_formatDate(movie.watchDate!)}',
                            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
                        ],
                        Divider(height: 32, thickness: 0.5, color: colors.outline),
                        // 详细信息
                        if (movie.directors.isNotEmpty) _buildDesktopInfoRow('导演', movie.directors.join('，'), colors),
                        if (movie.writers.isNotEmpty) _buildDesktopInfoRow('编剧', movie.writers.join('，'), colors),
                        if (movie.actors.isNotEmpty) _buildDesktopInfoRow('主演', movie.actors.join('，'), colors),
                        if (movie.genres.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 56, child: Text('类型', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
                            Expanded(child: Wrap(spacing: 8, runSpacing: 8,
                              children: movie.genres.map((g) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                                child: Text(g, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                              )).toList(),
                            )),
                          ]),
                        ],
                        if (movie.summary != null && movie.summary!.isNotEmpty) ...[
                          Divider(height: 32, thickness: 0.5, color: colors.outline),
                          Row(children: [
                            Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text('简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                          ]),
                          const SizedBox(height: 12),
                          Text(movie.summary!, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.8)),
                        ],
                        Divider(height: 32, thickness: 0.5, color: colors.outline),
                        // 更多
                        Row(children: [
                          Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text('更多', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        ]),
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

  static const _categories = [
    ('电影', 'movie'), ('电视剧', 'tv'), ('动漫', 'anime'),
    ('综艺', 'variety'), ('纪录片', 'documentary'), ('微短剧', 'short'), ('其他', 'other'),
  ];

  Widget _buildDesktopEditStyle(Movie movie, ColorScheme colors) {
    final hasPoster = _editPosterPath != null && _editPosterPath!.isNotEmpty;
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
                  child: Text('编辑影视',
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
                              hasPoster
                                  ? FadeInLocalImage(path: _editPosterPath, fit: BoxFit.cover)
                                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Icon(Icons.image_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
                                      const SizedBox(height: 8),
                                      Text('点击添加海报', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                                    ]),
                              if (_editIsDownloading)
                                Container(color: Colors.black.withValues(alpha: 0.4),
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                            ]),
                          ),
                        ),
                        if (hasPoster)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _editPosterPath = null),
                              child: Text('移除海报', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)))),
                          ),
                        const SizedBox(height: 20),
                        // 状态
                        _buildEditSectionLabel('状态', colors),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            _buildEditStatusChip('想看', 'want_to_watch', colors),
                            _buildEditStatusChip('在看', 'watching', colors),
                            _buildEditStatusChip('已看', 'watched', colors),
                          ]),
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
                        Wrap(spacing: 4, runSpacing: 4, children: _categories.map((c) {
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
                          _buildEditField('名称', _titleCtrl, hint: '影视名称', required: true),
                          const SizedBox(height: 16),
                          // 别名
                          _buildEditChipField('别名', _editAlternateTitles, onTap: () async {
                            final result = await GenreSelectorPage.show(
                              context: context, title: '添加别名', existingTags: [],
                              initialSelected: _editAlternateTitles, hint: '输入别名',
                            );
                            if (result != null) setState(() => _editAlternateTitles = result);
                          }),
                          const SizedBox(height: 16),
                          // 导演
                          _buildEditChipField('导演', _editDirectors, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final data = provider.movies.map((m) => m.directors).toList();
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择导演',
                              existingTagsFuture: compute(_collectUnique, data),
                              initialSelected: _editDirectors, hint: '如：张艺谋、李安',
                            );
                            if (result != null) setState(() => _editDirectors = result);
                          }),
                          const SizedBox(height: 16),
                          // 编剧
                          _buildEditChipField('编剧', _editWriters, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final data = provider.movies.map((m) => m.writers).toList();
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择编剧',
                              existingTagsFuture: compute(_collectUnique, data),
                              initialSelected: _editWriters, hint: '如：刘慈欣、王家卫',
                            );
                            if (result != null) setState(() => _editWriters = result);
                          }),
                          const SizedBox(height: 16),
                          // 主演
                          _buildEditChipField('主演', _editActors, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final data = provider.movies.map((m) => m.actors).toList();
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择主演',
                              existingTagsFuture: compute(_collectUnique, data),
                              initialSelected: _editActors, hint: '如：梁朝伟、周星驰',
                            );
                            if (result != null) setState(() => _editActors = result);
                          }),
                          const SizedBox(height: 16),
                          // 类型
                          _buildEditChipField('类型', _editGenres, onTap: () async {
                            final provider = context.read<AppProvider>();
                            final tags = await provider.getTags('movie_genre', excludeHidden: true);
                            final names = tags.map((t) => t['name'] as String).toList();
                            if (!mounted) return;
                            final result = await GenreSelectorPage.show(
                              context: context, title: '选择类型', existingTags: names,
                              initialSelected: _editGenres, hint: '如：剧情、科幻、悬疑',
                            );
                            if (result != null) setState(() => _editGenres = result);
                          }),
                          const SizedBox(height: 16),
                          // 日期行
                          Row(children: [
                            Expanded(child: _buildEditDateField('上映日期', _editReleaseDate, (d) => setState(() => _editReleaseDate = d))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildEditDateField('观看日期', _editWatchDate, (d) => setState(() => _editWatchDate = d), clearable: true)),
                          ]),
                          const SizedBox(height: 16),
                          // 简介
                          _buildEditSectionLabel('剧情简介', colors),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            child: TextFormField(
                              controller: _summaryCtrl,
                              maxLines: null,
                              style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
                              decoration: InputDecoration(
                                hintText: '写下剧情简介...',
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
              child: Text('添加海报', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)))),
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
      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(widget.movie.id, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(picked.path).copy(targetPath);
      if (mounted) setState(() => _editPosterPath = targetPath);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择海报失败: $e');
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
      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(widget.movie.id, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);
      if (mounted) setState(() => _editPosterPath = targetPath);
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
      final updated = widget.movie.copyWith(
        title: _titleCtrl.text.trim(),
        posterPath: _editPosterPath,
        releaseDate: _editReleaseDate,
        directors: _editDirectors,
        writers: _editWriters,
        actors: _editActors,
        genres: _editGenres,
        alternateTitles: _editAlternateTitles,
        summary: _summaryCtrl.text.trim(),
        rating: rating,
        status: _editStatus,
        category: _editCategory,
        watchDate: _editWatchDate,
        updatedAt: DateTime.now(),
      );
      await context.read<AppProvider>().updateMovie(updated);
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

  /// 标准样式
  Widget _buildStandardStyle(Movie movie, ColorScheme colors) {
    final topSafe = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
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
                        ? () => context.read<AppProvider>().selectMovie(null)
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
                        ? () => context.read<AppProvider>().selectMovie(null)
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
                  child: Icon(icons[i], size: 20, color: _detailStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(names[i], style: TextStyle(fontSize: 13, fontWeight: _detailStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
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
            onPressed: () => _showSharePoster(movie),
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
        label,
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
      provider.setEditRefresh(widget.movie.id);
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
              final provider = context.read<AppProvider>();
              await provider.removeMovie(widget.movie.id);
              if (!mounted || !context.mounted) return;
              if (widget.embedded) {
                Navigator.of(context).pop(); // close dialog
                provider.selectMovie(null);
              } else {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pop();
              }
              if (mounted && context.mounted) {
                ToastUtil.show(context, '已删除');
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
            child: const Text('删除'),
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
