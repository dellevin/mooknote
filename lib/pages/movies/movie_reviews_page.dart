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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索影评内容、评论人、来源...',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
                  border: InputBorder.none,
                ),
                style: TextStyle(color: colors.onSurface),
                onChanged: _onSearchChanged,
              )
            : const Text('影评'),
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddReview(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('添加影评'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReviews.isEmpty
              ? _buildEmptyState()
              : _buildReviewList(),
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
              Icons.rate_review_outlined,
              size: 40,
              color: colors.onSurface.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无影评',
            style: TextStyle(
              fontSize: 16,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => _navigateToAddReview(),
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
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _navigateToReviewDetail(review),
      onLongPress: () => _showDeleteDialog(review),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
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
                    ? colors.surface
                    : colors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                review.typeText,
                style: TextStyle(
                  fontSize: 10,
                  color: review.reviewType == 1
                      ? colors.onSurface.withValues(alpha: 0.6)
                      : colors.onPrimary,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // 评论内容
            Text(
              review.content,
              maxLines: review.reviewType == 1 ? 4 : 8,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface,
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
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.6),
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
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.onSurface.withValues(alpha: 0.4),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // 日期
                Text(
                  _formatDate(review.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: colors.onSurface.withValues(alpha: 0.4),
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
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('确定要删除这条影评吗？删除后可在回收站恢复。',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<AppProvider>().removeMovieReview(review.id);
                Navigator.pop(context);
                _loadReviews();
                ToastUtil.show(context, '已删除');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('删除'),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
    );
  }
}
