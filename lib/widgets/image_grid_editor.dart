import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import '../utils/image_saver.dart';
import 'app_overlay.dart';
import 'fade_in_local_image.dart';
import 'image_rename_dialog.dart';

/// 评价列表卡片封面：有图时显示首图（4:3 裁剪），多图右下角带数量角标
class ReviewImageThumb extends StatelessWidget {
  final List<String> images;

  const ReviewImageThumb({super.key, required this.images});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.expand(
              child: FadeInLocalImage(path: images.first, fit: BoxFit.cover),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 10, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('${images.length}',
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 图片网格编辑器（影评/书评/游戏评价共用）
/// 点按预览（预览中长按可保存），长按删除；readOnly 时仅展示+预览
class ImageGridEditor extends StatelessWidget {
  final List<String> images;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;
  final bool readOnly;

  const ImageGridEditor({
    super.key,
    required this.images,
    this.onAdd,
    this.onRemove,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = ((constraints.maxWidth - 10 * 2) / 3).clamp(60.0, 120.0);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (int i = 0; i < images.length; i++) _buildImageItem(context, i, size),
            if (!readOnly && onAdd != null) _buildAddButton(context, size),
          ],
        );
      },
    );
  }

  Widget _buildImageItem(BuildContext context, int index, double size) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showImagePreview(context, index),
      onLongPress: readOnly ? null : () => _showDeleteImageDialog(context, index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outline, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: FadeInLocalImage(path: images[index], fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, double size) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.outline, width: 0.5),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 28,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  void _showImagePreview(BuildContext context, int index) {
    appDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        onLongPress: () =>
            ImageSaver.showSaveFromFileSheet(
              images[index],
              context: context,
              extraAction: (
                icon: Icons.edit_outlined,
                label: '重命名'.tr,
                onTap: () => ImageRenameDialog.show(context, images[index]),
              ),
            ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: FadeInLocalImage(path: images[index], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteImageDialog(BuildContext context, int index) {
    appDialog(
      context: context,
      builder: (dialogCtx) {
        final colors = Theme.of(dialogCtx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            '确认删除'.tr,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: Text(
            '确定要删除这张图片吗？此操作不可恢复。'.tr,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurface.withValues(alpha: 0.6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('取消'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                onRemove?.call(index);
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('删除'.tr),
            ),
          ],
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }
}
