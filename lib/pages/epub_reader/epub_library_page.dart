import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/epub/reader_dao.dart';
import '../../utils/epub/epub_service.dart';
import 'reader_screen.dart';

/// EPUB 书架页面
class EpubLibraryPage extends StatefulWidget {
  const EpubLibraryPage({super.key});

  @override
  State<EpubLibraryPage> createState() => _EpubLibraryPageState();
}

class _EpubLibraryPageState extends State<EpubLibraryPage> {
  final ReaderDao _dao = ReaderDao();
  final EpubService _service = EpubService();
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final books = await _dao.getAllReaderBooks();
    if (mounted) {
      setState(() {
        _books = books;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final imported = await _service.importBook(path);

    if (mounted) Navigator.pop(context); // 关闭 loading

    if (imported != null) {
      await _loadBooks();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('EPUB 解析失败，请检查文件')),
      );
    }
  }

  Future<void> _deleteBook(Map<String, dynamic> book) async {
    final colors = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除书籍', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('确定删除《${book['title']}》？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除', style: TextStyle(color: colors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteBook(book['id']);
      await _loadBooks();
    }
  }

  void _openBook(Map<String, dynamic> book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: book['id'],
          filePath: book['file_path'],
          title: book['title'],
          coverPath: book['cover_path'],
        ),
      ),
    ).then((_) => _loadBooks()); // 返回时刷新进度
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('EPUB 阅读',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_outlined, color: colors.onSurface.withValues(alpha: 0.7)),
            onPressed: _pickAndImport,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : _books.isEmpty
              ? _buildEmpty(colors)
              : _buildGrid(colors),
    );
  }

  Widget _buildEmpty(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.auto_stories_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 24),
            Text('EPUB 阅读', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 8),
            Text('点击右上角导入 .epub 文件', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickAndImport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(24)),
                child: Text('导入 EPUB', style: TextStyle(fontSize: 15, color: colors.onPrimary, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return _buildBookItem(book, colors);
      },
    );
  }

  Widget _buildBookItem(Map<String, dynamic> book, ColorScheme colors) {
    final coverPath = book['cover_path'] as String?;
    final title = book['title'] as String? ?? '';
    final author = book['author'] as String? ?? '';
    final progress = (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;

    return GestureDetector(
      onTap: () => _openBook(book),
      onLongPress: () => _deleteBook(book),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync()
                  ? Image.file(File(coverPath), fit: BoxFit.cover)
                  : Icon(Icons.auto_stories_outlined, size: 36, color: colors.onSurface.withValues(alpha: 0.2)),
            ),
          ),
          const SizedBox(height: 8),
          // 标题
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colors.onSurface)),
          if (author.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4))),
          ],
          const SizedBox(height: 4),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: colors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colors.primary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
