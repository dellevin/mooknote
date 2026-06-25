import 'package:flutter/material.dart';
import '../../models/note_plus_models.dart';

/// 单个块的渲染组件
///
/// 负责根据 block type 渲染不同 UI。
/// 焦点 block 使用 TextEditingController 编辑，非焦点 block 渲染为静态 Text。
class NotePlusBlockWidget extends StatelessWidget {
  final NoteBlock block;
  final int index;
  final int numberedIndex; // 有序列表序号
  final bool isFocused;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final VoidCallback? onToggleChecklist;
  final void Function(String)? onTextChanged;
  final void Function(TextSelection)? onSelectionChanged;

  const NotePlusBlockWidget({
    super.key,
    required this.block,
    required this.index,
    this.numberedIndex = 1,
    required this.isFocused,
    this.controller,
    this.focusNode,
    required this.onTap,
    this.onToggleChecklist,
    this.onTextChanged,
    this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (block.type == NoteBlockType.divider) {
      return _buildDivider(colors);
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧标记区
          _buildPrefix(colors),
          const SizedBox(width: 4),
          // 内容区
          Expanded(child: _buildContent(context, colors)),
        ],
      ),
    );
  }

  /// 块类型前缀标记
  Widget _buildPrefix(ColorScheme colors) {
    switch (block.type) {
      case NoteBlockType.bulletList:
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
        );
      case NoteBlockType.numberedList:
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            width: 24,
            child: Text(
              '$numberedIndex.',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        );
      case NoteBlockType.checklist:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: onToggleChecklist,
            child: Icon(
              block.metadata['checked'] == true
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              size: 20,
              color: block.metadata['checked'] == true
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        );
      case NoteBlockType.quote:
        // AppFlowy: 4px wide grey.shade300 left border
        return Container(
          width: 4,
          margin: const EdgeInsets.only(top: 6, bottom: 6, right: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      default:
        return const SizedBox(width: 0);
    }
  }

  /// 块内容
  Widget _buildContent(BuildContext context, ColorScheme colors) {
    final style = _getTextStyle(colors);

    Widget content;
    if (!isFocused) {
      content = Padding(
        padding: _getContentPadding(),
        child: block.text.isEmpty
            ? Text(_getPlaceholder(), style: style.copyWith(
                color: colors.onSurface.withValues(alpha: 0.25)))
            : _buildRichText(block.text, style, colors),
      );
    } else {
      content = _buildEditable(style, colors);
    }

    // AppFlowy code block: grey.shade50 background, 2px border radius
    if (block.type == NoteBlockType.codeBlock) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(2),
        ),
        child: content,
      );
    }

    return content;
  }

  Widget _buildEditable(TextStyle style, ColorScheme colors) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style,
      maxLines: null,
      minLines: 1,
      decoration: InputDecoration(
        hintText: _getPlaceholder(),
        hintStyle: style.copyWith(
          color: colors.onSurface.withValues(alpha: 0.25)),
        border: InputBorder.none,
        contentPadding: _getContentPadding(),
        isDense: true,
      ),
      onChanged: onTextChanged,
      // selection handler 通过 controller listener 处理
    );
  }

  Widget _buildRichText(String text, TextStyle style, ColorScheme colors) {
    if (block.formatting.isEmpty) {
      return Text(text, style: style);
    }

    final spans = _buildTextSpans(text, style, colors);
    return Text.rich(
      TextSpan(children: spans),
      maxLines: null,
    );
  }

  List<InlineSpan> _buildTextSpans(
      String text, TextStyle baseStyle, ColorScheme colors) {
    // 收集所有格式边界
    final events = <_FormatEvent>[];
    for (final span in block.formatting) {
      if (span.start < text.length) {
        events.add(_FormatEvent(span.start, true, span.formats));
        events.add(_FormatEvent(
            span.end > text.length ? text.length : span.end, false, span.formats));
      }
    }
    events.sort((a, b) {
      if (a.pos != b.pos) return a.pos.compareTo(b.pos);
      // 关闭优先于打开
      if (a.isStart && !b.isStart) return 1;
      if (!a.isStart && b.isStart) return -1;
      return 0;
    });

    if (events.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    final spans = <InlineSpan>[];
    int lastPos = 0;
    final activeFormats = <InlineFormatType>{};

    for (final event in events) {
      if (event.pos > lastPos) {
        spans.add(TextSpan(
          text: text.substring(lastPos, event.pos),
          style: _applyFormats(baseStyle, activeFormats, colors),
        ));
      }
      if (event.isStart) {
        activeFormats.addAll(event.formats);
      } else {
        activeFormats.removeAll(event.formats);
      }
      lastPos = event.pos;
    }

    if (lastPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastPos),
        style: _applyFormats(baseStyle, activeFormats, colors),
      ));
    }

    return spans;
  }

  TextStyle _applyFormats(
      TextStyle style, Set<InlineFormatType> formats, ColorScheme colors) {
    if (formats.isEmpty) return style;
    return style.copyWith(
      fontWeight: formats.contains(InlineFormatType.bold)
          ? FontWeight.bold
          : null,
      fontStyle: formats.contains(InlineFormatType.italic)
          ? FontStyle.italic
          : null,
      decoration: _getTextDecoration(formats),
      fontFamily: formats.contains(InlineFormatType.inlineCode)
          ? 'monospace'
          : null,
      fontSize: formats.contains(InlineFormatType.inlineCode) ? 13 : null,
      color: formats.contains(InlineFormatType.inlineCode)
          ? Colors.blue.shade900.withValues(alpha: 0.9)
          : null,
      backgroundColor: formats.contains(InlineFormatType.inlineCode)
          ? Colors.grey.shade50
          : null,
    );
  }

  TextDecoration? _getTextDecoration(Set<InlineFormatType> formats) {
    final decorations = <TextDecoration>[];
    if (formats.contains(InlineFormatType.underline)) {
      decorations.add(TextDecoration.underline);
    }
    if (formats.contains(InlineFormatType.strikethrough)) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (decorations.isEmpty) return null;
    return TextDecoration.combine(decorations);
  }

  TextStyle _getTextStyle(ColorScheme colors) {
    // AppFlowy: 18px, w300, height 1.3, letter-spacing 0.6
    final base = TextStyle(
      color: colors.onSurface,
      fontSize: 18,
      fontWeight: FontWeight.w300,
      height: 1.3,
      letterSpacing: 0.6,
    );
    switch (block.type) {
      case NoteBlockType.heading1:
        // AppFlowy H1: 34px, w300, height 1.15, 70% opacity
        return base.copyWith(
            fontSize: 34, fontWeight: FontWeight.w300, height: 1.15,
            letterSpacing: 0,
            color: colors.onSurface.withValues(alpha: 0.7));
      case NoteBlockType.heading2:
        // AppFlowy H2: 24px, w400, height 1.15, 70% opacity
        return base.copyWith(
            fontSize: 24, fontWeight: FontWeight.w400, height: 1.15,
            letterSpacing: 0,
            color: colors.onSurface.withValues(alpha: 0.7));
      case NoteBlockType.heading3:
        // AppFlowy H3: 20px, w500, height 1.25, 70% opacity
        return base.copyWith(
            fontSize: 20, fontWeight: FontWeight.w500, height: 1.25,
            letterSpacing: 0,
            color: colors.onSurface.withValues(alpha: 0.7));
      case NoteBlockType.quote:
        // AppFlowy quote: 60% opacity text
        return base.copyWith(
            color: colors.onSurface.withValues(alpha: 0.6));
      case NoteBlockType.codeBlock:
        // AppFlowy code: 13px, blue.shade900 at 90%, height 1.15, monospace
        return base.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          fontFamily: 'monospace',
          height: 1.15,
          letterSpacing: 0,
          color: Colors.blue.shade900.withValues(alpha: 0.9),
        );
      case NoteBlockType.checklist:
        return base.copyWith(
          decoration: block.metadata['checked'] == true
              ? TextDecoration.lineThrough
              : null,
          color: block.metadata['checked'] == true
              ? colors.onSurface.withValues(alpha: 0.4)
              : null,
        );
      default:
        return base;
    }
  }

  EdgeInsets _getContentPadding() {
    switch (block.type) {
      case NoteBlockType.heading1:
        return const EdgeInsets.only(top: 16);
      case NoteBlockType.heading2:
        return const EdgeInsets.only(top: 8);
      case NoteBlockType.heading3:
        return const EdgeInsets.only(top: 8);
      case NoteBlockType.codeBlock:
        // AppFlowy code: grey.shade50 background, no inner padding
        return const EdgeInsets.symmetric(vertical: 8, horizontal: 12);
      case NoteBlockType.quote:
        // AppFlowy quote: 6px top, 2px bottom inner padding
        return const EdgeInsets.only(top: 6, bottom: 2);
      default:
        // AppFlowy paragraph: 10px top spacing
        return const EdgeInsets.only(top: 10);
    }
  }

  String _getPlaceholder() {
    switch (block.type) {
      case NoteBlockType.heading1:
        return '标题1';
      case NoteBlockType.heading2:
        return '标题2';
      case NoteBlockType.heading3:
        return '标题3';
      case NoteBlockType.bulletList:
        return '列表项';
      case NoteBlockType.numberedList:
        return '列表项';
      case NoteBlockType.checklist:
        return '待办事项';
      case NoteBlockType.quote:
        return '引用';
      case NoteBlockType.codeBlock:
        return '代码';
      default:
        return '输入文字，或输入 / 打开菜单';
    }
  }

  Widget _buildDivider(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 1,
          color: colors.outlineVariant,
        ),
      ),
    );
  }
}

class _FormatEvent {
  final int pos;
  final bool isStart;
  final Set<InlineFormatType> formats;
  _FormatEvent(this.pos, this.isStart, this.formats);
}
