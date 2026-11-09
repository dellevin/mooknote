import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import 'app_overlay.dart';

/// 导出前的选项对话框：让用户选择是否把 WebDAV 密码、API Token 等凭证
/// 一并写入备份。备份页与首页导出入口共用。
class ExportOptionsDialog {
  /// 返回值：null = 取消导出；false = 普通导出（不含凭证）；true = 含敏感凭证导出
  static Future<bool?> show(BuildContext context) {
    var includeSensitive = false;
    return appDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: colors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text('导出备份'.tr,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  value: includeSensitive,
                  onChanged: (v) => setState(() => includeSensitive = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('同时备份账号密码和 API Token'.tr,
                      style: TextStyle(fontSize: 14, color: colors.onSurface)),
                  subtitle: Text('WebDAV 配置、在线搜索 Token'.tr,
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
                ),
                const SizedBox(height: 4),
                Text(
                  '勾选后备份将包含明文敏感信息，请勿通过微信、邮件等方式分享给他人'.tr,
                  style: TextStyle(fontSize: 12, color: colors.error, height: 1.5),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, includeSensitive),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: Text('开始导出'.tr),
              ),
            ],
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        );
      },
    );
  }
}
