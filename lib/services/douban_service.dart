import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'api_proxy_client.dart';

/// doubanio 图片防盗链同时校验 Referer 与 User-Agent：
/// 缺 Referer 返回 418，仅带 Referer 但 UA 非浏览器返回 403，
/// 两者齐全（任意豆瓣子站 Referer + 浏览器 UA）才放行。
/// 图片展示与下载统一带此头。
const Map<String, String> doubanImageHeaders = {
  'Referer': 'https://www.douban.com/',
  'User-Agent': DoubanService._desktopUa,
};

/// 豆瓣登录态失效（分类搜索需要 dbcl2，未登录/过期时抛出）
class DoubanAuthException implements Exception {}

/// 网络不通 / 请求失败
class DoubanNetworkException implements Exception {}

/// 豆瓣搜索结果条目（结构对齐参考 Python demo 的统一条目）
class DoubanSearchItem {
  final String id;

  /// movie / tv / book
  final String type;
  final String typeName;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String rating;
  final String year;

  const DoubanSearchItem({
    required this.id,
    required this.type,
    required this.typeName,
    required this.title,
    this.subtitle = '',
    this.coverUrl = '',
    this.rating = '',
    this.year = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'type_name': typeName,
        'title': title,
        'card_subtitle': subtitle,
        'cover_url': coverUrl,
        'rating': rating,
        'year': year,
      };
}

/// 豆瓣搜索服务：rexxar 综合搜索（匿名）+ j/search 分类翻页（登录）+ rexxar 详情。
/// 对齐 story_spider/douban_test 的 Python 实现。
class DoubanService {
  DoubanService._();
  static final DoubanService instance = DoubanService._();

  static const _mixSearchUrl = 'https://m.douban.com/rexxar/api/v2/search';
  static const _categorySearchUrl = 'https://www.douban.com/j/search';
  static const _detailUrl =
      'https://m.douban.com/rexxar/api/v2/{type}/{id}';
  static const _homeUrl = 'https://www.douban.com/';
  static const _loginPage = 'https://accounts.douban.com/passport/login';

  /// 分类搜索 cat 参数（网页版 search?cat=，demo 实测可用）
  static const catBook = '1001';
  static const catMovie = '1002'; // 电影 + 电视剧

  static const categoryPageSize = 20;

  static const _desktopUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const _refererByType = {
    'movie': 'https://movie.douban.com/',
    'tv': 'https://movie.douban.com/',
    'book': 'https://book.douban.com/',
  };

  /// 网页结果标签 -> rexxar 详情 type
  static const _labelToType = {
    '书籍': 'book',
    '电影': 'movie',
    '电视剧': 'tv',
  };

  /// 提取结果封面：懒加载页真实地址在 data-src，src 可能是占位图；
  /// 命中 blank/loading/pixel 等占位资源时回退另一个属性
  static String _pickCover(Element? imgEl) {
    if (imgEl == null) return '';
    bool isPlaceholder(String? url) =>
        url == null ||
        url.isEmpty ||
        RegExp(r'blank|loading|pixel|/icon/|\.gif', caseSensitive: false)
            .hasMatch(url);
    final dataSrc = imgEl.attributes['data-src'];
    final src = imgEl.attributes['src'];
    if (!isPlaceholder(dataSrc)) return dataSrc!;
    if (!isPlaceholder(src)) return src!;
    return dataSrc?.isNotEmpty == true ? dataSrc! : (src ?? '');
  }

  /// 登录 cookie（dbcl2/bid 等），空=匿名
  Map<String, String> _cookies = {};
  String _proxy = '';
  http.Client _client = http.Client();

  bool get isLoggedIn => _cookies.containsKey('dbcl2');

  /// 用已保存的凭证配置服务；[cookiesJson] 为 WebView 收割后持久化的 JSON
  void configure(String cookiesJson, {String proxy = ''}) {
    _cookies = _parseCookies(cookiesJson);
    if (proxy != _proxy) {
      _proxy = proxy;
      _client.close();
      _client = buildProxyClient(proxy);
    }
  }

  static Map<String, String> _parseCookies(String cookiesJson) {
    if (cookiesJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(cookiesJson);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  /// 测试登录态：带 cookie 请求分类搜索接口，200 即视为有效
  static Future<bool> testLogin(String cookiesJson,
      {String proxy = ''}) async {
    final cookies = _parseCookies(cookiesJson);
    if (!cookies.containsKey('dbcl2')) return false;
    final client = buildProxyClient(proxy);
    try {
      final uri = Uri.parse(_categorySearchUrl).replace(queryParameters: {
        'q': 'a',
        'cat': catMovie,
        'start': '0',
      });
      final resp = await client
          .get(uri, headers: _categoryHeaders(catMovie, 'a', cookies))
          .timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  Map<String, String> _cookieHeader() =>
      {'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ')};

  Map<String, String> _baseHeaders() => {
        'accept': 'application/json, text/plain, */*',
        'accept-language': 'zh-CN,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'origin': 'https://www.douban.com',
        'user-agent': _desktopUa,
        ..._cookieHeader(),
      };

  static Map<String, String> _categoryHeaders(
      String cat, String keyword, Map<String, String> cookies) {
    return {
      'accept': 'application/json, text/plain, */*',
      'referer':
          'https://www.douban.com/search?cat=$cat&q=${Uri.encodeQueryComponent(keyword)}',
      'x-requested-with': 'XMLHttpRequest',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-origin',
      'user-agent': _desktopUa,
      'Cookie':
          cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    };
  }

  /// 匿名访问首页让服务器种 bid（登录态已含 bid 时跳过）
  Future<void> _ensureBid() async {
    if (_cookies.containsKey('bid')) return;
    try {
      final resp = await _client
          .get(Uri.parse(_homeUrl), headers: {
            'user-agent': _desktopUa,
            'accept': 'text/html,application/xhtml+xml',
          })
          .timeout(const Duration(seconds: 10));
      final setCookie = resp.headers['set-cookie'];
      if (setCookie != null) {
        final match = RegExp(r'bid=([^;]+)').firstMatch(setCookie);
        if (match != null) _cookies['bid'] = match.group(1)!;
      }
    } catch (_) {
      // bid 缺失时 rexxar 仍可能放行，失败不阻塞
    }
  }

  /// 综合搜索（rexxar，匿名可用，仅首屏混合结果；音乐等 app 不支持的类型过滤掉）
  Future<List<DoubanSearchItem>> searchMix(String keyword) async {
    await _ensureBid();
    final uri = Uri.parse(_mixSearchUrl).replace(queryParameters: {
      'q': keyword,
      'type': '',
      'loc_id': '',
      'start': '0',
      'count': '20',
      'sort': 'relevance',
    });
    final data = await _getJson(uri, headers: {
      ..._baseHeaders(),
      'referer':
          'https://www.douban.com/search?q=${Uri.encodeQueryComponent(keyword)}',
    });
    final items =
        ((data['subjects'] as Map?)?['items'] as List?) ?? const [];
    final result = <DoubanSearchItem>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final targetType = raw['target_type']?.toString() ?? '';
      if (!const {'movie', 'tv', 'book'}.contains(targetType)) continue;
      final target = (raw['target'] as Map?) ?? const {};
      result.add(DoubanSearchItem(
        id: (raw['target_id'] ?? target['id'] ?? '').toString(),
        type: targetType,
        typeName: raw['type_name']?.toString() ?? targetType,
        title: target['title']?.toString() ?? '',
        subtitle: target['card_subtitle']?.toString() ?? '',
        coverUrl: target['cover_url']?.toString() ?? '',
        rating: (target['rating'] as Map?)?['value']?.toString() ?? '',
        year: target['year']?.toString() ?? '',
      ));
    }
    return result;
  }

  /// 分类翻页搜索（j/search，需登录）。返回 (条目列表, 总条数)
  Future<({List<DoubanSearchItem> items, int total})> searchCategory(
      String keyword, String cat, int start) async {
    if (!isLoggedIn) throw DoubanAuthException();
    final uri = Uri.parse(_categorySearchUrl).replace(queryParameters: {
      'q': keyword,
      'cat': cat,
      'start': '$start',
    });
    final data = await _getJson(
      uri,
      headers: _categoryHeaders(cat, keyword, _cookies),
    );
    final rawItems = data['items'];
    final itemList = rawItems is List ? rawItems : const [];
    final fragments = itemList.map((e) => e.toString()).join();
    final total = (data['total'] as num?)?.toInt() ?? 0;
    final fallbackType = cat == catBook ? 'book' : 'movie';
    final result = <DoubanSearchItem>[];
    final doc = html_parser.parse(fragments);
    final resultEls = doc.querySelectorAll('div.result');
    for (final el in resultEls) {
      final link = el.querySelector('h3 a');
      final tag = el.querySelector('h3 span');
      if (link == null) continue;
      final match = RegExp(r'sid:\s*(\d+)').firstMatch(
          link.attributes['onclick'] ?? '');
      if (match == null) continue;
      final label = (tag?.text.trim() ?? '').replaceAll(RegExp(r'[\[\]]'), '');
      final ratingEl = el.querySelector('.rating_nums');
      final castEl = el.querySelector('.subject-cast');
      final imgEl = el.querySelector('div.pic img');
      final cover = _pickCover(imgEl);
      result.add(DoubanSearchItem(
        id: match.group(1)!,
        type: _labelToType[label] ?? fallbackType,
        typeName: label.isNotEmpty ? label : fallbackType,
        title: link.text.trim(),
        subtitle: castEl?.text.trim() ?? '',
        coverUrl: cover,
        rating: ratingEl?.text.trim() ?? '',
      ));
    }
    return (items: result, total: total);
  }

  /// rexxar 详情（结构化 JSON；不覆盖游戏，游戏仍走原 HTML 抓取）
  Future<Map<String, dynamic>> getDetail(String type, String id) async {
    await _ensureBid();
    final uri = Uri.parse(
        _detailUrl.replaceFirst('{type}', type).replaceFirst('{id}', id));
    final data = await _getJson(uri, headers: {
      ..._baseHeaders(),
      'referer': _refererByType[type] ?? _homeUrl,
    });
    return data;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri,
      {required Map<String, String> headers}) async {
    http.Response resp;
    try {
      resp = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw DoubanNetworkException();
    } on SocketException {
      throw DoubanNetworkException();
    } on http.ClientException {
      throw DoubanNetworkException();
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw DoubanAuthException();
    }
    if (resp.statusCode != 200) throw DoubanNetworkException();
    try {
      return jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw DoubanNetworkException();
    }
  }

  /// 登录页地址，供 WebView 登录页使用
  static String get loginPage => _loginPage;
}
