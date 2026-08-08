import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import 'fade_in_local_image.dart';

/// 人物详情页使用的作品关联结果（按媒体类型分组）
class WorkSelectionResult {
  final List<MoviePerson> movies;
  final List<BookPerson> books;
  final List<GamePerson> games;

  WorkSelectionResult({required this.movies, required this.books, required this.games});
}

/// 一条"作品 + 角色"选择（内部用）
class _WorkRoleEntry {
  final String workId; // movieId / bookId / gameId
  final String workType; // 'movie' / 'book' / 'game'
  final String roleType;
  final String? characterName; // 仅影视 actor

  _WorkRoleEntry({
    required this.workId,
    required this.workType,
    required this.roleType,
    this.characterName,
  });
}

/// 作品选择独立页面（人物详情页使用）
/// 选择影视/书籍/游戏作品并为每个作品分配 1~N 个角色
/// 支持按作品标题或人物名称搜索
class WorkSelectorPage extends StatefulWidget {
  final String personId;
  final List<MoviePerson> initialMovies;
  final List<BookPerson> initialBooks;
  final List<GamePerson> initialGames;

  const WorkSelectorPage({
    super.key,
    required this.personId,
    required this.initialMovies,
    required this.initialBooks,
    required this.initialGames,
  });

  static Future<WorkSelectionResult?> show({
    required BuildContext context,
    required String personId,
    required List<MoviePerson> initialMovies,
    required List<BookPerson> initialBooks,
    required List<GamePerson> initialGames,
  }) {
    return Navigator.push<WorkSelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => WorkSelectorPage(
          personId: personId,
          initialMovies: initialMovies,
          initialBooks: initialBooks,
          initialGames: initialGames,
        ),
      ),
    );
  }

  @override
  State<WorkSelectorPage> createState() => _WorkSelectorPageState();
}

class _WorkSelectorPageState extends State<WorkSelectorPage> {
  /// 所有已选的"作品+角色"条目（影视/书籍/游戏混在一起，靠 workType 区分）
  final List<_WorkRoleEntry> _entries = [];

  /// 当前 Tab：0=影视 1=书籍 2=游戏
  int _tabIndex = 0;
  String _query = '';

  /// 搜索模式：0=按作品标题 1=按人物名称
  int _searchMode = 0;

  /// 人物名称搜索结果：personId → 该人物在当前 Tab 作品类型下的关联作品 ID 集合
  List<Person> _matchedPeople = [];
  bool _searching = false;

  static const _movieRoles = [('director', '导演'), ('writer', '编剧'), ('actor', '演员')];
  static const _bookRoles = [('author', '作者'), ('translator', '译者')];
  static const _gameRoles = [('developer', '开发者')];

  @override
  void initState() {
    super.initState();
    for (final mp in widget.initialMovies) {
      _entries.add(_WorkRoleEntry(workId: mp.movieId, workType: 'movie', roleType: mp.roleType, characterName: mp.characterName));
    }
    for (final bp in widget.initialBooks) {
      _entries.add(_WorkRoleEntry(workId: bp.bookId, workType: 'book', roleType: bp.roleType));
    }
    for (final gp in widget.initialGames) {
      _entries.add(_WorkRoleEntry(workId: gp.gameId, workType: 'game', roleType: gp.roleType));
    }
  }

  String get _currentWorkType => switch (_tabIndex) { 0 => 'movie', 1 => 'book', 2 => 'game', _ => 'movie' };
  List<(String, String)> get _currentRoleOptions => switch (_tabIndex) { 0 => _movieRoles, 1 => _bookRoles, 2 => _gameRoles, _ => _movieRoles };

  /// 按人物名称搜索：找到匹配的人物，再反查他们参与的当前 Tab 类型作品
  Future<void> _searchByPerson(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _matchedPeople = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final provider = context.read<AppProvider>();
    final people = await provider.searchPeople(trimmed);
    if (!mounted) return;
    setState(() {
      _matchedPeople = people;
      _searching = false;
    });
  }

  /// 获取人物在当前 Tab 类型下的作品 ID 集合
  Future<Set<String>> _getPersonWorkIds(Person person) async {
    final provider = context.read<AppProvider>();
    switch (_currentWorkType) {
      case 'movie':
        final rels = await provider.getPersonMovies(person.id);
        return rels.map((r) => r.movieId).toSet();
      case 'book':
        final rels = await provider.getPersonBooks(person.id);
        return rels.map((r) => r.bookId).toSet();
      case 'game':
        final rels = await provider.getPersonGames(person.id);
        return rels.map((r) => r.gameId).toSet();
    }
    return {};
  }

  void _changeRole(_WorkRoleEntry entry, String roleType) {
    setState(() {
      final idx = _entries.indexOf(entry);
      if (idx < 0) return;
      _entries[idx] = _WorkRoleEntry(
        workId: entry.workId,
        workType: entry.workType,
        roleType: roleType,
        characterName: entry.workType == 'movie' && roleType == 'actor' ? entry.characterName : null,
      );
    });
  }

  void _editCharacterName(_WorkRoleEntry entry, String name) {
    setState(() {
      final idx = _entries.indexOf(entry);
      if (idx < 0) return;
      _entries[idx] = _WorkRoleEntry(
        workId: entry.workId,
        workType: entry.workType,
        roleType: entry.roleType,
        characterName: name.isEmpty ? null : name,
      );
    });
  }

  void _removeEntry(_WorkRoleEntry entry) {
    setState(() => _entries.remove(entry));
  }

  /// 为已选作品追加一个新角色条目（多角色）
  void _addRoleToWork(String workId) {
    final usedRoles = _entries
        .where((e) => e.workType == _currentWorkType && e.workId == workId)
        .map((e) => e.roleType)
        .toSet();
    final nextRole = _currentRoleOptions.firstWhere((r) => !usedRoles.contains(r.$1), orElse: () => _currentRoleOptions.first);
    setState(() {
      _entries.add(_WorkRoleEntry(
        workId: workId,
        workType: _currentWorkType,
        roleType: nextRole.$1,
      ));
    });
  }

  void _onConfirm() {
    final movies = _entries
        .where((e) => e.workType == 'movie')
        .map((e) => MoviePerson(
              id: const Uuid().v4(),
              movieId: e.workId,
              personId: widget.personId,
              roleType: e.roleType,
              characterName: e.characterName,
              sortOrder: 0,
            ))
        .toList();
    final books = _entries
        .where((e) => e.workType == 'book')
        .map((e) => BookPerson(
              id: const Uuid().v4(),
              bookId: e.workId,
              personId: widget.personId,
              roleType: e.roleType,
              sortOrder: 0,
            ))
        .toList();
    final games = _entries
        .where((e) => e.workType == 'game')
        .map((e) => GamePerson(
              id: const Uuid().v4(),
              gameId: e.workId,
              personId: widget.personId,
              roleType: e.roleType,
              sortOrder: 0,
            ))
        .toList();
    Navigator.pop(context, WorkSelectionResult(movies: movies, books: books, games: games));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('关联作品'),
        actions: [
          TextButton(
            onPressed: _onConfirm,
            child: Text('完成', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab 切换
          _buildTabs(colors),
          // 搜索模式切换
          _buildSearchModeToggle(colors),
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              cursorColor: colors.primary,
              decoration: InputDecoration(
                hintText: _searchMode == 0 ? '搜索作品标题' : '搜索人物名称',
                hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                filled: true,
                fillColor: colors.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
                prefixIcon: Icon(Icons.search, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                        onPressed: () {
                          setState(() {
                            _query = '';
                            _matchedPeople = [];
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                setState(() => _query = v);
                if (_searchMode == 1) {
                  _searchByPerson(v);
                }
              },
            ),
          ),
          // 可选作品列表
          Expanded(child: _searchMode == 0 ? _buildAvailableList(provider, colors) : _buildPersonSearchList(provider, colors)),
        ],
      ),
    );
  }

  Widget _buildTabs(ColorScheme colors) {
    const labels = ['影视', '书籍', '游戏'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _tabIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _tabIndex = i; _query = ''; _matchedPeople = []; }),
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchModeToggle(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _buildModeChip(0, '按作品', colors),
          const SizedBox(width: 8),
          _buildModeChip(1, '按人物', colors),
        ],
      ),
    );
  }

  Widget _buildModeChip(int mode, String label, ColorScheme colors) {
    final selected = _searchMode == mode;
    return GestureDetector(
      onTap: () => setState(() {
        _searchMode = mode;
        _query = '';
        _matchedPeople = [];
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
            color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// 按人物名称搜索结果列表
  Widget _buildPersonSearchList(AppProvider provider, ColorScheme colors) {
    if (_query.trim().isEmpty) {
      return Center(
        child: Text('输入人物名称搜索作品', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
      );
    }
    if (_searching) {
      return Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.onSurface.withValues(alpha: 0.3)));
    }
    if (_matchedPeople.isEmpty) {
      return Center(
        child: Text('未找到匹配的人物', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _matchedPeople.length,
      itemBuilder: (_, i) => _buildPersonItem(_matchedPeople[i], provider, colors),
    );
  }

  Widget _buildPersonItem(Person person, AppProvider provider, ColorScheme colors) {
    return FutureBuilder<Set<String>>(
      future: _getPersonWorkIds(person),
      builder: (ctx, snapshot) {
        final workIds = snapshot.data ?? {};
        final works = _getWorksByIds(workIds, provider);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 人物名
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle),
                    clipBehavior: Clip.antiAlias,
                    child: person.photoPath != null && person.photoPath!.isNotEmpty
                        ? FadeInLocalImage(path: person.photoPath, fit: BoxFit.cover)
                        : Center(
                            child: Text(
                              person.name.isNotEmpty ? person.name[0] : '?',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4)),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(person.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                        if (person.occupation.isNotEmpty)
                          Text(person.occupation.join(' / '),
                              style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  ),
                  if (works.isEmpty)
                    Text('暂无该类型作品', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                ],
              ),
              // 该人物在当前 Tab 下的作品列表
              ...works.map((work) => _buildPersonWorkItem(work, person, colors)),
            ],
          ),
        );
      },
    );
  }

  /// 根据 ID 集合获取当前 Tab 类型的作品列表 (id, title, coverPath)
  List<(String, String, String?)> _getWorksByIds(Set<String> ids, AppProvider provider) {
    switch (_currentWorkType) {
      case 'movie':
        return provider.movies
            .where((m) => !m.isDeleted && ids.contains(m.id))
            .map((m) => (m.id, m.title, m.posterPath))
            .toList();
      case 'book':
        return provider.books
            .where((b) => !b.isDeleted && ids.contains(b.id))
            .map((b) => (b.id, b.title, b.coverPath))
            .toList();
      case 'game':
        return provider.games
            .where((g) => !g.isDeleted && ids.contains(g.id))
            .map((g) => (g.id, g.title, g.coverPath))
            .toList();
    }
    return [];
  }

  Widget _buildPersonWorkItem((String, String, String?) work, Person person, ColorScheme colors) {
    final id = work.$1;
    final title = work.$2;
    final coverPath = work.$3;
    final workEntries = _entries.where((e) => e.workType == _currentWorkType && e.workId == id).toList();
    final canAddMore = workEntries.length < _currentRoleOptions.length;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCover(coverPath, 32, colors),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 13, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (canAddMore)
                  GestureDetector(
                    onTap: () => _addRoleToWork(id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: colors.primary),
                          const SizedBox(width: 2),
                          Text('角色', style: TextStyle(fontSize: 11, color: colors.primary)),
                        ],
                      ),
                    ),
                  )
                else
                  Icon(Icons.check_circle, size: 16, color: colors.onSurface.withValues(alpha: 0.3)),
              ],
            ),
            ...workEntries.map((entry) => _buildRoleRow(entry, colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDropdown(_WorkRoleEntry entry, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: DropdownButton<String>(
        value: entry.roleType,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: TextStyle(fontSize: 12, color: colors.onSurface),
        items: _roleOptionsFor(entry.workType)
            .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2, style: const TextStyle(fontSize: 12))))
            .toList(),
        onChanged: (v) { if (v != null) _changeRole(entry, v); },
      ),
    );
  }

  List<(String, String)> _roleOptionsFor(String workType) {
    return switch (workType) { 'movie' => _movieRoles, 'book' => _bookRoles, 'game' => _gameRoles, _ => _movieRoles };
  }

  Widget _buildCover(String? path, double size, ColorScheme colors) {
    final has = path != null && path.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size * 0.72,
        height: size,
        child: has
            ? FadeInLocalImage(path: path, fit: BoxFit.cover)
            : Container(color: colors.surfaceContainerHighest, child: Icon(Icons.movie_outlined, size: 12, color: colors.onSurface.withValues(alpha: 0.2))),
      ),
    );
  }

  void _showCharacterNameDialog(_WorkRoleEntry entry, String? current) {
    final ctrl = TextEditingController(text: current ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('饰演角色', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: TextStyle(fontSize: 15, color: colors.onSurface),
            cursorColor: colors.primary,
            decoration: InputDecoration(
              hintText: '如：关羽',
              hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
              filled: true,
              fillColor: colors.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
            ),
            onSubmitted: (v) { Navigator.pop(ctx); _editCharacterName(entry, v.trim()); },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _editCharacterName(entry, ctrl.text.trim()); },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAvailableList(AppProvider provider, ColorScheme colors) {
    final query = _query.toLowerCase();
    final workType = _currentWorkType;

    List<(String id, String title, String? coverPath)> works;
    switch (workType) {
      case 'movie':
        works = provider.movies
            .where((m) => !m.isDeleted && (query.isEmpty || m.title.toLowerCase().contains(query)))
            .map((m) => (m.id, m.title, m.posterPath))
            .toList();
        break;
      case 'book':
        works = provider.books
            .where((b) => !b.isDeleted && (query.isEmpty || b.title.toLowerCase().contains(query)))
            .map((b) => (b.id, b.title, b.coverPath))
            .toList();
        break;
      case 'game':
        works = provider.games
            .where((g) => !g.isDeleted && (query.isEmpty || g.title.toLowerCase().contains(query)))
            .map((g) => (g.id, g.title, g.coverPath))
            .toList();
        break;
      default:
        works = [];
    }

    if (works.isEmpty) {
      return Center(
        child: Text(
          query.isEmpty ? '暂无可选作品' : '无匹配结果',
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: works.length,
      itemBuilder: (_, i) => _buildAvailableItem(works[i], colors),
    );
  }

  Widget _buildAvailableItem((String id, String title, String? coverPath) work, ColorScheme colors) {
    final id = work.$1;
    final title = work.$2;
    final coverPath = work.$3;
    final workEntries = _entries.where((e) => e.workType == _currentWorkType && e.workId == id).toList();
    final canAddMore = workEntries.length < _currentRoleOptions.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 作品标题行
          Row(
            children: [
              _buildCover(coverPath, 36, colors),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (canAddMore)
                GestureDetector(
                  onTap: () => _addRoleToWork(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: colors.primary),
                        const SizedBox(width: 2),
                        Text('角色', style: TextStyle(fontSize: 11, color: colors.primary)),
                      ],
                    ),
                  ),
                )
              else
                Icon(Icons.check_circle, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
            ],
          ),
          // 已选角色行
          ...workEntries.map((entry) => _buildRoleRow(entry, colors)),
        ],
      ),
    );
  }

  /// 角色行：职业下拉 + 角色名（影视演员）+ 编辑 + 删除
  Widget _buildRoleRow(_WorkRoleEntry entry, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 46),
      child: Row(
        children: [
          // 职业标签/下拉
          _buildRoleDropdown(entry, colors),
          const SizedBox(width: 8),
          // 角色名（仅影视演员）
          if (entry.workType == 'movie' && entry.roleType == 'actor') ...[
            GestureDetector(
              onTap: () => _showCharacterNameDialog(entry, entry.characterName),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.outlineVariant, width: 0.5)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.characterName != null && entry.characterName!.isNotEmpty ? '饰 ${entry.characterName}' : '设置角色',
                      style: TextStyle(fontSize: 12, color: entry.characterName != null ? colors.onSurface : colors.onSurface.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          // 删除
          GestureDetector(
            onTap: () => _removeEntry(entry),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}
