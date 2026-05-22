import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 漫步页面 - 随机发现一条内容
class StrollPage extends StatefulWidget {
  const StrollPage({super.key});

  @override
  State<StrollPage> createState() => _StrollPageState();
}

class _StrollPageState extends State<StrollPage> {
  final _random = Random();
  _StrollItem? _currentItem;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final provider = context.read<AppProvider>();

    // 按类别分组
    final movies = provider.movies.where((m) => !m.isDeleted).toList();
    final books = provider.books.where((b) => !b.isDeleted).toList();
    final notes = provider.notes.where((n) => !n.isDeleted).toList();

    // 收集非空类别
    final categories = <String, List<dynamic>>{};
    if (movies.isNotEmpty) categories['movie'] = movies;
    if (books.isNotEmpty) categories['book'] = books;
    if (notes.isNotEmpty) categories['note'] = notes;

    if (categories.isEmpty) {
      setState(() => _currentItem = null);
      return;
    }

    // 先等概率选类别，再从该类中随机选一条
    final categoryKeys = categories.keys.toList();
    final pickedCategory = categoryKeys[_random.nextInt(categoryKeys.length)];

    _StrollItem item;
    switch (pickedCategory) {
      case 'movie':
        final m = movies[_random.nextInt(movies.length)];
        item = _StrollItem(
          type: 'movie',
          title: m.title,
          subtitle: m.alternateTitles.isNotEmpty ? m.alternateTitles.first : '',
          detail: _buildMovieDetail(m),
          imagePath: m.posterPath,
          icon: Icons.movie_outlined,
          label: '影视',
          createdAt: m.createdAt,
        );
        break;
      case 'book':
        final b = books[_random.nextInt(books.length)];
        item = _StrollItem(
          type: 'book',
          title: b.title,
          subtitle: b.authors.isNotEmpty ? b.authors.first : '',
          detail: _buildBookDetail(b),
          imagePath: b.coverPath,
          icon: Icons.menu_book_outlined,
          label: '书籍',
          createdAt: b.createdAt,
        );
        break;
      case 'note':
        final n = notes[_random.nextInt(notes.length)];
        item = _StrollItem(
          type: 'note',
          title: n.title.isNotEmpty ? n.title : '无标题',
          subtitle: '${n.content.length} 字 · ${n.tags.isNotEmpty ? n.tags.take(2).join(' / ') : '无标签'}',
          detail: n.content,
          imagePath: n.images.isNotEmpty ? n.images.first : null,
          icon: Icons.note_outlined,
          label: '笔记',
          createdAt: n.createdAt,
        );
        break;
      default:
        setState(() => _currentItem = null);
        return;
    }

    setState(() => _currentItem = item);
  }

  String _buildMovieDetail(Movie m) {
    final parts = <String>[];
    if (m.rating != null && m.rating! > 0) parts.add('评分 ${m.rating!.toStringAsFixed(1)}');
    if (m.genres.isNotEmpty) parts.add(m.genres.take(3).join(' / '));
    if (m.status == 'watched') parts.add('已看');
    if (m.status == 'watching') parts.add('在看');
    return parts.join(' · ');
  }

  String _buildBookDetail(Book b) {
    final parts = <String>[];
    if (b.rating != null && b.rating! > 0) parts.add('评分 ${b.rating!.toStringAsFixed(1)}');
    if (b.publisher != null && b.publisher!.isNotEmpty) parts.add(b.publisher!);
    if (b.status == 'read') parts.add('已读');
    if (b.status == 'reading') parts.add('在读');
    return parts.join(' · ');
  }

  String _getTimeAgoText(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 365) return '1年前';
    if (diff.inDays >= 180) return '6个月前';
    if (diff.inDays >= 90) return '3个月前';
    if (diff.inDays >= 30) return '1个月前';
    return '${diff.inDays}天前';
  }

  String _getActionTimeAgo(_StrollItem item) {
    final timeAgo = _getTimeAgoText(item.createdAt);
    switch (item.type) {
      case 'movie':
        return '${timeAgo}看过';
      case 'book':
        return '${timeAgo}读过';
      case 'note':
        return '${timeAgo}写下';
      default:
        return timeAgo;
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
              onTap: _refresh,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 14, color: Color(0xFF666666)),
                    const SizedBox(width: 4),
                    const Text(
                      '换一个',
                      style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: _currentItem == null
          ? const Center(
              child: Text(
                '还没有任何内容\n去添加一些吧',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Color(0xFFBBBBBB), height: 1.6),
              ),
            )
          : Consumer<AppProvider>(
              builder: (context, provider, _) {
                final item = _currentItem!;

                // 笔记：独立卡片样式
                if (item.type == 'note') {
                  return _buildNoteCard(item);
                }

                // 影视/书籍：海报+信息样式
                final hasImage = item.imagePath != null &&
                    item.imagePath!.isNotEmpty &&
                    File(item.imagePath!).existsSync();

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 类型标签
                        _buildTypeChip(item),

                        const SizedBox(height: 28),

                        // 海报/封面/图标
                        if (hasImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(item.imagePath!),
                              width: 200,
                              height: 260,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(item),
                            ),
                          )
                        else
                          _buildPlaceholder(item),

                        const SizedBox(height: 28),

                        // 标题
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                            height: 1.3,
                          ),
                        ),

                        // 副标题
                        if (item.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
                          ),
                        ],

                        // 详情
                        if (item.detail.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.detail,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
                          ),
                        ],

                        // 时间
                        const SizedBox(height: 10),
                        Text(
                          _getActionTimeAgo(item),
                          style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC)),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildTypeChip(_StrollItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 14, color: const Color(0xFF999999)),
          const SizedBox(width: 6),
          Text(item.label, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        ],
      ),
    );
  }

  /// 笔记卡片样式
  Widget _buildNoteCard(_StrollItem item) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTypeChip(item),
            const SizedBox(height: 24),

            // 笔记卡片 - 类似分享海报
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 340),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 内容
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      item.detail,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF333333),
                        height: 1.8,
                      ),
                    ),
                  ),

                  // 底部分隔
                  Container(height: 0.5, color: const Color(0xFFEEEEEE)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.note_outlined, size: 13, color: Color(0xFFCCCCCC)),
                        const SizedBox(width: 6),
                        Text(
                          '${item.detail.length} 字',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _getActionTimeAgo(item),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                        ),
                        const Spacer(),
                        const Text(
                          'Mooknote',
                          style: TextStyle(fontSize: 11, color: Color(0xFFDDDDDD)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(_StrollItem item) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 0.5),
      ),
      child: Icon(item.icon, size: 40, color: const Color(0xFFDDDDDD)),
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
  final DateTime createdAt;

  _StrollItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.imagePath,
    required this.icon,
    required this.label,
    required this.createdAt,
  });
}
