import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../widgets/fade_in_local_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import 'movie_reviews_page.dart';
import 'movie_posters_page.dart';
import 'movie_share_page.dart';

/// 影视详情页 - 极简主义设计
class MovieDetailPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late bool _showExactDate;

  @override
  void initState() {
    super.initState();
    _showExactDate = UserPrefs().showExactReleaseDate;
  }

  void _toggleDateDisplay() {
    setState(() => _showExactDate = !_showExactDate);
    UserPrefs().setShowExactReleaseDate(_showExactDate);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final movie = context.watch<AppProvider>().movies
        .where((m) => m.id == widget.movie.id)
        .firstOrNull ?? widget.movie;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(movie),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfo(movie),
                    Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                    if (movie.directors.isNotEmpty)
                      _buildDirectorsSection(movie),
                    if (movie.writers.isNotEmpty)
                      _buildWritersSection(movie),
                    if (movie.actors.isNotEmpty)
                      _buildActorsSection(movie),
                    if (movie.genres.isNotEmpty)
                      _buildGenresSection(movie),
                    Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                    if (movie.summary != null && movie.summary!.isNotEmpty)
                      _buildSummarySection(movie),
                    Divider(height: 0.5, thickness: 0.5, color: colors.outline),
                    _buildExtraSections(movie),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(movie),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons(Movie movie) {
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
          onPressed: () => _showSharePoster(movie),
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

  Widget _buildSliverAppBar(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: colors.surfaceContainerHighest,
      leading: _buildBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildPosterSection(movie),
      ),
    );
  }

  Widget _buildPosterSection(Movie movie) {
    return SizedBox.expand(
      child: movie.posterPath != null && movie.posterPath!.isNotEmpty
          ? FadeInLocalImage(
              path: movie.posterPath,
              fit: BoxFit.cover,
            )
          : _buildPosterPlaceholder(),
    );
  }

  Widget _buildPosterPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: colors.onSurface.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无海报',
            style: TextStyle(
              fontSize: 14,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movie.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
              height: 1.3,
            ),
          ),
          if (movie.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              movie.alternateTitles.join(' / '),
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
              if (movie.rating != null) ...[
                Icon(
                  Icons.star,
                  size: 20,
                  color: colors.onSurface,
                ),
                const SizedBox(width: 4),
                Text(
                  movie.rating!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(movie),
            ],
          ),
          const SizedBox(height: 8),
          if (movie.releaseDate != null)
            GestureDetector(
              onTap: _toggleDateDisplay,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showExactDate
                        ? '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月${movie.releaseDate!.day.toString().padLeft(2, '0')}日上映'
                        : '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月上映',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.tune, size: 14, color: colors.onSurface.withValues(alpha: 0.2)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (movie.watchDate != null)
            Text(
              '观看于 ${_formatDate(movie.watchDate!)}',
              style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusTag(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    String label;
    Color bgColor;
    Color textColor;
    switch (movie.status) {
      case 'watched':
        label = '已看';
        bgColor = colors.primary;
        textColor = colors.onPrimary;
        break;
      case 'watching':
        label = '在看';
        bgColor = colors.outlineVariant;
        textColor = colors.onSurface.withValues(alpha: 0.6);
        break;
      case 'want_to_watch':
        label = '想看';
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

  Widget _buildDirectorsSection(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '导演',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.directors.join('，'),
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

  Widget _buildWritersSection(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '编剧',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.writers.join('，'),
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

  Widget _buildActorsSection(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              '主演',
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.actors.join('，'),
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

  Widget _buildGenresSection(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
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
              children: movie.genres.map((genre) {
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

  Widget _buildSummarySection(Movie movie) {
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
              movie.summary!,
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

  Widget _buildExtraSections(Movie movie) {
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
            title: '影评',
            subtitleFuture: context.read<AppProvider>().getMovieReviewCount(movie.id),
            emptyText: '暂无影评',
            unit: '条影评',
            onTap: () => _navigateToReviews(movie),
          ),
          const SizedBox(height: 12),
          _buildExtraSectionItem(
            icon: Icons.photo_library_outlined,
            title: '海报墙',
            subtitleFuture: context.read<AppProvider>().getMoviePosterCount(movie.id),
            emptyText: '暂无海报',
            unit: '张海报',
            onTap: () => _navigateToPosters(movie),
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

  void _navigateToReviews(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieReviewsPage(movie: movie),
      ),
    );
  }

  void _navigateToPosters(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoviePostersPage(movie: movie),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/movie-form', arguments: widget.movie).then((_) {
      context.read<AppProvider>().loadMovies();
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
          '确定要删除"${widget.movie.title}"吗？删除后可在回收站恢复。',
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
              await context.read<AppProvider>().removeMovie(widget.movie.id);
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

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        var status = await Permission.storage.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true;
  }

  Future<int> _getAndroidSdkInt() async {
    return 30;
  }

  void _showSharePoster(Movie movie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MovieSharePage(movie: movie),
      ),
    );
  }
}
