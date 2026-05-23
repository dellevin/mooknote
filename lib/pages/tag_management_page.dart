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

  @override
  void initState() {
    super.initState();
    _loadTags(_tabTypes[0]);
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
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String get _currentType => _tabTypes[_currentIndex];

  /// 计算标签使用次数
  Map<String, int> _getTagUsageCounts(String type) {
    final provider = context.read<AppProvider>();
    final counts = <String, int>{};

    switch (type) {
      case 'movie_genre':
        for (final m in provider.movies.where((m) => !m.isDeleted)) {
          for (final g in m.genres) {
            counts[g] = (counts[g] ?? 0) + 1;
          }
        }
        break;
      case 'book_genre':
        for (final b in provider.books) {
          for (final g in b.genres) {
            counts[g] = (counts[g] ?? 0) + 1;
          }
        }
        break;
      case 'note_tag':
        for (final n in provider.notes.where((n) => !n.isDeleted)) {
          for (final t in n.tags) {
            counts[t] = (counts[t] ?? 0) + 1;
          }
        }
        break;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A))),
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
          Expanded(child: _buildTagList(_currentType)),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: _showAddDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('添加${_typeLabels[_currentIndex]}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 选择器 ──────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEBEB),
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
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  left: _currentIndex * tabWidth,
                  top: 0, bottom: 0, width: tabWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                        onTap: () {
                          setState(() => _currentIndex = i);
                          _loadTags(_tabTypes[i]);
                        },
                        child: Container(
                          height: double.infinity,
                          alignment: Alignment.center,
                          child: Text(_typeLabels[i],
                              style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF999999))),
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

  // ─── 标签列表 ────────────────────────────────────────────────────────

  Widget _buildTagList(String type) {
    final tags = _tagCache[type] ?? [];
    final usageCounts = _getTagUsageCounts(type);

    if (tags.isEmpty) {
      return _buildEmptyState(type);
    }

    // 按使用次数降序排序
    final sorted = List<Map<String, dynamic>>.from(tags)
      ..sort((a, b) {
        final ca = usageCounts[a['name']] ?? 0;
        final cb = usageCounts[b['name']] ?? 0;
        return cb.compareTo(ca);
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计行
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('共 ${tags.length} 个标签', style: const TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                const Spacer(),
                Text('已使用 ${usageCounts.length} 个', style: const TextStyle(fontSize: 12, color: Color(0xFFD0D0D0))),
              ],
            ),
          ),
          // 标签列表
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: sorted.map((tag) => _buildTagChip(tag, usageCounts)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(Map<String, dynamic> tag, Map<String, int> usageCounts) {
    final name = tag['name'] as String;
    final count = usageCounts[name] ?? 0;

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 6, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标签名区域 — 点击改名
          GestureDetector(
            onTap: () => _showRenameDialog(tag),
            child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
            ),
          ],
          const SizedBox(width: 4),
          // X 按钮 — 点击删除
          GestureDetector(
            onTap: () => _showDeleteDialog(tag),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.close, size: 12, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    final idx = _tabTypes.indexOf(type);
    final icon = _typeIcons[idx];
    final label = _typeLabels[idx];
    final hints = ['同步或手动添加影视类型', '同步或手动添加书籍类型', '同步或手动添加笔记标签'];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: const Color(0xFFECECEC), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, size: 28, color: const Color(0xFFCCCCCC)),
          ),
          const SizedBox(height: 16),
          Text('暂无$label',
              style: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB), fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(hints[idx], style: const TextStyle(fontSize: 12, color: Color(0xFFD5D5D5))),
        ],
      ),
    );
  }

  // ─── 添加标签 ────────────────────────────────────────────────────────

  void _showAddDialog() {
    final controller = TextEditingController();
    final type = _currentType;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('添加${_typeLabels[_currentIndex]}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        content: TextField(
          controller: controller, autofocus: true,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: '输入标签名称',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
            filled: true, fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1)),
          ),
          onSubmitted: (value) => _doAddTag(ctx, controller.text.trim(), type),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Color(0xFF999999)))),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _doAddTag(ctx, controller.text.trim(), type),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('添加', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
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
      await context.read<AppProvider>().addTag(name, type);
    } catch (e) {
      if (ctx.mounted) ToastUtil.show(ctx, '添加失败：该标签已存在');
      return;
    }
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ToastUtil.show(context, '添加成功');
    }
    await _loadTags(type);
  }

  // ─── 重命名 ──────────────────────────────────────────────────────────

  void _showRenameDialog(Map<String, dynamic> tag) {
    final controller = TextEditingController(text: tag['name'] as String);
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final oldName = tag['name'] as String;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('重命名标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        content: TextField(
          controller: controller, autofocus: true,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: '输入新名称',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
            filled: true, fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1)),
          ),
          onSubmitted: (value) => _doRenameTag(ctx, tagId, value.trim(), type, oldName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Color(0xFF999999)))),
          Container(
            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _doRenameTag(ctx, tagId, controller.text.trim(), type, oldName),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('确定', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w500)),
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

  // ─── 删除（长按触发）──────────────────────────────────────────────────

  void _showDeleteDialog(Map<String, dynamic> tag) {
    final tagId = tag['id'] as String;
    final type = tag['type'] as String;
    final name = tag['name'] as String;
    String? selectedAction = 'remove';
    final replacementController = TextEditingController();

    final otherTags = (_tagCache[type] ?? [])
        .where((t) => t['id'] != tagId)
        .map((t) => t['name'] as String)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF666666))),
              ),
              const SizedBox(width: 10),
              const Text('删除标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
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
                    const Text('删除后对已有条目的影响：', style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                    const SizedBox(height: 12),
                    _buildDeleteOption(value: 'remove', groupValue: selectedAction, onChanged: (v) => setDialogState(() => selectedAction = v), title: '从所有条目中移除该标签', subtitle: '标签将从影视/书籍/笔记中清除'),
                    const SizedBox(height: 4),
                    _buildDeleteOption(value: 'deleteOnly', groupValue: selectedAction, onChanged: (v) => setDialogState(() => selectedAction = v), title: '仅删除标签', subtitle: '保留已有条目上的标签名'),
                    const SizedBox(height: 4),
                    _buildDeleteOption(value: 'replace', groupValue: selectedAction, onChanged: (v) => setDialogState(() => selectedAction = v), title: '替换为其他标签'),
                    if (selectedAction == 'replace')
                      Padding(
                        padding: const EdgeInsets.only(left: 40, top: 10),
                        child: otherTags.isNotEmpty
                            ? Wrap(
                                spacing: 8, runSpacing: 8,
                                children: otherTags.map((t) {
                                  final isSelected = replacementController.text == t;
                                  return GestureDetector(
                                    onTap: () {
                                      replacementController.text = isSelected ? '' : t;
                                      setDialogState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8), width: 0.5),
                                      ),
                                      child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : const Color(0xFF555555))),
                                    ),
                                  );
                                }).toList(),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(12)),
                                child: const Text('无其他标签可替换', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Color(0xFF999999)))),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(20)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    String? replacement;
                    if (selectedAction == 'replace') {
                      replacement = replacementController.text.trim().isNotEmpty ? replacementController.text.trim() : null;
                      if (replacement == null) return;
                    }
                    Navigator.pop(ctx, {'action': selectedAction, 'replacement': replacement});
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
        ),
      ),
    ).then((result) async {
      if (result == null) return;
      final action = result['action'] as String;
      final replacement = result['replacement'] as String?;
      if (action == 'deleteOnly') {
        await context.read<AppProvider>().deleteTagOnly(tagId, type);
      } else {
        await context.read<AppProvider>().deleteTag(tagId, type, replacementName: replacement);
      }
      if (mounted) ToastUtil.show(context, '删除成功');
      await _loadTags(type);
    });
  }

  Widget _buildDeleteOption({
    required String value,
    required String? groupValue,
    required ValueChanged<String?> onChanged,
    required String title,
    String? subtitle,
  }) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFAFAFA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE), width: selected ? 1 : 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC), width: selected ? 5 : 1.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w500 : FontWeight.normal, color: selected ? const Color(0xFF1A1A1A) : const Color(0xFF666666))),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
