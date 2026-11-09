import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../l10n/app_strings.dart';
import '../../utils/status_labels.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../services/bangumi_service.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';
import 'bangumi_search_page.dart';

/// Bangumi 条目详情页（动画/书籍/游戏/三次元）
class BangumiDetailPage extends StatefulWidget {
  /// 搜索结果条目（含 id/type，用于详情加载前的占位展示）
  final Map<String, dynamic> item;

  const BangumiDetailPage({super.key, required this.item});

  @override
  State<BangumiDetailPage> createState() => _BangumiDetailPageState();
}

class _BangumiDetailPageState extends State<BangumiDetailPage> {
  final _bgm = BangumiService.instance;

  int get _type => (widget.item['type'] as num?)?.toInt() ?? 0;

  /// 目标库: movie / book / game
  String get _target {
    switch (_type) {
      case 1:
        return 'book';
      case 4:
        return 'game';
      default:
        return 'movie';
    }
  }

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  String? _localId; // 本地库中已存在的条目 id

  @override
  void initState() {
    super.initState();
    _bgm.configure(UserPrefs().bangumiAccessToken,
        proxy: UserPrefs().bangumiProxy);
    _load();
  }

  Future<void> _load() async {
    try {
      final id = (widget.item['id'] as num).toInt();
      final data = await _bgm.subjectDetail(id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _checkLocal();
    } on BangumiAuthException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Token 已失效，请前往设置重新验证'.tr;
        });
      }
    } on BangumiNetworkException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '网络错误'.tr;
        });
      }
    }
  }

  String get _title {
    final nameCn = (_data?['name_cn'] ?? '').toString();
    final name = (_data?['name'] ?? '').toString();
    return nameCn.isNotEmpty ? nameCn : name;
  }

  void _checkLocal() {
    final title = _title;
    if (title.isEmpty) return;
    final provider = context.read<AppProvider>();
    String? found;
    switch (_target) {
      case 'book':
        final m = provider.books
            .where((e) => !e.isDeleted && e.title == title)
            .toList();
        if (m.isNotEmpty) found = m.first.id;
        break;
      case 'game':
        final m = provider.games
            .where((e) => !e.isDeleted && e.title == title)
            .toList();
        if (m.isNotEmpty) found = m.first.id;
        break;
      default:
        final m = provider.movies
            .where((e) => !e.isDeleted && e.title == title)
            .toList();
        if (m.isNotEmpty) found = m.first.id;
    }
    if (found != null) setState(() => _localId = found);
  }

  // ── infobox 提取 ──────────────────────────────────────────────

  /// 取 infobox 中指定 key 的值（字符串或 {k,v} 列表统一为单行文本）
  String _infobox(String key) {
    final box = _data?['infobox'] as List? ?? [];
    for (final e in box) {
      if (e is Map && e['key'] == key) {
        final v = e['value'];
        if (v is String) return v.trim();
        if (v is List) {
          return v
              .map((x) => x is Map
                  ? (x['v'] ?? x['k'] ?? '').toString()
                  : x.toString())
              .where((t) => t.trim().isNotEmpty)
              .join('、');
        }
        return '';
      }
    }
    return '';
  }

  List<String> _infoboxList(String key) {
    final text = _infobox(key);
    if (text.isEmpty) return [];
    return text
        .split(RegExp(r'[、,，/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ── 封面下载 ──────────────────────────────────────────────

  Future<String?> _downloadCover(String id) async {
    final url = (_data?['images']?['large'] ?? '').toString();
    if (url.isEmpty) return null;
    try {
      final resp = await http.get(Uri.parse(url), headers: {
        'User-Agent': await _bgm.userAgent(),
      }).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.bodyBytes.length < 10 * 1024 * 1024) {
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final helper = ImagePathHelper.instance;
        final targetPath = switch (_target) {
          'book' => await helper.getBookCoverPath(id, fileName),
          'game' => await helper.getGameCoverPath(id, fileName),
          _ => await helper.getMoviePosterPath(id, fileName),
        };
        await helper.ensureDirExists(p.dirname(targetPath));
        await File(targetPath).writeAsBytes(resp.bodyBytes);
        return targetPath;
      }
    } catch (_) {}
    return null;
  }

  // ── 添加到本地库 ──────────────────────────────────────────────

  Future<void> _add(String status) async {
    final m = _data!;
    final id = const Uuid().v4();
    final title = _title;
    final originalName = (m['name'] ?? '').toString();
    final dateStr = (m['date'] ?? '').toString();
    final date = DateTime.tryParse(dateStr);
    final coverPath = await _downloadCover(id);
    final rating = (m['rating']?['score'] as num?)?.toDouble();
    final summary = (m['summary'] ?? '').toString().trim();
    final tags = (m['tags'] as List? ?? [])
        .take(8)
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final now = DateTime.now();

    if (!mounted) return;
    final provider = context.read<AppProvider>();

    switch (_target) {
      case 'book':
        final book = Book(
          id: id,
          title: title,
          coverPath: coverPath,
          authors: _infoboxList('作者'),
          alternateTitles:
              originalName.isNotEmpty && originalName != title
                  ? [originalName]
                  : [],
          publisher: _infobox('出版社').isNotEmpty ? _infobox('出版社') : null,
          genres: tags,
          summary: summary.isNotEmpty ? summary : null,
          rating: rating,
          status: status,
          isbn: _infobox('ISBN-13').isNotEmpty
              ? _infobox('ISBN-13')
              : (_infobox('ISBN').isNotEmpty ? _infobox('ISBN') : null),
          publishDate: date,
          createdAt: now,
          updatedAt: now,
        );
        await provider.addBook(book);
        await provider.loadBooks();
        break;
      case 'game':
        final game = Game(
          id: id,
          title: title,
          coverPath: coverPath,
          rating: rating,
          status: status,
          platforms: _infoboxList('平台'),
          genres: tags,
          developer: _infoboxList('开发'),
          releaseDate: date,
          summary: summary.isNotEmpty ? summary : null,
          createdAt: now,
          updatedAt: now,
        );
        await provider.addGame(game);
        await provider.loadGames();
        break;
      default:
        final movie = Movie(
          id: id,
          title: title,
          posterPath: coverPath,
          releaseDate: date,
          directors: _infoboxList('导演'),
          genres: tags,
          alternateTitles:
              originalName.isNotEmpty && originalName != title
                  ? [originalName]
                  : [],
          summary: summary.isNotEmpty ? summary : null,
          rating: rating,
          status: status,
          category: _type == 2 ? 'anime' : 'tv',
          createdAt: now,
          updatedAt: now,
        );
        await provider.addMovie(movie);
        await provider.loadMovies();
    }

    if (mounted) {
      setState(() => _localId = id);
      ToastUtil.show(
          context, '已添加到{status}'.trf({'status': _statusLabel(status)}));
    }
  }

  List<(String, String, IconData)> get _statusOptions {
    switch (_target) {
      case 'book':
        return [
          (StatusLabels.label('book', 'read'), 'read', Icons.check_circle_outline),
          (StatusLabels.label('book', 'reading'), 'reading', Icons.play_circle_outline),
          (StatusLabels.label('book', 'want_to_read'), 'want_to_read', Icons.bookmark_outline),
        ];
      case 'game':
        return [
          (StatusLabels.label('game', 'completed'), 'completed', Icons.check_circle_outline),
          (StatusLabels.label('game', 'playing'), 'playing', Icons.play_circle_outline),
          (StatusLabels.label('game', 'want_to_play'), 'want_to_play', Icons.bookmark_outline),
        ];
      default:
        return [
          (StatusLabels.label('movie', 'watched'), 'watched', Icons.check_circle_outline),
          (StatusLabels.label('movie', 'watching'), 'watching', Icons.play_circle_outline),
          (StatusLabels.label('movie', 'want_to_watch'), 'want_to_watch', Icons.bookmark_outline),
          (StatusLabels.label('movie', 'abandoned'), 'abandoned', Icons.cancel_outlined),
        ];
    }
  }

  String _statusLabel(String status) {
    for (final (label, value, _) in _statusOptions) {
      if (value == status) return label;
    }
    return '';
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
            for (final (label, value, icon) in _statusOptions)
              _sheetItem(ctx, colors, icon, label, value),
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
        _add(status);
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
      appBar: AppBar(
        title: Text('条目详情'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton:
          (!_loading && _error == null && _localId == null && _data != null)
              ? FloatingActionButton(
                  onPressed: _showAddSheet,
                  backgroundColor: colors.primary,
                  child: Icon(Icons.add, color: colors.onPrimary))
              : null,
      body: _loading
          ? Center(
              child:
                  CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
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
        Icon(Icons.error_outline,
            size: 48, color: colors.onSurface.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text(_error!,
            style: TextStyle(
                fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 16),
        TextButton(
            onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
            child: Text('重试'.tr, style: TextStyle(color: colors.primary))),
      ],
    ));
  }

  Widget _buildBody(ColorScheme colors) {
    final m = _data!;
    final originalName = (m['name'] ?? '').toString();
    final dateStr = (m['date'] ?? '').toString();
    final rating = (m['rating']?['score'] as num?)?.toDouble() ?? 0;
    final cover = (m['images']?['large'] ?? '').toString();
    final summary = (m['summary'] ?? '').toString().trim();
    final tags = (m['tags'] as List? ?? [])
        .take(8)
        .map((e) => (e['name'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toList();
    final infoRows = _infoRows();

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        // 封面 + 基本信息
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 100,
                  height: 150,
                  child: cover.isNotEmpty
                      ? Image.network(cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _coverPlaceholder(colors))
                      : _coverPlaceholder(colors),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(_title,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                  height: 1.3)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          margin: const EdgeInsets.only(top: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(bangumiTypeLabel(_type),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary)),
                        ),
                      ],
                    ),
                    if (originalName.isNotEmpty && originalName != _title)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(originalName,
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    colors.onSurface.withValues(alpha: 0.4))),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (dateStr.isNotEmpty) _meta(colors, dateStr),
                        if (rating > 0)
                          _meta(colors, '⭐ ${rating.toStringAsFixed(1)}'),
                        if ((m['eps'] as num? ?? 0) > 0)
                          _meta(colors, '${m['eps']} ${'话'.tr}'),
                        if ((m['volumes'] as num? ?? 0) > 0)
                          _meta(colors, '${m['volumes']} ${'卷'.tr}'),
                      ],
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags
                            .map((g) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(g,
                                      style: TextStyle(
                                          fontSize: 11, color: colors.primary)),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        // 简介
        if (summary.isNotEmpty) ...[
          _sectionTitle(colors, '概要'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(summary,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.6)),
          ),
        ],
        // 信息表
        if (infoRows.isNotEmpty) ...[
          _sectionTitle(colors, '信息'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final (k, v) in infoRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(k,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.4))),
                        ),
                        Expanded(
                          child: Text(v,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurface
                                      .withValues(alpha: 0.7),
                                  height: 1.4)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// 按条目类型提取有展示价值的 infobox 字段
  List<(String, String)> _infoRows() {
    final keys = switch (_target) {
      'book' => ['作者', '出版社', '页数', '刊行日'],
      'game' => ['开发', '发行', '平台', '游戏类型', '发售日期'],
      _ => _type == 2
          ? ['导演', '原作', '脚本', '动画制作', '官方网站']
          : ['导演', '编剧', '主演', '官方网站'],
    };
    return [
      for (final k in keys)
        if (_infobox(k).isNotEmpty) (k.tr, _infobox(k)),
    ];
  }

  Widget _coverPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_outlined,
            size: 28, color: colors.onSurface.withValues(alpha: 0.2)),
      ),
    );
  }

  Widget _meta(ColorScheme colors, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text,
        style: TextStyle(
            fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)));
  }

  Widget _sectionTitle(ColorScheme colors, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface)),
    );
  }
}
