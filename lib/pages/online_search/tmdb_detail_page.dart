import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../services/tmdb_service.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/slide_up_page_route.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';

/// TMDB 影视详情页（电影/剧集）
class TmdbDetailPage extends StatefulWidget {
  /// 搜索结果条目（含 media_type/id，用于详情加载前的占位展示）
  final Map<String, dynamic> item;

  const TmdbDetailPage({super.key, required this.item});

  @override
  State<TmdbDetailPage> createState() => _TmdbDetailPageState();
}

class _TmdbDetailPageState extends State<TmdbDetailPage> {
  final _tmdb = TmdbService.instance;

  bool get _isMovie => widget.item['media_type'] == 'movie';

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  Movie? _localMovie;

  @override
  void initState() {
    super.initState();
    _tmdb.configure(UserPrefs().tmdbApiToken, UserPrefs().tmdbAuthType);
    _load();
  }

  Future<void> _load() async {
    try {
      final id = widget.item['id'] as int;
      final data =
          _isMovie ? await _tmdb.movieDetail(id) : await _tmdb.tvDetail(id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      _checkLocal();
    } on TmdbAuthException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Token 已失效，请前往设置重新验证'.tr;
        });
      }
    } on TmdbNetworkException {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '网络错误'.tr;
        });
      }
    }
  }

  void _checkLocal() {
    final title = (_data?['title'] ?? _data?['name'] ?? '').toString();
    if (title.isEmpty) return;
    final provider = context.read<AppProvider>();
    final match = provider.movies
        .where((m) => !m.isDeleted && m.title == title)
        .toList();
    if (match.isNotEmpty) {
      setState(() => _localMovie = match.first);
    }
  }

  // ── 添加到本地库 ──────────────────────────────────────────────

  Future<void> _addMovie(String status) async {
    final m = _data!;
    final title = (m['title'] ?? m['name'] ?? '').toString();
    final originalTitle =
        (m['original_title'] ?? m['original_name'] ?? '').toString();
    final dateStr =
        (m['release_date'] ?? m['first_air_date'] ?? '').toString();
    final releaseDate = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;

    final credits = m['credits'] as Map<String, dynamic>? ?? {};
    final actors = (credits['cast'] as List? ?? [])
        .take(10)
        .map((e) => e['name'].toString())
        .toList();
    final genres = (m['genres'] as List? ?? [])
        .map((e) => e['name'].toString())
        .toList();

    final movieId = const Uuid().v4();
    String? posterPath;
    final poster = (m['poster_path'] ?? '').toString();
    if (poster.isNotEmpty) {
      try {
        final resp = await http.get(
            Uri.parse('${TmdbService.imageBase}$poster'),
            headers: {'User-Agent': 'Mozilla/5.0'}).timeout(
                const Duration(seconds: 15));
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
      title: title,
      posterPath: posterPath,
      releaseDate: releaseDate,
      directors: _directors(m),
      actors: actors,
      genres: genres,
      alternateTitles: originalTitle.isNotEmpty && originalTitle != title
          ? [originalTitle]
          : [],
      summary: (m['overview'] ?? '').toString(),
      rating: (m['vote_average'] as num?)?.toDouble(),
      status: status,
      category: _isMovie ? 'movie' : 'tv',
      duration: _duration(m),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    final provider = context.read<AppProvider>();
    await provider.addMovie(movie);
    await provider.loadMovies();

    if (mounted) {
      setState(() {
        _localMovie = provider.movies.firstWhere((e) => e.id == movie.id);
      });
      ToastUtil.show(
          context, '已添加到{status}'.trf({'status': _statusLabel(status)}));
    }
  }

  List<String> _directors(Map<String, dynamic> m) {
    if (_isMovie) {
      final credits = m['credits'] as Map<String, dynamic>? ?? {};
      return (credits['crew'] as List? ?? [])
          .where((e) => e['job'] == 'Director')
          .map((e) => e['name'].toString())
          .toList();
    }
    return (m['created_by'] as List? ?? [])
        .map((e) => e['name'].toString())
        .toList();
  }

  int _duration(Map<String, dynamic> m) {
    if (_isMovie) return (m['runtime'] as num?)?.toInt() ?? 0;
    final runtimes = m['episode_run_time'] as List? ?? [];
    return runtimes.isNotEmpty ? (runtimes.first as num).toInt() : 0;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'watched':
        return '已看'.tr;
      case 'watching':
        return '在看'.tr;
      case 'want_to_watch':
        return '想看'.tr;
      default:
        return '';
    }
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
            _sheetItem(
                ctx, colors, Icons.check_circle_outline, '已看'.tr, 'watched'),
            _sheetItem(
                ctx, colors, Icons.play_circle_outline, '在看'.tr, 'watching'),
            _sheetItem(
                ctx, colors, Icons.bookmark_outline, '想看'.tr, 'want_to_watch'),
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
      appBar: AppBar(
        title: Text(_isMovie ? '电影详情'.tr : '剧集详情'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton:
          (!_loading && _error == null && _localMovie == null && _data != null)
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
    final title = (m['title'] ?? m['name'] ?? '').toString();
    final originalTitle =
        (m['original_title'] ?? m['original_name'] ?? '').toString();
    final dateStr =
        (m['release_date'] ?? m['first_air_date'] ?? '').toString();
    final rating = (m['vote_average'] as num?)?.toDouble() ?? 0;
    final poster = (m['poster_path'] ?? '').toString();
    final backdrop = (m['backdrop_path'] ?? '').toString();
    final overview = (m['overview'] ?? '').toString();
    final genres = (m['genres'] as List? ?? [])
        .map((e) => e['name'].toString())
        .toList();
    final directors = _directors(m);
    final cast = (m['credits']?['cast'] as List? ?? []).take(15).toList();
    final duration = _duration(m);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        // 背景图
        if (backdrop.isNotEmpty)
          SizedBox(
            height: 180,
            width: double.infinity,
            child: Image.network(
              '${TmdbService.backdropBase}$backdrop',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        // 海报 + 基本信息
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
                  child: poster.isNotEmpty
                      ? Image.network('${TmdbService.imageBase}$poster',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _posterPlaceholder(colors))
                      : _posterPlaceholder(colors),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                            height: 1.3)),
                    if (originalTitle.isNotEmpty && originalTitle != title)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(originalTitle,
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
                        if (dateStr.isNotEmpty)
                          _meta(colors, dateStr),
                        if (rating > 0)
                          _meta(colors, '⭐ ${rating.toStringAsFixed(1)}'),
                        if (duration > 0)
                          _meta(colors, '$duration ${'分钟'.tr}'),
                        if (!_isMovie) ...[
                          if ((m['number_of_seasons'] as num? ?? 0) > 0)
                            _meta(colors,
                                '${m['number_of_seasons']} ${'季'.tr} · ${m['number_of_episodes']} ${'集'.tr}'),
                          _meta(colors, _tvStatus(m['status'])),
                        ],
                      ],
                    ),
                    if (genres.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: genres
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
        if (overview.isNotEmpty) ...[
          _sectionTitle(colors, '概要'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(overview,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.6)),
          ),
        ],
        // 导演/主创
        if (directors.isNotEmpty) ...[
          _sectionTitle(colors, _isMovie ? '导演'.tr : '主创'.tr),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(directors.join(' / '),
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.7))),
          ),
        ],
        // 演职人员
        if (cast.isNotEmpty) ...[
          _sectionTitle(colors, '演职人员'.tr),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _showPersonSheet(cast[i]['id'] as int),
                  child: _castItem(colors, cast[i])),
            ),
          ),
        ],
      ],
    );
  }

  Widget _castItem(ColorScheme colors, dynamic c) {
    final name = (c['name'] ?? '').toString();
    final character = (c['character'] ?? '').toString();
    final profile = (c['profile_path'] ?? '').toString();
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: colors.surfaceContainerHighest,
            backgroundImage: profile.isNotEmpty
                ? NetworkImage('${TmdbService.profileBase}$profile')
                : null,
            child: profile.isEmpty
                ? Icon(Icons.person,
                    size: 28, color: colors.onSurface.withValues(alpha: 0.2))
                : null,
          ),
          const SizedBox(height: 6),
          Text(name,
              style: TextStyle(fontSize: 11, color: colors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center),
          if (character.isNotEmpty)
            Text(character,
                style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.4)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _tvStatus(dynamic status) {
    switch (status) {
      case 'Ended':
        return '已完结'.tr;
      case 'Returning Series':
        return '连载中'.tr;
      case 'Canceled':
        return '已砍'.tr;
      case 'In Production':
        return '制作中'.tr;
      default:
        return status?.toString() ?? '';
    }
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

  // ── 人员详情弹层 ──────────────────────────────────────────────

  void _showPersonSheet(int personId) {
    final colors = Theme.of(context).colorScheme;
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: _TmdbPersonSheet(personId: personId),
        ),
      ),
    );
  }

  Widget _posterPlaceholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie_outlined,
            size: 28, color: colors.onSurface.withValues(alpha: 0.2)),
      ),
    );
  }
}

/// TMDB 人员详情弹层内容
class _TmdbPersonSheet extends StatefulWidget {
  final int personId;

  const _TmdbPersonSheet({required this.personId});

  @override
  State<_TmdbPersonSheet> createState() => _TmdbPersonSheetState();
}

class _TmdbPersonSheetState extends State<_TmdbPersonSheet> {
  final _tmdb = TmdbService.instance;

  Map<String, dynamic>? _data;
  String? _error;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _tmdb.personDetail(widget.personId);
      if (!mounted) return;
      setState(() => _data = data);
    } on TmdbAuthException {
      if (mounted) setState(() => _error = 'Token 已失效，请前往设置重新验证'.tr);
    } on TmdbNetworkException {
      if (mounted) setState(() => _error = '网络错误'.tr);
    }
  }

  String _department(String dept) {
    switch (dept) {
      case 'Acting':
        return '演员'.tr;
      case 'Directing':
        return '导演'.tr;
      case 'Writing':
        return '编剧'.tr;
      case 'Production':
        return '制片'.tr;
      default:
        return dept;
    }
  }

  /// TMDB 部门 → 本地职业（中文存储），无法映射时返回 null
  String? _occupation(String dept) {
    switch (dept) {
      case 'Acting':
        return '演员';
      case 'Directing':
        return '导演';
      case 'Writing':
        return '编剧';
      case 'Production':
        return '制片';
      default:
        return null;
    }
  }

  // ── 同步到本地人物库（有同名更新，无同名新增）───────────────────────

  Future<void> _syncLocalPerson() async {
    final p = _data!;
    final name = (p['name'] ?? '').toString();
    if (name.isEmpty) return;
    final provider = context.read<AppProvider>();
    final matches = provider.people
        .where((e) => !e.isDeleted && e.name == name)
        .toList();

    setState(() => _updating = true);
    if (matches.isEmpty) {
      await _addNewPerson(p);
    } else {
      Person? target = matches.first;
      if (matches.length > 1) {
        setState(() => _updating = false);
        target = await _pickPerson(matches);
        if (target == null || !mounted) return;
        setState(() => _updating = true);
      }
      await _applyUpdate(target, p);
    }
    if (mounted) setState(() => _updating = false);
  }

  /// 本地无同名人物，直接新增
  Future<void> _addNewPerson(Map<String, dynamic> tmdb) async {
    final name = (tmdb['name'] ?? '').toString();
    final id = const Uuid().v4();
    final photoPath = await _downloadProfilePhoto(
        id, (tmdb['profile_path'] ?? '').toString());
    final bio = (tmdb['biography'] ?? '').toString();
    final place = (tmdb['place_of_birth'] ?? '').toString();
    final occ = _occupation((tmdb['known_for_department'] ?? '').toString());

    final person = Person(
      id: id,
      name: name,
      gender: switch (tmdb['gender']) { 1 => 'female', 2 => 'male', 3 => 'other', _ => null },
      birthDate: DateTime.tryParse((tmdb['birthday'] ?? '').toString()),
      birthPlace: place.isNotEmpty ? place : null,
      alternateNames: (tmdb['also_known_as'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      occupation: [if (occ != null) occ],
      summary: bio.isNotEmpty ? bio : null,
      photoPath: photoPath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    await context.read<AppProvider>().addPerson(person);
    if (mounted) {
      ToastUtil.show(context, '已添加「{name}」'.trf({'name': name}));
    }
  }

  /// 下载 TMDB 头像到本地人物目录
  Future<String?> _downloadProfilePhoto(String personId, String profile) async {
    if (profile.isEmpty) return null;
    try {
      final resp = await http
          .get(Uri.parse('${TmdbService.imageBase}$profile'),
              headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.bodyBytes.length < 10 * 1024 * 1024) {
        final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final targetPath = await ImagePathHelper.instance
            .getPersonPhotoPath(personId, fileName);
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
        await File(targetPath).writeAsBytes(resp.bodyBytes);
        return targetPath;
      }
    } catch (_) {}
    return null;
  }

  /// 多个同名人物时让用户选择
  Future<Person?> _pickPerson(List<Person> matches) {
    return appDialog<Person>(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: c.surface,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('选择要更新的人物'.tr,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (_, i) {
                final person = matches[i];
                final subtitle = [
                  if (person.occupation.isNotEmpty)
                    person.occupation.join(' / '),
                  if (person.birthDate != null)
                    '${person.birthDate!.year}',
                ].join(' · ');
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(person.name,
                      style:
                          TextStyle(fontSize: 14, color: c.onSurface)),
                  subtitle: subtitle.isNotEmpty
                      ? Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              color: c.onSurface.withValues(alpha: 0.4)))
                      : null,
                  onTap: () => Navigator.pop(ctx, person),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 将 TMDB 人员数据写入本地人物
  Future<void> _applyUpdate(Person existing, Map<String, dynamic> tmdb) async {
    final downloaded = await _downloadProfilePhoto(
        existing.id, (tmdb['profile_path'] ?? '').toString());
    final photoPath = downloaded ?? existing.photoPath;

    final gender = switch (tmdb['gender']) {
      1 => 'female',
      2 => 'male',
      3 => 'other',
      _ => existing.gender,
    };
    final birthday = DateTime.tryParse((tmdb['birthday'] ?? '').toString());
    final bio = (tmdb['biography'] ?? '').toString();
    final place = (tmdb['place_of_birth'] ?? '').toString();
    final occ = _occupation((tmdb['known_for_department'] ?? '').toString());
    final alsoKnown = (tmdb['also_known_as'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty);

    final updated = existing.copyWith(
      gender: gender,
      birthDate: birthday ?? existing.birthDate,
      birthPlace: place.isNotEmpty ? place : existing.birthPlace,
      alternateNames: {...existing.alternateNames, ...alsoKnown}.toList(),
      occupation: {...existing.occupation, if (occ != null) occ}.toList(),
      summary: bio.isNotEmpty ? bio : existing.summary,
      photoPath: photoPath,
      updatedAt: DateTime.now(),
    );

    if (!mounted) return;
    await context.read<AppProvider>().updatePerson(updated);
    if (mounted) {
      ToastUtil.show(context, '已更新「{name}」'.trf({'name': existing.name}));
    }
  }

  /// 合并电影/剧集作品，按热度排序去重
  List<Map<String, dynamic>> _works(Map<String, dynamic> p) {
    List<dynamic> pick(Map<String, dynamic>? credits) {
      if (credits == null) return [];
      final cast = credits['cast'] as List? ?? [];
      return cast.isNotEmpty ? cast : (credits['crew'] as List? ?? []);
    }

    final merged = <Map<String, dynamic>>[
      ...pick(p['movie_credits'] as Map<String, dynamic>?)
          .map((e) => {...e as Map<String, dynamic>, 'media_type': 'movie'}),
      ...pick(p['tv_credits'] as Map<String, dynamic>?)
          .map((e) => {...e as Map<String, dynamic>, 'media_type': 'tv'}),
    ];
    final seen = <String>{};
    merged.retainWhere((e) => seen.add('${e['media_type']}_${e['id']}'));
    merged.sort((a, b) => ((b['popularity'] as num?) ?? 0)
        .compareTo((a['popularity'] as num?) ?? 0));
    return merged.take(20).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Center(
            child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 6, bottom: 10),
                decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2)))),
        Expanded(
          child: _data == null
              ? Center(
                  child: _error != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colors.onSurface
                                        .withValues(alpha: 0.4))),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: () {
                                  setState(() => _error = null);
                                  _load();
                                },
                                child: Text('重试'.tr,
                                    style:
                                        TextStyle(color: colors.primary))),
                          ],
                        )
                      : CircularProgressIndicator(
                          color: colors.primary, strokeWidth: 2),
                )
              : _buildContent(colors, _data!),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme colors, Map<String, dynamic> p) {
    final name = (p['name'] ?? '').toString();
    final profile = (p['profile_path'] ?? '').toString();
    final dept = (p['known_for_department'] ?? '').toString();
    final birthday = (p['birthday'] ?? '').toString();
    final place = (p['place_of_birth'] ?? '').toString();
    final bio = (p['biography'] ?? '').toString();
    final works = _works(p);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // 头像 + 基本信息
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage: profile.isNotEmpty
                  ? NetworkImage('${TmdbService.profileBase}$profile')
                  : null,
              child: profile.isEmpty
                  ? Icon(Icons.person,
                      size: 34, color: colors.onSurface.withValues(alpha: 0.2))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface)),
                      ),
                      if (dept.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_department(dept),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary)),
                        ),
                      ],
                    ],
                  ),
                  if (birthday.isNotEmpty || place.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          [birthday, place]
                              .where((e) => e.isNotEmpty)
                              .join(' · '),
                          style: TextStyle(
                              fontSize: 12,
                              color:
                                  colors.onSurface.withValues(alpha: 0.4))),
                    ),
                ],
              ),
            ),
          ],
        ),
        // 同步到本地人物库
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _updating ? null : _syncLocalPerson,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: colors.primary.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Center(
              child: _updating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.primary))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, size: 16, color: colors.primary),
                        const SizedBox(width: 6),
                        Text('同步到本地人物库'.tr,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: colors.primary)),
                      ],
                    ),
            ),
          ),
        ),
        // 个人简介
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('个人简介'.tr,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
          const SizedBox(height: 8),
          Text(bio,
              style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.6),
                  height: 1.6)),
        ],
        // 代表作品
        if (works.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('代表作品'.tr,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
          const SizedBox(height: 10),
          SizedBox(
            height: 192,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: works.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _workItem(colors, works[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _workItem(ColorScheme colors, Map<String, dynamic> w) {
    final isMovie = w['media_type'] == 'movie';
    final title = (w['title'] ?? w['name'] ?? '').toString();
    final poster = (w['poster_path'] ?? '').toString();
    final dateStr =
        (w['release_date'] ?? w['first_air_date'] ?? '').toString();
    final year = dateStr.length >= 4 ? dateStr.substring(0, 4) : '';

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          SlideUpPageRoute(
              page: TmdbDetailPage(
                  item: {'media_type': w['media_type'], 'id': w['id']}))),
      child: SizedBox(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 92,
                height: 128,
                child: poster.isNotEmpty
                    ? Image.network('${TmdbService.profileBase}$poster',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: colors.surfaceContainerHighest,
                            child: Icon(
                                isMovie
                                    ? Icons.movie_outlined
                                    : Icons.tv_outlined,
                                size: 24,
                                color: colors.onSurface
                                    .withValues(alpha: 0.2))))
                    : Container(
                        color: colors.surfaceContainerHighest,
                        child: Icon(
                            isMovie ? Icons.movie_outlined : Icons.tv_outlined,
                            size: 24,
                            color: colors.onSurface.withValues(alpha: 0.2))),
              ),
            ),
            const SizedBox(height: 6),
            Text(title,
                style: TextStyle(fontSize: 11, color: colors.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (year.isNotEmpty)
              Text(year,
                  style: TextStyle(
                      fontSize: 10,
                      color: colors.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}
