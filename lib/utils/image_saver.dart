import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
      _toast(messenger, '原文件不存在');
      return;
    }
    if (!context.mounted) return;
    _showSheet(
      context: context,
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
      onConfirm: () => saveFromBytes(bytes, originalPath: originalPath, context: context),
    );
  }

  static void _showSheet({
    required BuildContext context,
    required Future<void> Function() onConfirm,
  }) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32, height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  onConfirm();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.download_outlined, size: 20, color: colors.primary),
                      const SizedBox(width: 12),
                      const Text('下载图片'),
                    ],
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pop(sheetCtx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.close, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 12),
                      Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
      _toast(messenger, '原文件不存在');
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
      _toast(messenger, '存储权限被拒绝');
      return false;
    }
    try {
      final dir = await _getSaveDir();
      final target = File(p.join(dir.path, fileName));
      await target.writeAsBytes(bytes);
      _toast(messenger, '已保存到 ${dir.path}');
      return true;
    } catch (e) {
      _toast(messenger, '保存失败：$e');
      return false;
    }
  }

  static void _toast(ScaffoldMessengerState? messenger, String msg) {
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }
}
