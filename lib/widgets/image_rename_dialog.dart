import 'package:flutter/material.dart';
import '../data/gallery/image_asset_dao.dart';
import '../l10n/app_strings.dart';
import '../services/cloud/cloud_explore_service.dart';
import '../services/cloud/cloud_image_upload.dart';
import '../utils/toast_util.dart';
import 'app_overlay.dart';

/// 图片重命名对话框 —— 图库查看页 / 海报画廊等长按菜单共用
class ImageRenameDialog {
  /// 弹出重命名对话框。返回保存后的名称（空串表示已清除恢复默认），取消返回 null。
  static Future<String?> show(BuildContext context, String absImagePath) async {
    // 云模式图片是 OSS URL，本地 image_assets 表无法跨设备同步，走专用云端接口
    if (CloudImageUpload.isRemoteUrl(absImagePath)) {
      return showCloud(context, absImagePath, null);
    }
    final logicalPath = ImageAssetDao.toLogicalPath(absImagePath);
    final current = await ImageAssetDao().getTitle(logicalPath);
    if (!context.mounted) return null;
    final saved = await prompt(context, current);
    if (saved == null) return null;
    try {
      await ImageAssetDao().rename(logicalPath, saved);
    } catch (_) {
      if (context.mounted) ToastUtil.show(context, '重命名失败，请稍后重试'.tr);
      return null;
    }
    return saved;
  }

  /// 云端图片重命名：自定义名写入服务端 mn_image_assets，按逻辑路径关联，可跨设备同步。
  /// [remoteUrl] 为 OSS lite URL；[currentTitle] 为当前自定义名（无则传 null）。
  static Future<String?> showCloud(
      BuildContext context, String remoteUrl, String? currentTitle) async {
    final logicalPath = CloudExploreService.logicalPathFromUrl(remoteUrl);
    if (logicalPath == null) {
      ToastUtil.show(context, '重命名失败，请稍后重试'.tr);
      return null;
    }
    final saved = await prompt(context, currentTitle);
    if (saved == null) return null;
    try {
      await CloudExploreService.instance.saveImageAsset(logicalPath, saved);
    } catch (_) {
      if (context.mounted) ToastUtil.show(context, '重命名失败，请稍后重试'.tr);
      return null;
    }
    return saved;
  }

  /// 仅弹出输入框并返回用户输入（空串表示清除，取消为 null），不做任何持久化
  static Future<String?> prompt(BuildContext context, String? currentTitle) {
    final controller = TextEditingController(text: currentTitle ?? '');
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
    );
  }
}
