import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import '../../widgets/app_overlay.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  int _currentIndex = 0;
  bool _isSyncing = false;

  static const _tabTypes = ['movie_genre', 'book_genre', 'note_tag', 'game_genre'];
  static const _typeBaseNames = ['影视', '书籍', '笔记', '游戏'];
  static const _typeIcons = [Icons.movie_outlined, Icons.menu_book_outlined, Icons.sticky_note_2_outlined, Icons.sports_esports_outlined];

  List<String> get _typeLabels =>
      ['影视类型'.tr, '书籍类型'.tr, '笔记标签'.tr, '游戏类型'.tr];

  final Map<String, List<Map<String, dynamic>>> _tagCache = {};
  Map<String, int> _usageCounts = {};
  String? _newlyAddedTagId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showTypePicker = false;
  final Set<String> _collapsedIds = {}; // 已折叠的标签ID（默认展开）

  @override
  void initState() {
    super.initState();
    _loadTags(_tabTypes[0]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateUsageCounts();
  }

  void _updateUsageCounts() {
    final provider = context.read<AppProvider>();
    final counts = <String, int>{};

    for (final m in provider.movies.where((m) => !m.isDeleted)) {
      for (final g in m.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    for (final b in provider.books.where((b) => !b.isDeleted)) {
      for (final g in b.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    for (final n in provider.notes.where((n) => !n.isDeleted)) {
      for (final t in n.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    for (final g in provider.games.where((g) => !g.isDeleted)) {
      for (final genre in g.genres) {
        counts[genre] = (counts[genre] ?? 0) + 1;
      }
    }

    _usageCounts = counts;
  }

  Future<void> _loadTags(String type) async {
    final provider = context.read<AppProvider>();
    final tags = await provider.getTags(type);
    if (mounted) setState(() => _tagCache[type] = tags);
  }

  Future<void> _syncTags() async {
    setState(() => _isSyncing = true);
    try {
      final provider = context.read<AppProvider>();
      final count = await provider.syncTagsFromData();
      if (mounted) {
        ToastUtil.show(context,
            count > 0
                ? '已同步 {n} 个新标签'.trf({'n': count})
                : '标签已是最新'.tr);
        await _loadTags(_currentType);
        _updateUsageCounts();
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _onTabChanged(int index) {
    setState(() => _currentIndex = index);
    _loadTags(_tabTypes[index]);
  }

  String get _currentType => _tabTypes[_currentIndex];

  // ─── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(title: Text('标签'.tr), actions: [
        _isSyncing
            ? Padding(padding: const EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)))
            : IconButton(icon: const Icon(Icons.sync, size: 20), tooltip: '从数据中同步标签'.tr, onPressed: _syncTags),
      ]),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildTagList(_currentType),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 弹出的类别胶囊按钮
          if (_showTypePicker) ...[
            ...[0, 1, 2, 3].where((i) => i != _currentIndex).map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() => _showTypePicker = false);
                  _onTabChanged(i);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface, borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_typeIcons[i], size: 16, color: colors.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(_typeLabels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  ]),
                ),
              ),
            )),
            const SizedBox(height: 4),
          ],
          // 底部按钮行
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 类别切换按钮
              GestureDetector(
                onTap: () => setState(() => _showTypePicker = !_showTypePicker),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surface, borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_typeIcons[_currentIndex], size: 16, color: colors.onSurface.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(_typeLabels[_currentIndex], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
                    const SizedBox(width: 4),
                    Icon(_showTypePicker ? Icons.arrow_drop_down : Icons.arrow_drop_up, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              // 添加按钮
              GestureDetector(
                onTap: _showAddDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.primary, borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 18, color: colors.onPrimary),
                    const SizedBox(width: 6),
                    Text('添加{type}'.trf({'type': _typeLabels[_currentIndex]}), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onPrimary)),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 标签列表 ──────────────────────────────────────────────────────────

  Widget _buildTagList(String type) {
    final tags = _tagCache[type] ?? [];
    final colors = Theme.of(context).colorScheme;
    final isSearching = _searchQuery.isNotEmpty;

    if (tags.isEmpty && !isSearching) {
      return SingleChildScrollView(
        key: ValueKey('empty_$type'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSearchBar(colors),
          const SizedBox(height: 40),
          _buildEmptyState(type),
        ]),
      );
    }

    // 搜索模式
    if (isSearching) {
      final filtered = tags.where((t) => (t['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList()
        ..sort((a, b) => (_usageCounts[b['name']] ?? 0).compareTo(_usageCounts[a['name']] ?? 0));
      return SingleChildScrollView(
        key: ValueKey('search_$type'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSearchBar(colors),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('没有找到"{q}"相关标签'.trf({'q': _searchQuery}), style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
            )
          else
            Wrap(spacing: 8, runSpacing: 6, children: filtered.map(_buildTagChip).toList()),
        ]),
      );
    }

    // 树形模式：按 parent_id 构建层级
    final childrenByParent = _groupByParent(tags);
    final roots = childrenByParent[''] ?? [];
    // 兜底：父级不在标签集合中的节点也作为根显示，避免标签丢失
    final allIds = tags.map((t) => t['id'] as String).toSet();
    for (final t in tags) {
      final pid = (t['parent_id'] as String?) ?? '';
      if (pid.isNotEmpty && !allIds.contains(pid) && !roots.any((r) => r['id'] == t['id'])) {
        roots.add(t);
      }
    }

    if (roots.isEmpty) {
      return SingleChildScrollView(
        key: ValueKey(type),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(colors),
            const SizedBox(height: 8),
            _buildEmptyGroup('暂无标签'.tr, colors),
          ],
        ),
      );
    }

    // 扁平化 + 按需构建，标签量大时不卡顿
    final items = _flattenTree(roots, childrenByParent);
    return ListView.builder(
      key: ValueKey(type),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(children: [
            _buildSearchBar(colors),
            const SizedBox(height: 8),
          ]);
        }
        final item = items[index - 1];
        return item.isGap
            ? _buildDropGap(item.siblings!, item.parentId!, item.insertIndex, item.depth)
            : _buildTagRow(item.tag!, item.children!, item.depth);
      },
    );
  }

  /// 按 parent_id 将标签分组
  Map<String, List<Map<String, dynamic>>> _groupByParent(List<Map<String, dynamic>> tags) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final t in tags) {
      final parent = (t['parent_id'] as String?) ?? '';
      map.putIfAbsent(parent, () => []).add(t);
    }
    return map;
  }

  /// 将树扁平化为「行/缝隙」序列，供 ListView.builder 按需构建（长列表性能）
  List<_TreeItem> _flattenTree(
    List<Map<String, dynamic>> roots,
    Map<String, List<Map<String, dynamic>>> childrenByParent,
  ) {
    final items = <_TreeItem>[];

    void walk(List<Map<String, dynamic>> nodes, int depth, String parentId) {
      for (var i = 0; i < nodes.length; i++) {
        final tag = nodes[i];
        final id = tag['id'] as String;
        final sub = childrenByParent[id] ?? [];
        items.add(_TreeItem.gap(nodes, parentId, i, depth));
        items.add(_TreeItem.row(tag, sub, depth));
        if (sub.isNotEmpty && !_collapsedIds.contains(id)) {
          walk(sub, depth + 1, id);
        }
      }
      items.add(_TreeItem.gap(nodes, parentId, nodes.length, depth));
    }

    walk(roots, 0, '');
    return items;
  }

  /// 行间缝隙放置区：拖到两行之间时展开并显示指示线，松手插入该位置
  Widget _buildDropGap(List<Map<String, dynamic>> siblings, String parentId, int insertIndex, int depth) {
    final colors = Theme.of(context).colorScheme;
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => _canDropInGap(details.data, parentId),
      onAcceptWithDetails: (details) => _doGapDrop(details.data, siblings, parentId, insertIndex),
      builder: (context, candidates, rejected) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 16 : 6,
          margin: EdgeInsets.only(left: depth * 20.0 + 28),
          child: Center(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: active ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 缝隙放置校验：父级不能是自身或自己的后代（防成环）
  bool _canDropInGap(Map<String, dynamic> dragged, String parentId) {
    if (parentId.isEmpty) return true;
    final draggedId = dragged['id'] as String;
    if (parentId == draggedId) return false;
    final allTags = _tagCache[dragged['type'] as String] ?? [];
    return !_collectDescendants(allTags, draggedId).contains(parentId);
  }

  Future<void> _doGapDrop(Map<String, dynamic> dragged, List<Map<String, dynamic>> siblings, String parentId, int insertIndex) async {
    final type = dragged['type'] as String;
    final draggedId = dragged['id'] as String;
    // 目标组现有顺序（去掉被拖项）；若被拖项原本在插入点之前，移除后插入点前移一位
    final ids = siblings.map((s) => s['id'] as String).where((id) => id != draggedId).toList();
    var idx = insertIndex;
    final oldIndex = siblings.indexWhere((s) => s['id'] == draggedId);
    if (oldIndex >= 0 && oldIndex < insertIndex) idx -= 1;
    ids.insert(idx.clamp(0, ids.length), draggedId);
    await context.read<AppProvider>().reorderTags(type, parentId, ids, draggedId);
    await _loadTags(type);
  }

  Widget _buildTagRow(Map<String, dynamic> tag, List<Map<String, dynamic>> children, int depth) {
    final colors = Theme.of(context).colorScheme;
    final id = tag['id'] as String;
    final name = tag['name'] as String;
    final count = _usageCounts[name] ?? 0;
    final isHidden = (tag['is_hidden'] as int?) == 1;
    final isNew = id == _newlyAddedTagId;
    final hasChildren = children.isNotEmpty;
    final collapsed = _collapsedIds.contains(id);

    final rowContent = Stack(
      children: [
        // 层级引导线：每个祖先层级一条竖线（文件树风格）
        if (depth > 0)
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < depth; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9.5),
                    child: Container(width: 1, color: colors.outlineVariant.withValues(alpha: 0.6)),
                  ),
              ],
            ),
          ),
        Row(
      children: [
        SizedBox(width: depth * 20.0),
        // 展开/收起箭头
        SizedBox(
          width: 28,
          height: 44,
          child: Center(
            child: hasChildren
                ? GestureDetector(
                    onTap: () => setState(() {
                          if (collapsed) {
                            _collapsedIds.remove(id);
                          } else {
                            _collapsedIds.add(id);
                          }
                        }),
                    child: Icon(
                      collapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 20,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  )
                : Icon(Icons.circle, size: 4, color: colors.onSurface.withValues(alpha: 0.15)),
          ),
        ),
        // 标签主体（点击打开菜单，长按拖拽移动分类）
        Expanded(
          child: GestureDetector(
            key: ValueKey(id),
            behavior: HitTestBehavior.opaque,
            onTap: () => _showTagMenu(tag),
            child: Opacity(
              opacity: isHidden ? 0.4 : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: isNew
                    ? _NewTagHighlight(child: _rowContent(name, count, colors, isHidden: isHidden))
                    : _rowContent(name, count, colors, isHidden: isHidden),
              ),
            ),
          ),
        ),
      ],
        ),
      ],
    );

    // 拖动目标：把拖来的标签设为当前标签的子级
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => _canDropOn(details.data, tag),
      onAcceptWithDetails: (details) => _doDragMove(details.data, tag),
      builder: (context, candidates, rejected) {
        final isTarget = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isTarget ? colors.primary.withValues(alpha: 0.08) : Colors.transparent,
            border: depth == 0
                ? Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))
                : null,
          ),
          child: LongPressDraggable<Map<String, dynamic>>(
            data: tag,
            feedback: _dragFeedback(name, colors),
            childWhenDragging: Opacity(opacity: 0.3, child: rowContent),
            child: rowContent,
          ),
        );
      },
    );
  }

  /// 是否允许把 [dragged] 拖到 [target] 下（排除自身与成环）
  bool _canDropOn(Map<String, dynamic> dragged, Map<String, dynamic> target) {
    final draggedId = dragged['id'] as String;
    final targetId = target['id'] as String;
    if (draggedId == targetId) return false;
    final allTags = _tagCache[target['type'] as String] ?? [];
    final descendants = _collectDescendants(allTags, draggedId);
    return !descendants.contains(targetId);
  }

  Future<void> _doDragMove(Map<String, dynamic> dragged, Map<String, dynamic> target) async {
    final type = dragged['type'] as String;
    final success = await context.read<AppProvider>().setTagParent(
        dragged['id'] as String, type, target['id'] as String);
    if (mounted) {
      if (success) ToastUtil.show(context, '已移动到「{name}」'.trf({'name': target['name']}));
      await _loadTags(type);
    }
  }

  /// 拖拽反馈 — 全宽灰色行，与列表中的标签行视觉一致
  Widget _dragFeedback(String name, ColorScheme colors) {
    final width = MediaQuery.of(context).size.width - 40; // 对齐列表 padding: 20
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
          border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
      ),
    );
  }

  Widget _rowContent(String name, int count, ColorScheme colors, {bool isHidden = false}) {
    return Row(
      children: [
        Flexible(
          child: Text(name, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface,
            decoration: isHidden ? TextDecoration.lineThrough : null,
          )),
        ),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ],
    );
  }

  Widget _buildSearchBar(ColorScheme colors) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search_rounded, size: 18, color: colors.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              cursorColor: colors.primary,
              decoration: InputDecoration(
                hintText: '搜索标签...'.tr,
                hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); FocusManager.instance.primaryFocus?.unfocus(); },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildEmptyGroup(String text, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final name = tag['name'] as String;
    final count = _usageCounts[name] ?? 0;
    final tagId = tag['id'] as String;
    final isNew = tagId == _newlyAddedTagId;
    final isHidden = (tag['is_hidden'] as int?) == 1;

    return GestureDetector(
      key: ValueKey(tagId),
      onTap: () => _showTagMenu(tag),
      onLongPress: () => _showTagMenu(tag),
      child: Opacity(
        opacity: isHidden ? 0.4 : 1.0,
        child: isNew
            ? _NewTagHighlight(child: _tagChipContent(name, count, colors, isHidden: isHidden))
            : _tagChipContent(name, count, colors, isHidden: isHidden),
      ),
    );
  }

  Widget _tagChipContent(String name, int count, ColorScheme colors, {bool isHidden = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface,
            decoration: isHidden ? TextDecoration.lineThrough : null,
          )),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.35))),
          ],
        ],
      ),
    );
  }

  // ─── 新标签高亮动画 ─────────────────────────────────────────────────────

  Widget _buildEmptyState(String type) {
    final colors = Theme.of(context).colorScheme;
    final idx = _tabTypes.indexOf(type);
    final icon = _typeIcons[idx];
    final label = _typeLabels[idx];
    final hints = [
      '同步或手动添加影视类型'.tr,
      '同步或手动添加书籍类型'.tr,
      '同步或手动添加笔记标签'.tr,
      '同步或手动添加游戏类型'.tr,
    ];

    return Center(
      key: ValueKey('empty_$type'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, size: 28, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 16),
          Text('暂无{label}'.trf({'label': label}),
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(hints[idx], style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.15))),
        ],
      ),
    );
  }

  // ─── 标签操作菜单 ───────────────────────────────────────────────────────

  void _showTagMenu(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final name = tag['name'] as String;
    final isHidden = (tag['is_hidden'] as int?) == 1;

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(
                  width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                )),
                // 紧凑标题
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
                      if (isHidden) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
                        child: Text('已隐藏'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _menuAction(
                  isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  (isHidden ? '取消隐藏' : '隐藏').tr,
                  colors,
                  () async {
                    Navigator.pop(ctx);
                    await context.read<AppProvider>().toggleTagHidden(tag['id'] as String);
                    await _loadTags(_currentType);
                  },
                ),
                _menuAction(Icons.drive_file_move_outlined, '移动到分类'.tr, colors, () {
                  Navigator.pop(ctx);
                  _showMoveDialog(tag);
                }),
                _menuAction(
                    Icons.open_in_new_outlined,
                    '查看相关{name}'.trf({'name': _typeBaseNames[_currentIndex].tr}),
                    colors, () {
                  Navigator.pop(ctx);
                  _showTagItems(name);
                }),
                _menuAction(Icons.edit_outlined, '重命名'.tr, colors, () {
                  Navigator.pop(ctx);
                  _showRenameDialog(tag);
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 0.5, color: colors.outlineVariant),
                ),
                _menuAction(Icons.delete_outline, '删除'.tr, colors, () {
                  Navigator.pop(ctx);
                  _showDeleteDialog(tag);
                }, isDestructive: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuAction(IconData icon, String title, ColorScheme colors, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: isDestructive ? colors.error : colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDestructive ? colors.error : colors.onSurface,
            )),
          ],
        ),
      ),
    );
  }

  void _showTagItems(String tagName) {
    final provider = context.read<AppProvider>();
    final colors = Theme.of(context).colorScheme;

    // item 为对应的 Movie/Book/Game/Note 对象，点击跳转详情
    List<({String title, String? subtitle, String type, Object item})> items = [];
    if (_currentType == 'movie_genre') {
      for (final m in provider.movies.where((m) => !m.isDeleted && m.genres.contains(tagName))) {
        items.add((title: m.title, subtitle: m.directors.take(2).join(' / '), type: '影视', item: m));
      }
    } else if (_currentType == 'book_genre') {
      for (final b in provider.books.where((b) => !b.isDeleted && b.genres.contains(tagName))) {
        items.add((title: b.title, subtitle: b.authors.take(2).join(' / '), type: '书籍', item: b));
      }
    } else if (_currentType == 'game_genre') {
      for (final g in provider.games.where((g) => !g.isDeleted && g.genres.contains(tagName))) {
        items.add((title: g.title, subtitle: g.platforms.take(2).join(' / '), type: '游戏', item: g));
      }
    } else {
      for (final n in provider.notes.where((n) => !n.isDeleted && n.tags.contains(tagName))) {
        items.add((title: n.title.isNotEmpty ? n.title : '随手记'.tr, subtitle: null, type: '笔记', item: n));
      }
    }

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('{name}（{n}）'.trf({'name': tagName, 'n': items.length}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('暂无相关内容'.tr, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)))),
              )
            else
              ...items.asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry.key > 0) Divider(height: 0.5, color: colors.outlineVariant),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title, style: TextStyle(fontSize: 14, color: colors.onSurface)),
                        subtitle: item.subtitle != null && item.subtitle!.isNotEmpty
                            ? Text(item.subtitle!, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)))
                            : null,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                            child: Text(item.type.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
                        ]),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openItemDetail(item.item);
                        },
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// 跳转到条目对应的详情页
  void _openItemDetail(Object item) {
    if (item is Movie) {
      Navigator.pushNamed(context, '/movie-detail', arguments: item);
    } else if (item is Book) {
      Navigator.pushNamed(context, '/book-detail', arguments: item);
    } else if (item is Game) {
      Navigator.pushNamed(context, '/game-detail', arguments: item);
    } else if (item is Note) {
      Navigator.pushNamed(context, '/note-detail', arguments: item);
    }
  }

  // ─── 移动到分类 ─────────────────────────────────────────────────────────

  Set<String> _collectDescendants(List<Map<String, dynamic>> allTags, String tagId) {
    final result = <String>{};
    final queue = <String>[tagId];
    while (queue.isNotEmpty) {
      final parent = queue.removeAt(0);
      for (final t in allTags) {
        if ((t['parent_id'] as String?) == parent) {
          final id = t['id'] as String;
          if (result.add(id)) queue.add(id);
        }
      }
    }
    return result;
  }

  void _showMoveDialog(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final name = tag['name'] as String;
    final currentParent = (tag['parent_id'] as String?) ?? '';

    final allTags = _tagCache[type] ?? [];
    final descendants = _collectDescendants(allTags, tagId);
    final candidates = allTags
        .where((t) => (t['id'] as String) != tagId && !descendants.contains(t['id'] as String))
        .toList();

    var query = '';

    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => OwnedTextController(
        builder: (ctx, controller) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bc = Theme.of(ctx).colorScheme;
            final filtered = query.isEmpty
                ? candidates
                : candidates.where((c) => (c['name'] as String).toLowerCase().contains(query.toLowerCase())).toList();
            return SafeArea(
              child: Padding(
                // 键盘弹出时顶起面板
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: Container(
                      width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 12),
                      decoration: BoxDecoration(color: bc.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('移动到「{name}」'.trf({'name': name}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: bc.onSurface)),
                    ),
                    // 搜索框
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: bc.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded, size: 17, color: bc.onSurface.withValues(alpha: 0.35)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: controller,
                              style: TextStyle(fontSize: 14, color: bc.onSurface),
                              cursorColor: bc.primary,
                              decoration: InputDecoration(
                                hintText: '搜索分类...'.tr,
                                hintStyle: TextStyle(fontSize: 14, color: bc.onSurface.withValues(alpha: 0.3)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 9),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                              onChanged: (v) => setSheetState(() => query = v.trim()),
                            ),
                          ),
                          if (query.isNotEmpty)
                            GestureDetector(
                              onTap: () { controller.clear(); setSheetState(() => query = ''); },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: bc.surfaceContainerHighest, shape: BoxShape.circle),
                                child: Icon(Icons.close_rounded, size: 13, color: bc.onSurface.withValues(alpha: 0.4)),
                              ),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _moveOption(
                      bc,
                      icon: Icons.home_outlined,
                      title: '顶级（无父级）'.tr,
                      selected: currentParent.isEmpty,
                      onTap: () => _doMoveParent(ctx, tagId, type, ''),
                    ),
                    if (filtered.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('设为某分类的子级'.tr, style: TextStyle(fontSize: 12, color: bc.onSurface.withValues(alpha: 0.4))),
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(bottom: 16),
                          children: filtered.map((c) => _moveOption(
                            bc,
                            icon: Icons.folder_outlined,
                            title: c['name'] as String,
                            selected: c['id'] == currentParent,
                            onTap: () => _doMoveParent(ctx, tagId, type, c['id'] as String),
                          )).toList(),
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('没有找到相关分类'.tr, style: TextStyle(fontSize: 13, color: bc.onSurface.withValues(alpha: 0.4))),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _doMoveParent(BuildContext ctx, String tagId, String type, String parentId) async {
    final success = await context.read<AppProvider>().setTagParent(tagId, type, parentId);
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ToastUtil.show(context, success ? '移动成功'.tr : '无法移动到该分类'.tr);
    }
    await _loadTags(type);
  }

  Widget _moveOption(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.7),
            ))),
            if (selected) Icon(Icons.check, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }

  // ─── 添加标签 ──────────────────────────────────────────────────────────

  void _showAddDialog() {
    final colors = Theme.of(context).colorScheme;
    final type = _currentType;

    appDialog(
      context: context,
      builder: (ctx) => OwnedTextController(
        builder: (ctx, controller) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('添加{type}'.trf({'type': _typeLabels[_currentIndex]}),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true,
          style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入标签名称'.tr,
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            filled: true, fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
          onSubmitted: (value) => _doAddTag(ctx, controller.text.trim(), type),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          Container(
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _doAddTag(ctx, controller.text.trim(), type),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('添加'.tr, style: TextStyle(fontSize: 14, color: colors.onPrimary, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
    );
  }

  Future<void> _doAddTag(BuildContext ctx, String name, String type) async {
    if (name.isEmpty) return;
    try {
      final provider = context.read<AppProvider>();
      final newId = await provider.addTag(name, type);
      if (!mounted) return;
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ToastUtil.show(context, '添加成功'.tr);
      }
      setState(() => _newlyAddedTagId = newId);
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _newlyAddedTagId = null);
      });
      await _loadTags(type);
    } catch (e) {
      if (ctx.mounted) ToastUtil.show(ctx, '添加失败：该标签已存在'.tr);
    }
  }

  // ─── 重命名 ────────────────────────────────────────────────────────────

  void _showRenameDialog(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final oldName = tag['name'] as String;

    appDialog(
      context: context,
      builder: (ctx) => OwnedTextController(
        initialText: tag['name'] as String,
        builder: (ctx, controller) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重命名标签'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true,
          style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入新名称'.tr,
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            filled: true, fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
          onSubmitted: (value) => _doRenameTag(ctx, tagId, value.trim(), type, oldName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          Container(
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _doRenameTag(ctx, tagId, controller.text.trim(), type, oldName),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('确定'.tr, style: TextStyle(fontSize: 14, color: colors.onPrimary, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
    );
  }

  Future<void> _doRenameTag(BuildContext ctx, String tagId, String newName, String type, String oldName) async {
    if (newName.isEmpty || newName == oldName) {
      if (ctx.mounted) Navigator.pop(ctx);
      return;
    }
    final success = await context.read<AppProvider>().renameTag(tagId, newName, type);
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ToastUtil.show(context, success ? '重命名成功'.tr : '重命名失败：标签名已存在'.tr);
    }
    if (success) await _loadTags(type);
  }

  // ─── 删除标签（简化版：默认仅删除标签，高级选项可展开） ─────────────────────

  void _showDeleteDialog(Map<String, dynamic> tag) {
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final name = tag['name'] as String;
    String? selectedAction = 'deleteOnly';
    String? selectedReplacement;
    bool showAdvanced = false;

    final otherTags = (_tagCache[type] ?? [])
        .where((t) => t['id'] != tagId)
        .map((t) => t['name'] as String)
        .toList();

    appDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bc = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: bc.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: bc.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: bc.onSurface.withValues(alpha: 0.6))),
                ),
                const SizedBox(width: 10),
                Text('删除标签'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: bc.onSurface)),
              ],
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      // 默认选项
                      _buildDeleteOption(
                        value: 'deleteOnly',
                        groupValue: selectedAction,
                        onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                        title: '仅删除标签'.tr,
                        subtitle: '保留已有条目上的标签名，不影响数据'.tr,
                        colors: bc,
                      ),
                      const SizedBox(height: 8),
                      // 展开/收起高级选项
                      GestureDetector(
                        onTap: () => setDialogState(() => showAdvanced = !showAdvanced),
                        child: Row(
                          children: [
                            Text('更多选项'.tr, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: bc.primary)),
                            Icon(showAdvanced ? Icons.expand_less : Icons.expand_more, size: 16, color: bc.primary),
                          ],
                        ),
                      ),
                      if (showAdvanced) ...[
                        const SizedBox(height: 10),
                        _buildDeleteOption(
                          value: 'remove',
                          groupValue: selectedAction,
                          onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                          title: '从所有条目中移除'.tr,
                          subtitle: '彻底清除该标签在所有条目中的记录'.tr,
                          colors: bc,
                        ),
                        const SizedBox(height: 4),
                        _buildDeleteOption(
                          value: 'replace',
                          groupValue: selectedAction,
                          onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                          title: '替换为其他标签'.tr,
                          subtitle: '选择一个已有标签替代'.tr,
                          colors: bc,
                        ),
                        if (selectedAction == 'replace')
                          Padding(
                            padding: const EdgeInsets.only(left: 40, top: 10),
                            child: otherTags.isNotEmpty
                                ? Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: otherTags.map((t) {
                                      final isSelected = selectedReplacement == t;
                                      return GestureDetector(
                                        onTap: () => setDialogState(() => selectedReplacement = isSelected ? null : t),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: isSelected ? bc.primary : bc.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: isSelected ? bc.primary : bc.outlineVariant, width: 0.5),
                                          ),
                                          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? bc.onPrimary : bc.onSurface.withValues(alpha: 0.7))),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(color: bc.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                                    child: Text('无其他标签可替换'.tr, style: TextStyle(fontSize: 13, color: bc.onSurface.withValues(alpha: 0.35))),
                                  ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消'.tr, style: TextStyle(color: bc.onSurface.withValues(alpha: 0.4)))),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(20)),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (selectedAction == 'replace' && (selectedReplacement == null || selectedReplacement!.isEmpty)) return;
                      Navigator.pop(ctx, {'action': selectedAction, 'replacement': selectedReplacement});
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text('删除'.tr, style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          );
        },
      ),
    ).then((result) async {
      if (result == null) return;
      final action = result['action'] as String;
      final replacement = result['replacement'] as String?;
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (action == 'deleteOnly') {
        await provider.deleteTagOnly(tagId, type);
      } else {
        await provider.deleteTag(tagId, type, replacementName: replacement);
      }
      if (!mounted) return;
      ToastUtil.show(context, '删除成功'.tr);
      await _loadTags(type);
    });
  }

  Widget _buildDeleteOption({
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
    required String title,
    String? subtitle,
    required ColorScheme colors,
  }) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? colors.surfaceContainerHigh : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? colors.primary : colors.outlineVariant, width: selected ? 1 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? colors.primary : colors.onSurface.withValues(alpha: 0.25), width: selected ? 5 : 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w500 : FontWeight.normal, color: selected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.6))),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 树扁平化条目 ─────────────────────────────────────────────────────────

/// 扁平化后的树条目：标签行 或 行间缝隙放置区
class _TreeItem {
  final bool isGap;
  // 行字段
  final Map<String, dynamic>? tag;
  final List<Map<String, dynamic>>? children;
  // 缝隙字段
  final List<Map<String, dynamic>>? siblings;
  final String? parentId;
  final int insertIndex;

  final int depth;

  _TreeItem.row(this.tag, this.children, this.depth)
      : isGap = false,
        siblings = null,
        parentId = null,
        insertIndex = 0;

  _TreeItem.gap(this.siblings, this.parentId, this.insertIndex, this.depth)
      : isGap = true,
        tag = null,
        children = null;
}

// ─── 新标签高亮动画 Widget ─────────────────────────────────────────────────

class _NewTagHighlight extends StatefulWidget {
  final Widget child;
  const _NewTagHighlight({required this.child});

  @override
  State<_NewTagHighlight> createState() => _NewTagHighlightState();
}

class _NewTagHighlightState extends State<_NewTagHighlight> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _controller.value < 0.3
            ? (_controller.value / 0.3).clamp(0.0, 1.0)
            : (1.0 - (_controller.value - 0.3) / 0.7).clamp(0.0, 1.0);
        final scale = 1.0 + 0.06 * (1.0 - _controller.value);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: colors.primary.withValues(alpha: 0.12 * opacity),
              border: Border.all(color: colors.primary.withValues(alpha: 0.3 * opacity), width: 1),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}
