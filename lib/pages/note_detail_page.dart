import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';

/// 笔记详情页 - 极简主义设计
class NoteDetailPage extends StatefulWidget {
  final Note note;

  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_formatDateTime(widget.note.createdAt)),
        actions: [
          // 格式指示器
          if (widget.note.contentType == 'markdown')
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                border: Border.all(color: const Color(0xFFE5E5E5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.code, size: 14, color: Color(0xFF666666)),
                  SizedBox(width: 4),
                  Text(
                    'Markdown',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _navigateToEdit(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 标签区域
          if (widget.note.tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // 内容区域
          Expanded(
            child: widget.note.contentType == 'markdown'
                ? _buildMarkdownContent()
                : _buildPlainTextContent(),
          ),

          // 底部操作栏
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '更新于 ${_formatDateTime(widget.note.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: const Color(0xFF666666),
                          onPressed: () => _navigateToEdit(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: Colors.red,
                          onPressed: () => _showDeleteDialog(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 Markdown 内容
  Widget _buildMarkdownContent() {
    return Markdown(
      data: widget.note.content,
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          height: 1.4,
        ),
        h2: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          height: 1.4,
        ),
        h3: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          height: 1.4,
        ),
        p: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          height: 1.8,
        ),
        code: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A1A),
          backgroundColor: Color(0xFFF5F5F5),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        blockquote: const TextStyle(
          fontSize: 16,
          color: Color(0xFF666666),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: const Color(0xFF999999), width: 4),
          ),
        ),
        listBullet: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1A1A1A),
        ),
        a: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          decoration: TextDecoration.underline,
        ),
      ),
      padding: const EdgeInsets.all(24),
    );
  }

  /// 构建纯文本内容
  Widget _buildPlainTextContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Text(
        widget.note.content,
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          height: 1.8,
        ),
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/note-form', arguments: widget.note).then((_) {
      context.read<AppProvider>().loadNotes();
    });
  }

  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeNote(widget.note.id);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
