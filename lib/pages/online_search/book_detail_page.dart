import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../utils/server_config.dart';
import '../../utils/user_prefs.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/cover_network_image.dart';
import '../../services/douban_service.dart';
import '../../l10n/app_strings.dart';
import '../../utils/status_labels.dart';

/// 书籍详情页 - 在线版（对接 my_sys /book/detail 网络小说爬虫接口）
class BookDetailPage extends StatefulWidget {
  final String bookId;
  const BookDetailPage({super.key, required this.bookId});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _chapters = [];
  bool _loading = true;
  bool _catalogLoading = false;
  String? _error;
  Book? _localBook;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = UserPrefs().bookSearchToken;
    try {
      final url = '${ServerConfig.cloudApiBase}/book/detail?id=${widget.bookId}&token=$token';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final json_ = json.decode(utf8.decode(resp.bodyBytes));
        if (json_['code'] == 0 && json_['data'] != null) {
          final data = json_['data'] as Map<String, dynamic>;
          setState(() {
            _data = data;
            _chapters = _parseChapters(data['chapters']);
            _loading = false;
          });
          _checkLocal();
          if (_chapters.isEmpty) _loadCatalog();
          return;
        }
      }
      setState(() {
        _error = '加载失败'.tr;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '网络错误'.tr;
          _loading = false;
        });
      }
    }
  }

  /// 详情未带章节时，请求独立目录接口兜底
  Future<void> _loadCatalog() async {
    final token = UserPrefs().bookSearchToken;
    setState(() => _catalogLoading = true);
    try {
      final url = '${ServerConfig.cloudApiBase}/book/catalog?id=${widget.bookId}&token=$token';
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final json_ = json.decode(utf8.decode(resp.bodyBytes));
        if (json_['code'] == 0 && json_['data'] != null) {
          setState(() {
            _chapters = _parseChapters(json_['data']['chapters']);
            _catalogLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _catalogLoading = false);
  }

  /// 章节兼容两种格式：bqg 为纯标题字符串，bqglll/catalog 为 {id,title,url} 对象
  List<Map<String, dynamic>> _parseChapters(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return {'title': e.toString()};
    }).toList();
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

  Future<void> _addBook(String status) async {
    final m = _data!;
    final title = m['title'] ?? '';
    final author = m['author'] ?? '';
    final intro = m['intro'] ?? '';
    final sortname = m['sortname'] ?? '';
    final cover = m['cover'] ?? '';

    final bookId = const Uuid().v4();
    String? coverPath;

    if (cover.toString().isNotEmpty) {
      try {
        final resp = await http.get(
            Uri.parse(cover.toString()),
            headers: cover.toString().contains('doubanio.com')
                ? doubanImageHeaders
                : {'User-Agent': 'Mozilla/5.0'}
        ).timeout(const Duration(seconds: 15));
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
      genres: _splitStr(sortname.toString()),
      summary: intro.toString().isNotEmpty ? intro.toString() : null,
      status: status,
      category: 'novel',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.addBook(book);
    await provider.loadBooks();

    if (mounted) {
      setState(() {
        _localBook = provider.books.firstWhere((b) => b.id == book.id);
      });
      ToastUtil.show(context, '已添加到{status}'.trf({'status': _statusLabel(status)}));
    }
  }

  List<String> _splitStr(String s) => s
      .split(RegExp(r'[,，/、]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String _statusLabel(String status) {
    if (!StatusLabels.defaults['book']!.containsKey(status)) return '';
    return StatusLabels.label('book', status);
  }

  void _showAddSheet() {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
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
            Text('添加到'.tr,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface)),
            const SizedBox(height: 14),
            _sheetItem(ctx, colors, Icons.check_circle_outline, StatusLabels.label('book', 'read'), 'read'),
            _sheetItem(ctx, colors, Icons.play_circle_outline, StatusLabels.label('book', 'reading'), 'reading'),
            _sheetItem(ctx, colors, Icons.bookmark_outline, StatusLabels.label('book', 'want_to_read'), 'want_to_read'),
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
            child: Text('重试'.tr, style: TextStyle(color: colors.primary))),
      ],
    ));
  }

  bool get _isFinished => (_data?['full'] ?? '').toString().contains('完');

  Widget _buildBody(ColorScheme colors) {
    final m = _data!;
    final cover = (m['cover'] ?? '').toString();
    final title = (m['title'] ?? '').toString();
    final author = (m['author'] ?? '').toString();
    final source = (m['source'] ?? '').toString();
    final lastchapter = (m['lastchapter'] ?? '').toString();
    final lastupdate = (m['lastupdate'] ?? '').toString();

    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(children: [
        // 头部：返回按钮 + 封面信息
        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                AppBackButton(color: colors.onSurface, size: 15),
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
                        child: CoverNetworkImage(
                            url: cover,
                            placeholder: _coverPlaceholder(colors)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface)),
                            if (author.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(author, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6))),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildHeaderTag(
                                  _isFinished ? '已完结'.tr : '连载中'.tr,
                                  _isFinished ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
                                ),
                                if (source.isNotEmpty)
                                  _buildHeaderTag(source, colors.onSurface.withValues(alpha: 0.5)),
                              ],
                            ),
                            if (lastchapter.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('最新章节：{c}'.trf({'c': lastchapter}),
                                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                            if (lastupdate.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('更新：{t}'.trf({'t': lastupdate}),
                                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
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
        // Tab 栏
        Container(
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                  bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
          child: Row(children: [
            _buildTabButton('书籍信息'.tr, 0),
            _buildTabButton('书籍目录'.tr, 1),
          ]),
        ),
        // Tab 内容
        Expanded(
          child: _currentTab == 0
              ? _buildInfoTab(colors)
              : _buildCatalogTab(colors),
        ),
      ]),
    );
  }

  Widget _buildHeaderTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color)),
    );
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

  // ── 书籍信息 Tab ──────────────────────────────────────────

  Widget _buildInfoTab(ColorScheme colors) {
    final m = _data!;
    final intro = (m['intro'] ?? '').toString();
    final sortname = (m['sortname'] ?? '').toString();
    final source = (m['source'] ?? '').toString();
    final lastchapter = (m['lastchapter'] ?? '').toString();
    final lastupdate = (m['lastupdate'] ?? '').toString();

    final meta = <List<String>>[
      if (sortname.isNotEmpty) ['分类'.tr, sortname],
      if (source.isNotEmpty) ['来源'.tr, source],
      if (lastchapter.isNotEmpty) ['最新章节'.tr, lastchapter],
      if (lastupdate.isNotEmpty) ['更新时间'.tr, lastupdate],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      children: [
        if (meta.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: meta.map((pair) => Padding(
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
          ),
          const SizedBox(height: 16),
        ],
        _buildSectionTitle(colors, '内容简介'.tr, Icons.article_outlined),
        const SizedBox(height: 8),
        if (intro.isNotEmpty)
          Text(intro,
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.7), height: 1.7))
        else
          _buildEmptyHint(colors),
      ],
    );
  }

  Widget _buildEmptyHint(ColorScheme colors) {
    return Text('暂无该信息数据'.tr,
        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3)));
  }

  // ── 书籍目录 Tab ──────────────────────────────────────────

  Widget _buildCatalogTab(ColorScheme colors) {
    if (_catalogLoading) {
      return Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)));
    }
    if (_chapters.isEmpty) {
      return Center(
          child: Text('暂无目录信息'.tr,
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
      itemCount: _chapters.length,
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final title = (chapter['title'] ?? '').toString();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 3, height: 14,
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Expanded(
                child: Text(title, style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface.withValues(alpha: 0.75),
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
    final dotColor = AppTheme.statusDotColor(colors, status);
    return Row(children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text('已在本地 · {label}'.trf({'label': label}),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.onSurface.withValues(alpha: 0.6))),
    ]);
  }
}
