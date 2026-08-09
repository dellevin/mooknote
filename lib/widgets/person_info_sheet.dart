import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../pages/people/person_detail_page.dart';
import '../providers/app_provider.dart';
import 'fade_in_local_image.dart';

/// 人物信息浮动面板（底部 ModalBottomSheet）
/// 展示人物基本信息 + 关联作品，点击「查看全部」跳转到原详情页
class PersonInfoSheet extends StatefulWidget {
  final Person person;

  const PersonInfoSheet({super.key, required this.person});

  static Future<void> show(BuildContext context, Person person) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PersonInfoSheet(person: person),
    );
  }

  @override
  State<PersonInfoSheet> createState() => _PersonInfoSheetState();
}

class _PersonInfoSheetState extends State<PersonInfoSheet> {
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
    final results = await Future.wait([
      provider.getPersonMovies(personId),
      provider.getPersonBooks(personId),
      provider.getPersonGames(personId),
    ]);
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

    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 拖拽条
              Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 顶部：头像 + 名字 + 查看全部
              _buildHeader(person, colors),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 详细信息
                      if (person.gender != null) _buildInfoRow('性别', _genderLabel(person.gender!), colors),
                      if (person.occupation.isNotEmpty) _buildInfoRow('职业', person.occupation.join(' / '), colors),
                      if (person.birthPlace != null) _buildInfoRow('出生地', person.birthPlace!, colors),
                      if (person.birthDate != null) _buildInfoRow('出生日期', _formatDate(person.birthDate!), colors),
                      if (person.alternateNames.isNotEmpty) _buildInfoRow('其他名称', person.alternateNames.join('、'), colors),

                      // 简介
                      if (person.summary != null && person.summary!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildSectionTitle('简介', colors),
                        const SizedBox(height: 8),
                        _buildSummary(person.summary!, colors),
                      ],

                      // 作品
                      if (!_loading) ...[
                        const SizedBox(height: 16),
                        _buildSectionTitle('作品', colors),
                        const SizedBox(height: 8),
                        _buildWorksSection(colors),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Person person, ColorScheme colors) {
    final hasPhoto = person.photoPath != null && person.photoPath!.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
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
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                person.name,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (person.occupation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  person.occupation.join(' / '),
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => PersonDetailPage(person: person),
            ));
          },
          icon: const Icon(Icons.arrow_outward, size: 16),
          label: const Text('详情', style: TextStyle(fontSize: 13)),
          style: TextButton.styleFrom(
            foregroundColor: colors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, ColorScheme colors) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(String summary, ColorScheme colors) {
    const int previewLimit = 80;
    final needsToggle = summary.length > previewLimit;
    final displayText = _summaryExpanded || !needsToggle
        ? summary
        : '${summary.substring(0, previewLimit)}…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText, style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.7)),
        if (needsToggle) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => setState(() => _summaryExpanded = !_summaryExpanded),
            child: Text(
              _summaryExpanded ? '收起' : '展开',
              style: TextStyle(fontSize: 12, color: colors.primary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWorksSection(ColorScheme colors) {
    final provider = context.read<AppProvider>();

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('暂无关联作品', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.3))),
        ),
      );
    }

    String joinRoles(List<String> roles) => roles.join(' / ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (movieGroups.isNotEmpty) ...[
          Text('影视 (${movieGroups.length})', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          ...movieGroups.entries.map((entry) {
            final movie = provider.movies.where((m) => m.id == entry.key).firstOrNull;
            if (movie == null) return const SizedBox.shrink();
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
            );
          }),
          const SizedBox(height: 12),
        ],
        if (bookGroups.isNotEmpty) ...[
          Text('书籍 (${bookGroups.length})', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
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
            );
          }),
          const SizedBox(height: 12),
        ],
        if (gameGroups.isNotEmpty) ...[
          Text('游戏 (${gameGroups.length})', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
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
  }) {
    final hasPoster = posterPath != null && posterPath.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 44,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPoster
                ? FadeInLocalImage(path: posterPath, fit: BoxFit.cover)
                : Center(child: Icon(Icons.movie_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.2))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
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
}
