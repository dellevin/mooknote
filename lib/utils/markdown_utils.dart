import 'package:flutter/services.dart';

/// 把 Markdown 内容转换为适合列表摘要展示的纯文本。
String markdownToPlainText(String text) {
  var result = text;
  result = result.replaceAllMapped(
    RegExp(r'```(?:\w+)?\n?(.*?)```', dotAll: true),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  result = result
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
      .replaceAll(
        RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+[.)]\s+', multiLine: true), '');
  result = result.replaceAllMapped(
    RegExp(r'(\*\*|__)(.*?)\1'),
    (match) => match.group(2) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'(\*|_)(.*?)\1'),
    (match) => match.group(2) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'~~(.*?)~~'),
    (match) => match.group(1) ?? '',
  );
  result = result.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (match) => match.group(1) ?? '',
  );
  return result
      .replaceAll(
        RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$', multiLine: true),
        '',
      )
      .replaceAll(RegExp(r'\n\s*\n+'), '\n')
      .trim();
}

/// 没有协议的网址默认按 HTTPS 处理。
String normalizeMarkdownLinkUrl(String url) {
  final value = url.trim();
  if (value.isEmpty) return value;
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return value;
  return 'https://$value';
}

/// 用 Markdown 链接替换当前选区，并把光标移动到链接末尾。
TextEditingValue insertMarkdownLink(
  TextEditingValue value, {
  required String label,
  required String url,
}) {
  final text = value.text;
  final selection = value.selection;
  final start =
      selection.isValid ? selection.start.clamp(0, text.length) : text.length;
  final end =
      selection.isValid ? selection.end.clamp(0, text.length) : text.length;
  final from = start < end ? start : end;
  final to = start < end ? end : start;
  final selectedText = text.substring(from, to);
  final normalizedUrl = normalizeMarkdownLinkUrl(url);
  final displayText = label.trim().isNotEmpty
      ? label.trim()
      : selectedText.trim().isNotEmpty
          ? selectedText.trim()
          : normalizedUrl;
  final markdown = '[$displayText]($normalizedUrl)';
  final updated = text.replaceRange(from, to, markdown);
  return TextEditingValue(
    text: updated,
    selection: TextSelection.collapsed(offset: from + markdown.length),
  );
}
