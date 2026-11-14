import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/app_back_button.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/person_avatar.dart';
import '../../services/cloud/cloud_explore_service.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../../l10n/app_strings.dart';

/// 角色信息页面 - 列出所有导演/主演/编剧/作者
class PersonListPage extends StatefulWidget {
  const PersonListPage({super.key});

  @override
  State<PersonListPage> createState() => _PersonListPageState();
}

class _PersonListPageState extends State<PersonListPage> {
  String _filter = 'all'; // all / 导演 / 编剧 / 主演 / 作者
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;

  // ── 云端轻量行（云模式域使用，本地域仍读 AppProvider）──
  bool get _anyCloud =>
      UserPrefs().cloudMovieMode || UserPrefs().cloudBookMode;
  bool _cloudError = false;
  List<Movie> _cloudMovies = const [];
  List<Book> _cloudBooks = const [];

  // 服务端作品行分页（人物由客户端聚合，分页落在作品行上）
  static const int _pageSize = 50;
  int _page = 0;
  bool _hasMore = true;
  bool _loadingMore = false;

  // 人物列表的显示窗口：本地全量数据与云端已聚合结果统一走窗口切片，触底扩窗
  static const int _visibleWindow = 30;
  int _visibleCount = _visibleWindow;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 300) {
      return;
    }
    final total = _filteredPersons().length;
    if (_visibleCount < total) {
      // 已加载数据还有未展示的人物，先扩显示窗口
      setState(() => _visibleCount += _visibleWindow);
    } else if (_anyCloud && _hasMore && !_loadingMore && !_loading) {
      _loadMore();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _cloudError = false;
      _page = 0;
      _hasMore = true;
      _loadingMore = false;
      _visibleCount = _visibleWindow;
    });
    final prefs = UserPrefs();
    final provider = context.read<AppProvider>();
    try {
      if (_anyCloud) {
        final data = await CloudExploreService.instance
            .fetchPersons(page: 0, size: _pageSize);
        _cloudMovies = data.movies;
        _cloudBooks = data.books;
        _hasMore = data.hasMore;
      }
      // 混合模式：本地域仍加载内存首页；纯云端域跳过
      await Future.wait([
        if (!prefs.cloudMovieMode) provider.loadMovies(),
        if (!prefs.cloudBookMode) provider.loadBooks(),
      ]);
    } catch (_) {
      _cloudError = _anyCloud;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 触底加载云端作品下一页，追加后人物聚合在 build 时随累积数据重建
  Future<void> _loadMore() async {
    _loadingMore = true;
    final nextPage = _page + 1;
    try {
      final data = await CloudExploreService.instance
          .fetchPersons(page: nextPage, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _hasMore = data.hasMore;
        _cloudMovies = [..._cloudMovies, ...data.movies];
        _cloudBooks = [..._cloudBooks, ...data.books];
      });
    } catch (_) {
      if (mounted) ToastUtil.show(context, '加载失败，请检查网络'.tr);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  List<_PersonEntry> _buildPersons() {
    final prefs = UserPrefs();
    final provider = context.read<AppProvider>();
    // 云模式域走轻量行（服务端已过滤软删除），本地域读 Provider 并过滤
    final movies = prefs.cloudMovieMode
        ? _cloudMovies
        : provider.movies.where((m) => !m.isDeleted).toList();
    final books = prefs.cloudBookMode
        ? _cloudBooks
        : provider.books.where((b) => !b.isDeleted).toList();
    final map = <String, _PersonEntry>{};

    void addRole(String name, String role, {Movie? movie, Book? book}) {
      if (name.trim().isEmpty) return;
      final key = name.trim();
      map.putIfAbsent(key, () => _PersonEntry(name: key));
      map[key]!.roles.add(role);
      if (movie != null && !map[key]!.movies.any((m) => m.id == movie.id)) {
        map[key]!.movies.add(movie);
      }
      if (book != null && !map[key]!.books.any((b) => b.id == book.id)) {
        map[key]!.books.add(book);
      }
    }

    for (final m in movies) {
      for (final d in m.directors) {
        addRole(d, '导演', movie: m);
      }
      for (final w in m.writers) {
        addRole(w, '编剧', movie: m);
      }
      for (final a in m.actors) {
        addRole(a, '主演', movie: m);
      }
    }
    for (final b in books) {
      for (final a in b.authors) {
        addRole(a, '作者', book: b);
      }
      for (final t in b.translators) {
        addRole(t, '译者', book: b);
      }
    }

    var list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  /// 已加载作品行聚合出的人物，再按角色/搜索词过滤
  List<_PersonEntry> _filteredPersons() {
    return _buildPersons().where((p) {
      if (_filter != 'all' && !p.roles.contains(_filter)) return false;
      if (_searchQuery.isNotEmpty &&
          !p.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_cloudError) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(leading: const AppBackButton(), title: Text('角色信息'.tr)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 44, color: colors.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('云端记录加载失败'.tr,
                  style: TextStyle(color: colors.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 12),
              TextButton(onPressed: _refresh, child: Text('重试'.tr)),
            ],
          ),
        ),
      );
    }
    final filtered = _filteredPersons();
    final visible = filtered.take(_visibleCount).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('角色信息'.tr),
        actions: [
          IconButton(
            icon: _loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurface.withValues(alpha: 0.5)))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 15, color: colors.onSurface),
                      cursorColor: colors.primary,
                      decoration: InputDecoration(
                        hintText: '搜索导演、编剧、演员、作者、译者'.tr,
                        hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: (v) => setState(() {
                        _searchQuery = v.trim();
                        _visibleCount = _visibleWindow;
                      }),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); FocusManager.instance.primaryFocus?.unfocus(); },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle),
                        child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                ],
              ),
            ),
          ),

          // 角色筛选
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              children: [
                for (final f in ['all', '导演', '编剧', '主演', '作者', '译者'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _filter = f;
                        _visibleCount = _visibleWindow;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filter == f ? colors.primary : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(f == 'all' ? '全部'.tr : f.tr,
                            style: TextStyle(fontSize: 12, fontWeight: _filter == f ? FontWeight.w600 : FontWeight.normal,
                                color: _filter == f ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 数量
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('共 {n} 人'.trf({'n': filtered.length}), style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            ),
          ),

          // 列表
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(child: Text('暂无数据'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, i) {
                      if (i == visible.length) {
                        return _buildListFooter(colors, filtered.length);
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0) Divider(height: 0.5, color: colors.outlineVariant),
                          _buildPersonTile(visible[i], colors),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 列表底部：云端翻页转圈 / 手动加载更多（兜底新页无新人的情况）/ 没有更多
  Widget _buildListFooter(ColorScheme colors, int total) {
    if (_loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        ),
      );
    }
    if (_anyCloud && _hasMore && _visibleCount >= total) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: TextButton(onPressed: _loadMore, child: Text('加载更多'.tr)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text('没有更多了'.tr,
            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
      ),
    );
  }

  Widget _buildPersonTile(_PersonEntry person, ColorScheme colors) {
    final roleColors = {
      '导演': const Color(0xFF4A90D9),
      '编剧': const Color(0xFF009688),
      '主演': const Color(0xFFE91E63),
      '作者': const Color(0xFF7E57C2),
      '译者': const Color(0xFFFF7043),
    };
    final totalWorks = person.movies.length + person.books.length;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: PersonAvatar(
        photoPath: null,
        name: person.name,
        size: 40,
        fontSize: 16,
      ),
      title: Text(person.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final role in person.roles.toSet())
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (roleColors[role] ?? colors.outline).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(role.tr, style: TextStyle(fontSize: 10, color: roleColors[role] ?? colors.onSurface)),
              ),
            Text('{n} 部作品'.trf({'n': totalWorks}), style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.35))),
          ],
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PersonDetailPage(person: person),
      )),
    );
  }
}

// ─── 人物详情页（只读展示）───

class _PersonDetailPage extends StatelessWidget {
  final _PersonEntry person;
  const _PersonDetailPage({required this.person});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final roleColors = {
      '导演': const Color(0xFF4A90D9),
      '编剧': const Color(0xFF009688),
      '主演': const Color(0xFFE91E63),
      '作者': const Color(0xFF7E57C2),
      '译者': const Color(0xFFFF7043),
    };

    final movieItems = <_WorkItem>[];
    final bookItems = <_WorkItem>[];

    for (final m in person.movies) {
      final roles = <String>[];
      if (m.directors.contains(person.name)) roles.add('导演');
      if (m.writers.contains(person.name)) roles.add('编剧');
      if (m.actors.contains(person.name)) roles.add('主演');
      movieItems.add(_WorkItem(title: m.title, roles: roles, path: m.posterPath, data: m));
    }
    for (final b in person.books) {
      final roles = <String>[];
      if (b.authors.contains(person.name)) roles.add('作者');
      if (b.translators.contains(person.name)) roles.add('译者');
      bookItems.add(_WorkItem(title: b.title, roles: roles, path: b.coverPath, data: b));
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(leading: const AppBackButton(), title: Text(person.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // 角色标签
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final role in person.roles.toSet())
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (roleColors[role] ?? colors.outline).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(role.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: roleColors[role] ?? colors.onSurface)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 影视作品
          if (movieItems.isNotEmpty) ...[
            Text('影视作品（{n}）'.trf({'n': movieItems.length}), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            for (final item in movieItems) _buildWorkTile(context, item, colors, isMovie: true),
            const SizedBox(height: 16),
          ],

          // 书籍作品
          if (bookItems.isNotEmpty) ...[
            Text('书籍作品（{n}）'.trf({'n': bookItems.length}), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            for (final item in bookItems) _buildWorkTile(context, item, colors, isMovie: false),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkTile(BuildContext context, _WorkItem item, ColorScheme colors, {required bool isMovie}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _openWork(context, item, isMovie),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 44, height: 44,
                  child: item.path != null && item.path!.isNotEmpty
                      ? _workImage(item.path!, colors, isMovie)
                      : Container(color: colors.surfaceContainerHighest,
                          child: Icon(isMovie ? Icons.movie_outlined : Icons.menu_book_outlined,
                              size: 16, color: colors.onSurface.withValues(alpha: 0.3))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(item.roles.map((r) => r.tr).join(' · '), style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                ]),
              ),
              Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
            ],
          ),
        ),
      ),
    );
  }

  /// 作品封面：云模式为 OSS 网络 URL，本地模式为文件路径
  Widget _workImage(String path, ColorScheme colors, bool isMovie) {
    final errorWidget = Container(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.image_outlined,
          size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
    );
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => errorWidget);
    }
    return Image(image: FileImage(File(path)),
        fit: BoxFit.cover, errorBuilder: (_, __, ___) => errorWidget);
  }

  /// 点击作品：云模式轻量行先按 id 拉完整实体再进详情
  Future<void> _openWork(BuildContext context, _WorkItem item, bool isMovie) async {
    final prefs = UserPrefs();
    final isCloud = isMovie ? prefs.cloudMovieMode : prefs.cloudBookMode;
    dynamic data = item.data;
    if (isCloud) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        final provider = context.read<AppProvider>();
        data = isMovie
            ? await provider.cloudMovieById((item.data as Movie).id)
            : await provider.cloudBookById((item.data as Book).id);
      } finally {
        if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
      }
      if (data == null) {
        if (context.mounted) ToastUtil.show(context, '加载失败，请检查网络'.tr);
        return;
      }
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMovie
            ? MovieDetailPage(movie: data as Movie)
            : BookDetailPage(book: data as Book),
      ),
    );
  }
}

// ─── 数据模型 ───

class _PersonEntry {
  final String name;
  final Set<String> roles = {};
  final List<Movie> movies = [];
  final List<Book> books = [];

  _PersonEntry({required this.name});
}

class _WorkItem {
  final String title;
  final List<String> roles;
  final String? path;
  final dynamic data;

  _WorkItem({required this.title, required this.roles, this.path, required this.data});
}
