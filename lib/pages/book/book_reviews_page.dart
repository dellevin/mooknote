import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import 'book_review_form_page.dart';
import 'book_review_detail_page.dart';

/// 书籍书评列表页面
class BookReviewsPage extends StatefulWidget {
  final Book book;

  const BookReviewsPage({super.key, required this.book});

  @override
  State<BookReviewsPage> createState() => _BookReviewsPageState();
}

class _BookReviewsPageState extends State<BookReviewsPage> {
  List<BookReview> _reviews = [];
  List<BookReview> _filteredReviews = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final reviews = await context.read<AppProvider>().getBookReviews(widget.book.id);
    setState(() {
      _reviews = reviews;
      _filteredReviews = reviews;
      _isLoading = false;
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredReviews = _reviews;
      }
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredReviews = _reviews;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredReviews = _reviews.where((review) {
          return review.content.toLowerCase().contains(lowerQuery) ||
              review.reviewer.toLowerCase().contains(lowerQuery) ||
              review.source.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索书评内容、书评人、来源...',
                  hintStyle: TextStyle(color: Color(0xFF999999)),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                onChanged: _onSearchChanged,
              )
            : const Text('书评'),
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          // 添加按钮
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddReview(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReviews.isEmpty
              ? _buildEmptyState()
              : _buildReviewList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无书评',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => _navigateToAddReview(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '添加记录',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    return MasonryGridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(12),
      itemCount: _filteredReviews.length,
      itemBuilder: (context, index) {
        final review = _filteredReviews[index];
        return _buildReviewCard(review);
      },
    );
  }

  Widget _buildReviewCard(BookReview review) {
    return InkWell(
      onTap: () => _navigateToReviewDetail(review),
      onLongPress: () => _showDeleteDialog(review),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: review.reviewType == 1
                    ? Colors.white
                    : const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                review.typeText,
                style: TextStyle(
                  fontSize: 10,
                  color: review.reviewType == 1
                      ? const Color(0xFF666666)
                      : Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 评论内容
            Text(
              review.content,
              maxLines: review.reviewType == 1 ? 4 : 8,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            // 底部信息
            Row(
              children: [
                // 书评人
                if (review.reviewer.isNotEmpty)
                  Expanded(
                    child: Text(
                      review.reviewer,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF666666),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // 来源和日期一行
            Row(
              children: [
                // 来源
                if (review.source.isNotEmpty)
                  Expanded(
                    child: Text(
                      review.source,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF999999),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // 日期
                Text(
                  _formatDate(review.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToAddReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReviewFormPage(bookId: widget.book.id),
      ),
    ).then((_) => _loadReviews());
  }

  void _navigateToEditReview(BookReview review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReviewFormPage(
          bookId: widget.book.id,
          review: review,
        ),
      ),
    ).then((_) => _loadReviews());
  }

  void _navigateToReviewDetail(BookReview review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookReviewDetailPage(
          review: review,
          bookId: widget.book.id,
        ),
      ),
    ).then((_) => _loadReviews());
  }

  void _showDeleteDialog(BookReview review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这条书评吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBookReview(review.id);
              Navigator.pop(context);
              _loadReviews();
              ToastUtil.show(context, '已删除');
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
