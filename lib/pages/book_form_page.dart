import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑书籍记录页面
class BookFormPage extends StatefulWidget {
  final Book? book; // 如果为 null，则是添加模式；否则是编辑模式

  const BookFormPage({super.key, this.book});

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _ratingController;
  late TextEditingController _noteController;
  late String _status;
  DateTime? _readDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book?.title ?? '');
    _authorController = TextEditingController(text: widget.book?.author ?? '');
    _ratingController = TextEditingController(text: widget.book?.rating?.toString() ?? '');
    _noteController = TextEditingController(text: widget.book?.note ?? '');
    _status = widget.book?.status ?? 'want_to_read';
    _readDate = widget.book?.readDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _ratingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.book != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑书籍' : '添加书籍'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveBook,
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
                  labelText: '书名 *',
                  hintText: '请输入书名',
                  prefixIcon: Icon(Icons.menu_book),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入书名';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 作者
              TextFormField(
                controller: _authorController,
                decoration: const InputDecoration(
                  labelText: '作者',
                  hintText: '请输入作者',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              // 年份和评分
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ratingController,
                      decoration: const InputDecoration(
                        labelText: '评分',
                        hintText: '0-10',
                        prefixIcon: Icon(Icons.star),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final rating = double.tryParse(value);
                          if (rating == null || rating < 0 || rating > 10) {
                            return '评分必须在 0-10 之间';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 状态选择
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: '状态',
                  prefixIcon: Icon(Icons.check_circle_outline),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'read', child: Text('读完')),
                  DropdownMenuItem(value: 'reading', child: Text('在读')),
                  DropdownMenuItem(value: 'want_to_read', child: Text('准备读')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),

              const SizedBox(height: 16),

              // 阅读日期选择
              InkWell(
                onTap: _selectReadDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '阅读日期',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _readDate != null
                            ? '${_readDate!.year}-${_readDate!.month.toString().padLeft(2, '0')}-${_readDate!.day.toString().padLeft(2, '0')}'
                            : '选择日期',
                        style: TextStyle(
                          color: _readDate != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_readDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _readDate = null;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 笔记
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '笔记',
                  hintText: '写下你的读后感...',
                  prefixIcon: Icon(Icons.edit_note),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),

              const SizedBox(height: 32),

              // 保存按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveBook,
                  icon: const Icon(Icons.save),
                  label: Text(isEdit ? '保存修改' : '添加记录'),
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

  /// 选择阅读日期
  Future<void> _selectReadDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _readDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _readDate = picked;
      });
    }
  }

  /// 保存书籍记录
  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final rating = _ratingController.text.isNotEmpty ? double.tryParse(_ratingController.text) : null;

    if (widget.book == null) {
      // 添加新模式
      final newBook = Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        rating: rating,
        status: _status,
        readDate: _readDate,
        note: _noteController.text.trim(),
      );

      await context.read<AppProvider>().addBook(newBook);
    } else {
      // 编辑现有模式
      final updatedBook = Book(
        id: widget.book!.id,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        rating: rating,
        status: _status,
        readDate: _readDate,
        note: _noteController.text.trim(),
      );

      await context.read<AppProvider>().updateBook(updatedBook);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.book == null ? '添加成功' : '更新成功'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }
}
