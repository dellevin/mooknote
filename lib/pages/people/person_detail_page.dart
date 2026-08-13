import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/work_selector_page.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';
import 'person_form_page.dart';
import '../../widgets/app_overlay.dart';

/// 人物档案详情页
class PersonDetailPage extends StatefulWidget {
  final Person person;

  const PersonDetailPage({super.key, required this.person});

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  List<MoviePerson> _moviePeople = [];
  List<BookPerson> _bookPeople = [];
  List<GamePerson> _gamePeople = [];
  bool _loading = true;
  bool _summaryExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  Future<void> _loadRelations() async {
    final provider = context.read<AppProvider>();
    final personId = widget.person.id;
    final movies = provider.getPersonMovies(personId);
    final books = provider.getPersonBooks(personId);
    final games = provider.getPersonGames(personId);
    final results = await Future.wait([movies, books, games]);
    if (!mounted) return;
    setState(() {
      _moviePeople = results[0] as List<MoviePerson>;
      _bookPeople = results[1] as List<BookPerson>;
      _gamePeople = results[2] as List<GamePerson>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final person = context.watch<AppProvider>().people
        .where((p) => p.id == widget.person.id)
        .firstOrNull ?? widget.person;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(person.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_link_outlined),
            tooltip: '关联作品',
            onPressed: () => _editWorks(),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '编辑',
            onPressed: () => _navigateToEdit(person),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: () => _showDeleteDialog(person),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：头像 + 基本信息
            _buildHeader(person, colors),
            const SizedBox(height: 24),

            // 详细信息
            if (person.gender != null) _buildInfoRow('性别', _genderLabel(person.gender!), colors),
            if (person.occupation.isNotEmpty) _buildInfoRow('职业', person.occupation.join(' / '), colors),
            if (person.birthPlace != null) _buildInfoRow('出生地', person.birthPlace!, colors),
            if (person.birthDate != null) _buildInfoRow('出生日期', _formatDate(person.birthDate!), colors),
            if (person.alternateNames.isNotEmpty) _buildInfoRow('其他名称', person.alternateNames.join('、'), colors),

            // 简介
            if (person.summary != null && person.summary!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 0.5, thickness: 0.5, color: colors.outline),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('简介', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ]),
              const SizedBox(height: 12),
              _buildSummary(person.summary!, colors),
            ],

            // 作品列表
            if (!_loading) ...[
              const SizedBox(height: 16),
              Divider(height: 0.5, thickness: 0.5, color: colors.outline),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Text('作品', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ]),
              const SizedBox(height: 12),
              _buildWorksSection(colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Person person, ColorScheme colors) {
    final hasPhoto = person.photoPath != null && person.photoPath!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 头像
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? FadeInLocalImage(path: person.photoPath, fit: BoxFit.cover)
              : Center(
                  child: Text(
                    person.name.isNotEmpty ? person.name[0] : '?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                person.name,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface),
              ),
              if (person.occupation.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: person.occupation.map((occ) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(occ, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(String summary, ColorScheme colors) {
    const int previewLimit = 100;
    final needsToggle = summary.length > previewLimit;
    final displayText = _summaryExpanded || !needsToggle
        ? summary
        : '${summary.substring(0, previewLimit)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText, style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.8)),
        if (needsToggle) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Text(
              _summaryExpanded ? '收起' : '展开',
              style: TextStyle(fontSize: 13, color: colors.primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorksSection(ColorScheme colors) {
    final provider = context.read<AppProvider>();

    // 按作品 ID 分组，合并多角色
    final movieGroups = <String, List<MoviePerson>>{};
    for (final mp in _moviePeople) {
      movieGroups.putIfAbsent(mp.movieId, () => []).add(mp);
    }
    final bookGroups = <String, List<BookPerson>>{};
    for (final bp in _bookPeople) {
      bookGroups.putIfAbsent(bp.bookId, () => []).add(bp);
    }
    final gameGroups = <String, List<GamePerson>>{};
    for (final gp in _gamePeople) {
      gameGroups.putIfAbsent(gp.gameId, () => []).add(gp);
    }

    final totalWorks = movieGroups.length + bookGroups.length + gameGroups.length;

    if (totalWorks == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('暂无关联作品', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))),
        ),
      );
    }

    String joinRoles(List<String> roles) => roles.join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 影视作品
        if (movieGroups.isNotEmpty) ...[
          Text('影视 (${movieGroups.length})', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          ...movieGroups.entries.map((entry) {
            final movie = provider.movies.where((m) => m.id == entry.key).firstOrNull;
            if (movie == null) return const SizedBox.shrink();
            // 按 (roleType, characterName) 去重
            final seen = <String>{};
            final roles = <String>[];
            for (final mp in entry.value) {
              final key = '${mp.roleType}|${mp.characterName ?? ''}';
              if (!seen.add(key)) continue;
              final label = _roleTypeLabel(mp.roleType);
              if (mp.characterName != null && mp.characterName!.isNotEmpty) {
                roles.add('$label 饰 ${mp.characterName}');
              } else {
                roles.add(label);
              }
            }
            return _buildWorkItem(
              title: movie.title,
              subtitle: joinRoles(roles),
              posterPath: movie.posterPath,
              colors: colors,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => MovieDetailPage(movie: movie),
              )),
            );
          }),
          const SizedBox(height: 16),
        ],
        // 书籍作品
        if (bookGroups.isNotEmpty) ...[
          Text('书籍 (${bookGroups.length})', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          ...bookGroups.entries.map((entry) {
            final book = provider.books.where((b) => b.id == entry.key).firstOrNull;
            if (book == null) return const SizedBox.shrink();
            final seen = <String>{};
            final roles = <String>[];
            for (final bp in entry.value) {
              if (!seen.add(bp.roleType)) continue;
              roles.add(_roleTypeLabel(bp.roleType));
            }
            return _buildWorkItem(
              title: book.title,
              subtitle: joinRoles(roles),
              posterPath: book.coverPath,
              colors: colors,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BookDetailPage(book: book),
              )),
            );
          }),
          const SizedBox(height: 16),
        ],
        // 游戏作品
        if (gameGroups.isNotEmpty) ...[
          Text('游戏 (${gameGroups.length})', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          ...gameGroups.entries.map((entry) {
            final game = provider.games.where((g) => g.id == entry.key).firstOrNull;
            if (game == null) return const SizedBox.shrink();
            final seen = <String>{};
            final roles = <String>[];
            for (final gp in entry.value) {
              if (!seen.add(gp.roleType)) continue;
              roles.add(_roleTypeLabel(gp.roleType));
            }
            return _buildWorkItem(
              title: game.title,
              subtitle: joinRoles(roles),
              posterPath: game.coverPath,
              colors: colors,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => GameDetailPage(game: game),
              )),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildWorkItem({
    required String title,
    required String subtitle,
    String? posterPath,
    required ColorScheme colors,
    VoidCallback? onTap,
  }) {
    final hasPoster = posterPath != null && posterPath.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 50,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPoster
                  ? FadeInLocalImage(path: posterPath, fit: BoxFit.cover)
                  : Center(child: Icon(Icons.movie_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.2))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(String gender) {
    return switch (gender) {
      'male' => '男',
      'female' => '女',
      'other' => '其他',
      _ => gender,
    };
  }

  String _roleTypeLabel(String roleType) {
    return switch (roleType) {
      'director' => '导演',
      'writer' => '编剧',
      'actor' => '演员',
      'voiceActor' => '配音',
      'author' => '作者',
      'translator' => '译者',
      'developer' => '开发者',
      _ => roleType,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
  }

  void _navigateToEdit(Person person) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonFormPage(person: person),
      ),
    ).then((_) {
      if (mounted) {
        context.read<AppProvider>().loadPeople();
        _loadRelations();
      }
    });
  }

  Future<void> _editWorks() async {
    final result = await WorkSelectorPage.show(
      context: context,
      personId: widget.person.id,
      initialMovies: _moviePeople,
      initialBooks: _bookPeople,
      initialGames: _gamePeople,
    );
    if (result == null || !mounted) return;

    final provider = context.read<AppProvider>();
    await Future.wait([
      provider.savePersonMovieRelations(widget.person.id, result.movies),
      provider.savePersonBookRelations(widget.person.id, result.books),
      provider.savePersonGameRelations(widget.person.id, result.games),
    ]);
    if (!mounted) return;
    await _loadRelations();
    if (mounted) ToastUtil.show(context, '作品关联已更新');
  }

  void _showDeleteDialog(Person person) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除"${person.name}"吗？删除后可在回收站恢复。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = this.context.read<AppProvider>();
              await provider.removePerson(person.id);
              if (!mounted || !context.mounted) return;
              Navigator.pop(context); // close dialog
              Navigator.pop(this.context); // close detail page
              ToastUtil.show(this.context, '已删除');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
