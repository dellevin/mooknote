import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import 'book_review_form_page.dart';

/// 书评详情页
class BookReviewDetailPage extends StatefulWidget {
  final BookReview review;
  final String bookId;

  const BookReviewDetailPage({
    super.key,
    required this.review,
    required this.bookId,
  });

  @override
  State<BookReviewDetailPage> createState() => _BookReviewDetailPageState();
}

class _BookReviewDetailPageState extends State<BookReviewDetailPage> {
  late BookReview _review;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshReviewData();
  }

  Future<void> _refreshReviewData() async {
    final provider = context.read<AppProvider>();
    final reviews = await provider.getBookReviews(widget.bookId);
    final updatedReview = reviews
        .where((r) => r.id == widget.review.id)
        .firstOrNull;
    if (updatedReview != null && updatedReview.id == _review.id) {
      setState(() {
        _review = updatedReview;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('书评详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _navigateToEdit(context),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: colors.error.withValues(alpha: 0.7)),
            onPressed: _deleteReview,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 书评内容
            Text(
              _review.content,
              style: TextStyle(
                fontSize: 16,
                color: colors.onSurface,
                height: 1.8,
              ),
            ),

            const SizedBox(height: 32),

            // 分隔线
            Container(
              height: 0.5,
              color: colors.outline,
            ),

            const SizedBox(height: 24),

            // 书评人
            _buildInfoRow(
              icon: Icons.person_outline,
              label: '书评人：',
              value: _review.reviewer.isNotEmpty ? _review.reviewer : '匿名',
              colors: colors,
            ),

            const SizedBox(height: 16),

            // 来源
            if (_review.source.isNotEmpty)
              _buildInfoRow(
                icon: Icons.source_outlined,
                label: '来源：',
                value: _review.source,
                colors: colors,
              ),

            if (_review.source.isNotEmpty) const SizedBox(height: 16),

            // 类型
            _buildInfoRow(
              icon: Icons.category_outlined,
              label: '类型：',
              value: _review.typeText,
              colors: colors,
            ),

            const SizedBox(height: 16),

            // 时间
            _buildInfoRow(
              icon: Icons.access_time,
              label: '时间：',
              value: _formatDate(_review.createdAt),
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colors,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteReview() async {
    final colors = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除这条书评吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    if (confirmed == true) {
      await context.read<AppProvider>().removeBookReview(_review.id);
      if (mounted) { ToastUtil.show(context, '已删除'); Navigator.pop(context); }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReviewFormPage(
          bookId: widget.bookId,
          review: _review,
        ),
      ),
    ).then((_) => _refreshReviewData());
  }
}
