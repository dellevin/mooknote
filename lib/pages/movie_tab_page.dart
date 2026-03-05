import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../widgets/movie_status_bar.dart';
import '../widgets/movie_list_item.dart';

/// 观影标签页
class MovieTabPage extends StatelessWidget {
  const MovieTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 状态选择栏（已看、想看、在看）
        const MovieStatusBar(),
        
        // 影片列表
        Expanded(
          child: _buildMovieList(context),
        ),
      ],
    );
  }

  /// 构建影片列表
  Widget _buildMovieList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // 根据状态筛选影片
        final statusMap = {
          0: 'watched',
          1: 'want_to_watch',
          2: 'watching',
        };
        final currentStatus = statusMap[provider.movieStatusIndex]!;
        final movies = provider.getMoviesByStatus(currentStatus);
        
        if (movies.isEmpty) {
          return _buildEmptyState(context, provider.movieStatusIndex);
        }
        
        return RefreshIndicator(
          onRefresh: () async => await provider.loadMovies(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return MovieListItem(movie: movies[index]);
            },
          ),
        );
      },
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final statusText = ['已看', '想看', '在看'][statusIndex];
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_creation_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无$statusText的影片',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加记录'),
            onPressed: () {
              Navigator.pushNamed(context, '/movie-form');
            },
          ),
        ],
      ),
    );
  }
}
