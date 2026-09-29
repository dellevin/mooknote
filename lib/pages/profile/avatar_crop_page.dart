import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';

/// 头像裁剪页：圆形裁剪框，双指缩放 + 拖动调整位置
/// 确认后 Navigator.pop 返回 PNG 字节
class AvatarCropPage extends StatefulWidget {
  final Uint8List imageBytes;

  const AvatarCropPage({super.key, required this.imageBytes});

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final _cropController = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('调整头像'.tr),
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _cropController,
        withCircleUi: true,
        baseColor: Colors.black,
        maskColor: Colors.black.withValues(alpha: 0.6),
        onCropped: (result) {
          switch (result) {
            case CropSuccess(:final croppedImage):
              Navigator.pop(context, croppedImage);
            case CropFailure():
              if (mounted) setState(() => _cropping = false);
          }
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _cropController.cropCircle();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _cropping
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('确定'.tr,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
