import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 影视详情页 - 极简主义设计
class MovieDetailPage extends StatefulWidget {
  final Movie movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  late Movie _movie;

  @override
  void initState() {
    super.initState();
    _movie = widget.movie;
  }

  void _refreshMovie() {
    final provider = context.read<AppProvider>();
    final updated = provider.movies.firstWhere(
      (m) => m.id == _movie.id,
      orElse: () => _movie,
    );
    setState(() => _movie = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('详情'),
        actions: [
          TextButton(
            onPressed: () => _navigateToEdit(context),
            child: const Text('编辑'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报
            _buildPoster(),
            
            const SizedBox(height: 40),
            
            // 标题
            Text(
              _movie.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                height: 1.3,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 状态标签
            _buildStatusTag(),
            
            const SizedBox(height: 32),
            
            // 基本信息
            _buildInfoRow(),
            
            // 别名
            if (_movie.alternateTitles.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('别名'),
              const SizedBox(height: 12),
              _buildTextList(_movie.alternateTitles),
            ],
            
            // 导演
            if (_movie.directors.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('导演'),
              const SizedBox(height: 12),
              _buildTextList(_movie.directors),
            ],
            
            // 编剧
            if (_movie.writers.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('编剧'),
              const SizedBox(height: 12),
              _buildTextList(_movie.writers),
            ],
            
            // 主演
            if (_movie.actors.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('主演'),
              const SizedBox(height: 12),
              _buildTextList(_movie.actors),
            ],
            
            // 类型
            if (_movie.genres.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('类型'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _movie.genres.map((genre) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE5E5E5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    genre,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                  ),
                )).toList(),
              ),
            ],
            
            // 剧情简介
            if (_movie.summary != null && _movie.summary!.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionTitle('简介'),
              const SizedBox(height: 12),
              Text(
                _movie.summary!,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF666666),
                  height: 1.7,
                ),
              ),
            ],
            
            const SizedBox(height: 48),
            
            // 删除按钮
            Center(
              child: TextButton(
                onPressed: () => _showDeleteDialog(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                ),
                child: const Text('删除此影片'),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// 海报
  Widget _buildPoster() {
    return Center(
      child: Container(
        width: 140,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(
            color: const Color(0xFFE5E5E5),
            width: 0.5,
          ),
        ),
        child: _movie.posterPath != null && _movie.posterPath!.isNotEmpty
            ? Image.file(
                File(_movie.posterPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Text(
        '无海报',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF999999),
        ),
      ),
    );
  }

  /// 状态标签
  Widget _buildStatusTag() {
    String label;
    Color bgColor;
    Color textColor;
    
    switch (_movie.status) {
      case 'watched':
        label = '已看';
        bgColor = const Color(0xFF1A1A1A);
        textColor = Colors.white;
        break;
      case 'watching':
        label = '在看';
        bgColor = const Color(0xFF666666);
        textColor = Colors.white;
        break;
      case 'want_to_watch':
        label = '想看';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF666666);
        break;
      default:
        label = '未知';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF999999);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 基本信息行
  Widget _buildInfoRow() {
    final items = <String>[];
    
    if (_movie.releaseDate != null) {
      items.add('${_movie.releaseDate!.year}');
    }
    if (_movie.rating != null) {
      items.add('${_movie.rating!.toStringAsFixed(1)} 分');
    }
    
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Row(
      children: items.asMap().entries.map((entry) {
        return Row(
          children: [
            Text(
              entry.value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
            if (entry.key < items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ),
          ],
        );
      }).toList(),
    );
  }

  /// 区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF999999),
        letterSpacing: 1,
      ),
    );
  }

  /// 文本列表
  Widget _buildTextList(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => Text(
        item,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF333333),
        ),
      )).toList(),
    );
  }

  /// 跳转到编辑
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/movie-form', arguments: _movie).then((_) {
      _refreshMovie();
      context.read<AppProvider>().loadMovies();
    });
  }

  /// 删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          '确定要删除"${_movie.title}"吗？',
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(_movie.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFDC2626)),
            ),
          ),
        ],
      ),
    );
  }
}
