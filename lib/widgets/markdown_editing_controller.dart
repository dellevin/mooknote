import 'package:flutter/material.dart';

/// Markdown 编辑器控制器
/// 实现 Typora 风格的所见即所得 Markdown 编辑体验
/// 输入 # 标题 时，# 变小变淡，标题文字变大加粗
/// 输入 **粗体** 时，文字自动加粗
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({String? text}) : super(text: text);
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return _buildMarkdownSpan(text, style);
  }

  /// 构建 Markdown 样式的 TextSpan
  TextSpan _buildMarkdownSpan(String text, TextStyle? baseStyle) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      if (i > 0) {
        spans.add(const TextSpan(text: '\n'));
      }
      spans.add(_parseLine(lines[i], baseStyle));
    }

    return TextSpan(children: spans);
  }

  /// 解析单行文本
  InlineSpan _parseLine(String line, TextStyle? baseStyle) {
    // 空行
    if (line.isEmpty) {
      return const TextSpan(text: '');
    }

    // 代码块分隔符 ```
    if (line.startsWith('```')) {
      return TextSpan(
        text: line,
        style: _codeBlockStyle(baseStyle),
      );
    }

    // 标题 # ## ### 等
    if (line.startsWith('#')) {
      final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!;
        return _buildHeaderSpan(level, content, baseStyle);
      }
    }

    // 引用 >
    if (line.startsWith('>')) {
      final quoteMatch = RegExp(r'^>\s?(.*)$').firstMatch(line);
      if (quoteMatch != null) {
        final content = quoteMatch.group(1)!;
        return _buildQuoteSpan(content, baseStyle);
      }
    }

    // 无序列表 - 或 *
    final ulMatch = RegExp(r'^([\-\*])\s+(.*)$').firstMatch(line);
    if (ulMatch != null) {
      final content = ulMatch.group(2)!;
      return _buildListSpan(content, baseStyle, isOrdered: false);
    }

    // 有序列表 1. 2. 等
    final olMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
    if (olMatch != null) {
      final number = olMatch.group(1)!;
      final content = olMatch.group(2)!;
      return _buildListSpan(content, baseStyle, isOrdered: true, number: number);
    }

    // 分割线 --- *** ___
    if (RegExp(r'^( {0,3}([-_*])\s*\2\s*\2[\s\2]*)$').hasMatch(line)) {
      return _buildDividerSpan(line, baseStyle);
    }

    // 普通行 - 解析行内元素
    return _parseInline(line, baseStyle);
  }

  // ==================== 标题 ====================

  InlineSpan _buildHeaderSpan(int level, String content, TextStyle? baseStyle) {
    // 标题只改变颜色和粗细，不改变字体大小，避免光标错位
    final headerStyle = (baseStyle ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w600,
      color: const Color(0xFF1A1A1A),
    );

    return TextSpan(
      children: [
        TextSpan(
          text: '${'#' * level} ',
          style: const TextStyle(
            color: Color(0xFFCCCCCC),
            fontWeight: FontWeight.w400,
          ),
        ),
        ..._parseInlineSpans(content, headerStyle),
      ],
    );
  }

  // ==================== 引用 ====================

  InlineSpan _buildQuoteSpan(String content, TextStyle? baseStyle) {
    final quoteStyle = (baseStyle ?? const TextStyle()).copyWith(
      color: const Color(0xFF666666),
      fontStyle: FontStyle.italic,
      height: 1.8,
    );

    return TextSpan(
      children: [
        const TextSpan(
          text: '> ',
          style: TextStyle(
            color: Color(0xFF999999),
            fontWeight: FontWeight.bold,
          ),
        ),
        ..._parseInlineSpans(content, quoteStyle),
      ],
    );
  }

  // ==================== 列表 ====================

  InlineSpan _buildListSpan(String content, TextStyle? baseStyle,
      {required bool isOrdered, String? number}) {
    return TextSpan(
      children: [
        TextSpan(
          text: isOrdered ? '$number. ' : '• ',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w600,
          ),
        ),
        ..._parseInlineSpans(
          content,
          (baseStyle ?? const TextStyle()).copyWith(
            color: const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  // ==================== 分割线 ====================

  InlineSpan _buildDividerSpan(String line, TextStyle? baseStyle) {
    // 返回原始文本，但用灰色显示
    return TextSpan(
      text: line,
      style: const TextStyle(
        color: Color(0xFFCCCCCC),
      ),
    );
  }

  // ==================== 行内元素解析 ====================

  InlineSpan _parseInline(String text, TextStyle? baseStyle) {
    return TextSpan(children: _parseInlineSpans(text, baseStyle));
  }

  /// 解析行内 Markdown 元素
  /// 返回 InlineSpan 列表
  List<InlineSpan> _parseInlineSpans(String text, TextStyle? baseStyle) {
    if (text.isEmpty) {
      return [const TextSpan(text: '')];
    }

    // 收集所有匹配的模式
    final patterns = <_MatchPattern>[];

    // 粗体 **text**
    for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(text)) {
      if (match.group(1)!.isNotEmpty) {
        patterns.add(_MatchPattern(
          match.start,
          match.end,
          _InlineType.bold,
          match.group(0)!,
          match.group(1)!,
        ));
      }
    }

    // 斜体 *text* (排除 **)
    for (final match in RegExp(r'(?<!\*)\*([^*]+)\*(?!\*)').allMatches(text)) {
      if (match.group(1)!.isNotEmpty) {
        patterns.add(_MatchPattern(
          match.start,
          match.end,
          _InlineType.italic,
          match.group(0)!,
          match.group(1)!,
        ));
      }
    }

    // 删除线 ~~text~~
    for (final match in RegExp(r'~~([^~]+)~~').allMatches(text)) {
      if (match.group(1)!.isNotEmpty) {
        patterns.add(_MatchPattern(
          match.start,
          match.end,
          _InlineType.strikethrough,
          match.group(0)!,
          match.group(1)!,
        ));
      }
    }

    // 行内代码 `code`
    for (final match in RegExp(r'`([^`]+)`').allMatches(text)) {
      if (match.group(1)!.isNotEmpty) {
        patterns.add(_MatchPattern(
          match.start,
          match.end,
          _InlineType.inlineCode,
          match.group(0)!,
          match.group(1)!,
        ));
      }
    }

    // 链接 [text](url)
    for (final match in RegExp(r'\[([^\]]+)\]\(([^)]+)\)').allMatches(text)) {
      if (match.group(1)!.isNotEmpty) {
        patterns.add(_MatchPattern(
          match.start,
          match.end,
          _InlineType.link,
          match.group(0)!,
          match.group(1)!,
          url: match.group(2),
        ));
      }
    }

    // 如果没有匹配到任何模式，返回原始文本
    if (patterns.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    // 按起始位置排序
    patterns.sort((a, b) => a.start.compareTo(b.start));

    // 过滤重叠的模式（选择第一个匹配的，跳过被包含的）
    final filtered = <_MatchPattern>[];
    _MatchPattern? last;
    for (final pattern in patterns) {
      if (last == null || pattern.start >= last.end) {
        filtered.add(pattern);
        last = pattern;
      }
    }

    // 构建 InlineSpan 列表
    final spans = <InlineSpan>[];
    var currentPos = 0;

    for (final pattern in filtered) {
      // 添加匹配前的普通文本
      if (pattern.start > currentPos) {
        spans.add(TextSpan(
          text: text.substring(currentPos, pattern.start),
          style: baseStyle,
        ));
      }

      // 添加带样式的匹配内容
      final style = _getInlineStyle(pattern.type, baseStyle);
      spans.add(TextSpan(
        text: pattern.content,
        style: style,
      ));

      currentPos = pattern.end;
    }

    // 添加剩余的普通文本
    if (currentPos < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentPos),
        style: baseStyle,
      ));
    }

    return spans;
  }

  /// 获取行内元素的样式
  TextStyle? _getInlineStyle(_InlineType type, TextStyle? base) {
    final baseStyle = base ?? const TextStyle();
    switch (type) {
      case _InlineType.bold:
        return baseStyle.copyWith(fontWeight: FontWeight.bold);
      case _InlineType.italic:
        return baseStyle.copyWith(fontStyle: FontStyle.italic);
      case _InlineType.strikethrough:
        return baseStyle.copyWith(
          decoration: TextDecoration.lineThrough,
          color: const Color(0xFF999999),
        );
      case _InlineType.inlineCode:
        return baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: const Color(0xFFF5F5F5),
          color: const Color(0xFF1A1A1A),
        );
      case _InlineType.link:
        return baseStyle.copyWith(
          color: const Color(0xFF4A90D9),
          decoration: TextDecoration.underline,
        );
    }
  }

  /// 代码块样式
  TextStyle _codeBlockStyle(TextStyle? baseStyle) {
    return (baseStyle ?? const TextStyle()).copyWith(
      fontFamily: 'monospace',
      color: const Color(0xFF999999),
      fontSize: 14,
    );
  }
}

/// 行内元素类型
enum _InlineType {
  bold,
  italic,
  strikethrough,
  inlineCode,
  link,
}

/// 匹配模式
class _MatchPattern {
  final int start;
  final int end;
  final _InlineType type;
  final String fullMatch;
  final String content;
  final String? url;

  _MatchPattern(
    this.start,
    this.end,
    this.type,
    this.fullMatch,
    this.content, {
    this.url,
  });
}
