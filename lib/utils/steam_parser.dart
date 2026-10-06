import 'package:http/http.dart' as http;

/// Steam 商店页抓取：GET 中文商店页 HTML 后正则解析。
/// Steam 商店页为服务端渲染，普通 GET 即可拿到完整元信息；
/// 通过 Cookie 预置出生日期/成人内容标记绕过年龄验证跳转。
/// 抓取/解析失败返回 null。
class SteamGameParser {
  static final _appRe = RegExp(r'store\.steampowered\.com/app/(\d+)');

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept-Language': 'zh-CN,zh;q=0.9',
    'Referer': 'https://store.steampowered.com/',
    // 绕过年龄验证门
    'Cookie': 'birthtime=568022401; mature_content=1; wants_mature_content=1',
  };

  /// 是否 Steam 商店 app 链接
  static bool isSteamAppUrl(String url) => _appRe.hasMatch(url);

  /// 抓取并解析游戏信息
  static Future<Map<String, dynamic>?> fetch(String url) async {
    final id = _appRe.firstMatch(url)?[1];
    if (id == null) return null;
    String html;
    try {
      final resp = await http
          .get(Uri.parse('https://store.steampowered.com/app/$id/?l=schinese'),
              headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      html = resp.body;
    } catch (_) {
      return null;
    }
    // 年龄验证页未绕过 / 页面结构异常
    if (!html.contains('appHubAppName')) return null;
    return _parse(html);
  }

  static Map<String, dynamic> _parse(String html) {
    final info = <String, dynamic>{};

    // 标题
    info['title'] =
        _clean(_first(html, RegExp(r'id="appHubAppName"[^>]*>([\s\S]*?)</div>')));

    // 封面（header 横图）
    info['coverUrl'] = _first(html,
            RegExp(r'class="game_header_image_full"[^>]*src="([^"]+)"')) ??
        '';

    // 简介
    info['summary'] = _clean(_first(html,
        RegExp(r'class="game_description_snippet"[^>]*>([\s\S]*?)</div>')));

    // 发行日期：2023 年 5 月 26 日 → 2023-05-26
    info['releaseDate'] = _normalizeDate(_clean(_first(
        html,
        RegExp(
            r'<div class="release_date">[\s\S]*?<div class="date">([\s\S]*?)</div>'))));

    // 开发者 / 发行商（dev_row：label + summary 内 <a>）
    info['developer'] = _devRowValues(html, '开发者');
    info['publisher'] = _devRowValues(html, '发行商');

    // 用户自定义标签作为类型，最多取 5 个。
    // 注意：服务端 HTML 中所有标签都带 display:none，显隐由前端 JS 控制，
    // 因此直接按出现顺序取前 5 个（即热门排序的头部）。
    final tags = <String>[];
    final tagRe = RegExp(r'class="app_tag"[^>]*>([^<]+)</a>');
    for (final m in tagRe.allMatches(html)) {
      final t = _clean(m[1]);
      if (t.isNotEmpty && t != '+' && !tags.contains(t)) tags.add(t);
      if (tags.length >= 5) break;
    }
    info['genres'] = tags;

    // 平台：win / mac / linux 图标
    final platforms = <String>[
      if (html.contains('platform_img win')) 'Windows',
      if (html.contains('platform_img mac')) 'macOS',
      if (html.contains('platform_img linux')) 'SteamOS + Linux',
    ];
    info['platforms'] = platforms;

    return info;
  }

  /// dev_row 中某标签的所有 <a> 值
  static List<String> _devRowValues(String html, String label) {
    final block = _first(
        html,
        RegExp(
            '<div class="dev_row">\\s*<div class="subtitle column">\\s*$label:?\\s*</div>\\s*<div class="summary column"[^>]*>([\\s\\S]*?)</div>'));
    if (block == null) return const [];
    return RegExp(r'<a[^>]*>([\s\S]*?)</a>')
        .allMatches(block)
        .map((m) => _clean(m[1]))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static String? _first(String html, RegExp re) => re.firstMatch(html)?[1];

  static String _clean(String? s) => _unescape(
          (s ?? '').replaceAll(RegExp(r'<[^>]+>'), ''))
      .trim();

  static String _unescape(String s) => s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  /// 「2023 年 5 月 26 日」/「2023 年 5 月」→ yyyy-MM-dd；无法识别返回 ''
  static String _normalizeDate(String s) {
    final m = RegExp(r'(\d{4})\s*年\s*(\d{1,2})\s*月\s*(?:(\d{1,2})\s*日)?')
        .firstMatch(s);
    return m == null
        ? ''
        : '${m[1]}-${m[2]!.padLeft(2, '0')}-${(m[3] ?? '01').padLeft(2, '0')}';
  }
}
