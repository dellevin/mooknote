import 'package:flutter/material.dart';

/// 类型/标签选择右侧弹窗（影视类型、导演、编剧、主演、书籍类型通用）
class GenreSelectorPage extends StatefulWidget {
  final String title;
  final List<String>? existingTags;
  final Future<List<String>>? existingTagsFuture;
  final List<String> initialSelected;
  final String hint;
  const GenreSelectorPage({
    super.key,
    required this.title,
    this.existingTags,
    this.existingTagsFuture,
    required this.initialSelected,
    this.hint = '',
  }) : assert(existingTags != null || existingTagsFuture != null, 'existingTags 和 existingTagsFuture 至少提供一个');

  /// 显示右侧弹窗
  static Future<List<String>?> show({
    required BuildContext context,
    required String title,
    List<String>? existingTags,
    Future<List<String>>? existingTagsFuture,
    required List<String> initialSelected,
    String hint = '',
  }) {
    return showGeneralDialog<List<String>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'selector-panel',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: Align(
            alignment: Alignment.centerRight,
            child: GenreSelectorPage(
              title: title,
              existingTags: existingTags,
              existingTagsFuture: existingTagsFuture,
              initialSelected: initialSelected,
              hint: hint,
            ),
          ),
        );
      },
    );
  }

  @override
  State<GenreSelectorPage> createState() => _GenreSelectorPageState();
}

class _GenreSelectorPageState extends State<GenreSelectorPage> {
  late List<String> _selected;
  final _controller = TextEditingController();
  String _query = '';
  List<String>? _loadedTags;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _loadTags();
  }

  Future<void> _loadTags() async {
    if (widget.existingTags != null) {
      _loadedTags = widget.existingTags;
    } else {
      _loadedTags = await widget.existingTagsFuture;
    }
    if (mounted) setState(() => _loading = false);
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
    final tag = _query.trim();
    if (tag.isNotEmpty && !_selected.contains(tag)) {
      setState(() {
        _selected.add(tag);
        _query = '';
        _controller.clear();
      });
    }
  }

  void _editItem(int index, String oldValue) {
    final editController = TextEditingController(text: oldValue);
    showDialog<String>(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('编辑', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: TextField(
            controller: editController,
            autofocus: true,
            style: TextStyle(fontSize: 15, color: colors.onSurface),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, editController.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('确定'),
            ),
          ],
        );
      },
    ).then((newValue) {
      if (newValue != null && newValue.isNotEmpty && newValue != oldValue && mounted) {
        setState(() => _selected[index] = newValue);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final allTags = _loadedTags ?? [];
    final query = _query.toLowerCase();
    final available = allTags
        .where((t) => !_selected.contains(t))
        .where((t) => query.isEmpty || t.toLowerCase().contains(query))
        .toList();

    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: screenWidth * 0.75,
        height: double.infinity,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
              ),
              child: Row(
                children: [
                  Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text('完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
                  ),
                ],
              ),
            ),

            // 已选择（一行一个，最新在上）
            if (_selected.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('已选择', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.25),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _selected.length,
                    itemBuilder: (_, i) {
                      final idx = _selected.length - 1 - i;
                      final tag = _selected[idx];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            leading: Icon(Icons.check_circle, size: 20, color: colors.primary),
                            title: GestureDetector(
                              onTap: () => _editItem(idx, tag),
                              child: Text(tag, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _editItem(idx, tag),
                                  child: Icon(Icons.edit, size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _toggle(tag),
                                  child: Icon(Icons.close, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            // 搜索/输入框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                cursorColor: colors.primary,
                decoration: InputDecoration(
                  hintText: widget.hint.isNotEmpty ? '搜索或${widget.hint}' : '搜索或输入',
                  hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.add, size: 20,
                        color: _query.trim().isNotEmpty ? colors.primary : colors.onSurface.withValues(alpha: 0.25)),
                    onPressed: _addCustom,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (_) => _addCustom(),
              ),
            ),

            // 已有类型/搜索结果
            if (allTags.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _loading ? '加载中...' : (query.isEmpty ? '已有类型' : '匹配结果'),
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                    : available.isEmpty
                        ? Center(child: Text(
                            query.isEmpty ? '暂无已有选项' : '无匹配结果，回车添加',
                            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3)),
                          ))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: available.map((tag) {
                                return GestureDetector(
                                  onTap: () => _toggle(tag),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: colors.outline, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                                        const SizedBox(width: 4),
                                        Text(tag, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7))),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
