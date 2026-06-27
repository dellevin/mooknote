import 'package:flutter/material.dart';
import '../../../models/book_annotation.dart';
import '../../../utils/reader/book_annotation_dao.dart';

/// 书签列表组件 — 显示当前书籍的所有书签，点击跳转
class BookmarkList extends StatefulWidget {
  final String bookId;
  final void Function(String cfi) onNavigate;

  const BookmarkList({
    super.key,
    required this.bookId,
    required this.onNavigate,
  });

  @override
  State<BookmarkList> createState() => _BookmarkListState();
}

class _BookmarkListState extends State<BookmarkList> {
  final _dao = BookAnnotationDao();
  List<BookAnnotation> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await _dao.getBookmarks(widget.bookId);
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
        _loading = false;
      });
    }
  }

  Future<void> _deleteBookmark(BookAnnotation bookmark) async {
    await _dao.deleteById(bookmark.id!);
    await _loadBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 48, color: colors.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 12),
            Text('暂无书签', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              '阅读时点击顶部 ⭐ 按钮添加书签',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withAlpha(150)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bm = _bookmarks[index];
        return Dismissible(
          key: ValueKey(bm.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: colors.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除书签'),
                content: Text('确定删除「${bm.content.isNotEmpty ? bm.content : bm.chapter}」？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
                ],
              ),
            );
          },
          onDismissed: (_) => _deleteBookmark(bm),
          child: ListTile(
            leading: Icon(Icons.bookmark, color: Colors.amber, size: 20),
            title: Text(
              bm.content.isNotEmpty ? bm.content : bm.chapter,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              bm.chapter.isNotEmpty ? bm.chapter : '',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            dense: true,
            onTap: () => widget.onNavigate(bm.cfi),
          ),
        );
      },
    );
  }
}
