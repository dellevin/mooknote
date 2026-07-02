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
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/master_detail_scaffold.dart';
import '../../widgets/detail_placeholder.dart';
import 'book_detail_page.dart';

/// 阅读标签页（分页 + 触底加载）
class BookTabPage extends StatefulWidget {
  const BookTabPage({super.key});

  @override
  State<BookTabPage> createState() => _BookTabPageState();
}

class _BookTabPageState extends State<BookTabPage> {
  int _layoutStyle = 0;
  final List<Book> _items = [];
  bool _hasMore = true;
  bool _isLoading = false;
  int _offset = 0;
  int _lastStatusIndex = -1;
  bool _initialized = false;
  late ScrollController _scrollController;
  AppProvider? _provider;
  int _lastScrollSignal = 0;
  int _lastEditRefreshCounter = 0;
  int _prevBookCount = -1;
  double _dragDelta = 0.0; // 当前拖动偏移量

  void _onBookTap(Book book) {
    if (Breakpoint.isWideContent(context)) {
      context.read<AppProvider>().selectBook(book);
    } else {
      Navigator.pushNamed(context, '/book-detail', arguments: book);
    }
  }

  static const _statusMap = {0: 'read', 1: 'reading', 2: 'want_to_read', 3: 'abandoned'};

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().bookLayoutStyle;
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

    // 仅在数据实际变化时刷新列表，避免底部导航栏显隐等UI变化误触发重载
    final statusChanged = provider.bookStatusIndex != _lastStatusIndex;
    final countChanged = provider.books.length != _prevBookCount;
    final editRefreshed = provider.editRefreshCounter > _lastEditRefreshCounter;
    if (statusChanged || countChanged || editRefreshed) {
      _prevBookCount = provider.books.length;
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
    final isWallMode = provider.bookshelfMode;
    final statusIdx = provider.bookStatusIndex;
    _lastStatusIndex = statusIdx;
    _initialized = true;
    // 书架模式：不筛选状态，使用用户选择的排序（默认创建时间）
    final status = isWallMode ? null : (_statusMap[statusIdx] ?? 'read');
    final sortMode = UserPrefs().bookSortMode;
    setState(() { _isLoading = true; _offset = 0; _hasMore = true; });
    final list = await provider.loadBooksPaged(status: status, offset: 0, sortMode: sortMode);
    if (!mounted) return;
    setState(() { _items.clear(); _items.addAll(list); _offset = list.length; _hasMore = list.length >= 20; _isLoading = false; });
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final isWallMode = provider.bookshelfMode;
    final status = isWallMode ? null : (_statusMap[provider.bookStatusIndex] ?? 'read');
    final sortMode = UserPrefs().bookSortMode;
    final list = await provider.loadBooksPaged(status: status, offset: _offset, sortMode: sortMode);
    if (!mounted) return;
    setState(() { _items.addAll(list); _offset += list.length; _hasMore = list.length >= 20; _isLoading = false; });
  }

  Future<void> _refresh() async {
    await context.read<AppProvider>().loadBooks();
    await _loadFirst();
  }

  @override
  Widget build(BuildContext context) {
    final isWideContent = Breakpoint.isWideContent(context);
    final provider = context.watch<AppProvider>();
    final isWallMode = provider.bookshelfMode;
    final masterContent = Column(children: [
      if (!isWallMode) const BookStatusBar(),
      Expanded(child: _buildBody(context)),
    ]);

    if (!isWideContent) return masterContent;

    final selectedBook = provider.selectedBook;
    return MasterDetailScaffold(
      master: masterContent,
      detail: selectedBook != null
          ? BookDetailPage(book: selectedBook, embedded: true)
          : const DetailPlaceholder(icon: Icons.menu_book_outlined, message: '选择一本书查看详情'),
    );
  }

  Widget _buildBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 用 GestureDetector 包裹，左右滑动切换状态
    return GestureDetector(
      onHorizontalDragStart: (_) => _dragDelta = 0.0,
      onHorizontalDragUpdate: (details) => setState(() => _dragDelta += details.primaryDelta ?? 0),
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity;
        if ((velocity ?? 0).abs() < 80) {
          setState(() => _dragDelta = 0.0);
          return;
        }
        final direction = (velocity ?? 0) > 0 ? -1 : 1; // 右滑→上一个，左滑→下一个
        final provider = context.read<AppProvider>();
        final currentIndex = provider.bookStatusIndex;
        final newIndex = (currentIndex + direction + 4) % 4;
        setState(() => _dragDelta = 0.0);
        provider.setBookStatusIndex(newIndex);
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: _dragDelta.clamp(-100.0, 100.0)),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(offset: Offset(value, 0), child: child);
        },
        child: Consumer<AppProvider>(builder: (context, provider, _) {
          if (_initialized && provider.bookStatusIndex != _lastStatusIndex) {
            _lastStatusIndex = provider.bookStatusIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) => _loadFirst());
          }
          final content = () {
            if (_items.isEmpty && _isLoading) return _buildSkeleton();
            if (_items.isEmpty) {
              return RefreshIndicator(onRefresh: _refresh, color: colors.primary, backgroundColor: colors.surface,
                  child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [_buildEmptyState(context, provider.bookStatusIndex)]));
            }
            return RefreshIndicator(onRefresh: _refresh, color: colors.primary, backgroundColor: colors.surface,
                child: _layoutStyle == 1 ? _buildListView() : _buildGridView());
          }();
          return content;
        }),
      ),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = responsiveCrossAxisCount(constraints.maxWidth, minItemWidth: 110);
      return GridView.builder(controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount, childAspectRatio: 0.55, crossAxisSpacing: 12, mainAxisSpacing: 16),
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
    });
  }

  Widget _buildListView() {
    return ListView.builder(controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) return _buildLoadMore();
        return _buildListCard(_items[index]);
      },
    );
  }

  Widget _buildLoadMore() {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(child: _isLoading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
          : Text('没有更多了', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)))),
    );
  }

  Widget _buildListCard(Book book) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _onBookTap(book),
      onLongPress: () => _showDeleteDialog(context, book),
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(width: 48, height: 64,
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
            if (book.authors.isNotEmpty) ...[const SizedBox(height: 3),
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
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: colors.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
      content: Text('确定要删除《${book.title}》吗？删除后可在回收站恢复。',
          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
        ElevatedButton(onPressed: () async { await context.read<AppProvider>().removeBook(book.id); Navigator.pop(ctx); _loadFirst(); },
          style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
          child: const Text('删除'),
        ),
      ],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ));
  }

  Widget _buildSkeleton() => _layoutStyle == 1 ? const MovieSkeletonGrid() : const BookSkeletonGrid();

  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<AppProvider>();
    final isWallMode = provider.bookshelfMode;
    final statusText = isWallMode ? '' : ['已读', '在读', '想读', '弃读'][statusIndex];
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
          child: Icon(Icons.menu_book_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25))),
      const SizedBox(height: 20),
      Text(isWallMode ? '暂无书籍' : '暂无$statusText的书籍', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
    ]));
  }
}
