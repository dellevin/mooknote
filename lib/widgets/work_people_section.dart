import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import 'fade_in_local_image.dart';
import 'person_info_sheet.dart';

/// 作品详情页使用的"关联人物"区块
/// 根据 workType + workId 加载关联的 Person 列表并展示
class WorkPeopleSection extends StatefulWidget {
  final String workId;
  final String workType; // 'movie' / 'book' / 'game'

  const WorkPeopleSection({
    super.key,
    required this.workId,
    required this.workType,
  });

  @override
  State<WorkPeopleSection> createState() => _WorkPeopleSectionState();
}

class _WorkPeopleSectionState extends State<WorkPeopleSection> {
  List<_PersonRole> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<AppProvider>();
    // 确保 people 已加载，否则 person 查找全部失败
    if (provider.people.isEmpty) {
      await provider.loadPeople();
    }
    final people = provider.people;

    // 按 personId 聚合：同一个人可能有多条关联（导演/编剧/演员等）
    final Map<String, _PersonRole> byPerson = {};
    void addRelation(dynamic r, {bool withCharacter = false}) {
      final personId = r.personId as String;
      final roleType = r.roleType as String;
      final person = people.where((p) => p.id == personId).firstOrNull;
      if (person == null) return;
      final existing = byPerson[personId];
      if (existing != null) {
        existing.roleTypes.add(roleType);
        if (withCharacter) {
          final c = r.characterName as String?;
          if (c != null && c.isNotEmpty) existing.characterNames.add(c);
        }
      } else {
        final characterNames = <String>[];
        if (withCharacter) {
          final c = r.characterName as String?;
          if (c != null && c.isNotEmpty) characterNames.add(c);
        }
        byPerson[personId] = _PersonRole(
          person: person,
          roleTypes: [roleType],
          characterNames: characterNames,
        );
      }
    }

    switch (widget.workType) {
      case 'movie':
        final rels = await provider.getMoviePeople(widget.workId);
        for (final r in rels) {
          addRelation(r, withCharacter: true);
        }
        break;
      case 'book':
        final rels = await provider.getBookPeople(widget.workId);
        for (final r in rels) {
          addRelation(r);
        }
        break;
      case 'game':
        final rels = await provider.getGamePeople(widget.workId);
        for (final r in rels) {
          addRelation(r);
        }
        break;
    }

    // 按 sortOrder 保留首次出现的顺序
    final items = byPerson.values.toList();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  String _roleLabel(String roleType) {
    return switch (roleType) {
      'director' => '导演',
      'writer' => '编剧',
      'actor' => '演员',
      'author' => '作者',
      'translator' => '译者',
      'developer' => '开发者',
      _ => roleType,
    };
  }

  /// 角色排序权重：演员放最后
  int _roleWeight(String roleType) {
    return switch (roleType) {
      'director' => 0,
      'writer' => 1,
      'author' => 2,
      'translator' => 3,
      'developer' => 4,
      'actor' => 99,
      _ => 50,
    };
  }

  /// 拼接角色描述：
  /// 「导演 / 编剧」
  /// 「导演 / 演员 饰 唐僧 / 演员 饰 孙悟空」
  String _buildRoleText(_PersonRole item) {
    final parts = <String>[];
    // 非演员角色：去重后按权重排序
    final nonActor = item.roleTypes.where((r) => r != 'actor').toSet().toList()
      ..sort((a, b) => _roleWeight(a).compareTo(_roleWeight(b)));
    parts.addAll(nonActor.map(_roleLabel));

    // 演员角色：每个饰演角色名单独成段
    final isActor = item.roleTypes.contains('actor');
    if (isActor) {
      if (item.characterNames.isEmpty) {
        parts.add('演员');
      } else {
        for (final c in item.characterNames) {
          parts.add('演员 饰 $c');
        }
      }
    }
    return parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_items.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '人物',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _items.map((item) {
                final idx = _items.indexOf(item);
                return Padding(
                  padding: EdgeInsets.only(left: idx == 0 ? 0 : 16),
                  child: _buildPersonChip(item, colors),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonChip(_PersonRole item, ColorScheme colors) {
    final person = item.person;
    final hasPhoto = person.photoPath != null && person.photoPath!.isNotEmpty;
    return GestureDetector(
      onTap: () => PersonInfoSheet.show(context, person),
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
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
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              person.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _buildRoleText(item),
              style: TextStyle(
                fontSize: 10,
                color: colors.onSurface.withValues(alpha: 0.4),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRole {
  final Person person;
  final List<String> roleTypes;
  final List<String> characterNames;

  _PersonRole({
    required this.person,
    required this.roleTypes,
    required this.characterNames,
  });
}
