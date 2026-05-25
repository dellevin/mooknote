import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/movie_status_bar.dart';
import '../../widgets/movie_list_item.dart';
import '../../widgets/animated_star_rating.dart';
import '../../widgets/shimmer_skeleton.dart';

/// 观影标签页
class MovieTabPage extends StatefulWidget {
  const MovieTabPage({super.key});

  @override
  State<MovieTabPage> createState() => _MovieTabPageState();
}

class _MovieTabPageState extends State<MovieTabPage> {
  int _layoutStyle = 0;
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().movieLayoutStyle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _firstLoad = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        const MovieStatusBar(),
        Divider(height: 0.5, thickness: 0.5, color: colors.outline),
        Expanded(
          child: _buildMovieList(context),
        ),
      ],
    );
  }

  Widget _buildMovieList(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final statusMap = {0: 'watched', 1: 'watching', 2: 'want_to_watch'};
        final currentStatus = statusMap[provider.movieStatusIndex]!;
        final allMovies = provider.movies.where((m) => !m.isDeleted).toList();
        if (_firstLoad && allMovies.isEmpty) {
          return _buildSkeleton();
        }
        _firstLoad = false;

        final movies = provider.getMoviesByStatus(currentStatus);

        if (movies.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => await provider.loadMovies(),
            color: colors.primary,
            backgroundColor: colors.surface,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [_buildEmptyState(context, provider.movieStatusIndex)],
            ),
          );
        }

        if (_layoutStyle == 1) {
          return _buildListView(movies, provider);
        }
        return _buildGridView(movies, provider);
      },
    );
  }

  Widget _buildGridView(List movies, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => await provider.loadMovies(),
      color: colors.primary,
      backgroundColor: colors.surface,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: movies.length,
        itemBuilder: (context, index) => MovieListItem(movie: movies[index]),
      ),
    );
  }

  Widget _buildListView(List movies, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => await provider.loadMovies(),
      color: colors.primary,
      backgroundColor: colors.surface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: movies.length,
        itemBuilder: (context, index) => _buildListCard(movies[index]),
      ),
    );
  }

  Widget _buildListCard(movie) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/movie-detail', arguments: movie),
      onLongPress: () => _showDeleteDialog(context, movie),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 64,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: movie.posterPath != null && movie.posterPath!.isNotEmpty
                  ? Image.file(File(movie.posterPath!), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.movie_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)))
                  : Icon(Icons.movie_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  if (movie.alternateTitles.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(movie.alternateTitles.take(2).join('、'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                  ],
                  const SizedBox(height: 6),
                  if (movie.rating != null)
                    AnimatedStarRating(rating: movie.rating!, starSize: 12, showNumber: true)
                  else
                    const SizedBox(height: 14),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, movie) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除《${movie.title}》吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(movie.id);
              Navigator.pop(ctx);
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
      ),
    );
  }

  Widget _buildSkeleton() {
    return _layoutStyle == 1 ? _buildListSkeleton() : const MovieSkeletonGrid();
  }

  Widget _buildListSkeleton() {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            ShimmerSkeleton(width: 48, height: 64, borderRadius: 6),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerSkeleton(width: 160, height: 16),
                  SizedBox(height: 6),
                  ShimmerSkeleton(width: 100, height: 12),
                  SizedBox(height: 6),
                  ShimmerSkeleton(width: 70, height: 12),
                ],
              ),
            ),
            SizedBox(width: 8),
            ShimmerSkeleton(width: 20, height: 20, borderRadius: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final colors = Theme.of(context).colorScheme;
    final statusText = ['已看', '在看', '想看'][statusIndex];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.movie_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          Text('暂无$statusText的影片', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              final statusMap = {0: 'watched', 1: 'watching', 2: 'want_to_watch'};
              Navigator.pushNamed(context, '/movie-form', arguments: {'initialStatus': statusMap[statusIndex]!});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(8)),
              child: Text('添加记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}
