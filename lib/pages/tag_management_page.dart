import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/toast_util.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  int _currentIndex = 0;
  bool _isSyncing = false;

  static const _tabTypes = ['movie_genre', 'book_genre', 'note_tag'];
  static const _typeLabels = ['影视类型', '书籍类型', '笔记标签'];
  static const _typeIcons = [Icons.movie_outlined, Icons.menu_book_outlined, Icons.note_outlined];

  final Map<String, List<Map<String, dynamic>>> _tagCache = {};
  Map<String, int> _usageCounts = {};
  String? _newlyAddedTagId;

  @override
  void initState() {
    super.initState();
    _loadTags(_tabTypes[0]);
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
        ToastUtil.show(context, count > 0 ? '已同步 $count 个新标签' : '标签已是最新');
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

  int get _activeTagCount {
    return (_tagCache[_currentType] ?? []).where((t) => (_usageCounts[t['name']] ?? 0) > 0).length;
  }

  // ─── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHigh,
      appBar: AppBar(
        title: const Text('标签管理'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '共 ${(_tagCache[_currentType] ?? []).length} 个标签 · 已使用 $_activeTagCount 个',
              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3)),
            ),
          ),
        ),
        actions: [
          _isSyncing
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
                )
              : IconButton(
                  icon: const Icon(Icons.sync, size: 20),
                  tooltip: '从数据中同步标签',
                  onPressed: _syncTags,
                ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          _buildTabSelector(),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _buildTagList(_currentType),
            ),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: _showAddDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: colors.onPrimary),
              const SizedBox(width: 6),
              Text('添加${_typeLabels[_currentIndex]}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 选择器 ─────────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.outlineVariant,
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 3;
          return SizedBox(
            height: 42,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: _currentIndex * tabWidth,
                  top: 0, bottom: 0, width: tabWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(3, (i) {
                    final selected = _currentIndex == i;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _onTabChanged(i),
                        child: AnimatedOpacity(
                          opacity: selected ? 1.0 : 0.4,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          child: Container(
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: Text(_typeLabels[i],
                                style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                    color: colors.onSurface)),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── 标签列表 ──────────────────────────────────────────────────────────

  Widget _buildTagList(String type) {
    final tags = _tagCache[type] ?? [];

    if (tags.isEmpty) {
      return _buildEmptyState(type);
    }

    final sorted = List<Map<String, dynamic>>.from(tags)
      ..sort((a, b) {
        final ca = _usageCounts[a['name']] ?? 0;
        final cb = _usageCounts[b['name']] ?? 0;
        return cb.compareTo(ca);
      });

    return Padding(
      key: ValueKey(type),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sorted.map((tag) => _buildTagChip(tag)).toList(),
        ),
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final name = tag['name'] as String;
    final count = _usageCounts[name] ?? 0;
    final tagId = tag['id'] as String;
    final isNew = tagId == _newlyAddedTagId;

    return GestureDetector(
      key: ValueKey(tagId),
      onTap: () => _showTagMenu(tag),
      onLongPress: () => _showTagMenu(tag),
      child: isNew
          ? _NewTagHighlight(
              child: _tagChipContent(name, count, colors),
            )
          : _tagChipContent(name, count, colors),
    );
  }

  Widget _tagChipContent(String name, int count, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 10, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.4))),
            ),
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
    final hints = ['同步或手动添加影视类型', '同步或手动添加书籍类型', '同步或手动添加笔记标签'];

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
          Text('暂无$label',
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

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
                )),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                ),
                const SizedBox(height: 16),
                _menuAction(Icons.edit_outlined, '重命名', colors, () {
                  Navigator.pop(ctx);
                  _showRenameDialog(tag);
                }),
                _menuAction(Icons.delete_outline, '删除', colors, () {
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isDestructive ? const Color(0xFFE53935) : colors.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 14),
            Text(title, style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDestructive ? const Color(0xFFE53935) : colors.onSurface,
            )),
          ],
        ),
      ),
    );
  }

  // ─── 添加标签 ──────────────────────────────────────────────────────────

  void _showAddDialog() {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    final type = _currentType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('添加${_typeLabels[_currentIndex]}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true,
          style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入标签名称',
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            filled: true, fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
          onSubmitted: (value) => _doAddTag(ctx, controller.text.trim(), type),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          Container(
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _doAddTag(ctx, controller.text.trim(), type),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('添加', style: TextStyle(fontSize: 14, color: colors.onPrimary, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
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
        ToastUtil.show(context, '添加成功');
      }
      setState(() => _newlyAddedTagId = newId);
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _newlyAddedTagId = null);
      });
      await _loadTags(type);
    } catch (e) {
      if (ctx.mounted) ToastUtil.show(ctx, '添加失败：该标签已存在');
    }
  }

  // ─── 重命名 ────────────────────────────────────────────────────────────

  void _showRenameDialog(Map<String, dynamic> tag) {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: tag['name'] as String);
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final oldName = tag['name'] as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重命名标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true,
          style: TextStyle(fontSize: 15, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入新名称',
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            filled: true, fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
          onSubmitted: (value) => _doRenameTag(ctx, tagId, value.trim(), type, oldName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          Container(
            decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _doRenameTag(ctx, tagId, controller.text.trim(), type, oldName),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('确定', style: TextStyle(fontSize: 14, color: colors.onPrimary, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          ),
        ],
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
      ToastUtil.show(context, success ? '重命名成功' : '重命名失败：标签名已存在');
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

    showDialog(
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
                Text('删除标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: bc.onSurface)),
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
                        title: '仅删除标签',
                        subtitle: '保留已有条目上的标签名，不影响数据',
                        colors: bc,
                      ),
                      const SizedBox(height: 8),
                      // 展开/收起高级选项
                      GestureDetector(
                        onTap: () => setDialogState(() => showAdvanced = !showAdvanced),
                        child: Row(
                          children: [
                            Text('更多选项', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: bc.primary)),
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
                          title: '从所有条目中移除',
                          subtitle: '彻底清除该标签在所有条目中的记录',
                          colors: bc,
                        ),
                        const SizedBox(height: 4),
                        _buildDeleteOption(
                          value: 'replace',
                          groupValue: selectedAction,
                          onChanged: (v) => setDialogState(() { selectedAction = v; selectedReplacement = null; }),
                          title: '替换为其他标签',
                          subtitle: '选择一个已有标签替代',
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
                                    child: Text('无其他标签可替换', style: TextStyle(fontSize: 13, color: bc.onSurface.withValues(alpha: 0.35))),
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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: bc.onSurface.withValues(alpha: 0.4)))),
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
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text('删除', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
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
      ToastUtil.show(context, '删除成功');
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
