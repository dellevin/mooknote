import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mooknote/utils/markdown_utils.dart';

void main() {
  group('markdownToPlainText', () {
    test('keeps link labels and removes markdown syntax', () {
      expect(
        markdownToPlainText(
          '推荐阅读[导演访谈](https://example.com/interview)，还有 **幕后故事**。',
        ),
        '推荐阅读导演访谈，还有 幕后故事。',
      );
    });

    test('cleans common block syntax for list previews', () {
      expect(
        markdownToPlainText('# 标题\n\n- [ ] 待看\n> 引用\n`代码`'),
        '标题\n待看\n引用\n代码',
      );
    });
  });

  group('insertMarkdownLink', () {
    test('replaces selected text and adds https by default', () {
      const value = TextEditingValue(
        text: '查看导演访谈',
        selection: TextSelection(baseOffset: 2, extentOffset: 6),
      );

      final result = insertMarkdownLink(
        value,
        label: '',
        url: 'example.com/interview',
      );

      expect(result.text, '查看[导演访谈](https://example.com/interview)');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('inserts a named link at the cursor', () {
      const value = TextEditingValue(
        text: '相关：',
        selection: TextSelection.collapsed(offset: 3),
      );

      final result = insertMarkdownLink(
        value,
        label: '官方网站',
        url: 'https://example.com',
      );

      expect(result.text, '相关：[官方网站](https://example.com)');
    });
  });
}
