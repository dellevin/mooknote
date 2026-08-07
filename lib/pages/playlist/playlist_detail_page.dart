import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/animated_star_rating.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';
import 'playlist_add_item_page.dart';

class PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  List<PlaylistItem> _items = [];
  bool _loading = true;
  final Map<String, double> _slideOffsets = {};
  double _dragStartX = 0;
  double _dragStartOffset = 0;
  bool _isHorizontalDrag = false;
  static const _actionWidth = 56.0;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final provider = context.read<AppProvider>();
    final items = await provider.getPlaylistItems(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  /// 解析条目信息
  _ResolvedItem? _resolve(PlaylistItem item, AppProvider provider) {
    final type = widget.playlist.type;
    String? status;
    String title = '';
    String? coverPath;
    double? rating;
    String subtitle = '';
    dynamic entity;

    if (type == 'movie') {
      final movie = provider.movies.where((m) => m.id == item.itemId).firstOrNull;
      if (movie == null) return null;
      entity = movie;
      status = movie.status;
      title = movie.title;
      coverPath = movie.posterPath;
      rating = movie.rating;
      subtitle = movie.directors.isNotEmpty ? movie.directors.take(2).join(' / ') : '';
    } else if (type == 'book') {
      final book = provider.books.where((b) => b.id == item.itemId).firstOrNull;
      if (book == null) return null;
      entity = book;
      status = book.status;
      title = book.title;
      coverPath = book.coverPath;
      rating = book.rating;
      subtitle = book.authors.isNotEmpty ? book.authors.take(2).join(' / ') : '';
    } else if (type == 'game') {
      final game = provider.games.where((g) => g.id == item.itemId).firstOrNull;
      if (game == null) return null;
      entity = game;
      status = game.status;
      title = game.title;
      coverPath = game.coverPath;
      rating = game.rating;
      subtitle = game.developer.isNotEmpty ? game.developer.take(2).join(' / ') : '';
    }

    return _ResolvedItem(
      playlistItem: item,
      entity: entity,
      title: title,
      coverPath: coverPath,
      rating: rating,
      subtitle: subtitle,
      status: status ?? '',
    );
  }

  static String _statusLabel(String type, String status) {
    if (type == 'movie') {
      return switch (status) {
        'watched' => '已看',
        'watching' => '在看',
        'want_to_watch' => '想看',
        _ => '',
      };
    } else if (type == 'book') {
      return switch (status) {
        'read' => '已读',
        'reading' => '在读',
        'want_to_read' => '想读',
        _ => '',
      };
    } else {
      return switch (status) {
        'completed' => '已完',
        'playing' => '在玩',
        'want_to_play' => '想玩',
        'abandoned' => '已弃',
        _ => '',
      };
    }
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'watched' || 'read' || 'completed' => const Color(0xFF4CAF50),
      'watching' || 'reading' || 'playing' => const Color(0xFF42A5F5),
      'want_to_watch' || 'want_to_read' || 'want_to_play' => const Color(0xFFFF9800),
      'abandoned' => const Color(0xFFEF5350),
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final playlist = provider.playlists.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => PlaylistAddItemPage(playlist: playlist)),
              );
              if (mounted) {
                _loadItems();
                provider.loadPlaylists();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : _items.isEmpty
              ? _buildEmpty(context)
              : _buildList(context, provider),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.playlist_add_check_outlined, size: 36, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(height: 16),
          Text('还没有添加条目', style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('点击右上角 + 添加', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, AppProvider provider) {
    final type = widget.playlist.type;
    final resolved = _items
        .map((item) => _resolve(item, provider))
        .whereType<_ResolvedItem>()
        .toList();

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: resolved.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final list = List<_ResolvedItem>.from(resolved);
        final item = list.removeAt(oldIndex);
        list.insert(newIndex, item);
        setState(() {
          _items = list.map((r) => r.playlistItem).toList();
        });
        provider.reorderPlaylistItems(
          widget.playlist.id,
          _items.map((i) => i.id).toList(),
        );
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(animation.value);
            return Transform.scale(
              scale: 1.0 + 0.03 * t,
              child: Opacity(opacity: 1.0 - 0.15 * t, child: child),
            );
          },
        );
      },
      itemBuilder: (context, index) {
        return _buildItem(context, resolved[index], type, provider);
      },
    );
  }

  Widget _buildItem(BuildContext context, _ResolvedItem item, String type, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(item.status);
    final statusLabel = _statusLabel(type, item.status);
    final itemId = item.playlistItem.id;

    return Padding(
      key: Key(itemId),
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 底层：删除按钮
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _slideOffsets[itemId] = 0.0);
                    await provider.removePlaylistItem(item.playlistItem.id, item.playlistItem.playlistId);
                    if (mounted) _loadItems();
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline, size: 20, color: colors.error),
                  ),
                ),
              ),
            ),
          ),
          // 上层：卡片内容（左滑 + 长按拖动排序）
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_slideOffsets[itemId] ?? 0, 0, 0),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                _dragStartX = event.position.dx;
                _dragStartOffset = _slideOffsets[itemId] ?? 0;
                _isHorizontalDrag = false;
              },
              onPointerMove: (event) {
                final dx = event.position.dx - _dragStartX;
                if (!_isHorizontalDrag && dx.abs() > 10) {
                  if (dx < 0 || _dragStartOffset < 0) {
                    _isHorizontalDrag = true;
                  }
                }
                if (_isHorizontalDrag) {
                  setState(() {
                    _slideOffsets[itemId] = (_dragStartOffset + dx).clamp(-_actionWidth * 2, 0.0);
                  });
                }
              },
              onPointerUp: (_) {
                if (_isHorizontalDrag) {
                  final offset = _slideOffsets[itemId] ?? 0.0;
                  final target = offset < -_actionWidth ? -_actionWidth * 2 : 0.0;
                  setState(() => _slideOffsets[itemId] = target);
                }
                _isHorizontalDrag = false;
              },
              child: ReorderableDelayedDragStartListener(
                index: _items.indexOf(item.playlistItem),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if ((_slideOffsets[itemId] ?? 0) < 0) {
                        setState(() => _slideOffsets[itemId] = 0.0);
                        return;
                      }
                      final page = switch (type) {
                        'movie' => MovieDetailPage(movie: item.entity as Movie),
                        'book' => BookDetailPage(book: item.entity as Book),
                        'game' => GameDetailPage(game: item.entity as Game),
                        _ => null,
                      };
                      if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page));
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          // 封面
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48, height: 64,
                              child: item.coverPath != null && item.coverPath!.isNotEmpty
                                  ? FadeInLocalImage(
                                      path: item.coverPath,
                                      fit: BoxFit.cover,
                                      errorWidget: _buildPlaceholder(type, colors),
                                    )
                                  : _buildPlaceholder(type, colors),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 信息
                          Expanded(
                            child: SizedBox(
                              height: 64,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                                  if (item.subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                                  ],
                                  const Spacer(),
                                  if (item.rating != null)
                                    AnimatedStarRating(rating: item.rating!, starSize: 11, showNumber: true)
                                  else
                                    Text('未评分', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 状态章
                          if (statusLabel.isNotEmpty) _buildStamp(statusLabel, statusColor),
                        ],
                      ),
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

  /// 章形状的状态标签 — 双圈外圆 + 内长方框，模拟印章效果
  Widget _buildStamp(String label, Color color) {
    return Transform.rotate(
      angle: -0.12,
      child: SizedBox(
        width: 52, height: 52,
        child: CustomPaint(
          painter: _StampPainter(color: color),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1.5),
                border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: color.withValues(alpha: 0.85),
                        height: 1.1,
                        letterSpacing: 0.8,
                      )),
                  const SizedBox(height: 0.5),
                  Text('MOOKNOTE',
                      style: TextStyle(
                        fontSize: 2,
                        fontWeight: FontWeight.w700,
                        color: color.withValues(alpha: 0.45),
                        height: 1,
                        letterSpacing: 1,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String type, ColorScheme colors) {
    final icon = switch (type) {
      'movie' => Icons.movie_outlined,
      'book' => Icons.menu_book_outlined,
      'game' => Icons.sports_esports_outlined,
      _ => Icons.list_outlined,
    };
    return Container(
      color: colors.surfaceContainerHighest,
      child: Center(child: Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.25))),
    );
  }

}

class _ResolvedItem {
  final PlaylistItem playlistItem;
  final dynamic entity;
  final String title;
  final String? coverPath;
  final double? rating;
  final String subtitle;
  final String status;

  _ResolvedItem({
    required this.playlistItem,
    this.entity,
    required this.title,
    this.coverPath,
    this.rating,
    this.subtitle = '',
    required this.status,
  });
}

/// 印章绘制器 — 双圈外圆
class _StampPainter extends CustomPainter {
  final Color color;
  _StampPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // 外圈
    canvas.drawCircle(Offset(cx, cy), size.width / 2 - 2, paint);

    // 内圈
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), size.width / 2 - 5, innerPaint);
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) => old.color != color;
}
