import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import 'movie_review_form_page.dart';

/// 影视影评列表页面
class MovieReviewsPage extends StatefulWidget {
  final Movie movie;

  const MovieReviewsPage({super.key, required this.movie});

  @override
  State<MovieReviewsPage> createState() => _MovieReviewsPageState();
}

class _MovieReviewsPageState extends State<MovieReviewsPage> {
  List<MovieReview> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    final reviews = await context.read<AppProvider>().getMovieReviews(widget.movie.id);
    setState(() {
      _reviews = reviews;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('影评'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToAddReview(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
              ? _buildEmptyState()
              : _buildReviewList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无影评',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _navigateToAddReview(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFF1A1A1A)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text('写影评'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return _buildReviewItem(review);
      },
    );
  }

  Widget _buildReviewItem(MovieReview review) {
    return InkWell(
      onLongPress: () => _showDeleteDialog(review),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：类型标签 + 操作按钮
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: review.reviewType == 1
                        ? const Color(0xFFF5F5F5)
                        : const Color(0xFF1A1A1A),
                  ),
                  child: Text(
                    review.typeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: review.reviewType == 1
                          ? const Color(0xFF666666)
                          : Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                // 编辑按钮
                GestureDetector(
                  onTap: () => _navigateToEditReview(review),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 16),
                // 删除按钮
                GestureDetector(
                  onTap: () => _showDeleteDialog(review),
                  child: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 评论内容
            Text(
              review.content,
              maxLines: review.reviewType == 1 ? 3 : 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.6,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 底部信息
            Row(
              children: [
                if (review.reviewer.isNotEmpty) ...[
                  Text(
                    review.reviewer,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (review.source.isNotEmpty) ...[
                  Text(
                    '来源：${review.source}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  _formatDate(review.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
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
        builder: (context) => MovieReviewFormPage(movieId: widget.movie.id),
      ),
    ).then((_) => _loadReviews());
  }

  void _navigateToEditReview(MovieReview review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieReviewFormPage(
          movieId: widget.movie.id,
          review: review,
        ),
      ),
    ).then((_) => _loadReviews());
  }

  void _showDeleteDialog(MovieReview review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这条影评吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovieReview(review.id);
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