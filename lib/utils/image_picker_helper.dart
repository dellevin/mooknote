import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 多选本地图片：移动端走相册（wechat_assets_picker）；
/// Windows 走系统文件选择器（wechat_assets_picker 依赖的 photo_manager 无 Windows 实现）
Future<List<File>> pickLocalImages(BuildContext context) async {
  if (Platform.isWindows) {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return [];
    return result.paths.whereType<String>().map((path) => File(path)).toList();
  }
  final List<AssetEntity>? assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      requestType: RequestType.image, // 只允许选择图片，不能选择视频
    ),
  );
  if (assets == null) return [];
  final files = <File>[];
  for (final asset in assets) {
    final file = await asset.file;
    if (file != null) files.add(file);
  }
  return files;
}
