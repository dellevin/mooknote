import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.note.content,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                  height: 1.8,
                ),
              ),
            ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
