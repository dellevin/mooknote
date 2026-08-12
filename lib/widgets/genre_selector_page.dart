import 'package:flutter/material.dart';
import '../widgets/app_overlay.dart';

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
  final _scrollController = ScrollController();
  String _query = '';
  List<String>? _loadedTags;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
    _loadTags();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    if (widget.existingTags != null) {
      _loadedTags = widget.existingTags;
    } else {
      _loadedTags = await widget.existingTagsFuture;
    }
    if (mounted) setState(() => _loading = false);
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
    appDialog<String>(
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
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 8, 14),
              child: Row(
                children: [
                  Text(widget.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      // 输入框非空时，完成即添加并关闭
                      if (_query.trim().isNotEmpty && !_selected.contains(_query.trim())) {
                        _selected.add(_query.trim());
                      }
                      Navigator.pop(context, _selected);
                    },
                    child: Text('完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
                  ),
                ],
              ),
            ),

            // 搜索/输入框
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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

            // 已选择区（紧凑 chip 流，最新在上）
            if (_selected.isNotEmpty) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildSelectedChips(colors),
              ),
              const SizedBox(height: 4),
            ],

            // 可选区标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _loading ? '加载中...' : (query.isEmpty ? '可选 (${available.length})' : '匹配结果 (${available.length})'),
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                ),
              ),
            ),

            // 可选列表（虚拟化）
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
                  : available.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Text(
                              query.isEmpty ? '暂无可选' : '无匹配结果，回车添加',
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                          itemCount: available.length,
                          itemExtent: 44,
                          itemBuilder: (_, i) {
                            final tag = available[i];
                            return _buildAvailableItem(tag, colors);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 已选 chip 流：每个 chip 显示「标签名 ×」，点 × 移除，长按编辑
  Widget _buildSelectedChips(ColorScheme colors) {
    // 反序展示，最新在上
    final reversed = _selected.reversed.toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(reversed.length, (i) {
        final actualIdx = _selected.length - 1 - i;
        final tag = reversed[i];
        return GestureDetector(
          onTap: () => _toggle(tag),
          onLongPress: () => _editItem(actualIdx, tag),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onPrimary)),
                const SizedBox(width: 4),
                Icon(Icons.close, size: 14, color: colors.onPrimary.withValues(alpha: 0.85)),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// 可选列表项：左标签 + 右添加图标
  Widget _buildAvailableItem(String tag, ColorScheme colors) {
    return InkWell(
      onTap: () => _toggle(tag),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tag,
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.8)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.add_circle_outline, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
