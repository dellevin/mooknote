import 'package:flutter/material.dart';
import '../../utils/book/book_dao.dart';
import '../../utils/epub/reader_dao.dart';
import '../../models/data_models.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已关联《${book.title}》')),
      );
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: '搜索书名或作者...',
                hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
                prefixIcon: Icon(Icons.search, size: 20, color: colors.onSurface.withValues(alpha: 0.4)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // 书籍列表
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: colors.primary))
                : _filteredBooks.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty ? '暂无书籍' : '未找到匹配的书籍',
                          style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filteredBooks.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 0.5, indent: 72, color: colors.outlineVariant),
                        itemBuilder: (_, index) => _buildBookTile(_filteredBooks[index], colors),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookTile(Book book, ColorScheme colors) {
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    return InkWell(
      onTap: () => _selectBook(book),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // 封面缩略图
          Container(
            width: 44, height: 62,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasCover
                ? Image.asset(book.coverPath!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.book_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.2)))
                : Icon(Icons.book_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          const SizedBox(width: 14),
          // 书名 + 作者
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
                if (book.authors.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(book.authors.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
        ]),
      ),
    );
  }
}
