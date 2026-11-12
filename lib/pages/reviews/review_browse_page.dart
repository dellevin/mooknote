import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../l10n/app_strings.dart';
import '../../providers/app_provider.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/image_grid_editor.dart';
import '../book/book_detail_page.dart';
import '../movies/movie_detail_page.dart';

/// 影评 / 书评 / 书摘的全局浏览类型
enum ReviewBrowseKind { movieReview, bookReview, bookExcerpt }

/// 全局影评/书评/书摘浏览页：聚合全部记录，瀑布流与列表两种布局可切换
class ReviewBrowsePage extends StatefulWidget {
  final ReviewBrowseKind kind;

  const ReviewBrowsePage({super.key, required this.kind});

  @override
  State<ReviewBrowsePage> createState() => _ReviewBrowsePageState();
}

/// 统一展示条目，屏蔽三类模型的字段差异
class _ReviewItem {
  final String workId;
  final String workTitle;
  final String content;
  final DateTime date;
  final List<String> images;
  final int? reviewType; // 1 短评 / 2 长评；书摘为 null
  final String reviewer;
  final String source;
  final String chapter;
  final String comment;

  const _ReviewItem({
    required this.workId,
    required this.workTitle,
    required this.content,
    required this.date,
    this.images = const [],
    this.reviewType,
    this.reviewer = '',
    this.source = '',
    this.chapter = '',
    this.comment = '',
  });
}

class _ReviewBrowsePageState extends State<ReviewBrowsePage> {
  bool _isLoading = true;
  List<_ReviewItem> _items = [];
  late int _layoutStyle; // 0 瀑布流，1 列表

  bool _isSearching = false;
  String _keyword = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_ReviewItem> get _filteredItems {
    if (_keyword.isEmpty) return _items;
    final kw = _keyword.toLowerCase();
    return _items
        .where((it) =>
            it.workTitle.toLowerCase().contains(kw) ||
            it.content.toLowerCase().contains(kw) ||
            it.reviewer.toLowerCase().contains(kw) ||
            it.source.toLowerCase().contains(kw) ||
            it.chapter.toLowerCase().contains(kw) ||
            it.comment.toLowerCase().contains(kw))
        .toList();
  }

  String get _title => switch (widget.kind) {
        ReviewBrowseKind.movieReview => '影评'.tr,
        ReviewBrowseKind.bookReview => '书评'.tr,
        ReviewBrowseKind.bookExcerpt => '书摘'.tr,
      };

  String get _emptyText => switch (widget.kind) {
        ReviewBrowseKind.movieReview => '暂无影评'.tr,
        ReviewBrowseKind.bookReview => '暂无书评'.tr,
        ReviewBrowseKind.bookExcerpt => '暂无书摘'.tr,
      };

  IconData get _emptyIcon => switch (widget.kind) {
        ReviewBrowseKind.movieReview => Icons.rate_review_outlined,
        ReviewBrowseKind.bookReview => Icons.menu_book_outlined,
        ReviewBrowseKind.bookExcerpt => Icons.format_quote_outlined,
      };

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().reviewBrowseLayoutStyle;
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    final List<_ReviewItem> items;
    switch (widget.kind) {
      case ReviewBrowseKind.movieReview:
        final movieTitle = {for (final m in provider.movies) m.id: m.title};
        items = (await provider.getAllMovieReviews())
            .map((r) => _ReviewItem(
                  workId: r.movieId,
                  workTitle: movieTitle[r.movieId] ?? '',
                  content: r.content,
                  date: r.reviewDate ?? r.createdAt,
                  images: r.images,
                  reviewType: r.reviewType,
                  reviewer: r.reviewer,
                  source: r.source,
                ))
            .toList();
      case ReviewBrowseKind.bookReview:
        final bookTitle = {for (final b in provider.books) b.id: b.title};
        items = (await provider.getAllBookReviews())
            .map((r) => _ReviewItem(
                  workId: r.bookId,
                  workTitle: bookTitle[r.bookId] ?? '',
                  content: r.content,
                  date: r.reviewDate ?? r.createdAt,
                  images: r.images,
                  reviewType: r.reviewType,
                  reviewer: r.reviewer,
                  source: r.source,
                ))
            .toList();
      case ReviewBrowseKind.bookExcerpt:
        final bookTitle = {for (final b in provider.books) b.id: b.title};
        items = (await provider.getAllBookExcerpts())
            .map((e) => _ReviewItem(
                  workId: e.bookId,
                  workTitle: bookTitle[e.bookId] ?? '',
                  content: e.content,
                  date: e.createdAt,
                  chapter: e.chapter,
                  comment: e.comment,
                ))
            .toList();
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _showLayoutSheet() async {
    final colors = Theme.of(context).colorScheme;
    final options = <(int, IconData, String)>[
      (0, Icons.grid_view_rounded, '瀑布流'.tr),
      (1, Icons.view_agenda_rounded, '列表'.tr),
    ];
    // 样式对齐片单页的显示方式弹层：拖拽条 + 分组圆角容器 + 图标色块 + 勾选
    await appModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Container(
                    width: 28,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  '显示方式'.tr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          indent: 56,
                          color: colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      _buildLayoutOption(sheetContext, options[i], colors),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLayoutOption(
    BuildContext sheetContext,
    (int, IconData, String) opt,
    ColorScheme colors,
  ) {
    final selected = _layoutStyle == opt.$1;
    return InkWell(
      onTap: () async {
        final navigator = Navigator.of(sheetContext);
        await UserPrefs().setReviewBrowseLayoutStyle(opt.$1);
        if (!mounted) return;
        setState(() => _layoutStyle = opt.$1);
        navigator.pop();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(opt.$2, size: 17, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.$3,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: colors.onSurface,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 19, color: colors.primary),
          ],
        ),
      ),
    );
  }

  void _openWork(_ReviewItem item) {
    final provider = context.read<AppProvider>();
    if (widget.kind == ReviewBrowseKind.movieReview) {
      final movie = provider.movies.where((m) => m.id == item.workId).firstOrNull;
      if (movie == null) {
        ToastUtil.show(context, '关联作品已删除'.tr);
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => MovieDetailPage(movie: movie)));
    } else {
      final book = provider.books.where((b) => b.id == item.workId).firstOrNull;
      if (book == null) {
        ToastUtil.show(context, '关联作品已删除'.tr);
        return;
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _filteredItems;
    // 展开后的搜索框宽度：为返回键、布局按钮和边距预留空间
    final searchWidth = (MediaQuery.of(context).size.width - 132).clamp(180.0, 320.0);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_title),
        actions: [
          // 搜索按钮向左展开为药丸输入框（AnimatedSize 右对齐生长）
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerRight,
            child: _isSearching
                ? Container(
                    width: searchWidth,
                    height: 40,
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 19, color: colors.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            cursorColor: colors.primary,
                            style: TextStyle(color: colors.onSurface, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '搜索内容、作品或评论人'.tr,
                              hintStyle: TextStyle(
                                  fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35)),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              filled: false,
                            ),
                            onChanged: (v) => setState(() => _keyword = v),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() {
                              _keyword = '';
                              _isSearching = false;
                            });
                          },
                          child: Icon(Icons.close,
                              size: 17, color: colors.onSurface.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: '搜索'.tr,
                    onPressed: () => setState(() => _isSearching = true),
                  ),
          ),
          // 搜索展开时隐藏布局按钮，避免窄屏溢出
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: '显示方式'.tr,
              onPressed: _showLayoutSheet,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary))
          : filtered.isEmpty
              ? _buildEmptyState(colors)
              : _layoutStyle == 0
                  ? _buildMasonry(colors, filtered)
                  : _buildList(colors, filtered),
    );
  }

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_emptyIcon, size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(height: 20),
          Text(
            _keyword.isNotEmpty ? '未找到匹配的内容'.tr : _emptyText,
            style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildMasonry(ColorScheme colors, List<_ReviewItem> items) {
    final columns = MediaQuery.of(context).size.width >= 900 ? 3 : 2;
    return MasonryGridView.count(
      crossAxisCount: columns,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildCard(items[index], colors, isList: false),
    );
  }

  Widget _buildList(ColorScheme colors, List<_ReviewItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _buildCard(items[index], colors, isList: true),
    );
  }

  Widget _buildCard(_ReviewItem item, ColorScheme colors, {required bool isList}) {
    final isExcerpt = widget.kind == ReviewBrowseKind.bookExcerpt;
    final contentMaxLines = isExcerpt
        ? (isList ? 10 : 8)
        : item.reviewType == 1
            ? (isList ? 6 : 4)
            : (isList ? 12 : 8);

    return InkWell(
      onTap: () => _openWork(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 所属作品
            Row(
              children: [
                SvgPicture.asset(
                  widget.kind == ReviewBrowseKind.movieReview
                      ? 'assets/svg/ying_shi.svg'
                      : 'assets/svg/shu_ji.svg',
                  width: 13,
                  height: 13,
                  colorFilter: ColorFilter.mode(
                    colors.onSurface.withValues(alpha: 0.4),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.workTitle.isEmpty ? '关联作品已删除'.tr : item.workTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!isExcerpt) ...[
              // 短评/长评标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.reviewType == 1 ? colors.surface : colors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (item.reviewType == 1 ? '短评' : '长评').tr,
                  style: TextStyle(
                    fontSize: 10,
                    color: item.reviewType == 1
                        ? colors.onSurface.withValues(alpha: 0.6)
                        : colors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (item.chapter.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.chapter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // 正文
            Text(
              item.content,
              maxLines: contentMaxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: colors.onSurface,
                fontStyle: isExcerpt ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            // 书摘感悟
            if (isExcerpt && item.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.comment,
                maxLines: isList ? 6 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.5, color: colors.onSurface.withValues(alpha: 0.55)),
              ),
            ],
            // 图片
            if (item.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              ReviewImageThumb(images: item.images),
            ],
            const SizedBox(height: 12),
            // 底部信息
            Row(
              children: [
                if (item.reviewer.isNotEmpty)
                  Expanded(
                    child: Text(
                      item.reviewer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
                    ),
                  ),
                if (item.source.isNotEmpty)
                  Expanded(
                    child: Text(
                      item.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ),
                Text(
                  _formatDate(item.date),
                  style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
