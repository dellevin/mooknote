import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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

/// 影视详情页 - 在线版
class MovieDetailPage extends StatefulWidget {
  final int vodId;
  const MovieDetailPage({super.key, required this.vodId});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _staffList = [];
  bool _loading = true;
  bool _staffLoading = false;
  String? _error;
  bool _expanded = false;
  Movie? _localMovie;
  int _currentTab = 0;
  int _detailStyle = 0; // 0: 紧凑, 1: 沉浸式

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = UserPrefs().movieSearchToken;
    try {
      final url =
          '${ServerConfig.vipBaseUrl}/api/movie/detail?vodId=${widget.vodId}&token=$token';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final json_ = json.decode(resp.body);
        if (json_['code'] == 0 && json_['data'] != null) {
          setState(() {
            _data = json_['data'];
            _loading = false;
          });
          _loadStaff();
          _checkLocal();
          return;
        }
      }
      setState(() {
        _error = '加载失败';
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = '网络错误';
          _loading = false;
        });
    }
  }

  Future<void> _loadStaff() async {
    final staffStr = _data?['vod_staff'] ?? '';
    if (staffStr.toString().isEmpty) return;
    final token = UserPrefs().movieSearchToken;
    setState(() {
      _staffLoading = true;
    });
    try {
      final url = '${ServerConfig.vipBaseUrl}/api/actor/staff-pic?token=$token';
      final resp = await http.post(Uri.parse(url),
          body: staffStr.toString(),
          headers: {
            'Content-Type': 'application/json'
          }).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final json_ = json.decode(resp.body);
        if (json_['code'] == 0 && json_['data'] != null) {
          setState(() {
            _staffList = (json_['data'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
            _staffLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted)
      setState(() {
        _staffLoading = false;
      });
  }

  void _checkLocal() {
    final name = _data?['vod_name'] ?? '';
    if (name.toString().isEmpty) return;
    final provider = context.read<AppProvider>();
    final match =
        provider.movies.where((m) => !m.isDeleted && m.title == name).toList();
    if (match.isNotEmpty) {
      setState(() {
        _localMovie = match.first;
      });
    }
  }

  Future<void> _addMovie(String status) async {
    final m = _data!;
    final name = m['vod_name'] ?? '';
    final director = m['vod_director'] ?? '';
    final actorStr = m['vod_actor'] ?? '';
    final classStr = m['vod_class'] ?? '';
    final yearStr = m['vod_year'] ?? '';
    final scoreStr = m['vod_score'] ?? '';
    final content = m['vod_content'] ?? m['vod_blurb'] ?? '';
    final pic = m['vod_pic'] ?? '';

    DateTime? releaseDate;
    if (yearStr.toString().isNotEmpty) {
      releaseDate = DateTime.tryParse('${yearStr}-01-01');
    }

    final movieId = const Uuid().v4();
    String? posterPath;

    if (pic.toString().isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(pic.toString()), headers: {
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200 &&
            resp.bodyBytes.length < 10 * 1024 * 1024) {
          final fileName =
              'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = await ImagePathHelper.instance
              .getMoviePosterPath(movieId, fileName);
          await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
          await File(targetPath).writeAsBytes(resp.bodyBytes);
          posterPath = targetPath;
        }
      } catch (_) {}
    }

    final movie = Movie(
      id: movieId,
      title: name.toString(),
      posterPath: posterPath,
      releaseDate: releaseDate,
      directors: _splitStr(director.toString()),
      actors: _splitStr(actorStr.toString()),
      genres: _splitStr(classStr.toString()),
      summary: content.toString(),
      rating: double.tryParse(scoreStr.toString()),
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.addMovie(movie);
    await provider.loadMovies();

    if (mounted) {
      setState(() {
        _localMovie = provider.movies.firstWhere((m) => m.id == movie.id);
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
      case 'watched':
        return '已看';
      case 'watching':
        return '在看';
      case 'want_to_watch':
        return '想看';
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
            _sheetItem(
                ctx, colors, Icons.check_circle_outline, '已看', 'watched'),
            _sheetItem(
                ctx, colors, Icons.play_circle_outline, '在看', 'watching'),
            _sheetItem(
                ctx, colors, Icons.bookmark_outline, '想看', 'want_to_watch'),
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
        _addMovie(status);
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
          (!_loading && _error == null && _localMovie == null && _data != null)
              ? FloatingActionButton(
                  onPressed: _showAddSheet,
                  backgroundColor: colors.primary,
                  child: Icon(Icons.add, color: colors.onPrimary))
              : null,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                  color: colors.primary, strokeWidth: 2))
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
            child: Text('重试', style: TextStyle(color: colors.primary))),
      ],
    ));
  }

  Widget _buildBody(ColorScheme colors) {
    if (_detailStyle == 1) return _buildImmersiveBody(colors);
    final m = _data!;
    final pic = m['vod_pic'] ?? '';
    final name = m['vod_name'] ?? '';
    final isEnd = m['vod_isend'] ?? 0;
    final year = m['vod_year'] ?? '';
    final area = m['vod_area'] ?? '';
    final typeName = m['type_name'] ?? '';
    final classStr = m['vod_class'] ?? '';
    final score = m['vod_score'] ?? '';

    final metaParts =
        [year, area].where((s) => s.toString().isNotEmpty).join(' · ');
    final typeParts =
        [typeName, classStr].where((s) => s.toString().isNotEmpty).join(' / ');

    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(children: [
        // 头部：返回按钮 + 海报信息
        SafeArea(
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
                      child: Icon(Icons.arrow_back,
                          size: 20, color: colors.onSurface)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _detailStyle = _detailStyle == 0 ? 1 : 0),
                  child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          shape: BoxShape.circle),
                      child: Icon(
                          _detailStyle == 0
                              ? Icons.crop_landscape_rounded
                              : Icons.grid_view_rounded,
                          size: 18,
                          color: colors.onSurface)),
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
                        width: 120,
                        height: 170,
                        child: pic.toString().isNotEmpty
                            ? Image.network(pic,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _posterPlaceholder(colors))
                            : _posterPlaceholder(colors),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colors.onSurface)),
                            const SizedBox(height: 8),
                            if (score.toString().isNotEmpty && score != '0.0') ...[
                              Row(children: [
                                Icon(Icons.star_rounded, size: 16, color: const Color(0xFFF59E0B)),
                                const SizedBox(width: 3),
                                Text('$score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                                Text(' /10', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                              ]),
                              const SizedBox(height: 2),
                              Text('评分来源于网络资源收集，并非官方评分', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.25))),
                              const SizedBox(height: 8),
                            ],
                            _endTag(isEnd),
                            if (metaParts.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(metaParts,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurface
                                          .withValues(alpha: 0.5))),
                            ],
                            if (typeParts.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(typeParts,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colors.onSurface
                                          .withValues(alpha: 0.4)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                            if (_localMovie != null) ...[
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
            _buildTabButton('概要', 0),
            _buildTabButton('演职人员', 1),
          ]),
        ),
        // Tab 内容
        Expanded(
          child: _currentTab == 0 ? _buildOverview(colors) : _buildStaffTab(colors),
        ),
      ]),
    );
  }

  // ── 沉浸式布局 ──────────────────────────────────────────

  Widget _buildImmersiveBody(ColorScheme colors) {
    final m = _data!;
    final pic = m['vod_pic'] ?? '';
    final name = m['vod_name'] ?? '';
    final isEnd = m['vod_isend'] ?? 0;
    final year = m['vod_year'] ?? '';
    final area = m['vod_area'] ?? '';
    final typeName = m['type_name'] ?? '';
    final classStr = m['vod_class'] ?? '';
    final score = m['vod_score'] ?? '';
    final metaParts = [year, area].where((s) => s.toString().isNotEmpty).join(' · ');
    final typeParts = [typeName, classStr].where((s) => s.toString().isNotEmpty).join(' / ');

    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(children: [
        // 沉浸式头部
        Stack(children: [
          SizedBox(
            width: double.infinity,
            height: 320,
            child: pic.toString().isNotEmpty
                ? Image.network(pic, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest))
                : Container(color: colors.surfaceContainerHighest,
                    child: Icon(Icons.movie_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.1))),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                  stops: const [0.35, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_back, size: 20, color: Colors.white)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _detailStyle = 0),
                  child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.grid_view_rounded, size: 18, color: Colors.white)),
                ),
              ]),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: 18,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 8),
              Row(children: [
                if (score.toString().isNotEmpty && score != '0.0') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade400),
                        const SizedBox(width: 3),
                        Text('$score', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                _endTag(isEnd),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(metaParts, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ]),
              if (typeParts.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(typeParts, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              ],
              if (_localMovie != null) ...[
                const SizedBox(height: 8),
                _buildLocalStatus(colors),
              ],
            ]),
          ),
        ]),
        // Tab 栏
        Container(
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
          child: Row(children: [
            _buildTabButton('概要', 0),
            _buildTabButton('演职人员', 1),
          ]),
        ),
        // Tab 内容
        Expanded(
          child: _currentTab == 0 ? _buildOverview(colors) : _buildStaffTab(colors),
        ),
      ]),
    );
  }

  Widget _posterPlaceholder(ColorScheme colors) {
    return Container(
        color: colors.surfaceContainerHighest,
        child: Center(
            child: Icon(Icons.movie_outlined,
                size: 32, color: colors.onSurface.withValues(alpha: 0.15))));
  }

  Widget _endTag(int isEnd) {
    final finished = isEnd == 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: finished
            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
            : const Color(0xFFF59E0B).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(finished ? '已完结' : '连载中',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: finished
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFF59E0B))),
    );
  }

  Widget _buildLocalStatus(ColorScheme colors) {
    final status = _localMovie!.status;
    final label = _statusLabel(status);
    Color dotColor;
    switch (status) {
      case 'watched':
        dotColor = colors.primary;
        break;
      case 'watching':
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

  Widget _buildTabButton(String label, int index) {
    final colors = Theme.of(context).colorScheme;
    final selected = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
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

  // ── 概要 Tab ──────────────────────────────────────────

  Widget _buildOverview(ColorScheme colors) {
    final m = _data!;
    final isManual = m['is_manual_optimized'] ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // 信息行
        _infoRow(colors, '导演', m['vod_director']),
        _infoRow(colors, '主演', _formatActors()),
        _infoRow(colors, '语言', m['vod_lang']),
        _infoRow(colors, '时长', m['vod_duration']),
        _infoRow(colors, '上映', m['vod_pubdate']),
        const SizedBox(height: 16),

        // 标签
        if (isManual == 1 || (m['vod_tag'] ?? '').toString().isNotEmpty) ...[
          _buildTags(colors),
          const SizedBox(height: 16),
        ],

        // 分隔线
        Container(height: 0.5, color: colors.outlineVariant),
        const SizedBox(height: 16),

        // 简介
        _buildSynopsis(colors),
      ],
    );
  }

  Widget _infoRow(ColorScheme colors, String label, dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 44,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4)))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.75),
                    height: 1.5))),
      ]),
    );
  }

  String _formatActors() {
    final staffStr = _data?['vod_staff'] ?? '';
    if (staffStr.toString().isNotEmpty) {
      try {
        final staff = json.decode(staffStr.toString()) as List;
        final actors = staff.where((s) => s['position'] == '演员').toList();
        if (actors.isNotEmpty) {
          return actors.map((s) {
            final name = s['name'] ?? '';
            final role = s['role'] ?? '';
            if (role.toString().isNotEmpty) return '$name（$role）';
            return name;
          }).join('，');
        }
      } catch (_) {}
    }
    return _data?['vod_actor'] ?? '';
  }

  Widget _buildTags(ColorScheme colors) {
    final m = _data!;
    final isManual = m['is_manual_optimized'] ?? 0;
    final tagStr = m['vod_tag'] ?? '';
    final tags =
        tagStr.toString().split(',').where((t) => t.trim().isNotEmpty).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (isManual == 1)
          _tag('官方优化', const Color(0xFF16A34A), highlight: true),
        ...tags.map(
            (t) => _tag(t.trim(), colors.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _tag(String text, Color color, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: highlight
                ? const Color(0xFF16A34A).withValues(alpha: 0.3)
                : color.withValues(alpha: 0.2),
            width: 0.5),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: highlight ? const Color(0xFF16A34A) : color)),
    );
  }

  Widget _buildSynopsis(ColorScheme colors) {
    final m = _data!;
    final blurb = m['vod_blurb'] ?? '';
    final content = m['vod_content'] ?? '';
    final fullText = content.toString().isNotEmpty
        ? content.toString().replaceAll(RegExp(r'<[^>]*>'), '')
        : blurb.toString();
    final isLong = fullText.length > 120;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState:
            _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: Text(fullText,
            style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
                height: 1.8),
            maxLines: 4,
            overflow: TextOverflow.ellipsis),
        secondChild: Text(fullText,
            style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.7),
                height: 1.8)),
      ),
      if (isLong)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_expanded ? '收起' : '展开全文',
                style: TextStyle(
                    fontSize: 12,
                    color: colors.primary,
                    fontWeight: FontWeight.w500)),
          ),
        ),
    ]);
  }

  // ── 演职人员 Tab ──────────────────────────────────────────

  Widget _buildStaffTab(ColorScheme colors) {
    if (_staffLoading)
      return Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colors.primary)));
    if (_staffList.isEmpty)
      return Center(
          child: Text('暂无演职信息',
              style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.35))));
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          childAspectRatio: 0.7),
      itemCount: _staffList.length,
      itemBuilder: (context, index) =>
          _buildStaffCard(colors, _staffList[index]),
    );
  }

  Widget _buildStaffCard(ColorScheme colors, Map<String, dynamic> s) {
    final name = s['name'] ?? '';
    final position = s['position'] ?? '';
    final role = s['role'] ?? '';
    final pic = s['actor_pic'] ?? '';
    final sub = [position, if (role.toString().isNotEmpty) role].join(' · ');

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
          height: 100,
          child: pic.toString().isNotEmpty
              ? Image.network(pic,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _avatarPlaceholder(colors, name))
              : _avatarPlaceholder(colors, name),
        ),
      ),
      const SizedBox(height: 6),
      Text(name,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(sub,
          style: TextStyle(
              fontSize: 9, color: colors.onSurface.withValues(alpha: 0.4)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center),
    ]);
  }

  Widget _avatarPlaceholder(ColorScheme colors, String name) {
    final ch = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
          child: Text(ch,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface.withValues(alpha: 0.25)))),
    );
  }
}
