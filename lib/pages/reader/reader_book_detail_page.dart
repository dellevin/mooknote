import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reader_book.dart';
import '../../providers/app_provider.dart';
import '../../utils/book_file_helper.dart';
import 'reading_page.dart';

/// 阅读器书籍详情页
class ReaderBookDetailPage extends StatefulWidget {
  final ReaderBook book;

  const ReaderBookDetailPage({super.key, required this.book});

  @override
  State<ReaderBookDetailPage> createState() => _ReaderBookDetailPageState();
}

class _ReaderBookDetailPageState extends State<ReaderBookDetailPage> {
  late String _title;
  late ReaderBook _book;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _title = _book.title;
  }

  Future<void> _startReading() async {
    // 确保获取最新的book数据
    final provider = context.read<AppProvider>();
    final latest = provider.readerBooks.firstWhere(
      (b) => b.id == _book.id,
      orElse: () => _book,
    );
    if (context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReadingPage(book: latest),
        ),
      );
      // 返回后刷新
      if (mounted) {
        await provider.loadReaderBooks();
        final updated = provider.readerBooks.firstWhere(
          (b) => b.id == _book.id,
          orElse: () => _book,
        );
        setState(() {
          _book = updated;
        });
      }
    }
  }

  Future<void> _deleteBook() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍'),
        content: Text('确定要删除「$_title」吗？\n此操作将同时删除书籍文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BookFileHelper.instance.deleteBookFiles(_book.id);
      await context.read<AppProvider>().removeReaderBook(_book.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('书籍详情'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 占位书封
            Center(
              child: Container(
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant, width: 0.5),
                ),
                child: Icon(Icons.menu_book, size: 64, color: colors.onSurface.withValues(alpha: 0.2)),
              ),
            ),
            const SizedBox(height: 24),

            // 书名
            Text('书名', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 4),
            Text(_title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 16),

            // 文件名
            Text('文件', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 4),
            Text('${_book.fileName}  (.${_book.fileExtension})',
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 16),

            // 阅读进度
            Text('阅读进度', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _book.readingPercentage,
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${(_book.readingPercentage * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
              ],
            ),
            const SizedBox(height: 16),

            // 导入时间
            Text('导入时间', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 4),
            Text(_book.createdAt.toString().substring(0, 10),
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),

            const SizedBox(height: 40),

            // 底部按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deleteBook,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('删除'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _startReading,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('阅读'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
