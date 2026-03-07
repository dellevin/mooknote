import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';

/// 添加/编辑影视记录页面（Typecho 风格）
class MovieFormPage extends StatefulWidget {
  final Movie? movie;

  const MovieFormPage({super.key, this.movie});

  @override
  State<MovieFormPage> createState() => _MovieFormPageState();
}

class _MovieFormPageState extends State<MovieFormPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _releaseDateController;
  late TextEditingController _directorsController;
  late TextEditingController _writersController;
  late TextEditingController _actorsController;
  late TextEditingController _genresController;
  late TextEditingController _alternateTitlesController;
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;
  
  String _status = 'want_to_watch';
  File? _posterImage;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.movie?.title ?? '');
    _releaseDateController = TextEditingController(
      text: widget.movie?.releaseDate != null 
          ? _formatDate(widget.movie!.releaseDate!) 
          : '',
    );
    _directorsController = TextEditingController(
      text: (widget.movie?.directors ?? []).join(', '),
    );
    _writersController = TextEditingController(
      text: (widget.movie?.writers ?? []).join(', '),
    );
    _actorsController = TextEditingController(
      text: (widget.movie?.actors ?? []).join(', '),
    );
    _genresController = TextEditingController(
      text: (widget.movie?.genres ?? []).join(', '),
    );
    _alternateTitlesController = TextEditingController(
      text: (widget.movie?.alternateTitles ?? []).join(', '),
    );
    _summaryController = TextEditingController(text: widget.movie?.summary ?? '');
    _ratingController = TextEditingController(
      text: widget.movie?.rating?.toString() ?? '',
    );
    _status = widget.movie?.status ?? 'want_to_watch';
    
    if (widget.movie?.posterPath != null) {
      _posterImage = File(widget.movie!.posterPath!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _releaseDateController.dispose();
    _directorsController.dispose();
    _writersController.dispose();
    _actorsController.dispose();
    _genresController.dispose();
    _alternateTitlesController.dispose();
    _summaryController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.movie != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑影视' : '添加影视'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveMovie,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 封面上传区域
            _buildCoverSection(),
            
            const SizedBox(height: 24),
            
            // 表单区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(),
                    const SizedBox(height: 32),
                    _buildCastSection(),
                    const SizedBox(height: 32),
                    _buildDetailSection(),
                    const SizedBox(height: 48),
                    _buildSaveButton(isEdit),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建封面上传区域
  Widget _buildCoverSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 300,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: _posterImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _posterImage!,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '点击上传海报',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '建议尺寸：2:3 比例',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// 构建基本信息区域
  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('基本信息'),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: '影视名称 *',
            hintText: '请输入影视名称',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.title),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入影视名称';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _releaseDateController,
                decoration: const InputDecoration(
                  labelText: '上映时间',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                readOnly: true,
                onTap: _selectReleaseDate,
              ),
            ),
            
            const SizedBox(width: 16),
            
            Expanded(
              child: TextFormField(
                controller: _ratingController,
                decoration: const InputDecoration(
                  labelText: '评分',
                  hintText: '1-10',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.star),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final rating = double.tryParse(value);
                    if (rating == null || rating < 1 || rating > 10) {
                      return '1-10';
                    }
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        DropdownButtonFormField<String>(
          value: _status,
          decoration: const InputDecoration(
            labelText: '状态',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.check_circle_outline),
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
      ],
    );
  }

  /// 构建演职人员区域
  Widget _buildCastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('演职人员'),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _directorsController,
          decoration: const InputDecoration(
            labelText: '导演',
            hintText: '多个用逗号分隔',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _writersController,
          decoration: const InputDecoration(
            labelText: '编剧',
            hintText: '多个用逗号分隔',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.edit_note),
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _actorsController,
          decoration: const InputDecoration(
            labelText: '主演',
            hintText: '多个用逗号分隔',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.people),
          ),
        ),
      ],
    );
  }

  /// 构建详细信息区域
  Widget _buildDetailSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('详细信息'),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _genresController,
          decoration: const InputDecoration(
            labelText: '类型',
            hintText: '多个用逗号分隔',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _alternateTitlesController,
          decoration: const InputDecoration(
            labelText: '别名',
            hintText: '多个用逗号分隔',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.alt_route),
          ),
        ),
        
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _summaryController,
          decoration: const InputDecoration(
            labelText: '剧情简介',
            hintText: '请输入剧情简介...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 6,
        ),
      ],
    );
  }

  /// 构建保存按钮
  Widget _buildSaveButton(bool isEdit) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveMovie,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(isEdit ? '保存修改' : '添加记录'),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  /// 选择图片
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _posterImage = File(image.path);
      });
    }
  }

  /// 选择日期
  Future<void> _selectReleaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _releaseDateController.text = _formatDate(picked);
      });
    }
  }

  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 保存影视记录
  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 处理列表字段
      final directors = _parseList(_directorsController.text);
      final writers = _parseList(_writersController.text);
      final actors = _parseList(_actorsController.text);
      final genres = _parseList(_genresController.text);
      final alternateTitles = _parseList(_alternateTitlesController.text);
      
      // 处理评分
      final rating = _ratingController.text.isNotEmpty 
          ? double.parse(_ratingController.text) 
          : null;
      
      // 处理日期
      final releaseDate = _releaseDateController.text.isNotEmpty
          ? DateTime.tryParse(_releaseDateController.text)
          : null;

      // 处理图片
      String? posterPath;
      if (_posterImage != null) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = '${const Uuid().v4()}.jpg';
        final savedImage = await _posterImage!.copy('${dir.path}/posters/$fileName');
        posterPath = savedImage.path;
      }

      if (widget.movie == null) {
        // 添加新模式
        final now = DateTime.now();
        final newMovie = Movie(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          posterPath: posterPath,
          releaseDate: releaseDate,
          directors: directors,
          writers: writers,
          actors: actors,
          genres: genres,
          alternateTitles: alternateTitles,
          summary: _summaryController.text.trim(),
          rating: rating,
          status: _status,
          createdAt: now,
          updatedAt: now,
        );

        await context.read<AppProvider>().addMovie(newMovie);
      } else {
        // 编辑现有模式
        final updatedMovie = Movie(
          id: widget.movie!.id,
          title: _titleController.text.trim(),
          posterPath: posterPath ?? widget.movie!.posterPath,
          releaseDate: releaseDate,
          directors: directors,
          writers: writers,
          actors: actors,
          genres: genres,
          alternateTitles: alternateTitles,
          summary: _summaryController.text.trim(),
          rating: rating,
          status: _status,
          createdAt: widget.movie!.createdAt,
          updatedAt: DateTime.now(),
        );

        await context.read<AppProvider>().updateMovie(updatedMovie);
      }

      if (!mounted) return;

      ToastUtil.show(context, widget.movie == null ? '添加成功' : '更新成功');

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败：$e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 解析列表
  List<String> _parseList(String text) {
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
