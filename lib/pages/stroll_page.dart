import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../widgets/animated_star_rating.dart';

/// 漫步页面 - 随机发现内容
class StrollPage extends StatefulWidget {
  const StrollPage({super.key});

  @override
  State<StrollPage> createState() => _StrollPageState();
}

class _StrollPageState extends State<StrollPage> with SingleTickerProviderStateMixin {
  final _random = Random();
  _StrollItem? _currentItem;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.value = 1.0;
    _loadRandom();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _loadRandom() {
    final provider = context.read<AppProvider>();
    final movies = provider.movies.where((m) => !m.isDeleted).toList();
    final books = provider.books.where((b) => !b.isDeleted).toList();
    final notes = provider.notes.where((n) => !n.isDeleted).toList();

    final categories = <String, List<dynamic>>{};
    if (movies.isNotEmpty) categories['movie'] = movies;
    if (books.isNotEmpty) categories['book'] = books;
    if (notes.isNotEmpty) categories['note'] = notes;

    if (categories.isEmpty) {
      setState(() => _currentItem = null);
      return;
    }

    final categoryKeys = categories.keys.toList();
    final pickedCategory = categoryKeys[_random.nextInt(categoryKeys.length)];

    _StrollItem item;
    switch (pickedCategory) {
      case 'movie':
        final m = movies[_random.nextInt(movies.length)];
        item = _StrollItem(
          type: 'movie',
          title: m.title,
          subtitle: m.alternateTitles.take(2).join(' / '),
          detail: _movieDetail(m),
          imagePath: m.posterPath,
          icon: Icons.movie_outlined,
          label: '影视',
          rating: m.rating,
          createdAt: m.createdAt,
          color: const Color(0xFF4A90D9),
        );
        break;
      case 'book':
        final b = books[_random.nextInt(books.length)];
        item = _StrollItem(
          type: 'book',
          title: b.title,
          subtitle: b.authors.take(2).join(' / '),
          detail: _bookDetail(b),
          imagePath: b.coverPath,
          icon: Icons.menu_book_outlined,
          label: '书籍',
          rating: b.rating,
          createdAt: b.createdAt,
          color: const Color(0xFF7E57C2),
        );
        break;
      case 'note':
        final n = notes[_random.nextInt(notes.length)];
        item = _StrollItem(
          type: 'note',
          title: n.title.isNotEmpty ? n.title : '随手记',
          subtitle: n.tags.take(3).join(' · '),
          detail: n.content,
          imagePath: n.images.isNotEmpty ? n.images.first : null,
          icon: Icons.note_outlined,
          label: '笔记',
          createdAt: n.createdAt,
          color: const Color(0xFF66BB6A),
        );
        break;
      default:
        setState(() => _currentItem = null);
        return;
    }

    setState(() => _currentItem = item);
  }

  void _refresh() async {
    setState(() => _isLoading = true);
    await _animController.reverse();
    _loadRandom();
    setState(() => _isLoading = false);
    _animController.forward();
  }

  String _movieDetail(Movie m) {
    final parts = <String>[];
    if (m.genres.isNotEmpty) parts.add(m.genres.take(3).join(' / '));
    if (m.summary != null && m.summary!.isNotEmpty) parts.add(m.summary!.length > 80 ? '${m.summary!.substring(0, 80)}...' : m.summary!);
    return parts.join('\n');
  }

  String _bookDetail(Book b) {
    final parts = <String>[];
    if (b.genres.isNotEmpty) parts.add(b.genres.take(3).join(' / '));
    if (b.publisher != null && b.publisher!.isNotEmpty) parts.add(b.publisher!);
    if (b.summary != null && b.summary!.isNotEmpty) parts.add(b.summary!.length > 80 ? '${b.summary!.substring(0, 80)}...' : b.summary!);
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('漫步'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _isLoading ? null : _refresh,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.casino_outlined, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text('随机', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _currentItem == null
          ? const Center(child: Text('还没有任何内容\n去添加一些吧', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB), height: 1.6)))
          : Consumer<AppProvider>(builder: (context, provider, _) {
              final item = _currentItem!;
              final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty && File(item.imagePath!).existsSync();

              return FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 类型标签
                        _buildTypeBadge(item),
                        const SizedBox(height: 24),

                        // 封面/图片
                        if (item.type != 'note')
                          _buildCoverCard(item, hasImage)
                        else
                          _buildNoteCard(item, hasImage),

                        const SizedBox(height: 24),

                        // 标题（笔记卡片已包含标题和内容，不需要重复）
                        if (item.type != 'note') ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A), height: 1.3),
                            ),
                          ),

                          if (item.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(item.subtitle, textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
                            ),
                          ],

                          // 评分
                          if (item.rating != null) ...[
                            const SizedBox(height: 10),
                            AnimatedStarRating(rating: item.rating!, starSize: 16, showNumber: true),
                          ],

                          // 详情
                          if (item.detail.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(item.detail,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF777777), height: 1.7)),
                            ),
                          ],
                        ],

                        // 时间
                        const SizedBox(height: 12),
                        Text(_actionText(item), style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC))),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              );
            }),
    );
  }

  Widget _buildTypeBadge(_StrollItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 14, color: item.color),
          const SizedBox(width: 5),
          Text(item.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.color)),
        ],
      ),
    );
  }

  Widget _buildCoverCard(_StrollItem item, bool hasImage) {
    return Container(
      width: 220,
      height: 290,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: item.color.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.file(File(item.imagePath!), fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(item))
          : _buildPlaceholder(item),
    );
  }

  Widget _buildNoteCard(_StrollItem item, bool hasImage) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasImage)
            Image.file(File(item.imagePath!), fit: BoxFit.cover, height: 200, width: double.infinity,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(item.detail.isEmpty ? '(无内容)' : item.detail,
                style: const TextStyle(fontSize: 14, color: Color(0xFF444444), height: 1.8)),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text('${item.detail.length} 字 · Mooknote', style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(_StrollItem item) {
    return Container(
      color: const Color(0xFFF8F8F8),
      child: Center(
        child: Icon(item.icon, size: 48, color: item.color.withValues(alpha: 0.2)),
      ),
    );
  }
}

class _StrollItem {
  final String type;
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
