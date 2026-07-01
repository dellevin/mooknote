import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/epub/reader_dao.dart';
import 'book_excerpt_form_page.dart';

/// 书籍摘抄列表页面
class BookExcerptsPage extends StatefulWidget {
  final Book book;

  const BookExcerptsPage({super.key, required this.book});

  @override
  State<BookExcerptsPage> createState() => _BookExcerptsPageState();
}

class _BookExcerptsPageState extends State<BookExcerptsPage> {
  List<BookExcerpt> _excerpts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExcerpts();
  }

  Future<void> _loadExcerpts() async {
    setState(() => _isLoading = true);
    try {
      final excerpts = await context.read<AppProvider>().getBookExcerpts(widget.book.id);
      if (mounted) {
        setState(() {
          _excerpts = excerpts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ToastUtil.show(context, '加载失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('摘抄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (_excerpts.isNotEmpty)
              Text('共 ${_excerpts.length} 条', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddExcerpt,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('添加摘抄'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _excerpts.isEmpty
              ? _buildEmptyState(colors)
              : _buildExcerptList(colors),
    );
  }

  // ── 空状态 ──

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.format_quote_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            const SizedBox(height: 20),
            Text('暂无摘抄', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text('记录书中触动人心的文字', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25))),
          ],
        ),
      ),
    );
  }

  // ── 摘抄列表 ──

  Widget _buildExcerptList(ColorScheme colors) {
    final chapters = _groupExcerptsByChapter().keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final excerpts = _groupExcerptsByChapter()[chapter]!;
        return _buildChapterSection(chapter, excerpts, colors, index);
      },
    );
  }

  /// 按章节分组
  Map<String, List<BookExcerpt>> _groupExcerptsByChapter() {
    final groups = <String, List<BookExcerpt>>{};
    for (final e in _excerpts) {
      final chapter = e.chapter.isEmpty ? '未分类' : e.chapter;
      (groups[chapter] ??= []).add(e);
    }
    for (final key in groups.keys) {
      groups[key]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return groups;
  }

  // ── 章节分组 ──

  Widget _buildChapterSection(String chapter, List<BookExcerpt> excerpts, ColorScheme colors, int chapterIndex) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(chapter, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${excerpts.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
          // 摘抄卡片
          ...excerpts.map((excerpt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildExcerptCard(excerpt, colors),
          )),
        ],
      ),
    );
  }

  // ── 摘抄卡片 ──

  Widget _buildExcerptCard(BookExcerpt excerpt, ColorScheme colors) {
    return Dismissible(
      key: ValueKey(excerpt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (direction) => _showDeleteDialog(excerpt),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateToEditExcerpt(excerpt),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 引号 + 摘抄内容
                Stack(
                  children: [
                    Positioned(
                      left: -6,
                      top: -6,
                      child: Text(
                        '"',
                        style: TextStyle(
                          fontSize: 32,
                          color: colors.primary.withValues(alpha: 0.15),
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        excerpt.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.85),
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                // 感悟
                if (excerpt.comment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(color: colors.primary.withValues(alpha: 0.3), width: 2),
                      ),
                    ),
                    child: Text(
                      excerpt.comment,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.55),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
                // 底部：日期 + 操作
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: colors.onSurface.withValues(alpha: 0.25)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(excerpt.createdAt),
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _navigateToEditExcerpt(excerpt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(Icons.edit_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  void _navigateToAddExcerpt() {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => BookExcerptFormPage(bookId: widget.book.id))).then((_) => _loadExcerpts());
  }

  void _navigateToEditExcerpt(BookExcerpt excerpt) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => BookExcerptFormPage(bookId: widget.book.id, excerpt: excerpt))).then((_) => _loadExcerpts());
  }

  Future<bool?> _showDeleteDialog(BookExcerpt excerpt) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('删除摘抄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: Text('确定删除这条摘抄吗？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
            TextButton(
              onPressed: () async {
                Navigator.pop(context, true);
                final readerBook = await ReaderDao().getReaderBookByBookId(widget.book.id);
                if (readerBook != null) {
                  await ReaderDao().deleteExcerptHighlightByContent(
                    readerBook['id'] as String,
                    excerpt.content,
                  );
                }
                await context.read<AppProvider>().removeBookExcerpt(excerpt.id);
                _loadExcerpts();
                if (mounted) ToastUtil.show(context, '已删除');
              },
              child: Text('删除', style: TextStyle(color: colors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }
}
