import 'package:flutter/material.dart';
import '../data/gallery/image_asset_dao.dart';
import '../l10n/app_strings.dart';
import 'app_overlay.dart';

/// 图片重命名对话框 —— 图库查看页 / 海报画廊等长按菜单共用
class ImageRenameDialog {
  /// 弹出重命名对话框。返回保存后的名称（空串表示已清除恢复默认），取消返回 null。
  static Future<String?> show(BuildContext context, String absImagePath) async {
    final logicalPath = ImageAssetDao.toLogicalPath(absImagePath);
    final current = await ImageAssetDao().getTitle(logicalPath);
    if (!context.mounted) return null;
    final controller = TextEditingController(text: current ?? '');
    // 注意：控制器不要手动 dispose，对话框关闭动画期间 TextField 仍在树中
    return appDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('重命名'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: '输入图片名称，留空恢复默认'.tr,
              hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('保存'.tr),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    ).then((saved) async {
      if (saved == null) return null;
      await ImageAssetDao().rename(logicalPath, saved);
      return saved;
    });
  }
}
