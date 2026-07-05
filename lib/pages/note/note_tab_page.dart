import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/note_list_item.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../utils/responsive.dart';
import '../../widgets/master_detail_scaffold.dart';
import '../../widgets/detail_placeholder.dart';
import 'note_detail_page.dart';

/// 笔记标签页（分页 + 触底加载）
class NoteTabPage extends StatefulWidget {
  const NoteTabPage({super.key});

  @override
  State<NoteTabPage> createState() => _NoteTabPageState();
}

class _NoteTabPageState extends State<NoteTabPage> {
  final List<Note> _items = [];
  bool _hasMore = true;
  bool _isLoading = false;
  int _offset = 0;
  late ScrollController _scrollController;
  AppProvider? _provider;
  int _layoutStyle = 0;
  bool _initialized = false;
  int _lastScrollSignal = 0;
  int _prevNoteCount = -1;
  int _lastEditRefreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().noteLayoutStyle;
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      _provider = provider;
      provider.addListener(_onDataChanged);
      _loadFirst();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onDataChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (!_initialized || !mounted) return;
    final provider = context.read<AppProvider>();

    if (provider.scrollToTopSignal != _lastScrollSignal && provider.scrollToTopSignal > 0) {
      _lastScrollSignal = provider.scrollToTopSignal;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }

    // 仅在数据实际变化时刷新列表，避免底部导航栏显隐等UI变化误触发重载
    final countChanged = provider.notes.length != _prevNoteCount;
    final editRefreshed = provider.editRefreshCounter > _lastEditRefreshCounter;
    if (editRefreshed && provider.lastEditedItemId != null) {
      // 就地更新被编辑的条目，不重置分页
      _lastEditRefreshCounter = provider.editRefreshCounter;
      _prevNoteCount = provider.notes.length;
      final editedId = provider.lastEditedItemId!;
      final idx = _items.indexWhere((n) => n.id == editedId);
      if (idx != -1) {
        final updated = provider.notes.where((n) => n.id == editedId).firstOrNull;
        if (updated != null) {
          setState(() { _items[idx] = updated; });
        }
      }
      return;
    }
    if (countChanged || editRefreshed) {
      _prevNoteCount = provider.notes.length;
      _loadFirst();
    }
    if (editRefreshed) {
      _lastEditRefreshCounter = provider.editRefreshCounter;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    _initialized = true;
    setState(() { _isLoading = true; _offset = 0; _hasMore = true; });
    final sortMode = UserPrefs().noteSortMode;
    final list = await context.read<AppProvider>().loadNotesPaged(offset: 0, sortMode: sortMode);
    if (!mounted) return;
    setState(() { _items.clear(); _items.addAll(list); _offset = list.length; _hasMore = list.length >= 20; _isLoading = false; });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final sortMode = UserPrefs().noteSortMode;
    final list = await context.read<AppProvider>().loadNotesPaged(offset: _offset, sortMode: sortMode);
    if (!mounted) return;
    setState(() { _items.addAll(list); _offset += list.length; _hasMore = list.length >= 20; _isLoading = false; });
  }

  void _onNoteTap(Note note) {
    if (Breakpoint.isWideContent(context)) {
      context.read<AppProvider>().selectNote(note);
    } else {
      Navigator.pushNamed(context, '/note-detail', arguments: note);
    }
  }

  Future<void> _refresh() async {
    await context.read<AppProvider>().loadNotes();
    await _loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isWideContent = Breakpoint.isWideContent(context);
    return Consumer<AppProvider>(builder: (context, provider, _) {
      if (_items.isEmpty && _isLoading) return _buildSkeleton();
      if (_items.isEmpty) {
        return RefreshIndicator(onRefresh: _refresh, color: colors.primary, backgroundColor: colors.surface,
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [_buildEmptyState(context)]));
      }
      final masterContent = _buildContent(isWideContent);
      if (!isWideContent) return masterContent;
      return MasterDetailScaffold(
        master: masterContent,
        detail: provider.selectedNote != null
            ? NoteDetailPage(note: provider.selectedNote!, embedded: true)
            : const DetailPlaceholder(icon: Icons.note_outlined, message: '选择一条笔记查看详情'),
      );
    });
  }

  Widget _buildContent(bool isWideContent) {
    if (_layoutStyle == 1) return _buildWaterfallView(isWideContent);
    if (_layoutStyle == 2) return _buildTimelineView(isWideContent);
    return _buildListView(isWideContent);
  }

  Widget _buildSkeleton() {
    switch (_layoutStyle) {
      case 1: return _buildWaterfallSkeleton();
      case 2: return const NoteSkeletonTimeline();
      default: return const NoteSkeletonList();
    }
  }

  Widget _buildWaterfallSkeleton() {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: List.generate(2, (_) => Expanded(
        child: Column(children: List.generate(4, (_) => Container(margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const ShimmerSkeleton(width: double.infinity, height: 140, borderRadius: 10),
            Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const ShimmerSkeleton(width: double.infinity, height: 14), const SizedBox(height: 6),
              const ShimmerSkeleton(width: double.infinity, height: 12), const SizedBox(height: 6),
              const ShimmerSkeleton(width: 60, height: 10),
            ])),
          ]),
        ))),
      ))),
    );
  }

  Widget _buildListView(bool isWideContent) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(onRefresh: _refresh, color: colors.primary, backgroundColor: colors.surface,
      child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) return _buildLoadMore();
          final selectedId = context.read<AppProvider>().selectedNote?.id;
          return NoteListItem(note: _items[index], selected: isWideContent && selectedId == _items[index].id, onTap: () => _onNoteTap(_items[index]));
        },
      ),
    );
  }

  Widget _buildTimelineView(bool isWideContent) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(onRefresh: _refresh, color: colors.primary, backgroundColor: colors.surface,
      child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: _items.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) return _buildLoadMore();
          return _buildTimelineItem(_items[index]);
        },
      ),
    );
  }

  Widget _buildTimelineItem(Note note) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onNoteTap(note),
      onLongPress: () => _showNoteActions(note),
      child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 40, child: Column(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle, border: Border.all(color: colors.surface, width: 2))),
          Expanded(child: Container(width: 1, color: colors.outline)),
        ])),
        Expanded(child: Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(_formatFullDate(note.updatedAt), style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)))),
              if (note.isPinned) Icon(Icons.push_pin, size: 14, color: colors.primary),
            ]),
            if (note.title.isNotEmpty) ...[const SizedBox(height: 6),
              Text(note.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 6),
            Text(_getPreviewText(note), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5)),
            if (note.tags.isNotEmpty) ...[const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: note.tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(4)),
                child: Text(tag, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
              )).toList()),
            ],
          ]),
        )),
      ])),
    );
  }

  String _formatFullDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Widget _buildWaterfallView(bool isWideContent) {
    return LayoutBuilder(builder: (context, constraints) {
      final colCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 160, minCount: 2, maxCount: 4);
      final columns = List.generate(colCount, (_) => <Note>[]);
      for (int i = 0; i < _items.length; i++) {
        columns[i % colCount].add(_items[i]);
      }
      return SingleChildScrollView(controller: _scrollController, padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (int c = 0; c < colCount; c++) ...[
            if (c > 0) const SizedBox(width: 8),
            Expanded(child: Column(children: columns[c].map(_buildWaterfallCard).toList())),
          ],
        ]),
      );
    });
  }

  Widget _buildWaterfallCard(Note note) {
    final colors = Theme.of(context).colorScheme;
    final contentText = _getPreviewText(note);
    final images = note.images;
    final hasImage = images.isNotEmpty;
    final extraCount = images.length - 1;
    return GestureDetector(
      onTap: () => _onNoteTap(note),
      onLongPress: () => _showNoteActions(note),
      child: Container(margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))]),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (hasImage) Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: FadeInLocalImage(path: images.first, fit: BoxFit.cover, errorWidget: const SizedBox.shrink())),
            if (extraCount > 0) Positioned(top: 6, right: 6,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(10)),
                child: Text('+$extraCount', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (note.title.isNotEmpty) Text(note.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3)),
              if (contentText.isNotEmpty && contentText != '(无内容)') ...[
                if (note.title.isNotEmpty) const SizedBox(height: 4),
                Text(contentText, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4), height: 1.4)),
              ],
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(_formatTime(note.updatedAt),
                    style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.25)))),
                if (note.tags.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(3)),
                  child: Text(note.tags.first, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }  String _getPreviewText(Note note) {
    final text = note.content.replaceAll(RegExp(r'[#*\[\]\(\)]'), '').trim();
    return text.isEmpty ? '(无内容)' : text;
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildLoadMore() {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: _isLoading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
          : Text('没有更多了', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)))),
    );
  }

  void _showNoteActions(Note note) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(note.isPinned ? Icons.push_pin_outlined : Icons.push_pin, size: 20, color: colors.onSurface.withValues(alpha: 0.6))),
            title: Text(note.isPinned ? '取消置顶' : '置顶', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
            subtitle: Text(note.isPinned ? '取消置顶后按时间排序' : '置顶后始终显示在最前', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () async {
              Navigator.pop(ctx);
              await context.read<AppProvider>().toggleNotePin(note.id, !note.isPinned);
              _loadFirst();
            },
          ),
          Divider(height: 0.5, color: colors.outlineVariant),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.delete_outline, size: 20, color: colors.error)),
            title: Text('删除', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.error)),
            subtitle: Text('删除后可在回收站恢复', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              _showDeleteDialog(note);
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _showDeleteDialog(Note note) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除这条笔记吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async { await context.read<AppProvider>().removeNote(note.id); if (!ctx.mounted) return; Navigator.pop(ctx); if (mounted) _loadFirst(); },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.note_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25))),
      const SizedBox(height: 20),
      Text('暂无笔记', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
    ]));
  }
}
