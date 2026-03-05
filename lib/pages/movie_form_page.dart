import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑影视记录 - 极简主义设计
class MovieFormPage extends StatefulWidget {
  final Movie? movie;

  const MovieFormPage({super.key, this.movie});

  @override
  State<MovieFormPage> createState() => _MovieFormPageState();
}

class _MovieFormPageState extends State<MovieFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _titleController;
  late TextEditingController _ratingController;
  late TextEditingController _summaryController;
  
  final List<TextEditingController> _directorControllers = [];
  final List<TextEditingController> _writerControllers = [];
  final List<TextEditingController> _actorControllers = [];
  final List<TextEditingController> _genreControllers = [];
  final List<TextEditingController> _alternateTitleControllers = [];
  
  late String _status;
  DateTime? _releaseDate;
  String? _posterPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final movie = widget.movie;
    
    _titleController = TextEditingController(text: movie?.title ?? '');
    _ratingController = TextEditingController(text: movie?.rating?.toString() ?? '');
    _summaryController = TextEditingController(text: movie?.summary ?? '');
    
    _status = movie?.status ?? 'want_to_watch';
    _releaseDate = movie?.releaseDate;
    _posterPath = movie?.posterPath;
    
    _initListControllers(movie?.directors ?? [], _directorControllers);
    _initListControllers(movie?.writers ?? [], _writerControllers);
    _initListControllers(movie?.actors ?? [], _actorControllers);
    _initListControllers(movie?.genres ?? [], _genreControllers);
    _initListControllers(movie?.alternateTitles ?? [], _alternateTitleControllers);
  }

  void _initListControllers(List<String> items, List<TextEditingController> controllers) {
    if (items.isEmpty) {
      controllers.add(TextEditingController());
    } else {
      for (final item in items) {
        controllers.add(TextEditingController(text: item));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ratingController.dispose();
    _summaryController.dispose();
    
    for (final c in _directorControllers) c.dispose();
    for (final c in _writerControllers) c.dispose();
    for (final c in _actorControllers) c.dispose();
    for (final c in _genreControllers) c.dispose();
    for (final c in _alternateTitleControllers) c.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.movie != null;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑' : '添加'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveMovie,
            child: _isLoading 
              ? SizedBox(
                  width: 18, 
                  height: 18, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)
                )
              : Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 海报
              _buildPosterSection(),
              
              const SizedBox(height: 40),
              
              // 基本信息
              _buildSectionTitle('基本信息'),
              const SizedBox(height: 24),
              
              // 影视名称
              _buildTextField(
                controller: _titleController,
                label: '名称',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入影视名称';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 24),
              
              // 上映日期
              _buildDatePicker(),
              
              const SizedBox(height: 24),
              
              // 评分
              _buildTextField(
                controller: _ratingController,
                label: '评分',
                hint: '1-10',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final rating = double.tryParse(value);
                    if (rating == null || rating < 1 || rating > 10) {
                      return '评分范围 1-10';
                    }
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // 状态
              _buildSectionTitle('状态'),
              const SizedBox(height: 16),
              _buildStatusSelector(),
              
              const SizedBox(height: 40),
              
              // 别名
              _buildSectionTitle('别名'),
              const SizedBox(height: 16),
              _buildTagList(_alternateTitleControllers),
              
              const SizedBox(height: 40),
              
              // 导演
              _buildSectionTitle('导演'),
              const SizedBox(height: 16),
              _buildTagList(_directorControllers),
              
              const SizedBox(height: 40),
              
              // 编剧
              _buildSectionTitle('编剧'),
              const SizedBox(height: 16),
              _buildTagList(_writerControllers),
              
              const SizedBox(height: 40),
              
              // 主演
              _buildSectionTitle('主演'),
              const SizedBox(height: 16),
              _buildTagList(_actorControllers),
              
              const SizedBox(height: 40),
              
              // 类型
              _buildSectionTitle('类型'),
              const SizedBox(height: 16),
              _buildTagList(_genreControllers),
              
              const SizedBox(height: 40),
              
              // 剧情简介
              _buildSectionTitle('简介'),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _summaryController,
                label: '',
                hint: '剧情简介...',
                maxLines: 6,
              ),
              
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  /// 海报区域 - 极简
  Widget _buildPosterSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 120,
          height: 170,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(
              color: const Color(0xFFE5E5E5),
              width: 0.5,
            ),
          ),
          child: _posterPath != null && _posterPath!.isNotEmpty
              ? Image.file(
                  File(_posterPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Text(
        '添加海报',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF999999),
        ),
      ),
    );
  }

  /// 区块标题 - 大写字母，小字号
  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Color(0xFF999999),
        letterSpacing: 1,
      ),
    );
  }

  /// 文本输入框 - 极简无边框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 15,
          color: Color(0xFFCCCCCC),
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1A1A1A), width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  /// 日期选择器
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _selectReleaseDate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              _releaseDate != null
                  ? '${_releaseDate!.year}.${_releaseDate!.month.toString().padLeft(2, '0')}.${_releaseDate!.day.toString().padLeft(2, '0')}'
                  : '上映日期',
              style: TextStyle(
                fontSize: 16,
                color: _releaseDate != null
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFFCCCCCC),
              ),
            ),
            const Spacer(),
            if (_releaseDate != null)
              GestureDetector(
                onTap: () => setState(() => _releaseDate = null),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFF999999),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 状态选择器 - 极简分段
  Widget _buildStatusSelector() {
    final statuses = [
      {'value': 'watching', 'label': '在看'},
      {'value': 'watched', 'label': '已看'},
      {'value': 'want_to_watch', 'label': '想看'},
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      child: Row(
        children: statuses.asMap().entries.map((entry) {
          final isSelected = _status == entry.value['value'];
          final isLast = entry.key == statuses.length - 1;
          
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _status = entry.value['value'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A1A1A) : Colors.transparent,
                  border: !isLast 
                      ? const Border(
                          right: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
                        )
                      : null,
                ),
                child: Text(
                  entry.value['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 标签列表 - 极简输入
  Widget _buildTagList(List<TextEditingController> controllers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Container(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A1A1A),
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: '输入...',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFCCCCCC),
                      ),
                    ),
                  ),
                ),
                if (controllers.length > 1)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.dispose();
                        controllers.removeAt(index);
                      });
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text(
                        '删除',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        
        // 添加按钮
        GestureDetector(
          onTap: () => setState(() => controllers.add(TextEditingController())),
          child: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '+ 添加',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 选择图片
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'posters', fileName);
        
        final posterDir = Directory(path.join(appDir.path, 'posters'));
        if (!await posterDir.exists()) {
          await posterDir.create(recursive: true);
        }
        
        await File(pickedFile.path).copy(savedPath);
        
        setState(() => _posterPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// 选择日期
  Future<void> _selectReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? DateTime.now(),
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
      setState(() => _releaseDate = picked);
    }
  }

  /// 保存
  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final rating = _ratingController.text.isNotEmpty 
          ? double.tryParse(_ratingController.text) 
          : null;

      final directors = _collectNonEmptyTexts(_directorControllers);
      final writers = _collectNonEmptyTexts(_writerControllers);
      final actors = _collectNonEmptyTexts(_actorControllers);
      final genres = _collectNonEmptyTexts(_genreControllers);
      final alternateTitles = _collectNonEmptyTexts(_alternateTitleControllers);

      final now = DateTime.now();

      if (widget.movie == null) {
        final newMovie = Movie(
          id: now.millisecondsSinceEpoch.toString(),
          title: _titleController.text.trim(),
          posterPath: _posterPath,
          releaseDate: _releaseDate,
          directors: directors,
          writers: writers,
          actors: actors,
          genres: genres,
          alternateTitles: alternateTitles,
          summary: _summaryController.text.trim().isEmpty 
              ? null 
              : _summaryController.text.trim(),
          rating: rating,
          status: _status,
          createdAt: now,
          updatedAt: now,
        );

        await context.read<AppProvider>().addMovie(newMovie);
      } else {
        final updatedMovie = widget.movie!.copyWith(
          title: _titleController.text.trim(),
          posterPath: _posterPath,
          releaseDate: _releaseDate,
          directors: directors,
          writers: writers,
          actors: actors,
          genres: genres,
          alternateTitles: alternateTitles,
          summary: _summaryController.text.trim().isEmpty 
              ? null 
              : _summaryController.text.trim(),
          rating: rating,
          status: _status,
          updatedAt: now,
        );

        await context.read<AppProvider>().updateMovie(updatedMovie);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _collectNonEmptyTexts(List<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
}
