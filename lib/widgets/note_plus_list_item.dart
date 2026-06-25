import 'package:flutter/material.dart';
import '../../models/note_plus_models.dart';

/// AppFlowy 风格的文件树列表项
///
/// 匹配 AppFlowy ViewSectionItem 的样式：
/// - 固定高度 26px
/// - 16px 图标 + 文字
/// - 12px 字号
/// - hover 时显示操作按钮
class NotePlusTreeItem extends StatefulWidget {
  final NotePlusDocument doc;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const NotePlusTreeItem({
    super.key,
    required this.doc,
    required this.isSelected,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  State<NotePlusTreeItem> createState() => _NotePlusTreeItemState();
}

class _NotePlusTreeItemState extends State<NotePlusTreeItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSelected = widget.isSelected;
    final showActions = _isHovering || isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.only(left: 22, right: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.08)
                : _isHovering
                    ? colors.onSurface.withValues(alpha: 0.04)
                    : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // 文档图标
              SizedBox(
                width: 16,
                height: 16,
                child: Icon(
                  _getBlockIcon(widget.doc),
                  size: 14,
                  color: isSelected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 2),
              // 文档标题
              Expanded(
                child: Text(
                  widget.doc.title.isEmpty ? '无标题' : widget.doc.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                    color: isSelected
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.75),
                  ),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                ),
              ),
              // hover 操作按钮
              if (showActions)
                _buildActions(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onRename != null)
          _ActionButton(
            icon: Icons.edit_outlined,
            onTap: widget.onRename!,
            colors: colors,
          ),
        if (widget.onDelete != null)
          _ActionButton(
            icon: Icons.delete_outline,
            onTap: widget.onDelete!,
            colors: colors,
          ),
      ],
    );
  }

  IconData _getBlockIcon(NotePlusDocument doc) {
    // 根据第一个块的类型显示图标
    if (doc.blocks.isEmpty) return Icons.description_outlined;
    final firstType = doc.blocks.first.type;
    switch (firstType) {
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return Icons.title;
      case NoteBlockType.checklist:
        return Icons.check_box_outlined;
      case NoteBlockType.codeBlock:
        return Icons.code;
      case NoteBlockType.quote:
        return Icons.format_quote;
      default:
        return Icons.description_outlined;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme colors;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Icon(icon, size: 14,
            color: colors.onSurface.withValues(alpha: 0.4)),
      ),
    );
  }
}
