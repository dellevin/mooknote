import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';

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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final provider = context.read<AppProvider>();
    await Future.wait([
      provider.loadMovies(),
      provider.loadBooks(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  List<_PersonEntry> _buildPersons() {
    final provider = context.read<AppProvider>();
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

    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      for (final d in m.directors) addRole(d, '导演', movie: m);
      for (final w in m.writers) addRole(w, '编剧', movie: m);
      for (final a in m.actors) addRole(a, '主演', movie: m);
    }
    for (final b in provider.books.where((b) => !b.isDeleted)) {
      for (final a in b.authors) addRole(a, '作者', book: b);
      for (final t in b.translators) addRole(t, '译者', book: b);
    }

    var list = map.values.toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allPersons = _buildPersons();

    var filtered = allPersons.where((p) {
      if (_filter != 'all' && !p.roles.contains(_filter)) return false;
      if (_searchQuery.isNotEmpty && !p.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('角色信息'),
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
                        hintText: '搜索导演、编剧、演员、作者、译者',
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
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
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
                      onTap: () => setState(() => _filter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _filter == f ? colors.primary : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(f == 'all' ? '全部' : f,
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
              child: Text('共 ${filtered.length} 人', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            ),
          ),

          // 列表
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('暂无数据', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 0.5, color: colors.outlineVariant),
                    itemBuilder: (_, i) => _buildPersonTile(filtered[i], colors),
                  ),
          ),
        ],
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
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: colors.surfaceContainerHighest,
        child: Text(
          person.name.isNotEmpty ? person.name[0] : '?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5)),
        ),
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
                child: Text(role, style: TextStyle(fontSize: 10, color: roleColors[role] ?? colors.onSurface)),
              ),
            Text('$totalWorks 部作品', style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.35))),
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
      appBar: AppBar(title: Text(person.name)),
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
                  child: Text(role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: roleColors[role] ?? colors.onSurface)),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 影视作品
          if (movieItems.isNotEmpty) ...[
            Text('影视作品（${movieItems.length}）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            for (final item in movieItems) _buildWorkTile(context, item, colors, isMovie: true),
            const SizedBox(height: 16),
          ],

          // 书籍作品
          if (bookItems.isNotEmpty) ...[
            Text('书籍作品（${bookItems.length}）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.6))),
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
        onTap: () {
          if (isMovie) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
          }
        },
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
                      ? Image(image: FileImage(File(item.path!)), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: colors.surfaceContainerHighest,
                              child: Icon(Icons.image_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.2))))
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
                  Text(item.roles.join(' · '), style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                ]),
              ),
              Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.2)),
            ],
          ),
        ),
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
