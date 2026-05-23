import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../utils/user_prefs.dart';
import '../../widgets/book_status_bar.dart';
import '../../widgets/book_list_item.dart';
import '../../widgets/animated_star_rating.dart';
import '../../widgets/shimmer_skeleton.dart';

/// 阅读标签页
class BookTabPage extends StatefulWidget {
  const BookTabPage({super.key});

  @override
  State<BookTabPage> createState() => _BookTabPageState();
}

class _BookTabPageState extends State<BookTabPage> {
  int _layoutStyle = 0; // 0: 封面网格, 1: 列表
  bool _firstLoad = true;

  @override
  void initState() {
    super.initState();
    _layoutStyle = UserPrefs().bookLayoutStyle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _firstLoad = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const BookStatusBar(),
        Expanded(
          child: _buildBookList(context),
        ),
      ],
    );
  }

  Widget _buildBookList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        final statusMap = {0: 'read', 1: 'reading', 2: 'want_to_read'};
        final currentStatus = statusMap[provider.bookStatusIndex]!;
        final books = provider.getBooksByStatus(currentStatus);

        if (_firstLoad) {
          return _buildSkeleton();
        }

        if (books.isEmpty) {
          return _buildEmptyState(context, provider.bookStatusIndex);
        }

        if (_layoutStyle == 1) {
          return _buildListView(books, provider);
        }
        return _buildGridView(books, provider);
      },
    );
  }

  Widget _buildGridView(List books, AppProvider provider) {
    return RefreshIndicator(
      onRefresh: () async => await provider.loadBooks(),
      color: const Color(0xFF1A1A1A),
      backgroundColor: Colors.white,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) => BookListItem(book: books[index]),
      ),
    );
  }

  Widget _buildListView(List books, AppProvider provider) {
    return RefreshIndicator(
      onRefresh: () async => await provider.loadBooks(),
      color: const Color(0xFF1A1A1A),
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        itemCount: books.length,
        itemBuilder: (context, index) => _buildListCard(books[index]),
      ),
    );
  }

  Widget _buildListCard(book) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/book-detail', arguments: book),
      onLongPress: () => _showDeleteDialog(context, book),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 封面缩略图
            Container(
              width: 48, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(6),
              ),
              clipBehavior: Clip.antiAlias,
              child: book.coverPath != null && book.coverPath!.isNotEmpty
                  ? Image.file(File(book.coverPath!), fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_outlined, size: 22, color: Color(0xFFCCCCCC)))
                  : const Icon(Icons.menu_book_outlined, size: 22, color: Color(0xFFCCCCCC)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(book.authors.take(2).join('、'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
                  ],
                  const SizedBox(height: 6),
                  if (book.rating != null)
                    AnimatedStarRating(rating: book.rating!, starSize: 12, showNumber: true)
                  else
                    const SizedBox(height: 14),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFD0D0D0), size: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, book) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        content: Text('确定要删除《${book.title}》吗？删除后可在回收站恢复。',
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(book.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSkeleton() {
    return _layoutStyle == 1
        ? MovieSkeletonGrid() // reuse same grid skeleton pattern
        : const BookSkeletonGrid();
  }

  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final statusText = ['已读', '在读', '想读'][statusIndex];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.menu_book_outlined, size: 40, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(height: 20),
          Text('暂无$statusText的书籍', style: const TextStyle(fontSize: 16, color: Color(0xFF999999))),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              final statusMap = {0: 'read', 1: 'reading', 2: 'want_to_read'};
              Navigator.pushNamed(context, '/book-form', arguments: {'initialStatus': statusMap[statusIndex]!});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
              child: const Text('添加记录', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
