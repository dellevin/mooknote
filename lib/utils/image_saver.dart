import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_strings.dart';
import '../widgets/app_overlay.dart';

/// 图片保存工具 —— 将图片复制/写入到 /sdcard/Pictures/mooknote/
class ImageSaver {
  /// 请求存储权限，返回是否已获取
  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.manageExternalStorage.status;
    if (status.isGranted) return true;
    status = await Permission.manageExternalStorage.request();
    if (status.isGranted) return true;
    status = await Permission.storage.status;
    if (status.isGranted) return true;
    status = await Permission.storage.request();
    return status.isGranted;
  }

  /// 获取保存目录
  static Future<Directory> _getSaveDir() async {
    if (Platform.isAndroid) {
      final dir = Directory('/sdcard/Pictures/mooknote');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    // 非 Android 平台使用临时目录
    return await getTemporaryDirectory();
  }

  /// 生成带时间戳的文件名，保留原扩展名
  static String _buildFileName(String? originalPath, {String defaultExt = 'png'}) {
    final ts = DateTime.now().toLocal();
    final stamp = '${ts.year}${_pad(ts.month)}${_pad(ts.day)}_${_pad(ts.hour)}${_pad(ts.minute)}${_pad(ts.second)}';
    String ext = defaultExt;
    if (originalPath != null && originalPath.isNotEmpty) {
      final parsed = p.extension(originalPath).toLowerCase().replaceAll('.', '');
      if (parsed.isNotEmpty) ext = parsed;
    }
    return 'mooknote_$stamp.$ext';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// 长按保存的统一入口：弹出底部确认框，点击「下载」后才执行保存
  static Future<void> showSaveFromFileSheet(
    String sourcePath, {
    required BuildContext context,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final src = File(sourcePath);
    if (!await src.exists()) {
      _toast(messenger, '原文件不存在'.tr);
      return;
    }
    if (!context.mounted) return;
    _showSheet(
      context: context,
      preview: FileImage(src),
      onConfirm: () => saveFromFile(sourcePath, context: context),
    );
  }

  /// 长按保存（字节）的统一入口：弹出底部确认框，点击「下载」后才执行保存
  static Future<void> showSaveFromBytesSheet(
    Uint8List bytes, {
    String? originalPath,
    required BuildContext context,
  }) async {
    _showSheet(
      context: context,
      preview: MemoryImage(bytes),
      onConfirm: () => saveFromBytes(bytes, originalPath: originalPath, context: context),
    );
  }

  static void _showSheet({
    required BuildContext context,
    required Future<void> Function() onConfirm,
    ImageProvider? preview,
  }) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 3,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(
                color: colors.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            // 图片预览缩略图
            if (preview != null)
              Container(
                width: 88, height: 88,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.outlineVariant, width: 0.8),
                  image: DecorationImage(image: preview, fit: BoxFit.cover),
                ),
              ),
            // 操作组
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _sheetAction(
                    colors,
                    icon: Icons.download_outlined,
                    label: '下载图片'.tr,
                    color: colors.primary,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      onConfirm();
                    },
                  ),
                  Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: 56,
                      color: colors.outlineVariant.withValues(alpha: 0.3)),
                  _sheetAction(
                    colors,
                    icon: Icons.close,
                    label: '取消'.tr,
                    color: colors.onSurface.withValues(alpha: 0.6),
                    onTap: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  static Widget _sheetAction(
    ColorScheme colors, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: color))),
          ],
        ),
      ),
    );
  }

  /// 保存本地文件路径的图片，返回是否成功
  static Future<bool> saveFromFile(
    String sourcePath, {
    BuildContext? context,
  }) async {
    final messenger = context != null ? ScaffoldMessenger.maybeOf(context) : null;
    final src = File(sourcePath);
    if (!await src.exists()) {
      _toast(messenger, '原文件不存在'.tr);
      return false;
    }
    return _saveBytes(await src.readAsBytes(), _buildFileName(sourcePath), messenger);
  }

  /// 保存内存中的图片字节
  static Future<bool> saveFromBytes(
    Uint8List bytes, {
    String? originalPath,
    BuildContext? context,
  }) async {
    final messenger = context != null ? ScaffoldMessenger.maybeOf(context) : null;
    return _saveBytes(bytes, _buildFileName(originalPath), messenger);
  }

  static Future<bool> _saveBytes(Uint8List bytes, String fileName, ScaffoldMessengerState? messenger) async {
    if (!await requestPermission()) {
      _toast(messenger, '存储权限被拒绝'.tr);
      return false;
    }
    try {
      final dir = await _getSaveDir();
      final target = File(p.join(dir.path, fileName));
      await target.writeAsBytes(bytes);
      _toast(messenger, '已保存到 {path}'.trf({'path': dir.path}));
      return true;
    } catch (e) {
      _toast(messenger, '保存失败：{e}'.trf({'e': e}));
      return false;
    }
  }

  static void _toast(ScaffoldMessengerState? messenger, String msg) {
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }
}
