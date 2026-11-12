import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/data_models.dart';
import '../../providers/app_provider.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/publisher_avatar.dart';
import '../book/book_detail_page.dart';

/// 出版社详情页（只读：按社名精确匹配书籍 publisher 文本）
class PublisherDetailPage extends StatelessWidget {
  final String publisherName;

  const PublisherDetailPage({super.key, required this.publisherName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.watch<AppProvider>();

    final books = provider.books
        .where((b) => !b.isDeleted && (b.publisher?.trim() ?? '') == publisherName)
        .toList();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(publisherName),
      ),
      body: SingleChildScrollView(
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
                publisherName,
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
