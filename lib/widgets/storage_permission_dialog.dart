import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import 'app_overlay.dart';

/// 存储权限用途说明弹窗。
/// Android 11+ 的"所有文件访问"只能跳系统设置页开启，跳转前先用本弹窗
/// 向用户解释为什么需要该权限。返回 true 表示用户确认前往授权，null/false 表示取消。
class StoragePermissionDialog {
  static Future<bool?> show(BuildContext context) {
    return appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_open, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('需要文件访问权限'.tr,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ),
            ],
          ),
          content: Text(
            '备份功能需要"所有文件访问"权限，用于把备份压缩包写入手机的 Download/mooknote 目录，并在恢复备份时读取备份文件。\n\n点击"去授权"后将跳转到系统设置页，请在列表中找到 MookNote 并允许管理所有文件。'.tr,
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.65), height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('暂不'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('去授权'.tr),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }
}
