import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    // 页面获得焦点时刷新数据
    _refreshBookData();
  }

  void _refreshBookData() {
    final provider = context.read<AppProvider>();
    // 强制刷新当前书籍数据
    provider.loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    // 从 Provider 获取最新的 book 数据，实现动态刷新
    final book = context.watch<AppProvider>().books
        .where((b) => b.id == widget.book.id)
        .firstOrNull ?? widget.book;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 顶部封面区域
              _buildSliverAppBar(book),

              // 内容区域
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本信息
                    _buildBasicInfo(book),
                    
                    const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                    
                    // 作者信息
                    _buildAuthorsSection(book),

                    // 类型
                    if (book.genres.isNotEmpty)
                      _buildGenresSection(book),

                    // ISBN
                    if (book.isbn != null && book.isbn!.isNotEmpty)
                      _buildIsbnSection(book),

                    // 出版社
                    if (book.publisher != null && book.publisher!.isNotEmpty)
                      _buildPublisherSection(book),

                    // 出版时间
                    if (book.publishDate != null)
                      _buildPublishDateSection(book),
                    
                    const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                    
                    // 简介
                    if (book.summary != null && book.summary!.isNotEmpty)
                      _buildSummarySection(book),

                    const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),

                    // 书评和摘抄入口
                    _buildExtraSections(book),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          
          // 右下角悬浮按钮组
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(book),
          ),
        ],
      ),
    );
  }
  
  /// 构建右下角悬浮按钮组
  Widget _buildFloatingActionButtons(Book book) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 删除按钮
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: Colors.red,
        ),
        const SizedBox(height: 12),
        // 清空封面按钮（仅当有封面时显示）
        if (hasCover) ...[
          _buildFloatingButton(
            icon: Icons.hide_image_outlined,
            onPressed: () => _showClearCoverDialog(book),
            tooltip: '清空封面',
          ),
          const SizedBox(height: 12),
        ],
        // 编辑按钮
        _buildFloatingButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
        ),
        const SizedBox(height: 12),
        // 分享按钮
        _buildFloatingButton(
          icon: Icons.share_outlined,
          onPressed: () => _showSharePoster(book),
          tooltip: '分享海报',
          backgroundColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  /// 构建单个悬浮按钮
  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color backgroundColor = const Color(0xFF1A1A1A),
  }) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      mini: true,
      elevation: 4,
      child: Icon(icon, size: 20),
    );
  }

  /// 构建带背景的返回按钮
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

  /// 构建顶部 AppBar
  Widget _buildSliverAppBar(Book book) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFFF5F5F5),
      leading: _buildBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildCoverSection(book),
      ),
      // 右上角按钮已移到右下角悬浮按钮
    );
  }

  /// 构建封面区域
  Widget _buildCoverSection(Book book) {
    return SizedBox.expand(
      child: book.coverPath != null && book.coverPath!.isNotEmpty
          ? Image.file(
              File(book.coverPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
            )
          : _buildCoverPlaceholder(),
    );
  }
  
  Widget _buildCoverPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16),
          Text(
            '暂无封面',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建基本信息
  Widget _buildBasicInfo(Book book) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 书名
          Text(
            book.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),

          // 别名（显示在主名称下面，用 / 分隔）
          if (book.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              book.alternateTitles.join(' / '),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
                height: 1.4,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 评分和状态
          Row(
            children: [
              if (book.rating != null) ...[
                const Icon(
                  Icons.star,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 4),
                Text(
                  book.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(book),
            ],
          ),

          const SizedBox(height: 8),

          // 时间信息
          Text(
            '添加于 ${_formatDate(book.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建状态标签
  Widget _buildStatusTag(Book book) {
    String label;
    Color bgColor;
    Color textColor;
    switch (book.status) {
      case 'read':
        label = '已读';
        bgColor = const Color(0xFF1A1A1A);
        textColor = Colors.white;
        break;
      case 'reading':
        label = '在读';
        bgColor = const Color(0xFFF0F0F0);
        textColor = const Color(0xFF666666);
        break;
      case 'want_to_read':
        label = '想读';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        bgColor = const Color(0xFFEEEEEE);
        textColor = const Color(0xFFCCCCCC);
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
  
  /// 构建作者区域
  Widget _buildAuthorsSection(Book book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 64,
            child: Text(
              '作者',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.authors.join('，'),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建ISBN区域
  Widget _buildIsbnSection(Book book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 64,
            child: Text(
              'ISBN',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.isbn!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建出版社区域
  Widget _buildPublisherSection(Book book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 64,
            child: Text(
              '出版社',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              book.publisher!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建出版时间区域
  Widget _buildPublishDateSection(Book book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 64,
            child: Text(
              '出版时间',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${book.publishDate!.year}年${book.publishDate!.month.toString().padLeft(2, '0')}月',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类型区域
  Widget _buildGenresSection(Book book) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 64,
            child: Text(
              '类型',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
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
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    genre,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
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
  
  /// 构建简介区域
  Widget _buildSummarySection(Book book) {
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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '简介',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              book.summary!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建额外功能区域（书评、摘抄）
  Widget _buildExtraSections(Book book) {
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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '更多',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 书评入口
          _buildExtraSectionItem(
            icon: Icons.rate_review_outlined,
            title: '书评',
            subtitleFuture: context.read<AppProvider>().getBookReviewCount(book.id),
            emptyText: '暂无书评',
            unit: '条书评',
            onTap: () => _navigateToReviews(book),
          ),
          const SizedBox(height: 12),
          // 摘抄入口
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

  /// 构建更多区域项
  Widget _buildExtraSectionItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '$count $unit' : emptyText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
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


  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/book-form', arguments: widget.book).then((_) {
      context.read<AppProvider>().loadBooks();
    });
  }
  
  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要删除"${widget.book.title}"吗？删除后可在回收站恢复。',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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

  /// 显示清空封面对话框
  void _showClearCoverDialog(Book book) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '清空封面',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '确定要清空封面吗？清空后将使用默认占位图。',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final updatedBook = book.copyWith(
                coverPath: null,
                updatedAt: DateTime.now(),
              );
              await context.read<AppProvider>().updateBook(updatedBook);
              if (mounted) {
                ToastUtil.show(context, '封面已清空');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('清空'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// 下载封面到本地
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

      // 生成文件名：书籍名称_时间戳_封面.jpg
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${book.title}_${timestamp}_封面.jpg';

      // 获取临时目录路径
      final tempDir = await Directory.systemTemp.createTemp();
      final tempFile = File('${tempDir.path}/$fileName');
      await sourceFile.copy(tempFile.path);

      // 使用分享功能让用户选择保存位置
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '${book.title} 封面',
        text: '下载自 MookNote',
      );
    } catch (e) {
      ToastUtil.show(context, '下载失败: $e');
    }
  }

  /// 显示分享海报页面
  void _showSharePoster(Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookSharePage(book: book),
      ),
    );
  }
}
