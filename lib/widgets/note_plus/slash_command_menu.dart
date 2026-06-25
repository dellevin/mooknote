import 'package:flutter/material.dart';
import '../../models/note_plus_models.dart';

/// 斜杠命令菜单
///
/// 输入 `/` 后弹出，显示可插入的 block 类型列表。
/// 支持按中文关键词过滤。
class SlashCommandMenu extends StatefulWidget {
  final String query;
  final void Function(NoteBlockType) onSelect;
  final VoidCallback onDismiss;

  const SlashCommandMenu({
    super.key,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<SlashCommandMenu> createState() => _SlashCommandMenuState();
}

class _SlashCommandMenuState extends State<SlashCommandMenu> {
  int _selectedIndex = 0;

  static const _menuItems = [
    _MenuItem(NoteBlockType.paragraph, Icons.notes, '正文', '段落'),
    _MenuItem(NoteBlockType.heading1, Icons.title, '标题1', '大标题'),
    _MenuItem(NoteBlockType.heading2, Icons.title, '标题2', '中标题'),
    _MenuItem(NoteBlockType.heading3, Icons.title, '标题3', '小标题'),
    _MenuItem(NoteBlockType.bulletList, Icons.format_list_bulleted, '无序列表', '圆点列表'),
    _MenuItem(NoteBlockType.numberedList, Icons.format_list_numbered, '有序列表', '数字列表'),
    _MenuItem(NoteBlockType.checklist, Icons.check_box_outlined, '待办', '清单'),
    _MenuItem(NoteBlockType.quote, Icons.format_quote, '引用', '引述'),
    _MenuItem(NoteBlockType.codeBlock, Icons.code, '代码块', '源码'),
    _MenuItem(NoteBlockType.divider, Icons.horizontal_rule, '分割线', '分隔'),
  ];

  List<_MenuItem> get _filtered {
    if (widget.query.isEmpty) return _menuItems;
    final q = widget.query.toLowerCase();
    return _menuItems.where((item) {
      return item.label.toLowerCase().contains(q) ||
          item.keywords.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void didUpdateWidget(SlashCommandMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      final items = _filtered;
      if (_selectedIndex >= items.length) {
        _selectedIndex = items.isEmpty ? 0 : items.length - 1;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = _filtered;

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Text('无匹配项',
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = index == _selectedIndex;

          return InkWell(
            onTap: () => widget.onSelect(item.type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.08)
                  : null,
              child: Row(
                children: [
                  Icon(item.icon, size: 20,
                      color: isSelected
                          ? colors.primary
                          : colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                          color: isSelected ? colors.primary : colors.onSurface,
                        )),
                  ),
                  Text(item.keywords,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.3),
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuItem {
  final NoteBlockType type;
  final IconData icon;
  final String label;
  final String keywords;

  const _MenuItem(this.type, this.icon, this.label, this.keywords);
}
