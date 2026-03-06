import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑影视页面 - 极简主义设计
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
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;
  
  List<String> _directors = [];
  List<String> _writers = [];
  List<String> _actors = [];
  List<String> _genres = [];
  List<String> _alternateTitles = [];
  String? _posterPath;
  String _status = 'want_to_watch';
  DateTime? _releaseDate;
  
  @override
  void initState() {
    super.initState();
    final movie = widget.movie;
    _titleController = TextEditingController(text: movie?.title ?? '');
    _summaryController = TextEditingController(text: movie?.summary ?? '');
    _ratingController = TextEditingController(text: movie?.rating?.toString() ?? '');
    
    if (movie != null) {
      _directors = List.from(movie.directors);
      _writers = List.from(movie.writers);
      _actors = List.from(movie.actors);
      _genres = List.from(movie.genres);
      _alternateTitles = List.from(movie.alternateTitles);
      _posterPath = movie.posterPath;
      _status = movie.status;
      _releaseDate = movie.releaseDate;
    }
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    _ratingController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.movie != null;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? '编辑影视' : '添加影视'),
        actions: [
          TextButton(
            onPressed: _saveMovie,
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
            
            // 影视名称
            _buildTextField(
              controller: _titleController,
              label: '影视名称 *',
              hint: '请输入影视名称',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入影视名称';
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
            
            const SizedBox(height: 16),
            
            // 上映日期
            _buildDatePicker(),
            
            const SizedBox(height: 24),
            
            // 导演
            _buildSectionTitle('导演'),
            const SizedBox(height: 16),
            
            _buildTagInput(
              label: '导演',
              hint: '输入导演，按回车添加',
              tags: _directors,
              onAdd: (tag) => setState(() => _directors.add(tag)),
              onRemove: (index) => setState(() => _directors.removeAt(index)),
            ),
            
            const SizedBox(height: 24),
            
            // 编剧
            _buildSectionTitle('编剧'),
            const SizedBox(height: 16),
            
            _buildTagInput(
              label: '编剧',
              hint: '输入编剧，按回车添加',
              tags: _writers,
              onAdd: (tag) => setState(() => _writers.add(tag)),
              onRemove: (index) => setState(() => _writers.removeAt(index)),
            ),
            
            const SizedBox(height: 24),
            
            // 主演
            _buildSectionTitle('主演'),
            const SizedBox(height: 16),
            
            _buildTagInput(
              label: '主演',
              hint: '输入主演，按回车添加',
              tags: _actors,
              onAdd: (tag) => setState(() => _actors.add(tag)),
              onRemove: (index) => setState(() => _actors.removeAt(index)),
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
            
            // 剧情简介
            _buildSectionTitle('剧情简介'),
            const SizedBox(height: 16),
            
            _buildTextField(
              controller: _summaryController,
              label: '',
              hint: '写下剧情简介...',
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
        child: _posterPath != null && _posterPath!.isNotEmpty
            ? Image.file(
                File(_posterPath!),
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
          '添加海报',
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
  
  /// 构建日期选择器
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _selectReleaseDate,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5)),
          ),
        ),
        child: Row(
          children: [
            Text(
              _releaseDate != null
                  ? '${_releaseDate!.year}.${_releaseDate!.month.toString().padLeft(2, '0')}.${_releaseDate!.day.toString().padLeft(2, '0')}'
                  : '上映日期',
              style: TextStyle(
                fontSize: 15,
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
            SizedBox(
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
            _buildStatusOption('已看', 'watched'),
            const SizedBox(width: 12),
            _buildStatusOption('在看', 'watching'),
            const SizedBox(width: 12),
            _buildStatusOption('想看', 'want_to_watch'),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatusOption(String label, String value) {
    final isSelected = _status == value;
    Color color;
    switch (value) {
      case 'watched':
        color = const Color(0xFF1A1A1A);
        break;
      case 'watching':
        color = const Color(0xFF666666);
        break;
      case 'want_to_watch':
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
        final fileName = 'movie_poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'movie_posters', fileName);
        
        final posterDir = Directory(path.join(appDir.path, 'movie_posters'));
        if (!await posterDir.exists()) {
          await posterDir.create(recursive: true);
        }
        
        await File(pickedFile.path).copy(savedPath);
        
        setState(() => _posterPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择海报失败: $e')),
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
  
  /// 保存影视
  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final rating = _ratingController.text.isNotEmpty 
        ? double.tryParse(_ratingController.text) 
        : null;
    
    final now = DateTime.now();
    
    if (widget.movie == null) {
      // 添加新模式
      final newMovie = Movie(
        id: now.millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        posterPath: _posterPath,
        releaseDate: _releaseDate,
        directors: _directors,
        writers: _writers,
        actors: _actors,
        genres: _genres,
        alternateTitles: _alternateTitles,
        summary: _summaryController.text.trim(),
        rating: rating,
        status: _status,
        createdAt: now,
        updatedAt: now,
      );
      
      await context.read<AppProvider>().addMovie(newMovie);
    } else {
      // 编辑现有模式
      final updatedMovie = widget.movie!.copyWith(
        title: _titleController.text.trim(),
        posterPath: _posterPath,
        releaseDate: _releaseDate,
        directors: _directors,
        writers: _writers,
        actors: _actors,
        genres: _genres,
        alternateTitles: _alternateTitles,
        summary: _summaryController.text.trim(),
        rating: rating,
        status: _status,
        updatedAt: now,
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
