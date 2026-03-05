import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/app_theme.dart';

/// 影视详情页
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
    setState(() {
      _movie = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 海报区域（可折叠）
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildPosterSection(context),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                onPressed: () => _navigateToEdit(context),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                ),
                onPressed: () => _showDeleteDialog(context),
              ),
            ],
          ),

          // 内容区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题和状态
                  _buildTitleSection(context),
                  
                  const SizedBox(height: 20),
                  
                  // 基本信息
                  _buildBasicInfoSection(context),
                  
                  const SizedBox(height: 24),
                  
                  // 导演
                  if (_movie.directors.isNotEmpty) ...[
                    _buildListSection(context, '导演', _movie.directors, Icons.videocam_outlined),
                    const SizedBox(height: 20),
                  ],
                  
                  // 编剧
                  if (_movie.writers.isNotEmpty) ...[
                    _buildListSection(context, '编剧', _movie.writers, Icons.edit_note_outlined),
                    const SizedBox(height: 20),
                  ],
                  
                  // 主演
                  if (_movie.actors.isNotEmpty) ...[
                    _buildListSection(context, '主演', _movie.actors, Icons.people_outline),
                    const SizedBox(height: 20),
                  ],
                  
                  // 类型
                  if (_movie.genres.isNotEmpty) ...[
                    _buildGenreSection(context),
                    const SizedBox(height: 20),
                  ],
                  
                  // 别名
                  if (_movie.alternateTitles.isNotEmpty) ...[
                    _buildListSection(context, '别名', _movie.alternateTitles, Icons.alternate_email_outlined),
                    const SizedBox(height: 20),
                  ],
                  
                  // 剧情简介
                  if (_movie.summary != null && _movie.summary!.isNotEmpty) ...[
                    _buildSummarySection(context),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建海报区域
  Widget _buildPosterSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey[300],
      child: _movie.posterPath != null && _movie.posterPath!.isNotEmpty
          ? Image.file(
              File(_movie.posterPath!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie, size: 80, color: Colors.grey[500]),
            const SizedBox(height: 12),
            Text(
              '暂无海报',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建标题区域
  Widget _buildTitleSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态标签
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _getStatusText(),
            style: TextStyle(
              fontSize: 12,
              color: _getStatusColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 标题
        Text(
          _movie.title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// 构建基本信息区域
  Widget _buildBasicInfoSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 上映日期
          if (_movie.releaseDate != null) ...[
            Expanded(
              child: _buildInfoItem(
                context,
                icon: Icons.calendar_today_outlined,
                label: '上映日期',
                value: '${_movie.releaseDate!.year}.${_movie.releaseDate!.month.toString().padLeft(2, '0')}.${_movie.releaseDate!.day.toString().padLeft(2, '0')}',
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: colorScheme.outline.withOpacity(0.2),
            ),
          ],
          
          // 评分
          Expanded(
            child: _buildInfoItem(
              context,
              icon: Icons.star_rounded,
              label: '评分',
              value: _movie.rating != null ? '${_movie.rating!.toStringAsFixed(1)}' : '暂无',
              valueColor: _movie.rating != null ? Colors.amber[700] : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// 构建列表区块（导演、编剧、演员、别名）
  Widget _buildListSection(BuildContext context, String title, List<String> items, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.85),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  /// 构建类型区块
  Widget _buildGenreSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_movies_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '类型',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _movie.genres.map((genre) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              genre,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }

  /// 构建剧情简介区块
  Widget _buildSummarySection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.article_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '剧情简介',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _movie.summary!,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withOpacity(0.8),
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }

  /// 获取状态颜色
  Color _getStatusColor() {
    switch (_movie.status) {
      case 'watched':
        return AppTheme.watchedColor;
      case 'want_to_watch':
        return AppTheme.wantToWatchColor;
      case 'watching':
        return AppTheme.watchingColor;
      default:
        return Colors.grey;
    }
  }

  /// 获取状态文本
  String _getStatusText() {
    switch (_movie.status) {
      case 'watched':
        return '已看';
      case 'want_to_watch':
        return '想看';
      case 'watching':
        return '在看';
      default:
        return '未知';
    }
  }

  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/movie-form', arguments: _movie).then((_) {
      _refreshMovie();
      context.read<AppProvider>().loadMovies();
    });
  }

  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        content: Text(
          '确定要删除"${_movie.title}"吗？此操作不可恢复。',
          style: TextStyle(color: colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(_movie.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('已删除'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: colorScheme.primary,
                ),
              );
            },
            child: Text(
              '删除',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
