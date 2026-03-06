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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 顶部海报区域
          _buildSliverAppBar(),
          
          // 内容区域
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息
                _buildBasicInfo(),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 导演
                if (widget.movie.directors.isNotEmpty)
                  _buildDirectorsSection(),
                
                // 编剧
                if (widget.movie.writers.isNotEmpty)
                  _buildWritersSection(),
                
                // 主演
                if (widget.movie.actors.isNotEmpty)
                  _buildActorsSection(),
                
                // 类型
                if (widget.movie.genres.isNotEmpty)
                  _buildGenresSection(),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 简介
                if (widget.movie.summary != null && widget.movie.summary!.isNotEmpty)
                  _buildSummarySection(),
                
                // 别名
                if (widget.movie.alternateTitles.isNotEmpty)
                  _buildAlternateTitlesSection(),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
      
      // 底部操作栏
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  /// 构建顶部 AppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildPosterSection(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _navigateToEdit(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
  
  /// 构建海报区域
  Widget _buildPosterSection() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      child: widget.movie.posterPath != null && widget.movie.posterPath!.isNotEmpty
          ? Image.file(
              File(widget.movie.posterPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildPosterPlaceholder(),
            )
          : _buildPosterPlaceholder(),
    );
  }
  
  Widget _buildPosterPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_outlined,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16),
          Text(
            '暂无海报',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建基本信息
  Widget _buildBasicInfo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 影视名称
          Text(
            widget.movie.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 评分和状态
          Row(
            children: [
              if (widget.movie.rating != null) ...[
                const Icon(
                  Icons.star,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.movie.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 上映日期
          if (widget.movie.releaseDate != null)
            Text(
              '${widget.movie.releaseDate!.year}年上映',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
          
          const SizedBox(height: 8),
          
          // 时间信息
          Text(
            '添加于 ${_formatDate(widget.movie.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建状态标签
  Widget _buildStatusTag() {
    String label;
    Color color;
    switch (widget.movie.status) {
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
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// 构建导演区域
  Widget _buildDirectorsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '导演',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.movie.directors.map((director) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  director,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建编剧区域
  Widget _buildWritersSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '编剧',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.movie.writers.map((writer) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  writer,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建主演区域
  Widget _buildActorsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '主演',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.movie.actors.map((actor) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  actor,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建类型区域
  Widget _buildGenresSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '类型',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.movie.genres.map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建简介区域
  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '简介',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.movie.summary!,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建别名区域
  Widget _buildAlternateTitlesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '别名',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.movie.alternateTitles.map((title) {
              return Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建底部操作栏
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _navigateToEdit(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFF1A1A1A)),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showDeleteDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/movie-form', arguments: widget.movie).then((_) {
      context.read<AppProvider>().loadMovies();
    });
  }
  
  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: Text('确定要删除"${widget.movie.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(widget.movie.id);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
