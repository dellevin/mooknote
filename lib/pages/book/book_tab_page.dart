import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../utils/responsive.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/book_status_bar.dart';
import '../../widgets/book_list_item.dart';
import '../../widgets/animated_star_rating.dart';
import '../../widgets/shimmer_skeleton.dart';
import '../../widgets/top_fade_scrim.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/master_detail_scaffold.dart';
import '../../widgets/detail_placeholder.dart';
import 'book_detail_page.dart';
import 'book_add_page.dart';
import '../../widgets/app_overlay.dart';

/// 状态索引 → 状态值
const _bookStatusMap = {0: 'read', 1: 'reading', 2: 'want_to_read', 3: 'abandoned'};

/// 阅读标签页（PageView 分页 + 触底加载），左右滑动丝滑切换
class BookTabPage extends StatefulWidget {
  const BookTabPage({super.key});

  @override
  State<BookTabPage> createState() => _BookTabPageState();
}

class _BookTabPageState extends State<BookTabPage> {
  late PageController _pageController;
  int _currentPage = 0; // PageView 当前页的唯一真源
  int? _pendingTarget; // 待跟随的页，避免重复调度动画
  int _lastModeSignature = -1; // 编码 wall 模式，检测书架/状态切换
  bool _modeInitialized = false; // 吞掉首次构建的伪"变化"

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // 应用启动时保存的初始索引（可能 > 0）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<AppProvider>();
      final initial = _activeIndexFor(p).clamp(0, _pageCountFor(p) - 1);
      _currentPage = initial;
      if (_pageController.hasClients && initial != 0) _pageController.jumpToPage(initial);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _pageCountFor(AppProvider p) => p.bookshelfMode ? 1 : 4;

  int _activeIndexFor(AppProvider p) => p.bookshelfMode ? 0 : p.bookStatusIndex;

  int _modeSignature(AppProvider p) => p.bookshelfMode ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final isWideContent = Breakpoint.isWideContent(context);
    final provider = context.watch<AppProvider>();
    final isWallMode = provider.bookshelfMode;

    final masterContent = Column(
      children: [
        if (!isWallMode) const BookStatusBar(),
        Expanded(
          child: Stack(
            children: [
              _buildPageView(provider),
              if (!isWallMode) const TopFadeScrim(),
            ],
          ),
        ),
      ],
    );

    if (!isWideContent) return masterContent;

    final selectedBook = provider.selectedBook;
    final detailWidget = provider.isAdding && provider.addingType == 1
        ? BookAddPage(onCancel: () => provider.cancelAdding())
        : selectedBook != null
            ? BookDetailPage(book: selectedBook, embedded: true)
            : const DetailPlaceholder(icon: Icons.menu_book_outlined, message: '选择一本书查看详情');
    return MasterDetailScaffold(
      master: masterContent,
      detail: detailWidget,
    );
  }

  Widget _buildPageView(AppProvider provider) {
    final wall = provider.bookshelfMode;
    final pageCount = _pageCountFor(provider);
    final mode = wall ? 1 : 0;

    // (a) 首次构建作为基线，不当成模式切换
    if (!_modeInitialized) {
      _modeInitialized = true;
      _lastModeSignature = _modeSignature(provider);
    }
    // (b) 模式切换（书架 <-> 状态）：跳到第 0 页 + 重置索引
    else if (_modeSignature(provider) != _lastModeSignature) {
      _lastModeSignature = _modeSignature(provider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _currentPage = 0;
        _pendingTarget = null;
        if (!wall) provider.setBookStatusIndex(0);
        _pageController.jumpToPage(0);
      });
    }
    // (c) 外部索引变化（bar 点击等）：动画跟随
    final target = _activeIndexFor(provider).clamp(0, pageCount - 1);
    if (pageCount > 1 && _pageController.hasClients && target != _currentPage && _pendingTarget != target) {
      _pendingTarget = target;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: pageCount,
      allowImplicitScrolling: true, // 拖动时预构建相邻页 → 无白色空隙
      onPageChanged: (index) => _onPageChanged(index, provider),
      itemBuilder: (context, index) => _BookTabView(
        key: ValueKey('$mode-$index'), // 模式切换时全部重建
        index: index,
        mode: mode,
      ),
    );
  }

  void _onPageChanged(int index, AppProvider provider) {
    _currentPage = index;
    _pendingTarget = null;
    final wall = provider.bookshelfMode;
    final cur = wall ? 0 : provider.bookStatusIndex;
    // 回显守卫：仅在真实拖动导致索引变化时推送，避免死循环
    if (cur != index) {
      if (!wall) provider.setBookStatusIndex(index);
    }
  }
}

/// 单页：独立持有列表数据、滚动与分页状态，滑走再滑回保留状态
class _BookTabView extends StatefulWidget {
  final int index; // 0..pageCount-1
  final int mode; // 0=status, 1=wall(书架)
  const _BookTabView({super.key, required this.index, required this.mode});

  @override
  State<_BookTabView> createState() => _BookTabViewState();
}

class _BookTabViewState extends State<_BookTabView>
    with AutomaticKeepAliveClientMixin {
  final List<Book> _items = [];
  bool _hasMore = true;
  bool _isLoading = false;
  int _offset = 0;
  bool _initialized = false;
  int _layoutStyle = 0;
  late ScrollController _scrollController;
  AppProvider? _provider;
  int _lastScrollSignal = 0;
  int _lastEditRefreshCounter = 0;
  int _prevBookCount = -1;
  int _prevSortMode = -1;

  String? get _status => widget.mode == 0 ? _bookStatusMap[widget.index] : null;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().bookLayoutStyle;
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<AppProvider>();
      _provider = p;
      _lastEditRefreshCounter = p.editRefreshCounter;
      _lastScrollSignal = p.scrollToTopSignal;
      _prevBookCount = p.books.length;
      _prevSortMode = UserPrefs().bookSortMode;
      p.addListener(_onDataChanged);
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
    final p = context.read<AppProvider>();

    // 回到顶部信号：每页滚自己的 controller
    if (p.scrollToTopSignal != _lastScrollSignal) {
      _lastScrollSignal = p.scrollToTopSignal;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }

    // 就地编辑：更新本页匹配项，不重置分页
    if (p.editRefreshCounter > _lastEditRefreshCounter && p.lastEditedItemId != null) {
      _lastEditRefreshCounter = p.editRefreshCounter;
      _prevBookCount = p.books.length;
      final id = p.lastEditedItemId!;
      final i = _items.indexWhere((b) => b.id == id);
      if (i != -1) {
        final u = p.books.where((b) => b.id == id).firstOrNull;
        if (u != null) setState(() => _items[i] = u);
      }
      return;
    }

    // 排序/数量变化才重新拉取（布局变化由 context.select 原地重渲染）
    final sortChanged = UserPrefs().bookSortMode != _prevSortMode;
    final countChanged = p.books.length != _prevBookCount;
    if (sortChanged || countChanged) {
      _prevSortMode = UserPrefs().bookSortMode;
      _prevBookCount = p.books.length;
      _loadFirst();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    final provider = context.read<AppProvider>();
    final sortMode = UserPrefs().bookSortMode;
    _initialized = true;
    setState(() { _isLoading = true; _offset = 0; _hasMore = true; });
    final list = await provider.loadBooksPaged(status: _status, offset: 0, sortMode: sortMode);
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
    final sortMode = UserPrefs().bookSortMode;
    final list = await provider.loadBooksPaged(status: _status, offset: _offset, sortMode: sortMode);
    if (!mounted) return;
    setState(() {
      _items.addAll(list);
      _offset += list.length;
      _hasMore = list.length >= 20;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    await context.read<AppProvider>().loadBooks();
    await _loadFirst();
  }

  void _onBookTap(Book book) {
    if (Breakpoint.isWideContent(context)) {
      context.read<AppProvider>().selectBook(book);
    } else {
      Navigator.pushNamed(context, '/book-detail', arguments: book);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = Theme.of(context).colorScheme;

    final content = () {
      if (_items.isEmpty && _isLoading) return _buildSkeleton(_layoutStyle);
      if (_items.isEmpty) {
        return RefreshIndicator(
          onRefresh: _refresh,
          color: colors.primary,
          backgroundColor: colors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [_buildEmptyState()],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        color: colors.primary,
        backgroundColor: colors.surface,
        child: _layoutStyle == 1 ? _buildListView() : _buildGridView(),
      );
    }();
    return content;
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount, childAspectRatio: 0.55, crossAxisSpacing: 12, mainAxisSpacing: 16,
          ),
          itemCount: _items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _items.length) return _buildLoadMore();
            final item = _items[index];
            final provider = context.read<AppProvider>();
            return BookListItem(
              book: item,
              selected: Breakpoint.isWideContent(context) && provider.selectedBook?.id == item.id,
              onTap: () => _onBookTap(item),
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
        if (index >= _items.length) return _buildLoadMore();
        return _buildListCard(_items[index]);
      },
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoading
            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
            : Text('没有更多了', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
      ),
    );
  }

  Widget _buildListCard(Book book) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onBookTap(book),
      onLongPress: () => _showDeleteDialog(context, book),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            width: 48, height: 64,
            decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(6)),
            clipBehavior: Clip.antiAlias,
            child: book.coverPath != null && book.coverPath!.isNotEmpty
                ? FadeInLocalImage(path: book.coverPath, fit: BoxFit.cover,
                    errorWidget: Icon(Icons.menu_book_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)))
                : Icon(Icons.menu_book_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
            if (book.authors.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(book.authors.take(2).join('、'), maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
            ],
            const SizedBox(height: 6),
            if (book.rating != null) AnimatedStarRating(rating: book.rating!, starSize: 12, showNumber: true)
            else const SizedBox(height: 14),
          ])),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.2), size: 20),
        ]),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Book book) {
    final colors = Theme.of(context).colorScheme;
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定要删除《${book.title}》吗？删除后可在回收站恢复。',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(book.id);
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

  Widget _buildSkeleton(int layoutStyle) => layoutStyle == 1 ? const MovieSkeletonGrid() : const BookSkeletonGrid();

  Widget _buildEmptyState() {
    final colors = Theme.of(context).colorScheme;
    final statusText = widget.mode == 1 ? '' : ['已读', '在读', '想读', '弃读'][widget.index];
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.menu_book_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25))),
      const SizedBox(height: 20),
      Text(widget.mode == 1 ? '暂无书籍' : '暂无$statusText的书籍',
          style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
    ]));
  }
}