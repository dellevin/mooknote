import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../l10n/app_strings.dart';
import '../pages/profile/avatar_crop_page.dart';
import '../widgets/app_overlay.dart';
import 'image_normalizer.dart';
import 'image_path_helper.dart';
import 'toast_util.dart';
import 'user_prefs.dart';

/// 用户头像的选择 / 裁剪 / 保存 / 移除共享逻辑。
/// 个人中心、设置-个人信息、侧边栏三处入口复用，避免重复实现。
class AvatarHelper {
  AvatarHelper._();

  static final ImagePicker _picker = ImagePicker();

  /// 选图 → PNG 归一化 → 圆形裁剪 → 保存到 avatars 目录 → 写入 UserPrefs。
  /// 成功返回新头像路径；用户取消返回 null；失败时 toast 提示并返回 null。
  static Future<String?> pickAndSave(BuildContext context) async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return null;
      // 先读取原图字节，归一化为 PNG（兼容 HEIC 等格式）后进入裁剪页
      final raw = await File(pickedFile.path).readAsBytes();
      final bytes = await normalizeToPng(raw);
      if (bytes == null) {
        if (context.mounted) {
          ToastUtil.show(context, '无法识别该图片，请换一张 JPG/PNG 图片'.tr);
        }
        return null;
      }
      if (!context.mounted) return null;
      final Uint8List? cropped = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => AvatarCropPage(imageBytes: bytes)),
      );
      if (cropped == null) return null;
      final appDirPath = await ImagePathHelper.getAppDir();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedPath = path.join(appDirPath, 'avatars', fileName);
      final avatarDir = Directory(path.join(appDirPath, 'avatars'));
      if (!await avatarDir.exists()) await avatarDir.create(recursive: true);
      await File(savedPath).writeAsBytes(cropped);
      final oldPath = UserPrefs().avatarPath;
      await UserPrefs().setAvatarPath(savedPath);
      await ImagePathHelper.deleteOwnedImage(oldPath, 'avatars');
      return savedPath;
    } catch (e) {
      if (context.mounted) ToastUtil.show(context, '选择头像失败'.tr);
      return null;
    }
  }

  /// 头像操作底部弹窗（从文件选择 / 移除头像）。
  /// 任何成功变更（更换或移除）后调用 [onChanged]，由调用方负责刷新界面。
  static Future<void> showActionSheet(
    BuildContext context, {
    required VoidCallback onChanged,
  }) async {
    final colors = Theme.of(context).colorScheme;
    final hasAvatar = UserPrefs().avatarPath?.isNotEmpty ?? false;
    await appModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2))),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('更换头像'.tr,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)))),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.folder_outlined,
                    size: 20, color: colors.onSurface.withValues(alpha: 0.6))),
            title: Text('从文件管理器选择'.tr,
                style: TextStyle(fontSize: 14, color: colors.onSurface)),
            trailing: Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () async {
              Navigator.pop(ctx);
              final saved = await pickAndSave(context);
              if (saved != null) onChanged();
            },
          ),
          if (hasAvatar) ...[
            Divider(
                height: 0.5,
                indent: 24,
                endIndent: 24,
                color: colors.outlineVariant),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.delete_outline,
                      size: 20, color: colors.error)),
              title: Text('移除头像'.tr,
                  style: TextStyle(fontSize: 14, color: colors.error)),
              trailing: Icon(Icons.chevron_right,
                  color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () async {
                Navigator.pop(ctx);
                final oldPath = UserPrefs().avatarPath;
                await UserPrefs().clearAvatarPath();
                await ImagePathHelper.deleteOwnedImage(oldPath, 'avatars');
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
