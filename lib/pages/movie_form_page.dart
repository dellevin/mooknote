import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑影视记录页面
class MovieFormPage extends StatefulWidget {
  final Movie? movie; // 如果为 null，则是添加模式；否则是编辑模式

  const MovieFormPage({super.key, this.movie});

  @override
  State<MovieFormPage> createState() => _MovieFormPageState();
}

class _MovieFormPageState extends State<MovieFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _yearController;
  late TextEditingController _ratingController;
  late TextEditingController _noteController;
  late String _status;
  DateTime? _watchDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.movie?.title ?? '');
    _yearController = TextEditingController(text: widget.movie?.year?.toString() ?? '');
    _ratingController = TextEditingController(text: widget.movie?.rating?.toString() ?? '');
    _noteController = TextEditingController(text: widget.movie?.note ?? '');
    _status = widget.movie?.status ?? 'want_to_watch';
    _watchDate = widget.movie?.watchDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _ratingController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.movie != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑影片' : '添加影片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveMovie,
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
                  labelText: '影片名称 *',
                  hintText: '请输入影片名称',
                  prefixIcon: Icon(Icons.movie),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入影片名称';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 年份和评分
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: '年份',
                        hintText: '例如：2024',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),

                  const SizedBox(width: 16),

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
                  DropdownMenuItem(value: 'watched', child: Text('已看')),
                  DropdownMenuItem(value: 'want_to_watch', child: Text('想看')),
                  DropdownMenuItem(value: 'watching', child: Text('在看')),
                ],
                onChanged: (value) {
                  setState(() {
                    _status = value!;
                  });
                },
              ),

              const SizedBox(height: 16),

              // 观看日期选择
              InkWell(
                onTap: _selectWatchDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '观看日期',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _watchDate != null
                            ? '${_watchDate!.year}-${_watchDate!.month.toString().padLeft(2, '0')}-${_watchDate!.day.toString().padLeft(2, '0')}'
                            : '选择日期',
                        style: TextStyle(
                          color: _watchDate != null
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_watchDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _watchDate = null;
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
                  hintText: '写下你的观后感...',
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
                  onPressed: _saveMovie,
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

  /// 选择观看日期
  Future<void> _selectWatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _watchDate = picked;
      });
    }
  }

  /// 保存影视记录
  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final year = _yearController.text.isNotEmpty ? int.tryParse(_yearController.text) : null;
    final rating = _ratingController.text.isNotEmpty ? double.tryParse(_ratingController.text) : null;

    if (widget.movie == null) {
      // 添加新模式
      final newMovie = Movie(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        year: year,
        rating: rating,
        status: _status,
        watchDate: _watchDate,
        note: _noteController.text.trim(),
      );

      await context.read<AppProvider>().addMovie(newMovie);
    } else {
      // 编辑现有模式
      final updatedMovie = Movie(
        id: widget.movie!.id,
        title: _titleController.text.trim(),
        year: year,
        rating: rating,
        status: _status,
        watchDate: _watchDate,
        note: _noteController.text.trim(),
      );

      await context.read<AppProvider>().updateMovie(updatedMovie);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.movie == null ? '添加成功' : '更新成功'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }
}
