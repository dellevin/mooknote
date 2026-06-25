import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expandable/expandable.dart';
import '../../providers/note_plus_provider.dart';
import '../../models/note_plus_models.dart';

/// Note Plus 树形文件列表页
class NotePlusTabPage extends StatefulWidget {
  const NotePlusTabPage({super.key});

  @override
  State<NotePlusTabPage> createState() => _NotePlusTabPageState();
}

class _NotePlusTabPageState extends State<NotePlusTabPage> {
  String? _selectedDocId;
  String? _dragOverNodeId; // 拖到节点上（成为子节点）
  _DropPosition? _dropPos; // 拖到节点之间（排序）

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotePlusProvider>().loadDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(colors),
        Expanded(child: _buildTree(colors)),
      ],
    );
  }

  Widget _buildHeader(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(children: [
        Icon(Icons.edit_note, size: 18, color: colors.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text('Note Plus', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.7))),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final provider = context.read<NotePlusProvider>();
            final doc = await provider.createDocument();
            if (!mounted) return;
            Navigator.pushNamed(context, '/note-plus-form', arguments: doc.id);
          },
          child: Icon(Icons.add, size: 20,
              color: colors.onSurface.withValues(alpha: 0.45)),
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: () => _showRecycleBin(context),
          child: Icon(Icons.delete_outline, size: 18,
              color: colors.onSurface.withValues(alpha: 0.35)),
        ),
      ]),
    );
  }

  Widget _buildTree(ColorScheme colors) {
    return Consumer<NotePlusProvider>(
      builder: (context, provider, _) {
        if (provider.documents.isEmpty) return _buildEmptyState(colors);

        final roots = provider.documents
            .where((d) => d.parentId.isEmpty)
            .toList()
          ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

        if (roots.isEmpty) return _buildEmptyState(colors);

        return ExpandableTheme(
          data: const ExpandableThemeData(
            useInkWell: false,
            animationDuration: Duration(milliseconds: 200),
            headerAlignment: ExpandablePanelHeaderAlignment.center,
            tapBodyToExpand: false, tapBodyToCollapse: false,
            tapHeaderToExpand: false, iconPadding: EdgeInsets.zero, hasIcon: false,
          ),
          child: RefreshIndicator(
            onRefresh: () => provider.loadDocuments(),
            child: ListView(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 40),
              children: _buildChildrenList(roots, 0, colors),
            ),
          ),
        );
      },
    );
  }

  /// 构建子节点列表，节点之间插入 drop zone（共 n+1 个间隙）
  List<Widget> _buildChildrenList(List<NotePlusDocument> docs, int depth, ColorScheme colors) {
    final widgets = <Widget>[];
    final parentId = docs.isNotEmpty ? docs.first.parentId : '';
    for (int i = 0; i < docs.length; i++) {
      // 节点前的间隙
      widgets.add(_buildReorderGap(parentId, i, depth, colors));
      // 节点本身
      widgets.add(_buildTreeNode(docs[i], depth, colors));
    }
    // 末尾间隙
    if (docs.isNotEmpty) {
      widgets.add(_buildReorderGap(parentId, docs.length, depth, colors));
    }
    return widgets;
  }

  /// 排序间隙 drop zone
  Widget _buildReorderGap(String parentId, int insertIndex, int depth, ColorScheme colors) {
    final indent = 28.0 + depth * 18.0;
    final isTarget = _dropPos != null &&
        _dropPos!.parentId == parentId &&
        _dropPos!.index == insertIndex;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final draggedId = details.data;
        final provider = context.read<NotePlusProvider>();
        final dragged = provider.documents.where((d) => d.id == draggedId).firstOrNull;
        if (dragged == null) return false;
        // 防止拖到自己的子孙上
        if (parentId.isNotEmpty &&
            _isDescendantOf(provider.documents, childId: parentId, ancestorId: draggedId)) {
          return false;
        }
        setState(() => _dropPos = _DropPosition(parentId, insertIndex));
        return true;
      },
      onLeave: (_) {
        if (_dropPos?.parentId == parentId && _dropPos?.index == insertIndex) {
          setState(() => _dropPos = null);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() { _dropPos = null; _dragOverNodeId = null; });
        _handleDrop(details.data, parentId, insertIndex);
      },
      builder: (_, __, ___) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isTarget ? 36 : 6,
          margin: EdgeInsets.only(left: indent, right: 16),
          decoration: isTarget
              ? BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1),
                )
              : null,
          child: isTarget
              ? Center(
                  child: Text('放置到此处',
                      style: TextStyle(fontSize: 11,
                          color: colors.primary.withValues(alpha: 0.7))),
                )
              : null,
        );
      },
    );
  }

  /// 递归构建单个树节点
  Widget _buildTreeNode(NotePlusDocument doc, int depth, ColorScheme colors) {
    final provider = context.watch<NotePlusProvider>();
    final children = provider.documents
        .where((d) => d.parentId == doc.id)
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    final hasChildren = children.isNotEmpty;
    final isSelected = _selectedDocId == doc.id;
    final isDropTarget = _dragOverNodeId == doc.id;

    final nodeContent = _buildNodeContent(doc, depth,
        hasChildren: hasChildren, isSelected: isSelected,
        isDropTarget: isDropTarget, colors: colors);

    // 可拖拽包装
    final draggable = LongPressDraggable<String>(
      data: doc.id,
      delay: const Duration(milliseconds: 300),
      feedback: Material(
        elevation: 4, borderRadius: BorderRadius.circular(6),
        child: Container(
          width: MediaQuery.of(context).size.width - 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(Icons.description_outlined, size: 14,
                color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Expanded(child: Text(doc.title.isEmpty ? '无标题' : doc.title,
                style: TextStyle(fontSize: 12, color: colors.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: nodeContent),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) {
          final draggedId = details.data;
          if (draggedId == doc.id) return false;
          if (_isDescendantOf(provider.documents, childId: doc.id, ancestorId: draggedId)) {
            return false;
          }
          setState(() => _dragOverNodeId = doc.id);
          return true;
        },
        onLeave: (_) {
          if (_dragOverNodeId == doc.id) setState(() => _dragOverNodeId = null);
        },
        onAcceptWithDetails: (details) {
          setState(() { _dragOverNodeId = null; _dropPos = null; });
          // 拖到节点上 → 成为该节点的子节点
          provider.moveDocument(details.data, doc.id);
        },
        builder: (_, __, ___) => nodeContent,
      ),
    );

    // 组装：可展开节点带子树，叶子节点直接返回
    if (hasChildren) {
      return ExpandableNotifier(
        initialExpanded: true,
        child: Builder(
          builder: (innerCtx) {
            // 给 _buildNodeContent 传入 expandContext 用于展开/折叠
            final nodeWithExpand = _buildNodeContent(doc, depth,
                hasChildren: true, isSelected: isSelected,
                isDropTarget: isDropTarget, expandContext: innerCtx, colors: colors);

            final draggableWithExpand = LongPressDraggable<String>(
              data: doc.id, delay: const Duration(milliseconds: 300),
              feedback: Material(
                elevation: 4, borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: MediaQuery.of(context).size.width - 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(Icons.description_outlined, size: 14,
                        color: colors.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(doc.title.isEmpty ? '无标题' : doc.title,
                        style: TextStyle(fontSize: 12, color: colors.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: nodeWithExpand),
              child: DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  final draggedId = details.data;
                  if (draggedId == doc.id) return false;
                  if (_isDescendantOf(provider.documents, childId: doc.id, ancestorId: draggedId)) {
                    return false;
                  }
                  setState(() => _dragOverNodeId = doc.id);
                  return true;
                },
                onLeave: (_) {
                  if (_dragOverNodeId == doc.id) setState(() => _dragOverNodeId = null);
                },
                onAcceptWithDetails: (details) {
                  setState(() { _dragOverNodeId = null; _dropPos = null; });
                  provider.moveDocument(details.data, doc.id);
                },
                builder: (_, __, ___) => nodeWithExpand,
              ),
            );

            return Column(children: [
              draggableWithExpand,
              Expandable(
                collapsed: const SizedBox(),
                expanded: Column(children: _buildChildrenList(children, depth + 1, colors)),
              ),
            ]);
          },
        ),
      );
    }

    return draggable;
  }

  /// 节点内容（标题行）
  Widget _buildNodeContent(NotePlusDocument doc, int depth,
      {required bool hasChildren, required bool isSelected,
       required bool isDropTarget, BuildContext? expandContext,
       required ColorScheme colors}) {
    final indent = 12.0 + depth * 18.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedDocId = doc.id);
          Navigator.pushNamed(context, '/note-plus-form', arguments: doc.id);
        },
        onLongPress: () => _showDocActions(doc),
        borderRadius: BorderRadius.circular(4),
        child: Container(
        height: 30,
        padding: EdgeInsets.only(left: indent, right: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.08)
              : isDropTarget
                  ? colors.primary.withValues(alpha: 0.12)
                  : null,
          borderRadius: BorderRadius.circular(4),
          border: isDropTarget
              ? Border.all(color: colors.primary.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Row(children: [
          // 展开/折叠箭头
          if (hasChildren)
            SizedBox(
              width: 20, height: 20,
              child: InkWell(
                onTap: () {
                  if (expandContext != null) {
                    ExpandableController.of(expandContext,
                            rebuildOnChange: false, required: true)
                        ?.toggle();
                  }
                },
                child: expandContext != null
                    ? ExpandableIcon(
                        theme: ExpandableThemeData(
                          expandIcon: Icons.keyboard_arrow_right,
                          collapseIcon: Icons.keyboard_arrow_down,
                          iconColor: colors.onSurface.withValues(alpha: 0.4),
                          iconSize: 14, iconPadding: EdgeInsets.zero, hasIcon: false,
                        ),
                      )
                    : Icon(Icons.keyboard_arrow_down, size: 14,
                        color: colors.onSurface.withValues(alpha: 0.4)),
              ),
            )
          else
            const SizedBox(width: 20),
          // 图标
          Icon(_getDocIcon(doc), size: 14,
              color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 6),
          // 标题
          Expanded(
            child: Text(doc.title.isEmpty ? '无标题' : doc.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.75),
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          // 添加子文档
          SizedBox(
            width: 20, height: 20,
            child: InkWell(
              onTap: () => _createChildDoc(doc.id),
              borderRadius: BorderRadius.circular(4),
              child: Icon(Icons.add, size: 13,
                  color: colors.onSurface.withValues(alpha: 0.25)),
            ),
          ),
          const SizedBox(width: 2),
          // 删除
          SizedBox(
            width: 20, height: 20,
            child: InkWell(
              onTap: () => _showDeleteDialog(doc.id),
              borderRadius: BorderRadius.circular(4),
              child: Icon(Icons.delete_outline, size: 13,
                  color: colors.onSurface.withValues(alpha: 0.25)),
            ),
          ),
        ]),
      ),
      ),
    );
  }

  // ─── 拖放处理 ─────────────────────────────────────

  void _handleDrop(String draggedId, String targetParentId, int insertIndex) {
    final provider = context.read<NotePlusProvider>();
    provider.moveDocumentTo(draggedId, targetParentId, insertIndex);
  }

  // ─── 工具 ─────────────────────────────────────

  bool _isDescendantOf(List<NotePlusDocument> docs,
      {required String childId, required String ancestorId}) {
    if (childId.isEmpty) return false;
    if (childId == ancestorId) return true; // 自身也算（防止拖到自己下面）
    var current = docs.where((d) => d.id == childId).firstOrNull;
    while (current != null) {
      if (current.parentId == ancestorId) return true;
      current = docs.where((d) => d.id == current!.parentId).firstOrNull;
    }
    return false;
  }

  IconData _getDocIcon(NotePlusDocument doc) {
    if (doc.blocks.isEmpty) return Icons.description_outlined;
    switch (doc.blocks.first.type) {
      case NoteBlockType.heading1:
      case NoteBlockType.heading2:
      case NoteBlockType.heading3:
        return Icons.title;
      case NoteBlockType.checklist:
        return Icons.check_box_outlined;
      case NoteBlockType.codeBlock:
        return Icons.code;
      case NoteBlockType.quote:
        return Icons.format_quote;
      default:
        return Icons.description_outlined;
    }
  }

  // ─── 操作 ─────────────────────────────────────

  Future<void> _createChildDoc(String parentId) async {
    final provider = context.read<NotePlusProvider>();
    final doc = await provider.createDocument(parentId: parentId);
    if (!mounted) return;
    Navigator.pushNamed(context, '/note-plus-form', arguments: doc.id);
  }

  void _showDocActions(NotePlusDocument doc) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Icon(Icons.subdirectory_arrow_right, size: 20,
                color: colors.onSurface.withValues(alpha: 0.6)),
            title: const Text('新建子文档', style: TextStyle(fontSize: 14)),
            onTap: () { Navigator.pop(ctx); _createChildDoc(doc.id); },
          ),
          ListTile(
            leading: Icon(Icons.edit_outlined, size: 20,
                color: colors.onSurface.withValues(alpha: 0.6)),
            title: const Text('重命名', style: TextStyle(fontSize: 14)),
            onTap: () { Navigator.pop(ctx); _showRenameDialog(doc); },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, size: 20, color: colors.error),
            title: Text('删除', style: TextStyle(fontSize: 14, color: colors.error)),
            subtitle: Text('子文档将提升到上一级',
                style: TextStyle(fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.4))),
            onTap: () { Navigator.pop(ctx); _showDeleteDialog(doc.id); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showRenameDialog(NotePlusDocument doc) {
    final colors = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: doc.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('重命名', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
            color: colors.onSurface)),
        content: TextField(
          controller: controller, autofocus: true,
          decoration: InputDecoration(hintText: '输入标题',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
          onSubmitted: (_) {
            context.read<NotePlusProvider>().renameDocument(doc.id, controller.text);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () {
              context.read<NotePlusProvider>().renameDocument(doc.id, controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary, foregroundColor: colors.onPrimary,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String id) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('删除文档', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
            color: colors.onSurface)),
        content: Text('子文档将自动提升到上一级。可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<NotePlusProvider>().deleteDocument(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showRecycleBin(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<NotePlusProvider>();
    showModalBottomSheet(
      context: context, backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
        builder: (ctx, scrollCtrl) {
          return FutureBuilder<List<NotePlusDocument>>(
            future: provider.getDeletedDocuments(),
            builder: (context, snapshot) {
              final deleted = snapshot.data ?? [];
              return Column(children: [
                Container(width: 36, height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 14),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text('回收站', style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: colors.onSurface)),
                    const Spacer(),
                    Text('${deleted.length} 个文档', style: TextStyle(fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.4))),
                  ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: deleted.isEmpty
                      ? Center(child: Text('回收站为空',
                          style: TextStyle(fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.35))))
                      : ListView.builder(
                          controller: scrollCtrl, itemCount: deleted.length,
                          itemBuilder: (context, i) {
                            final doc = deleted[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.description_outlined, size: 18,
                                  color: colors.onSurface.withValues(alpha: 0.4)),
                              title: Text(doc.title.isEmpty ? '无标题' : doc.title,
                                  style: const TextStyle(fontSize: 13)),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: Icon(Icons.restore, size: 18, color: colors.primary),
                                  onPressed: () { provider.restoreDocument(doc.id); Navigator.pop(ctx); },
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_forever, size: 18, color: colors.error),
                                  onPressed: () { provider.permanentDeleteDocument(doc.id); Navigator.pop(ctx); },
                                ),
                              ]),
                            );
                          },
                        ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 64, height: 64,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.edit_note, size: 32,
              color: colors.onSurface.withValues(alpha: 0.2)),
        ),
        const SizedBox(height: 16),
        Text('暂无文档', style: TextStyle(fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.4))),
        const SizedBox(height: 6),
        Text('点击右上角 + 创建', style: TextStyle(fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.25))),
      ]),
    );
  }
}

/// 拖放位置记录
class _DropPosition {
  final String parentId;
  final int index;
  _DropPosition(this.parentId, this.index);
}
