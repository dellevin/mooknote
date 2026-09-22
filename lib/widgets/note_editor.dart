import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

/// 笔记纯文本编辑器（Flutter TextField）：固定高度、内部滚动。
/// 高度约占可视区中部，键盘弹出时收缩到键盘上方，保证编辑器不被键盘遮挡
class NoteEditor extends StatefulWidget {
  final String? initialContent;
  final ValueChanged<String>? onContentChanged;
  final String placeholder;

  const NoteEditor({
    super.key,
    this.initialContent,
    this.onContentChanged,
    this.placeholder = '使用 Markdown 格式书写...',
  });

  @override
  State<NoteEditor> createState() => NoteEditorState();
}

class NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _controller;

  bool get isReady => true;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> getValue() async => _controller.text;

  /// 在当前光标处插入文本（光标处插入，选中则替换）
  Future<void> insertValue(String text) async {
    final sel = _controller.selection;
    final valid = sel.isValid && sel.start != sel.end;
    final start = sel.isValid ? sel.start : _controller.text.length;
    final newText =
        _controller.text.replaceRange(start, valid ? sel.end : start, text);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    widget.onContentChanged?.call(newText);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final topPad = MediaQuery.paddingOf(context).top;
    final h =
        ((size.height - topPad - kb) * 0.5).clamp(160.0, size.height).toDouble();
    return SizedBox(
      height: h,
      child: TextField(
        controller: _controller,
        maxLines: null,
        minLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        strutStyle:
            const StrutStyle(forceStrutHeight: true, height: 1.6, fontSize: 15),
        style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.6),
        cursorColor: colors.primary,
        decoration: InputDecoration(
          hintText: widget.placeholder.tr,
          hintStyle: TextStyle(
              fontSize: 15,
              color: colors.onSurface.withValues(alpha: 0.25),
              height: 1.6),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        onChanged: (v) => widget.onContentChanged?.call(v),
      ),
    );
  }
}
