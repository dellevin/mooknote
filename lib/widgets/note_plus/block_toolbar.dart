import 'package:flutter/material.dart';
import '../../models/note_plus_models.dart';

/// AppFlowy 风格的格式化工具栏
///
/// 样式参考 AppFlowy tool_bar.dart:
/// - 高度 36px（iconSize 18 * 2）
/// - 背景 #f2f2f2
/// - 按钮 18px 图标，~32px 宽
/// - 切换态：#00bcf0 背景 + 白色图标
class BlockToolbar extends StatelessWidget {
  final NoteBlockType currentBlockType;
  final Set<InlineFormatType> activeFormats;
  final void Function(InlineFormatType) onFormatToggle;
  final void Function(NoteBlockType) onBlockTypeChange;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const BlockToolbar({
    super.key,
    required this.currentBlockType,
    required this.activeFormats,
    required this.onFormatToggle,
    required this.onBlockTypeChange,
    required this.onUndo,
    required this.onRedo,
  });

  static const double _iconSize = 18;
  static const double _buttonWidth = 32;
  static const Color _bgColor = Color(0xFFF2F2F2);
  static const Color _toggledColor = Color(0xFF00BCF0);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: const BoxDecoration(color: _bgColor),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // 撤销/重做
          _iconButton(Icons.undo_outlined, onUndo, false),
          _iconButton(Icons.redo_outlined, onRedo, false),
          _divider(),
          // 内联格式
          _iconButton(Icons.format_bold, () => onFormatToggle(InlineFormatType.bold),
              activeFormats.contains(InlineFormatType.bold)),
          _iconButton(Icons.format_italic, () => onFormatToggle(InlineFormatType.italic),
              activeFormats.contains(InlineFormatType.italic)),
          _iconButton(Icons.format_underlined, () => onFormatToggle(InlineFormatType.underline),
              activeFormats.contains(InlineFormatType.underline)),
          _iconButton(Icons.format_strikethrough, () => onFormatToggle(InlineFormatType.strikethrough),
              activeFormats.contains(InlineFormatType.strikethrough)),
          _divider(),
          // 标题
          _headingButton('H1', NoteBlockType.heading1),
          _headingButton('H2', NoteBlockType.heading2),
          _headingButton('H3', NoteBlockType.heading3),
          _divider(),
          // 列表
          _iconButton(Icons.format_list_numbered, () => onBlockTypeChange(NoteBlockType.numberedList),
              currentBlockType == NoteBlockType.numberedList),
          _iconButton(Icons.format_list_bulleted, () => onBlockTypeChange(NoteBlockType.bulletList),
              currentBlockType == NoteBlockType.bulletList),
          _iconButton(Icons.check_box_outlined, () => onBlockTypeChange(NoteBlockType.checklist),
              currentBlockType == NoteBlockType.checklist),
          _divider(),
          // 代码/引用
          _iconButton(Icons.code, () => onFormatToggle(InlineFormatType.inlineCode),
              activeFormats.contains(InlineFormatType.inlineCode)),
          _iconButton(Icons.format_quote, () => onBlockTypeChange(NoteBlockType.quote),
              currentBlockType == NoteBlockType.quote),
          // 块类型选择
          _divider(),
          _blockTypeSelector(context, colors),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, bool isToggled) {
    return SizedBox(
      width: _buttonWidth,
      child: Material(
        color: isToggled ? _toggledColor : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          hoverColor: isToggled ? _toggledColor : const Color(0xFFE0E0E0),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Icon(icon,
                size: _iconSize,
                color: isToggled ? Colors.white : const Color(0xFF333333)),
          ),
        ),
      ),
    );
  }

  Widget _headingButton(String label, NoteBlockType type) {
    final isToggled = currentBlockType == type;
    return SizedBox(
      width: _buttonWidth,
      child: Material(
        color: isToggled ? _toggledColor : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: () => onBlockTypeChange(type),
          borderRadius: BorderRadius.circular(2),
          hoverColor: isToggled ? _toggledColor : const Color(0xFFE0E0E0),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isToggled ? Colors.white : const Color(0xFF333333),
                )),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      color: const Color(0xFFE0E0E0),
    );
  }

  Widget _blockTypeSelector(BuildContext context, ColorScheme colors) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentBlockType.label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF4F4F4F))),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF828282)),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...NoteBlockType.values.map((type) {
                final isSelected = type == currentBlockType;
                return ListTile(
                  dense: true,
                  leading: Icon(_getBlockIcon(type), size: 20,
                      color: isSelected ? _toggledColor : colors.onSurface.withValues(alpha: 0.5)),
                  title: Text(type.label,
                      style: TextStyle(fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? _toggledColor : colors.onSurface)),
                  trailing: isSelected
                      ? const Icon(Icons.check, size: 18, color: _toggledColor)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    onBlockTypeChange(type);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  IconData _getBlockIcon(NoteBlockType type) {
    switch (type) {
      case NoteBlockType.paragraph:
        return Icons.notes;
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return Icons.title;
      case NoteBlockType.bulletList:
        return Icons.format_list_bulleted;
      case NoteBlockType.numberedList:
        return Icons.format_list_numbered;
      case NoteBlockType.checklist:
        return Icons.check_box_outlined;
      case NoteBlockType.quote:
        return Icons.format_quote;
      case NoteBlockType.codeBlock:
        return Icons.code;
      case NoteBlockType.divider:
        return Icons.horizontal_rule;
    }
  }
}
