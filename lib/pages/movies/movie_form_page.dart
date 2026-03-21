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

/// 添加/编辑影视页面 - 紧凑双行布局设计
class MovieFormPage extends StatefulWidget {
  final Movie? movie;
  final String? initialStatus; // 添加时的默认状态
  
  const MovieFormPage({super.key, this.movie, this.initialStatus});
  
  @override
  State<MovieFormPage> createState() => _MovieFormPageState();
}

class _MovieFormPageState extends State<MovieFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  // 输入框控制器
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;
  
  // 多值字段的临时输入控制器
  final Map<String, TextEditingController> _tagControllers = {};
  
  // 数据
  List<String> _directors = [];
  List<String> _writers = [];
  List<String> _actors = [];
  List<String> _genres = [];
  List<String> _alternateTitles = [];
  String? _posterPath;
  String _status = 'want_to_watch';
  DateTime? _releaseDate;
  DateTime? _watchDate;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }
  
  void _initializeData() {
    // 如果有传入movie，尝试从Provider获取最新数据
    Movie? movie = widget.movie;
    if (movie != null) {
      final appProvider = context.read<AppProvider>();
      final latestMovie = appProvider.movies
          .where((m) => m.id == movie!.id)
          .firstOrNull;
      if (latestMovie != null) {
        movie = latestMovie;
      }
    }
    
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
      _watchDate = movie.watchDate;
    } else if (widget.initialStatus != null) {
      // 添加模式：使用传入的默认状态
      _status = widget.initialStatus!;
    }
  }
  
  @override
  void dispose() {
    // 先 dispose controllers
    _titleController.dispose();
    _summaryController.dispose();
    _ratingController.dispose();
    _tagControllers.values.forEach((c) => c.dispose());
    // 最后调用 super.dispose
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

  /// 显示快捷添加对话框
  void _showQuickAddDialog() {
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '快捷添加',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请输入分享的豆瓣影视链接：',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'https://m.douban.com/subject/...',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (url) async {
                if (url.trim().isNotEmpty) {
                  // 先移除焦点
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop(url);
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 先移除焦点，等待一帧确保焦点已释放
              FocusManager.instance.primaryFocus?.unfocus();
              await Future.delayed(const Duration(milliseconds: 50));
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(null);
              }
            },
            child: const Text(
              '取消',
              style: TextStyle(color: Color(0xFF999999)),
            ),
          ),
          TextButton(
            onPressed: () async {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                // 先移除焦点
                FocusManager.instance.primaryFocus?.unfocus();
                await Future.delayed(const Duration(milliseconds: 50));
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(url);
                }
              }
            },
            child: const Text(
              '确定',
              style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ).then((result) {
      // 延迟 dispose，确保 widget tree 已释放 controller
      WidgetsBinding.instance.addPostFrameCallback((_) {
        textController.dispose();
      });
      // 处理结果
      if (result != null && result is String && result.isNotEmpty) {
        _openDoubanWebView(result);
      }
    });
  }

  /// 打开豆瓣WebView页面
  Future<void> _openDoubanWebView(String url) async {
    // 导航到WebView页面并等待返回结果
    final result = await Navigator.pushNamed(
      context,
      '/douban-webview',
      arguments: url,
    );
    
    // 处理返回的影视信息
    if (result != null && result is Map<String, dynamic>) {
      _fillMovieInfo(result);
    }
  }
  
  /// 填充影视信息到表单
  void _fillMovieInfo(Map<String, dynamic> info) {
    setState(() {
      // 填充标题
      if (info['title'] != null && info['title'].toString().isNotEmpty) {
        _titleController.text = info['title'].toString();
      }
      
      // 填充评分
      if (info['rating'] != null && info['rating'].toString().isNotEmpty) {
        _ratingController.text = info['rating'].toString();
      }
      
      // 填充导演
      if (info['director'] != null && info['director'].toString().isNotEmpty) {
        _directors = [info['director'].toString()];
      }
      
      // 填充编剧
      if (info['writers'] != null && info['writers'] is List) {
        _writers = (info['writers'] as List).map((w) => w.toString()).toList();
      }
      
      // 填充演员
      if (info['actors'] != null && info['actors'] is List) {
        _actors = (info['actors'] as List).map((a) => a.toString()).toList();
      }
      
      // 填充类型
      if (info['genres'] != null && info['genres'].toString().isNotEmpty) {
        _genres = info['genres'].toString().split(',').map((g) => g.trim()).toList();
      }
      
      // 填充别名
      if (info['alternateTitles'] != null && info['alternateTitles'] is List) {
        _alternateTitles = (info['alternateTitles'] as List).map((t) => t.toString()).toList();
      }
      
      // 填充简介
      if (info['summary'] != null && info['summary'].toString().isNotEmpty) {
        _summaryController.text = info['summary'].toString();
      }
      
      // 填充上映日期
      if (info['releaseDate'] != null && info['releaseDate'].toString().isNotEmpty) {
        final dateStr = info['releaseDate'].toString();
        // 尝试解析日期
        try {
          // 处理格式如 "2023-01-01(中国大陆)"
          final cleanDate = dateStr.split('(')[0].trim();
          _releaseDate = DateTime.parse(cleanDate);
        } catch (e) {
          // 解析失败则忽略
        }
      }
      
      // 下载封面图
      if (info['coverUrl'] != null && info['coverUrl'].toString().isNotEmpty) {
        _downloadCoverFromUrl(info['coverUrl'].toString());
      }
      
    });
    
    // 显示成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已自动填充影视信息')),
      );
    }
  }
  
  /// 从URL下载封面图
  Future<void> _downloadCoverFromUrl(String url) async {
    try {
      // 下载网络图片，添加请求头模拟浏览器
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': 'https://movie.douban.com/',
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
      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 如果是编辑模式，使用现有影视ID；如果是新建模式，使用临时ID
      final movieId = widget.movie?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // 保存到新的路径结构
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(
        movieId, 
        fileName
      );
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));

      // 写入文件
      await File(targetPath).writeAsBytes(response.bodyBytes);

      setState(() => _posterPath = targetPath);
    } catch (e) {
      // 封面下载失败不影响其他信息填充
      debugPrint('封面下载失败: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.movie != null;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? '编辑影视' : '添加影视'),
        actions: [
          // 快捷添加按钮（仅添加模式显示）
          if (!isEdit)
            _buildActionButton(
              icon: Icons.auto_fix_high_outlined,
              onPressed: _showQuickAddDialog,
              tooltip: '快捷添加',
            ),
          // 保存按钮
          _buildActionButton(
            icon: Icons.save_outlined,
            onPressed: _saveMovie,
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
            
            // 影视名称
            _buildHorizontalFormItem(
              label: '名称',
              required: true,
              child: TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: '请输入影视名称',
                  hintStyle: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入影视名称';
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

            // 导演
            _buildHorizontalMultiValueItem(
              label: '导演',
              values: _directors,
              hint: '输入导演姓名',
              controllerKey: 'directors',
              onAdd: (v) => setState(() => _directors.add(v)),
              onRemove: (i) => setState(() => _directors.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // 编剧
            _buildHorizontalMultiValueItem(
              label: '编剧',
              values: _writers,
              hint: '输入编剧姓名',
              controllerKey: 'writers',
              onAdd: (v) => setState(() => _writers.add(v)),
              onRemove: (i) => setState(() => _writers.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // 主演
            _buildHorizontalMultiValueItem(
              label: '主演',
              values: _actors,
              hint: '输入主演姓名',
              controllerKey: 'actors',
              onAdd: (v) => setState(() => _actors.add(v)),
              onRemove: (i) => setState(() => _actors.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // 类型（自定义填写，带示例）
            _buildHorizontalMultiValueItem(
              label: '类型',
              values: _genres,
              hint: '如：剧情、科幻、悬疑',
              controllerKey: 'genres',
              onAdd: (v) => setState(() => _genres.add(v)),
              onRemove: (i) => setState(() => _genres.removeAt(i)),
            ),

            const SizedBox(height: 16),

            // 上映日期
            _buildVerticalDateItem(
              label: '上映日期',
              date: _releaseDate,
              onTap: _selectReleaseDate,
              onClear: () => setState(() => _releaseDate = null),
            ),

            const SizedBox(height: 16),

            // 观看日期
            _buildVerticalDateItem(
              label: '观看日期',
              date: _watchDate,
              onTap: _selectWatchDate,
              onClear: () => setState(() => _watchDate = null),
            ),

            const SizedBox(height: 16),
            
            // 剧情简介
            _buildFormItem(
              label: '剧情简介',
              child: TextFormField(
                controller: _summaryController,
                maxLines: 4,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A), height: 1.5),
                decoration: const InputDecoration(
                  hintText: '写下剧情简介...',
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

  /// 构建表单条目（标签 + 内容）- 剧情简介使用
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
              _buildStatusOption('想看', 'want_to_watch'),
              _buildStatusOption('在看', 'watching'),
              _buildStatusOption('已看', 'watched'),
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
    final hasPoster = _posterPath != null && _posterPath!.isNotEmpty;
    
    return Column(
      children: [
        GestureDetector(
          onTap: _showCoverOptions,
          child: Container(
            width: 140,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
            ),
            child: hasPoster
                ? Image.file(
                    File(_posterPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
                  )
                : _buildCoverPlaceholder(),
          ),
        ),
        // 清空海报按钮（仅当有海报时显示）
        if (hasPoster)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: () => setState(() => _posterPath = null),
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
                      '清空海报',
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
  
  /// 显示封面选择选项
  void _showCoverOptions() {
    showModalBottomSheet(
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
                    '添加海报',
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
                  Navigator.pop(context);
                  _pickCover();
                },
              ),
              // 网络链接选项
              _buildCoverOption(
                icon: Icons.link_outlined,
                title: '网络链接',
                onTap: () {
                  Navigator.pop(context);
                  _pickCoverFromUrl();
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          '点击添加海报',
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
        // 生成文件名
        final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // 如果是编辑模式，使用现有影视ID；如果是新建模式，使用临时ID（保存时会替换）
        final movieId = widget.movie?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        // 保存到新的路径结构: images/movies/{movieId}/{fileName}
        final targetPath = await ImagePathHelper.instance.getMoviePosterPath(
          movieId, 
          fileName
        );
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
        
        await File(pickedFile.path).copy(targetPath);
        
        setState(() => _posterPath = targetPath);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '选择海报失败: $e');
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
                hintText: 'https://movie.douban.com/image.jpg',
                hintStyle: TextStyle(color: Color(0xFFCCCCCC)),
                border: UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE5E5E5)),
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
      // 下载网络图片，添加请求头模拟浏览器
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );
      
      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      // 检查内容类型
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) {
        throw Exception('链接返回的不是图片，可能是网页或需要登录');
      }

      // 检查文件大小（最大 10MB）
      if (response.bodyBytes.length > 10 * 1024 * 1024) {
        throw Exception('图片太大，请使用小于 10MB 的图片');
      }

      // 生成文件名
      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // 如果是编辑模式，使用现有影视ID；如果是新建模式，使用临时ID
      final movieId = widget.movie?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // 保存到新的路径结构
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(
        movieId, 
        fileName
      );
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));

      // 写入文件
      await File(targetPath).writeAsBytes(response.bodyBytes);

      setState(() => _posterPath = targetPath);
      
      if (mounted) {
        ToastUtil.show(context, '添加成功');
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '添加失败: $e');
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

  /// 选择观看日期
  Future<void> _selectWatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _watchDate = picked);
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
      // 生成新的影视ID
      final newMovieId = now.millisecondsSinceEpoch.toString();
      
      // 如果有海报，需要移动到正确的ID目录
      String? finalPosterPath;
      if (_posterPath != null && _posterPath!.isNotEmpty) {
        finalPosterPath = await _movePosterToNewId(_posterPath!, newMovieId);
      }
      
      final newMovie = Movie(
        id: newMovieId,
        title: _titleController.text.trim(),
        posterPath: finalPosterPath,
        releaseDate: _releaseDate,
        directors: _directors,
        writers: _writers,
        actors: _actors,
        genres: _genres,
        alternateTitles: _alternateTitles,
        summary: _summaryController.text.trim(),
        rating: rating,
        status: _status,
        watchDate: _watchDate,
        createdAt: now,
        updatedAt: now,
      );
      
      await context.read<AppProvider>().addMovie(newMovie);
    } else {
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
        watchDate: _watchDate,
        updatedAt: now,
      );
      
      await context.read<AppProvider>().updateMovie(updatedMovie);
    }
    
    if (!mounted) return;
    
    ToastUtil.show(context, widget.movie == null ? '添加成功' : '更新成功');
    
    Navigator.pop(context);
  }
  
  /// 将海报从临时ID目录移动到新的影视ID目录
  Future<String?> _movePosterToNewId(String currentPath, String newMovieId) async {
    // 检查是否已经在正确的目录中（兼容 Windows 路径分隔符）
    final normalizedPath = currentPath.replaceAll('\\', '/');
    if (normalizedPath.contains('/movies/$newMovieId/')) {
      return currentPath;
    }
    
    // 提取文件名
    final fileName = p.basename(currentPath);
    
    // 获取新路径
    final newPath = await ImagePathHelper.instance.getMoviePosterPath(
      newMovieId, 
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
