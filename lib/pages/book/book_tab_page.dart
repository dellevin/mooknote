import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../widgets/book_status_bar.dart';
import '../../widgets/book_list_item.dart';

/// 阅读标签页
class BookTabPage extends StatelessWidget {
  const BookTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 状态选择栏（读完、在读、准备读）
        const BookStatusBar(),
        
        // 书籍列表
        Expanded(
          child: _buildBookList(context),
        ),
      ],
    );
  }

  /// 构建书籍列表
  Widget _buildBookList(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // 根据状态筛选书籍
        final statusMap = {
          0: 'read',
          1: 'reading',
          2: 'want_to_read',
        };
        final currentStatus = statusMap[provider.bookStatusIndex]!;
        final books = provider.getBooksByStatus(currentStatus);
        
        if (books.isEmpty) {
          return _buildEmptyState(context, provider.bookStatusIndex);
        }
        
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
            itemBuilder: (context, index) {
              return BookListItem(book: books[index]);
            },
          ),
        );
      },
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(BuildContext context, int statusIndex) {
    final statusText = ['已读', '在读', '想读'][statusIndex];
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '暂无$statusText的书籍',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              final statusMap = {
                0: 'read',
                1: 'reading',
                2: 'want_to_read',
              };
              final currentStatus = statusMap[statusIndex]!;
              Navigator.pushNamed(
                context,
                '/book-form',
                arguments: {'initialStatus': currentStatus},
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '添加记录',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取示例书籍数据
  List<Book> _getSampleBooks(int statusIndex) {
    final statusMap = ['read', 'reading', 'want_to_read'];
    final currentStatus = statusMap[statusIndex];
    final now = DateTime.now();
    
    // 示例数据（实际应从数据库获取）
    final allBooks = [
      Book(
        id: '1',
        title: '活着',
        authors: ['余华'],
        rating: 9.2,
        status: 'read',
        genres: ['小说', '文学'],
        summary: '非常感人的故事，让人思考生命的意义',
        createdAt: now,
        updatedAt: now,
      ),
      Book(
        id: '2',
        title: '百年孤独',
        authors: ['加西亚·马尔克斯'],
        rating: 9.3,
        status: 'read',
        genres: ['小说', '魔幻现实主义'],
        publisher: '南海出版公司',
        createdAt: now,
        updatedAt: now,
      ),
      Book(
        id: '3',
        title: '人类简史',
        authors: ['尤瓦尔·赫拉利'],
        rating: 9.0,
        status: 'reading',
        genres: ['历史', '科普'],
        createdAt: now,
        updatedAt: now,
      ),
      Book(
        id: '4',
        title: '三体',
        authors: ['刘慈欣'],
        rating: 9.5,
        status: 'want_to_read',
        genres: ['科幻', '小说'],
        createdAt: now,
        updatedAt: now,
      ),
      Book(
        id: '5',
        title: '追风筝的人',
        authors: ['卡勒德·胡赛尼'],
        rating: 8.9,
        status: 'read',
        genres: ['小说', '文学'],
        summary: '关于救赎与成长的故事',
        createdAt: now,
        updatedAt: now,
      ),
    ];
    
    return allBooks.where((b) => b.status == currentStatus).toList();
  }
}
