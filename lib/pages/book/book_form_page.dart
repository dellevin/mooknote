import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';

/// 添加/编辑书籍页面 - 紧凑双行布局设计
class BookFormPage extends StatefulWidget {
  final Book? book;
  final String? initialStatus; // 添加时的默认状态

  const BookFormPage({super.key, this.book, this.initialStatus});
  
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
  late TextEditingController _isbnController;
  
  // 多值字段的临时输入控制器
  final Map<String, TextEditingController> _tagControllers = {};
  
  // 数据
  List<String> _authors = [];
  List<String> _alternateTitles = [];
  List<String> _genres = [];
  String? _coverPath;
  String _status = 'want_to_read';
  DateTime? _publishDate;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    // 如果有传入book，尝试从Provider获取最新数据
    Book? book = widget.book;
    if (book != null) {
      final appProvider = context.read<AppProvider>();
      final latestBook = appProvider.books
          .where((b) => b.id == book!.id)
          .firstOrNull;
      if (latestBook != null) {
        book = latestBook;
      }
    }

    _titleController = TextEditingController(text: book?.title ?? '');
    _publisherController = TextEditingController(text: book?.publisher ?? '');
    _summaryController = TextEditingController(text: book?.summary ?? '');
    _ratingController = TextEditingController(text: book?.rating?.toString() ?? '');
    _isbnController = TextEditingController(text: book?.isbn ?? '');

    if (book != null) {
      _authors = List.from(book.authors);
      _alternateTitles = List.from(book.alternateTitles);
      _genres = List.from(book.genres);
      _coverPath = book.coverPath;
      _status = book.status;
      _publishDate = book.publishDate;
    } else if (widget.initialStatus != null) {
      // 添加模式：使用传入的默认状态
      _status = widget.initialStatus!;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _publisherController.dispose();
    _summaryController.dispose();
    _ratingController.dispose();
    _isbnController.dispose();
    _tagControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
  
  TextEditingController _getTagController(String key) {
    return _tagControllers.putIfAbsent(key, () => TextEditingController());
  }
  
  /// 构建右上角操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color color = const Color(0xFF1A1A1A),
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.book != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? '编辑书籍' : '添加书籍'),
        actions: [
          // 保存按钮
          _buildActionButton(
            icon: Icons.save_outlined,
            onPressed: _saveBook,
            tooltip: '保存',
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

            // 状态选择（靠左显示）
            _buildStatusSelector(),

            const SizedBox(height: 20),

            // 评分 - 星星选择（靠左显示）
            _buildStarRating(),

            const SizedBox(height: 32),

            // 书名
            _buildHorizontalFormItem(
              label: '书名',
              required: true,
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

            const SizedBox(height: 16),

            // 别名
            _buildHorizontalMultiValueItem(
              label: '别名',
              values: _alternateTitles,
              hint: '输入别名',
              controllerKey: 'alternateTitles',
              onAdd: (v) => setState(() => _alternateTitles.add(v)),
              onRemove: (i) => setState(() => _alternateTitles.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // 作者
            _buildHorizontalMultiValueItem(
              label: '作者',
              values: _authors,
              hint: '输入作者姓名',
              controllerKey: 'authors',
              onAdd: (v) => setState(() => _authors.add(v)),
              onRemove: (i) => setState(() => _authors.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // 出版社
            _buildHorizontalFormItem(
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

            const SizedBox(height: 16),

            // 类型
            _buildHorizontalMultiValueItem(
              label: '类型',
              values: _genres,
              hint: '如：小说、历史、传记',
              controllerKey: 'genres',
              onAdd: (v) => setState(() => _genres.add(v)),
              onRemove: (i) => setState(() => _genres.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // ISBN
            _buildHorizontalFormItem(
              label: 'ISBN',
              child: TextFormField(
                controller: _isbnController,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: '请输入ISBN编号',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 出版社
            _buildHorizontalFormItem(
              label: '出版社',
              child: TextFormField(
                controller: _publisherController,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: '请输入出版社名称',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 出版时间
            _buildVerticalDateItem(
              label: '出版时间',
              date: _publishDate,
              onTap: _selectPublishDate,
              onClear: () => setState(() => _publishDate = null),
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
  
  /// 构建表单条目（标签 + 内容）- 书籍简介使用
  Widget _buildFormItem({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// 构建横向表单条目（标签在左，内容在右）
  Widget _buildHorizontalFormItem({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            required ? '$label *' : label,
            style: TextStyle(
              fontSize: 13,
              color: required ? const Color(0xFF1A1A1A) : const Color(0xFF999999),
              fontWeight: required ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }

  /// 构建横向多值条目（标签在左，内容在右）
  Widget _buildHorizontalMultiValueItem({
    required String label,
    required List<String> values,
    required String hint,
    required String controllerKey,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    final controller = _getTagController(controllerKey);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...values.asMap().entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
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
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 120),
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                  decoration: InputDecoration(
                    hintText: values.isEmpty ? hint : '',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCCCCCC)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
        ),
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
  

  /// 构建状态选择器（靠左显示，带标签）
  Widget _buildStatusSelector() {
    return Row(
      children: [
        const Text(
          '状态',
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption('想读', 'want_to_read'),
              _buildStatusOption('在读', 'reading'),
              _buildStatusOption('已读', 'read'),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建星星评分（5星制，每星2分，支持手动输入）
  Widget _buildStarRating() {
    return Row(
      children: [
        const Text(
          '评分',
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
        const SizedBox(width: 16),
        // 星星选择
        _buildStarSelector(),
        const SizedBox(width: 12),
        // 手动输入框
        _buildRatingInputField(),
      ],
    );
  }

  /// 构建星星选择器
  Widget _buildStarSelector() {
    final currentRating = double.tryParse(_ratingController.text) ?? 0;
    final starRating = currentRating / 2;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final starValue = index + 1;
          final scoreValue = starValue * 2;
          final isFilled = starValue <= starRating;
          final isHalf = starValue == starRating.ceil() && starRating % 1 != 0;

          return InkWell(
            onTap: () {
              setState(() {
                _ratingController.text = scoreValue.toString();
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Icon(
                isHalf
                    ? Icons.star_half
                    : isFilled
                        ? Icons.star
                        : Icons.star_border,
                size: 24,
                color: isFilled || isHalf
                    ? const Color(0xFFFFB800)
                    : const Color(0xFFE5E5E5),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 构建评分输入框
  Widget _buildRatingInputField() {
    return Container(
      width: 56,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextFormField(
        controller: _ratingController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        decoration: const InputDecoration(
          hintText: '-',
          hintStyle: TextStyle(fontSize: 15, color: Color(0xFFCCCCCC)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        validator: (value) {
          if (value != null && value.isNotEmpty) {
            final rating = double.tryParse(value);
            if (rating == null || rating < 0 || rating > 10) {
              return '0-10';
            }
          }
          return null;
        },
        onChanged: (value) {
          // 限制输入范围
          if (value.isNotEmpty) {
            final rating = double.tryParse(value);
            if (rating != null) {
              if (rating > 10) {
                _ratingController.text = '10';
              } else if (rating < 0) {
                _ratingController.text = '0';
              }
            }
          }
          setState(() {}); // 更新星星显示
        },
      ),
    );
  }

  /// 构建纵向日期条目（标签在上，日期在下）
  Widget _buildVerticalDateItem({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  date != null
                      ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
                      : '选择日期',
                  style: TextStyle(
                    fontSize: 15,
                    color: date != null
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFFCCCCCC),
                  ),
                ),
              ),
              if (date != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF999999)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 选择出版时间
  Future<void> _selectPublishDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _publishDate = picked);
    }
  }

  /// 构建状态选项
  Widget _buildStatusOption(String label, String value) {
    final isSelected = _status == value;

    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF999999),
          ),
        ),
      ),
    );
  }

  /// 构建封面选择器
  Widget _buildCoverPicker() {
    final hasCover = _coverPath != null && _coverPath!.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: _pickCover,
          child: Container(
            width: 140,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
            ),
            child: hasCover
                ? Image.file(
                    File(_coverPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
                  )
                : _buildCoverPlaceholder(),
          ),
        ),
        // 清空封面按钮（仅当有封面时显示）
        if (hasCover)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: () => setState(() => _coverPath = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hide_image_outlined,
                      size: 16,
                      color: Color(0xFF666666),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '清空封面',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
    // 显示选择对话框
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部指示条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // 标题
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '添加封面',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 本地图片选项
              _buildCoverOption(
                icon: Icons.photo_library_outlined,
                title: '从相册选择',
                onTap: () {
                  Navigator.pop(context, 0);
                },
              ),
              // 网络链接选项
              _buildCoverOption(
                icon: Icons.link_outlined,
                title: '网络链接',
                onTap: () {
                  Navigator.pop(context, 1);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;

    if (result == 0) {
      await _pickCoverFromGallery();
    } else if (result == 1) {
      await _pickCoverFromUrl();
    }
  }

  /// 从相册选择封面
  Future<void> _pickCoverFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        // 生成文件名
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // 如果是编辑模式，使用现有书籍ID；如果是新建模式，使用临时ID（保存时会替换）
        final bookId = widget.book?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        // 保存到新的路径结构: images/books/{bookId}/{fileName}
        final targetPath = await ImagePathHelper.instance.getBookCoverPath(
          bookId, 
          fileName
        );
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
        
        await File(pickedFile.path).copy(targetPath);
        
        setState(() => _coverPath = targetPath);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '选择封面失败: $e');
      }
    }
  }

  /// 从网络链接选择封面
  Future<void> _pickCoverFromUrl() async {
    final urlController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('添加网络图片'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请输入图片链接地址',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://book.doban.com/image.jpg',
                hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                border: UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color.fromARGB(255, 58, 49, 49)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF1A1A1A)),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定', style: TextStyle(color: Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final url = urlController.text.trim();
    if (url.isEmpty) {
      ToastUtil.show(context, '请输入图片链接');
      return;
    }

    try {
      // 下载网络图片
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': 'https://book.douban.com/',
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      // 检查内容类型
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) {
        throw Exception('链接返回的不是图片');
      }

      // 检查文件大小（最大 10MB）
      if (response.bodyBytes.length > 10 * 1024 * 1024) {
        throw Exception('图片太大');
      }

      // 生成文件名
      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 如果是编辑模式，使用现有书籍ID；如果是新建模式，使用临时ID
      final bookId = widget.book?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // 保存到新的路径结构
      final targetPath = await ImagePathHelper.instance.getBookCoverPath(
        bookId, 
        fileName
      );
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));

      // 写入文件
      await File(targetPath).writeAsBytes(response.bodyBytes);

      setState(() => _coverPath = targetPath);
      
      if (mounted) {
        ToastUtil.show(context, '添加成功');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '添加失败: $e');
      }
    }
  }

  /// 构建封面选项
  Widget _buildCoverOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFCCCCCC),
              size: 20,
            ),
          ],
        ),
      ),
    );
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
      // 生成新的书籍ID
      final newBookId = now.millisecondsSinceEpoch.toString();
      
      // 如果有封面，需要移动到正确的ID目录
      String? finalCoverPath;
      if (_coverPath != null && _coverPath!.isNotEmpty) {
        finalCoverPath = await _moveCoverToNewId(_coverPath!, newBookId);
      }
      
      final newBook = Book(
        id: newBookId,
        title: _titleController.text.trim(),
        coverPath: finalCoverPath,
        authors: _authors,
        alternateTitles: _alternateTitles,
        publisher: _publisherController.text.trim(),
        genres: _genres,
        summary: _summaryController.text.trim(),
        rating: rating,
        status: _status,
        isbn: _isbnController.text.trim().isNotEmpty ? _isbnController.text.trim() : null,
        publishDate: _publishDate,
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
        isbn: _isbnController.text.trim().isNotEmpty ? _isbnController.text.trim() : null,
        publishDate: _publishDate,
        updatedAt: now,
      );
      
      await context.read<AppProvider>().updateBook(updatedBook);
    }
    
    if (!mounted) return;
    
    ToastUtil.show(context, widget.book == null ? '添加成功' : '更新成功');
    
    Navigator.pop(context);
  }
  
  /// 将封面从临时ID目录移动到新的书籍ID目录
  Future<String?> _moveCoverToNewId(String currentPath, String newBookId) async {
    // 检查是否已经在正确的目录中（兼容 Windows 路径分隔符）
    final normalizedPath = currentPath.replaceAll('\\', '/');
    if (normalizedPath.contains('/books/$newBookId/')) {
      return currentPath;
    }
    
    // 提取文件名
    final fileName = p.basename(currentPath);
    
    // 获取新路径
    final newPath = await ImagePathHelper.instance.getBookCoverPath(
      newBookId, 
      fileName
    );
    
    // 确保目标目录存在
    await ImagePathHelper.instance.ensureDirExists(p.dirname(newPath));
    
    // 移动文件
    final currentFile = File(currentPath);
    if (await currentFile.exists()) {
      await currentFile.rename(newPath);
      
      // 删除空的临时目录
      final tempDir = Directory(p.dirname(currentPath));
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          // 忽略删除目录失败的情况
        }
      }
      
      return newPath;
    }
    
    return null;
  }
}
