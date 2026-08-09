import 'package:flutter/material.dart';
import 'fade_in_local_image.dart';

/// 人物头像。
///
/// 有照片时显示照片；无照片时根据名字哈希从调色板取色，
/// 显示首字占位（同一人物始终同色）。
class PersonAvatar extends StatelessWidget {
  final String? photoPath;
  final String name;
  final double size;
  final double fontSize;

  const PersonAvatar({
    super.key,
    required this.photoPath,
    required this.name,
    required this.size,
    required this.fontSize,
  });

  // 固定调色板：背景为该色的低透明度，文字为该色本身。
  static const _palette = <Color>[
    Color(0xFF4A90D9), // 蓝
    Color(0xFF009688), // 青
    Color(0xFFE91E63), // 粉
    Color(0xFF7E57C2), // 紫
    Color(0xFFFF7043), // 橙
    Color(0xFF4CAF50), // 绿
    Color(0xFFFF9800), // 琥珀
    Color(0xFF795548), // 棕
    Color(0xFF5C6BC0), // 靛
    Color(0xFFEC407A), // 玫红
  ];

  Color _colorFor(String name) {
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;
    final color = _colorFor(name);
    final initial = name.isNotEmpty ? name[0] : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasPhoto ? null : color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? FadeInLocalImage(path: photoPath, fit: BoxFit.cover)
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
    );
  }
}
