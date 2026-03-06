import 'dart:io';
import 'package:flutter/material.dart';
import '../models/data_models.dart';

/// 观影列表项组件 - 网格布局设计
class MovieListItem extends StatelessWidget {
  final Movie movie;

  const MovieListItem({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/movie-detail', arguments: movie);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报
          Expanded(
            child: _buildPoster(),
          ),

          const SizedBox(height: 8),

          // 影视名称
          Text(
            movie.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // 评分
          if (movie.rating != null)
            Row(
              children: [
                const Icon(
                  Icons.star,
                  size: 12,
                  color: Color(0xFFFFB800),
                ),
                const SizedBox(width: 2),
                Text(
                  movie.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  /// 构建海报
  Widget _buildPoster() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: movie.posterPath != null && movie.posterPath!.isNotEmpty
          ? Image.file(
              File(movie.posterPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPosterPlaceholder(),
            )
          : _buildPosterPlaceholder(),
    );
  }
  
  Widget _buildPosterPlaceholder() {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        size: 24,
        color: Color(0xFFCCCCCC),
      ),
    );
  }
  
}
