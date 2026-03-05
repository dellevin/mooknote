import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑笔记页面
class NoteFormPage extends StatefulWidget {
  final Note? note; // 如果为 null，则是添加模式；否则是编辑模式

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _tagsController = TextEditingController(
      text: widget.note?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑笔记' : '添加笔记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题 *',
                  hintText: '请输入笔记标题',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入标题';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 标签
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '多个标签用逗号分隔',
                  prefixIcon: Icon(Icons.local_offer),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // 内容
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '内容 *',
                  hintText: '请输入笔记内容...',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 15,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入内容';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveNote,
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? '保存修改' : '添加笔记'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 保存笔记
  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 解析标签
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (widget.note == null) {
      // 添加新模式
      final now = DateTime.now();
      final newNote = Note(
        id: now.millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );

      await context.read<AppProvider>().addNote(newNote);
    } else {
      // 编辑现有模式
      final updatedNote = Note(
        id: widget.note!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        tags: tags,
        createdAt: widget.note!.createdAt,
        updatedAt: DateTime.now(),
      );

      await context.read<AppProvider>().updateNote(updatedNote);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.note == null ? '添加成功' : '更新成功'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }
}
