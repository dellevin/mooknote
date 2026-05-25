import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
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
      setState(() {
        _excerpts = excerpts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ToastUtil.show(context, '加载失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('摘抄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddExcerpt(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _excerpts.isEmpty
              ? _buildEmptyState()
              : _buildExcerptList(),
    );
  }

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.format_quote_outlined,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无摘抄',
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => _navigateToAddExcerpt(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '添加记录',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 按章节分组摘抄数据
  Map<String, List<BookExcerpt>> _groupExcerptsByChapter() {
    final Map<String, List<BookExcerpt>> groups = {};

    for (final excerpt in _excerpts) {
      final chapter = excerpt.chapter.isEmpty ? '未分类' : excerpt.chapter;
      if (!groups.containsKey(chapter)) {
        groups[chapter] = [];
      }
      groups[chapter]!.add(excerpt);
    }

    // 每个章节内的摘抄按时间排序（新的在前）
    for (final chapter in groups.keys) {
      groups[chapter]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return groups;
  }

  Widget _buildExcerptList() {
    final groups = _groupExcerptsByChapter();
    final chapters = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final excerpts = groups[chapter]!;
        return _buildChapterSection(chapter, excerpts);
      },
    );
  }

  Widget _buildChapterSection(String chapter, List<BookExcerpt> excerpts) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 章节标题
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            border: Border(
              left: BorderSide(color: colors.primary, width: 4),
            ),
          ),
          child: Text(
            chapter,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 该章节下的摘抄列表
        ...excerpts.map((excerpt) => _buildExcerptItem(excerpt)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExcerptItem(BookExcerpt excerpt) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 摘抄内容
          Text(
            excerpt.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface,
              height: 1.5,
            ),
          ),

          // 评论/感悟
          if (excerpt.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
              ),
              child: Text(
                excerpt.comment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 底部：时间 + 操作按钮
          Row(
            children: [
              Text(
                _formatDate(excerpt.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const Spacer(),
              // 编辑按钮
              GestureDetector(
                onTap: () => _navigateToEditExcerpt(excerpt),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 12),
              // 删除按钮
              GestureDetector(
                onTap: () => _showDeleteDialog(excerpt),
                child: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: colors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToAddExcerpt() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookExcerptFormPage(bookId: widget.book.id),
      ),
    ).then((_) => _loadExcerpts());
  }

  void _navigateToEditExcerpt(BookExcerpt excerpt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookExcerptFormPage(
          bookId: widget.book.id,
          excerpt: excerpt,
        ),
      ),
    ).then((_) => _loadExcerpts());
  }

  void _showDeleteDialog(BookExcerpt excerpt) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text('确认删除'),
          content: const Text('确定要删除这条摘抄吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () async {
                await context.read<AppProvider>().removeBookExcerpt(excerpt.id);
                Navigator.pop(context);
                _loadExcerpts();
                ToastUtil.show(context, '已删除');
              },
              child: Text('删除', style: TextStyle(color: colors.error)),
            ),
          ],
        );
      },
    );
  }
}
