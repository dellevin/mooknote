import 'package:flutter/material.dart';

/// 别名标签式输入弹窗（影视/书籍共用）
class AlternateTitlesDialog extends StatefulWidget {
  final List<String> initial;
  const AlternateTitlesDialog({super.key, required this.initial});

  @override
  State<AlternateTitlesDialog> createState() => _AlternateTitlesDialogState();
}

class _AlternateTitlesDialogState extends State<AlternateTitlesDialog> {
  late final TextEditingController _controller;
  late List<String> _items;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _items = List.from(widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    if (!_items.contains(v)) {
      setState(() => _items.add(v));
    }
    _controller.clear();
    _focus.requestFocus();
  }

  void _remove(int i) => setState(() => _items.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('添加别名', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 输入框 + 添加按钮
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: '输入别名',
                      hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: colors.surfaceContainerHigh,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary, width: 1)),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _add,
                  icon: Icon(Icons.add_circle, color: colors.primary, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 标签列表
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无别名', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(_items.length, (i) {
                      return Chip(
                        label: Text(_items[i], style: TextStyle(fontSize: 13, color: colors.onSurface)),
                        backgroundColor: colors.surfaceContainerHighest,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        deleteIcon: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
                        onDeleted: () => _remove(i),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _items),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}