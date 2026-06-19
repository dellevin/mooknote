import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../widgets/animated_star_rating.dart';
import '../widgets/fade_in_local_image.dart';
import 'movies/movie_detail_page.dart';
import 'book/book_detail_page.dart';
import 'note/note_detail_page.dart';

/// 漫步页面 - 随机发现内容（滑卡形式）
class StrollPage extends StatefulWidget {
  const StrollPage({super.key});

  @override
  State<StrollPage> createState() => _StrollPageState();
}

class _StrollPageState extends State<StrollPage> {
  final _random = Random();
  final List<_StrollItem> _items = [];
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _loadBatch(5);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadBatch(int count) {
    final provider = context.read<AppProvider>();
    final movies = provider.movies.where((m) => !m.isDeleted).toList();
    final books = provider.books.where((b) => !b.isDeleted).toList();
    final notes = provider.notes.where((n) => !n.isDeleted).toList();

    final categories = <String, List<dynamic>>{};
    if (movies.isNotEmpty) categories['movie'] = movies;
    if (books.isNotEmpty) categories['book'] = books;
    if (notes.isNotEmpty) categories['note'] = notes;

    if (categories.isEmpty) return;

    final categoryKeys = categories.keys.toList();
    for (int i = 0; i < count; i++) {
      final pickedCategory = categoryKeys[_random.nextInt(categoryKeys.length)];
      _StrollItem? item;
      switch (pickedCategory) {
        case 'movie':
          final m = movies[_random.nextInt(movies.length)];
          item = _StrollItem(
            type: 'movie', data: m,
            title: m.title,
            subtitle: m.alternateTitles.take(2).join(' / '),
            detail: _movieDetail(m),
            imagePath: m.posterPath,
            icon: Icons.movie_outlined, label: '影视',
            rating: m.rating, createdAt: m.createdAt,
            color: const Color(0xFF4A90D9),
          );
        case 'book':
          final b = books[_random.nextInt(books.length)];
          item = _StrollItem(
            type: 'book', data: b,
            title: b.title,
            subtitle: b.authors.take(2).join(' / '),
            detail: _bookDetail(b),
            imagePath: b.coverPath,
            icon: Icons.menu_book_outlined, label: '书籍',
            rating: b.rating, createdAt: b.createdAt,
            color: const Color(0xFF7E57C2),
          );
        case 'note':
          final n = notes[_random.nextInt(notes.length)];
          item = _StrollItem(
            type: 'note', data: n,
            title: n.title.isNotEmpty ? n.title : '随手记',
            subtitle: n.tags.take(3).join(' · '),
            detail: n.content,
            imagePath: n.images.isNotEmpty ? n.images.first : null,
            icon: Icons.note_outlined, label: '笔记',
            createdAt: n.createdAt,
            color: const Color(0xFF66BB6A),
          );
      }
      if (item != null) _items.add(item);
    }
  }

  void _reshuffle() {
    setState(() {
      _items.clear();
      _currentIndex = 0;
      _loadBatch(5);
    });
  }

  void _openDetail(_StrollItem item) {
    switch (item.type) {
      case 'movie':
        Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: item.data as Movie)));
      case 'book':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: item.data as Book)));
      case 'note':
        Navigator.push(context, MaterialPageRoute(builder: (_) => NoteDetailPage(note: item.data as Note)));
    }
  }

  String _movieDetail(Movie m) {
    final parts = <String>[];
    if (m.genres.isNotEmpty) parts.add(m.genres.take(3).join(' / '));
    if (m.summary != null && m.summary!.isNotEmpty) {
      parts.add(m.summary!.length > 80 ? '${m.summary!.substring(0, 80)}...' : m.summary!);
    }
    return parts.join('\n');
  }

  String _bookDetail(Book b) {
    final parts = <String>[];
    if (b.genres.isNotEmpty) parts.add(b.genres.take(3).join(' / '));
    if (b.publisher != null && b.publisher!.isNotEmpty) parts.add(b.publisher!);
    if (b.summary != null && b.summary!.isNotEmpty) {
      parts.add(b.summary!.length > 80 ? '${b.summary!.substring(0, 80)}...' : b.summary!);
    }
    return parts.join('\n');
  }

  String _timeAgoText(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}年前';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}个月前';
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    return '刚刚';
  }

  String _actionText(_StrollItem item) {
    final ago = _timeAgoText(item.createdAt);
    switch (item.type) {
      case 'movie': return '$ago 看过';
      case 'book': return '$ago 读过';
      case 'note': return '$ago 写下';
      default: return ago;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasContent = _items.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('漫步'),
        actions: [
          if (hasContent)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text('${_currentIndex + 1}/${_items.length}',
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _reshuffle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.casino_outlined, size: 14, color: colors.onPrimary),
                    const SizedBox(width: 5),
                    Text('随机', style: TextStyle(fontSize: 12, color: colors.onPrimary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: !hasContent
          ? Center(
              child: Text('还没有任何内容\n去添加一些吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.3), height: 1.6)))
          : PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                // 接近末尾时追加新条目
                if (index >= _items.length - 2) {
                  setState(() => _loadBatch(3));
                }
              },
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_pageController.hasClients && _pageController.page != null) {
                      final diff = (_pageController.page! - index).abs();
                      scale = (1 - diff * 0.1).clamp(0.85, 1.0);
                    }
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: _buildCard(_items[index], colors),
                );
              },
            ),
    );
  }

  Widget _buildCard(_StrollItem item, ColorScheme colors) {
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openDetail(item),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // 封面/图片区域
            if (hasImage)
              Expanded(
                flex: 5,
                child: SizedBox(
                  width: double.infinity,
                  child: FadeInLocalImage(path: item.imagePath, fit: BoxFit.cover),
                ),
              )
            else
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  color: colors.surfaceContainerHigh,
                  child: Center(child: Icon(item.icon, size: 56, color: item.color.withValues(alpha: 0.2))),
                ),
              ),

            // 内容区域
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 类型标签 + 评分
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: item.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(item.icon, size: 12, color: item.color),
                              const SizedBox(width: 4),
                              Text(item.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: item.color)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (item.rating != null)
                          AnimatedStarRating(rating: item.rating!, starSize: 14, showNumber: true),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 标题
                    Text(item.title,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.onSurface, height: 1.3)),

                    // 副标题
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
                    ],

                    const SizedBox(height: 8),

                    // 详情
                    if (item.detail.isNotEmpty)
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(item.detail, maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6), height: 1.7)),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // 时间 + 点击提示
                    Row(
                      children: [
                        Text(_actionText(item), style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.25))),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios, size: 12, color: colors.onSurface.withValues(alpha: 0.15)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrollItem {
  final String type;
  final dynamic data;
  final String title;
  final String subtitle;
  final String detail;
  final String? imagePath;
  final IconData icon;
  final String label;
  final double? rating;
  final DateTime createdAt;
  final Color color;

  _StrollItem({
    required this.type,
    required this.data,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.imagePath,
    required this.icon,
    required this.label,
    this.rating,
    required this.createdAt,
    required this.color,
  });
}
