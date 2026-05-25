import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/note_list_item.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/fade_in_local_image.dart';

/// 笔记标签页
class NoteTabPage extends StatefulWidget {
  const NoteTabPage({super.key});

  @override
  State<NoteTabPage> createState() => _NoteTabPageState();
}

class _NoteTabPageState extends State<NoteTabPage> {
  static const int _pageSize = 50;
  final List<Note> _displayedNotes = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  int _layoutStyle = 0;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _layoutStyle = UserPrefs().noteLayoutStyle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreNotes();
      if (mounted) setState(() => _firstLoad = false);
    });
  }

  int _lastNotesCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<AppProvider>();
    final allNotes = provider.notes;

    if (allNotes.length != _lastNotesCount && _displayedNotes.isNotEmpty) {
      _lastNotesCount = allNotes.length;
      setState(() {
        _displayedNotes.clear();
        _hasMore = true;
      });
      Future.microtask(() => _loadMoreNotes());
    } else {
      _lastNotesCount = allNotes.length;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotes();
    }
  }

  Future<void> _loadMoreNotes() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    await Future.microtask(() {
      final provider = context.read<AppProvider>();
      final allNotes = provider.notes;

      final startIndex = _displayedNotes.length;
      final endIndex = (startIndex + _pageSize).clamp(0, allNotes.length);

      if (startIndex >= allNotes.length) {
        _hasMore = false;
      } else {
        final newNotes = allNotes.sublist(startIndex, endIndex);
        _displayedNotes.addAll(newNotes);
        _hasMore = endIndex < allNotes.length;
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    final provider = context.read<AppProvider>();
    await provider.loadNotes();
    setState(() {
      _displayedNotes.clear();
      _hasMore = true;
    });
    await _loadMoreNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Consumer<AppProvider>(
            builder: (context, provider, child) {
              final allNotes = provider.notes;
              _syncDisplayedNotes(allNotes);

              if (_firstLoad) {
                return _buildSkeleton();
              }

              if (allNotes.isEmpty && _displayedNotes.isEmpty) {
                final colors = Theme.of(context).colorScheme;
                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: colors.primary,
                  backgroundColor: colors.surface,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [_buildEmptyState(context)],
                  ),
                );
              }

              if (_layoutStyle == 1) {
                return _buildWaterfallView();
              }
              if (_layoutStyle == 2) {
                return _buildTimelineView();
              }
              return _buildListView();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    switch (_layoutStyle) {
      case 1:
        return _buildWaterfallSkeleton();
      case 2:
        return const NoteSkeletonList();
      default:
        return const NoteSkeletonList();
    }
  }

  Widget _buildWaterfallSkeleton() {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(2, (_) => Expanded(
          child: Column(
            children: List.generate(4, (_) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerSkeleton(width: double.infinity, height: 140, borderRadius: 10),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShimmerSkeleton(width: double.infinity, height: 14),
                        const SizedBox(height: 6),
                        const ShimmerSkeleton(width: double.infinity, height: 12),
                        const SizedBox(height: 6),
                        const ShimmerSkeleton(width: 60, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ),
        )),
      ),
    );
  }

  Widget _buildListView() {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
        itemCount: _displayedNotes.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _displayedNotes.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                ),
              ),
            );
          }
          return NoteListItem(note: _displayedNotes[index]);
        },
      ),
    );
  }

  Widget _buildTimelineView() {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: _displayedNotes.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _displayedNotes.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
              ),
            );
          }
          return _buildTimelineItem(_displayedNotes[index]);
        },
      ),
    );
  }

  Widget _buildTimelineItem(Note note) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/note-detail', arguments: note).then((_) async {
          await context.read<AppProvider>().loadNotes();
        });
      },
      onLongPress: () => _showDeleteDialog(context, note),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 1,
                      color: colors.outline,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatFullDate(note.updatedAt),
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                    if (note.title.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        note.title,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _getPreviewText(note),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5), height: 1.5),
                    ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: note.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(tag, style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
                        )).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWaterfallView() {
    final colors = Theme.of(context).colorScheme;
    final leftItems = <Note>[];
    final rightItems = <Note>[];
    for (int i = 0; i < _displayedNotes.length; i++) {
      if (i % 2 == 0) {
        leftItems.add(_displayedNotes[i]);
      } else {
        rightItems.add(_displayedNotes[i]);
      }
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: colors.primary,
      backgroundColor: colors.surface,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: leftItems.map((n) => _buildWaterfallCard(n)).toList())),
            const SizedBox(width: 8),
            Expanded(child: Column(children: rightItems.map((n) => _buildWaterfallCard(n)).toList())),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterfallCard(Note note) {
    final colors = Theme.of(context).colorScheme;
    final contentText = _getPreviewText(note);
    final images = note.images;
    final hasImage = images.isNotEmpty;
    final extraCount = images.length - 1;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/note-detail', arguments: note).then((_) async {
          await context.read<AppProvider>().loadNotes();
        });
      },
      onLongPress: () => _showDeleteDialog(context, note),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImage)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: FadeInLocalImage(
                      path: images.first,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                  if (extraCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+$extraCount',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note.title.isNotEmpty)
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                        height: 1.3,
                      ),
                    ),
                  if (contentText.isNotEmpty && contentText != '(无内容)') ...[
                    if (note.title.isNotEmpty) const SizedBox(height: 4),
                    Text(
                      contentText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.4),
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatTime(note.updatedAt),
                          style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.25)),
                        ),
                      ),
                      if (note.tags.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            note.tags.first,
                            style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPreviewText(Note note) {
    final text = note.content
        .replaceAll(RegExp(r'#'), '')
        .replaceAll(RegExp(r'\*'), '')
        .replaceAll(RegExp(r'`'), '')
        .replaceAll(RegExp(r'[\[\]\(\)]'), '')
        .trim();
    return text.isEmpty ? '(无内容)' : text;
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(BuildContext context, Note note) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除这条笔记吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeNote(note.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _syncDisplayedNotes(List<Note> allNotes) {
    final validNoteIds = allNotes.map((n) => n.id).toSet();
    final initialLength = _displayedNotes.length;
    _displayedNotes.removeWhere((note) => !validNoteIds.contains(note.id));

    final displayedIds = _displayedNotes.map((n) => n.id).toSet();
    final hasNewNotes = allNotes.any((note) => !displayedIds.contains(note.id));

    bool hasUpdates = false;
    for (int i = 0; i < _displayedNotes.length; i++) {
      final localNote = _displayedNotes[i];
      final providerNote = allNotes.firstWhere((n) => n.id == localNote.id);
      if (localNote.updatedAt != providerNote.updatedAt) {
        hasUpdates = true;
        break;
      }
    }

    if (_displayedNotes.length < initialLength || hasNewNotes || hasUpdates) {
      _displayedNotes.clear();
      _displayedNotes.addAll(allNotes);
      _hasMore = false;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.note_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          Text('暂无笔记', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => Navigator.pushNamed(context, '/note-form'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('添加记录',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
