import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/server_config.dart';
import '../utils/user_prefs.dart';
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import '../utils/image_path_helper.dart';
import '../utils/toast_util.dart';

/// 书籍详情页 - 在线版
class BookDetailPage extends StatefulWidget {
  final String bookId;
  const BookDetailPage({super.key, required this.bookId});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  Book? _localBook;
  String? _catalog;
  bool _catalogLoading = false;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _resolveCoverUrl(String cover) {
    if (cover.startsWith('http')) return cover;
    return '${ServerConfig.vipBaseUrl}/mk_book$cover';
  }

  Future<void> _load() async {
    final token = UserPrefs().bookSearchToken;
    try {
      final url = '${ServerConfig.vipBaseUrl}/api/book/detail?id=${widget.bookId}&token=$token';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final json_ = json.decode(resp.body);
        if (json_['code'] == 0 && json_['data'] != null) {
          setState(() {
            _data = json_['data'];
            _loading = false;
          });
          _checkLocal();
          _loadCatalog();
          return;
        }
      }
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _error = '网络错误';
        _loading = false;
      });
    }
  }

  void _checkLocal() {
    final title = _data?['title'] ?? '';
    if (title.toString().isEmpty) return;
    final provider = context.read<AppProvider>();
    final match = provider.books.where((b) => !b.isDeleted && b.title == title).toList();
    if (match.isNotEmpty) {
      setState(() => _localBook = match.first);
    }
  }

  String _decodeText(List<int> bytes) {
    if (bytes.length >= 2) {
      // UTF-16 LE BOM: FF FE
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        final codes = <int>[];
        for (var i = 2; i + 1 < bytes.length; i += 2) {
          codes.add(bytes[i] | (bytes[i + 1] << 8));
        }
        return String.fromCharCodes(codes);
      }
      // UTF-16 BE BOM: FE FF
      if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        final codes = <int>[];
        for (var i = 2; i + 1 < bytes.length; i += 2) {
          codes.add((bytes[i] << 8) | bytes[i + 1]);
        }
        return String.fromCharCodes(codes);
      }
    }
    // 无 BOM，按 UTF-16 LE 尝试（大部分中文 txt 是这种）
    if (bytes.length >= 2 && bytes.length % 2 == 0) {
      final codes = <int>[];
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        codes.add(bytes[i] | (bytes[i + 1] << 8));
      }
      final text = String.fromCharCodes(codes);
      // 检查解码结果是否包含大量不可打印字符（说明不是 UTF-16）
      final printable = text.runes.where((r) => r >= 0x20 && r < 0xFFFF).length;
      if (printable > text.length * 0.8) return text;
    }
    // fallback: UTF-8
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  Future<void> _loadCatalog() async {
    final bookmark = _data?['bookmark'] ?? '';
    if (bookmark.toString().isEmpty) return;
    setState(() => _catalogLoading = true);
    try {
      final bookmarkStr = bookmark.toString();
      final bookmarkUrl = bookmarkStr.startsWith('http')
          ? bookmarkStr
          : '${ServerConfig.vipBaseUrl}/mk_book/$bookmarkStr';
      final resp = await http.get(
        Uri.parse(bookmarkUrl),
        headers: {'Accept-Encoding': 'identity'},
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final bytes = resp.bodyBytes;
        final text = _decodeText(bytes);
        setState(() {
          _catalog = text;
          _catalogLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _catalogLoading = false);
  }

  Future<void> _addBook(String status) async {
    final m = _data!;
    final title = m['title'] ?? '';
    final author = m['author'] ?? '';
    final press = m['press'] ?? '';
    final isbn = m['isbn'] ?? '';
    final yearStr = m['publishedDate'] ?? '';
    final cover = m['cover'] ?? '';

    DateTime? publishDate;
    if (yearStr.toString().isNotEmpty) {
      publishDate = DateTime.tryParse('${yearStr}-01-01');
    }

    final bookId = const Uuid().v4();
    String? coverPath;

    if (cover.toString().isNotEmpty) {
      try {
        final coverUrl = _resolveCoverUrl(cover.toString());
        final resp = await http.get(Uri.parse(coverUrl), headers: {
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200 && resp.bodyBytes.length < 10 * 1024 * 1024) {
          final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = await ImagePathHelper.instance.getBookCoverPath(bookId, fileName);
          await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
          await File(targetPath).writeAsBytes(resp.bodyBytes);
          coverPath = targetPath;
        }
      } catch (_) {}
    }

    final book = Book(
      id: bookId,
      title: title.toString(),
      coverPath: coverPath,
      authors: _splitStr(author.toString()),
      publisher: press.toString(),
      isbn: isbn.toString(),
      publishDate: publishDate,
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.addBook(book);

    if (mounted) {
      setState(() {
        _localBook = provider.books.firstWhere((b) => b.id == book.id);
      });
      ToastUtil.show(context, '已添加到${_statusLabel(status)}');
    }
  }

  List<String> _splitStr(String s) => s
      .split(RegExp(r'[,，/、]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String _statusLabel(String status) {
    switch (status) {
      case 'read':
        return '已读';
      case 'reading':
        return '在读';
      case 'want_to_read':
        return '想读';
      default:
        return '';
    }
  }

  void _showAddSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
                child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                        color: colors.onSurface.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2)))),
            Text('添加到',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
            const SizedBox(height: 14),
            _sheetItem(ctx, colors, Icons.check_circle_outline, '已读', 'read'),
            _sheetItem(ctx, colors, Icons.play_circle_outline, '在读', 'reading'),
            _sheetItem(ctx, colors, Icons.bookmark_outline, '想读', 'want_to_read'),
          ]),
        ),
      ),
    );
  }

  Widget _sheetItem(BuildContext ctx, ColorScheme colors, IconData icon,
      String label, String status) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        _addBook(status);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Icon(icon, size: 22, color: colors.onSurface.withValues(alpha: 0.6)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface)),
        ]),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      floatingActionButton:
          (!_loading && _error == null && _localBook == null && _data != null)
              ? FloatingActionButton(
                  onPressed: _showAddSheet,
                  backgroundColor: colors.primary,
                  child: Icon(Icons.add, color: colors.onPrimary))
              : null,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
          : _error != null
              ? _buildError(colors)
              : _buildBody(colors),
    );
  }

  Widget _buildError(ColorScheme colors) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: colors.onSurface.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text(_error!, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        TextButton(
            onPressed: () {
              setState(() { _loading = true; _error = null; });
              _load();
            },
            child: Text('重试', style: TextStyle(color: colors.primary))),
      ],
    ));
  }

  Widget _buildBody(ColorScheme colors) {
    final m = _data!;
    final cover = m['cover'] ?? '';
    final title = m['title'] ?? '';
    final author = m['author'] ?? '';
    final press = m['press'] ?? '';
    final isbn = m['isbn'] ?? '';
    final year = m['publishedDate'] ?? '';
    final pages = m['pagination'];
    final coverUrl = cover.toString().isNotEmpty ? _resolveCoverUrl(cover.toString()) : '';

    return Column(children: [
      // 顶部固定区域
      Container(
        color: colors.surface,
        child: SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          shape: BoxShape.circle),
                      child: Icon(Icons.arrow_back, size: 20, color: colors.onSurface)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 110,
                        height: 160,
                        child: coverUrl.isNotEmpty
                            ? Image.network(coverUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _coverPlaceholder(colors))
                            : _coverPlaceholder(colors),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface)),
                            if (author.toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(author, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                            ],
                            if (press.toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(press, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45))),
                            ],
                            if (year.toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('出版年份：$year', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                            if (isbn.toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('ISBN：$isbn', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                            if (pages != null && pages != 0) ...[
                              const SizedBox(height: 4),
                              Text('页数：$pages', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                            if (_localBook != null) ...[
                              const SizedBox(height: 10),
                              _buildLocalStatus(colors),
                            ],
                          ]),
                    ),
                  ]),
            ),
          ]),
        ),
      ),

      // Tab 栏
      Container(
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
        child: Row(children: [
          _buildTabButton('基础信息', 0),
          _buildTabButton('国图信息', 1),
          _buildTabButton('网购地址', 2),
          _buildTabButton('书籍目录', 3),
        ]),
      ),

      // 内容区
      Expanded(
        child: _currentTab == 0
            ? _buildBasicInfo(colors)
            : _currentTab == 1
                ? _buildOpacTab(colors)
                : _currentTab == 2
                    ? _buildOnlineTab(colors)
                    : _buildCatalogTab(colors),
      ),
    ]);
  }

  Widget _buildTabButton(String label, int index) {
    final colors = Theme.of(context).colorScheme;
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: selected ? colors.primary : Colors.transparent,
                    width: 2))),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.4))),
      ),
    );
  }

  // ── 基础信息 Tab ──────────────────────────────────────────

  Widget _buildBasicInfo(ColorScheme colors) {
    final m = _data!;
    final tags = m['tags'] ?? '';
    final sub1 = m['sub1'] ?? '';
    final sub2 = m['sub2'] ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        // 分类
        _buildSectionTitle(colors, '分类', Icons.category_outlined),
        const SizedBox(height: 6),
        if (sub1.toString().isNotEmpty)
          _buildChipWrap(colors, sub1.toString().split(RegExp(r'[,，]')))
        else
          _buildEmptyHint(colors),
        const SizedBox(height: 16),
        // 标签
        _buildSectionTitle(colors, '标签', Icons.sell_outlined),
        const SizedBox(height: 6),
        if (tags.toString().isNotEmpty)
          _buildChipWrap(colors, tags.toString().split(RegExp(r'[,，]')))
        else
          _buildEmptyHint(colors),
        const SizedBox(height: 16),
        // 内容简介
        _buildSectionTitle(colors, '内容简介', Icons.article_outlined),
        const SizedBox(height: 8),
        if (sub2.toString().isNotEmpty)
          Text(sub2.toString().replaceAll(RegExp(r'<[^>]*>'), ''),
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7), height: 1.7))
        else
          _buildEmptyHint(colors),
      ],
    );
  }

  Widget _buildEmptyHint(ColorScheme colors) {
    return Text('暂无该信息数据',
        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3)));
  }

  // ── 国图信息 Tab ──────────────────────────────────────────

  Widget _buildOpacTab(ColorScheme colors) {
    final opacStr = _data?['opacInfo'];
    Map<String, dynamic>? opac;
    if (opacStr != null && opacStr.toString().isNotEmpty) {
      try { opac = json.decode(opacStr.toString()); } catch (_) {}
    }
    if (opac == null) {
      return Center(
          child: Text('暂无国图信息',
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        _buildOpacInfo(colors, opac),
      ],
    );
  }

  // ── 网购地址 Tab ──────────────────────────────────────────

  Widget _buildOnlineTab(ColorScheme colors) {
    final onlineStr = _data?['online'];
    List<Map<String, dynamic>> links = [];
    if (onlineStr != null && onlineStr.toString().isNotEmpty) {
      try {
        final list = json.decode(onlineStr.toString()) as List;
        links = list.map((e) => e as Map<String, dynamic>).toList();
      } catch (_) {}
    }
    if (links.isEmpty) {
      return Center(
          child: Text('暂无网购地址',
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      itemCount: links.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildOnlineLink(colors, links[index]),
    );
  }

  // ── 书籍目录 Tab ──────────────────────────────────────────

  Widget _buildCatalogTab(ColorScheme colors) {
    if (_catalogLoading) {
      return Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)));
    }
    if (_catalog == null || _catalog!.isEmpty) {
      return Center(
          child: Text('暂无目录信息',
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))));
    }
    final lines = _catalog!.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final text = lines[index].trim();
        final level = _detectLevel(text);
        final indent = level * 16.0;
        final isMain = level == 0;
        return Padding(
          padding: EdgeInsets.only(left: 8 + indent, top: isMain ? 10 : 4, bottom: isMain ? 2 : 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMain)
                Container(
                  width: 3, height: 14,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              Expanded(
                child: Text(text, style: TextStyle(
                  fontSize: isMain ? 13.5 : 12.5,
                  fontWeight: isMain ? FontWeight.w600 : FontWeight.w400,
                  color: isMain ? colors.onSurface.withValues(alpha: 0.85) : colors.onSurface.withValues(alpha: 0.55),
                  height: 1.4,
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 通用组件 ──────────────────────────────────────────────

  Widget _buildSectionTitle(ColorScheme colors, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: colors.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ],
    );
  }

  Widget _buildChipWrap(ColorScheme colors, List<String> items) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items.where((t) => t.trim().isNotEmpty).map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Text(t.trim(), style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.65))),
      )).toList(),
    );
  }

  Widget _buildOpacInfo(ColorScheme colors, Map<String, dynamic> opac) {
    final items = <List<String>>[];
    if (opac['title'] != null && opac['title'].toString().isNotEmpty) items.add(['题名', opac['title'].toString()]);
    if (opac['authors'] != null) {
      final authors = (opac['authors'] as List).map((e) => e.toString()).join('；');
      if (authors.isNotEmpty) items.add(['作者', authors]);
    }
    if (opac['publisher'] != null && opac['publisher'].toString().isNotEmpty) items.add(['出版社', opac['publisher'].toString()]);
    if (opac['pubdate'] != null && opac['pubdate'].toString().isNotEmpty) items.add(['出版日期', opac['pubdate'].toString()]);
    if (opac['isbn'] != null && opac['isbn'].toString().isNotEmpty) items.add(['ISBN', opac['isbn'].toString()]);
    if (opac['clc'] != null && opac['clc'].toString().isNotEmpty) items.add(['中图分类号', opac['clc'].toString()]);
    if (opac['tags'] != null && opac['tags'].toString().isNotEmpty) items.add(['主题词', opac['tags'].toString()]);

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: items.map((pair) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                child: Text(pair[0], style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              ),
              Expanded(
                child: Text(pair[1], style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.75), height: 1.4)),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildOnlineLink(ColorScheme colors, Map<String, dynamic> link) {
    final source = link['source'] ?? '';
    final url = link['url'] ?? '';
    if (source.toString().isEmpty || url.toString().isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url.toString()), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: colors.primary.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source.toString(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  const SizedBox(height: 2),
                  Text(url.toString(), style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  /// 检测目录层级：0=主章节, 1=子章节
  int _detectLevel(String line) {
    // 主章节：第X章、第X篇、Chapter X、数字+点开头（如 "1. "）
    if (RegExp(r'^第[一二三四五六七八九十百千\d]+[章篇部回卷]').hasMatch(line)) return 0;
    if (RegExp(r'^Chapter\s+\d+', caseSensitive: false).hasMatch(line)) return 0;
    if (RegExp(r'^\d+[\.\s、]').hasMatch(line)) return 0;
    if (RegExp(r'^[一二三四五六七八九十]+[、．.]').hasMatch(line)) return 0;
    // 子章节：第X节、数字.数字（如 "1.1 "）
    if (RegExp(r'^第[一二三四五六七八九十百千\d]+[节]').hasMatch(line)) return 1;
    if (RegExp(r'^\d+\.\d+[\.\s、]').hasMatch(line)) return 1;
    if (RegExp(r'^[（(]\d+[）)]').hasMatch(line)) return 1;
    if (line.startsWith('  ') || line.startsWith('\t')) return 1;
    // 默认主章节
    return 0;
  }

  Widget _coverPlaceholder(ColorScheme colors) {
    return Container(
        color: colors.surfaceContainerHighest,
        child: Center(
            child: Icon(Icons.menu_book_outlined,
                size: 32, color: colors.onSurface.withValues(alpha: 0.15))));
  }

  Widget _buildLocalStatus(ColorScheme colors) {
    final status = _localBook!.status;
    final label = _statusLabel(status);
    Color dotColor;
    switch (status) {
      case 'read':
        dotColor = colors.primary;
        break;
      case 'reading':
        dotColor = const Color(0xFF666666);
        break;
      default:
        dotColor = const Color(0xFF999999);
        break;
    }
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('已在本地 · $label',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(alpha: 0.6))),
    ]);
  }
}
