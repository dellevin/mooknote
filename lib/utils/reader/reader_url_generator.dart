import 'dart:convert';
import '../../service/book_server.dart';

/// 生成 foliate-js 阅读器 URL
String generateReaderUrl({
  required String fileUrl,
  String cfi = '',
  required String backgroundColor,
  required String textColor,
  bool isDarkMode = false,
}) {
  final indexHtmlPath = 'http://127.0.0.1:${Server().port}/foliate-js/index.html';

  final jsBg = _convertDartColorToJs(backgroundColor);
  final jsTc = _convertDartColorToJs(textColor);

  final style = {
    'fontSize': 100,
    'fontName': '',
    'fontPath': '',
    'fontWeight': 400,
    'letterSpacing': 0,
    'spacing': 1.6,
    'paragraphSpacing': 0.6,
    'textIndent': 2,
    'fontColor': '#$jsTc',
    'backgroundColor': '#$jsBg',
    'topMargin': 25,
    'bottomMargin': 25,
    'sideMargin': 3,
    'justify': true,
    'hyphenate': false,
    'pageTurnStyle': 'slide',
    'maxColumnCount': 1,
    'columnThreshold': 3,
    'writingMode': 'horizontal-tb',
    'textAlign': 'justify',
    'backgroundImage': '',
    'bgimgBlur': 0,
    'bgimgOpacity': 1.0,
    'bgimgFit': 'cover',
    'allowScript': false,
    'customCSS': '',
    'customCSSEnabled': false,
    'useBookStyles': true,
    'headingFontSize': 130,
    'codeHighlightTheme': 'atom-one-light',
  };

  final params = {
    'importing': false,
    'url': fileUrl,
    'initialCfi': cfi,
    'style': style,
  };

  final queryParts = params.entries
      .map((e) => '${e.key}=${Uri.encodeComponent(jsonEncode(e.value))}')
      .join('&');

  return '$indexHtmlPath?$queryParts';
}

/// 将 Dart 的 ARGB hex (FFRRGGBB) 转成 CSS 的 #RRGGBB 格式
String _convertDartColorToJs(String dartColor) {
  if (dartColor.startsWith('#')) {
    dartColor = dartColor.substring(1);
  }
  if (dartColor.length == 8) {
    return '#${dartColor.substring(2)}';
  }
  return '#$dartColor';
}
