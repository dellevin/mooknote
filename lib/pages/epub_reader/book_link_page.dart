import 'package:flutter/material.dart';
import '../../utils/book/book_dao.dart';
import '../../utils/epub/reader_dao.dart';
import '../../utils/toast_util.dart';
import '../../models/data_models.dart';
import '../../widgets/fade_in_local_image.dart';

/// 选择关联书籍页面（带搜索功能）
class BookLinkPage extends StatefulWidget {
  final String readerBookId;

  const BookLinkPage({super.key, required this.readerBookId});

  @override
  State<BookLinkPage> createState() => _BookLinkPageState();
}

class _BookLinkPageState extends State<BookLinkPage> {
  final BookDao _bookDao = BookDao();
  final ReaderDao _readerDao = ReaderDao();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Book> _allBooks = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final books = await _bookDao.getAllBooks();
    if (mounted) {
      setState(() {
        _allBooks = books;
        _filteredBooks = books;
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    _query = query.trim().toLowerCase();
    if (_query.isEmpty) {
      setState(() => _filteredBooks = _allBooks);
      return;
    }
    setState(() {
      _filteredBooks = _allBooks.where((b) {
        return b.title.toLowerCase().contains(_query) ||
            b.authors.any((a) => a.toLowerCase().contains(_query));
      }).toList();
    });
  }

  Future<void> _selectBook(Book book) async {
    await _readerDao.linkToBook(widget.readerBookId, book.id);
    if (mounted) {
      ToastUtil.show(context, '已关联《${book.title}》');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('关联书籍',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(colors),
          // 书籍列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : _filteredBooks.isEmpty
                    ? _buildEmptyState(colors)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _filteredBooks.length,
                        itemBuilder: (_, index) => _buildBookCard(_filteredBooks[index], colors, index),
                      ),
          ),
        ],
      ),
    );
  }

  // ── 搜索栏 ──

  Widget _buildSearchBar(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: _onSearch,
          style: TextStyle(fontSize: 14, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '搜索书名或作者…',
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(Icons.search_rounded, size: 20, color: colors.onSurface.withValues(alpha: 0.35)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: _query.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _onSearch('');
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            filled: true,
            fillColor: colors.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colors.primary.withValues(alpha: 0.5), width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  // ── 空状态 ──

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _query.isEmpty ? Icons.library_books_outlined : Icons.search_off_rounded,
                size: 36,
                color: colors.onSurface.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _query.isEmpty ? '暂无书籍' : '未找到匹配的书籍',
              style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 书籍卡片 ──

  Widget _buildBookCard(Book book, ColorScheme colors, int index) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: index < _filteredBooks.length - 1 ? 10 : 0),
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectBook(book),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面
                Container(
                  width: 48,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasCover
                      ? FadeInLocalImage(
                          path: book.coverPath,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Icon(Icons.menu_book_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.2)),
                        ),
                ),
                const SizedBox(width: 14),
                // 书名 + 作者
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3),
                      ),
                      if (book.authors.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          book.authors.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                      if (book.genres.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: book.genres.take(2).map((g) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              g,
                              style: TextStyle(fontSize: 10, color: colors.primary.withValues(alpha: 0.6)),
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 关联图标
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.link_rounded, size: 14, color: colors.primary),
                      const SizedBox(width: 4),
                      Text('关联', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
