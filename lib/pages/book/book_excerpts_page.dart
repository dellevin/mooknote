import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/epub/reader_dao.dart';
import '../../widgets/fade_in_local_image.dart';
import 'book_excerpt_form_page.dart';

/// 书籍摘抄列表页面
class BookExcerptsPage extends StatefulWidget {
  final Book book;

  const BookExcerptsPage({super.key, required this.book});

  @override
  State<BookExcerptsPage> createState() => _BookExcerptsPageState();
}

class _BookExcerptsPageState extends State<BookExcerptsPage> {
  List<BookExcerpt> _excerpts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExcerpts();
  }

  Future<void> _loadExcerpts() async {
    setState(() => _isLoading = true);
    try {
      final excerpts = await context.read<AppProvider>().getBookExcerpts(widget.book.id);
      if (mounted) {
        setState(() {
          _excerpts = excerpts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) ToastUtil.show(context, '加载失败: $e');
    }
  }

  int get _thoughtCount => _excerpts.where((e) => e.comment.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('摘抄', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: '导入',
            onPressed: _showImportSheet,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '删除全部',
            onPressed: _excerpts.isEmpty ? null : _showDeleteAllDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : Column(
              children: [
                _buildBookHeader(colors),
                Expanded(
                  child: _excerpts.isEmpty
                      ? _buildEmptyState(colors)
                      : _buildExcerptList(colors),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddExcerpt,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('添加摘抄'),
      ),
    );
  }

  // ── 书籍头部 ──

  Widget _buildBookHeader(ColorScheme colors) {
    final book = widget.book;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Container(
            width: 52,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: colors.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: book.coverPath != null && book.coverPath!.isNotEmpty
                ? FadeInLocalImage(
                    path: book.coverPath,
                    fit: BoxFit.cover,
                    errorWidget: Icon(Icons.menu_book_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
                  )
                : Icon(Icons.menu_book_outlined, size: 22, color: colors.onSurface.withValues(alpha: 0.25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                ),
                if (book.authors.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    book.authors.take(2).join('、'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
                const SizedBox(height: 10),
                // 统计行
                Row(
                  children: [
                    _buildStatChip(colors, Icons.format_quote, '${_excerpts.length} 条摘抄'),
                    if (_thoughtCount > 0) ...[
                      const SizedBox(width: 12),
                      _buildStatChip(colors, Icons.chat_bubble_outline, '$_thoughtCount 条想法'),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(ColorScheme colors, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.45)),
        ),
      ],
    );
  }

  // ── 空状态 ──

  Widget _buildEmptyState(ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.format_quote_outlined, size: 40, color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            const SizedBox(height: 20),
            Text('暂无摘抄', style: TextStyle(fontSize: 16, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text('记录书中触动人心的文字', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25))),
          ],
        ),
      ),
    );
  }

  // ── 摘抄列表 ──

  Widget _buildExcerptList(ColorScheme colors) {
    final chapters = _groupExcerptsByChapter().keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final excerpts = _groupExcerptsByChapter()[chapter]!;
        return _buildChapterSection(chapter, excerpts, colors, index);
      },
    );
  }

  /// 按章节分组
  Map<String, List<BookExcerpt>> _groupExcerptsByChapter() {
    final groups = <String, List<BookExcerpt>>{};
    for (final e in _excerpts) {
      final chapter = e.chapter.isEmpty ? '未分类' : e.chapter;
      (groups[chapter] ??= []).add(e);
    }
    for (final key in groups.keys) {
      groups[key]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return groups;
  }

  // ── 章节分组 ──

  Widget _buildChapterSection(String chapter, List<BookExcerpt> excerpts, ColorScheme colors, int chapterIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 章节标题
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(chapter, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${excerpts.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.primary),
                  ),
                ),
              ],
            ),
          ),
          // 摘抄卡片
          ...excerpts.map((excerpt) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildExcerptCard(excerpt, colors),
          )),
        ],
      ),
    );
  }

  // ── 摘抄卡片 ──

  Widget _buildExcerptCard(BookExcerpt excerpt, ColorScheme colors) {
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToEditExcerpt(excerpt),
        onLongPress: () => _showDeleteDialog(excerpt),
        child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 想法（在内容上方，无背景）
                if (excerpt.comment.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 13, color: colors.primary.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          excerpt.comment,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurface.withValues(alpha: 0.5),
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                // 摘抄内容
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u201C',
                      style: TextStyle(
                        fontSize: 20,
                        color: colors.primary.withValues(alpha: 0.35),
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        excerpt.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurface.withValues(alpha: 0.85),
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                // 底部：日期
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: colors.onSurface.withValues(alpha: 0.25)),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(excerpt.createdAt),
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }

  String _formatDate(DateTime date) => '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

  void _navigateToAddExcerpt() {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => BookExcerptFormPage(bookId: widget.book.id))).then((_) => _loadExcerpts());
  }

  void _navigateToEditExcerpt(BookExcerpt excerpt) {
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => BookExcerptFormPage(bookId: widget.book.id, excerpt: excerpt))).then((_) => _loadExcerpts());
  }

  Future<bool?> _showDeleteDialog(BookExcerpt excerpt) {
    final colors = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('确定删除这条摘抄吗？', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, true);
                final readerBook = await ReaderDao().getReaderBookByBookId(widget.book.id);
                if (readerBook != null) {
                  await ReaderDao().deleteExcerptHighlightByContent(
                    readerBook['id'] as String,
                    excerpt.content,
                  );
                }
                await this.context.read<AppProvider>().removeBookExcerpt(excerpt.id);
                _loadExcerpts();
                if (mounted) ToastUtil.show(this.context, '已删除');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAllDialog() {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('确认删除', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Text('确定删除全部 ${_excerpts.length} 条摘抄吗？此操作不可恢复。', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: colors.onSurface.withValues(alpha: 0.6), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final provider = this.context.read<AppProvider>();
                for (final excerpt in _excerpts) {
                  await provider.removeBookExcerpt(excerpt.id);
                }
                _loadExcerpts();
                if (mounted) ToastUtil.show(this.context, '已删除全部摘抄');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('删除全部'),
            ),
          ],
        );
      },
    );
  }

  // ── 导入 ──

  void _showImportSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text('导入摘抄', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 微信读书
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showWechatReadImport();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF07C160).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset('assets/images/imp_book/wxreader.webp', width: 44, height: 44),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('微信读书', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colors.onSurface)),
                              const SizedBox(height: 2),
                              Text('粘贴微信读书导出的笔记', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25), size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWechatReadImport() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final controller = TextEditingController();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: colors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text('微信读书导入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              final data = await Clipboard.getData('text/plain');
                              if (data?.text != null) {
                                controller.text = data!.text!;
                              }
                            },
                            child: Text('粘贴', style: TextStyle(color: colors.primary, fontSize: 14)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: controller,
                        maxLines: 8,
                        decoration: InputDecoration(
                          hintText: '粘贴微信读书导出的笔记内容...',
                          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                          filled: true,
                          fillColor: colors.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        style: TextStyle(fontSize: 14, color: colors.onSurface),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            final text = controller.text.trim();
                            if (text.isEmpty) {
                              ToastUtil.show(sheetContext, '请粘贴内容');
                              return;
                            }
                            Navigator.pop(sheetContext);
                            _importWechatRead(text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('导入', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _importWechatRead(String text) {
    final excerpts = _parseWechatRead(text);
    if (excerpts.isEmpty) {
      ToastUtil.show(context, '未识别到有效摘抄');
      return;
    }
    _saveImportedExcerpts(excerpts);
  }

  /// 解析微信读书导出格式
  List<({String content, String comment, String chapter})> _parseWechatRead(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final results = <({String content, String comment, String chapter})>[];
    String? currentComment;
    bool waitingForOriginal = false;
    String currentChapter = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // 跳过空行和结尾
      if (line.isEmpty || line.startsWith('-- 来自微信读书')) continue;

      // 跳过书名行（以《开头）和笔记数量行
      if (line.startsWith('《') || RegExp(r'^\d+个笔记$').hasMatch(line)) continue;

      // 匹配 "◆ YYYY/MM/DD发表想法"
      final thoughtMatch = RegExp(r'^◆\s*\d{4}/\d{2}/\d{2}发表想法').firstMatch(line);
      if (thoughtMatch != null) {
        // 如果之前有未匹配原文的想法，先保存
        if (currentComment != null && !waitingForOriginal) {
          results.add((content: currentComment, comment: '', chapter: currentChapter));
          currentComment = null;
        }
        // 想法行本身可能有内容在 "发表想法" 之后
        final afterThought = line.substring(thoughtMatch.end).trim();
        currentComment = afterThought.isNotEmpty ? afterThought : '';
        waitingForOriginal = true;
        continue;
      }

      // 匹配 "原文：..."
      if (line.startsWith('原文：') || line.startsWith('原文:')) {
        final originalText = line.substring(3).trim();
        if (originalText.isNotEmpty) {
          results.add((content: originalText, comment: currentComment ?? '', chapter: currentChapter));
          currentComment = null;
          waitingForOriginal = false;
        }
        continue;
      }

      // 匹配普通划线 "◆ ..."
      if (line.startsWith('◆ ')) {
        // 如果之前有未匹配原文的想法，先保存想法本身
        if (currentComment != null && waitingForOriginal) {
          if (currentComment.isNotEmpty) {
            results.add((content: currentComment, comment: '', chapter: currentChapter));
          }
          currentComment = null;
          waitingForOriginal = false;
        }
        final content = line.substring(2).trim();
        if (content.isNotEmpty) {
          results.add((content: content, comment: '', chapter: currentChapter));
        }
        continue;
      }

      // 多行想法内容（想法紧接在 "发表想法" 行之后）
      if (currentComment != null && waitingForOriginal && line.isNotEmpty) {
        // 检查是否是 "原文：" 行
        if (line.startsWith('原文：') || line.startsWith('原文:')) {
          final originalText = line.substring(3).trim();
          if (originalText.isNotEmpty) {
            results.add((content: originalText, comment: currentComment, chapter: currentChapter));
          }
          currentComment = null;
          waitingForOriginal = false;
        } else {
          // 追加到想法内容
          currentComment = currentComment.isEmpty ? line : '$currentComment\n$line';
        }
        continue;
      }

      // 其他非空行视为章节标题
      if (line.isNotEmpty) {
        currentChapter = line;
      }
    }

    // 处理末尾残留
    if (currentComment != null && currentComment.isNotEmpty) {
      results.add((content: currentComment, comment: '', chapter: currentChapter));
    }

    return results;
  }

  Future<void> _saveImportedExcerpts(List<({String content, String comment, String chapter})> excerpts) async {
    final provider = context.read<AppProvider>();
    final now = DateTime.now();
    int imported = 0;

    for (int i = 0; i < excerpts.length; i++) {
      final item = excerpts[i];
      final excerpt = BookExcerpt(
        id: '${widget.book.id}_${now.millisecondsSinceEpoch}_$i',
        bookId: widget.book.id,
        chapter: item.chapter,
        content: item.content,
        comment: item.comment,
        createdAt: now,
        updatedAt: now,
      );
      await provider.addBookExcerpt(excerpt);
      imported++;
    }

    _loadExcerpts();
    if (mounted) {
      ToastUtil.show(context, '成功导入 $imported 条摘抄');
    }
  }
}
