import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/game_status_bar.dart';
import '../../widgets/game_list_item.dart';
import '../../widgets/animated_star_rating.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../utils/responsive.dart';
import '../../widgets/master_detail_scaffold.dart';
import '../../widgets/detail_placeholder.dart';
import 'game_detail_page.dart';
import 'game_add_page.dart';

/// 游戏标签页（分页 + 触底加载）
class GameTabPage extends StatefulWidget {
  const GameTabPage({super.key});

  @override
  State<GameTabPage> createState() => _GameTabPageState();
}

class _GameTabPageState extends State<GameTabPage> {
  final List<Game> _items = [];
  bool _hasMore = true;
  bool _isLoading = false;
  int _offset = 0;
  bool _initialized = false;
  int _lastStatusIndex = -1;
  late ScrollController _scrollController;
  AppProvider? _provider;
  int _lastScrollSignal = 0;
  int _lastEditRefreshCounter = 0;
  int _prevGameCount = -1;
  int _prevLayoutStyle = -1;
  double _swipeOffset = 0.0;

  static const _statusMap = {0: 'completed', 1: 'playing', 2: 'want_to_play', 3: 'abandoned'};

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

    if (provider.scrollToTopSignal != _lastScrollSignal && provider.scrollToTopSignal > 0) {
      _lastScrollSignal = provider.scrollToTopSignal;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }

    final statusChanged = provider.gameStatusIndex != _lastStatusIndex;
    final layoutChanged = provider.gameLayoutStyle != _prevLayoutStyle;
    final countChanged = provider.games.length != _prevGameCount;
    final editRefreshed = provider.editRefreshCounter > _lastEditRefreshCounter;
    if (editRefreshed && provider.lastEditedItemId != null) {
      _lastEditRefreshCounter = provider.editRefreshCounter;
      _prevGameCount = provider.games.length;
      final editedId = provider.lastEditedItemId!;
      final idx = _items.indexWhere((g) => g.id == editedId);
      final updated = provider.games.where((g) => g.id == editedId).firstOrNull;
      if (updated != null) {
        final isWallMode = provider.gameWallMode;
        final currentStatus = isWallMode ? null : (_statusMap[provider.gameStatusIndex] ?? 'completed');
        if (currentStatus != null && updated.status != currentStatus) {
          // 状态已变更，从当前列表移除
          if (idx != -1) {
            setState(() { _items.removeAt(idx); });
          }
        } else if (idx != -1) {
          setState(() { _items[idx] = updated; });
        }
      } else if (idx != -1) {
        // 游戏已被删除，从列表移除
        setState(() { _items.removeAt(idx); });
      }
      return;
    }
    if (statusChanged || layoutChanged || countChanged || editRefreshed) {
      _prevLayoutStyle = provider.gameLayoutStyle;
      _prevGameCount = provider.games.length;
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
    final isWallMode = provider.gameWallMode;
    final statusIdx = provider.gameStatusIndex;
    _lastStatusIndex = statusIdx;
    _initialized = true;
    final status = isWallMode ? null : (_statusMap[statusIdx] ?? 'completed');
    final sortMode = UserPrefs().gameSortMode;
    setState(() { _isLoading = true; _offset = 0; _hasMore = true; });
    final list = await provider.loadGamesPaged(status: status, offset: 0, sortMode: sortMode);
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
    final isWallMode = provider.gameWallMode;
    final status = isWallMode ? null : (_statusMap[provider.gameStatusIndex] ?? 'completed');
    final sortMode = UserPrefs().gameSortMode;
    final list = await provider.loadGamesPaged(status: status, offset: _offset, sortMode: sortMode);
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
    await provider.loadGames();
    await _loadFirst();
  }

  void _onGameTap(Game game) {
    if (Breakpoint.isWideContent(context)) {
      context.read<AppProvider>().selectGame(game);
    } else {
      Navigator.pushNamed(context, '/game-detail', arguments: game);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideContent = Breakpoint.isWideContent(context);
    final provider = context.watch<AppProvider>();
    final isWallMode = provider.gameWallMode;

    final masterContent = Column(
      children: [
        if (!isWallMode) const GameStatusBar(),
        Expanded(child: _buildBody(context)),
      ],
    );

    if (!isWideContent) return masterContent;

    final selectedGame = provider.selectedGame;
    final detailWidget = provider.isAdding && provider.addingType == 3
        ? GameAddPage(onCancel: () => provider.cancelAdding())
        : selectedGame != null
            ? GameDetailPage(game: selectedGame, embedded: true)
            : const DetailPlaceholder(icon: Icons.sports_esports_outlined, message: '选择一款游戏查看详情');
    return MasterDetailScaffold(
      master: masterContent,
      detail: detailWidget,
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        if (_initialized && provider.gameStatusIndex != _lastStatusIndex) {
          _lastStatusIndex = provider.gameStatusIndex;
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
                children: [_buildEmptyState(context, provider.gameStatusIndex)],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: colors.primary,
            backgroundColor: colors.surface,
            child: provider.gameLayoutStyle == 1 ? _buildListView() : provider.gameLayoutStyle == 2 ? _buildCoverCardView() : _buildGridView(),
          );
        }();

        return GestureDetector(
          onHorizontalDragStart: (_) => _swipeOffset = 0.0,
          onHorizontalDragUpdate: (details) => setState(() => _swipeOffset += details.primaryDelta ?? 0),
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity;
            if ((velocity ?? 0).abs() < 80) {
              setState(() => _swipeOffset = 0.0);
              return;
            }
            final direction = (velocity ?? 0) > 0 ? -1 : 1;
            final currentIndex = provider.gameStatusIndex;
            final newIndex = (currentIndex + direction + 4) % 4;
            setState(() => _swipeOffset = 0.0);
            provider.setGameStatusIndex(newIndex);
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
            return GameListItem(
              game: item,
              selected: isWideContent && provider.selectedGame?.id == item.id,
              onTap: () => _onGameTap(item),
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

  Widget _buildListCard(Game game) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onGameTap(game),
      onLongPress: () => _showDeleteDialog(context, game),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 48, height: 64,
            decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: game.coverPath != null && game.coverPath!.isNotEmpty
                ? FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover,
                    errorWidget: Icon(Icons.sports_esports_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)))
                : Icon(Icons.sports_esports_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 3),
            Text(_buildSubtitle(game), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            const SizedBox(height: 6),
            if (game.rating != null) AnimatedStarRating(rating: game.rating!, starSize: 12, showNumber: true)
            else const SizedBox(height: 14),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
        ]),
      ),
    );
  }

  String _buildSubtitle(Game game) {
    final parts = <String>[];
    if (game.platforms.isNotEmpty) parts.add(game.platforms.take(2).join('、'));
    if (game.genres.isNotEmpty) parts.add(game.genres.take(2).join('、'));
    if (game.playTimeHours > 0 || game.playTimeMinutes > 0) {
      parts.add('${game.playTimeHours}时${game.playTimeMinutes}分');
    }
    return parts.join(' · ');
  }

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

  Widget _buildCoverCard(Game game) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onGameTap(game),
      onLongPress: () => _showDeleteDialog(context, game),
      child: Container(
        height: 200,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colors.surfaceContainerHigh,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (game.coverPath != null && game.coverPath!.isNotEmpty)
            FadeInLocalImage(path: game.coverPath, fit: BoxFit.cover,
                errorWidget: Container(color: colors.surfaceContainerHighest))
          else
            Container(color: colors.surfaceContainerHighest,
                child: Icon(Icons.sports_esports_outlined, size: 48, color: colors.onSurface.withValues(alpha: 0.15))),
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
          Positioned(
            left: 14, right: 14, bottom: 14,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(game.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: Text(_buildSubtitle(game), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                ),
                if (game.rating != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade400),
                  const SizedBox(width: 2),
                  Text(game.rating!.toStringAsFixed(1),
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

  void _showDeleteDialog(BuildContext context, Game game) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除《${game.title}》吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeGame(game.id);
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
    final layoutStyle = context.read<AppProvider>().gameLayoutStyle;
    if (layoutStyle == 1) return _buildListSkeleton();
    if (layoutStyle == 2) return _buildCoverCardSkeleton();
    return const GameSkeletonGrid();
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
    final isWallMode = provider.gameWallMode;
    final statusText = isWallMode ? '' : ['已通关', '在玩', '想玩', '弃游'][statusIndex];
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.sports_esports_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25))),
      const SizedBox(height: 20),
      Text(isWallMode ? '暂无游戏' : '暂无$statusText的游戏', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
    ]));
  }
}
