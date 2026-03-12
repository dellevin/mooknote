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
    return Scaffold(
      backgroundColor: Colors.white,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.format_quote_outlined,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无摘抄',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _navigateToAddExcerpt(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFF1A1A1A)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text('添加摘抄'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 章节标题
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            border: Border(
              left: BorderSide(color: Color(0xFF1A1A1A), width: 4),
            ),
          ),
          child: Text(
            chapter,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 摘抄内容
          Text(
            excerpt.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),

          // 评论/感悟
          if (excerpt.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
              ),
              child: Text(
                excerpt.comment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF666666),
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
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF999999),
                ),
              ),
              const Spacer(),
              // 编辑按钮
              GestureDetector(
                onTap: () => _navigateToEditExcerpt(excerpt),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF999999),
                ),
              ),
              const SizedBox(width: 12),
              // 删除按钮
              GestureDetector(
                onTap: () => _showDeleteDialog(excerpt),
                child: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.red,
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
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这条摘抄吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBookExcerpt(excerpt.id);
              Navigator.pop(context);
              _loadExcerpts();
              ToastUtil.show(context, '已删除');
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
