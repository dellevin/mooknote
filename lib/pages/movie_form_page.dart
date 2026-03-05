import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 添加/编辑影视记录页面
class MovieFormPage extends StatefulWidget {
  final Movie? movie;

  const MovieFormPage({super.key, this.movie});

  @override
  State<MovieFormPage> createState() => _MovieFormPageState();
}

class _MovieFormPageState extends State<MovieFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // 文本控制器
  late TextEditingController _titleController;
  late TextEditingController _ratingController;
  late TextEditingController _summaryController;
  
  // 列表控制器（导演、编剧、演员、类型、别名）
  final List<TextEditingController> _directorControllers = [];
  final List<TextEditingController> _writerControllers = [];
  final List<TextEditingController> _actorControllers = [];
  final List<TextEditingController> _genreControllers = [];
  final List<TextEditingController> _alternateTitleControllers = [];
  
  // 状态
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
    
    // 初始化列表控制器
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEdit ? '编辑影片' : '添加影片',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveMovie,
            child: _isLoading 
              ? SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)
                )
              : Text('保存', style: TextStyle(color: colorScheme.primary)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 海报上传区域
              _buildPosterSection(),
              
              const SizedBox(height: 24),
              
              // 基本信息
              _buildSectionTitle('基本信息'),
              const SizedBox(height: 12),
              
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
              
              // 上映日期和评分
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _ratingController,
                      label: '评分',
                      hint: '1-10',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final rating = double.tryParse(value);
                          if (rating == null || rating < 1 || rating > 10) {
                            return '评分1-10';
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
              _buildStatusSelector(),
              
              const SizedBox(height: 24),
              
              // 别名
              _buildSectionTitle('别名'),
              const SizedBox(height: 8),
              _buildTagList(_alternateTitleControllers, '添加别名'),
              
              const SizedBox(height: 24),
              
              // 导演
              _buildSectionTitle('导演'),
              const SizedBox(height: 8),
              _buildTagList(_directorControllers, '添加导演'),
              
              const SizedBox(height: 24),
              
              // 编剧
              _buildSectionTitle('编剧'),
              const SizedBox(height: 8),
              _buildTagList(_writerControllers, '添加编剧'),
              
              const SizedBox(height: 24),
              
              // 主演
              _buildSectionTitle('主演'),
              const SizedBox(height: 8),
              _buildTagList(_actorControllers, '添加主演'),
              
              const SizedBox(height: 24),
              
              // 类型
              _buildSectionTitle('类型'),
              const SizedBox(height: 8),
              _buildTagList(_genreControllers, '添加类型'),
              
              const SizedBox(height: 24),
              
              // 剧情简介
              _buildSectionTitle('剧情简介'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _summaryController,
                label: '',
                hint: '请输入剧情简介...',
                maxLines: 5,
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建海报上传区域
  Widget _buildPosterSection() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 140,
          height: 200,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: _posterPath != null && _posterPath!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(_posterPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colorScheme),
                  ),
                )
              : _buildPlaceholder(colorScheme),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 40,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        const SizedBox(height: 8),
        Text(
          '上传海报',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
      ),
    );
  }

  /// 构建文本输入框
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        labelStyle: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  /// 构建日期选择器
  Widget _buildDatePicker() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: _selectReleaseDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _releaseDate != null
                    ? '${_releaseDate!.year}-${_releaseDate!.month.toString().padLeft(2, '0')}-${_releaseDate!.day.toString().padLeft(2, '0')}'
                    : '上映日期',
                style: TextStyle(
                  fontSize: 15,
                  color: _releaseDate != null
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ),
            if (_releaseDate != null)
              GestureDetector(
                onTap: () => setState(() => _releaseDate = null),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建状态选择器
  Widget _buildStatusSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    final statuses = [
      {'value': 'watching', 'label': '在看', 'icon': Icons.play_circle_outline},
      {'value': 'watched', 'label': '已看', 'icon': Icons.check_circle_outline},
      {'value': 'want_to_watch', 'label': '想看', 'icon': Icons.bookmark_border},
    ];

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: statuses.map((status) {
          final isSelected = _status == status['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _status = status['value'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      status['icon'] as IconData,
                      size: 18,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status['label'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建标签列表（导演、编剧、演员等）
  Widget _buildTagList(List<TextEditingController> controllers, String addHint) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      children: [
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: addHint,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline, 
                      color: colorScheme.error.withOpacity(0.6), 
                      size: 20
                    ),
                    onPressed: () {
                      setState(() {
                        controller.dispose();
                        controllers.removeAt(index);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          );
        }),
        
        // 添加按钮
        GestureDetector(
          onTap: () {
            setState(() {
              controllers.add(TextEditingController());
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  addHint,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                  ),
                ),
              ],
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
        // 复制图片到应用目录
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'movie_poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = path.join(appDir.path, 'posters', fileName);
        
        // 创建目录
        final posterDir = Directory(path.join(appDir.path, 'posters'));
        if (!await posterDir.exists()) {
          await posterDir.create(recursive: true);
        }
        
        // 复制文件
        final sourceFile = File(pickedFile.path);
        await sourceFile.copy(savedPath);
        
        setState(() {
          _posterPath = savedPath;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  /// 选择上映日期
  Future<void> _selectReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _releaseDate = picked;
      });
    }
  }

  /// 保存影视记录
  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rating = _ratingController.text.isNotEmpty 
          ? double.tryParse(_ratingController.text) 
          : null;

      // 收集列表数据
      final directors = _collectNonEmptyTexts(_directorControllers);
      final writers = _collectNonEmptyTexts(_writerControllers);
      final actors = _collectNonEmptyTexts(_actorControllers);
      final genres = _collectNonEmptyTexts(_genreControllers);
      final alternateTitles = _collectNonEmptyTexts(_alternateTitleControllers);

      final now = DateTime.now();

      if (widget.movie == null) {
        // 添加新模式
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
        // 编辑模式
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.movie == null ? '添加成功' : '更新成功'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// 收集非空文本
  List<String> _collectNonEmptyTexts(List<TextEditingController> controllers) {
    return controllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
}
