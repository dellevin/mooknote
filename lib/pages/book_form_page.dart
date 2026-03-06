import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑书籍页面 - 极简主义设计
class BookFormPage extends StatefulWidget {
  final Book? book;
  
  const BookFormPage({super.key, this.book});
  
  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _titleController;
  late TextEditingController _publisherController;
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;
  
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
    super.dispose();
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
          padding: const EdgeInsets.all(24),
          children: [
            // 封面选择
            _buildCoverPicker(),
            
            const SizedBox(height: 32),
            
            // 基本信息
            _buildSectionTitle('基本信息'),
            const SizedBox(height: 16),
            
            // 书名
            _buildTextField(
              controller: _titleController,
              label: '书名 *',
              hint: '请输入书名',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入书名';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // 别名
            _buildTagInput(
              label: '别名',
              hint: '输入别名，按回车添加',
              tags: _alternateTitles,
              onAdd: (tag) => setState(() => _alternateTitles.add(tag)),
              onRemove: (index) => setState(() => _alternateTitles.removeAt(index)),
            ),
            
            const SizedBox(height: 24),
            
            // 作者
            _buildSectionTitle('作者'),
            const SizedBox(height: 16),
            
            _buildTagInput(
              label: '作者',
              hint: '输入作者，按回车添加',
              tags: _authors,
              onAdd: (tag) => setState(() => _authors.add(tag)),
              onRemove: (index) => setState(() => _authors.removeAt(index)),
            ),
            
            const SizedBox(height: 24),
            
            // 出版社
            _buildTextField(
              controller: _publisherController,
              label: '出版社',
              hint: '请输入出版社',
            ),
            
            const SizedBox(height: 24),
            
            // 类型
            _buildSectionTitle('类型'),
            const SizedBox(height: 16),
            
            _buildTagInput(
              label: '类型',
              hint: '输入类型，按回车添加',
              tags: _genres,
              onAdd: (tag) => setState(() => _genres.add(tag)),
              onRemove: (index) => setState(() => _genres.removeAt(index)),
            ),
            
            const SizedBox(height: 24),
            
            // 书籍简介
            _buildSectionTitle('书籍简介'),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _summaryController,
              label: '',
              hint: '写下书籍简介...',
              maxLines: 5,
            ),
            
            const SizedBox(height: 24),
            
            // 评分和状态
            _buildSectionTitle('评分与状态'),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _ratingController,
                    label: '评分',
                    hint: '1-10',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildStatusSelector(),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
  
  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF999999),
        letterSpacing: 1,
      ),
    );
  }
  
  /// 构建封面选择器
  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        width: 120,
        height: 160,
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
          size: 32,
          color: Color(0xFF999999),
        ),
        SizedBox(height: 8),
        Text(
          '添加封面',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF999999),
          ),
        ),
      ],
    );
  }
  
  /// 构建文本输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFF666666),
        ),
        hintStyle: const TextStyle(
          fontSize: 14,
          color: Color(0xFFCCCCCC),
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E5E5)),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E5E5)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1A1A1A)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
  
  /// 构建标签输入
  Widget _buildTagInput({
    required String label,
    required String hint,
    required List<String> tags,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...tags.asMap().entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Container(
              width: 120,
              child: TextField(
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFCCCCCC),
                  ),
                  border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE5E5E5)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty && !tags.contains(value.trim())) {
                    onAdd(value.trim());
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建状态选择器
  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '状态',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStatusOption('已读', 'read'),
            const SizedBox(width: 12),
            _buildStatusOption('在读', 'reading'),
            const SizedBox(width: 12),
            _buildStatusOption('想读', 'want_to_read'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatusOption(String label, String value) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : color,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
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
      // 添加新模式
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
      // 编辑现有模式
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
