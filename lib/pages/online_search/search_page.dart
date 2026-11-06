import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../note/note_detail_page.dart';
import '../game/game_detail_page.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../data/custom_module/custom_module_design_dao.dart';
import '../custom_module/custom_module_detail_page.dart';
import '../../utils/slide_up_page_route.dart';
import '../../l10n/app_strings.dart';

/// 搜索页面（带 Scaffold + AppBar）
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('搜索'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: const SearchPageBody(),
    );
  }
}

/// 搜索页 body —— 可嵌入到统一搜索页 SearchHubPage
class SearchPageBody extends StatefulWidget {
  const SearchPageBody({super.key});

  @override
  State<SearchPageBody> createState() => _SearchPageBodyState();
}

class _SearchPageBodyState extends State<SearchPageBody> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  bool _showMovies = true;
  bool _showBooks = true;
  bool _showNotes = true;
  bool _showGames = true;
  bool _showCustom = true;

  List<_SearchResult> _results = [];
  bool _hasSearched = false;
  List<String> _matchingTags = [];
  String? _selectedTag;

  // 各类型命中数（含自定义模块），由异步搜索统一算出供筛选栏展示
  final Map<String, int> _counts = {'movie': 0, 'book': 0, 'note': 0, 'game': 0, 'custom': 0};
  // 模块激活设计缓存：moduleId -> design（null 表示无激活设计，仅匹配标题）
  final Map<String, CustomModuleDesign?> _designCache = {};
  final CustomModuleDesignDao _designDao = CustomModuleDesignDao();

  Timer? _debounce;
  // 搜索作废序号：筛选 chip 可绕过防抖直接发起搜索，乱序完成时只接受最后一次结果
  int _searchToken = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _performSearch);
  }

  // 单一匹配判定（结果与计数共用，避免两处各写一份）
  bool _movieMatch(Movie m, String kw) =>
      m.title.toLowerCase().contains(kw) ||
      m.alternateTitles.any((t) => t.toLowerCase().contains(kw)) ||
      (m.summary?.toLowerCase().contains(kw) ?? false) ||
      m.genres.any((g) => g.toLowerCase().contains(kw)) ||
      m.directors.any((d) => d.toLowerCase().contains(kw)) ||
      m.writers.any((w) => w.toLowerCase().contains(kw)) ||
      m.actors.any((a) => a.toLowerCase().contains(kw));

  bool _bookMatch(Book b, String kw) =>
      b.title.toLowerCase().contains(kw) ||
      b.alternateTitles.any((t) => t.toLowerCase().contains(kw)) ||
      (b.summary?.toLowerCase().contains(kw) ?? false) ||
      b.authors.any((a) => a.toLowerCase().contains(kw));

  bool _noteMatch(Note n, String kw) =>
      n.title.toLowerCase().contains(kw) ||
      n.content.toLowerCase().contains(kw) ||
      n.tags.any((t) => t.toLowerCase().contains(kw));

  bool _gameMatch(Game g, String kw) =>
      g.title.toLowerCase().contains(kw) ||
      g.genres.any((e) => e.toLowerCase().contains(kw)) ||
      g.platforms.any((p) => p.toLowerCase().contains(kw)) ||
      g.versions.any((v) => v.toLowerCase().contains(kw));

  // 分集/章节/关卡命中（标题、评价、序号）后并入对应父类 chip
  bool _episodeMatch(MovieEpisode e, String kw) =>
      e.title.toLowerCase().contains(kw) ||
      e.review.toLowerCase().contains(kw) ||
      '${e.episodeNo}'.contains(kw);

  bool _chapterMatch(BookChapter c, String kw) =>
      c.title.toLowerCase().contains(kw) ||
      c.review.toLowerCase().contains(kw) ||
      '${c.chapterNo}'.contains(kw);

  bool _levelMatch(GameLevel l, String kw) =>
      l.title.toLowerCase().contains(kw) ||
      l.review.toLowerCase().contains(kw) ||
      '${l.levelNo}'.contains(kw);

  Set<String> _matchingParentIds<T>(List<T> items, bool Function(T) match, String Function(T) parentOf) {
    final ids = <String>{};
    for (final e in items) {
      if (match(e)) ids.add(parentOf(e));
    }
    return ids;
  }

  /// 自定义条目：匹配标题 + 表单内全部字段值（文本、多行、状态、日期、
  /// 数量、评分、时长、进度、日期范围等）；封面/多图字段仅存文件路径，跳过。
  /// 直接遍历 data 而非依赖当前激活设计，避免切换/编辑设计后旧条目搜不到。
  bool _customItemMatch(CustomModuleItem item, String kw, CustomModuleDesign? design) {
    if (item.title.toLowerCase().contains(kw)) return true;
    final imageKeys = <String>{};
    if (design != null) {
      for (final field in design.fields) {
        if (field.type == CustomFieldType.poster ||
            field.type == CustomFieldType.multiImage) {
          imageKeys.add(field.key);
        }
      }
    }
    for (final entry in item.data.entries) {
      if (imageKeys.contains(entry.key)) continue;
      if (_valueContainsKeyword(entry.value, kw)) return true;
    }
    return false;
  }

  /// 递归匹配字段值：String 做小写包含，num 转字符串（评分/数量/时长/年份），
  /// List/Map 逐层下钻（multiText、progress、dateRange 等）。
  bool _valueContainsKeyword(dynamic value, String kw) {
    if (value == null) return false;
    if (value is String) return value.toLowerCase().contains(kw);
    if (value is num) return value.toString().contains(kw);
    if (value is List) return value.any((e) => _valueContainsKeyword(e, kw));
    if (value is Map) return value.values.any((e) => _valueContainsKeyword(e, kw));
    return value.toString().toLowerCase().contains(kw);
  }

  Future<CustomModuleDesign?> _designFor(String moduleId) async {
    if (_designCache.containsKey(moduleId)) return _designCache[moduleId];
    final design = await _designDao.getActiveDesign(moduleId);
    _designCache[moduleId] = design;
    return design;
  }

  Future<void> _performSearch() async {
    final token = ++_searchToken;
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _matchingTags = [];
        _selectedTag = null;
        _counts.updateAll((_, __) => 0);
      });
      return;
    }
    final provider = context.read<AppProvider>();
    final kw = keyword.toLowerCase();
    final results = <_SearchResult>[];

    // 分集/章节/关卡命中并入父类
    final episodes = await provider.getAllMovieEpisodes();
    final chapters = await provider.getAllBookChapters();
    final levels = await provider.getAllGameLevels();
    final episodeParents =
        _matchingParentIds(episodes, (e) => _episodeMatch(e, kw), (e) => e.movieId);
    final chapterParents =
        _matchingParentIds(chapters, (c) => _chapterMatch(c, kw), (c) => c.bookId);
    final levelParents =
        _matchingParentIds(levels, (l) => _levelMatch(l, kw), (l) => l.gameId);
    bool movieHit(Movie m) => _movieMatch(m, kw) || episodeParents.contains(m.id);
    bool bookHit(Book b) => _bookMatch(b, kw) || chapterParents.contains(b.id);
    bool gameHit(Game g) => _gameMatch(g, kw) || levelParents.contains(g.id);

    if (_showMovies) {
      for (final movie in provider.movies.where((m) => !m.isDeleted && movieHit(m))) {
        results.add(_SearchResult(type: 'movie', data: movie));
      }
    }
    if (_showBooks) {
      for (final book in provider.books.where((b) => !b.isDeleted && bookHit(b))) {
        results.add(_SearchResult(type: 'book', data: book));
      }
    }
    if (_showNotes) {
      for (final note in provider.notes.where((n) => !n.isDeleted && _noteMatch(n, kw))) {
        results.add(_SearchResult(type: 'note', data: note));
      }
    }
    if (_showGames) {
      for (final game in provider.games.where((g) => !g.isDeleted && gameHit(g))) {
        results.add(_SearchResult(type: 'game', data: game));
      }
    }
    final customItems = await provider.ensureCustomItemsLoaded();
    if (_showCustom) {
      for (final item in customItems) {
        final design = await _designFor(item.moduleId);
        if (_customItemMatch(item, kw, design)) {
          results.add(_SearchResult(type: 'custom', data: item));
        }
      }
    }

    if (!mounted || token != _searchToken) return;
    // 计数不受筛选开关影响，始终反映该关键词下各类型的总命中数
    _counts['movie'] = provider.movies.where((m) => !m.isDeleted && movieHit(m)).length;
    _counts['book'] = provider.books.where((b) => !b.isDeleted && bookHit(b)).length;
    _counts['note'] = provider.notes.where((n) => !n.isDeleted && _noteMatch(n, kw)).length;
    _counts['game'] = provider.games.where((g) => !g.isDeleted && gameHit(g)).length;
    var customCount = 0;
    for (final item in customItems) {
      if (_customItemMatch(item, kw, await _designFor(item.moduleId))) customCount++;
    }
    _counts['custom'] = customCount;

    setState(() {
      _results = results;
      _hasSearched = true;
      _matchingTags = _collectMatchingTags(kw);
      _selectedTag = null;
    });
  }

  /// 收集所有包含关键词的标签
  List<String> _collectMatchingTags(String lowerKeyword) {
    final provider = context.read<AppProvider>();
    final tagSet = <String>{};
    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      for (final g in m.genres) {
        if (g.toLowerCase().contains(lowerKeyword)) tagSet.add(g);
      }
    }
    for (final b in provider.books.where((b) => !b.isDeleted)) {
      for (final g in b.genres) {
        if (g.toLowerCase().contains(lowerKeyword)) tagSet.add(g);
      }
    }
    for (final n in provider.notes.where((n) => !n.isDeleted)) {
      for (final t in n.tags) {
        if (t.toLowerCase().contains(lowerKeyword)) tagSet.add(t);
      }
    }
    for (final g in provider.games.where((g) => !g.isDeleted)) {
      for (final genre in g.genres) {
        if (genre.toLowerCase().contains(lowerKeyword)) tagSet.add(genre);
      }
    }
    return tagSet.toList()..sort();
  }

  /// 按标签筛选：点击标签后只显示包含该标签的结果
  void _filterByTag(String tag) {
    final provider = context.read<AppProvider>();
    setState(() {
      _selectedTag = tag;
      final results = <_SearchResult>[];
      for (final m in provider.movies.where((m) => !m.isDeleted)) {
        if (m.genres.contains(tag)) results.add(_SearchResult(type: 'movie', data: m));
      }
      for (final b in provider.books.where((b) => !b.isDeleted)) {
        if (b.genres.contains(tag)) results.add(_SearchResult(type: 'book', data: b));
      }
      for (final n in provider.notes.where((n) => !n.isDeleted)) {
        if (n.tags.contains(tag)) results.add(_SearchResult(type: 'note', data: n));
      }
      for (final g in provider.games.where((g) => !g.isDeleted)) {
        if (g.genres.contains(tag)) results.add(_SearchResult(type: 'game', data: g));
      }
      _results = results;
    });
  }

  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: Column(children: [
        _buildSearchBar(),
        _buildFilterRow(),
        Expanded(
          child: _hasSearched
              ? _results.isEmpty && _matchingTags.isEmpty ? _buildEmptyState() : _buildResultList()
              : _buildInitialState(),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(fontSize: 15, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: '搜索标题、作者、标签...'.tr,
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3), fontSize: 15),
          prefixIcon: Icon(Icons.search, color: colors.onSurface.withValues(alpha: 0.4), size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () { _searchController.clear(); setState(() {}); _scheduleSearch(); _focusNode.requestFocus(); },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.close, color: colors.onSurface.withValues(alpha: 0.5), size: 16),
                  ),
                )
              : null,
          filled: true, fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: colors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) { _debounce?.cancel(); _performSearch(); },
        onChanged: (_) { _debounce?.cancel(); setState(() {}); _scheduleSearch(); },
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 34,
        child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        children: [
          _filterChip('影视'.tr, Icons.movie_outlined, _showMovies, _counts['movie']!, () { setState(() { _showMovies = !_showMovies; _performSearch(); }); }),
          const SizedBox(width: 8),
          _filterChip('书籍'.tr, Icons.menu_book_outlined, _showBooks, _counts['book']!, () { setState(() { _showBooks = !_showBooks; _performSearch(); }); }),
          const SizedBox(width: 8),
          _filterChip('笔记'.tr, Icons.sticky_note_2_outlined, _showNotes, _counts['note']!, () { setState(() { _showNotes = !_showNotes; _performSearch(); }); }),
          const SizedBox(width: 8),
          _filterChip('游戏'.tr, Icons.sports_esports_outlined, _showGames, _counts['game']!, () { setState(() { _showGames = !_showGames; _performSearch(); }); }),
          const SizedBox(width: 8),
          _filterChip('自定义'.tr, Icons.dashboard_customize_outlined, _showCustom, _counts['custom']!, () { setState(() { _showCustom = !_showCustom; _performSearch(); }); }),
        ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, IconData icon, bool selected, int count, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    final showCount = _searchController.text.trim().isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.4)), overflow: TextOverflow.ellipsis)),
          if (showCount) ...[const SizedBox(width: 3), Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? colors.onPrimary.withValues(alpha: 0.7) : colors.onSurface.withValues(alpha: 0.25)))],
        ]),
      ),
    );
  }

  Widget _buildInitialState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.search_rounded, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 20),
        Text('输入关键词搜索'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.35))),
        const SizedBox(height: 4),
        Text('支持标题、导演、作者、标签、简介'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.2))),
      ]),
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.search_off_rounded, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 20),
        Text('未找到相关内容'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.35))),
        const SizedBox(height: 4),
        Text('换个关键词试试'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.2))),
      ]),
    );
  }

  Widget _buildResultList() {
    final colors = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 标签筛选区
      if (_matchingTags.isNotEmpty) _buildTagSection(colors),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Text(_selectedTag != null
            ? '标签 "{tag}" 共 {n} 条'.trf({'tag': _selectedTag, 'n': _results.length})
            : '找到 {n} 条结果'.trf({'n': _results.length}),
            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
      ),
      Expanded(
        child: _results.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  switch (item.type) {
                    case 'movie': return _buildMovieItem(item.data as Movie);
                    case 'book': return _buildBookItem(item.data as Book);
                    case 'note': return _buildNoteItem(item.data as Note);
                    case 'game': return _buildGameItem(item.data as Game);
                    case 'custom': return _buildCustomItem(item.data as CustomModuleItem);
                    default: return const SizedBox.shrink();
                  }
                },
              ),
      ),
    ]);
  }

  Widget _buildTagSection(ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.label_outline, size: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            const SizedBox(width: 4),
            Text('匹配标签'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            if (_selectedTag != null) ...[
              const Spacer(),
              GestureDetector(
                onTap: () { setState(() { _selectedTag = null; }); _performSearch(); },
                child: Text('清除筛选'.tr, style: TextStyle(fontSize: 12, color: colors.primary)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _matchingTags.map((tag) {
              final isSelected = _selectedTag == tag;
              return GestureDetector(
                onTap: () => _filterByTag(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? colors.primary : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Text(tag, style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
                  )),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieItem(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _posterThumb(movie.posterPath, Icons.movie_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge('影视'.tr),
                const Spacer(),
                _statusBadge(movie.status, colors),
              ]),
              const SizedBox(height: 6),
              Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const SizedBox(height: 4),
              Row(children: [
                if (movie.rating != null) ...[
                  const Icon(Icons.star, size: 13, color: Color(0xFFFFB800)),
                  const SizedBox(width: 2),
                  Text('${movie.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
                  const SizedBox(width: 8),
                ],
                if (movie.genres.isNotEmpty)
                  Expanded(child: Text(movie.genres.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)))),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
        ]),
      ),
    );
  }

  Widget _buildBookItem(Book book) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _posterThumb(book.coverPath, Icons.menu_book_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge('书籍'.tr),
                const Spacer(),
                _statusBadge(book.status, colors, mediaType: 'book'),
              ]),
              const SizedBox(height: 6),
              Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const SizedBox(height: 4),
              Row(children: [
                if (book.rating != null) ...[
                  const Icon(Icons.star, size: 13, color: Color(0xFFFFB800)),
                  const SizedBox(width: 2),
                  Text('${book.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
                  const SizedBox(width: 8),
                ],
                if (book.authors.isNotEmpty)
                  Expanded(child: Text(book.authors.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)))),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
        ]),
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    final colors = Theme.of(context).colorScheme;
    final summary = note.summary.trim().isEmpty ? '(无内容)'.tr : note.summary.trim();
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: note))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _typeBadge('笔记'.tr),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.5)),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: note.tags.map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(4)),
                  child: Text(t, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                )).toList()),
              ],
            ]),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
          ),
        ]),
      ),
    );
  }

  Widget _buildGameItem(Game game) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameDetailPage(game: game))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _posterThumb(game.coverPath, Icons.sports_esports_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge('游戏'.tr),
                const Spacer(),
                _statusBadge(game.status, colors, mediaType: 'game'),
              ]),
              const SizedBox(height: 6),
              Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              const SizedBox(height: 4),
              Row(children: [
                if (game.rating != null) ...[
                  const Icon(Icons.star, size: 13, color: Color(0xFFFFB800)),
                  const SizedBox(width: 2),
                  Text('${game.rating}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
                  const SizedBox(width: 8),
                ],
                if (game.platforms.isNotEmpty)
                  Expanded(child: Text(game.platforms.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)))),
              ]),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
        ]),
      ),
    );
  }

  Widget _buildCustomItem(CustomModuleItem item) {
    final colors = Theme.of(context).colorScheme;
    final module = context.read<AppProvider>().getCustomModuleById(item.moduleId);
    final title = item.title.trim().isEmpty ? '(无标题)'.tr : item.title;
    return GestureDetector(
      onTap: () {
        if (module == null) return;
        Navigator.push(context, SlideUpPageRoute(
          page: CustomModuleDetailPage(module: module, itemId: item.id),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _posterThumb(item.coverPath, Icons.dashboard_customize_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _typeBadge(module?.name ?? '自定义'.tr),
                const Spacer(),
                if (item.status != null && item.status!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                    child: Text(item.status!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ]),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.15), size: 18),
        ]),
      ),
    );
  }

  Widget _posterThumb(String? path, IconData fallback) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 44, height: 58,
      decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: path != null && path.isNotEmpty
          ? FadeInLocalImage(path: path, fit: BoxFit.cover,
              errorWidget: Icon(fallback, size: 20, color: colors.onSurface.withValues(alpha: 0.25)))
          : Icon(fallback, size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
    );
  }

  Widget _typeBadge(String label) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.primary)),
    );
  }

  Widget _statusBadge(String status, ColorScheme colors, {String mediaType = 'movie'}) {
    final Map<String, String> labels = switch (mediaType) {
      'book' => const {
          'done': '已读',
          'ing': '在读',
          'want': '想读',
          'abandoned': '弃读',
        },
      'game' => const {
          'done': '已通关',
          'ing': '在玩',
          'want': '想玩',
          'abandoned': '弃游',
        },
      _ => const {
          'done': '已看',
          'ing': '在看',
          'want': '想看',
          'abandoned': '弃看',
        },
    };
    final key = switch (status) {
      'watched' || 'read' || 'completed' => 'done',
      'watching' || 'reading' || 'playing' => 'ing',
      'want_to_watch' || 'want_to_read' || 'want_to_play' => 'want',
      'abandoned' => 'abandoned',
      _ => '',
    };
    final (bg, fg) = switch (key) {
      'done' => (colors.primary, colors.onPrimary),
      'ing' => (colors.outlineVariant, colors.onSurface.withValues(alpha: 0.6)),
      'want' => (colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.4)),
      'abandoned' => (colors.errorContainer, colors.onError),
      _ => (colors.surfaceContainerHighest, colors.onSurface.withValues(alpha: 0.3)),
    };
    final label = labels[key] ?? '';
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _SearchResult {
  final String type;
  final dynamic data;
  _SearchResult({required this.type, required this.data});
}
