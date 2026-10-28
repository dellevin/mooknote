import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../services/bangumi_service.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/slide_up_page_route.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';
import 'bangumi_characters_page.dart';
import 'bangumi_person_sheet.dart';
import 'bangumi_search_page.dart';
import '../book/book_form_page.dart';
import '../game/game_form_page.dart';
import '../movies/movie_form_page.dart';

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
  List<dynamic>? _chars; // 条目关联角色（含声优）
  List<dynamic>? _staff; // 条目制作人员

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
      _loadPeople(id);
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

  Future<({String id, Object? created})?> _add(String status) async {
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
    Object? created; // 新入库实体，供"添加后打开编辑页"使用

    if (!mounted) return null;
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
        created = book;
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
        created = game;
        break;
      default:
        // 模板自动填充（对齐 TMDB 添加流程）：主演取主角 CV，
        // 编剧取脚本/系列构成，导演在 infobox 基础上补全；与人物收藏体系相互独立
        List<dynamic>? chars = _chars;
        List<dynamic>? staff = _staff;
        final subjectId = m['id'];
        if ((chars == null || staff == null) && subjectId is int) {
          try {
            chars ??= await _bgm.subjectCharacters(subjectId);
            staff ??= await _bgm.subjectPersons(subjectId);
          } catch (_) {}
        }
        final infoboxDirectors = _infoboxList('导演');
        final directorRefs = staff == null
            ? <Map<String, dynamic>>[]
            : _staffByRole(staff, 'director');
        final writerRefs = staff == null
            ? <Map<String, dynamic>>[]
            : _staffByRole(staff, 'writer');
        final cvRefs = chars == null
            ? <Map<String, dynamic>>[]
            : _mainCharacterCvRefs(chars).take(10).toList();
        // 模板名单填简体中文名（如有），仅对进入模板的少数人拉详情
        Map<int, String> cnNames = {};
        try {
          cnNames = await _cnNamesForRefs(
              [...directorRefs, ...writerRefs, ...cvRefs]);
        } catch (_) {}
        final movie = Movie(
          id: id,
          title: title,
          posterPath: coverPath,
          releaseDate: date,
          directors: ({
            ...infoboxDirectors,
            ...directorRefs.map((r) => _refName(r, cnNames)),
          }).where((n) => n.isNotEmpty).toList(),
          writers: [
            for (final r in writerRefs) _refName(r, cnNames)
          ].where((n) => n.isNotEmpty).toList(),
          actors: [
            for (final r in cvRefs) _refName(r, cnNames)
          ].where((n) => n.isNotEmpty).toList(),
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
        // 分集记录：拉取本篇分集，写入集号与中文标题（name_cn 优先）。
        // 放送中的条目后续话可能尚无名称——仍创建，标题留空。
        // "已看"入库时全部勾选已观看，观看日期为今天。
        if (subjectId is int) {
          try {
            final eps = await _bgm.subjectEpisodes(subjectId);
            final seen = <int>{};
            final list = <MovieEpisode>[];
            final epNow = DateTime.now();
            final watchedAll = status == 'watched';
            for (final e in eps) {
              final em = e as Map<String, dynamic>;
              final no = em['ep'] is int
                  ? em['ep'] as int
                  : int.tryParse((em['ep'] ?? '').toString());
              if (no == null || !seen.add(no)) continue;
              final cn = (em['name_cn'] ?? '').toString().trim();
              final jp = (em['name'] ?? '').toString().trim();
              list.add(MovieEpisode(
                id: const Uuid().v4(),
                movieId: id,
                episodeNo: no,
                title: cn.isNotEmpty ? cn : jp,
                watched: watchedAll,
                watchDate: watchedAll ? epNow : null,
                createdAt: epNow,
                updatedAt: epNow,
              ));
            }
            if (list.isNotEmpty) {
              await provider.addMovieEpisodesBatch(list);
            }
          } catch (_) {
            // 分集拉取失败不阻塞入库
          }
        }
        created = movie;
    }

    // 同步条目 tag 为本地标签实体（同名跳过）：
    // 表单写入的 tag 字符串原本不会创建标签实体，标签管理页与表单选择器看不到它们
    await _syncLocalTags(
      provider,
      switch (_target) {
        'book' => 'book_genre',
        'game' => 'game_genre',
        _ => 'movie_genre',
      },
      tags,
    );

    if (mounted) {
      setState(() => _localId = id);
      ToastUtil.show(
          context, '已添加到{status}'.trf({'status': _statusLabel(status)}));
    }
    return (id: id, created: created);
  }

  /// 将条目自带的 tag 同步为本地标签实体（同名跳过）
  Future<void> _syncLocalTags(
      AppProvider provider, String type, List<String> names) async {
    final existing = (await provider.getTags(type))
        .map((t) => (t['name'] ?? '').toString())
        .toSet();
    for (final n in names) {
      if (n.isEmpty || !existing.add(n)) continue;
      await provider.addTag(n, type);
    }
  }

  /// 确保条目已入库；未入库时以"想看/想读/想玩"自动加入，返回本地条目 id。
  /// 静默入库，不弹编辑页（避免打断人物收藏/关联流程）
  Future<String?> _ensureSubjectForLink() async {
    if (_localId != null) return _localId;
    final status = switch (_target) {
      'book' => 'want_to_read',
      'game' => 'want_to_play',
      _ => 'want_to_watch',
    };
    final rec = await _add(status);
    return rec?.id;
  }

  /// 状态按钮入库：显示加载指示（封面/人物/分集拉取有 1-2 秒耗时），
  /// 完成后按设置可选打开自动填好的编辑表单
  Future<void> _addWithLoading(String status) async {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      barrierColor: Colors.black.withValues(alpha: 0.06),
      builder: (_) => Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: colors.primary),
          ),
        ),
      ),
    );
    final rec = await _add(status);
    if (mounted) Navigator.of(context, rootNavigator: false).pop();
    if (rec == null || !mounted) return;
    // 可选增强：入库后直接打开自动填好的编辑表单
    if (UserPrefs().bangumiOpenEditorAfterAdd) {
      final Widget? editor = switch (rec.created) {
        Movie m => MovieFormPage(movie: m),
        Book b => BookFormPage(book: b),
        Game g => GameFormPage(game: g),
        _ => null,
      };
      if (editor != null) {
        Navigator.push(context, SlideUpPageRoute(page: editor));
      }
    }
  }

  /// 按映射后的 roleType 从制作人员中取人物元素（按名字去重保序）
  List<Map<String, dynamic>> _staffByRole(
      List<dynamic> staff, String wantRole) {
    final out = <Map<String, dynamic>>[];
    final names = <String>{};
    for (final raw in staff) {
      final s = raw as Map<String, dynamic>;
      final rel = (s['relation'] ?? '').toString();
      if (bangumiRoleType(rel, 'movie') != wantRole) continue;
      final name = (s['name'] ?? '').toString().trim();
      if (name.isEmpty || !names.add(name)) continue;
      out.add(s);
    }
    return out;
  }

  /// 主角角色的声优元素列表（按名字去重保序）
  List<Map<String, dynamic>> _mainCharacterCvRefs(List<dynamic> chars) {
    final out = <Map<String, dynamic>>[];
    final names = <String>{};
    for (final raw in chars) {
      final c = raw as Map<String, dynamic>;
      final rel = (c['relation'] ?? '').toString();
      if (rel != '主角' && rel != '主人公') continue;
      for (final a in (c['actors'] as List? ?? [])) {
        final m = a as Map<String, dynamic>;
        final name = (m['name'] ?? '').toString().trim();
        if (name.isEmpty || !names.add(name)) continue;
        out.add(m);
      }
    }
    return out;
  }

  /// 人物元素显示名：优先简体中文名（cn 为 id → 中文名映射）
  String _refName(Map<String, dynamic> ref, Map<int, String> cn) {
    final rid = (ref['id'] as num?)?.toInt();
    final c = rid != null ? (cn[rid] ?? '') : '';
    if (c.isNotEmpty) return c;
    return (ref['name'] ?? '').toString();
  }

  /// 为模板名单并发拉取 infobox 简体中文名（仅入库时对进入模板的少数人拉取，失败降级原名）
  Future<Map<int, String>> _cnNamesForRefs(
      List<Map<String, dynamic>> refs) async {
    final out = <int, String>{};
    await Future.wait(refs.map((r) async {
      final rid = (r['id'] as num?)?.toInt();
      if (rid == null || out.containsKey(rid)) return;
      try {
        final d = await _bgm.personDetail(rid);
        final c = bangumiNameCn(d);
        if (c != null && c.isNotEmpty) out[rid] = c;
      } catch (_) {}
    }));
    return out;
  }

  // ── 角色与制作人员 ──────────────────────────────────────────────

  /// 懒加载条目关联角色与制作人员（不阻塞首屏）
  Future<void> _loadPeople(int subjectId) async {
    try {
      final chars = await _bgm.subjectCharacters(subjectId);
      final staff = await _bgm.subjectPersons(subjectId);
      if (!mounted) return;
      setState(() {
        _chars = chars;
        _staff = staff;
      });
    } catch (_) {
      // 拉取失败时静默隐藏两个区块
    }
  }

  List<Widget> _buildCharactersSection(ColorScheme colors) {
    final chars = _chars;
    if (chars == null || chars.isEmpty) return const [];
    // 主角 → 配角 → 其他；横滑最多 12 个，超出走标题行「更多」
    final sorted = sortBangumiCharacters(chars);
    final shown = sorted.take(12).toList();
    return [
      _sectionTitleRow(colors, '角色介绍'.tr, sorted.length, onMore: () {
        Navigator.push(
          context,
          SlideUpPageRoute(
              page: BangumiCharactersPage(
            characters: sorted,
            target: _target,
            ensureSubject: _ensureSubjectForLink,
          )),
        );
      }),
      SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final c = shown[i];
            return BangumiCharacterCard(
              colors: colors,
              character: c,
              onTap: () async {
                await showBangumiCharacterSheet(
                  context,
                  character: c,
                  sortOrder: i,
                  target: _target,
                  ensureSubject: _ensureSubjectForLink,
                );
                // 弹层内按需拉取的简体中文名已合并进数据，返回后刷新卡片
                if (mounted) setState(() {});
              },
            );
          },
        ),
      ),
    ];
  }

  /// 制作人员：按 person id 去重并合并职务（Bangumi 按署名条目返回，一人多职会重复）。
  /// 合并结果写入独立字段 relation_merged，不覆写 API 原始 relation
  /// （覆写会导致 getter 每次调用把上次合并结果再合并，职务文本越滚越长）
  List<Map<String, dynamic>> get _mergedStaff {
    final staff = _staff;
    if (staff == null) return const [];
    final merged = <Map<String, dynamic>>[];
    final seen = <String, Set<String>>{};
    for (final raw in staff) {
      final s = raw as Map<String, dynamic>;
      final id = (s['id'] ?? '').toString();
      final rel = (s['relation'] ?? '').toString();
      if (seen.containsKey(id)) {
        if (rel.isNotEmpty) seen[id]!.add(rel);
      } else {
        seen[id] = {if (rel.isNotEmpty) rel};
        merged.add(s);
      }
    }
    for (final s in merged) {
      s['relation_merged'] =
          seen[(s['id'] ?? '').toString()]!.join(' / ');
    }
    // 核心主创靠前，杂项职务沉底
    return sortBangumiStaff(merged);
  }

  List<Widget> _buildStaffSection(ColorScheme colors) {
    final merged = _mergedStaff;
    if (merged.isEmpty) return const [];
    // 横滑最多 12 人，超出走标题行「更多」
    final shown = merged.take(12).toList();
    return [
      _sectionTitleRow(colors, '制作人员'.tr, merged.length, onMore: () {
        Navigator.push(
          context,
          SlideUpPageRoute(
              page: BangumiStaffPage(
            staff: merged,
            target: _target,
            ensureSubject: _ensureSubjectForLink,
          )),
        );
      }),
      SizedBox(
        height: 116,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final s = shown[i];
            final rawName = (s['name'] ?? '').toString();
            final cnName = (s['name_cn'] ?? '').toString().trim();
            final name = cnName.isNotEmpty ? cnName : rawName;
            final relation = ((s['relation_merged'] ?? s['relation'] ?? '')
                    as String)
                .toString();
            final imageUrl =
                bangumiImageUrl(s['images'] as Map<String, dynamic>?);
            return InkWell(
              onTap: () async {
                await showBangumiPersonSheet(
                  context,
                  personRef: s,
                  target: _target,
                  ensureSubject: _ensureSubjectForLink,
                );
                // 弹层内按需拉取的简体中文名已合并进数据，返回后刷新卡片
                if (mounted) setState(() {});
              },
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 66,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 29,
                      backgroundColor: colors.surfaceContainerHighest,
                      backgroundImage:
                          imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null
                          ? Icon(Icons.person,
                              size: 26,
                              color: colors.onSurface.withValues(alpha: 0.2))
                          : null,
                    ),
                    const SizedBox(height: 5),
                    Text(name,
                        style: TextStyle(
                            fontSize: 12, color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                    if (relation.isNotEmpty)
                      Text(relation,
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  colors.onSurface.withValues(alpha: 0.4)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _sectionTitleRow(ColorScheme colors, String title, int count,
      {VoidCallback? onMore}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface)),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text('共 {n} 个'.trf({'n': count}),
                style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.35))),
          ),
          if (onMore != null) ...[
            const Spacer(),
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 0, 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('更多'.tr,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.primary)),
                  Icon(Icons.chevron_right,
                      size: 16, color: colors.primary),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<(String, String, IconData)> get _statusOptions {
    switch (_target) {
      case 'book':
        return [
          ('已读'.tr, 'read', Icons.check_circle_outline),
          ('在读'.tr, 'reading', Icons.play_circle_outline),
          ('想读'.tr, 'want_to_read', Icons.bookmark_outline),
        ];
      case 'game':
        return [
          ('玩过'.tr, 'completed', Icons.check_circle_outline),
          ('在玩'.tr, 'playing', Icons.play_circle_outline),
          ('想玩'.tr, 'want_to_play', Icons.bookmark_outline),
        ];
      default:
        return [
          ('已看'.tr, 'watched', Icons.check_circle_outline),
          ('在看'.tr, 'watching', Icons.play_circle_outline),
          ('想看'.tr, 'want_to_watch', Icons.bookmark_outline),
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
        _addWithLoading(status);
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
            child: BangumiExpandableText(
                text: summary,
                maxLines: 8,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.6)),
          ),
        ],
        // 角色介绍
        ..._buildCharactersSection(colors),
        // 制作人员
        ..._buildStaffSection(colors),
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
