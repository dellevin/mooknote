import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
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

  bool get _isEditing => widget.excerpt != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _chapterController.text = widget.excerpt!.chapter;
      _contentController.text = widget.excerpt!.content;
      _commentController.text = widget.excerpt!.comment;
    }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isEditing ? '编辑摘抄' : '添加摘抄'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExcerpt,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    '保存',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 章节
            TextFormField(
              controller: _chapterController,
              decoration: const InputDecoration(
                labelText: '章节（可选）',
                hintText: '例如：第一章、第3节等',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF1A1A1A)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 摘抄内容
            TextFormField(
              controller: _contentController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '摘抄内容',
                hintText: '输入你想要摘抄的内容...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF1A1A1A)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入摘抄内容';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // 评论/感悟
            TextFormField(
              controller: _commentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '我的感悟（可选）',
                hintText: '记录你对这段内容的思考和感悟...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: Color(0xFF1A1A1A)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '摘抄已更新' : '摘抄已添加')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

