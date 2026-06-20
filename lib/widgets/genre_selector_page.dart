import 'package:flutter/material.dart';

/// 类型/标签选择全屏页（影视类型、书籍类型通用）
class GenreSelectorPage extends StatefulWidget {
  final String title;
  final List<String> existingTags;
  final List<String> initialSelected;
  final String hint;
  const GenreSelectorPage({
    super.key,
    required this.title,
    required this.existingTags,
    required this.initialSelected,
    this.hint = '',
  });

  @override
  State<GenreSelectorPage> createState() => _GenreSelectorPageState();
}

class _GenreSelectorPageState extends State<GenreSelectorPage> {
  late List<String> _selected;
  final _controller = TextEditingController();
  String _newTag = '';

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
  }

  void _addCustom() {
    final tag = _newTag.trim();
    if (tag.isNotEmpty && !_selected.contains(tag)) {
      setState(() {
        _selected.add(tag);
        _newTag = '';
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final available = widget.existingTags.where((t) => !_selected.contains(t)).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: Text('完成', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary,
            )),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 已选择
            if (_selected.isNotEmpty) ...[
              Text('已选择', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _selected.map((tag) {
                  final displayTag = tag.length > 8 ? '${tag.substring(0, 8)}...' : tag;
                  return GestureDetector(
                    onTap: () => _toggle(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.primary, borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayTag, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onPrimary)),
                          const SizedBox(width: 6),
                          Icon(Icons.close, size: 14, color: colors.onPrimary.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            // 自定义输入
            Text('自定义添加', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: widget.hint.isNotEmpty ? widget.hint : '输入自定义类型',
                      hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                      filled: true, fillColor: colors.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _newTag = v),
                    onSubmitted: (_) => _addCustom(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addCustom,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _newTag.trim().isNotEmpty ? colors.primary : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add, size: 20,
                        color: _newTag.trim().isNotEmpty ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ),
              ],
            ),
            // 已有类型
            if (available.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('已有类型', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: available.map((tag) {
                  final displayTag = tag.length > 8 ? '${tag.substring(0, 8)}...' : tag;
                  return GestureDetector(
                    onTap: () => _toggle(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                          const SizedBox(width: 4),
                          Text(displayTag, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7))),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
