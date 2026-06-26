import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../widgets/fade_in_local_image.dart';
import '../utils/toast_util.dart';
import 'movies/movie_detail_page.dart';
import 'book/book_detail_page.dart';
import 'note/note_detail_page.dart';

/// 漫步页面 - 随机发现内容
class StrollPage extends StatefulWidget {
  const StrollPage({super.key});

  @override
  State<StrollPage> createState() => _StrollPageState();
}

class _StrollPageState extends State<StrollPage> {
  final _random = Random();
  final List<_StrollItem> _items = [];
  final Set<String> _seenIds = {};
  late PageController _pageController;
  String _filter = 'all'; // all / movie / book / note

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
    _loadBatch(5);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── 数据加载 ───

  void _loadBatch(int count) {
    final provider = context.read<AppProvider>();

    // 按类别分池
    final moviePool = <_StrollItem>[];
    final bookPool = <_StrollItem>[];
    final notePool = <_StrollItem>[];
    if (_filter == 'all' || _filter == 'movie') {
      for (final m in provider.movies.where((m) => !m.isDeleted)) {
        moviePool.add(_StrollItem(
          type: 'movie', data: m, id: 'm_${m.id}',
          title: m.title,
          subtitle: m.alternateTitles.take(2).join(' / '),
          detail: _movieDetail(m),
          imagePath: m.posterPath,
          icon: Icons.movie_outlined, label: '影视',
          rating: m.rating, createdAt: m.createdAt,
          tags: m.genres.take(3).toList(),
          color: const Color(0xFF4A90D9),
        ));
      }
    }
    if (_filter == 'all' || _filter == 'book') {
      for (final b in provider.books.where((b) => !b.isDeleted)) {
        bookPool.add(_StrollItem(
          type: 'book', data: b, id: 'b_${b.id}',
          title: b.title,
          subtitle: b.authors.take(2).join(' / '),
          detail: _bookDetail(b),
          imagePath: b.coverPath,
          icon: Icons.menu_book_outlined, label: '书籍',
          rating: b.rating, createdAt: b.createdAt,
          tags: b.genres.take(3).toList(),
          color: const Color(0xFF7E57C2),
        ));
      }
    }
    if (_filter == 'all' || _filter == 'note') {
      for (final n in provider.notes.where((n) => !n.isDeleted)) {
        notePool.add(_StrollItem(
          type: 'note', data: n, id: 'n_${n.id}',
          title: n.title.isNotEmpty ? n.title : '随手记',
          subtitle: n.tags.take(3).join(' · '),
          detail: n.content,
          imagePath: n.images.isNotEmpty ? n.images.first : null,
          icon: Icons.note_outlined, label: '笔记',
          createdAt: n.createdAt,
          tags: n.tags.take(3).toList(),
          color: const Color(0xFF66BB6A),
        ));
      }
    }

    // 构建非空类别列表
    final pools = <List<_StrollItem>>[];
    if (moviePool.isNotEmpty) pools.add(moviePool);
    if (bookPool.isNotEmpty) pools.add(bookPool);
    if (notePool.isNotEmpty) pools.add(notePool);
    if (pools.isEmpty) return;

    // 全部模式下等概率选类别，单类别模式下直接选
    final target = _items.length + count;
    int attempts = 0;
    while (_items.length < target && attempts < count * 20) {
      attempts++;
      final pool = _filter == 'all'
          ? pools[_random.nextInt(pools.length)]
          : pools.first;
      final item = _weightedPick(pool);
      if (item != null && !_seenIds.contains(item.id)) {
        _seenIds.add(item.id);
        _items.add(item);
      }
    }
  }

  /// 加权随机：评分越高权重越大
  _StrollItem? _weightedPick(List<_StrollItem> pool) {
    if (pool.isEmpty) return null;
    final weights = pool.map((item) {
      final r = item.rating ?? 5.0;
      return r.clamp(1.0, 10.0);
    }).toList();
    final total = weights.reduce((a, b) => a + b);
    var roll = _random.nextDouble() * total;
    for (int i = 0; i < pool.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return pool[i];
    }
    return pool.last;
  }

  void _reshuffle() {
    setState(() {
      _items.clear();
      _seenIds.clear();
      _loadBatch(5);
    });
  }

  // ─── 辅助方法 ───

  String _movieDetail(Movie m) {
    final parts = <String>[];
    if (m.summary != null && m.summary!.isNotEmpty) {
      parts.add(m.summary!.length > 100 ? '${m.summary!.substring(0, 100)}...' : m.summary!);
    }
    return parts.join('\n');
  }

  String _bookDetail(Book b) {
    final parts = <String>[];
    if (b.publisher != null && b.publisher!.isNotEmpty) parts.add(b.publisher!);
    if (b.summary != null && b.summary!.isNotEmpty) {
      parts.add(b.summary!.length > 100 ? '${b.summary!.substring(0, 100)}...' : b.summary!);
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

  String _actionVerb(String type) {
    switch (type) {
      case 'movie': return '看过';
      case 'book': return '读过';
      case 'note': return '写下';
      default: return '';
    }
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

  void _deleteItem(_StrollItem item) async {
    final provider = context.read<AppProvider>();
    switch (item.type) {
      case 'movie': await provider.removeMovie(item.data.id);
      case 'book': await provider.removeBook(item.data.id);
      case 'note': await provider.removeNote(item.data.id);
    }
    setState(() => _items.remove(item));
    if (mounted) ToastUtil.show(context, '已删除');
  }

  // ─── 界面 ───

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasContent = _items.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          // 顶部栏
          _buildTopBar(colors),
          // 类型筛选
          _buildFilterBar(colors),
          // 内容
          Expanded(
            child: !hasContent
                ? _buildEmptyState(colors)
                : RefreshIndicator(
                    onRefresh: () async => _reshuffle(),
                    color: colors.primary,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
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
                              scale = (1 - diff * 0.08).clamp(0.88, 1.0);
                            }
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: _buildCard(_items[index], colors),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ColorScheme colors) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colors.onSurface.withValues(alpha: 0.7)),
            ),
            const Spacer(),
            Text('漫步', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const Spacer(),
            GestureDetector(
              onTap: _reshuffle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.casino_outlined, size: 14, color: colors.onPrimary),
                  const SizedBox(width: 4),
                  Text('随机', style: TextStyle(fontSize: 12, color: colors.onPrimary, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colors) {
    final filters = [
      ('all', '全部', Icons.apps_outlined),
      ('movie', '影视', Icons.movie_outlined),
      ('book', '书籍', Icons.menu_book_outlined),
      ('note', '笔记', Icons.note_outlined),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_filter != f.$1) {
                  setState(() {
                    _filter = f.$1;
                    _items.clear();
                    _seenIds.clear();
                    _loadBatch(5);
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? colors.primary : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.$3, size: 14, color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(f.$2, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5))),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard(_StrollItem item, ColorScheme colors) {
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

    return GestureDetector(
      onTap: () => _openDetail(item),
      onDoubleTap: () => ToastUtil.show(context, '已收藏'),
      child: hasImage ? _buildImmersiveCard(item, colors) : _buildContentCard(item, colors),
    );
  }

  /// 有图片的卡片：全屏沉浸式
  Widget _buildImmersiveCard(_StrollItem item, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 56, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FadeInLocalImage(path: item.imagePath, fit: BoxFit.cover),

          // 底部渐变蒙层
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.3, 0.7],
                ),
              ),
            ),
          ),

          // 顶部标签 + 评分
          Positioned(
            top: 16, left: 16, right: 16,
            child: _buildTopBadges(item),
          ),

          // 底部内容
          Positioned(
            left: 20, right: 20, bottom: 20,
            child: _buildBottomContent(item, Colors.white),
          ),
        ],
      ),
    );
  }

  /// 无图片的卡片：内容从顶部开始
  Widget _buildContentCard(_StrollItem item, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 56, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标签 + 评分
            _buildTopBadges(item, textColor: colors.onSurface, bgColor: item.color.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            // 内容
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标签
                    if (item.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 6,
                          children: item.tags.take(3).map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(tag, style: TextStyle(fontSize: 11, color: item.color)),
                          )).toList(),
                        ),
                      ),

                    // 标题
                    Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.onSurface, height: 1.3)),

                    // 副标题
                    if (item.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5))),
                    ],

                    // 详情
                    if (item.detail.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(item.detail, maxLines: 6, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.55), height: 1.7)),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 操作栏
            Row(children: [
              Text('${_timeAgoText(item.createdAt)} ${_actionVerb(item.type)}',
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
              const Spacer(),
              _actionBtn(Icons.visibility_outlined, '查看', () => _openDetail(item), colors: colors),
              const SizedBox(width: 8),
              _actionBtn(Icons.delete_outline, '删除', () => _showDeleteConfirm(item), colors: colors),
            ]),
          ],
        ),
      ),
    );
  }

  /// 顶部类型标签 + 评分
  Widget _buildTopBadges(_StrollItem item, {Color? textColor, Color? bgColor}) {
    final fg = textColor ?? Colors.white;
    final bg = bgColor ?? Colors.black.withValues(alpha: 0.3);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(item.icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(item.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ]),
      ),
      const Spacer(),
      if (item.rating != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star, size: 14, color: Color(0xFFFFB800)),
            const SizedBox(width: 3),
            Text(item.rating!.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
    ]);
  }

  /// 底部内容（沉浸式卡片用，白色文字）
  Widget _buildBottomContent(_StrollItem item, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 6,
              children: item.tags.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
                ),
                child: Text(tag, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
              )).toList(),
            ),
          ),

        Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor, height: 1.3)),

        if (item.subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6))),
        ],

        if (item.detail.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(item.detail, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5), height: 1.6)),
        ],

        const SizedBox(height: 16),

        Row(children: [
          Text('${_timeAgoText(item.createdAt)} ${_actionVerb(item.type)}',
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.4))),
          const Spacer(),
          _actionBtn(Icons.visibility_outlined, '查看', () => _openDetail(item)),
          const SizedBox(width: 12),
          _actionBtn(Icons.delete_outline, '删除', () => _showDeleteConfirm(item)),
        ]),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, {ColorScheme? colors}) {
    final fg = colors?.onSurface ?? Colors.white;
    final bg = colors != null ? colors.surfaceContainerHighest : Colors.white.withValues(alpha: 0.12);
    final border = colors != null ? colors.outlineVariant : Colors.white.withValues(alpha: 0.15);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg.withValues(alpha: 0.8)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }

  void _showDeleteConfirm(_StrollItem item) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除"${item.title}"吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _deleteItem(item); },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 80, height: 80,
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.explore_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.2))),
          const SizedBox(height: 20),
          Text('还没有内容', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 8),
          Text('去添加一些影视、书籍或笔记吧', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25))),
        ],
      ),
    );
  }
}

class _StrollItem {
  final String type;
  final dynamic data;
  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final String? imagePath;
  final IconData icon;
  final String label;
  final double? rating;
  final DateTime createdAt;
  final List<String> tags;
  final Color color;

  _StrollItem({
    required this.type,
    required this.data,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.detail,
    this.imagePath,
    required this.icon,
    required this.label,
    this.rating,
    required this.createdAt,
    this.tags = const [],
    required this.color,
  });
}
