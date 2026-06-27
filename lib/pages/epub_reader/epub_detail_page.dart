import 'dart:io';

import 'package:flutter/material.dart';

import '../../utils/epub/reader_dao.dart';
import '../../utils/epub/epub_parser.dart';
import '../../utils/epub/reader_models.dart';
import '../../utils/book/book_dao.dart';
import '../../models/data_models.dart';
import 'book_link_page.dart';
import 'reader_screen.dart';

/// EPUB 书籍详情页
class EpubDetailPage extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> book;

  const EpubDetailPage({
    super.key,
    required this.bookId,
    required this.book,
  });

  @override
  State<EpubDetailPage> createState() => _EpubDetailPageState();
}

class _EpubDetailPageState extends State<EpubDetailPage> {
  final ReaderDao _dao = ReaderDao();
  final BookDao _bookDao = BookDao();
  final EpubParser _parser = EpubParser();

  late Map<String, dynamic> _book;
  EpubBookInfo? _bookInfo;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _loadBookInfo();
  }

  Future<void> _loadBookInfo() async {
    final filePath = _book['file_path'] as String?;
    if (filePath == null || filePath.isEmpty) return;
    final info = await _parser.parseFromFile(filePath);
    if (mounted && info != null) setState(() => _bookInfo = info);
  }

  Future<void> _refreshBook() async {
    final updated = await _dao.getReaderBookById(widget.bookId);
    if (mounted && updated != null) setState(() => _book = updated);
  }

  void _navigateToReader() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: _book['id'] as String,
          filePath: _book['file_path'] as String,
          title: _book['title'] as String? ?? '',
          coverPath: _book['cover_path'] as String?,
          bookData: _book,
        ),
      ),
    ).then((_) => _refreshBook());
  }

  // ─── 编辑对话框 ─────────────────────────────────────────────

  void _showEditDialog() {
    final titleCtrl = TextEditingController(text: _book['title'] as String? ?? '');
    final authorCtrl = TextEditingController(text: _book['author'] as String? ?? '');
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('编辑书籍信息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: '标题',
                labelStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: authorCtrl,
              decoration: InputDecoration(
                labelText: '作者',
                labelStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () async {
              final newTitle = titleCtrl.text.trim();
              final newAuthor = authorCtrl.text.trim();
              if (newTitle.isEmpty) return;
              await _dao.updateReaderBook(widget.bookId, {
                'title': newTitle,
                'author': newAuthor,
                'updated_at': DateTime.now().toIso8601String(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              await _refreshBook();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (_book['reading_percentage'] as num?)?.toDouble() ?? 0.0;
    final title = _book['title'] as String? ?? '';
    final author = _book['author'] as String? ?? '';
    final coverPath = _book['cover_path'] as String?;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
            onPressed: _showEditDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 封面 + 基本信息（横向布局）──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面
                  GestureDetector(
                    onTap: _navigateToReader,
                    child: SizedBox(
                      width: 110, height: 154,
                      child: _buildCover(coverPath, colors),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                                color: colors.onSurface, height: 1.3)),
                        if (author.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(author, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.5))),
                        ],
                        // 元数据标签
                        if (_bookInfo != null) ...[
                          const SizedBox(height: 10),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _buildTag('${_bookInfo!.spine.length}章', colors),
                            _buildTag('EPUB ${_bookInfo!.epubVersion}', colors),
                          ]),
                        ],
                        const SizedBox(height: 12),
                        // 进度
                        Row(children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress > 0 ? progress : 0,
                                minHeight: 3,
                                backgroundColor: colors.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(progress > 0 ? '${(progress * 100).toInt()}%' : '未开始',
                              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 0.5, thickness: 0.5, color: colors.outline),

            // ── 描述 ──
            if (_bookInfo?.description != null && _bookInfo!.description!.isNotEmpty) ...[
              _buildSectionHeader('简介', colors),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: GestureDetector(
                  onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                  child: Text(_stripHtmlTags(_bookInfo!.description!),
                      maxLines: _descriptionExpanded ? null : 4,
                      overflow: _descriptionExpanded ? null : TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, height: 1.7, color: colors.onSurface)),
                ),
              ),
              Divider(height: 0.5, thickness: 0.5, color: colors.outline),
            ],

            // ── 关联书籍 ──
            _buildSectionHeader('关联书籍', colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: _buildLinkedBookCard(colors),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: FilledButton(
            onPressed: _navigateToReader,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              progress > 0 ? '继续阅读' : '开始阅读',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onPrimary),
            ),
          ),
        ),
      ),
    );
  }

  // ─── 构建组件 ────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        Container(width: 4, height: 14,
            decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
      ]),
    );
  }

  Widget _buildTag(String label, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5))),
    );
  }

  Widget _buildLinkedBookCard(ColorScheme colors) {
    final linkedBookId = _book['book_id'] as String? ?? '';
    if (linkedBookId.isEmpty) {
      return InkWell(
        onTap: _navigateToLinkPage,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.link_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('选择关联书籍',
                  style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.5))),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
          ]),
        ),
      );
    }

    return FutureBuilder<Book?>(
      future: _bookDao.getBookById(linkedBookId),
      builder: (context, snapshot) {
        final linkedTitle = snapshot.data?.title ?? '未知书籍';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(Icons.link_outlined, size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已关联', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                  Text(linkedTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colors.onSurface)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _unlinkBook,
              child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _navigateToLinkPage() async {
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookLinkPage(readerBookId: widget.bookId)),
    );
    if (linked == true && mounted) await _refreshBook();
  }

  Future<void> _unlinkBook() async {
    await _dao.unlinkBook(widget.bookId);
    await _refreshBook();
  }

  Widget _buildCover(String? coverPath, ColorScheme colors) {
    if (coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(File(coverPath), fit: BoxFit.cover,
            width: double.infinity, height: double.infinity),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.auto_stories_outlined, size: 36, color: colors.onSurface.withValues(alpha: 0.2)),
    );
  }

  static String _stripHtmlTags(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) return '';
    String text = htmlContent;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</(p|div|h[1-6]|tr|blockquote)>', caseSensitive: false), '\n\n');
    text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
    text = text.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text
        .replaceAll('&nbsp;', ' ').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'").replaceAll('&mdash;', '—').replaceAll('&ndash;', '–');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
    return text.trim();
  }
}
