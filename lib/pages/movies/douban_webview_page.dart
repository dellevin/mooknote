import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../widgets/app_overlay.dart';

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
    if (widget.source == 'fanqie') return '番茄阅读';
    return switch (widget.category) {
      'book' => '豆瓣书籍',
      'game' => '豆瓣游戏',
      _ => '豆瓣影视',
    };
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
            tooltip: '提取信息',
          ),
          // 刷新按钮
          _buildActionButton(
            colors: colors,
            icon: Icons.refresh,
            onPressed: () => _controller?.reload(),
            tooltip: '刷新',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
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

    final secondaryLabel = switch (widget.category) {
      'book' => '作者',
      'game' => '开发商',
      _ => '导演',
    };

    // 显示提取的信息
    if (mounted) {
      appDialog(
        context: context,
        builder: (ctx) {
          final colors = Theme.of(ctx).colorScheme;
          final isFanqie = widget.source == 'fanqie';
          final rows = isFanqie
              ? <Widget>[
                  _buildInfoRow(colors, '书名', info['title']?.toString() ?? '未提取到'),
                  _buildInfoRow(colors, '作者', info['author']?.toString() ?? '未提取到'),
                  _buildInfoRow(colors, '类型', info['genres']?.toString() ?? '未提取到'),
                  if (info['summary'] != null)
                    _buildInfoRow(colors, '简介', _truncate(info['summary'])),
                ]
              : <Widget>[
                  _buildInfoRow(colors, '标题', info['title']?.toString() ?? '未提取到'),
                  _buildInfoRow(colors, '评分', info['rating']?.toString() ?? '未提取到'),
                  _buildInfoRow(colors, secondaryLabel, info['director']?.toString() ?? '未提取到'),
                  _buildInfoRow(colors, '类型', info['genres']?.toString() ?? '未提取到'),
                  _buildInfoRow(colors, '日期', info['releaseDate']?.toString() ?? '未提取到'),
                  if (info['summary'] != null)
                    _buildInfoRow(colors, '简介', _truncate(info['summary'])),
                ];
          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(
              '提取的信息',
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
                  '取消',
                  style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, info);
                },
                child: Text(
                  '使用此信息',
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

      // 执行JavaScript代码提取页面信息
      final result = await _controller!.evaluateJavascript(source: _scriptFor(widget.source));

      // 关闭加载提示
      if (mounted) Navigator.pop(context);

      // 解析提取的信息
      // evaluateJavascript 返回 JS 值，JSON.stringify 的结果是字符串
      final String jsonStr = result?.toString() ?? '';
      if (jsonStr.isEmpty) return null;

      // result 是 JSON.stringify 的输出，可能带外层引号
      final String cleanJson = jsonStr.startsWith('"') && jsonStr.endsWith('"')
          ? jsonDecode(jsonStr) as String
          : jsonStr;
      final Map<String, dynamic> movieInfo = jsonDecode(cleanJson) as Map<String, dynamic>;

      return movieInfo;
    } catch (e) {
      // 关闭加载提示
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提取信息失败: $e')),
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
    'book' => _bookScript,
    'game' => _gameScript,
    _ => _movieScript,
  };
}

/// 影视抓取脚本（移动版豆瓣 subject 页）
const String _movieScript = r'''
        (function() {
          const info = {};

          // 获取标题 - 移动版页面
          const titleEl = document.querySelector('.sub-title');
          info.title = titleEl ? titleEl.textContent.trim() : '';

          // 获取年份 - 从 original-title 中提取
          const originalTitleEl = document.querySelector('.sub-original-title');
          if (originalTitleEl) {
            const yearMatch = originalTitleEl.textContent.match(/\((\d{4})\)/);
            info.year = yearMatch ? yearMatch[1] : '';
          } else {
            info.year = '';
          }

          // 获取封面图 - 从 sub-cover 中的 img 标签获取
          const coverEl = document.querySelector('.sub-cover img');
          if (coverEl) {
            let coverUrl = coverEl.src;
            // 将 webp 转换为 jpg 格式，提高兼容性
            if (coverUrl && coverUrl.includes('.webp')) {
              coverUrl = coverUrl.replace('.webp', '.jpg');
            }
            info.coverUrl = coverUrl;
          } else {
            info.coverUrl = '';
          }

          // 获取评分 - 移动版可能在 mark-item 中
          const ratingEl = document.querySelector('.score-num')
            || document.querySelector('.rating-num')
            || document.querySelector('.score');
          info.rating = ratingEl ? ratingEl.textContent.trim() : '';

          // 获取导演 - 从演职员列表中找
          const directorEl = document.querySelector('.movie-celebrities .item__celebrity .role');
          if (directorEl && directorEl.textContent.includes('导演')) {
            const nameEl = directorEl.closest('.item__celebrity').querySelector('.name');
            info.director = nameEl ? nameEl.textContent.trim() : '';
          } else {
            info.director = '';
          }

          // 获取编剧 - 从演职员列表中找（匹配"编剧"或"剧本"）
          const writerEls = document.querySelectorAll('.movie-celebrities .item__celebrity');
          const writers = [];
          writerEls.forEach(el => {
            const roleEl = el.querySelector('.role');
            if (roleEl && (roleEl.textContent.includes('编剧') || roleEl.textContent.includes('剧本'))) {
              const nameEl = el.querySelector('.name');
              if (nameEl) writers.push(nameEl.textContent.trim());
            }
          });
          info.writers = writers;

          // 获取主演- 从演职员列表中找前5个
          const actorEls = document.querySelectorAll('.movie-celebrities .item__celebrity');
          const actors = [];
          actorEls.forEach(el => {
            const roleEl = el
            .querySelector('.role');
            if (roleEl && (
            roleEl.textContent.includes('配音') ||
            roleEl.textContent.includes('主演') ||
            roleEl.textContent.includes('演员') ||
            roleEl.textContent.includes('参演') ||
            roleEl.textContent.includes('饰')
            )) {
              const nameEl = el.querySelector('.name');
              if (nameEl) actors.push(nameEl.textContent.trim());
            }
          });
          info.actors = actors;

          // 获取类型 - 从 sub-meta 或标签中提取
          const metaEl = document.querySelector('.sub-meta');
          if (metaEl) {
            const metaText = metaEl.textContent;
            const parts = metaText.split('/').map(s => s.trim());
            // 过滤出类型（通常是中文，不是日期，不是时长）
            info.genres = parts.filter(p =>
              p && !p.match(/^\d{4}/) && !p.includes('分钟') && !p.includes('上映')
            ).join(',');
          } else {
            info.genres = '';
          }

          // 获取上映日期
          if (metaEl) {
            const dateMatch = metaEl.textContent.match(/(\d{4}-\d{2}-\d{2})/);
            info.releaseDate = dateMatch ? dateMatch[1] : '';
          } else {
            info.releaseDate = '';
          }

          // 获取简介
          const summaryEl = document.querySelector('.subject-intro p');
          if (summaryEl) {
            info.summary = summaryEl.textContent.trim().substring(0, 500);
          } else {
            info.summary = '';
          }

          // 获取别名 - 从 original-title 中提取（去掉年份）
          if (originalTitleEl) {
            const fullText = originalTitleEl.textContent.trim();
            info.alternateTitles = [fullText.replace(/\s*\(\d{4}\)\s*$/, '')];
          } else {
            info.alternateTitles = [];
          }

          return JSON.stringify(info);
        })()
      ''';

/// 书籍抓取脚本（豆瓣 subject 页，兼容移动版/网页版）
const String _bookScript = r'''
        (function() {
          const info = {};

          // 标题（多种结构回退）
          const titleEl = document.querySelector('.sub-title')
            || document.querySelector('h1[property="v:itemreviewed"]')
            || document.querySelector('.title h1')
            || document.querySelector('h1');
          info.title = titleEl ? titleEl.textContent.trim() : '';

          // 封面（多种结构回退）
          const coverEl = document.querySelector('.sub-cover img')
            || document.querySelector('#mainpic img')
            || document.querySelector('.nbg img')
            || document.querySelector('.pic img');
          if (coverEl) {
            let coverUrl = coverEl.src;
            if (coverUrl && coverUrl.includes('.webp')) {
              coverUrl = coverUrl.replace('.webp', '.jpg');
            }
            info.coverUrl = coverUrl;
          } else {
            info.coverUrl = '';
          }

          // 评分
          const ratingEl = document.querySelector('.score-num')
            || document.querySelector('.rating-num')
            || document.querySelector('.score')
            || document.querySelector('.rating_self strong')
            || document.querySelector('.ll.rating_num');
          info.rating = ratingEl ? ratingEl.textContent.trim() : '';

          // 简介（网页版为 section-intro_desc，另加多级回退）
          const summaryEl = document.querySelector('.section-intro_desc')
            || document.querySelector('.subject-intro p')
            || document.querySelector('#link-report .intro')
            || document.querySelector('.intro');
          info.summary = summaryEl ? summaryEl.textContent.trim().substring(0, 1000) : '';

          // 副标题/别名
          const originalTitleEl = document.querySelector('.sub-original-title')
            || document.querySelector('h2');
          info.alternateTitles = originalTitleEl ? [originalTitleEl.textContent.trim()] : [];

          // 元信息：作者 / 译者 / 出版社 / 出版日期 / ISBN / 类型
          const metaEl = document.querySelector('.sub-meta')
            || document.querySelector('#info')
            || document.querySelector('.pub');
          const metaText = metaEl ? metaEl.textContent.replace(/\s+/g, ' ').trim() : '';
          info.director = metaText; // 暂存整行，供解析
          info.author = '';
          info.translator = '';
          info.publisher = '';
          info.releaseDate = '';
          info.isbn = '';
          info.genres = '';

          if (metaText) {
            // 作者
            const authorMatch = metaText.match(/作者[:\s]*([^\/\n]+?)(?:\s*译者|\s*出版社|\s*出版年|\s*页数|\s*定价|\s*装帧|\s*丛书|\s*ISBN|$)/);
            if (authorMatch) info.author = authorMatch[1].trim();

            // 译者
            const translatorMatch = metaText.match(/译者[:\s]*([^\/\n]+?)(?:\s*出版社|\s*出版年|\s*页数|\s*定价|\s*装帧|\s*丛书|\s*ISBN|$)/);
            if (translatorMatch) info.translator = translatorMatch[1].trim();

            // 出版社
            const publisherMatch = metaText.match(/出版社[:\s]*([^\/\n]+?)(?:\s*出版年|\s*页数|\s*定价|\s*装帧|\s*丛书|\s*ISBN|$)/);
            if (publisherMatch) info.publisher = publisherMatch[1].trim();

            // 出版日期 / 年份
            const dateMatch = metaText.match(/\d{4}-\d{1,2}(-\d{1,2})?/);
            if (dateMatch) info.releaseDate = dateMatch[0];

            // ISBN
            const isbnMatch = metaText.match(/ISBN[:\s]*([\dXx-]+)/);
            if (isbnMatch) info.isbn = isbnMatch[1].trim();

            // 类型标签
            const tagEls = document.querySelectorAll('.sub-tags a, .tags a, .tagCrumb a');
            const tags = [];
            tagEls.forEach(el => {
              const t = el.textContent.trim();
              if (t) tags.push(t);
            });
            info.genres = tags.join(',');
          }

          return JSON.stringify(info);
        })()
      ''';

/// 游戏抓取脚本（豆瓣 game subject 页 card 结构）
const String _gameScript = r'''
        (function() {
          const info = {};

          // 标题：card 内的 title
          const titleEl = document.querySelector('.card h1.title')
            || document.querySelector('h1.title')
            || document.querySelector('.sub-title')
            || document.querySelector('h1[property="v:itemreviewed"]');
          info.title = titleEl ? titleEl.textContent.trim() : '';

          // 封面：subject-info 内的 cover 图
          const coverEl = document.querySelector('.subject-info .cover')
            || document.querySelector('.sub-cover img')
            || document.querySelector('#mainpic img');
          if (coverEl) {
            let coverUrl = coverEl.src;
            if (coverUrl && coverUrl.includes('.webp')) {
              coverUrl = coverUrl.replace('.webp', '.jpg');
            }
            info.coverUrl = coverUrl;
          } else {
            info.coverUrl = '';
          }

          // 评分：subject-info 内 rating 的 strong
          const ratingEl = document.querySelector('.subject-info .rating strong')
            || document.querySelector('.score-num')
            || document.querySelector('.rating-num');
          info.rating = ratingEl ? ratingEl.textContent.trim() : '';

          // 简介：subject-intro 内 bd 的 p
          const summaryEl = document.querySelector('.subject-intro .bd p')
            || document.querySelector('.section-intro_desc')
            || document.querySelector('.subject-intro p')
            || document.querySelector('.intro');
          info.summary = summaryEl ? summaryEl.textContent.trim().substring(0, 1000) : '';

          // 元信息：subject-info 内 meta（斜杠分隔：类型 / 平台 / 发行日期）
          const metaEl = document.querySelector('.subject-info .meta')
            || document.querySelector('.sub-meta');
          const metaText = metaEl ? metaEl.textContent.replace(/\s+/g, ' ').trim() : '';
          info.director = metaText; // 暂存整行，供解析
          info.developer = '';
          info.platforms = '';
          info.releaseDate = '';
          info.genres = '';

          if (metaText) {
            // 发行日期（通常在最末尾，如 "2020-07-08 发行"）
            const dateMatch = metaText.match(/\d{4}-\d{1,2}(-\d{1,2})?/);
            if (dateMatch) info.releaseDate = dateMatch[0];

            // 按 / 切分，过滤空段和日期段
            const parts = metaText.split('/').map(s => s.trim()).filter(s => s && !s.match(/^\d{4}/));
            const platformNames = ['pc','ps4','ps5','psp','psv','ps3','ps2','xbox one','xbox series','xsx','xss','xbox 360','switch','wii u','wii','3ds','nds','nes','snes','steam','epic','itunes','ios','android','google play','itunes store','web','街机','街机盒'];
            const genres = [];
            const platforms = [];
            parts.forEach(p => {
              const lower = p.toLowerCase();
              if (platformNames.some(n => lower.includes(n))) {
                platforms.push(p);
              } else {
                genres.push(p);
              }
            });

            // 孤立的日期年份（如 "2020"）单列给 releaseDate
            if (!info.releaseDate) {
              const yearMatch = metaText.match(/\b(19|20)\d{2}\b/);
              if (yearMatch) info.releaseDate = yearMatch[0] + '-01-01';
            }

            info.genres = genres.join(',');
            info.platforms = platforms.join(',');
          }

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
