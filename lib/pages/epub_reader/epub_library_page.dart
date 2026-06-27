import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/epub/reader_dao.dart';
import '../../utils/epub/epub_service.dart';
import '../../utils/user_prefs.dart';
import 'epub_detail_page.dart';
import 'widgets/book_grid_item.dart';

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
  ViewMode _viewMode = UserPrefs().epubViewMode == 1
      ? ViewMode.compact
      : ViewMode.relaxed;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    if (mounted) setState(() => _isLoading = true);
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
    if (!path.toLowerCase().endsWith('.epub')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('仅支持导入 .epub 格式的文件')),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final imported = await _service.importBook(path);

    if (mounted) Navigator.pop(context);

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
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('删除书籍',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('确定删除《${book['title']}》？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
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
        builder: (_) => EpubDetailPage(bookId: book['id'], book: book),
      ),
    ).then((_) => _loadBooks());
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode =
          _viewMode == ViewMode.relaxed ? ViewMode.compact : ViewMode.relaxed;
    });
    UserPrefs().setEpubViewMode(_viewMode == ViewMode.compact ? 1 : 0);
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
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _viewMode == ViewMode.relaxed
                  ? Icons.view_compact_outlined
                  : Icons.view_agenda_outlined,
              size: 20,
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
            onPressed: _toggleViewMode,
          ),
          IconButton(
            icon: Icon(Icons.add_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
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
              child: Icon(Icons.auto_stories_outlined,
                  size: 40, color: colors.onSurface.withValues(alpha: 0.25)),
            ),
            const SizedBox(height: 24),
            Text('EPUB 阅读',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 8),
            Text('点击右上角导入 .epub 文件',
                style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickAndImport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text('导入 EPUB',
                    style: TextStyle(fontSize: 15, color: colors.onPrimary, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme colors) {
    final bool showList = _viewMode == ViewMode.compact;

    if (showList) {
      return _buildListView(colors);
    }
    return _buildGridView(colors);
  }

  Widget _buildGridView(ColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.55,
      ),
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return BookGridItem(
          book: book,
          viewMode: ViewMode.relaxed,
          onTap: () => _openBook(book),
          onLongPress: () => _deleteBook(book),
        );
      },
    );
  }

  Widget _buildListView(ColorScheme colors) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        final title = book['title'] as String? ?? '';
        final author = book['author'] as String? ?? '';
        final coverPath = book['cover_path'] as String?;
        final progress = (book['reading_percentage'] as num?)?.toDouble() ?? 0.0;

        return GestureDetector(
          onTap: () => _openBook(book),
          onLongPress: () => _deleteBook(book),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            child: Row(
              children: [
                // 封面
                SizedBox(
                  width: 56, height: 80,
                  child: _buildCover(coverPath, colors),
                ),
                const SizedBox(width: 14),
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                      ],
                      const SizedBox(height: 8),
                      // 标签
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _buildTag('EPUB', colors),
                        if (progress > 0) _buildTag('${(progress * 100).toInt()}%', colors),
                      ]),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCover(String? path, ColorScheme colors) {
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(path), fit: BoxFit.cover,
            width: double.infinity, height: double.infinity),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.auto_stories_outlined, size: 24,
          color: colors.onSurface.withValues(alpha: 0.25)),
    );
  }

  Widget _buildTag(String label, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.5))),
    );
  }
}
