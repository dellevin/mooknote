import 'package:flutter/material.dart';
import '../pages/character/character_form_page.dart';
import 'fade_in_local_image.dart';
import '../widgets/app_overlay.dart';

/// 角色信息底部弹窗
///
/// 展示角色详情，提供编辑入口。
/// [entityType] = 'movie' / 'book' / 'game'
/// [entityId] = 所属作品 ID
/// [character] = MovieCharacter / BookCharacter / GameCharacter
class CharacterInfoSheet extends StatefulWidget {
  final String entityType;
  final String entityId;
  final dynamic character;

  const CharacterInfoSheet({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.character,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String entityType,
    required String entityId,
    required dynamic character,
  }) {
    return appModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => CharacterInfoSheet(
        entityType: entityType,
        entityId: entityId,
        character: character,
      ),
    );
  }

  @override
  State<CharacterInfoSheet> createState() => _CharacterInfoSheetState();
}

class _CharacterInfoSheetState extends State<CharacterInfoSheet> {
  bool _summaryExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final c = widget.character;
    final name = c.name as String;
    final role = c.role as String?;
    final aliases = c.aliases as List<String>;
    final tags = c.tags as List<String>;
    final description = c.description as String?;
    final imagePath = c.imagePath as String?;

    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽条
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildHeader(name, role, imagePath, colors),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (aliases.isNotEmpty)
                        _buildInfoRow('别名', aliases.join('、'), colors),
                      if (tags.isNotEmpty)
                        _buildInfoRow('标签', tags.join(' | '), colors),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildSectionTitle('简介', colors),
                        const SizedBox(height: 8),
                        _buildSummary(description, colors),
                      ],
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

  Widget _buildHeader(String name, String? role, String? imagePath, ColorScheme colors) {
    final hasImage = imagePath != null && imagePath.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasImage
              ? FadeInLocalImage(path: imagePath, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    name.isNotEmpty ? name.characters.first : '?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (role != null && role.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  role,
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => CharacterFormPage(
                  entityType: widget.entityType,
                  entityId: widget.entityId,
                  character: widget.character,
                ),
              ),
            );
            if (result == true && mounted) {
              Navigator.pop(context, true);
            }
          },
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('编辑', style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colors) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(String summary, ColorScheme colors) {
    const int previewLimit = 80;
    final needsToggle = summary.length > previewLimit;
    final displayText = _summaryExpanded || !needsToggle
        ? summary
        : '${summary.substring(0, previewLimit)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText, style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.7)),
        if (needsToggle) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Text(
              _summaryExpanded ? '收起' : '展开',
              style: TextStyle(fontSize: 12, color: colors.primary),
            ),
          ),
        ],
      ],
    );
  }
}
