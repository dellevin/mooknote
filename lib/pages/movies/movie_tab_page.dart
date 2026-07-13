import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/movie_status_bar.dart';
import '../../widgets/movie_category_bar.dart';
import '../../widgets/movie_list_item.dart';
import '../../widgets/animated_star_rating.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../utils/responsive.dart';
import '../../widgets/master_detail_scaffold.dart';
import '../../widgets/detail_placeholder.dart';
import 'movie_detail_page.dart';
import 'movie_add_page.dart';

/// 观影标签页（分页 + 触底加载）
class MovieTabPage extends StatefulWidget {
  const MovieTabPage({super.key});

  @override
  State<MovieTabPage> createState() => _MovieTabPageState();
}

class _MovieTabPageState extends State<MovieTabPage> {
  final List<Movie> _items = [];
  bool _hasMore = true;
  bool _isLoading = false;
  int _offset = 0;
  bool _initialized = false;
  int _lastStatusIndex = -1;
  late ScrollController _scrollController;
  AppProvider? _provider;
  int _lastScrollSignal = 0;
  int _lastEditRefreshCounter = 0;
  int _prevMovieCount = -1;
  int _prevLayoutStyle = -1;
  int _prevCategoryIndex = -1;
  int _prevDisplayMode = -1;
  double _swipeOffset = 0.0; // 当前拖动偏移量（用于左右滑动切换状态）

  static const _statusMap = {0: 'watched', 1: 'watching', 2: 'want_to_watch'};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      _provider = provider;
      provider.addListener(_onDataChanged);
      _loadFirst();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_onDataChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (!_initialized || !mounted) return;
    final provider = context.read<AppProvider>();

    // 检查回到顶部信号
    if (provider.scrollToTopSignal != _lastScrollSignal && provider.scrollToTopSignal > 0) {
      _lastScrollSignal = provider.scrollToTopSignal;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }

    // 仅在数据或布局实际变化时刷新列表，避免底部导航栏显隐等UI变化误触发重载
    final statusChanged = provider.movieStatusIndex != _lastStatusIndex;
    final layoutChanged = provider.movieLayoutStyle != _prevLayoutStyle;
    final categoryChanged = provider.movieCategoryIndex != _prevCategoryIndex;
    final displayModeChanged = provider.movieDisplayMode != _prevDisplayMode;
    final countChanged = provider.movies.length != _prevMovieCount;
    final editRefreshed = provider.editRefreshCounter > _lastEditRefreshCounter;
    if (editRefreshed && provider.lastEditedItemId != null) {
      // 就地更新被编辑的条目，不重置分页
      _lastEditRefreshCounter = provider.editRefreshCounter;
      _prevMovieCount = provider.movies.length;
      final editedId = provider.lastEditedItemId!;
      final idx = _items.indexWhere((m) => m.id == editedId);
      if (idx != -1) {
        final updated = provider.movies.where((m) => m.id == editedId).firstOrNull;
        if (updated != null) {
          setState(() { _items[idx] = updated; });
        }
      }
      return;
    }
    if (statusChanged || layoutChanged || categoryChanged || displayModeChanged || countChanged || editRefreshed) {
      _prevLayoutStyle = provider.movieLayoutStyle;
      _prevCategoryIndex = provider.movieCategoryIndex;
      _prevDisplayMode = provider.movieDisplayMode;
      _prevMovieCount = provider.movies.length;
      _loadFirst();
    }
    if (editRefreshed) {
      _lastEditRefreshCounter = provider.editRefreshCounter;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    final provider = context.read<AppProvider>();
    final isWallMode = provider.movieWallMode;
    final isCategoryMode = provider.movieDisplayMode == 1;
    final statusIdx = provider.movieStatusIndex;
    final categoryIdx = provider.movieCategoryIndex;
    _lastStatusIndex = statusIdx;
    _initialized = true;
    // 影视墙模式：不筛选状态和分类
    // 分类模式：按分类筛选
    // 观看状态模式：按状态筛选
    String? status;
    String? category;
    if (isWallMode) {
      status = null;
      category = null;
    } else if (isCategoryMode) {
      status = null;
      category = MovieCategoryBar.categoryValue(categoryIdx);
    } else {
      status = _statusMap[statusIdx] ?? 'watched';
      category = null;
    }
    final sortMode = UserPrefs().movieSortMode;
    setState(() { _isLoading = true; _offset = 0; _hasMore = true; });
    final list = await provider.loadMoviesPaged(status: status, category: category, offset: 0, sortMode: sortMode);
    if (!mounted) return;
    setState(() {
      _items.clear();
      _items.addAll(list);
      _offset = list.length;
      _hasMore = list.length >= 20;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final isWallMode = provider.movieWallMode;
    final isCategoryMode = provider.movieDisplayMode == 1;
    String? status;
    String? category;
    if (isWallMode) {
      status = null;
      category = null;
    } else if (isCategoryMode) {
      status = null;
      category = MovieCategoryBar.categoryValue(provider.movieCategoryIndex);
    } else {
      status = _statusMap[provider.movieStatusIndex] ?? 'watched';
      category = null;
    }
    final sortMode = UserPrefs().movieSortMode;
    final list = await provider.loadMoviesPaged(status: status, category: category, offset: _offset, sortMode: sortMode);
    if (!mounted) return;
    setState(() {
      _items.addAll(list);
      _offset += list.length;
      _hasMore = list.length >= 20;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    final provider = context.read<AppProvider>();
    await provider.loadMovies();
    await _loadFirst();
  }

  void _onMovieTap(Movie movie) {
    if (Breakpoint.isWideContent(context)) {
      context.read<AppProvider>().selectMovie(movie);
    } else {
      Navigator.pushNamed(context, '/movie-detail', arguments: movie);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isWideContent = Breakpoint.isWideContent(context);
    final provider = context.watch<AppProvider>();
    final isWallMode = provider.movieWallMode;

    final masterContent = Column(
      children: [
        if (!isWallMode)
          provider.movieDisplayMode == 1
              ? const MovieCategoryBar()
              : const MovieStatusBar(),
        Expanded(child: _buildBody(context)),
      ],
    );

    if (!isWideContent) return masterContent;

    final selectedMovie = provider.selectedMovie;
    final detailWidget = provider.isAdding && provider.addingType == 0
        ? MovieAddPage(onCancel: () => provider.cancelAdding())
        : selectedMovie != null
            ? MovieDetailPage(movie: selectedMovie, embedded: true)
            : const DetailPlaceholder(icon: Icons.movie_outlined, message: '选择一部影片查看详情');
    return MasterDetailScaffold(
      master: masterContent,
      detail: detailWidget,
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // 状态切换时重新加载（跳过首次未初始化的情况）
        if (_initialized && provider.movieStatusIndex != _lastStatusIndex) {
          _lastStatusIndex = provider.movieStatusIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirst());
        }

        final content = () {
          if (_items.isEmpty && _isLoading) return _buildSkeleton();
          if (_items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              color: colors.primary,
              backgroundColor: colors.surface,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_buildEmptyState(context, provider.movieStatusIndex)],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: colors.primary,
            backgroundColor: colors.surface,
            child: provider.movieLayoutStyle == 1 ? _buildListView() : provider.movieLayoutStyle == 2 ? _buildCoverCardView() : _buildGridView(),
          );
        }();

        // 用 GestureDetector 包裹，左右滑动切换状态/分类
        return GestureDetector(
          onHorizontalDragStart: (_) => _swipeOffset = 0.0,
          onHorizontalDragUpdate: (details) => setState(() => _swipeOffset += details.primaryDelta ?? 0),
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity;
            if ((velocity ?? 0).abs() < 80) {
              setState(() => _swipeOffset = 0.0);
              return;
            }
            final direction = (velocity ?? 0) > 0 ? -1 : 1; // 右滑→上一个，左滑→下一个
            setState(() => _swipeOffset = 0.0);
            if (provider.movieDisplayMode == 1) {
              // 分类模式
              final count = MovieCategoryBar.count;
              final newIndex = (provider.movieCategoryIndex + direction + count) % count;
              provider.setMovieCategoryIndex(newIndex);
            } else {
              // 观看状态模式
              final newIndex = (provider.movieStatusIndex + direction + 3) % 3;
              provider.setMovieStatusIndex(newIndex);
            }
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: _swipeOffset.clamp(-100.0, 100.0)),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Transform.translate(offset: Offset(value, 0), child: child);
            },
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
        final isWideContent = Breakpoint.isWideContent(context);
        final provider = context.read<AppProvider>();
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, childAspectRatio: 0.55, crossAxisSpacing: 12, mainAxisSpacing: 16,
          ),
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) return _buildLoadMoreIndicator();
            final item = _items[index];
            return MovieListItem(
              movie: item,
              selected: isWideContent && provider.selectedMovie?.id == item.id,
              onTap: () => _onMovieTap(item),
            );
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) return _buildLoadMoreIndicator();
        return _buildListCard(_items[index]);
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
            : Text('没有更多了', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
      ),
    );
  }

  Widget _buildListCard(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onMovieTap(movie),
      onLongPress: () => _showDeleteDialog(context, movie),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 48, height: 64,
            decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: movie.posterPath != null && movie.posterPath!.isNotEmpty
                ? FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover,
                    errorWidget: Icon(Icons.movie_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)))
                : Icon(Icons.movie_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
            ...[
              const SizedBox(height: 3),
              Text(_buildSubtitle(movie), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            ],
            const SizedBox(height: 6),
            if (movie.rating != null) AnimatedStarRating(rating: movie.rating!, starSize: 12, showNumber: true)
            else const SizedBox(height: 14),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
        ]),
      ),
    );
  }

  String _buildSubtitle(Movie movie) {
    final parts = <String>[];
    if (movie.directors.isNotEmpty) parts.add(movie.directors.first);
    if (movie.actors.isNotEmpty) parts.add(movie.actors.take(2).join('、'));
    if (movie.genres.isNotEmpty) parts.add(movie.genres.take(2).join('、'));
    return parts.join(' · ');
  }

  // ─── 大图卡片样式 ───────────────────────────────────────

  Widget _buildCoverCardView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) return _buildLoadMoreIndicator();
        return _buildCoverCard(_items[index]);
      },
    );
  }

  Widget _buildCoverCard(Movie movie) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onMovieTap(movie),
      onLongPress: () => _showDeleteDialog(context, movie),
      child: Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.surfaceContainerHigh,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          // 海报背景
          if (movie.posterPath != null && movie.posterPath!.isNotEmpty)
            FadeInLocalImage(path: movie.posterPath, fit: BoxFit.cover,
                errorWidget: Container(color: colors.surfaceContainerHighest))
          else
            Container(color: colors.surfaceContainerHighest,
                child: Icon(Icons.movie_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.15))),
          // 底部渐变遮罩
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),
          // 底部信息
          Positioned(
            left: 14, right: 14, bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(_buildSubtitle(movie), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                ),
                if (movie.rating != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade400),
                  const SizedBox(width: 2),
                  Text(movie.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildCoverCardSkeleton() {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Movie movie) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除《${movie.title}》吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeMovie(movie.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) _loadFirst();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSkeleton() {
    final layoutStyle = context.read<AppProvider>().movieLayoutStyle;
    if (layoutStyle == 1) return _buildListSkeleton();
    if (layoutStyle == 2) return _buildCoverCardSkeleton();
    return const MovieSkeletonGrid();
  }

  Widget _buildListSkeleton() {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100), itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          ShimmerSkeleton(width: 48, height: 64, borderRadius: 6), SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShimmerSkeleton(width: 160, height: 16), SizedBox(height: 6),
            ShimmerSkeleton(width: 100, height: 12), SizedBox(height: 6),
            ShimmerSkeleton(width: 70, height: 12),
          ])),
          SizedBox(width: 8), ShimmerSkeleton(width: 20, height: 20, borderRadius: 10),
        ]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<AppProvider>();
    final isWallMode = provider.movieWallMode;
    final isCategoryMode = provider.movieDisplayMode == 1;
    final emptyText = isWallMode
        ? '暂无影片'
        : isCategoryMode
            ? '暂无${MovieCategoryBar.categoryLabel(provider.movieCategoryIndex)}'
            : '暂无${['已看', '在看', '想看'][statusIndex]}的影片';
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.movie_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25))),
      const SizedBox(height: 20),
      Text(emptyText, style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
    ]));
  }
}
