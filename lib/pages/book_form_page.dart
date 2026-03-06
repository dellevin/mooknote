import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑书籍页面 - 紧凑双行布局设计
class BookFormPage extends StatefulWidget {
  final Book? book;
  
  const BookFormPage({super.key, this.book});
  
  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // 输入框控制器
  late TextEditingController _titleController;
  late TextEditingController _publisherController;
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;
  
  // 多值字段的临时输入控制器
  final Map<String, TextEditingController> _tagControllers = {};
  
  // 数据
  List<String> _authors = [];
  List<String> _alternateTitles = [];
  List<String> _genres = [];
  String? _coverPath;
  String _status = 'want_to_read';
  
  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _titleController = TextEditingController(text: book?.title ?? '');
    _publisherController = TextEditingController(text: book?.publisher ?? '');
    _summaryController = TextEditingController(text: book?.summary ?? '');
    _ratingController = TextEditingController(text: book?.rating?.toString() ?? '');
    
    if (book != null) {
      _authors = List.from(book.authors);
      _alternateTitles = List.from(book.alternateTitles);
      _genres = List.from(book.genres);
      _coverPath = book.coverPath;
      _status = book.status;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _publisherController.dispose();
    _summaryController.dispose();
    _ratingController.dispose();
    _tagControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
  
  TextEditingController _getTagController(String key) {
    return _tagControllers.putIfAbsent(key, () => TextEditingController());
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.book != null;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? '编辑书籍' : '添加书籍'),
        actions: [
          TextButton(
            onPressed: _saveBook,
            child: const Text(
              '保存',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // 封面选择 - 居中显示
            Center(child: _buildCoverPicker()),
            
            const SizedBox(height: 32),
            
            // 基本信息区域
            _buildFormItem(
              label: '书名 *',
              child: TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: '请输入书名',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入书名';
                  }
                  return null;
                },
              ),
            ),
            
            _buildDivider(),
            
            // 别名
            _buildMultiValueItem(
              label: '别名',
              values: _alternateTitles,
              hint: '输入别名',
              controllerKey: 'alternateTitles',
              onAdd: (v) => setState(() => _alternateTitles.add(v)),
              onRemove: (i) => setState(() => _alternateTitles.removeAt(i)),
            ),
            
            _buildDivider(),
            
            // 作者
            _buildMultiValueItem(
              label: '作者',
              values: _authors,
              hint: '输入作者姓名',
              controllerKey: 'authors',
              onAdd: (v) => setState(() => _authors.add(v)),
              onRemove: (i) => setState(() => _authors.removeAt(i)),
            ),
            
            _buildDivider(),
            
            // 出版社
            _buildFormItem(
              label: '出版社',
              child: TextFormField(
                controller: _publisherController,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: '请输入出版社',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            
            _buildDivider(),
            
            // 类型
            _buildMultiValueItem(
              label: '类型',
              values: _genres,
              hint: '如：小说、历史',
              controllerKey: 'genres',
              onAdd: (v) => setState(() => _genres.add(v)),
              onRemove: (i) => setState(() => _genres.removeAt(i)),
            ),
            
            _buildDivider(),
            
            // 书籍简介
            _buildFormItem(
              label: '书籍简介',
              child: TextFormField(
                controller: _summaryController,
                maxLines: 4,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), height: 1.5),
                decoration: const InputDecoration(
                  hintText: '写下书籍简介...',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            
            _buildDivider(),
            
            // 评分
            _buildFormItem(
              label: '评分',
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ratingController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                      decoration: const InputDecoration(
                        hintText: '1-10',
                        hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final rating = double.tryParse(value);
                          if (rating == null || rating < 1 || rating > 10) {
                            return '评分必须在 1-10 之间';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                  if (_ratingController.text.isNotEmpty)
                    const Text(
                      '分',
                      style: TextStyle(fontSize: 14, color: Color(0xFF999999)),
                    ),
                ],
              ),
            ),
            
            _buildDivider(),
            
            // 状态
            _buildFormItem(
              label: '状态',
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 12,
                  children: [
                    _buildStatusChip('想读', 'want_to_read'),
                    _buildStatusChip('在读', 'reading'),
                    _buildStatusChip('已读', 'read'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
  
  /// 构建表单条目（标签 + 内容）
  Widget _buildFormItem({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: label.contains('*') ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
            fontWeight: label.contains('*') ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
  
  /// 构建多值条目
  Widget _buildMultiValueItem({
    required String label,
    required List<String> values,
    required String hint,
    required String controllerKey,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    final controller = _getTagController(controllerKey);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：标签 + 添加按钮
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
            ),
            const Spacer(),
            // 添加按钮（当输入框有内容时显示）
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: hasText
                      ? () {
                          final text = controller.text.trim();
                          if (text.isNotEmpty && !values.contains(text)) {
                            onAdd(text);
                            controller.clear();
                          }
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hasText ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: hasText ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasText ? const Color(0xFF1A1A1A) : const Color(0xFFCCCCCC),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 第二行：已选标签 + 输入框
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...values.asMap().entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: const Icon(Icons.close, size: 14, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              );
            }),
            // 输入框
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 150),
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: values.isEmpty ? hint : '',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                ),
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty && !values.contains(trimmed)) {
                    onAdd(trimmed);
                    controller.clear();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建分隔线
  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 0.5,
      color: const Color(0xFFE5E5E5),
    );
  }
  
  /// 构建状态选择 Chip
  Widget _buildStatusChip(String label, String value) {
    final isSelected = _status == value;
    Color color;
    switch (value) {
      case 'read':
        color = const Color(0xFF1A1A1A);
        break;
      case 'reading':
        color = const Color(0xFF666666);
        break;
      case 'want_to_read':
        color = const Color(0xFF999999);
        break;
      default:
        color = const Color(0xFFCCCCCC);
    }
    
    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
  
  /// 构建封面选择器
  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        width: 140,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
        ),
        child: _coverPath != null && _coverPath!.isNotEmpty
            ? Image.file(
                File(_coverPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
              )
            : _buildCoverPlaceholder(),
      ),
    );
  }
  
  Widget _buildCoverPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: Color(0xFF999999),
        ),
        SizedBox(height: 12),
        Text(
          '点击添加封面',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }
  
  /// 选择封面
  Future<void> _pickCover() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'book_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'book_covers', fileName);
        
        final coverDir = Directory(path.join(appDir.path, 'book_covers'));
        if (!await coverDir.exists()) {
          await coverDir.create(recursive: true);
        }
        
        await File(pickedFile.path).copy(savedPath);
        
        setState(() => _coverPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择封面失败: $e')),
        );
      }
    }
  }
  
  /// 保存书籍
  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final rating = _ratingController.text.isNotEmpty 
        ? double.tryParse(_ratingController.text) 
        : null;
    
    final now = DateTime.now();
    
    if (widget.book == null) {
      final newBook = Book(
        id: now.millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        coverPath: _coverPath,
        authors: _authors,
        alternateTitles: _alternateTitles,
        publisher: _publisherController.text.trim(),
        genres: _genres,
        summary: _summaryController.text.trim(),
        rating: rating,
        status: _status,
        createdAt: now,
        updatedAt: now,
      );
      
      await context.read<AppProvider>().addBook(newBook);
    } else {
      final updatedBook = widget.book!.copyWith(
        title: _titleController.text.trim(),
        coverPath: _coverPath,
        authors: _authors,
        alternateTitles: _alternateTitles,
        publisher: _publisherController.text.trim(),
        genres: _genres,
        summary: _summaryController.text.trim(),
        rating: rating,
        status: _status,
        updatedAt: now,
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
