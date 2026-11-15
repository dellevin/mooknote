import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../l10n/app_strings.dart';
import '../../services/douban_service.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/douban_network_image.dart';

/// 豆瓣详情页：拉取 rexxar 结构化详情，映射到现有 movie/book 表单 prefill 入库
class DoubanDetailPage extends StatefulWidget {
  final DoubanSearchItem item;

  const DoubanDetailPage({super.key, required this.item});

  @override
  State<DoubanDetailPage> createState() => _DoubanDetailPageState();
}

class _DoubanDetailPageState extends State<DoubanDetailPage> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  bool _adding = false;
  String? _error;

  bool get _isBook => widget.item.type == 'book';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await DoubanService.instance
          .getDetail(widget.item.type, widget.item.id);
      if (mounted) setState(() => _detail = data);
    } catch (_) {
      if (mounted) setState(() => _error = '详情加载失败，请稍后重试'.tr);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> _names(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => (e is Map ? e['name']?.toString() : e.toString()) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }

  String _scalar(Object? raw) {
    if (raw == null) return '';
    if (raw is List) return raw.map((e) => e.toString()).join(' / ');
    return raw.toString();
  }

  /// "2020-5" / "2020-5-1" / "2020-09-25(中国大陆)" → DateTime
  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final m = RegExp(r'(\d{4})(?:-(\d{1,2}))?(?:-(\d{1,2}))?')
        .firstMatch(s.trim().split('(').first);
    if (m == null) return null;
    return DateTime(
      int.parse(m[1]!),
      int.tryParse(m[2] ?? '1') ?? 1,
      int.tryParse(m[3] ?? '1') ?? 1,
    );
  }

  /// 详情封面回退链：cover_url → pic.large → pic.normal → 搜索结果卡片封面
  String _coverOf(Map<String, dynamic> d) {
    final direct = d['cover_url']?.toString() ?? '';
    if (direct.isNotEmpty) return direct;
    final pic = d['pic'];
    if (pic is Map) {
      final large = pic['large']?.toString() ?? '';
      if (large.isNotEmpty) return large;
      final normal = pic['normal']?.toString() ?? '';
      if (normal.isNotEmpty) return normal;
    }
    return widget.item.coverUrl;
  }

  Future<String?> _downloadCover(String url, String id) async {
    if (url.isEmpty || !url.startsWith('http')) return null;
    try {
      // 部分封面是 .webp 地址，统一按 jpg 落盘（字节内容为服务端实际格式）
      final normalized =
          url.contains('.webp') ? url.replaceAll('.webp', '.jpg') : url;
      final response = await http.get(
        Uri.parse(normalized),
        headers: {
          'Accept': 'image/avif,image/webp,image/apng,*/*',
          ...doubanImageHeaders,
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) return null;

      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = _isBook
          ? await ImagePathHelper.instance.getBookCoverPath(id, fileName)
          : await ImagePathHelper.instance.getMoviePosterPath(id, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);
      return targetPath;
    } catch (e) {
      debugPrint('豆瓣封面下载失败: $e');
      return null;
    }
  }

  Future<void> _add() async {
    final d = _detail;
    if (d == null || _adding) return;
    setState(() => _adding = true);
    try {
      final id = const Uuid().v4();
      final coverUrl = _coverOf(d);
      final coverPath = await _downloadCover(coverUrl, id);
      if (!mounted) return;

      final rating = double.tryParse(
          (d['rating'] as Map?)?['value']?.toString() ?? '');
      final summary = d['intro']?.toString().trim() ?? '';
      final base = <String, dynamic>{
        'title': d['title']?.toString() ?? widget.item.title,
        'rating': rating,
        'genres': _stringList(d['genres']),
        'summary': summary,
        'coverPath': coverPath,
      };

      if (_isBook) {
        final publishDate = _parseDate(d['pubdate']?.toString());
        final prefill = {
          ...base,
          'authors': _stringList(d['author']),
          'translators': _stringList(d['translator']),
          'publisher': _scalar(d['press']).trim(),
          'isbn': d['isbn']?.toString() ?? '',
          'releaseDate': publishDate,
          'publishDate': publishDate,
        };
        Navigator.of(context)
            .pushNamed('/book-form', arguments: {'prefill': prefill});
      } else {
        final prefill = {
          ...base,
          'releaseDate': _parseDate(d['year']?.toString()),
          'directors': _names(d['directors']),
          'actors': _names(d['actors']),
          'alternateTitles': _stringList(d['aka']),
        };
        Navigator.of(context)
            .pushNamed('/movie-form', arguments: {'prefill': prefill});
      }
    } catch (_) {
      if (mounted) ToastUtil.show(context, '添加失败，请稍后重试'.tr);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('豆瓣详情'.tr),
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: _adding ? null : _add,
              child: _adding
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: colors.primary),
                    )
                  : Text('添加'.tr,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.primary)),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: colors.primary),
            )
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4))),
                )
              : _buildBody(colors),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    final d = _detail!;
    final rating = (d['rating'] as Map?)?['value']?.toString() ?? '';
    final ratingCount = (d['rating'] as Map?)?['count']?.toString() ?? '';
    final cover = _coverOf(d);

    final rows = <(String, String)>[
      if (!_isBook) ...[
        ('导演'.tr, _names(d['directors']).join(' / ')),
        ('主演'.tr, _names(d['actors']).join(' / ')),
        ('类型'.tr, _stringList(d['genres']).join(' / ')),
        ('制片国家/地区'.tr, _stringList(d['countries']).join(' / ')),
        ('片长'.tr, _stringList(d['durations']).join(' / ')),
        ('集数'.tr, d['episodes_count']?.toString() ?? ''),
        ('又名'.tr, _stringList(d['aka']).join(' / ')),
      ] else ...[
        ('作者'.tr, _stringList(d['author']).join(' / ')),
        ('译者'.tr, _stringList(d['translator']).join(' / ')),
        ('出版社'.tr, _scalar(d['press'])),
        ('出版年'.tr, _scalar(d['pubdate'])),
        ('页数'.tr, _scalar(d['pages'])),
        ('定价'.tr, _scalar(d['price'])),
        ('ISBN'.tr, d['isbn']?.toString() ?? ''),
      ],
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 110,
                height: 156,
                child: cover.isNotEmpty
                    ? DoubanNetworkImage(
                        url: cover,
                        fit: BoxFit.cover,
                        placeholder: _coverPlaceholder(colors))
                    : _coverPlaceholder(colors),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title']?.toString() ?? widget.item.title,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                          height: 1.3)),
                  if ((d['original_title'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(d['original_title'].toString(),
                        style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.45))),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (rating.isNotEmpty) ...[
                        Icon(Icons.star_rounded,
                            size: 16, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text(rating,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface)),
                        if (ratingCount.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('($ratingCount)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.4))),
                        ],
                      ],
                      if ((d['year'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Text(d['year'].toString(),
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    colors.onSurface.withValues(alpha: 0.45))),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...[
          for (final (label, value) in rows)
            if (value.trim().isNotEmpty) _metaRow(colors, label, value),
        ],
        if ((d['intro'] ?? '').toString().trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('简介'.tr,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
          const SizedBox(height: 8),
          Text(d['intro'].toString().trim(),
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.onSurface.withValues(alpha: 0.7))),
        ],
      ],
    );
  }

  Widget _metaRow(ColorScheme colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: colors.onSurface.withValues(alpha: 0.75))),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 32, color: colors.onSurface.withValues(alpha: 0.2)),
      ),
    );
  }
}
