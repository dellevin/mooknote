import 'package:flutter/material.dart';
import 'fade_in_local_image.dart';

/// 角色卡片横向预览组件
///
/// 在影视/书籍/游戏详情页的角色入口上方展示。
/// 空列表返回 SizedBox.shrink()，不占空间。
class CharacterPreviewSection extends StatelessWidget {
  final List<dynamic> characters;
  final void Function(dynamic character) onTap;
  final bool isOverlay;

  const CharacterPreviewSection({
    super.key,
    required this.characters,
    required this.onTap,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    if (characters.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final titleColor = isOverlay ? Colors.white : colors.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: titleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '角色',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0x00FFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: [0.0, 0.04, 0.96, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: characters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return _CharacterCard(
                    character: characters[index],
                    onTap: () => onTap(characters[index]),
                    isOverlay: isOverlay,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final dynamic character;
  final VoidCallback onTap;
  final bool isOverlay;

  const _CharacterCard({
    required this.character,
    required this.onTap,
    required this.isOverlay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = character.name as String;
    final role = character.role as String?;
    final aliases = character.aliases as List<String>;
    final tags = character.tags as List<String>;
    final description = character.description as String?;
    final imagePath = character.imagePath as String?;

    final cardColor = isOverlay
        ? Colors.white.withValues(alpha: 0.08)
        : colors.surfaceContainerHigh;
    final borderColor = isOverlay
        ? Colors.white.withValues(alpha: 0.12)
        : colors.outlineVariant;
    final primaryText = isOverlay ? Colors.white : colors.onSurface;
    final secondaryText = isOverlay
        ? Colors.white.withValues(alpha: 0.5)
        : colors.onSurface.withValues(alpha: 0.4);
    final tagText = isOverlay
        ? Colors.white.withValues(alpha: 0.7)
        : colors.onSurface.withValues(alpha: 0.6);
    final avatarBg = isOverlay
        ? Colors.white.withValues(alpha: 0.1)
        : colors.surfaceContainerHighest;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 第一行：头像 + 名称 + 角色定位
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: imagePath != null && imagePath.isNotEmpty
                      ? FadeInLocalImage(path: imagePath, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            name.isNotEmpty ? name.characters.first : '?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      if (role != null && role.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: secondaryText),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // 第二行：标签用 | 分割
            if (tags.isNotEmpty || aliases.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [...tags, ...aliases].join(' | '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: tagText, height: 1.3),
                ),
              ),
            // 第三行：简介，最多两行
            if (description != null && description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondaryText, height: 1.35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
