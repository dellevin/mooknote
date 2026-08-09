import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/movie/movie_dao.dart';
import '../../data/book/book_dao.dart';
import '../../data/note/note_dao.dart';
import '../../data/game/game_dao.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../utils/image_saver.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../note/note_detail_page.dart';
import '../game/game_detail_page.dart';
import '../people/person_detail_page.dart';

/// 图库全屏预览页 —— 支持左右滑动、双指缩放、归属信息展示与跳转
class GalleryViewerPage extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;

  const GalleryViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<GalleryViewerPage> createState() => _GalleryViewerPageState();
}

class _GalleryViewerPageState extends State<GalleryViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _infoVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _buildInfoText(GalleryItem item) {
    if (item.parentTitle != null && item.parentTitle!.isNotEmpty) {
      return '来自：《${item.parentTitle}》— ${item.entityTitle}';
    }
    return '来自：《${item.entityTitle}》';
  }

  Future<void> _navigateToDetail(GalleryItem item) async {
    dynamic target;
    switch (item.entityType) {
      case 'movie':
        target = await MovieDao().getMovieById(item.entityId);
        break;
      case 'book':
        target = await BookDao().getBookById(item.entityId);
        break;
      case 'note':
        target = await NoteDao().getNoteById(item.entityId);
        break;
      case 'game':
        target = await GameDao().getGameById(item.entityId);
        break;
      case 'person':
        if (!mounted) return;
        target = await context.read<AppProvider>().getPersonById(item.entityId);
        break;
    }
    if (!mounted) return;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('原记录已不存在'), duration: Duration(seconds: 2)),
      );
      return;
    }
    Widget page;
    switch (item.entityType) {
      case 'movie':
        page = MovieDetailPage(movie: target as Movie);
        break;
      case 'book':
        page = BookDetailPage(book: target as Book);
        break;
      case 'note':
        page = NoteDetailPage(note: target as Note);
        break;
      case 'game':
        page = GameDetailPage(game: target as Game);
        break;
      case 'person':
        page = PersonDetailPage(person: target as Person);
        break;
      default:
        return;
    }
    Navigator.pop(context); // 关闭全屏预览
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 图片页面视图
          PageView.builder(
            controller: _pageController,
            itemCount: widget.items.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return GestureDetector(
                onTap: () => setState(() => _infoVisible = !_infoVisible),
                onLongPress: () => ImageSaver.showSaveFromFileSheet(item.path, context: context),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Center(
                    child: FadeInLocalImage(
                      path: item.path,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),

          // 顶部导航栏
          if (_infoVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${widget.items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),

          // 底部归属信息条
          if (_infoVisible)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: GestureDetector(
                  onTap: () => _navigateToDetail(widget.items[_currentIndex]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: Colors.white70, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _buildInfoText(widget.items[_currentIndex]),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 底部圆点指示器（图片较多时不显示，避免溢出）
          if (widget.items.length > 1 && widget.items.length <= 20 && _infoVisible)
            Positioned(
              bottom: 56,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.items.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
