import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/fade_in_local_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import 'book_reviews_page.dart';
import 'book_excerpts_page.dart';
import 'book_share_page.dart';

/// 书籍详情页 - 极简主义设计
class BookDetailPage extends StatefulWidget {
  final Book book;

  const BookDetailPage({super.key, required this.book});

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshBookData();
  }

  void _refreshBookData() {
    final provider = context.read<AppProvider>();
    provider.loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final book = context.watch<AppProvider>().books
        .where((b) => b.id == widget.book.id)
        .firstOrNull ?? widget.book;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(book),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfo(book),
                    Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                    _buildAuthorsSection(book),
                    if (book.genres.isNotEmpty)
                      _buildGenresSection(book),
                    if (book.isbn != null && book.isbn!.isNotEmpty)
                      _buildIsbnSection(book),
                    if (book.publisher != null && book.publisher!.isNotEmpty)
                      _buildPublisherSection(book),
                    if (book.publishDate != null)
                      _buildPublishDateSection(book),
                    Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                    if (book.summary != null && book.summary!.isNotEmpty)
                      _buildSummarySection(book),
                    Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                    _buildExtraSections(book),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(book),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.share_outlined,
          onPressed: () => _showSharePoster(book),
          tooltip: '分享海报',
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, size: 18, color: foregroundColor),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: tooltip,
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Book book) {
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: colors.surfaceContainerHighest,
      leading: _buildBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildCoverSection(book),
      ),
    );
  }

  Widget _buildCoverSection(Book book) {
    return SizedBox.expand(
      child: book.coverPath != null && book.coverPath!.isNotEmpty
          ? FadeInLocalImage(
              path: book.coverPath,
              fit: BoxFit.cover,
            )
          : _buildCoverPlaceholder(),
    );
  }

  Widget _buildCoverPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无封面',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              height: 1.3,
            ),
          ),
          if (book.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              book.alternateTitles.join(' / '),
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (book.rating != null) ...[
                Icon(
                  Icons.star,
                  size: 20,
                  color: colors.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  book.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(book),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '添加于 ${_formatDate(book.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(Book book) {
    final colors = Theme.of(context).colorScheme;
    String label;
    Color bgColor;
    Color textColor;
    switch (book.status) {
      case 'read':
        label = '已读';
        bgColor = colors.primary;
        textColor = colors.onPrimary;
        break;
      case 'reading':
        label = '在读';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.6);
        break;
      case 'want_to_read':
        label = '想读';
        bgColor = colors.surfaceContainerHighest;
        textColor = colors.onSurface.withValues(alpha: 0.4);
        break;
      default:
        label = '未知';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.25);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAuthorsSection(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '作者',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.authors.join('，'),
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIsbnSection(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              'ISBN',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.isbn!,
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublisherSection(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '出版社',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.publisher!,
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishDateSection(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '出版时间',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${book.publishDate!.year}年${book.publishDate!.month.toString().padLeft(2, '0')}月',
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenresSection(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '类型',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: book.genres.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '简介',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              book.summary!,
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurface,
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSections(Book book) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.onSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '更多',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildExtraSectionItem(
            icon: Icons.rate_review_outlined,
            title: '书评',
            subtitleFuture: context.read<AppProvider>().getBookReviewCount(book.id),
            emptyText: '暂无书评',
            unit: '条书评',
            onTap: () => _navigateToReviews(book),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.format_quote_outlined,
            title: '摘抄',
            subtitleFuture: context.read<AppProvider>().getBookExcerptCount(book.id),
            emptyText: '暂无摘抄',
            unit: '条摘抄',
            onTap: () => _navigateToExcerpts(book),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSectionItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              child: Icon(
                icon,
                size: 20,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '$count $unit' : emptyText,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToReviews(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReviewsPage(book: book),
      ),
    );
  }

  void _navigateToExcerpts(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookExcerptsPage(book: book),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/book-form', arguments: widget.book).then((_) {
      context.read<AppProvider>().loadBooks();
    });
  }

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          '确定要删除"${widget.book.title}"吗？删除后可在回收站恢复。',
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
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
              await context.read<AppProvider>().removeBook(widget.book.id);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _downloadCover(Book book) async {
    if (book.coverPath == null || book.coverPath!.isEmpty) {
      ToastUtil.show(context, '没有可下载的封面');
      return;
    }

    try {
      final sourceFile = File(book.coverPath!);
      if (!await sourceFile.exists()) {
        ToastUtil.show(context, '封面文件不存在');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${book.title}_${timestamp}_封面.jpg';

      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/$fileName');
      await sourceFile.copy(tempFile.path);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '${book.title} 封面',
        text: '下载自 MookNote',
      );
    } catch (e) {
      ToastUtil.show(context, '下载失败: $e');
    }
  }

  void _showSharePoster(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookSharePage(book: book),
      ),
    );
  }
}
