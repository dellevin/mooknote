import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import 'movie_review_form_page.dart';
import 'movie_review_detail_page.dart';

/// 影视影评列表页面
class MovieReviewsPage extends StatefulWidget {
  final Movie movie;

  const MovieReviewsPage({super.key, required this.movie});

  @override
  State<MovieReviewsPage> createState() => _MovieReviewsPageState();
}

class _MovieReviewsPageState extends State<MovieReviewsPage> {
  List<MovieReview> _reviews = [];
  List<MovieReview> _filteredReviews = [];
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
    final reviews = await context.read<AppProvider>().getMovieReviews(widget.movie.id);
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
                  hintText: '搜索影评内容、评论人、来源...',
                  hintStyle: TextStyle(color: Color(0xFF999999)),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Color(0xFF1A1A1A)),
                onChanged: _onSearchChanged,
              )
            : const Text('影评'),
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

  Widget _buildReviewCard(MovieReview review) {
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
                // 评论人
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

  void _navigateToReviewDetail(MovieReview review) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieReviewDetailPage(
          review: review,
          movieId: widget.movie.id,
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