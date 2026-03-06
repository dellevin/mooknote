import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

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
          const Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无海报',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _pickPoster,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFF1A1A1A)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: const Text('添加海报'),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _posters.length,
      itemBuilder: (context, index) {
        final poster = _posters[index];
        return _buildPosterItem(poster);
      },
    );
  }

  Widget _buildPosterItem(MoviePoster poster) {
    return GestureDetector(
      onTap: () => _showPosterDetail(poster),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
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
            // 删除按钮
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _showDeleteDialog(poster),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPosterDetail(MoviePoster poster) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Image.file(
              File(poster.posterPath),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPoster() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'movie_poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'movie_posters', fileName);

        final posterDir = Directory(path.join(appDir.path, 'movie_posters'));
        if (!await posterDir.exists()) {
          await posterDir.create(recursive: true);
        }

        await File(pickedFile.path).copy(savedPath);

        final newPoster = MoviePoster(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          movieId: widget.movie.id,
          posterPath: savedPath,
          createdAt: DateTime.now(),
        );

        await context.read<AppProvider>().addMoviePoster(newPoster);
        _loadPosters();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('添加成功')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加海报失败: $e')),
        );
      }
    }
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
