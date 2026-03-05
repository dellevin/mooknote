import 'dart:io';
import 'package:flutter/material.dart';
import '../models/data_models.dart';

/// 观影列表项 - 极简主义设计
class MovieListItem extends StatelessWidget {
  final Movie movie;

  const MovieListItem({super.key, required this.movie});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/movie-detail', arguments: movie),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报
            _buildPoster(),
            
            const SizedBox(width: 16),
            
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    movie.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // 年份和评分
                  _buildMetaInfo(),
                  
                  const SizedBox(height: 8),
                  
                  // 导演
                  if (movie.directors.isNotEmpty)
                    Text(
                      movie.directors.take(2).join(' / '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF999999),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // 状态
                  _buildStatusTag(),
                ],
              ),
            ),
            
            // 箭头
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }

  /// 海报
  Widget _buildPoster() {
    return Container(
      width: 56,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
          width: 0.5,
        ),
      ),
      child: movie.posterPath != null && movie.posterPath!.isNotEmpty
          ? Image.file(
              File(movie.posterPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        size: 20,
        color: Color(0xFFCCCCCC),
      ),
    );
  }

  /// 元信息
  Widget _buildMetaInfo() {
    final items = <String>[];
    
    if (movie.releaseDate != null) {
      items.add('${movie.releaseDate!.year}');
    }
    if (movie.rating != null) {
      items.add(movie.rating!.toStringAsFixed(1));
    }
    
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Row(
      children: items.asMap().entries.map((entry) {
        return Row(
          children: [
            Text(
              entry.value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
            if (entry.key < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  /// 状态标签
  Widget _buildStatusTag() {
    String label;
    Color color;
    
    switch (movie.status) {
      case 'watched':
        label = '已看';
        color = const Color(0xFF1A1A1A);
        break;
      case 'watching':
        label = '在看';
        color = const Color(0xFF666666);
        break;
      case 'want_to_watch':
        label = '想看';
        color = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        color = const Color(0xFFCCCCCC);
    }
    
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
