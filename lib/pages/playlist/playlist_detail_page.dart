import 'package:flutter/material.dart';
import '../../utils/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/animated_star_rating.dart';
import '../movies/movie_detail_page.dart';
import '../book/book_detail_page.dart';
import '../game/game_detail_page.dart';
import 'playlist_add_item_page.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/app_overlay.dart';
import '../../utils/responsive.dart';
import '../../utils/user_prefs.dart';

class PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;
  const PlaylistDetailPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> with SingleTickerProviderStateMixin {
  List<PlaylistItem> _items = [];
  bool _loading = true;
  String _statusFilter = 'all'; // all / 具体状态 / none
  int _layoutStyle = UserPrefs().playlistDetailLayoutStyle; // 0:列表 1:海报墙
  final Map<String, double> _slideOffsets = {};
  static const _actionWidth = 56.0;

  void _closeAllSlides({String? exceptId}) {
    final keys = _slideOffsets.keys
        .where((id) => id != exceptId && (_slideOffsets[id] ?? 0) != 0)
        .toList();
    if (keys.isEmpty) return;
    setState(() {
      for (final id in keys) {
        _slideOffsets[id] = 0.0;
      }
    });
  }

  late final AnimationController _wallCtrl;

  @override
  void initState() {
    super.initState();
    _wallCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    );
    _loadItems();
  }

  @override
  void dispose() {
    _wallCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final provider = context.read<AppProvider>();
    final items = await provider.getPlaylistItems(widget.playlist.id);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    if (items.isNotEmpty) {
      _wallCtrl.repeat();
    } else {
      _wallCtrl.stop();
    }
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
    String? itemType;

    if (type == 'movie' || type == 'all') {
      final movie = provider.movies.where((m) => m.id == item.itemId).firstOrNull;
      if (movie != null) {
        entity = movie;
        itemType = 'movie';
        status = movie.status;
        title = movie.title;
        coverPath = movie.posterPath;
        rating = movie.rating;
        subtitle = movie.directors.isNotEmpty ? movie.directors.take(2).join(' / ') : '';
      }
    }
    if (entity == null && (type == 'book' || type == 'all')) {
      final book = provider.books.where((b) => b.id == item.itemId).firstOrNull;
      if (book != null) {
        entity = book;
        itemType = 'book';
        status = book.status;
        title = book.title;
        coverPath = book.coverPath;
        rating = book.rating;
        subtitle = book.authors.isNotEmpty ? book.authors.take(2).join(' / ') : '';
      }
    }
    if (entity == null && (type == 'game' || type == 'all')) {
      final game = provider.games.where((g) => g.id == item.itemId).firstOrNull;
      if (game != null) {
        entity = game;
        itemType = 'game';
        status = game.status;
        title = game.title;
        coverPath = game.coverPath;
        rating = game.rating;
        subtitle = game.developer.isNotEmpty ? game.developer.take(2).join(' / ') : '';
      }
    }
    if (entity == null) return null;

    return _ResolvedItem(
      playlistItem: item,
      entity: entity,
      type: itemType!,
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

  static Color _statusColor(ColorScheme colors, String status) =>
      AppTheme.statusOverlayColors(colors, status).bg;

  bool _isDone(String status) =>
      status == 'watched' || status == 'read' || status == 'completed';

  /// 混合片单把各媒体状态归并为统一分组
  String _bucket(String status) {
    if (status.isEmpty) return 'none';
    if (_isDone(status)) return 'done';
    if (status == 'watching' || status == 'reading' || status == 'playing') return 'ing';
    if (status == 'abandoned') return 'abandoned';
    return 'want';
  }

  String _filterKey(_ResolvedItem r) =>
      widget.playlist.type == 'all' ? _bucket(r.status) : (r.status.isEmpty ? 'none' : r.status);

  /// 顶部斜向海报拼贴墙 + 片单信息
  Widget _buildHeader(BuildContext context, Playlist playlist, List<_ResolvedItem> resolved) {
    final covers = resolved
        .map((r) => r.coverPath)
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();

    final total = resolved.length;
    final done = resolved.where((r) => _isDone(r.status)).length;
    final progressText = switch (playlist.type) {
      'movie' => '看过 {done}/{total}部'.trf({'done': '$done', 'total': '$total'}),
      'book' => '读过 {done}/{total}本'.trf({'done': '$done', 'total': '$total'}),
      'game' => '通关 {done}/{total}款'.trf({'done': '$done', 'total': '$total'}),
      _ => '已完成 {done}/{total}项'.trf({'done': '$done', 'total': '$total'}),
    };
    final d = playlist.updatedAt;
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _closeAllSlides,
      child: SizedBox(
      height: 270,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // 斜向海报墙
          if (covers.isNotEmpty)
            _buildPosterWall(covers)
          else
            Container(color: const Color(0xFF2B2B36)),
          // 压暗渐变
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.82),
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),
          // 文字信息
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPad, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  playlist.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                ),
                if (playlist.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    playlist.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
                if (playlist.type != 'all') ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : done / total,
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.22),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(progressText,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '更新时间: {date}'.trf({'date': dateStr}),
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 倾斜放大的海报拼贴 + 沿斜向无限滚动（双段相同网格平移，无缝循环）
  Widget _buildPosterWall(List<String> covers) {
    const cols = 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final wallW = w * 1.7;
        final segH = h * 2.1; // 单段高度，也是一个循环的平移距离

        Widget buildSegment() => SizedBox(
              width: wallW,
              height: segH,
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: cols * 8,
                itemBuilder: (context, i) {
                  final path = covers[i % covers.length];
                  return FadeInLocalImage(path: path, fit: BoxFit.cover);
                },
              ),
            );

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: AnimatedBuilder(
              animation: _wallCtrl,
              builder: (context, _) {
                return Transform.rotate(
                  angle: -0.52,
                  child: Transform.translate(
                    offset: Offset(0, -_wallCtrl.value * segH),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [buildSegment(), buildSegment()],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 状态筛选 chip 行
  Widget _buildFilterChips(BuildContext context, Playlist playlist, List<_ResolvedItem> resolved) {
    final entries = <(String, String)>[];
    void addIfPresent(String key, String label) {
      if (resolved.any((r) => _filterKey(r) == key)) entries.add((key, label));
    }

    switch (playlist.type) {
      case 'movie':
        addIfPresent('none', '未看');
        addIfPresent('want_to_watch', '想看');
        addIfPresent('watching', '在看');
        addIfPresent('watched', '已看');
      case 'book':
        addIfPresent('none', '未读');
        addIfPresent('want_to_read', '想读');
        addIfPresent('reading', '在读');
        addIfPresent('read', '已读');
      case 'game':
        addIfPresent('none', '未玩');
        addIfPresent('want_to_play', '想玩');
        addIfPresent('playing', '在玩');
        addIfPresent('completed', '已通关');
        addIfPresent('abandoned', '弃游');
      default:
        addIfPresent('none', '未标记');
        addIfPresent('want', '想看');
        addIfPresent('ing', '在看');
        addIfPresent('done', '已完成');
        addIfPresent('abandoned', '已弃');
    }

    final colors = Theme.of(context).colorScheme;

    Widget chip(String? key, String label, int count) {
      final selected = _statusFilter == (key ?? 'all');
      return GestureDetector(
        onTap: () {
          _closeAllSlides();
          setState(() => _statusFilter = key ?? 'all');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? colors.primary : colors.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _closeAllSlides,
      child: Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip(null, '全部'.tr, resolved.length),
            const SizedBox(width: 8),
            for (final e in entries) ...[
              Builder(builder: (_) {
                final count = resolved.where((r) => _filterKey(r) == e.$1).length;
                return chip(e.$1, e.$2.tr, count);
              }),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final playlist = provider.playlists.firstWhere(
      (p) => p.id == widget.playlist.id,
      orElse: () => widget.playlist,
    );

    final showWall = !_loading && _items.isNotEmpty;
    final addAction = IconButton(
      icon: const Icon(Icons.add, size: 24),
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
    );
    final layoutToggle = IconButton(
      icon: Icon(_layoutStyle == 0 ? Icons.grid_view_outlined : Icons.view_list_outlined, size: 22),
      tooltip: _layoutStyle == 0 ? '海报墙'.tr : '列表'.tr,
      onPressed: () {
        final next = _layoutStyle == 0 ? 1 : 0;
        setState(() => _layoutStyle = next);
        UserPrefs().setPlaylistDetailLayoutStyle(next);
      },
    );
    final actions = [layoutToggle, addAction];

    return Scaffold(
      extendBodyBehindAppBar: showWall,
      appBar: showWall
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              foregroundColor: Colors.white,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: actions,
            )
          : AppBar(title: Text(playlist.name), actions: actions),
      body: _loading
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : _items.isEmpty
              ? _buildEmpty(context)
              : _buildList(context, provider, playlist),
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
          Text('还没有添加条目'.tr, style: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('点击右上角 + 添加'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, AppProvider provider, Playlist playlist) {
    final resolved = _items
        .map((item) => _resolve(item, provider))
        .whereType<_ResolvedItem>()
        .toList();

    final visible = _statusFilter == 'all'
        ? resolved
        : resolved.where((r) => _statusFilter == 'none' ? r.status.isEmpty : r.status == _statusFilter).toList();

    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 固定的海报墙 Header，不随列表滚动
        _buildHeader(context, playlist, resolved),
        if (resolved.isNotEmpty && playlist.type != 'all') _buildFilterChips(context, playlist, resolved),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text('该分类下暂无条目'.tr,
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
                )
              : _layoutStyle == 1
                  ? _buildGridView(context, visible, provider)
                  : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeAllSlides,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _closeAllSlides();
                return false;
              },
              child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  itemCount: visible.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final moved = visible[oldIndex].playlistItem;
                    final full = List<PlaylistItem>.from(_items);
                    final from = full.indexWhere((i) => i.id == moved.id);
                    full.removeAt(from);
                    int insertIndex;
                    if (newIndex < visible.length) {
                      final anchorId = visible[newIndex].playlistItem.id;
                      insertIndex = full.indexWhere((i) => i.id == anchorId);
                      if (insertIndex < 0) insertIndex = full.length;
                    } else {
                      insertIndex = full.length;
                    }
                    full.insert(insertIndex, moved);
                    setState(() {
                      _items = full;
                    });
                    provider.reorderPlaylistItems(
                      widget.playlist.id,
                      full.map((i) => i.id).toList(),
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
                    return _buildItem(context, visible[index], index, provider);
                  },
                ),
            ),
          ),
        ),
      ],
    );
  }

  /// 海报墙视图：封面卡片网格（点击进详情，长按从片单移除）
  Widget _buildGridView(BuildContext context, List<_ResolvedItem> visible, AppProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) => _buildGridCard(context, visible[index], provider),
        );
      },
    );
  }

  Widget _buildGridCard(BuildContext context, _ResolvedItem item, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final typeColor = switch (item.type) {
      'movie' => Colors.blue,
      'book' => Colors.teal,
      'game' => Colors.orange,
      _ => colors.onSurface,
    };
    final typeLabel = switch (item.type) {
      'movie' => '影视',
      'book' => '书籍',
      'game' => '游戏',
      _ => item.type,
    };

    return GestureDetector(
      onTap: () {
        final page = switch (item.type) {
          'movie' => MovieDetailPage(movie: item.entity as Movie),
          'book' => BookDetailPage(book: item.entity as Book),
          'game' => GameDetailPage(game: item.entity as Game),
          _ => null,
        };
        if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      onLongPress: () => _confirmRemoveItem(item, provider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colors.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: item.coverPath != null && item.coverPath!.isNotEmpty
                  ? FadeInLocalImage(
                      path: item.coverPath,
                      fit: BoxFit.cover,
                      errorWidget: _buildPlaceholder(item.type, colors),
                    )
                  : _buildPlaceholder(item.type, colors),
            ),
          ),
          const SizedBox(height: 6),
          Text(item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface)),
          const SizedBox(height: 3),
          Row(
            children: [
              if (item.rating != null)
                AnimatedStarRating(rating: item.rating!, starSize: 10, showNumber: true)
              else
                const SizedBox(height: 14),
              if (widget.playlist.type == 'all') ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(typeLabel.tr,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: typeColor)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, _ResolvedItem item, int index, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    final type = item.type;
    final statusColor = _statusColor(colors, item.status);
    final statusLabel = _statusLabel(type, item.status);
    final itemId = item.playlistItem.id;

    return Padding(
      key: Key(itemId),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Stack(
        clipBehavior: Clip.none,
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
                  onTap: () => _confirmRemoveItem(item, provider),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: colors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.error.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.delete_outline, size: 18, color: colors.onError),
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: (_) => _closeAllSlides(exceptId: itemId),
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _slideOffsets[itemId] =
                      ((_slideOffsets[itemId] ?? 0) + details.delta.dx).clamp(-_actionWidth, 0.0);
                });
              },
              onHorizontalDragEnd: (details) {
                final offset = _slideOffsets[itemId] ?? 0.0;
                final velocity = details.primaryVelocity ?? 0;
                final target = (velocity < -200 || offset < -_actionWidth / 2)
                    ? -_actionWidth
                    : 0.0;
                setState(() => _slideOffsets[itemId] = target);
              },
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if ((_slideOffsets[itemId] ?? 0) < 0) {
                        setState(() => _slideOffsets[itemId] = 0.0);
                        return;
                      }
                      if (_slideOffsets.values.any((v) => v < 0)) {
                        _closeAllSlides();
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
                        boxShadow: [
                          BoxShadow(
                            color: colors.shadow.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
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
                                  Row(
                                    children: [
                                      if (widget.playlist.type == 'all') ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: colors.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            switch (type) {
                                              'movie' => '影视'.tr,
                                              'book' => '书籍'.tr,
                                              'game' => '游戏'.tr,
                                              _ => type,
                                            },
                                            style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.45)),
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Flexible(
                                        child: Text(item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                                      ),
                                    ],
                                  ),
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
                                    Text('未评分'.tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25))),
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

  /// 删除前确认
  void _confirmRemoveItem(_ResolvedItem item, AppProvider provider) {
    final colors = Theme.of(context).colorScheme;
    appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要将「{name}」从片单中移除吗？'.trf({'name': item.title}),
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.removePlaylistItem(item.playlistItem.id, item.playlistItem.playlistId);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('删除'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        setState(() => _slideOffsets[item.playlistItem.id] = 0.0);
        _loadItems();
      }
    });
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
                  Text(label.tr,
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
  final String type;
  final String title;
  final String? coverPath;
  final double? rating;
  final String subtitle;
  final String status;

  _ResolvedItem({
    required this.playlistItem,
    this.entity,
    required this.type,
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
