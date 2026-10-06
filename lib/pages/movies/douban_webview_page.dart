import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../widgets/app_overlay.dart';
import '../../utils/douban_parser.dart';
import '../../utils/steam_parser.dart';
import '../../l10n/app_strings.dart';

/// 豆瓣WebView页面 - 用于抓取 影视/书籍/游戏 信息
class DoubanWebViewPage extends StatefulWidget {
  final String url;

  /// 分类：movie / book / game
  final String category;

  /// 来源：douban / fanqie（番茄小说）
  final String source;

  const DoubanWebViewPage({
    super.key,
    required this.url,
    this.category = 'movie',
    this.source = 'douban',
  });

  @override
  State<DoubanWebViewPage> createState() => _DoubanWebViewPageState();
}

class _DoubanWebViewPageState extends State<DoubanWebViewPage> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _isExtracting = false; // 防止重复提取

  String _titleFor() {
    if (widget.source == 'fanqie') return '番茄阅读'.tr;
    if (widget.source == 'steam') return 'Steam'.tr;
    return switch (widget.category) {
      'book' => '豆瓣书籍'.tr,
      'game' => '豆瓣游戏'.tr,
      _ => '豆瓣影视'.tr,
    };
  }

  /// 豆瓣书籍/游戏可裸 GET 网页版解析；电影域名有反爬质询只能走页面内 JS
  bool get _isDoubanDirectFetch =>
      widget.source == 'douban' &&
      (widget.category == 'book' || widget.category == 'game');

  bool get _isDoubanSubject =>
      widget.source == 'douban' &&
      (widget.category == 'book' ||
          widget.category == 'movie' ||
          widget.category == 'game');

  /// 手机版链接转网页版：m.douban.com/book|movie|game/subject/xxx → 对应网页版
  ///（网页版元信息块结构规整，解析更稳）
  String get _effectiveUrl {
    if (widget.source != 'douban') return widget.url;
    if (widget.category == 'book') {
      return DoubanBookParser.normalizeSubjectUrl(widget.url) ?? widget.url;
    }
    if (widget.category == 'game') {
      return DoubanGameParser.normalizeSubjectUrl(widget.url) ?? widget.url;
    }
    if (widget.category == 'movie') {
      final m = RegExp(r'm\.douban\.com/movie/subject/(\d+)').firstMatch(widget.url);
      if (m != null) return 'https://movie.douban.com/subject/${m[1]}/';
    }
    return widget.url;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_titleFor()),
        leading: _buildBackButton(),
        actions: [
          // 提取按钮 - 始终显示
          _buildActionButton(
            colors: colors,
            icon: Icons.auto_fix_high_outlined,
            onPressed: _showExtractedInfo,
            tooltip: '提取信息'.tr,
          ),
          // 刷新按钮
          _buildActionButton(
            colors: colors,
            icon: Icons.refresh,
            onPressed: () => _controller?.reload(),
            tooltip: '刷新'.tr,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_effectiveUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              // 书籍/电影抓网页版需桌面 UA，否则豆瓣检测到移动端 UA 会重定向回 m.douban.com
              userAgent: _isDoubanSubject
                  ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                  : '',
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
            },
            onLoadStart: (_, __) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                });
              }
            },
            onLoadStop: (_, __) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
          // 加载指示器
          if (_isLoading) const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }

  /// 构建返回按钮
  Widget _buildBackButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 停止加载并返回
            _controller?.loadUrl(
                urlRequest: URLRequest(url: WebUri('about:blank')));
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  /// 构建右上角操作按钮
  Widget _buildActionButton({
    required ColorScheme colors,
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: colors.onSurface, size: 22),
          ),
        ),
      ),
    );
  }

  /// 显示提取的信息对话框
  Future<void> _showExtractedInfo() async {
    // 先提取信息
    final info = await _extractInfo();
    if (info == null) return;

    // 显示提取的信息
    if (mounted) {
      appDialog(
        context: context,
        builder: (ctx) {
          final colors = Theme.of(ctx).colorScheme;
          String valueOf(Object? v) =>
              v is List ? v.join(' / ') : v?.toString() ?? '';
          final isFanqie = widget.source == 'fanqie';
          // 按分类列出全部可提取字段，空值行跳过
          final List<(String, Object?)> fields = isFanqie
              ? [
                  ('书名'.tr, info['title']),
                  ('作者'.tr, info['author']),
                  ('类型'.tr, info['genres']),
                  ('简介'.tr, info['summary']),
                ]
              : switch (widget.category) {
                  'book' => [
                      ('标题'.tr, info['title']),
                      ('评分'.tr, info['rating']),
                      ('作者'.tr, info['author']),
                      ('译者'.tr, info['translator']),
                      ('出版社'.tr, info['publisher']),
                      ('出版日期'.tr, info['releaseDate']),
                      ('ISBN'.tr, info['isbn']),
                      ('类型'.tr, info['genres']),
                      ('简介'.tr, info['summary']),
                    ],
                  'game' => [
                      ('标题'.tr, info['title']),
                      ('评分'.tr, info['rating']),
                      ('开发者'.tr, info['developer']),
                      ('类型'.tr, info['genres']),
                      ('平台'.tr, info['platforms']),
                      ('日期'.tr, info['releaseDate']),
                      ('别名'.tr, info['alternateTitles']),
                      ('简介'.tr, info['summary']),
                    ],
                  _ => [
                      ('标题'.tr, info['title']),
                      ('评分'.tr, info['rating']),
                      ('导演'.tr, info['director']),
                      ('编剧'.tr, info['writers']),
                      ('主演'.tr, info['actors']),
                      ('类型'.tr, info['genres']),
                      ('上映日期'.tr, info['releaseDate']),
                      ('别名'.tr, info['alternateTitles']),
                      ('简介'.tr, info['summary']),
                    ],
                };
          final summaryLabel = '简介'.tr;
          final rows = <Widget>[
            for (final (label, value) in fields)
              if (valueOf(value).isNotEmpty)
                _buildInfoRow(colors, label,
                    label == summaryLabel ? _truncate(value) : valueOf(value)),
          ];
          if (rows.isEmpty) {
            rows.add(_buildInfoRow(colors, '标题'.tr, '未提取到'.tr));
          }
          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              '提取的信息'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rows,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  '取消'.tr,
                  style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, info);
                },
                child: Text(
                  '使用此信息'.tr,
                  style: TextStyle(
                      color: colors.onSurface, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  /// 构建信息行
  Widget _buildInfoRow(ColorScheme colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 提取信息（按分类选择抓取脚本）
  Future<Map<String, dynamic>?> _extractInfo() async {
    // 检查是否已提取过，避免重复点击
    if (_isExtracting || _controller == null) return null;

    try {
      _isExtracting = true;

      // 显示加载提示
      appDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 豆瓣书籍/游戏：优先直接 GET 网页版 HTML 解析（字段规整）；
      // 电影域名有反爬质询（sec.douban.com），裸请求拿不到，只能走页面内 JS 提取
      Map<String, dynamic>? movieInfo;
      if (widget.source == 'steam') {
        // 用 WebView 当前地址（用户可能在页面里跳转到了别的游戏）
        final currentUrl = (await _controller!.getUrl())?.toString() ?? widget.url;
        movieInfo = await SteamGameParser.fetch(currentUrl);
      } else if (_isDoubanDirectFetch) {
        // 用 WebView 当前地址（用户可能在页面里跳转到了别的条目）
        final currentUrl = (await _controller!.getUrl())?.toString() ?? widget.url;
        movieInfo = widget.category == 'game'
            ? await DoubanGameParser.fetch(currentUrl)
            : await DoubanBookParser.fetch(currentUrl);
      }
      if (movieInfo == null) {
        // 执行JavaScript代码提取页面信息
        final result = await _controller!.evaluateJavascript(source: _scriptFor(widget.source));

        // 解析提取的信息
        // evaluateJavascript 返回 JS 值，JSON.stringify 的结果是字符串
        final String jsonStr = result?.toString() ?? '';

        // 关闭加载提示
        if (mounted) Navigator.pop(context);

        if (jsonStr.isEmpty) return null;

        // result 是 JSON.stringify 的输出，可能带外层引号
        final String cleanJson = jsonStr.startsWith('"') && jsonStr.endsWith('"')
            ? jsonDecode(jsonStr) as String
            : jsonStr;
        return jsonDecode(cleanJson) as Map<String, dynamic>;
      }

      // 关闭加载提示
      if (mounted) Navigator.pop(context);

      return movieInfo;
    } catch (e) {
      // 关闭加载提示
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提取信息失败: {e}'.trf({'e': e}))),
        );
      }
      return null;
    } finally {
      _isExtracting = false;
    }
  }
/// 截断长文本用于信息预览
  String _truncate(Object? v) {
    final s = v?.toString() ?? '';
    return s.length > 100 ? '${s.substring(0, 100)}...' : s;
  }
}

/// 按来源/分类返回对应的抓取脚本
String _scriptFor(String source) {
  return switch (source) {
    'fanqie' => _fanqieScript,
    'steam' => _steamScript,
    'book' => _bookScript,
    'game' => _gameScript,
    _ => _movieScript,
  };
}

/// 影视抓取脚本（豆瓣网页版 subject 页为主，保留移动版回退）
/// 元信息解析与书籍一致：#info 按 <br> 分段，span.pl 为标签，
/// 段内 <a> 链接文本（排除"更多..."伪链接）或标签后的纯文本为值
const String _movieScript = r'''
        (function() {
          const info = {};
          const q = (s) => document.querySelector(s);
          const t = (el) => el ? el.textContent.trim() : '';

          // 标题（网页版 / 移动版回退）
          info.title = t(q('h1 span[property="v:itemreviewed"]')
            || q('#wrapper h1 span') || q('.sub-title') || q('h1'));

          // 封面（电影网页版 a 是"更多海报"链接，取 img src；webp → jpg）
          const coverEl = q('#mainpic img') || q('.sub-cover img');
          let coverUrl = coverEl ? coverEl.src : '';
          if (coverUrl && coverUrl.includes('.webp')) coverUrl = coverUrl.replace('.webp', '.jpg');
          info.coverUrl = coverUrl;

          // 评分
          info.rating = t(q('.rating_self strong') || q('.ll.rating_num')
            || q('.score-num') || q('.rating-num') || q('.score'));

          // 剧情简介（网页版 v:summary，开头常带全角空格缩进）
          let summary = t(q('span[property="v:summary"]') || q('.subject-intro p'));
          info.summary = summary.replace(/^[\s　]+/, '').substring(0, 1000);

          // 元信息块 #info：按 <br> 分段，span.pl 为标签，段内 <a> 文本
          //（排除 javascript: 伪链接如"更多..."）或标签后的纯文本为值
          const meta = {};
          const infoDiv = q('#info');
          if (infoDiv) {
            const tmp = document.createElement('div');
            infoDiv.innerHTML.split(/<br\s*\/?>/i).forEach(seg => {
              tmp.innerHTML = seg;
              const labelEl = tmp.querySelector('.pl');
              if (!labelEl) return;
              const label = labelEl.textContent.replace(/[:：\s]/g, '');
              if (!label) return;
              let values = Array.from(tmp.querySelectorAll('a'))
                .filter(a => !(a.getAttribute('href') || '').startsWith('javascript'))
                .map(a => a.textContent.trim()).filter(v => v);
              if (values.length === 0) {
                const rest = tmp.textContent.replace(labelEl.textContent, '').trim();
                if (rest) values = [rest];
              }
              if (values.length > 0) meta[label] = values;
            });
          }
          const pick = (k) => (meta[k] || []).join(' / ');

          info.director = pick('导演');
          info.writers = meta['编剧'] || [];
          info.actors = meta['主演'] || [];
          info.genres = pick('类型');

          // 上映日期（如 "2026-09-25(中国大陆)"）规整为 yyyy-MM-dd
          const dm = pick('上映日期').match(/(\d{4})(?:-(\d{1,2}))?(?:-(\d{1,2}))?/);
          info.releaseDate = dm
            ? dm[1] + '-' + (dm[2] || '01').padStart(2, '0') + '-' + (dm[3] || '01').padStart(2, '0')
            : '';

          // 又名 → 别名
          const aka = pick('又名');
          info.alternateTitles = aka ? aka.split('/').map(s => s.trim()).filter(Boolean) : [];

          return JSON.stringify(info);
        })()
      ''';

/// 书籍抓取脚本（豆瓣网页版 subject 页为主，保留移动版回退）
/// 元信息解析与参考 Python 版一致：#info 按 <br> 分段，span.pl 为标签，
/// 段内 <a> 链接文本或标签后的纯文本为值（作者/译者/出版社/出版年/ISBN/原作名）
const String _bookScript = r'''
        (function() {
          const info = {};
          const q = (s) => document.querySelector(s);
          const t = (el) => el ? el.textContent.trim() : '';

          // 标题（网页版 / 移动版回退）
          info.title = t(q('#wrapper h1 span') || q('h1 span') || q('.sub-title') || q('h1'));

          // 封面（webp → jpg，提高兼容性）
          const coverEl = q('#mainpic img') || q('.sub-cover img') || q('.nbg img');
          let coverUrl = coverEl ? coverEl.src : '';
          if (coverUrl && coverUrl.includes('.webp')) coverUrl = coverUrl.replace('.webp', '.jpg');
          info.coverUrl = coverUrl;

          // 评分
          info.rating = t(q('.rating_self strong') || q('.ll.rating_num')
            || q('.rating_num') || q('.score-num') || q('.score'));

          // 简介（网页版 #link-report 里短/全文并存，取最长的一段）
          let summary = '';
          document.querySelectorAll('#link-report .intro').forEach(el => {
            const v = el.textContent.trim();
            if (v.length > summary.length) summary = v;
          });
          if (!summary) summary = t(q('.section-intro_desc') || q('.subject-intro p') || q('.intro'));
          info.summary = summary.substring(0, 1000);

          // 元信息块 #info：按 <br> 分段，span.pl 为标签，段内 <a> 文本
          // 或标签后的纯文本为值
          const meta = {};
          const infoDiv = q('#info');
          if (infoDiv) {
            const tmp = document.createElement('div');
            infoDiv.innerHTML.split(/<br\s*\/?>/i).forEach(seg => {
              tmp.innerHTML = seg;
              const labelEl = tmp.querySelector('.pl');
              if (!labelEl) return;
              const label = labelEl.textContent.replace(/[:：\s]/g, '');
              if (!label) return;
              let values = Array.from(tmp.querySelectorAll('a'))
                .map(a => a.textContent.trim()).filter(v => v);
              if (values.length === 0) {
                const rest = tmp.textContent.replace(labelEl.textContent, '').trim();
                if (rest) values = [rest];
              }
              if (values.length > 0) meta[label] = values;
            });
          }
          const pick = (k) => (meta[k] || []).join(' / ');

          info.author = pick('作者');
          info.translator = pick('译者');
          info.publisher = pick('出版社');
          info.isbn = pick('ISBN');
          info.director = info.author; // 供提取预览弹窗"作者"行展示

          // 出版年（如 "2026-7" / "2026-7-1"）规整为 yyyy-MM-dd，供 Dart DateTime.parse
          const dm = pick('出版年').match(/(\d{4})(?:-(\d{1,2}))?(?:-(\d{1,2}))?/);
          info.releaseDate = dm
            ? dm[1] + '-' + (dm[2] || '01').padStart(2, '0') + '-' + (dm[3] || '01').padStart(2, '0')
            : '';

          // 原作名 → 别名
          info.alternateTitles = pick('原作名') ? [pick('原作名')] : [];

          // 类型标签（网页版 / 移动版回退）
          const tags = [];
          document.querySelectorAll('#db-tags-section .tag a, .sub-tags a, .tags a').forEach(el => {
            const v = el.textContent.trim();
            if (v) tags.push(v);
          });
          info.genres = tags.join(',');

          return JSON.stringify(info);
        })()
      ''';

/// 游戏抓取脚本（豆瓣 www.douban.com/game 桌面页为主，保留移动版回退）
/// 元信息为 dl.thing-attr：dt 为标签，dd 内 <a> 链接文本或纯文本为值
///（类型里首条通用"游戏"链接除外）
const String _gameScript = r'''
        (function() {
          const info = {};
          const q = (s) => document.querySelector(s);
          const t = (el) => el ? el.textContent.trim() : '';

          // 标题（桌面版 #content h1 / 移动版回退）
          info.title = t(q('#content h1') || q('.card h1.title')
            || q('h1.title') || q('.sub-title') || q('h1'));

          // 封面（.pic 内 a 的 href 是大图，img src 兜底；webp → jpg）
          const picA = q('.item-subject-info .pic a') || q('.pic a');
          const coverEl = q('.item-subject-info .pic img') || q('.pic img')
            || q('.subject-info .cover') || q('.sub-cover img') || q('#mainpic img');
          let coverUrl = picA ? (picA.getAttribute('href') || '')
            : (coverEl ? coverEl.src : '');
          if (coverUrl && coverUrl.includes('.webp')) coverUrl = coverUrl.replace('.webp', '.jpg');
          info.coverUrl = coverUrl;

          // 评分
          info.rating = t(q('.rating_self strong') || q('.ll.rating_num')
            || q('.subject-info .rating strong') || q('.score-num') || q('.rating-num'));

          // 简介（桌面版 #link-report 第一个 p / 移动版回退）
          let summary = t(q('#link-report p'));
          if (!summary) summary = t(q('.subject-intro .bd p') || q('.section-intro_desc')
            || q('.subject-intro p') || q('.intro'));
          info.summary = summary.replace(/^[\s　]+/, '').substring(0, 1000);

          // 元信息 dl.thing-attr：dt 标签 + dd 值
          const meta = {};
          document.querySelectorAll('dl.thing-attr dt').forEach(dt => {
            const dd = dt.nextElementSibling;
            if (!dd || dd.tagName !== 'DD') return;
            const label = dt.textContent.replace(/[:：\s]/g, '');
            if (!label) return;
            let values = Array.from(dd.querySelectorAll('a'))
              .filter(a => !(a.getAttribute('href') || '').startsWith('javascript'))
              .map(a => a.textContent.trim()).filter(v => v);
            if (values.length === 0) {
              const rest = dd.textContent.trim();
              if (rest) values = [rest];
            }
            if (values.length > 0) meta[label] = values;
          });
          const pick = (k) => (meta[k] || []).join(' / ');

          // 类型：剔除通用"游戏"链接（href="/game/explore"）
          info.genres = (meta['类型'] || []).filter(v => v !== '游戏').join(',');
          info.platforms = (meta['平台'] || []).join(',');
          info.alternateTitles = meta['别名'] || [];
          info.developer = pick('开发商');

          // 发行日期（无则退 预计上市时间）规整为 yyyy-MM-dd
          const dateSrc = pick('发行日期') || pick('预计上市时间');
          const dm = dateSrc.match(/(\d{4})(?:-(\d{1,2}))?(?:-(\d{1,2}))?/);
          info.releaseDate = dm
            ? dm[1] + '-' + (dm[2] || '01').padStart(2, '0') + '-' + (dm[3] || '01').padStart(2, '0')
            : '';

          return JSON.stringify(info);
        })()
      ''';

/// Steam 商店页抓取脚本（store.steampowered.com/app/xxx 页面内兜底提取）
/// 字段与 SteamGameParser 输出一致；开发者/发行商/类型/平台返回数组
const String _steamScript = r'''
        (function() {
          const info = {};
          const q = (s) => document.querySelector(s);
          const t = (el) => el ? el.textContent.trim() : '';

          // 标题 / 封面 / 简介
          info.title = t(q('#appHubAppName'));
          const coverEl = q('.game_header_image_full');
          info.coverUrl = coverEl ? coverEl.src : '';
          info.summary = t(q('.game_description_snippet')).substring(0, 1000);

          // 发行日期：「2023 年 5 月 26 日」规整为 yyyy-MM-dd
          const dm = t(q('.release_date .date'))
            .match(/(\d{4})\s*年\s*(\d{1,2})\s*月\s*(?:(\d{1,2})\s*日)?/);
          info.releaseDate = dm
            ? dm[1] + '-' + dm[2].padStart(2, '0') + '-' + (dm[3] || '01').padStart(2, '0')
            : '';

          // 开发者 / 发行商（dev_row：subtitle 标签 + summary 内 <a>）
          const rows = {};
          document.querySelectorAll('.dev_row').forEach(row => {
            const label = t(row.querySelector('.subtitle')).replace(/[:：\s]/g, '');
            const vals = Array.from(row.querySelectorAll('.summary a'))
              .map(a => a.textContent.trim()).filter(Boolean);
            if (label && vals.length > 0) rows[label] = vals;
          });
          info.developer = rows['开发者'] || [];
          info.publisher = rows['发行商'] || [];

          // 用户标签作为类型（前 5 个，剔除 "+"）
          const tags = [];
          document.querySelectorAll('.app_tag').forEach(a => {
            const v = a.textContent.trim();
            if (v && v !== '+' && !tags.includes(v)) tags.push(v);
          });
          info.genres = tags.slice(0, 5);

          // 平台图标
          const platforms = [];
          if (q('.platform_img.win')) platforms.push('Windows');
          if (q('.platform_img.mac')) platforms.push('macOS');
          if (q('.platform_img.linux')) platforms.push('SteamOS + Linux');
          info.platforms = platforms;

          return JSON.stringify(info);
        })()
      ''';

/// 番茄小说抓取脚本（fanjienovel.com 书籍页）
const String _fanqieScript = r'''
        (function() {
          const info = {};
          const q = (s) => { const el = document.querySelector(s); return el ? el.textContent.trim() : ''; };

          // 书名
          info.title = q('h1.info-name');

          // 作者（如 "骁骑校 / 著"）
          info.author = q('div.info-author');

          // 封面
          const coverEl = document.querySelector('img.page-header-img');
          info.coverUrl = coverEl ? coverEl.src : '';

          // 简介
          const summaryEl = document.querySelector('.abstract-content-text p')
            || document.querySelector('.abstract-content-text')
            || document.querySelector('.abstract-content');
          info.summary = summaryEl ? summaryEl.textContent.trim().substring(0, 1000) : '';

          // 标签
          const tagEls = document.querySelectorAll('.category-item');
          const genres = [];
          tagEls.forEach(el => { const t = el.textContent.trim(); if (t) genres.push(t); });
          info.genres = genres.join(',');

          return JSON.stringify(info);
        })()
      ''';
