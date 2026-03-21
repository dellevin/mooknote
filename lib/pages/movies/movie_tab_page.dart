import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/movie_status_bar.dart';
import '../../widgets/movie_list_item.dart';

/// 观影标签页 - 极简主义设计
class MovieTabPage extends StatelessWidget {
  const MovieTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 状态选择栏
        const MovieStatusBar(),
        
        const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
        
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
        final statusMap = {
          0: 'watched',
          1: 'watching',
          2: 'want_to_watch',
        };
        final currentStatus = statusMap[provider.movieStatusIndex]!;
        final movies = provider.getMoviesByStatus(currentStatus);
        
        if (movies.isEmpty) {
          return _buildEmptyState(context, provider.movieStatusIndex);
        }
        
        return RefreshIndicator(
          onRefresh: () async => await provider.loadMovies(),
          color: const Color(0xFF1A1A1A),
          backgroundColor: Colors.white,
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: movies.length,
            itemBuilder: (context, index) {
              return MovieListItem(movie: movies[index]);
            },
          ),
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final statusText = ['已看', '在看', '想看'][statusIndex];
    
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
              Icons.movie_outlined,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无$statusText的影片',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              final statusMap = {
                0: 'watched',
                1: 'watching',
                2: 'want_to_watch',
              };
              final currentStatus = statusMap[statusIndex]!;
              Navigator.pushNamed(
                context,
                '/movie-form',
                arguments: {'initialStatus': currentStatus},
              );
            },
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
}
