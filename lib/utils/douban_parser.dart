import 'package:http/http.dart' as http;

/// 豆瓣网页版 subject 页直接抓取：GET HTML 后正则解析（对齐参考 Python 实现）。
/// 网页版 #info 元信息块结构规整（最内层 span 为标签 + <br> 分段），比移动版稳定。
/// 抓取/解析失败返回 null，调用方回退 WebView 内 JS 提取。
const _headers = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'Referer': 'https://www.douban.com',
};

String? _first(String html, RegExp re) => re.firstMatch(html)?[1];

String _stripTags(String s) => s.replaceAll(RegExp(r'<[^>]+>'), '');

String _unescape(String s) {
  return s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'");
}

/// 抓取 subject 页 HTML；非 200 或异常返回 null
Future<String?> _fetchHtml(String? subjectUrl) async {
  if (subjectUrl == null) return null;
  try {
    final resp = await http
        .get(Uri.parse(subjectUrl), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;
    return resp.body;
  } catch (_) {
    return null;
  }
}

/// #info 元信息块：按 <br> 分段，最内层 span 为标签，
/// 段内 <a> 链接文本或标签后的纯文本为值（"更多..."之类的 JS 伪链接除外）
Map<String, List<String>> _parseInfoBlock(String html) {
  final meta = <String, List<String>>{};
  final infoBlock = _first(
      html,
      RegExp("<div\\s+id=[\"']info[\"'][^>]*>([\\s\\S]*?)</div>",
          caseSensitive: false));
  if (infoBlock == null) return meta;
  final normalized = infoBlock.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false), '<br>');
  final innerSpanRe = RegExp(r'<span\b[^>]*>((?:(?!<span\b)[\s\S])*?)</span>',
      caseSensitive: false);
  final aRe = RegExp(
      "<a\\s+[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\\s\\S]*?)</a>",
      caseSensitive: false);
  for (final raw in normalized.split('<br>')) {
    final seg = raw.trim();
    if (seg.isEmpty) continue;
    final spanMatch = innerSpanRe.firstMatch(seg);
    if (spanMatch == null) continue;
    final label = _unescape(_stripTags(spanMatch.group(1)!))
        .trim()
        .replaceAll(RegExp(r'[:：]+$'), '')
        .trim();
    if (label.isEmpty) continue;
    final values = aRe
        .allMatches(seg)
        .where((m) => !(m.group(1) ?? '').startsWith('javascript'))
        .map((m) => _unescape(_stripTags(m.group(2)!)).trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (values.isEmpty) {
      final rest = _unescape(_stripTags(seg.substring(spanMatch.end))).trim();
      if (rest.isNotEmpty) values.add(rest);
    }
    if (values.isNotEmpty) meta.putIfAbsent(label, () => []).addAll(values);
  }
  return meta;
}

/// dl.thing-attr 元信息块（游戏页）：dt 为标签，紧随的 dd 为值；
/// dd 内 <a> 链接文本或纯文本为值
Map<String, List<String>> _parseThingAttr(String html) {
  final meta = <String, List<String>>{};
  final dl = _first(
      html,
      RegExp("<dl\\s+class=[\"']thing-attr[\"'][^>]*>([\\s\\S]*?)</dl>",
          caseSensitive: false));
  if (dl == null) return meta;
  final pairRe = RegExp(
      r'<dt[^>]*>([\s\S]*?)</dt>\s*<dd[^>]*>([\s\S]*?)</dd>',
      caseSensitive: false);
  final aRe = RegExp(
      "<a\\s+[^>]*href=[\"']([^\"']+)[\"'][^>]*>([\\s\\S]*?)</a>",
      caseSensitive: false);
  for (final m in pairRe.allMatches(dl)) {
    final label = _unescape(_stripTags(m.group(1)!))
        .trim()
        .replaceAll(RegExp(r'[:：]+$'), '')
        .trim();
    if (label.isEmpty) continue;
    final dd = m.group(2)!;
    final values = aRe
        .allMatches(dd)
        .where((am) => !(am.group(1) ?? '').startsWith('javascript'))
        .map((am) => _unescape(_stripTags(am.group(2)!)).trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (values.isEmpty) {
      final rest = _unescape(_stripTags(dd)).trim();
      if (rest.isNotEmpty) values.add(rest);
    }
    if (values.isNotEmpty) meta.putIfAbsent(label, () => []).addAll(values);
  }
  return meta;
}

String _pick(Map<String, List<String>> meta, String key) =>
    (meta[key] ?? const []).join(' / ');

/// "2014-7-1" / "2014-7" / "2026-09-25(中国大陆)" → yyyy-MM-dd（供 DateTime.parse）
String _normalizeDate(String s) {
  final dm = RegExp(r'(\d{4})(?:-(\d{1,2}))?(?:-(\d{1,2}))?').firstMatch(s);
  return dm == null
      ? ''
      : '${dm[1]}-${(dm[2] ?? '01').padLeft(2, '0')}-${(dm[3] ?? '01').padLeft(2, '0')}';
}

String _normalizeCover(String url) =>
    url.contains('.webp') ? url.replaceAll('.webp', '.jpg') : url;

/// 豆瓣书籍抓取
class DoubanBookParser {
  static final _subjectRe =
      RegExp(r'(?:m\.douban\.com/book|book\.douban\.com)/subject/(\d+)');

  /// 是否豆瓣书籍 subject 链接（手机版/网页版均可）
  static bool isBookSubjectUrl(String url) => _subjectRe.hasMatch(url);

  /// 统一转网页版链接：m.douban.com/book/subject/xxx → book.douban.com/subject/xxx
  static String? normalizeSubjectUrl(String url) {
    final m = _subjectRe.firstMatch(url);
    return m == null ? null : 'https://book.douban.com/subject/${m[1]}/';
  }

  /// 抓取并解析书籍信息
  static Future<Map<String, dynamic>?> fetch(String url) async {
    final html = await _fetchHtml(normalizeSubjectUrl(url));
    if (html == null) return null;
    return _parse(html);
  }

  static Map<String, dynamic> _parse(String html) {
    final info = <String, dynamic>{};

    // 标题
    info['title'] = _first(
            html,
            RegExp(
                r'<span property="v:itemreviewed">([^<]*)</span>')) ??
        _first(html, RegExp(r'<h1[^>]*>\s*<span[^>]*>([^<]*)<')) ??
        '';

    // 封面：#mainpic 内 a.nbg 的 href 是大图，img src 是小图兜底
    info['coverUrl'] = _normalizeCover(_first(html,
            RegExp(r'<div id="mainpic">[\s\S]*?<a[^>]*href="([^"]+)"')) ??
        _first(html,
            RegExp(r'<div id="mainpic">[\s\S]*?<img[^>]*src="([^"]+)"')) ??
        '');

    // 评分
    info['rating'] =
        _first(html, RegExp(r'rating_num"[^>]*>\s*([\d.]+)')) ?? '';

    // 简介：#link-report 内第一个 .intro
    final summaryHtml = _first(
        html,
        RegExp(
            r'id="link-report"[\s\S]*?<div class="intro">([\s\S]*?)</div>'));
    info['summary'] = summaryHtml == null
        ? ''
        : _unescape(_stripTags(summaryHtml.replaceAll(
                RegExp(r'</p>\s*<p[^>]*>'), '\n')))
            .trim();

    // 元信息块 #info
    final meta = _parseInfoBlock(html);
    info['author'] = _pick(meta, '作者');
    info['translator'] = _pick(meta, '译者');
    info['publisher'] = _pick(meta, '出版社');
    info['isbn'] = _pick(meta, 'ISBN');

    // 出版年
    info['releaseDate'] = _normalizeDate(_pick(meta, '出版年'));

    // 类型标签（匿名访问常不返回 #db-tags-section，尽力而为）
    final tagSection =
        _first(html, RegExp(r'id="db-tags-section"([\s\S]*?)</div>'));
    info['genres'] = tagSection == null
        ? ''
        : RegExp(r'class="tag"[^>]*>([^<]+)<')
            .allMatches(tagSection)
            .map((m) => m[1]!.trim())
            .where((t) => t.isNotEmpty)
            .join(',');

    return info;
  }
}

/// 豆瓣游戏抓取（www.douban.com/game/xxx 桌面页，元信息为 dl.thing-attr dt/dd 结构）
class DoubanGameParser {
  static final _subjectRe =
      RegExp(r'(?:m\.douban\.com/game/subject|www\.douban\.com/game)/(\d+)');

  /// 是否豆瓣游戏 subject 链接（手机版/网页版均可）
  static bool isGameSubjectUrl(String url) => _subjectRe.hasMatch(url);

  /// 统一转网页版链接：m.douban.com/game/subject/xxx → www.douban.com/game/xxx/
  static String? normalizeSubjectUrl(String url) {
    final m = _subjectRe.firstMatch(url);
    return m == null ? null : 'https://www.douban.com/game/${m[1]}/';
  }

  /// 抓取并解析游戏信息
  static Future<Map<String, dynamic>?> fetch(String url) async {
    final html = await _fetchHtml(normalizeSubjectUrl(url));
    if (html == null) return null;
    return _parse(html);
  }

  static Map<String, dynamic> _parse(String html) {
    final info = <String, dynamic>{};

    // 标题（#content 下唯一 h1，如 "永劫无间 Naraka: Bladepoint"）
    final titleHtml = _first(
        html, RegExp(r'id="content"[\s\S]*?<h1[^>]*>([\s\S]*?)</h1>'));
    info['title'] =
        titleHtml == null ? '' : _unescape(_stripTags(titleHtml)).trim();

    // 封面：.item-subject-info .pic 内 a 的 href 是大图，img src 兜底
    info['coverUrl'] = _normalizeCover(_first(html,
            RegExp(r'<div class="pic">[\s\S]*?<a[^>]*href="([^"]+)"')) ??
        _first(html,
            RegExp(r'<div class="pic">[\s\S]*?<img[^>]*src="([^"]+)"')) ??
        '');

    // 评分
    info['rating'] =
        _first(html, RegExp(r'rating_num"[^>]*>\s*([\d.]+)')) ?? '';

    // 简介：#link-report 内第一个 <p>
    final summaryHtml = _first(
        html, RegExp(r'id="link-report"[\s\S]*?<p[^>]*>([\s\S]*?)</p>'));
    info['summary'] =
        summaryHtml == null ? '' : _unescape(_stripTags(summaryHtml)).trim();

    // 元信息 dl.thing-attr（dt 标签 + dd 值）
    final meta = _parseThingAttr(html);

    // 类型：首条通用"游戏"链接（href="/game/explore"）剔除
    info['genres'] = (meta['类型'] ?? const [])
        .where((v) => v != '游戏')
        .join(',');
    info['platforms'] = (meta['平台'] ?? const []).join(',');
    info['alternateTitles'] = meta['别名'] ?? const [];
    info['developer'] = _pick(meta, '开发商');

    // 发行日期（无则退 预计上市时间）
    final release = _pick(meta, '发行日期');
    info['releaseDate'] = _normalizeDate(
        release.isNotEmpty ? release : _pick(meta, '预计上市时间'));

    return info;
  }
}
