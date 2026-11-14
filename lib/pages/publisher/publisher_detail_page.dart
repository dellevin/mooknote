import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../services/cloud/cloud_domain_data_service.dart';
import '../../l10n/app_strings.dart';
import '../../utils/toast_util.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/publisher_avatar.dart';
import '../../widgets/app_back_button.dart';
import '../book/book_detail_page.dart';

/// 出版社详情页（只读：按社名精确匹配书籍 publisher 文本）。
/// 本地模式从内存书籍过滤；云模式走服务端 publisher 过滤分页，避免首页 50 条上限导致缺书。
class PublisherDetailPage extends StatefulWidget {
  final String publisherName;

  const PublisherDetailPage({super.key, required this.publisherName});

  @override
  State<PublisherDetailPage> createState() => _PublisherDetailPageState();
}

class _PublisherDetailPageState extends State<PublisherDetailPage> {
  List<Book> _cloudBooks = const [];
  bool _loading = true;
  bool _error = false;

  String get _publisherName => widget.publisherName;

  @override
  void initState() {
    super.initState();
    if (UserPrefs().cloudBookMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCloudBooks());
    } else {
      _loading = false;
    }
  }

  /// 按出版社过滤分页拉全：单社书籍量一般不大，循环到取完 total。
  /// [showLoading] 为 false 时用于下拉刷新：保留当前列表，不切全屏加载态
  Future<void> _loadCloudBooks({bool showLoading = true}) async {
    setState(() {
      if (showLoading) _loading = true;
      _error = false;
    });
    try {
      const pageSize = 50;
      var offset = 0;
      var total = 1;
      final collected = <Book>[];
      while (offset < total) {
        final page = await CloudDomainDataService.instance.pageMain(
          'books',
          Book.fromJson,
          publisher: _publisherName,
          offset: offset,
          limit: pageSize,
        );
        total = page.total;
        collected.addAll(page.list);
        offset += page.list.length;
        if (page.list.isEmpty) break;
      }
      if (!mounted) return;
      setState(() {
        _cloudBooks = collected;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // 静默刷新失败且已有数据时保留列表，仅 Toast 提示
        if (showLoading || _cloudBooks.isEmpty) _error = true;
      });
      if (!showLoading && _cloudBooks.isNotEmpty && mounted) {
        ToastUtil.show(context, '加载失败，请检查网络'.tr);
      }
    }
  }

  /// 下拉刷新：云模式静默重拉，本地模式重新全量加载书籍
  Future<void> _refresh() async {
    if (UserPrefs().cloudBookMode) {
      await _loadCloudBooks(showLoading: false);
    } else {
      await context.read<AppProvider>().loadBooks();
    }
  }

  /// 非列表态（加载/错误）包成可滚动容器，使 RefreshIndicator 内容不足一屏时也能下拉
  Widget _buildRefreshPlaceholder(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (UserPrefs().cloudBookMode) {
      return Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          leading: const AppBackButton(),
          title: Text(_publisherName),
        ),
        body: _loading
            ? RefreshIndicator(
                onRefresh: _refresh,
                child: _buildRefreshPlaceholder(
                  Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary)),
                ),
              )
            : _error
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    child: _buildRefreshPlaceholder(
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 48, color: colors.onSurface.withValues(alpha: 0.25)),
                            const SizedBox(height: 16),
                            Text(
                              '加载失败，请检查网络'.tr,
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(onPressed: _loadCloudBooks, child: Text('重试'.tr)),
                          ],
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: _buildContent(context, _cloudBooks, colors),
                  ),
      );
    }

    final books = context
        .watch<AppProvider>()
        .books
        .where((b) => !b.isDeleted && (b.publisher?.trim() ?? '') == _publisherName)
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_publisherName),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildContent(context, books, colors),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Book> books, ColorScheme colors) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(books.length, colors),
          const SizedBox(height: 16),
          Divider(height: 0.5, thickness: 0.5, color: colors.outline),
          const SizedBox(height: 16),
          Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('书籍 ({n})'.trf({'n': books.length}), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ]),
          const SizedBox(height: 12),
          _buildBooksSection(context, books, colors),
        ],
      ),
    );
  }

  Widget _buildHeader(int bookCount, ColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PublisherAvatar(
          size: 72,
          iconSize: 32,
          borderRadius: 12,
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                _publisherName,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                '书籍 ({n})'.trf({'n': bookCount}),
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBooksSection(BuildContext context, List<Book> books, ColorScheme colors) {
    if (books.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('暂无相关书籍'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final book in books) _buildBookItem(context, book, colors)],
    );
  }

  Widget _buildBookItem(BuildContext context, Book book, ColorScheme colors) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => BookDetailPage(book: book),
      )),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 50,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasCover
                  ? FadeInLocalImage(path: book.coverPath, fit: BoxFit.cover)
                  : Center(child: Icon(Icons.menu_book_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.2))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(book.authors.join('、'), style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
