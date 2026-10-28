import 'package:flutter/material.dart';
import '../../l10n/app_strings.dart';
import '../../services/bangumi_service.dart';
import '../../utils/toast_util.dart';
import 'bangumi_person_sheet.dart';

/// Bangumi 条目全量角色网格页（"更多角色"入口）
class BangumiCharactersPage extends StatefulWidget {
  final List<dynamic> characters;
  final String target; // movie / book / game
  final Future<String?> Function() ensureSubject;

  const BangumiCharactersPage({
    super.key,
    required this.characters,
    required this.target,
    required this.ensureSubject,
  });

  @override
  State<BangumiCharactersPage> createState() => _BangumiCharactersPageState();
}

class _BangumiCharactersPageState extends State<BangumiCharactersPage> {
  final _bgm = BangumiService.instance;

  bool _selecting = false;
  final Set<int> _selected = {}; // Bangumi 角色 id
  bool _includeCv = false; // 批量时同时收藏各角色的主 CV 并关联
  bool _batching = false;
  int _done = 0;

  List<Map<String, dynamic>> get _sorted =>
      sortBangumiCharacters(widget.characters);

  void _toggleSelect(int? id) {
    if (id == null) return;
    setState(() =>
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
  }

  /// 批量保存勾选的角色（可选同时收藏主 CV 并关联本作品）
  Future<void> _runBatch() async {
    if (_batching) return;
    final items = _sorted
        .where((c) => _selected.contains((c['id'] as num?)?.toInt()))
        .toList();
    if (items.isEmpty) return;
    setState(() => _batching = true);
    var saved = 0;
    try {
      final localId = await widget.ensureSubject();
      if (localId == null || !mounted) return;
      for (var i = 0; i < items.length; i++) {
        final c = items[i];
        // 按需拉取角色详情获取简体中文名（失败回退原名，不中断批量）；
        // 合并进共享 map 后：保存的角色名、CV 关联的「饰演」角色名、返回后的卡片显示均为中文
        try {
          final cid = (c['id'] as num?)?.toInt();
          if (cid != null) {
            final detail = await _bgm.characterDetail(cid);
            final cn = bangumiNameCn(detail);
            if (cn != null && cn.isNotEmpty) c['name_cn'] = cn;
          }
        } catch (_) {}
        if (!mounted) return;
        final r = await saveBangumiCharacterToWork(context,
            character: c,
            sortOrder: i,
            target: widget.target,
            localId: localId);
        if (r == 'saved') saved++;
        if (_includeCv) {
          final actors = (c['actors'] as List? ?? []);
          if (actors.isNotEmpty) {
            final aid = ((actors.first as Map)['id'] as num?)?.toInt();
            if (aid != null) {
              try {
                final detail = await _bgm.personDetail(aid);
                if (!mounted) return;
                final person = await upsertBangumiPerson(context, detail,
                    roleType: 'voiceActor', silent: true);
                if (person != null && mounted) {
                  final cn = (c['name_cn'] ?? '').toString().trim();
                  final cname =
                      cn.isNotEmpty ? cn : (c['name'] ?? '').toString();
                  await linkBangumiPerson(context,
                      localId: localId,
                      target: widget.target,
                      person: person,
                      roleType: 'voiceActor',
                      characterName: cname);
                }
              } catch (_) {}
            }
          }
        }
        if (!mounted) return;
        setState(() => _done = i + 1);
      }
      if (mounted) {
        ToastUtil.show(context, '已保存 {n} 个角色'.trf({'n': saved}));
        setState(() {
          _selecting = false;
          _selected.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _batching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 主角 → 配角 → 其他（旁白/客串沉底），与详情页横滑列表一致
    final sorted = _sorted;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_selecting
            ? '已选 {n} 个'.trf({'n': _selected.length})
            : '角色介绍'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
              )
            : null,
        actions: _selecting
            ? [
                TextButton(
                  onPressed: _batching
                      ? null
                      : () => setState(() => _selected.addAll(sorted
                          .map((c) => (c['id'] as num?)?.toInt())
                          .whereType<int>())),
                  child: Text('全选'.tr),
                ),
                TextButton(
                  onPressed:
                      (_selected.isEmpty || _batching) ? null : _runBatch,
                  child: Text(_batching
                      ? '$_done/${_selected.length}'
                      : '完成'.tr),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => setState(() => _selecting = true),
                  child: Text('批量添加'.tr),
                ),
              ],
      ),
      body: Column(
        children: [
          if (_batching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          '正在获取中文名称 {n}/{N}'.trf({
                            'n': '$_done',
                            'N': '${_selected.length}',
                          }),
                          style: TextStyle(
                              fontSize: 13, color: colors.onSurface)),
                    ),
                  ],
                ),
              ),
            ),
          if (_selecting)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('同时收藏 CV 人物'.tr,
                          style: TextStyle(
                              fontSize: 13, color: colors.onSurface)),
                    ),
                    Switch(
                      value: _includeCv,
                      activeThumbColor: colors.primary,
                      activeTrackColor: colors.primary.withValues(alpha: 0.3),
                      inactiveThumbColor: colors.surface,
                      inactiveTrackColor: colors.outline,
                      onChanged: _batching
                          ? null
                          : (v) => setState(() => _includeCv = v),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 14,
                      childAspectRatio: 92 / 190),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final c = sorted[index];
                final id = (c['id'] as num?)?.toInt();
                final checked = id != null && _selected.contains(id);
                // 卡片固定 92 宽，网格 cell 更宽，居中避免整体偏左
                return Center(
                  child: Stack(
                    children: [
                      BangumiCharacterCard(
                        colors: colors,
                        character: c,
                        onTap: () async {
                          if (_selecting) {
                            _toggleSelect(id);
                            return;
                          }
                          await showBangumiCharacterSheet(
                            context,
                            character: c,
                            sortOrder: index,
                            target: widget.target,
                            ensureSubject: widget.ensureSubject,
                          );
                          // 弹层内按需拉取的简体中文名已合并进数据，返回后刷新卡片
                          if (mounted) setState(() {});
                        },
                      ),
                      if (_selecting)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: checked
                                  ? colors.primary
                                  : colors.surface.withValues(alpha: 0.85),
                              border: Border.all(
                                  color: checked
                                      ? colors.primary
                                      : colors.onSurface
                                          .withValues(alpha: 0.3)),
                            ),
                            child: checked
                                ? Icon(Icons.check,
                                    size: 15, color: colors.onPrimary)
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bangumi 条目全量制作人员网格页（"更多"入口）
class BangumiStaffPage extends StatefulWidget {
  final List<Map<String, dynamic>> staff; // 已按 person id 去重合并职务
  final String target;
  final Future<String?> Function() ensureSubject;

  const BangumiStaffPage({
    super.key,
    required this.staff,
    required this.target,
    required this.ensureSubject,
  });

  @override
  State<BangumiStaffPage> createState() => _BangumiStaffPageState();
}

class _BangumiStaffPageState extends State<BangumiStaffPage> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final staff = widget.staff;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text('制作人员'.tr),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 14,
            childAspectRatio: 0.62),
        itemCount: staff.length,
        itemBuilder: (context, index) {
          final s = staff[index];
          final cn = (s['name_cn'] ?? '').toString().trim();
          final name = cn.isNotEmpty ? cn : (s['name'] ?? '').toString();
          final relation =
              ((s['relation_merged'] ?? s['relation'] ?? '') as String)
                  .toString();
          final imageUrl =
              bangumiImageUrl(s['images'] as Map<String, dynamic>?);
          return InkWell(
            onTap: () async {
              await showBangumiPersonSheet(
                context,
                personRef: s,
                target: widget.target,
                ensureSubject: widget.ensureSubject,
              );
              // 弹层内按需拉取的简体中文名已合并进数据，返回后刷新卡片
              if (mounted) setState(() {});
            },
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: colors.surfaceContainerHighest,
                  backgroundImage:
                      imageUrl != null ? NetworkImage(imageUrl) : null,
                  child: imageUrl == null
                      ? Icon(Icons.person,
                          size: 30,
                          color: colors.onSurface.withValues(alpha: 0.2))
                      : null,
                ),
                const SizedBox(height: 6),
                Text(name,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center),
                const SizedBox(height: 2),
                if (relation.isNotEmpty)
                  Text(relation,
                      style: TextStyle(
                          fontSize: 10,
                          color: colors.onSurface.withValues(alpha: 0.4)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
              ],
            ),
          );
        },
      ),
    );
  }
}
