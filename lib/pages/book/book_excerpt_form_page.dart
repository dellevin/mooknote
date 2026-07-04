import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import 'book_excerpt_share_page.dart';
import 'package:uuid/uuid.dart';

/// 摘抄表单页面 - 新增/编辑摘抄
class BookExcerptFormPage extends StatefulWidget {
  final String bookId;
  final BookExcerpt? excerpt;

  const BookExcerptFormPage({
    super.key,
    required this.bookId,
    this.excerpt,
  });

  @override
  State<BookExcerptFormPage> createState() => _BookExcerptFormPageState();
}

class _BookExcerptFormPageState extends State<BookExcerptFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _chapterController = TextEditingController();
  final _contentController = TextEditingController();
  final _commentController = TextEditingController();

  bool _isLoading = false;
  String _bookTitle = '';

  bool get _isEditing => widget.excerpt != null;
  int get _contentChars => _contentController.text.trim().length;
  int get _commentChars => _commentController.text.trim().length;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _chapterController.text = widget.excerpt!.chapter;
      _contentController.text = widget.excerpt!.content;
      _commentController.text = widget.excerpt!.comment;
    }
    _contentController.addListener(() => setState(() {}));
    _commentController.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBookTitle();
  }

  void _loadBookTitle() {
    final provider = context.read<AppProvider>();
    final book = provider.books.where((b) => b.id == widget.bookId).firstOrNull;
    if (book != null) setState(() => _bookTitle = book.title);
  }

  @override
  void dispose() {
    _chapterController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(_isEditing ? '编辑摘抄' : '添加摘抄'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: '分享',
                onPressed: _shareExcerpt,
              ),
            TextButton(
              onPressed: _saveExcerpt,
              child: Text('保存', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary)),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 所属书籍
              if (_bookTitle.isNotEmpty) ...[
                _buildBookInfo(colors),
                const SizedBox(height: 24),
              ],

              // 章节
              _buildLabel(colors, Icons.bookmark_outlined, '章节'),
              const SizedBox(height: 8),
              _buildInput(
                colors: colors,
                controller: _chapterController,
                hintText: '例如：第一章、第3节',
              ),
              const SizedBox(height: 24),

              // 摘抄内容
              _buildLabel(colors, Icons.format_quote, '摘抄内容', required: true),
              const SizedBox(height: 8),
              _buildContentInput(colors),
              const SizedBox(height: 24),

              // 我的感悟
              _buildLabel(colors, Icons.lightbulb_outline, '我的感悟'),
              const SizedBox(height: 8),
              _buildCommentInput(colors),
            ],
          ),
        ),
      ),
    );
  }

  // ── 所属书籍 ──

  Widget _buildBookInfo(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _bookTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 标签 ──

  Widget _buildLabel(ColorScheme colors, IconData icon, String title, {bool required = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface.withValues(alpha: 0.5))),
        if (required) ...[
          const SizedBox(width: 2),
          Text(' *', style: TextStyle(fontSize: 13, color: colors.error)),
        ],
      ],
    );
  }

  // ── 章节输入框 ──

  Widget _buildInput({
    required ColorScheme colors,
    required TextEditingController controller,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 15, color: colors.onSurface),
      decoration: _inputDecoration(colors, hintText: hintText),
    );
  }

  // ── 摘抄内容输入框 ──

  Widget _buildContentInput(ColorScheme colors) {
    return TextFormField(
      controller: _contentController,
      maxLines: null,
      minLines: 6,
      style: TextStyle(fontSize: 15, height: 1.8, color: colors.onSurface),
      textAlignVertical: TextAlignVertical.top,
      decoration: _inputDecoration(
        colors,
        hintText: '在这里粘贴或输入书中的原文段落…',
        charCount: _contentChars,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return '请输入摘抄内容';
        return null;
      },
    );
  }

  // ── 感悟输入框 ──

  Widget _buildCommentInput(ColorScheme colors) {
    return TextFormField(
      controller: _commentController,
      maxLines: null,
      minLines: 3,
      style: TextStyle(fontSize: 15, height: 1.8, color: colors.onSurface),
      textAlignVertical: TextAlignVertical.top,
      decoration: _inputDecoration(
        colors,
        hintText: '记录思考、联想或评论…',
        charCount: _commentChars,
      ),
    );
  }

  // ── 统一输入框样式 ──

  InputDecoration _inputDecoration(ColorScheme colors, {String? hintText, int? charCount}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
      counterText: '',
      suffix: charCount != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('$charCount字', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
            )
          : null,
    );
  }

  // ─── 保存逻辑 ─────────────────────────────────────────────

  Future<void> _saveExcerpt() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final excerpt = BookExcerpt(
        id: _isEditing ? widget.excerpt!.id : const Uuid().v4(),
        bookId: widget.bookId,
        chapter: _chapterController.text.trim(),
        content: _contentController.text.trim(),
        comment: _commentController.text.trim(),
        isDeleted: false,
        createdAt: _isEditing ? widget.excerpt!.createdAt : now,
        updatedAt: now,
      );
      if (_isEditing) {
        await context.read<AppProvider>().updateBookExcerpt(excerpt);
      } else {
        await context.read<AppProvider>().addBookExcerpt(excerpt);
      }
      if (mounted) {
        Navigator.pop(context);
        ToastUtil.show(context, _isEditing ? '摘抄已更新' : '摘抄已添加');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '保存失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareExcerpt() {
    if (widget.excerpt == null) return;
    final provider = context.read<AppProvider>();
    final book = provider.books.where((b) => b.id == widget.bookId).firstOrNull;
    if (book == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => BookExcerptSharePage(excerpt: widget.excerpt!, book: book),
    ));
  }
}
