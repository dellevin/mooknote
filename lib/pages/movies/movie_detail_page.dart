import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import 'movie_reviews_page.dart';
import 'movie_posters_page.dart';

/// 影视详情页 - 极简主义设计
class MovieDetailPage extends StatefulWidget {
  final Movie movie;
  
  const MovieDetailPage({super.key, required this.movie});
  
  @override
  State<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends State<MovieDetailPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 页面获得焦点时刷新数据
    _refreshMovieData();
  }
  
  void _refreshMovieData() {
    final provider = context.read<AppProvider>();
    // 强制刷新当前影视数据
    provider.loadMovies();
  }
  
  @override
  Widget build(BuildContext context) {
    // 从 Provider 获取最新的 movie 数据，实现动态刷新
    final movie = context.watch<AppProvider>().movies
        .where((m) => m.id == widget.movie.id)
        .firstOrNull ?? widget.movie;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 顶部海报区域
          _buildSliverAppBar(movie),
          
          // 内容区域
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息
                _buildBasicInfo(movie),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 导演
                if (movie.directors.isNotEmpty)
                  _buildDirectorsSection(movie),
                
                // 编剧
                if (movie.writers.isNotEmpty)
                  _buildWritersSection(movie),
                
                // 主演
                if (movie.actors.isNotEmpty)
                  _buildActorsSection(movie),
                
                // 类型
                if (movie.genres.isNotEmpty)
                  _buildGenresSection(movie),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 简介
                if (movie.summary != null && movie.summary!.isNotEmpty)
                  _buildSummarySection(movie),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 影评和海报墙入口
                _buildExtraSections(movie),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
      
      // 底部无操作栏，编辑和删除在右上角
    );
  }
  
  /// 构建右上角操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color color = const Color(0xFF666666),
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建带背景的返回按钮
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

  /// 构建顶部 AppBar
  Widget _buildSliverAppBar(Movie movie) {
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
    
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      backgroundColor: const Color(0xFFF5F5F5),
      leading: _buildBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildPosterSection(movie),
      ),
      actions: [
        // 下载海报按钮（仅当有海报时显示）
        if (hasPoster)
          _buildActionButton(
            icon: Icons.download_outlined,
            onPressed: () => _downloadPoster(movie),
            tooltip: '下载海报',
          ),
        // 清空海报按钮（仅当有海报时显示）
        if (hasPoster)
          _buildActionButton(
            icon: Icons.hide_image_outlined,
            onPressed: () => _showClearPosterDialog(movie),
            tooltip: '清空海报',
          ),
        // 编辑按钮
        _buildActionButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
        ),
        // 删除按钮
        _buildActionButton(
          icon: Icons.delete_outline,
          color: Colors.red,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
  
  /// 构建海报区域
  Widget _buildPosterSection(Movie movie) {
    return SizedBox.expand(
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
  
  /// 显示清空海报对话框
  void _showClearPosterDialog(Movie movie) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '清空海报',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '确定要清空海报吗？清空后将使用默认占位图。',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final updatedMovie = movie.copyWith(
                posterPath: null,
                updatedAt: DateTime.now(),
              );
              await context.read<AppProvider>().updateMovie(updatedMovie);
              if (mounted) {
                ToastUtil.show(context, '海报已清空');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('清空'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
  
  /// 构建基本信息
  Widget _buildBasicInfo(Movie movie) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 影视名称
          Text(
            movie.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),
          
          // 别名（显示在主名称下面，用 / 分隔）
          if (movie.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              movie.alternateTitles.join(' / '),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
                height: 1.4,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // 评分和状态
          Row(
            children: [
              if (movie.rating != null) ...[
                const Icon(
                  Icons.star,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 4),
                Text(
                  movie.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(movie),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 上映日期
          if (movie.releaseDate != null)
            Text(
              '${movie.releaseDate!.year}年${movie.releaseDate!.month.toString().padLeft(2, '0')}月上映',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),

          const SizedBox(height: 8),

          // 观看日期
          if (movie.watchDate != null)
            Text(
              '观看于 ${_formatDate(movie.watchDate!)}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
            ),
        ],
      ),
    );
  }
  
  /// 构建状态标签
  Widget _buildStatusTag(Movie movie) {
    String label;
    Color bgColor;
    Color textColor;
    switch (movie.status) {
      case 'watched':
        label = '已看';
        bgColor = const Color(0xFF1A1A1A);
        textColor = Colors.white;
        break;
      case 'watching':
        label = '在看';
        bgColor = const Color(0xFFF0F0F0);
        textColor = const Color(0xFF666666);
        break;
      case 'want_to_watch':
        label = '想看';
        bgColor = const Color(0xFFF5F5F5);
        textColor = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        bgColor = const Color(0xFFEEEEEE);
        textColor = const Color(0xFFCCCCCC);
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
  
  /// 构建导演区域
  Widget _buildDirectorsSection(Movie movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 48,
            child: Text(
              '导演',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.directors.join('，'),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建编剧区域
  Widget _buildWritersSection(Movie movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 48,
            child: Text(
              '编剧',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.writers.join('，'),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建主演区域
  Widget _buildActorsSection(Movie movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 48,
            child: Text(
              '主演',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ),
          Expanded(
            child: Text(
              movie.actors.join('，'),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类型区域
  Widget _buildGenresSection(Movie movie) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 48,
            child: Text(
              '类型',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
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
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
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
          ),
        ],
      ),
    );
  }
  
  /// 构建简介区域
  Widget _buildSummarySection(Movie movie) {
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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '简介',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              movie.summary!,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建额外功能区域（影评、海报墙）
  Widget _buildExtraSections(Movie movie) {
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
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '更多',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 影评入口
          _buildExtraSectionItem(
            icon: Icons.rate_review_outlined,
            title: '影评',
            subtitleFuture: context.read<AppProvider>().getMovieReviewCount(movie.id),
            emptyText: '暂无影评',
            unit: '条影评',
            onTap: () => _navigateToReviews(movie),
          ),
          const SizedBox(height: 12),
          // 海报墙入口
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

  /// 构建更多区域项
  Widget _buildExtraSectionItem({
    required IconData icon,
    required String title,
    required Future<int> subtitleFuture,
    required String emptyText,
    required String unit,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              child: Icon(
                icon,
                size: 20,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<int>(
                    future: subtitleFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Text(
                        count > 0 ? '$count $unit' : emptyText,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要删除"${widget.movie.title}"吗？删除后可在回收站恢复。',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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
  
  /// 下载海报到本地
  Future<void> _downloadPoster(Movie movie) async {
    if (movie.posterPath == null || movie.posterPath!.isEmpty) {
      ToastUtil.show(context, '没有可下载的海报');
      return;
    }
    
    try {
      final sourceFile = File(movie.posterPath!);
      if (!await sourceFile.exists()) {
        ToastUtil.show(context, '海报文件不存在');
        return;
      }
      
      // 生成文件名：影视名称_时间戳_海报.扩展名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${movie.title}_${timestamp}_海报${path.extension(movie.posterPath!)}';
      
      // 复制到临时目录
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, fileName));
      await sourceFile.copy(tempFile.path);
      
      // 使用分享功能让用户选择保存位置
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        subject: '${movie.title} 海报',
        text: '下载自 MookNote',
      );
    } catch (e) {
      ToastUtil.show(context, '下载失败: $e');
    }
  }
  
  /// 请求存储权限
  Future<bool> _requestStoragePermission() async {
    // Android 13+ 使用新的权限
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= 33) {
        // Android 13+ 使用 READ_MEDIA_IMAGES
        final status = await Permission.photos.request();
        return status.isGranted;
      } else {
        // Android 12 及以下使用存储权限
        var status = await Permission.storage.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    // iOS 不需要额外权限来保存到应用沙盒
    return true;
  }
  
  /// 获取 Android SDK 版本
  Future<int> _getAndroidSdkInt() async {
    // 简化处理，实际可以通过 platform channel 获取
    // 这里默认返回较低版本，使用传统存储权限
    return 30;
  }
}
