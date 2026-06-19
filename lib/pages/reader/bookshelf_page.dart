import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reader_book.dart';
import '../../providers/app_provider.dart';
import '../../service/book_import_service.dart';
import 'reader_book_detail_page.dart';

/// 书架页面 — 展示导入的阅读器书籍，支持网格/列表切换
class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  bool _isGridView = true;

  Future<void> _importBook() async {
    final provider = context.read<AppProvider>();
    await BookImportService.pickAndImportBook(context, provider);
  }

  void _openBookDetail(ReaderBook book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderBookDetailPage(book: book),
      ),
    ).then((_) {
      context.read<AppProvider>().loadReaderBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('阅读器'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? '列表视图' : '网格视图',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '导入书籍',
            onPressed: _importBook,
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final books = provider.readerBooks;

          if (books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined, size: 64, color: colors.onSurface.withValues(alpha: 0.15)),
                  const SizedBox(height: 16),
                  Text('点击右上角导入书籍',
                      style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3))),
                ],
              ),
            );
          }

          if (_isGridView) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.65,
              ),
              itemCount: books.length,
              itemBuilder: (context, index) => _buildGridViewItem(books[index], colors),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            itemBuilder: (context, index) => _buildListViewItem(books[index], colors),
          );
        },
      ),
    );
  }

  Widget _buildGridViewItem(ReaderBook book, ColorScheme colors) {
    return GestureDetector(
      onTap: () => _openBookDetail(book),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              child: Center(
                child: Icon(Icons.menu_book, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface)),
          if (book.readingPercentage > 0)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text('${(book.readingPercentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.3))),
            ),
        ],
      ),
    );
  }

  Widget _buildListViewItem(ReaderBook book, ColorScheme colors) {
    return GestureDetector(
      onTap: () => _openBookDetail(book),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 64,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.menu_book, size: 24, color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colors.onSurface)),
                  const SizedBox(height: 4),
                  Text('.${book.fileExtension}',
                      style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3))),
                ],
              ),
            ),
            if (book.readingPercentage > 0)
              Text('${(book.readingPercentage * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}
