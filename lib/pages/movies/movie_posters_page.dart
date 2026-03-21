import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import 'poster_gallery_page.dart';

/// 影视海报墙页面
class MoviePostersPage extends StatefulWidget {
  final Movie movie;

  const MoviePostersPage({super.key, required this.movie});

  @override
  State<MoviePostersPage> createState() => _MoviePostersPageState();
}

class _MoviePostersPageState extends State<MoviePostersPage> {
  final ImagePicker _picker = ImagePicker();
  List<MoviePoster> _posters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosters();
  }

  Future<void> _loadPosters() async {
    setState(() => _isLoading = true);
    final posters = await context.read<AppProvider>().getMoviePosters(widget.movie.id);
    setState(() {
      _posters = posters;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('海报墙'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate),
            onPressed: _pickPoster,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posters.isEmpty
              ? _buildEmptyState()
              : _buildPosterGrid(),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.photo_library_outlined,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无海报',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _pickPoster,
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

  Widget _buildPosterGrid() {
    return MasonryGridView.count(
      padding: const EdgeInsets.all(16),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _posters.length,
      itemBuilder: (context, index) {
        final poster = _posters[index];
        return _buildPosterItem(poster, index);
      },
    );
  }

  Widget _buildPosterItem(MoviePoster poster, int index) {
    // 根据索引生成不同的高度，实现瀑布流效果
    final heights = [180.0, 220.0, 160.0, 200.0, 240.0, 190.0];
    final height = heights[index % heights.length];
    
    return GestureDetector(
      onTap: () => _showPosterDetail(poster),
      onLongPress: () => _showDeleteDialog(poster),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 海报图片
              Image.file(
                File(poster.posterPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ),
              // 渐变遮罩（底部）
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPosterDetail(MoviePoster poster) {
    // 找到当前海报的索引
    final initialIndex = _posters.indexWhere((p) => p.id == poster.id);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PosterGalleryPage(
          posters: _posters,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  Future<void> _pickPoster() async {
    // 显示选择对话框
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      '添加海报',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 从相册选择
              _buildAddOption(
                icon: Icons.photo_library_outlined,
                title: '从相册选择',
                subtitle: '选择本地图片',
                onTap: () => Navigator.pop(context, 0),
              ),
              // 网络链接
              _buildAddOption(
                icon: Icons.link_outlined,
                title: '网络链接',
                subtitle: '输入图片URL地址',
                onTap: () => Navigator.pop(context, 1),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    if (result == 0) {
      await _pickFromGallery();
    } else if (result == 1) {
      await _pickFromUrl();
    }
  }

  /// 从相册选择
  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // 生成文件名
        final fileName = 'posterimg_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // 保存到 posterimgs 子目录: images/movies/{movieId}/posterimgs/{fileName}
        final targetPath = await ImagePathHelper.instance.getMoviePosterImgPath(
          widget.movie.id, 
          fileName
        );
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));

        await File(pickedFile.path).copy(targetPath);

        final newPoster = MoviePoster(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          movieId: widget.movie.id,
          posterPath: targetPath,
          createdAt: DateTime.now(),
        );

        await context.read<AppProvider>().addMoviePoster(newPoster);
        _loadPosters();

        if (mounted) {
          ToastUtil.show(context, '添加成功');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '添加海报失败: $e');
      }
    }
  }

  /// 从网络链接添加
  Future<void> _pickFromUrl() async {
    final urlController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('添加网络图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请输入图片链接地址',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/image.jpg',
                hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                border: UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE5E5E5)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1A1A1A)),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final url = urlController.text.trim();
    if (url.isEmpty) {
      ToastUtil.show(context, '请输入图片链接');
      return;
    }

    try {
      // 下载网络图片
      await _downloadAndSavePoster(url);
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '添加失败: $e');
      }
    }
  }

  /// 下载网络图片并保存
  Future<void> _downloadAndSavePoster(String url) async {
    try {
      // 使用 http 下载图片，添加请求头模拟浏览器
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      // 检查内容类型
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) {
        throw Exception('链接返回的不是图片，可能是网页或需要登录');
      }

      // 检查文件大小（最大 10MB）
      if (response.bodyBytes.length > 10 * 1024 * 1024) {
        throw Exception('图片太大，请使用小于 10MB 的图片');
      }

      // 生成文件名
      final fileName = 'posterimg_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 保存到 posterimgs 子目录
      final targetPath = await ImagePathHelper.instance.getMoviePosterImgPath(
        widget.movie.id, 
        fileName
      );
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));

      // 写入文件
      await File(targetPath).writeAsBytes(response.bodyBytes);

      final newPoster = MoviePoster(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        movieId: widget.movie.id,
        posterPath: targetPath,
        createdAt: DateTime.now(),
      );

      await context.read<AppProvider>().addMoviePoster(newPoster);
      _loadPosters();

      if (mounted) {
        ToastUtil.show(context, '添加成功');
      }
    } catch (e) {
      throw Exception('下载图片失败: $e');
    }
  }

  /// 构建添加选项
  Widget _buildAddOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(MoviePoster poster) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这张海报吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMoviePoster(poster.id);
              Navigator.pop(context);
              _loadPosters();
              ToastUtil.show(context, '已删除');
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
