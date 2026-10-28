import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../services/bangumi_service.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';

/// Bangumi 人物收藏/关联相关 UI：
/// - 角色卡片（详情页横滑列表与全量网格页共用）
/// - 角色弹层（角色信息 + 声优 + 收藏/关联两段式按钮）
/// - 真人弹层（人物详情 + 收藏/关联两段式按钮）
///
/// 两段式按钮：加入人物收藏 → 已收藏，点击关联 → 已收藏并关联 ✓

// ── 数据映射 ──────────────────────────────────────────────

/// Bangumi 职业枚举 → 中文职业
const Map<String, String> _careerLabels = {
  'producer': '制作人',
  'mangaka': '漫画家',
  'artist': '艺术家',
  'seiyu': '声优',
  'writer': '作者',
  'illustrator': '插画师',
  'actor': '演员',
};

/// 制作职务（relation）→ 本地关联 roleType
/// 无法映射时返回中文原文（WorkPeopleSection 对未知 roleType 原样展示）
String bangumiRoleType(String relation, String target) {
  final r = relation.trim();
  if (r.isEmpty) return 'other';
  switch (target) {
    case 'book':
      if (r.contains('翻译') || r.contains('翻譯') || r.contains('翻訳')) {
        return 'translator';
      }
      if (r.contains('作者') ||
          r.contains('原作') ||
          r.contains('原画') ||
          r.contains('原畫') ||
          r.contains('作画') ||
          r.contains('作畫') ||
          r.contains('插画') ||
          r.contains('插畫')) {
        return 'author';
      }
      return r;
    case 'game':
      if (r.contains('开发') || r.contains('開發') || r.contains('開発')) {
        return 'developer';
      }
      return r;
    default:
      // 仅精确匹配导演类职务；'作画监督'/'音响监督'等不应映射为 director
      if (r == '导演' || r == '監督' || r == '总导演' || r == '總導演') {
        return 'director';
      }
      if (r.contains('脚本') ||
          r.contains('编剧') ||
          r.contains('編劇') ||
          r.contains('系列构成') ||
          r.contains('系列構成') ||
          r.contains('原作') ||
          r.contains('作者')) {
        return 'writer';
      }
      return r;
  }
}

/// roleType → 中文职业标签（写入 Person.occupation 时使用）
String? _roleTypeOccupation(String roleType) {
  return switch (roleType) {
    'director' => '导演',
    'writer' => '编剧',
    'author' => '作者',
    'translator' => '译者',
    'developer' => '开发者',
    'voiceActor' => '声优',
    _ => null,
  };
}

String? _mapGender(dynamic gender) {
  final s = (gender ?? '').toString();
  if (s.contains('女')) return 'female';
  if (s.contains('男')) return 'male';
  return null;
}

/// 从详情 infobox 提取「简体中文名」（无则返回 null）
String? bangumiNameCn(Map<String, dynamic> detail) {
  for (final item in (detail['infobox'] as List? ?? [])) {
    if (item is Map && item['key'] == '简体中文名') {
      final v = item['value'];
      final s = (v is List ? v.join('；') : v?.toString()) ?? '';
      final t = s.trim();
      if (t.isNotEmpty) return t;
    }
  }
  return null;
}

DateTime? _birthDate(Map<String, dynamic> d) {
  final y = d['birth_year'] as int?;
  final m = d['birth_mon'] as int?;
  final day = d['birth_day'] as int?;
  if (y == null || m == null || day == null) return null;
  return DateTime(y, m, day);
}

List<String> _occupations(Map<String, dynamic> detail, String? roleType) {
  final set = <String>{
    for (final c in (detail['career'] as List? ?? []))
      if (_careerLabels[c.toString()] != null) _careerLabels[c.toString()]!,
  };
  if (roleType != null) {
    final fromRole = _roleTypeOccupation(roleType);
    if (fromRole != null) set.add(fromRole);
  }
  return set.toList();
}

/// 角色排序：主角 → 配角 → 其他（旁白/客串等沉底），组内保持 API 原序
List<Map<String, dynamic>> sortBangumiCharacters(List<dynamic> chars) {
  int weight(String rel) {
    if (rel == '主角' || rel == '主人公') return 0;
    if (rel == '配角') return 1;
    return 2;
  }

  final indexed = <(Map<String, dynamic>, int)>[
    for (var i = 0; i < chars.length; i++) (chars[i] as Map<String, dynamic>, i),
  ];
  indexed.sort((a, b) {
    final w = weight((a.$1['relation'] ?? '').toString())
        .compareTo(weight((b.$1['relation'] ?? '').toString()));
    return w != 0 ? w : a.$2 - b.$2;
  });
  return [for (final e in indexed) e.$1];
}

/// 职务 → 重要性权重（越小越靠前；采用精确匹配，避免'作画监督'被'监督'误判为导演，
/// 未收录的职务一律沉底进「更多」）
const Map<String, int> _staffWeights = {
  '原作': 1, '原作者': 1, '原案': 1,
  '导演': 2, '監督': 2, '总导演': 2, '總導演': 2, '総監督': 2,
  '系列构成': 3, '系列構成': 3, '脚本': 3, '编剧': 3, '編劇': 3, '剧本': 3, '劇本': 3,
  '人物设定': 4, '人物設定': 4, '角色设计': 4, '角色設計': 4, '角色原案': 4,
  '作画监督': 5, '作畫監督': 5, '总作画监督': 5, '總作畫監督': 5,
  '音乐': 6, '音樂': 6, '音响监督': 6, '音響監督': 6,
  '美术监督': 7, '美術監督': 7, '美术设计': 7, '美術設計': 7,
  '色彩设计': 8, '色彩設計': 8, '色彩指定': 8,
  '摄影监督': 9, '摄影': 9, '攝影': 9,
  '动画制作': 10, '動畫制作': 10,
};

/// 制作人员排序：按最高职务权重升序，同权重保持 API 原序
/// （relation_merged 为按署名条目合并后的完整职务，回退原始 relation）
List<Map<String, dynamic>> sortBangumiStaff(List<Map<String, dynamic>> staff) {
  int weight(String relation) {
    int? w;
    for (final r in relation.split(' / ')) {
      final v = _staffWeights[r.trim()];
      if (v != null && (w == null || v < w)) w = v;
    }
    return w ?? 99;
  }

  String relOf(Map<String, dynamic> s) =>
      ((s['relation_merged'] ?? s['relation'] ?? '') as String).toString();

  final indexed = <(Map<String, dynamic>, int)>[
    for (var i = 0; i < staff.length; i++) (staff[i], i),
  ];
  indexed.sort((a, b) {
    final w = weight(relOf(a.$1)).compareTo(weight(relOf(b.$1)));
    return w != 0 ? w : a.$2 - b.$2;
  });
  return [for (final e in indexed) e.$1];
}

// ── 图片下载 ──────────────────────────────────────────────

/// 从 Bangumi 图片 URL 选择最合适的尺寸（medium 400px 优先）
String? bangumiImageUrl(Map<String, dynamic>? images) {
  if (images == null) return null;
  for (final k in ['medium', 'large', 'small', 'grid']) {
    final url = (images[k] ?? '').toString();
    if (url.isNotEmpty) return url;
  }
  return null;
}

Future<String?> downloadBangumiImage(String? url, String targetPath) async {
  if (url == null || url.isEmpty) return null;
  try {
    final resp = await http.get(Uri.parse(url), headers: {
      'User-Agent': await BangumiService.instance.userAgent(),
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200 && resp.bodyBytes.length < 10 * 1024 * 1024) {
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(resp.bodyBytes);
      return targetPath;
    }
  } catch (_) {}
  return null;
}

// ── 人物写入 / 关联写入 ──────────────────────────────────────────────

/// 按 name 查找本地人物；有则合并更新，无则新增。
/// 返回对应的本地人物，失败返回 null。
Future<Person?> upsertBangumiPerson(
  BuildContext context,
  Map<String, dynamic> detail, {
  String? roleType,
  bool silent = false, // 批量场景关闭逐人 toast
}) async {
  final name = (detail['name'] ?? '').toString().trim();
  if (name.isEmpty) return null;
  // 中文用户优先用简体中文名收藏，日文原名存入别名
  final cn = bangumiNameCn(detail);
  final displayName = (cn != null && cn.isNotEmpty ? cn : name).trim();
  final provider = context.read<AppProvider>();
  final matches =
      provider.people.where((e) => !e.isDeleted && e.name == displayName).toList();

  Person? target;
  if (matches.length > 1) {
    target = await _pickPerson(context, matches);
    if (target == null || !context.mounted) return null;
  } else if (matches.length == 1) {
    target = matches.first;
  }

  final occ = _occupations(detail, roleType);
  final summary = (detail['summary'] ?? '').toString().trim();
  final birth = _birthDate(detail);
  final gender = _mapGender(detail['gender']);

  if (target == null) {
    final id = const Uuid().v4();
    final photoUrl = bangumiImageUrl(detail['images'] as Map<String, dynamic>?);
    final photo = await downloadBangumiImage(
        photoUrl,
        await ImagePathHelper.instance
            .getPersonPhotoPath(id, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    if (!context.mounted) return null;
    // 记录头像来源，再次收藏时不再提示头像覆盖
    if (photo != null && photoUrl != null) {
      UserPrefs().setBangumiPersonPhoto(id, photoUrl, photo);
    }
    final person = Person(
      id: id,
      name: displayName,
      gender: gender,
      birthDate: birth,
      alternateNames:
          displayName != name && name.isNotEmpty ? [name] : const [],
      occupation: occ,
      summary: summary.isNotEmpty ? summary : null,
      photoPath: photo,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await provider.addPerson(person);
    if (context.mounted && !silent) {
      ToastUtil.show(context, '已添加「{name}」'.trf({'name': displayName}));
    }
    return person;
  }

  // 已有人物：空字段静默补全；冲突字段（本地已有值且与 Bangumi 不同）由用户勾选覆盖
  final photoUrl = bangumiImageUrl(detail['images'] as Map<String, dynamic>?);
  String fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String? genderLabel(String? g) => switch (g) {
        'male' => '男'.tr,
        'female' => '女'.tr,
        'other' => '其他'.tr,
        _ => g,
      };

  // 本地头像是否仍为 Bangumi 下载的那张（URL 与本地路径需同时匹配；
  // 被 TMDB 同步或手动更换后路径必变，会重新提示覆盖）
  final photoSrc = UserPrefs().bangumiPersonPhotos[target.id];
  final photoFromBangumi = photoUrl != null &&
      photoSrc != null &&
      photoSrc['url'] == photoUrl &&
      photoSrc['path'] == target.photoPath;

  final conflicts = <({String key, String label, String detail})>[
    if (photoUrl != null &&
        (target.photoPath?.isNotEmpty ?? false) &&
        !photoFromBangumi)
      (
        key: 'photo',
        label: '头像'.tr,
        detail: '替换为 Bangumi 头像'.tr,
      ),
    if (summary.isNotEmpty &&
        (target.summary?.isNotEmpty ?? false) &&
        target.summary != summary)
      (
        key: 'summary',
        label: '简介'.tr,
        detail: '本地 {a} 字 → Bangumi {b} 字'
            .trf({'a': '${target.summary!.length}', 'b': '${summary.length}'}),
      ),
    if (gender != null &&
        (target.gender?.isNotEmpty ?? false) &&
        target.gender != gender)
      (
        key: 'gender',
        label: '性别'.tr,
        detail: '${genderLabel(target.gender)} → ${genderLabel(gender)}',
      ),
    if (birth != null &&
        target.birthDate != null &&
        (target.birthDate!.year != birth.year ||
            target.birthDate!.month != birth.month ||
            target.birthDate!.day != birth.day))
      (
        key: 'birth',
        label: '生日'.tr,
        detail: '${fmtDate(target.birthDate!)} → ${fmtDate(birth)}',
      ),
  ];

  // 有冲突且非批量场景 → 弹框让用户选择覆盖哪些字段；取消则一字不动
  Set<String>? overwrite;
  if (conflicts.isNotEmpty && !silent) {
    overwrite = await _pickOverwriteFields(context, target, conflicts);
    if (overwrite == null) return target;
    if (!context.mounted) return null;
  }

  // 头像：本地为空 → 下载补全；被勾选 → 下载覆盖
  String? photoPath = target.photoPath;
  final fillPhoto = photoPath == null || photoPath.isEmpty;
  if ((fillPhoto || (overwrite?.contains('photo') ?? false)) &&
      photoUrl != null) {
    final downloaded = await downloadBangumiImage(
        photoUrl,
        await ImagePathHelper.instance.getPersonPhotoPath(
            target.id, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    if (!context.mounted) return null;
    if (downloaded != null) {
      photoPath = downloaded;
      // 覆盖成功，同步记录头像来源
      UserPrefs().setBangumiPersonPhoto(target.id, photoUrl, downloaded);
    }
  }

  // 职业/别名始终合并；用中文名收藏时原名补入别名
  final updated = target.copyWith(
    gender: (target.gender == null || target.gender!.isEmpty) ||
            (overwrite?.contains('gender') ?? false)
        ? gender
        : target.gender,
    birthDate: target.birthDate == null ||
            (overwrite?.contains('birth') ?? false)
        ? birth
        : target.birthDate,
    occupation: {...target.occupation, ...occ}.toList(),
    alternateNames: {
      ...target.alternateNames,
      if (displayName != name && name.isNotEmpty) name,
    }.toList(),
    summary: (target.summary == null || target.summary!.isEmpty)
        ? (summary.isNotEmpty ? summary : target.summary)
        : (overwrite?.contains('summary') ?? false) && summary.isNotEmpty
            ? summary
            : target.summary,
    photoPath: photoPath,
    updatedAt: DateTime.now(),
  );
  await provider.updatePerson(updated);
  if (context.mounted && !silent) {
    ToastUtil.show(context, '已更新「{name}」'.trf({'name': displayName}));
  }
  return updated;
}

/// 多个同名人物时让用户选择
Future<Person?> _pickPerson(BuildContext context, List<Person> matches) {
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
                if (person.birthDate != null) '${person.birthDate!.year}',
              ].join(' · ');
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title:
                    Text(person.name, style: TextStyle(fontSize: 14, color: c.onSurface)),
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

/// 冲突字段覆盖选择框：勾选要用 Bangumi 覆盖的字段；取消返回 null（一字不动）
Future<Set<String>?> _pickOverwriteFields(
  BuildContext context,
  Person target,
  List<({String key, String label, String detail})> conflicts,
) {
  return appDialog<Set<String>>(
    context: context,
    builder: (ctx) {
      final c = Theme.of(ctx).colorScheme;
      final selected = <String>{};
      return StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: c.surface,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('更新「{name}」'.trf({'name': target.name}),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text('本地已有信息，勾选要用 Bangumi 覆盖的字段'.tr,
                      style: TextStyle(
                          fontSize: 12,
                          color: c.onSurface.withValues(alpha: 0.5))),
                ),
                for (final f in conflicts)
                  CheckboxListTile(
                    value: selected.contains(f.key),
                    onChanged: (v) => setSt(() =>
                        v! ? selected.add(f.key) : selected.remove(f.key)),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.label,
                        style:
                            TextStyle(fontSize: 14, color: c.onSurface)),
                    subtitle: Text(f.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: c.onSurface.withValues(alpha: 0.45))),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'.tr),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text('更新'.tr),
            ),
          ],
        ),
      );
    },
  );
}

/// 建立人物与本地作品的关联（读取现有关联合并去重后整体保存）
Future<bool> linkBangumiPerson(
  BuildContext context, {
  required String localId,
  required String target,
  required Person person,
  required String roleType,
  String? characterName,
}) async {
  final provider = context.read<AppProvider>();
  const uuid = Uuid();

  switch (target) {
    case 'book':
      final rels = await provider.getBookPeople(localId);
      final exists = rels.any(
          (r) => r.personId == person.id && r.roleType == roleType);
      if (exists) return true;
      rels.add(BookPerson(
          id: uuid.v4(),
          bookId: localId,
          personId: person.id,
          roleType: roleType,
          sortOrder: rels.length));
      await provider.saveBookPeople(localId, rels);
      break;
    case 'game':
      final rels = await provider.getGamePeople(localId);
      final exists = rels.any(
          (r) => r.personId == person.id && r.roleType == roleType);
      if (exists) return true;
      rels.add(GamePerson(
          id: uuid.v4(),
          gameId: localId,
          personId: person.id,
          roleType: roleType,
          sortOrder: rels.length));
      await provider.saveGamePeople(localId, rels);
      break;
    default:
      final rels = await provider.getMoviePeople(localId);
      final exists = rels.any((r) =>
          r.personId == person.id &&
          r.roleType == roleType &&
          (r.characterName ?? '') == (characterName ?? ''));
      if (exists) return true;
      rels.add(MoviePerson(
          id: uuid.v4(),
          movieId: localId,
          personId: person.id,
          roleType: roleType,
          characterName: characterName,
          sortOrder: rels.length));
      await provider.saveMoviePeople(localId, rels);
  }
  return true;
}

// ── 角色卡片 ──────────────────────────────────────────────

/// 角色卡片（详情页横滑列表 / 全量网格页共用）
class BangumiCharacterCard extends StatelessWidget {
  final Map<String, dynamic> character;
  final ColorScheme colors;
  final VoidCallback onTap;

  const BangumiCharacterCard({
    super.key,
    required this.character,
    required this.colors,
    required this.onTap,
  });

  String get _name {
    final cn = (character['name_cn'] ?? '').toString().trim();
    if (cn.isNotEmpty) return cn;
    return (character['name'] ?? '').toString();
  }
  String get _relation => (character['relation'] ?? '').toString();
  bool get _isMain => _relation == '主角' || _relation == '主人公';

  String? get _imageUrl =>
      bangumiImageUrl(character['images'] as Map<String, dynamic>?);

  String get _cvName {
    final actors = character['actors'] as List? ?? [];
    if (actors.isEmpty) return '';
    final a = actors.first as Map;
    final cn = (a['name_cn'] ?? '').toString().trim();
    if (cn.isNotEmpty) return cn;
    return ((a)['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 92,
                height: 122,
                child: _imageUrl != null
                    ? Image.network(_imageUrl!,
                        fit: BoxFit.cover,
                        // 角色立绘头部在上方，优先展示图片顶部
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) =>
                            _placeholder(colors, name))
                    : _placeholder(colors, name),
              ),
            ),
            const SizedBox(height: 6),
            Text(name,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: _isMain
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_relation,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isMain
                          ? colors.onPrimary
                          : colors.onSurface.withValues(alpha: 0.55))),
            ),
            if (_cvName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'CV ',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.primary)),
                    TextSpan(
                        text: _cvName,
                        style: TextStyle(
                            fontSize: 11,
                            color: colors.onSurface.withValues(alpha: 0.45))),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _placeholder(ColorScheme colors, String name) {
    final ch = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(ch,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.onSurface.withValues(alpha: 0.25))),
    );
  }
}

// ── 长文本折叠 ──────────────────────────────────────────────

/// 超过 maxLines 显示"展开/收起"按钮的长文本组件
class BangumiExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle style;

  const BangumiExpandableText({
    super.key,
    required this.text,
    required this.maxLines,
    required this.style,
  });

  @override
  State<BangumiExpandableText> createState() => _BangumiExpandableTextState();
}

class _BangumiExpandableTextState extends State<BangumiExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: widget.style),
        maxLines: widget.maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);
      final overflow = tp.didExceedMaxLines;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.text,
              style: widget.style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? null : TextOverflow.ellipsis),
          if (overflow)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? '收起'.tr : '展开'.tr,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.primary)),
              ),
            ),
        ],
      );
    });
  }
}

// ── 弹层入口 ──────────────────────────────────────────────

/// 打开角色弹层
Future<void> showBangumiCharacterSheet(
  BuildContext context, {
  required Map<String, dynamic> character,
  required int sortOrder,
  required String target,
  required Future<String?> Function() ensureSubject,
}) {
  final colors = Theme.of(context).colorScheme;
  return appModalBottomSheet(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: _BangumiCharacterSheet(
          character: character,
          sortOrder: sortOrder,
          target: target,
          ensureSubject: ensureSubject,
        ),
      ),
    ),
  );
}

/// 打开真人弹层（制作人员 / 声优）
/// [characterName] 不为空时表示从角色进入（关联时建立 voiceActor 关系）
Future<void> showBangumiPersonSheet(
  BuildContext context, {
  required Map<String, dynamic> personRef,
  required String target,
  required Future<String?> Function() ensureSubject,
  String? characterName,
}) {
  final colors = Theme.of(context).colorScheme;
  return appModalBottomSheet(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.62,
        child: _BangumiPersonSheet(
          personRef: personRef,
          target: target,
          ensureSubject: ensureSubject,
          characterName: characterName,
        ),
      ),
    ),
  );
}

/// 保存 Bangumi 角色到本地作品角色库（手动弹层与批量添加共用）。
/// 返回 'saved' / 'exists' / 'none'（context 失效）
Future<String> saveBangumiCharacterToWork(
  BuildContext context, {
  required Map<String, dynamic> character,
  required int sortOrder,
  required String target,
  required String localId,
}) async {
  final provider = context.read<AppProvider>();
  const uuid = Uuid();
  final cn = (character['name_cn'] ?? '').toString().trim();
  final rawName = (character['name'] ?? '').toString();
  final name = cn.isNotEmpty ? cn : rawName;
  // 有中文译名时，日文原名存入别名；无译名则名称即原名，别名留空
  final aliases = cn.isNotEmpty && rawName.isNotEmpty && rawName != cn
      ? [rawName]
      : const <String>[];
  final relation = (character['relation'] ?? '').toString();
  final summary = (character['summary'] ?? '').toString().trim();
  final bgmCharId = (character['id'] ?? '').toString();

  // 匹配已有角色：显示名 / 原文名 / 别名任一命中即视为同一角色。
  // 覆盖「此前网络失败回退按原名保存、现在补中文名」等场景：命中则更新补全而非新建
  bool isMatch(String eName, List<String> eAliases) =>
      eName == name ||
      eName == rawName ||
      eAliases.contains(rawName) ||
      eAliases.contains(name);

  switch (target) {
    case 'book':
      {
        final matched = (await provider.getBookCharacters(localId))
            .where((e) => !e.isDeleted && isMatch(e.name, e.aliases))
            .toList();
        if (matched.isNotEmpty) {
          final m = matched.first;
          if (cn.isEmpty) return 'exists';
          final merged = <String>{
            ...m.aliases,
            if (rawName.isNotEmpty && rawName != cn) rawName,
          }.toList();
          final fillRole =
              (m.role == null || m.role!.isEmpty) && relation.isNotEmpty;
          final fillDesc = (m.description == null || m.description!.isEmpty) &&
              summary.isNotEmpty;
          final needImage = m.imagePath == null || m.imagePath!.isEmpty;
          // 已有中文名且无任何可补全信息 → 视为已存在
          if (m.name == cn &&
              merged.length == m.aliases.length &&
              !fillRole &&
              !fillDesc &&
              !needImage) {
            return 'exists';
          }
          String? imagePath = m.imagePath;
          if (needImage) {
            imagePath = await downloadBangumiImage(
                bangumiImageUrl(character['images'] as Map<String, dynamic>?),
                await ImagePathHelper.instance.getCharacterImagePath(
                    bgmCharId.isEmpty ? uuid.v4() : bgmCharId,
                    'crt_${DateTime.now().millisecondsSinceEpoch}.jpg'));
            if (!context.mounted) return 'none';
          }
          await provider.updateBookCharacter(m.copyWith(
            name: cn,
            aliases: merged,
            role: fillRole ? relation : m.role,
            description: fillDesc ? summary : m.description,
            imagePath: imagePath,
            updatedAt: DateTime.now(),
          ));
          return 'saved';
        }
        break;
      }
    case 'game':
      {
        final matched = (await provider.getGameCharacters(localId))
            .where((e) => !e.isDeleted && isMatch(e.name, e.aliases))
            .toList();
        if (matched.isNotEmpty) {
          final m = matched.first;
          if (cn.isEmpty) return 'exists';
          final merged = <String>{
            ...m.aliases,
            if (rawName.isNotEmpty && rawName != cn) rawName,
          }.toList();
          final fillRole =
              (m.role == null || m.role!.isEmpty) && relation.isNotEmpty;
          final fillDesc = (m.description == null || m.description!.isEmpty) &&
              summary.isNotEmpty;
          final needImage = m.imagePath == null || m.imagePath!.isEmpty;
          if (m.name == cn &&
              merged.length == m.aliases.length &&
              !fillRole &&
              !fillDesc &&
              !needImage) {
            return 'exists';
          }
          String? imagePath = m.imagePath;
          if (needImage) {
            imagePath = await downloadBangumiImage(
                bangumiImageUrl(character['images'] as Map<String, dynamic>?),
                await ImagePathHelper.instance.getCharacterImagePath(
                    bgmCharId.isEmpty ? uuid.v4() : bgmCharId,
                    'crt_${DateTime.now().millisecondsSinceEpoch}.jpg'));
            if (!context.mounted) return 'none';
          }
          await provider.updateGameCharacter(m.copyWith(
            name: cn,
            aliases: merged,
            role: fillRole ? relation : m.role,
            description: fillDesc ? summary : m.description,
            imagePath: imagePath,
            updatedAt: DateTime.now(),
          ));
          return 'saved';
        }
        break;
      }
    default:
      {
        final matched = (await provider.getMovieCharacters(localId))
            .where((e) => !e.isDeleted && isMatch(e.name, e.aliases))
            .toList();
        if (matched.isNotEmpty) {
          final m = matched.first;
          if (cn.isEmpty) return 'exists';
          final merged = <String>{
            ...m.aliases,
            if (rawName.isNotEmpty && rawName != cn) rawName,
          }.toList();
          final fillRole =
              (m.role == null || m.role!.isEmpty) && relation.isNotEmpty;
          final fillDesc = (m.description == null || m.description!.isEmpty) &&
              summary.isNotEmpty;
          final needImage = m.imagePath == null || m.imagePath!.isEmpty;
          if (m.name == cn &&
              merged.length == m.aliases.length &&
              !fillRole &&
              !fillDesc &&
              !needImage) {
            return 'exists';
          }
          String? imagePath = m.imagePath;
          if (needImage) {
            imagePath = await downloadBangumiImage(
                bangumiImageUrl(character['images'] as Map<String, dynamic>?),
                await ImagePathHelper.instance.getCharacterImagePath(
                    bgmCharId.isEmpty ? uuid.v4() : bgmCharId,
                    'crt_${DateTime.now().millisecondsSinceEpoch}.jpg'));
            if (!context.mounted) return 'none';
          }
          await provider.updateMovieCharacter(m.copyWith(
            name: cn,
            aliases: merged,
            role: fillRole ? relation : m.role,
            description: fillDesc ? summary : m.description,
            imagePath: imagePath,
            updatedAt: DateTime.now(),
          ));
          return 'saved';
        }
        break;
      }
  }

  final imagePath = await downloadBangumiImage(
      bangumiImageUrl(character['images'] as Map<String, dynamic>?),
      await ImagePathHelper.instance.getCharacterImagePath(
          bgmCharId.isEmpty ? uuid.v4() : bgmCharId,
          'crt_${DateTime.now().millisecondsSinceEpoch}.jpg'));
  if (!context.mounted) return 'none';
  final now = DateTime.now();
  switch (target) {
    case 'book':
      await provider.addBookCharacter(BookCharacter(
          id: uuid.v4(),
          bookId: localId,
          name: name,
          role: relation,
          aliases: aliases,
          description: summary.isNotEmpty ? summary : null,
          imagePath: imagePath,
          sortOrder: sortOrder,
          createdAt: now,
          updatedAt: now));
      break;
    case 'game':
      await provider.addGameCharacter(GameCharacter(
          id: uuid.v4(),
          gameId: localId,
          name: name,
          role: relation,
          aliases: aliases,
          description: summary.isNotEmpty ? summary : null,
          imagePath: imagePath,
          sortOrder: sortOrder,
          createdAt: now,
          updatedAt: now));
      break;
    default:
      await provider.addMovieCharacter(MovieCharacter(
          id: uuid.v4(),
          movieId: localId,
          name: name,
          role: relation,
          aliases: aliases,
          description: summary.isNotEmpty ? summary : null,
          imagePath: imagePath,
          sortOrder: sortOrder,
          createdAt: now,
          updatedAt: now));
  }
  return 'saved';
}

// ── 两段式按钮 ──────────────────────────────────────────────

/// 收藏/关联两段式主按钮：
/// 0=加入人物收藏 1=已收藏，点击关联 2=已收藏并关联
class _StageButton extends StatelessWidget {
  final int stage;
  final bool busy;
  final String Function(int) label;
  final VoidCallback onTap;

  const _StageButton({
    required this.stage,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = stage >= 2;
    return InkWell(
      onTap: done || busy ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: done
              ? colors.surfaceContainerHighest
              : colors.primary.withValues(alpha: busy ? 0.6 : 1),
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: colors.onPrimary))
            : Text(label(stage),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: done
                        ? colors.onSurface.withValues(alpha: 0.5)
                        : colors.onPrimary)),
      ),
    );
  }
}

// ── 角色弹层 ──────────────────────────────────────────────

class _BangumiCharacterSheet extends StatefulWidget {
  final Map<String, dynamic> character;
  final int sortOrder;
  final String target;
  final Future<String?> Function() ensureSubject;

  const _BangumiCharacterSheet({
    required this.character,
    required this.sortOrder,
    required this.target,
    required this.ensureSubject,
  });

  @override
  State<_BangumiCharacterSheet> createState() => _BangumiCharacterSheetState();
}

class _BangumiCharacterSheetState extends State<_BangumiCharacterSheet> {
  final _bgm = BangumiService.instance;

  int _stage = 0; // 主按钮（声优收藏/关联）状态
  bool _busy = false;
  bool _charSaving = false; // 「保存角色到作品」独立 loading，与主按钮互不影响
  bool _charSaved = false;

  List get _actors => widget.character['actors'] as List? ?? [];
  Map<String, dynamic> get _firstActor =>
      _actors.isNotEmpty ? _actors.first as Map<String, dynamic> : {};
  String get _cvName => _cvDisplay(_firstActor);

  String get _name {
    final cn = (widget.character['name_cn'] ?? '').toString().trim();
    if (cn.isNotEmpty) return cn;
    return (widget.character['name'] ?? '').toString();
  }
  String get _relation => (widget.character['relation'] ?? '').toString();
  String get _summary => (widget.character['summary'] ?? '').toString().trim();

  @override
  void initState() {
    super.initState();
    // 本地已有同名声优时，从"已收藏"状态起步
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      final exists =
          provider.people.any((e) => !e.isDeleted && e.name == _cvName);
      if (exists) setState(() => _stage = 1);
      _loadNames();
    });
  }

  /// 按需拉取角色与声优详情，把 infobox 简体中文名合并进条目数据（name_cn）。
  /// 弹层关闭后由调用方刷新卡片；不做批量预拉取，避免高频请求。
  Future<void> _loadNames() async {
    final cid = (widget.character['id'] as num?)?.toInt();
    if (cid != null) {
      try {
        final d = await _bgm.characterDetail(cid);
        final cn = bangumiNameCn(d);
        if (mounted && cn != null && cn.isNotEmpty) {
          setState(() => widget.character['name_cn'] = cn);
        }
      } catch (_) {}
    }
    for (final a in _actors) {
      if (((a as Map)['name_cn'] ?? '').toString().trim().isNotEmpty) continue;
      final aid = (a['id'] as num?)?.toInt();
      if (aid == null) continue;
      try {
        final d = await _bgm.personDetail(aid);
        final cn = bangumiNameCn(d);
        if (mounted && cn != null && cn.isNotEmpty) {
          setState(() => a['name_cn'] = cn);
        }
      } catch (_) {}
    }
  }

  Future<void> _favoriteCv() async {
    if (_firstActor.isEmpty) return;
    setState(() => _busy = true);
    try {
      final detail =
          await BangumiService.instance.personDetail(_firstActor['id'] as int);
      if (!mounted) return;
      final person = await upsertBangumiPerson(context, detail,
          roleType: 'voiceActor');
      if (mounted && person != null) setState(() => _stage = 1);
    } on BangumiAuthException {
      if (mounted) ToastUtil.show(context, 'Token 已失效，请前往设置重新验证'.tr);
    } on BangumiNetworkException {
      if (mounted) ToastUtil.show(context, '网络错误'.tr);
    } catch (_) {
      if (mounted) ToastUtil.show(context, '网络错误'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _linkCv() async {
    setState(() => _busy = true);
    try {
      final localId = await widget.ensureSubject();
      if (localId == null || !mounted) return;
      final detail =
          await BangumiService.instance.personDetail(_firstActor['id'] as int);
      if (!mounted) return;
      final person =
          await upsertBangumiPerson(context, detail, roleType: 'voiceActor');
      if (person == null || !mounted) return;
      await linkBangumiPerson(context,
          localId: localId,
          target: widget.target,
          person: person,
          roleType: 'voiceActor',
          characterName: _name);
      if (mounted) {
        setState(() => _stage = 2);
        ToastUtil.show(context, '已关联「{name}」'.trf({'name': _cvName}));
      }
    } on BangumiAuthException {
      if (mounted) ToastUtil.show(context, 'Token 已失效，请前往设置重新验证'.tr);
    } catch (_) {
      if (mounted) ToastUtil.show(context, '网络错误'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCharacter() async {
    setState(() => _charSaving = true);
    try {
      final localId = await widget.ensureSubject();
      if (localId == null || !mounted) return;
      final result = await saveBangumiCharacterToWork(context,
          character: widget.character,
          sortOrder: widget.sortOrder,
          target: widget.target,
          localId: localId);
      if (!mounted) return;
      if (result == 'saved') {
        setState(() => _charSaved = true);
        ToastUtil.show(context, '角色已保存'.tr);
      } else if (result == 'exists') {
        setState(() => _charSaved = true);
        ToastUtil.show(context, '角色已存在'.tr);
      }
    } on BangumiAuthException {
      if (mounted) ToastUtil.show(context, 'Token 已失效，请前往设置重新验证'.tr);
    } catch (_) {
      if (mounted) ToastUtil.show(context, '网络错误'.tr);
    } finally {
      if (mounted) setState(() => _charSaving = false);
    }
  }

  /// 声优显示名：简体中文名优先
  String _cvDisplay(Map a) {
    final cn = (a['name_cn'] ?? '').toString().trim();
    if (cn.isNotEmpty) return cn;
    return (a['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final imageUrl =
        bangumiImageUrl(widget.character['images'] as Map<String, dynamic>?);
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
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 84,
                      height: 112,
                      child: imageUrl != null
                          ? Image.network(imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (_, __, ___) => _placeholder(colors))
                          : _placeholder(colors),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name,
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            _chip(colors, _relation,
                                filled: _relation == '主角'),
                            _chip(colors, '角色'.tr),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: BangumiExpandableText(
                      text: _summary,
                      maxLines: 6,
                      style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.7),
                          height: 1.55)),
                ),
              if (_actors.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('配音'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface)),
                const SizedBox(height: 6),
                for (final a in _actors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () async {
                        await showBangumiPersonSheet(
                          context,
                          personRef: a as Map<String, dynamic>,
                          target: widget.target,
                          ensureSubject: widget.ensureSubject,
                          characterName: _name,
                        );
                        // 真人弹层拉到的简体中文名已合并进声优数据，刷新列表
                        if (mounted) setState(() {});
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: colors.primary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: Text('CV',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: colors.primary)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_cvDisplay(a),
                                  style: TextStyle(
                                      fontSize: 13, color: colors.onSurface)),
                            ),
                            Icon(Icons.chevron_right,
                                size: 18,
                                color: colors.onSurface.withValues(alpha: 0.3)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              if (_actors.isNotEmpty)
                _StageButton(
                  stage: _stage,
                  busy: _busy,
                  label: (s) => switch (s) {
                    0 => '收藏 CV {name}'.trf({'name': _cvName}),
                    1 => '已收藏，点击关联'.tr,
                    _ => '已收藏并关联'.tr,
                  },
                  onTap: _stage == 0 ? _favoriteCv : _linkCv,
                ),
              const SizedBox(height: 8),
              InkWell(
                onTap: (_charSaved || _charSaving) ? null : _saveCharacter,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: _charSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: colors.primary))
                      : Text(_charSaved ? '角色已保存'.tr : '保存角色到作品'.tr,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _charSaved
                                  ? colors.onSurface.withValues(alpha: 0.4)
                                  : colors.onSurface)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(ColorScheme colors, String text, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled
            ? colors.primary
            : colors.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: filled
                  ? colors.onPrimary
                  : colors.onSurface.withValues(alpha: 0.55))),
    );
  }

  Widget _placeholder(ColorScheme colors) {
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.person_outline,
            size: 28, color: colors.onSurface.withValues(alpha: 0.2)),
      ),
    );
  }
}

// ── 真人弹层 ──────────────────────────────────────────────

class _BangumiPersonSheet extends StatefulWidget {
  final Map<String, dynamic> personRef;
  final String target;
  final Future<String?> Function() ensureSubject;
  final String? characterName;

  const _BangumiPersonSheet({
    required this.personRef,
    required this.target,
    required this.ensureSubject,
    this.characterName,
  });

  @override
  State<_BangumiPersonSheet> createState() => _BangumiPersonSheetState();
}

class _BangumiPersonSheetState extends State<_BangumiPersonSheet> {
  final _bgm = BangumiService.instance;

  Map<String, dynamic>? _detail;
  bool _loading = true;
  String? _error;
  int _stage = 0;
  bool _busy = false;

  String get _name {
    final cn = (widget.personRef['name_cn'] ?? '').toString().trim();
    if (cn.isNotEmpty) return cn;
    final d = _detail;
    if (d != null) {
      final c = bangumiNameCn(d);
      if (c != null && c.isNotEmpty) return c;
    }
    return (widget.personRef['name'] ?? '').toString();
  }

  /// 关联用的 roleType：声优固定 voiceActor，制作人员按 relation 映射
  String get _roleType {
    if (widget.characterName != null) return 'voiceActor';
    return bangumiRoleType(
        ((widget.personRef['relation_merged'] ??
                    widget.personRef['relation'] ??
                    '') as String)
            .toString(),
        widget.target);
  }

  /// 徽章显示 Bangumi 原始职务（如「系列构成」），
  /// roleType 映射仅用于本地关联写入，不在此展示
  String? get _roleLabel {
    if (widget.characterName != null) return '配音'.tr;
    final rel = ((widget.personRef['relation_merged'] ??
                widget.personRef['relation'] ??
                '') as String)
        .toString()
        .trim();
    return rel.isNotEmpty ? rel : null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = (widget.personRef['id'] as num).toInt();
      final detail = await _bgm.personDetail(id);
      if (!mounted) return;
      // 中文名合并进条目数据（name_cn），弹层关闭后卡片可刷新
      final cn = bangumiNameCn(detail);
      if (cn != null && cn.isNotEmpty) widget.personRef['name_cn'] = cn;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      _checkLocal();
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

  /// 本地已存在同名人物时从"已收藏"起步
  void _checkLocal() {
    final provider = context.read<AppProvider>();
    final exists =
        provider.people.any((e) => !e.isDeleted && e.name == _name);
    if (exists) setState(() => _stage = 1);
  }

  Future<void> _onStageButton() async {
    if (_stage == 0) {
      await _favorite();
    } else if (_stage == 1) {
      await _link();
    }
  }

  Future<void> _favorite() async {
    if (_detail == null) return;
    setState(() => _busy = true);
    try {
      final person =
          await upsertBangumiPerson(context, _detail!, roleType: _roleType);
      if (mounted && person != null) setState(() => _stage = 1);
    } catch (_) {
      if (mounted) ToastUtil.show(context, '网络错误'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    if (_detail == null) return;
    setState(() => _busy = true);
    try {
      final localId = await widget.ensureSubject();
      if (localId == null || !mounted) return;
      final person =
          await upsertBangumiPerson(context, _detail!, roleType: _roleType);
      if (person == null || !mounted) return;
      await linkBangumiPerson(context,
          localId: localId,
          target: widget.target,
          person: person,
          roleType: _roleType,
          characterName: widget.characterName);
      if (mounted) {
        setState(() => _stage = 2);
        ToastUtil.show(context, '已关联「{name}」'.trf({'name': _name}));
      }
    } catch (_) {
      if (mounted) ToastUtil.show(context, '网络错误'.tr);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          child: _loading
              ? Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.primary)))
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  colors.onSurface.withValues(alpha: 0.4))))
                  : _buildContent(colors),
        ),
      ],
    );
  }

  Widget _buildContent(ColorScheme colors) {
    final d = _detail!;
    final imageUrl =
        bangumiImageUrl(d['images'] as Map<String, dynamic>?);
    final summary = (d['summary'] ?? '').toString().trim();
    final birth = _birthDate(d);
    final gender = _mapGender(d['gender']);
    final meta = [
      if (gender == 'female') '女',
      if (gender == 'male') '男',
      if (birth != null) '${birth.year}-${birth.month.toString().padLeft(2, '0')}-${birth.day.toString().padLeft(2, '0')}',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.surfaceContainerHighest,
              backgroundImage:
                  imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? Icon(Icons.person,
                      size: 30, color: colors.onSurface.withValues(alpha: 0.2))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (widget.characterName != null)
                        _chip(colors, '{cv} 饰 {name}'.trf({
                          'cv': '配音'.tr,
                          'name': widget.characterName!,
                        })),
                      if (_roleLabel != null) _chip(colors, _roleLabel!),
                    ],
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(meta,
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurface.withValues(alpha: 0.45))),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: BangumiExpandableText(
                text: summary,
                maxLines: 6,
                style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurface.withValues(alpha: 0.7),
                    height: 1.55)),
          ),
        const SizedBox(height: 18),
        _StageButton(
          stage: _stage,
          busy: _busy,
          label: (s) => switch (s) {
            0 => '加入人物收藏'.tr,
            1 => '已收藏，点击关联'.tr,
            _ => '已收藏并关联'.tr,
          },
          onTap: _onStageButton,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _chip(ColorScheme colors, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary)),
    );
  }
}
