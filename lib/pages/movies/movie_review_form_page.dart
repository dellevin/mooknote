import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../data/gallery/image_asset_dao.dart';
import '../../providers/app_provider.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/image_grid_editor.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/edit_sheets.dart';

/// 添加/编辑影评页面
class MovieReviewFormPage extends StatefulWidget {
  final String movieId;
  final MovieReview? review;

  const MovieReviewFormPage({super.key, required this.movieId, this.review});

  @override
  State<MovieReviewFormPage> createState() => _MovieReviewFormPageState();
}

class _MovieReviewFormPageState extends State<MovieReviewFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contentController;
  late TextEditingController _reviewerController;
  late TextEditingController _sourceController;
  late int _reviewType;
  late DateTime _reviewDate;
  late List<String> _images;
  String? _tempReviewId; // 新建评价时选图用的临时ID（保存时移到正式ID目录）

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.review?.content ?? '');
    _reviewerController = TextEditingController(text: widget.review?.reviewer ?? '');
    _sourceController = TextEditingController(text: widget.review?.source ?? '');
    _reviewType = widget.review?.reviewType ?? 1;
    _reviewDate = widget.review?.reviewDate ?? DateTime.now();
    _images = List<String>.from(widget.review?.images ?? []);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _reviewerController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Movie? _getMovie() {
    return context.read<AppProvider>().movies.where((m) => m.id == widget.movieId).firstOrNull;
  }

  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.review != null;
    final movie = _getMovie();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(isEdit ? '编辑影评'.tr : '写影评'.tr),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 电影信息卡片 ──────────────────
                    if (movie != null) _buildMovieCard(movie, colors),
                    const SizedBox(height: 20),

                    // ── 类型选择 ──────────────────────
                    Text('影评类型'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    _buildTypeSelector(colors),
                    const SizedBox(height: 20),

                    // ── 元信息 ────────────────────────
                    _buildMetaField(
                      icon: Icons.person_outline,
                      hint: '评论人（选填）'.tr,
                      controller: _reviewerController,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _buildMetaField(
                      icon: Icons.link,
                      hint: '来源（选填）'.tr,
                      controller: _sourceController,
                      colors: colors,
                    ),
                    const SizedBox(height: 12),
                    _buildDateField(colors),
                    const SizedBox(height: 20),

                    // ── 评论内容 ──────────────────────
                    Text('评论内容'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    _buildContentField(colors),
                    const SizedBox(height: 20),

                    // ── 图片 ──────────────────────────
                    Text('图片'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.5))),
                    const SizedBox(height: 8),
                    ImageGridEditor(
                      images: _images,
                      onAdd: _pickImage,
                      onRemove: (i) => setState(() => _images.removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),

            // ── 底部保存按钮 ──────────────────────
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saveReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isEdit ? '更新影评'.tr : '保存影评'.tr,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 电影信息卡片
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMovieCard(Movie movie, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: colors.outlineVariant,
            ),
            clipBehavior: Clip.antiAlias,
            child: movie.posterPath != null
                ? FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover,
                    errorWidget: Icon(Icons.movie_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25)))
                : Icon(Icons.movie_outlined, size: 24, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movie.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (movie.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFFFB800)),
                    const SizedBox(width: 2),
                    Text('${movie.rating}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 类型选择器（分段按钮）
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTypeSelector(ColorScheme colors) {
    return SegmentedButton<int>(
      segments: [
        ButtonSegment(value: 1, label: Text('短评'.tr), icon: const Icon(Icons.short_text)),
        ButtonSegment(value: 2, label: Text('长评'.tr), icon: const Icon(Icons.menu_book)),
      ],
      selected: {_reviewType},
      onSelectionChanged: (v) => setState(() => _reviewType = v.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.primary;
          return colors.surfaceContainerHighest;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.onPrimary;
          return colors.onSurface.withValues(alpha: 0.6);
        }),
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colors.onPrimary;
          return colors.onSurface.withValues(alpha: 0.4);
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 元信息输入
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMetaField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    required ColorScheme colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 影评日期选择
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDateField(ColorScheme colors) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePickerSheet(
          context: context,
          title: '影评日期'.tr,
          initial: _reviewDate,
        );
        if (!mounted) return;
        if (picked != null) setState(() => _reviewDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
            const SizedBox(width: 10),
            Text('影评日期'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
            const Spacer(),
            Text(
              '${_reviewDate.year}.${_reviewDate.month.toString().padLeft(2, '0')}.${_reviewDate.day.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 内容输入区 + 字数统计
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildContentField(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _contentController,
            maxLines: 10,
            minLines: 6,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.7),
            decoration: InputDecoration(
              hintText: '写下你的影评...'.tr,
              hintStyle: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.25)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '请输入评论内容'.tr;
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14, bottom: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '{n} 字'.trf({'n': _contentController.text.length}),
                style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 图片选择
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _pickImage() async {
    try {
      final files = await pickLocalImages(context);
      if (!mounted || files.isEmpty) return;

      // 编辑模式用现有ID；新建模式用临时ID（保存时移到正式ID目录）
      final String reviewId;
      if (widget.review != null) {
        reviewId = widget.review!.id;
      } else {
        reviewId = _tempReviewId ?? const Uuid().v4();
        _tempReviewId = reviewId;
      }

      // 复制图片到应用目录: images/reviews/{reviewId}/{fileName}
      final targetDir = await ImagePathHelper.instance.getReviewImagesDir(reviewId);
      await ImagePathHelper.instance.ensureDirExists(targetDir);

      final newPaths = <String>[];
      for (final file in files) {
        final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${newPaths.length}$ext';
        final targetPath = p.join(targetDir, fileName);
        await file.copy(targetPath);
        newPaths.add(targetPath);
      }

      if (newPaths.isNotEmpty && mounted) {
        setState(() => _images.addAll(newPaths));
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: {e}'.trf({'e': e}));
    }
  }

  /// 新建保存时把图片从临时ID目录移到正式ID目录
  Future<List<String>> _moveImagesToNewId(String oldId, String newId) async {
    final List<String> newPaths = [];
    final newDir = await ImagePathHelper.instance.getReviewImagesDir(newId);

    for (final imagePath in _images) {
      final normalizedPath = imagePath.replaceAll('\\', '/');
      if (normalizedPath.contains('/reviews/$oldId/')) {
        final fileName = p.basename(imagePath);
        final newPath = p.join(newDir, fileName);
        await ImagePathHelper.instance.ensureDirExists(newDir);
        final sourceFile = File(imagePath);
        if (await sourceFile.exists()) {
          await sourceFile.rename(newPath);
          await ImageAssetDao().onFileMoved(imagePath, newPath);
          newPaths.add(newPath);
        }
      } else {
        newPaths.add(imagePath);
      }
    }

    try {
      await ImagePathHelper.instance.deleteReviewImages(oldId);
    } catch (_) {}

    return newPaths;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 保存
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _saveReview() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();
    try {
    final now = DateTime.now();

    if (widget.review == null) {
      final reviewId = const Uuid().v4();
      List<String> finalImages = _images;
      if (_images.isNotEmpty && _tempReviewId != null) {
        finalImages = await _moveImagesToNewId(_tempReviewId!, reviewId);
      }
      final newReview = MovieReview(
        id: reviewId,
        movieId: widget.movieId,
        content: _contentController.text.trim(),
        reviewer: _reviewerController.text.trim(),
        source: _sourceController.text.trim(),
        reviewType: _reviewType,
        reviewDate: _reviewDate,
        images: finalImages,
        createdAt: now,
        updatedAt: now,
      );
      await provider.addMovieReview(newReview);
    } else {
      final updatedReview = widget.review!.copyWith(
        content: _contentController.text.trim(),
        reviewer: _reviewerController.text.trim(),
        source: _sourceController.text.trim(),
        reviewType: _reviewType,
        reviewDate: _reviewDate,
        images: _images,
        updatedAt: now,
      );
      await provider.updateMovieReview(updatedReview);
    }

    if (!mounted) return;
    ToastUtil.show(context, widget.review == null ? '添加成功'.tr : '更新成功'.tr);
    Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: {e}'.trf({'e': e}));
    }
  }
}
