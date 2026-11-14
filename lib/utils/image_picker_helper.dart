import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 多选本地图片：走系统相册（wechat_assets_picker）
Future<List<File>> pickLocalImages(BuildContext context) async {
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

/// 单选本地图片：头像等只需一张图的场景，maxAssets=1 选一张即自动确认；取消返回 null
Future<File?> pickSingleLocalImage(BuildContext context) async {
  final List<AssetEntity>? assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      requestType: RequestType.image,
      maxAssets: 1,
    ),
  );
  if (assets == null || assets.isEmpty) return null;
  return assets.first.file;
}
