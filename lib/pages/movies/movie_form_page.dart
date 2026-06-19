import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
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
    Color? color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final iconColor = color ?? colors.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
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
              color: iconColor,
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
      builder: (dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            '快捷添加',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入分享的豆瓣影视链接：',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'https://m.douban.com/subject/...',
                  hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
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
              child: Text(
                '取消',
                style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4)),
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
              child: Text(
                '确定',
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
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
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.movie != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmLeave();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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

            // 信息卡片网格
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // 第一行：名称 + 别名
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '名称',
                    value: _titleController.text,
                    required: true,
                    icon: Icons.movie_outlined,
                    onTap: () => _showTextInputDialog(
                      title: '影视名称',
                      initialValue: _titleController.text,
                      hint: '请输入影视名称',
                      onConfirm: (value) => setState(() => _titleController.text = value),
                    ),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '别名',
                    value: _alternateTitles.isEmpty
                        ? ''
                        : '${_alternateTitles.length}个：${_alternateTitles.join('、')}',
                    icon: Icons.alternate_email_outlined,
                    scrollable: true,
                    onTap: () => _showMultiValueDialog(
                      title: '添加别名',
                      initialValues: _alternateTitles,
                      hint: '输入别名',
                      onConfirm: (values) => setState(() => _alternateTitles = values),
                    ),
                  ),
                ),

                // 第二行：导演 + 编剧
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '导演',
                    value: _directors.isEmpty
                        ? ''
                        : '${_directors.length}人：${_directors.join('、')}',
                    icon: Icons.videocam_outlined,
                    onTap: () => _showMultiValueDialog(
                      title: '添加导演',
                      initialValues: _directors,
                      hint: '输入导演姓名',
                      onConfirm: (values) => setState(() => _directors = values),
                    ),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '编剧',
                    value: _writers.isEmpty
                        ? ''
                        : '${_writers.length}人：${_writers.join('、')}',
                    icon: Icons.edit_note_outlined,
                    onTap: () => _showMultiValueDialog(
                      title: '添加编剧',
                      initialValues: _writers,
                      hint: '输入编剧姓名',
                      onConfirm: (values) => setState(() => _writers = values),
                    ),
                  ),
                ),

                // 第三行：主演 + 类型
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '主演',
                    value: _actors.isEmpty
                        ? ''
                        : '${_actors.length}人：${_actors.join('、')}',
                    icon: Icons.people_outline,
                    onTap: () => _showMultiValueDialog(
                      title: '添加主演',
                      initialValues: _actors,
                      hint: '输入主演姓名',
                      onConfirm: (values) => setState(() => _actors = values),
                    ),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '类型',
                    value: _genres.isEmpty
                        ? ''
                        : '${_genres.length}个：${_genres.join('、')}',
                    icon: Icons.category_outlined,
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final tags = await provider.getTags('movie_genre');
                      final existingNames = tags.map((t) => t['name'] as String).toList();
                      if (mounted) {
                        _showMultiValueDialog(
                          title: '添加类型',
                          initialValues: _genres,
                          hint: '如：剧情、科幻、悬疑',
                          existingTags: existingNames,
                          onConfirm: (values) => setState(() => _genres = values),
                        );
                      }
                    },
                  ),
                ),

                // 第四行：上映日期 + 观看日期
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '上映日期',
                    value: _releaseDate != null
                        ? '${_releaseDate!.year}.${_releaseDate!.month.toString().padLeft(2, '0')}.${_releaseDate!.day.toString().padLeft(2, '0')}'
                        : '',
                    icon: Icons.theaters_outlined,
                    onTap: () => _selectReleaseDate(),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  height: 90,
                  child: _buildInfoCard(
                    label: '观看日期',
                    value: _watchDate != null
                        ? '${_watchDate!.year}.${_watchDate!.month.toString().padLeft(2, '0')}.${_watchDate!.day.toString().padLeft(2, '0')}'
                        : '',
                    icon: Icons.visibility_outlined,
                    onTap: () => _selectWatchDate(),
                  ),
                ),

                // 第五行：剧情简介（独占一行）
                SizedBox(
                  width: double.infinity,
                  child: _buildInfoCard(
                    label: '剧情简介',
                    value: _summaryController.text,
                    icon: Icons.description_outlined,
                    height: 120,
                    scrollable: true,
                    onTap: () => _showTextInputDialog(
                      title: '剧情简介',
                      initialValue: _summaryController.text,
                      hint: '写下剧情简介...',
                      maxLines: 8,
                      onConfirm: (value) => setState(() => _summaryController.text = value),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    ),
    );
  }
  Widget _buildInfoCard({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool required = false,
    IconData? icon,
    double? height,
    bool scrollable = false,
    bool scrollHorizontal = false,
  }) {
    final hasValue = value.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    // 构建值显示部分
    Widget buildContent() {
      if (scrollable && height != null) {
        // 可滚动模式（仅剧情简介使用）
        return Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              hasValue ? value : '点击填写',
              style: TextStyle(
                fontSize: 15,
                color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      } else if (scrollHorizontal) {
        // 水平可滚动模式（别名等长文本使用）
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Text(
            hasValue ? value : '点击填写',
            style: TextStyle(
              fontSize: 15,
              color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        );
      } else {
        // 普通模式：只显示一行
        return Text(
          hasValue ? value : '点击填写',
          style: TextStyle(
            fontSize: 15,
            color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25),
            fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
          boxShadow: [
            BoxShadow(
              color: colors.onSurface.withValues(alpha: 0.018),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // 标签行
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                ],
                Text(
                  required ? '$label *' : label,
                  style: TextStyle(
                    fontSize: 12,
                    color: required ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: required ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 值显示
            buildContent(),
          ],
        ),
      ),
    );
  }

  /// 显示文本输入对话框
  Future<void> _showTextInputDialog({
    required String title,
    required String initialValue,
    required Function(String) onConfirm,
    int maxLines = 1,
    String hint = '',
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _TextInputDialog(
        title: title,
        initialValue: initialValue,
        hint: hint,
        maxLines: maxLines,
      ),
    );

    if (result != null) {
      onConfirm(result);
    }
  }

  /// 显示多值输入对话框
  Future<void> _showMultiValueDialog({
    required String title,
    required List<String> initialValues,
    required Function(List<String>) onConfirm,
    String hint = '',
    List<String> existingTags = const [],
  }) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => _MultiValueDialog(
        title: title,
        initialValues: initialValues,
        hint: hint,
        existingTags: existingTags,
      ),
    );

    if (result != null) {
      onConfirm(result);
    }
  }

  /// 构建纵向日期条目（标签在上，日期在下）
  Widget _buildVerticalDateItem({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
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
                        ? colors.onSurface
                        : colors.onSurface.withValues(alpha: 0.25),
                  ),
                ),
              ),
              if (date != null)
                GestureDetector(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建卡片式表单条目（带边框背景）
  Widget _buildCardFormItem({
    required String label,
    required Widget child,
    bool required = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: TextStyle(
            fontSize: 13,
            color: required ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
            fontWeight: required ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ],
    );
  }

  /// 构建卡片式日期选择项
  Widget _buildCardDateItem({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: date != null ? colors.onSurface : colors.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
                        : '选择日期',
                    style: TextStyle(
                      fontSize: 15,
                      color: date != null
                          ? colors.onSurface
                          : colors.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                if (date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 构建表单条目（标签 + 内容）- 剧情简介使用
  Widget _buildFormItem({required String label, required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
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
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          child: Text(
            required ? '$label *' : label,
            style: TextStyle(
              fontSize: 13,
              color: required ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
              fontWeight: required ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }

  /// 构建纵向多值条目（标签在上，输入框在下，带添加按钮）
  Widget _buildHorizontalMultiValueItem({
    required String label,
    required List<String> values,
    required String hint,
    required String controllerKey,
    required Function(String) onAdd,
    required Function(int) onRemove,
  }) {
    final controller = _getTagController(controllerKey);
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签行：标签 + 添加按钮
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
            ),
            const Spacer(),
            // 添加按钮
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasText ? colors.primary : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: hasText ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasText ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.25),
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
        // 已选标签
        if (values.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.asMap().entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value,
                      style: TextStyle(fontSize: 14, color: colors.onSurface),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        if (values.isNotEmpty) const SizedBox(height: 8),
        // 输入框（带边框背景）
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 14, color: colors.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：标签 + 添加按钮
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
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
                        color: hasText ? colors.primary : colors.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add,
                          size: 14,
                          color: hasText ? colors.primary : colors.onSurface.withValues(alpha: 0.25),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasText ? colors.primary : colors.onSurface.withValues(alpha: 0.25),
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
                  color: colors.surfaceContainerHighest,
                  border: Border.all(color: colors.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.value,
                      style: TextStyle(fontSize: 14, color: colors.onSurface),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
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
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: values.isEmpty ? hint : '',
                  hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)),
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

  /// 构建状态选择器（简洁风格）
  Widget _buildStatusSelector() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          '状态',
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: colors.outlineVariant,
            borderRadius: BorderRadius.circular(6),
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

  /// 构建星星评分（支持手动输入）
  Widget _buildStarRating() {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          '评分',
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
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
    final colors = Theme.of(context).colorScheme;

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
                    : colors.outline,
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 构建评分输入框（支持0-10，保留1位小数）
  Widget _buildRatingInputField() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 32,
      decoration: BoxDecoration(
        color: colors.outlineVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextFormField(
        controller: _ratingController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
        decoration: InputDecoration(
          hintText: '-',
          hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            final rating = double.tryParse(value);
            if (rating != null) {
              if (rating > 10) {
                _ratingController.text = '10.0';
              } else if (rating < 0) {
                _ratingController.text = '0.0';
              }
            }
          }
          setState(() {});
        },
      ),
    );
  }

  /// 构建状态选项
  Widget _buildStatusOption(String label, String value) {
    final isSelected = _status == value;
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _status = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.onSurface.withValues(alpha: 0.03),
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
            color: isSelected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  /// 构建封面选择器
  Widget _buildCoverPicker() {
    final hasPoster = _posterPath != null && _posterPath!.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _showCoverOptions,
          child: Container(
            width: 120,
            height: 170,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPoster
                ? FadeInLocalImage(
                    path: _posterPath,
                    fit: BoxFit.cover,
                  )
                : _buildCoverPlaceholder(),
          ),
        ),
        // 清空海报按钮（仅当有海报时显示）
        if (hasPoster)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GestureDetector(
              onTap: () => setState(() => _posterPath = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '移除海报',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.6),
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
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
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
                    color: colors.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '添加海报',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
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
        );
      },
    );
  }

  /// 构建封面选项
  Widget _buildCoverOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(context).colorScheme;
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
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: colors.onSurface,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              color: colors.onSurface.withValues(alpha: 0.25),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.image_outlined,
          size: 32,
          color: colors.onSurface.withValues(alpha: 0.25),
        ),
        const SizedBox(height: 8),
        Text(
          '海报',
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.35),
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
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text('添加网络图片'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入图片链接地址',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'https://movie.douban.com/image.jpg',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                  border: const UnderlineInputBorder(),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.outline),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
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
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('确定', style: TextStyle(color: colors.onSurface)),
            ),
          ],
        );
      },
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
      builder: (context, child) => child!,
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
      builder: (context, child) => child!,
    );

    if (picked != null) {
      setState(() => _watchDate = picked);
    }
  }

  /// 收集所有多值字段输入框中的未提交内容
  void _collectUnsubmittedValues() {
    // 别名
    final alternateTitlesController = _tagControllers['alternateTitles'];
    if (alternateTitlesController != null) {
      final value = alternateTitlesController.text.trim();
      if (value.isNotEmpty && !_alternateTitles.contains(value)) {
        _alternateTitles.add(value);
        alternateTitlesController.clear();
      }
    }

    // 导演
    final directorsController = _tagControllers['directors'];
    if (directorsController != null) {
      final value = directorsController.text.trim();
      if (value.isNotEmpty && !_directors.contains(value)) {
        _directors.add(value);
        directorsController.clear();
      }
    }

    // 编剧
    final writersController = _tagControllers['writers'];
    if (writersController != null) {
      final value = writersController.text.trim();
      if (value.isNotEmpty && !_writers.contains(value)) {
        _writers.add(value);
        writersController.clear();
      }
    }

    // 主演
    final actorsController = _tagControllers['actors'];
    if (actorsController != null) {
      final value = actorsController.text.trim();
      if (value.isNotEmpty && !_actors.contains(value)) {
        _actors.add(value);
        actorsController.clear();
      }
    }

    // 类型
    final genresController = _tagControllers['genres'];
    if (genresController != null) {
      final value = genresController.text.trim();
      if (value.isNotEmpty && !_genres.contains(value)) {
        _genres.add(value);
        genresController.clear();
      }
    }
  }

  /// 检查表单是否有内容
  bool _hasContent() {
    if (widget.movie != null) return true; // 编辑模式始终需要确认
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_summaryController.text.trim().isNotEmpty) return true;
    if (_ratingController.text.trim().isNotEmpty) return true;
    if (_posterPath != null) return true;
    if (_directors.isNotEmpty || _writers.isNotEmpty || _actors.isNotEmpty) return true;
    if (_genres.isNotEmpty || _alternateTitles.isNotEmpty) return true;
    if (_releaseDate != null || _watchDate != null) return true;
    return false;
  }

  /// 离开确认
  Future<bool> _confirmLeave() async {
    if (!_hasContent()) return true;
    final colors = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('未保存', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('当前内容未保存，确定要离开吗？',
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('离开'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return result ?? false;
  }

  /// 保存影视
  Future<void> _saveMovie() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
    // 收集所有多值字段输入框中的未提交内容
    _collectUnsubmittedValues();

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
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: $e');
    }
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

/// 多值输入对话框组件
class _MultiValueDialog extends StatefulWidget {
  final String title;
  final List<String> initialValues;
  final String hint;
  final List<String> existingTags;

  const _MultiValueDialog({
    required this.title,
    required this.initialValues,
    required this.hint,
    this.existingTags = const [],
  });

  @override
  State<_MultiValueDialog> createState() => _MultiValueDialogState();
}

class _MultiValueDialogState extends State<_MultiValueDialog> {
  late List<String> values;
  final controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    values = List<String>.from(widget.initialValues);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _addValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty && !values.contains(trimmed)) {
      setState(() {
        values.add(trimmed);
      });
      controller.clear();
    }
  }

  void _removeValue(int index) {
    setState(() {
      values.removeAt(index);
    });
  }

  void _toggleExistingTag(String tag) {
    setState(() {
      if (values.contains(tag)) {
        values.remove(tag);
      } else {
        values.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 未选中的已有标签
    final availableTags = widget.existingTags
        .where((t) => !values.contains(t))
        .toList();

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 可滚动的标签区域
              if (values.isNotEmpty || availableTags.isNotEmpty)
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 已选择的标签
                        if (values.isNotEmpty) ...[
                          Text(
                            '已选择',
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: values.map((v) {
                              return Container(
                                padding: const EdgeInsets.only(left: 12, right: 6, top: 7, bottom: 7),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      v,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: colors.onPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => values.remove(v));
                                      },
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: colors.onPrimary.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.close, size: 12, color: colors.onPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          if (availableTags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Divider(height: 0.5, color: colors.outlineVariant),
                            const SizedBox(height: 16),
                          ],
                        ],
                        // 已有类型
                        if (availableTags.isNotEmpty) ...[
                          Text(
                            '已有类型',
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availableTags.map((tag) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() => values.add(tag));
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.outline,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                                      const SizedBox(width: 4),
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colors.onSurface.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              // 固定底部的输入框
              if (values.isNotEmpty || availableTags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 0.5, color: colors.outlineVariant),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(fontSize: 15, color: colors.onSurface),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: colors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: _addValue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _addValue(controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add, size: 20, color: colors.onPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4))),
        ),
        ElevatedButton(
          onPressed: () {
            _addValue(controller.text);
            Navigator.pop(context, values);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 文本输入对话框组件
class _TextInputDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final String hint;
  final int maxLines;

  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.hint,
    required this.maxLines,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: controller,
        maxLines: widget.maxLines,
        autofocus: true,
        style: TextStyle(fontSize: 15, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.35)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.4))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
