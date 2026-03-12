import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import 'movie_review_form_page.dart';

/// 影评详情页
class MovieReviewDetailPage extends StatefulWidget {
  final MovieReview review;
  final String movieId;

  const MovieReviewDetailPage({
    super.key,
    required this.review,
    required this.movieId,
  });

  @override
  State<MovieReviewDetailPage> createState() => _MovieReviewDetailPageState();
}

class _MovieReviewDetailPageState extends State<MovieReviewDetailPage> {
  late MovieReview _review;

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
    final reviews = await provider.getMovieReviews(widget.movieId);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('影评详情'),
        actions: [
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _navigateToEdit(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 影评内容
            Text(
              _review.content,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1A1A),
                height: 1.8,
              ),
            ),

            const SizedBox(height: 32),

            // 分隔线
            Container(
              height: 0.5,
              color: const Color(0xFFE5E5E5),
            ),

            const SizedBox(height: 24),

            // 影评人
            _buildInfoRow(
              icon: Icons.person_outline,
              label: '影评人：',
              value: _review.reviewer.isNotEmpty ? _review.reviewer : '匿名',
            ),

            const SizedBox(height: 16),

            // 来源
            if (_review.source.isNotEmpty)
              _buildInfoRow(
                icon: Icons.source_outlined,
                label: '来源：',
                value: _review.source,
              ),

            if (_review.source.isNotEmpty) const SizedBox(height: 16),

            // 类型
            _buildInfoRow(
              icon: Icons.category_outlined,
              label: '类型：',
              value: _review.typeText,
            ),

            const SizedBox(height: 16),

            // 时间
            _buildInfoRow(
              icon: Icons.access_time,
              label: '时间：',
              value: _formatDate(_review.createdAt),
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
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFF999999),
        ),
        const SizedBox(width: 12),
        // 固定宽度容器，以"影评人："的最大宽度为准
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieReviewFormPage(
          movieId: widget.movieId,
          review: _review,
        ),
      ),
    ).then((_) => _refreshReviewData());
  }
}
