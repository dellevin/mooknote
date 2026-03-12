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
      body: CustomScrollView(
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

                // 出版社
                if (book.publisher != null && book.publisher!.isNotEmpty)
                  _buildPublisherSection(book),

                // 类型
                if (book.genres.isNotEmpty)
                  _buildGenresSection(book),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 简介
                if (book.summary != null && book.summary!.isNotEmpty)
                  _buildSummarySection(book),

                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),

                // 书评和摘抄入口
                _buildExtraSections(book),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
      
      // 底部操作栏
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  /// 构建顶部 AppBar
  Widget _buildSliverAppBar(Book book) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFFF5F5F5),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildCoverSection(book),
      ),
      actions: [
        // 下载封面按钮（仅当有封面时显示）
        if (hasCover)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: IconButton(
              icon: const Icon(Icons.download_outlined, color: Color(0xFF666666)),
              onPressed: () => _downloadCover(book),
              tooltip: '下载封面',
            ),
          ),
        // 清空封面按钮（仅当有封面时显示）
        if (hasCover)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: IconButton(
              icon: const Icon(Icons.hide_image_outlined, color: Color(0xFF666666)),
              onPressed: () => _showClearCoverDialog(book),
              tooltip: '清空封面',
            ),
          ),
        // 编辑按钮
        Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A1A1A)),
            onPressed: () => _navigateToEdit(context),
          ),
        ),
        const SizedBox(width: 8),
      ],
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
    Color color;
    switch (book.status) {
      case 'read':
        label = '已读';
        color = const Color(0xFF1A1A1A);
        break;
      case 'reading':
        label = '在读';
        color = const Color(0xFF666666);
        break;
      case 'want_to_read':
        label = '想读';
        color = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        color = const Color(0xFFCCCCCC);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// 构建作者区域
  Widget _buildAuthorsSection(Book book) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '作者',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: book.authors.map((author) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  author,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建出版社区域
  Widget _buildPublisherSection(Book book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出版社',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.publisher!,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建类型区域
  Widget _buildGenresSection(Book book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '类型',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: book.genres.map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E5E5)),
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
          const Text(
            '简介',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            book.summary!,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              height: 1.6,
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
          const Text(
            '更多',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          // 书评入口
          GestureDetector(
            onTap: () => _navigateToReviews(book),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.rate_review_outlined,
                    size: 24,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '书评',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<int>(
                          future: context.read<AppProvider>().getBookReviewCount(book.id),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Text(
                              count > 0 ? '$count 条书评' : '暂无书评',
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
                    color: Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 摘抄入口
          GestureDetector(
            onTap: () => _navigateToExcerpts(book),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.format_quote_outlined,
                    size: 24,
                    color: Color(0xFF666666),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '摘抄',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FutureBuilder<int>(
                          future: context.read<AppProvider>().getBookExcerptCount(book.id),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            return Text(
                              count > 0 ? '$count 条摘抄' : '暂无摘抄',
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
                    color: Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ),
        ],
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

  /// 构建底部操作栏
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _navigateToEdit(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFF1A1A1A)),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showDeleteDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: Text('确定要删除"${widget.book.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(widget.book.id);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('清空封面'),
        content: const Text('确定要清空封面吗？清空后将使用默认占位图。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
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
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
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
}
