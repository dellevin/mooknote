import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/epub/reader_dao.dart';
import '../../utils/epub/epub_parser.dart';
import '../../utils/epub/reader_models.dart';
import '../../utils/book/book_dao.dart';
import '../../utils/book/book_excerpt_dao.dart';
import '../../utils/toast_util.dart';
import '../../models/data_models.dart';
import '../book/book_detail_page.dart';
import '../book/book_excerpts_page.dart';
import 'book_link_page.dart';
import 'epub_edit_page.dart';
import 'epub_highlights_page.dart';
import 'highlight_detail_sheet.dart';
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
  Future<List<BookExcerpt>>? _excerptsFuture;
  Future<List<Map<String, dynamic>>>? _highlightsFuture;
  String? _linkedBookCoverPath;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _loadBookInfo();
    _loadLinkedBookCover();
    final linkedBookId = _book['book_id'] as String? ?? '';
    if (linkedBookId.isNotEmpty) {
      _excerptsFuture = BookExcerptDao().getExcerptsByBookId(linkedBookId);
    }
    _highlightsFuture = _dao.getHighlightsByBookId(widget.bookId);
  }

  Future<void> _loadBookInfo() async {
    final filePath = _book['file_path'] as String?;
    if (filePath == null || filePath.isEmpty) return;
    final info = await _parser.parseFromFile(filePath);
    if (mounted && info != null) setState(() => _bookInfo = info);
  }

  Future<void> _loadLinkedBookCover() async {
    final linkedBookId = _book['book_id'] as String? ?? '';
    if (linkedBookId.isEmpty) return;
    final book = await _bookDao.getBookById(linkedBookId);
    if (mounted && book != null && book.coverPath != null && book.coverPath!.isNotEmpty) {
      setState(() => _linkedBookCoverPath = book.coverPath);
    }
  }

  Future<void> _refreshBook() async {
    final updated = await _dao.getReaderBookById(widget.bookId);
    if (mounted && updated != null) {
      final linkedBookId = updated['book_id'] as String? ?? '';
      setState(() {
        _book = updated;
        _linkedBookCoverPath = null;
        _highlightsFuture = _dao.getHighlightsByBookId(widget.bookId);
        if (linkedBookId.isNotEmpty) {
          _excerptsFuture = BookExcerptDao().getExcerptsByBookId(linkedBookId);
        } else {
          _excerptsFuture = null;
        }
      });
      _loadLinkedBookCover();
    }
  }

  void _navigateToReader() {
    final coverPath = _linkedBookCoverPath ?? _book['cover_path'] as String?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: _book['id'] as String,
          filePath: _book['file_path'] as String,
          title: _book['title'] as String? ?? '',
          coverPath: coverPath,
          bookData: _book,
        ),
      ),
    ).then((_) => _refreshBook());
  }

  void _navigateToEdit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EpubEditPage(bookId: widget.bookId, book: _book),
      ),
    );
    if (changed == true && mounted) await _refreshBook();
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (_book['reading_percentage'] as num?)?.toDouble() ?? 0.0;
    final title = _book['title'] as String? ?? '';
    final author = _book['author'] as String? ?? '';
    final coverPath = _linkedBookCoverPath ?? _book['cover_path'] as String?;

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
            onPressed: _navigateToEdit,
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

            // ── 句读（高亮）──
            Divider(height: 0.5, thickness: 0.5, color: colors.outline),
            _buildHighlightsSectionHeader(colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              child: _buildHighlightsList(colors),
            ),

            // ── 书籍摘抄（仅关联书籍时显示）──
            if ((_book['book_id'] as String? ?? '').isNotEmpty) ...[
              Divider(height: 0.5, thickness: 0.5, color: colors.outline),
              _buildExcerptsSectionHeader(colors),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                child: _buildExcerptsList(colors),
              ),
            ],

            // ── 其他作品（同作者）──
            if (author.isNotEmpty) ...[
              Divider(height: 0.5, thickness: 0.5, color: colors.outline),
              _buildSectionHeader('其他作品', colors),
              _buildOtherWorks(author, colors),
              const SizedBox(height: 24),
            ],
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
      return GestureDetector(
        onTap: _navigateToLinkPage,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant, width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              child: Icon(Icons.link_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('关联书籍', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                  const SizedBox(height: 4),
                  Text('点击选择要关联的书籍', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
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
        final linkedAuthor = snapshot.data?.authors.take(2).join(' / ') ?? '';
        return GestureDetector(
          onTap: () => _showLinkedBookActions(colors, linkedTitle),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.outlineVariant, width: 0.5),
                ),
                child: Icon(Icons.link, size: 20, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(linkedTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    const SizedBox(height: 4),
                    Text(
                      linkedAuthor.isNotEmpty ? '已关联 · $linkedAuthor' : '已关联',
                      style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 18, color: colors.onSurface.withValues(alpha: 0.25)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildExcerptsList(ColorScheme colors) {
    if (_excerptsFuture == null) return const SizedBox.shrink();
    return FutureBuilder<List<BookExcerpt>>(
      future: _excerptsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.format_quote, size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
                const SizedBox(width: 8),
                Text('暂无摘抄', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
              ],
            ),
          );
        }
        final excerpts = snapshot.data!;
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: excerpts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _buildExcerptCard(excerpts[i], colors),
          ),
        );
      },
    );
  }

  Widget _buildExcerptCard(BookExcerpt excerpt, ColorScheme colors) {
    final hasComment = excerpt.comment.isNotEmpty;
    return GestureDetector(
      onTap: () => _showExcerptDetail(excerpt, colors),
      child: Container(
        width: 160,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：图标 + 章节标签
            Row(
              children: [
                Icon(Icons.menu_book_outlined, size: 14, color: colors.primary.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                if (excerpt.chapter.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        excerpt.chapter,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 9, color: colors.primary.withValues(alpha: 0.7), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 摘抄内容
            Expanded(
              child: Text(
                excerpt.content,
                maxLines: hasComment ? 3 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.8), height: 1.6),
              ),
            ),
            // 底部：感悟标记 + 日期
            Row(
              children: [
                if (hasComment) ...[
                  Icon(Icons.lightbulb_outline, size: 10, color: colors.primary.withValues(alpha: 0.4)),
                  const SizedBox(width: 3),
                  Text('有感悟', style: TextStyle(fontSize: 9, color: colors.primary.withValues(alpha: 0.4))),
                ],
                const Spacer(),
                Text(
                  _formatDate(excerpt.createdAt.toIso8601String()),
                  style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 句读（高亮）──

  Widget _buildHighlightsSectionHeader(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(children: [
        Container(width: 4, height: 14,
            decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('句读', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
        const Spacer(),
        TextButton(
          onPressed: _navigateToHighlightsPage,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('详情', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
              Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── 书籍摘抄 ──

  Widget _buildExcerptsSectionHeader(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Row(children: [
        Container(width: 4, height: 14,
            decoration: BoxDecoration(color: colors.onSurface, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text('书籍摘抄', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
        const Spacer(),
        TextButton(
          onPressed: _navigateToExcerptsPage,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('详情', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
              Icon(Icons.chevron_right, size: 16, color: colors.onSurface.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildHighlightsList(ColorScheme colors) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _highlightsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final highlights = snapshot.data!
            .where((h) => h['color'] != 'excerpt')
            .toList();
        if (highlights.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.highlight_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.2)),
                const SizedBox(width: 8),
                Text('暂无句读', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
              ],
            ),
          );
        }
        return SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: highlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _buildHighlightCard(highlights[i], colors),
          ),
        );
      },
    );
  }

  Widget _buildHighlightCard(Map<String, dynamic> highlight, ColorScheme colors) {
    final content = highlight['content'] as String? ?? '';
    final chapter = highlight['chapter'] as String? ?? '';
    final chapterNum = int.tryParse(chapter);
    final createdAt = highlight['created_at'] as String? ?? '';

    return GestureDetector(
      onTap: () => _showHighlightDetail(highlight, colors),
      child: Container(
        width: 160,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：引号图标 + 章节标签
            Row(
              children: [
                Icon(Icons.format_quote, size: 14, color: const Color(0xFFFFC107)),
                const Spacer(),
                if (chapterNum != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '第${chapterNum + 1}章',
                      style: const TextStyle(fontSize: 9, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 高亮文本
            Expanded(
              child: Text(
                content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.8), height: 1.6),
              ),
            ),
            // 底部：日期
            if (createdAt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatDate(createdAt),
                  style: TextStyle(fontSize: 9, color: colors.onSurface.withValues(alpha: 0.3)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 摘抄详情弹窗
  void _showExcerptDetail(BookExcerpt excerpt, ColorScheme colors) {
    showExcerptDetailSheet(
      context,
      content: excerpt.content,
      chapter: excerpt.chapter,
      comment: excerpt.comment,
      createdAt: excerpt.createdAt,
      bookTitle: _book['title'] as String? ?? '',
      onDelete: () => _deleteExcerpt(excerpt, colors),
    );
  }

  /// 删除摘抄（同步删除蓝色高亮）
  Future<void> _deleteExcerpt(BookExcerpt excerpt, ColorScheme colors) async {
    final confirmed = showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除摘抄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('确定删除这条摘抄吗？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('删除', style: TextStyle(color: colors.error))),
        ],
      ),
    );
    if (await confirmed != true) return;
    // 同步删除蓝色高亮（用 books 表 ID 查找关联的 reader_book）
    final linkedBookId = _book['book_id'] as String? ?? '';
    if (linkedBookId.isNotEmpty) {
      final readerBook = await _dao.getReaderBookByBookId(linkedBookId);
      if (readerBook != null) {
        await _dao.deleteExcerptHighlightByContent(
          readerBook['id'] as String,
          excerpt.content,
        );
      }
    }
    // 删除摘抄记录
    await BookExcerptDao().deleteExcerpt(excerpt.id);
    if (mounted) {
      setState(() {
        _refreshBook();
      });
      ToastUtil.show(context, '已删除');
    }
  }

  /// 句读详情弹窗（使用共享组件）
  void _showHighlightDetail(Map<String, dynamic> highlight, ColorScheme colors) {
    showHighlightDetailSheet(
      context,
      highlight: highlight,
      book: _book,
      onDelete: () => _deleteHighlight(highlight['id'] as int, colors),
    );
  }

  Future<void> _deleteHighlight(int id, ColorScheme colors) async {
    final confirmed = showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除句读', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Text('确定删除这条句读？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
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
    if (await confirmed != true) return;
    await _dao.deleteHighlight(id);
    if (mounted) {
      setState(() {
        _highlightsFuture = _dao.getHighlightsByBookId(widget.bookId);
      });
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _navigateToHighlight(Map<String, dynamic> highlight) {
    final chapter = int.tryParse(highlight['chapter'] as String? ?? '') ?? 0;
    final xpath = _extractStartXPath(highlight['cfi'] as String? ?? '');
    final text = highlight['content'] as String? ?? '';
    final coverPath = _linkedBookCoverPath ?? _book['cover_path'] as String?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          bookId: _book['id'] as String,
          filePath: _book['file_path'] as String,
          title: _book['title'] as String? ?? '',
          coverPath: coverPath,
          bookData: _book,
          initialSpineIndex: chapter,
          scrollToXPath: xpath,
          scrollToText: text,
        ),
      ),
    ).then((_) => _refreshBook());
  }

  /// 从 cfi JSON 中提取 startXPath
  String? _extractStartXPath(String cfi) {
    if (cfi.isEmpty) return null;
    try {
      final decoded = jsonDecode(cfi) as Map<String, dynamic>;
      return decoded['startXPath'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _navigateToHighlightsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EpubHighlightsPage(bookId: widget.bookId, book: _book),
      ),
    ).then((_) => _refreshBook());
  }

  void _navigateToExcerptsPage() async {
    final linkedBookId = _book['book_id'] as String? ?? '';
    if (linkedBookId.isEmpty) return;
    final book = await _bookDao.getBookById(linkedBookId);
    if (!mounted || book == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookExcerptsPage(book: book),
      ),
    ).then((_) => _refreshBook());
  }

  void _showLinkedBookActions(ColorScheme colors, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(alignment: Alignment.centerLeft,
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          ),
          const SizedBox(height: 12),
          Divider(height: 0.5, color: colors.outlineVariant),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.menu_book_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.6))),
            title: Text('查看书籍详情', style: TextStyle(fontSize: 13, color: colors.onSurface)),
            onTap: () async {
              Navigator.pop(ctx);
              final bookId = _book['book_id'] as String? ?? '';
              if (bookId.isEmpty) return;
              final book = await _bookDao.getBookById(bookId);
              if (book != null && mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailPage(book: book)));
              }
            },
          ),
          Divider(height: 0.5, indent: 20, endIndent: 20, color: colors.outlineVariant),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.link_off, size: 18, color: colors.error)),
            title: Text('取消关联', style: TextStyle(fontSize: 13, color: colors.error)),
            onTap: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                builder: (confirmCtx) => AlertDialog(
                  title: const Text('取消关联', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  content: Text(
                    '取消关联会清除掉阅读界面的蓝色划线且重新关联后不可恢复，确定要取消关联吗？',
                    style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(confirmCtx), child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)))),
                    TextButton(
                      onPressed: () { Navigator.pop(confirmCtx); _unlinkBook(); },
                      child: Text('确定', style: TextStyle(color: colors.error, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
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

  Widget _buildOtherWorks(String author, ColorScheme colors) {
    final linkedBookId = _book['book_id'] as String? ?? '';
    return FutureBuilder<List<Book>>(
      future: _bookDao.getBooksByAuthor(author),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text('暂未收藏该作者其他作品',
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
          );
        }
        final books = snapshot.data!.where((b) => b.id != linkedBookId).toList();
        if (books.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Text('暂未收藏该作者其他作品',
                style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.35))),
          );
        }
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => BookDetailPage(book: book))),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90, height: 126,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: book.coverPath != null && book.coverPath!.isNotEmpty
                              ? Image.file(File(book.coverPath!), fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildBookCoverPlaceholder(colors))
                              : _buildBookCoverPlaceholder(colors),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: colors.onSurface)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBookCoverPlaceholder(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.menu_book_outlined, size: 28, color: colors.onSurface.withValues(alpha: 0.2)),
    );
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
