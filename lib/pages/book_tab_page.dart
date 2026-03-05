import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../widgets/book_status_bar.dart';
import '../widgets/book_list_item.dart';

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
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
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
    final statusText = ['读完', '在读', '准备读'][statusIndex];
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无$statusText的书籍',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加记录'),
            onPressed: () {
              Navigator.pushNamed(context, '/book-form');
            },
          ),
        ],
      ),
    );
  }

  /// 获取示例书籍数据
  List<Book> _getSampleBooks(int statusIndex) {
    final statusMap = ['read', 'reading', 'want_to_read'];
    final currentStatus = statusMap[statusIndex];
    
    // 示例数据（实际应从数据库获取）
    final allBooks = [
      Book(
        id: '1',
        title: '活着',
        author: '余华',
        rating: 9.2,
        status: 'read',
        readDate: DateTime(2024, 1, 20),
        note: '非常感人的故事，让人思考生命的意义',
      ),
      Book(
        id: '2',
        title: '百年孤独',
        author: '加西亚·马尔克斯',
        rating: 9.3,
        status: 'read',
        readDate: DateTime(2024, 2, 15),
      ),
      Book(
        id: '3',
        title: '人类简史',
        author: '尤瓦尔·赫拉利',
        rating: 9.0,
        status: 'reading',
      ),
      Book(
        id: '4',
        title: '三体',
        author: '刘慈欣',
        rating: 9.5,
        status: 'want_to_read',
      ),
      Book(
        id: '5',
        title: '追风筝的人',
        author: '卡勒德·胡赛尼',
        rating: 8.9,
        status: 'read',
        readDate: DateTime(2024, 3, 5),
        note: '关于救赎与成长的故事',
      ),
    ];
    
    return allBooks.where((b) => b.status == currentStatus).toList();
  }
}
