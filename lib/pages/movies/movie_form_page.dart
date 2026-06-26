import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/genre_selector_page.dart';
import '../../widgets/text_input_panel.dart';

/// 从多值字段列表中提取去重排序的唯一值（供 compute 使用）
List<String> _collectUnique(List<List<String>> lists) {
  final s = <String>{};
  for (final l in lists) { s.addAll(l); }
  return s.toList()..sort();
}

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
  bool _isDownloading = false;

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
    super.dispose();
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
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );

      if (response.statusCode != 200) throw Exception('下载失败: HTTP ${response.statusCode}');

      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) throw Exception('链接返回的不是图片');
      if (response.bodyBytes.length > 10 * 1024 * 1024) throw Exception('图片太大');

      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final movieId = widget.movie?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(movieId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);

      setState(() => _posterPath = targetPath);
    } catch (e) {
      debugPrint('封面下载失败: $e');
      if (mounted) ToastUtil.show(context, '下载失败: $e');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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

            const SizedBox(height: 20),

            // 状态 + 评分（合并为一行）
            _buildStatusRatingRow(),

            const SizedBox(height: 24),

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
                    onTap: () async {
                      final result = await TextInputPanel.show(
                        context: context,
                        title: '影视名称',
                        initialValue: _titleController.text,
                        hint: '请输入影视名称',
                      );
                      if (result != null) setState(() => _titleController.text = result);
                    },
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
                    onTap: () async {
                      final result = await GenreSelectorPage.show(
                        context: context,
                        title: '添加别名',
                        existingTags: [],
                        initialSelected: _alternateTitles,
                        hint: '输入别名',
                      );
                      if (result != null) setState(() => _alternateTitles = result);
                    },
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
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final data = provider.movies.map((m) => m.directors).toList();
                      final result = await GenreSelectorPage.show(
                        context: context,
                        title: '选择导演',
                        existingTagsFuture: compute(_collectUnique, data),
                        initialSelected: _directors,
                        hint: '如：张艺谋、李安',
                      );
                      if (result != null) setState(() => _directors = result);
                    },
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
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final data = provider.movies.map((m) => m.writers).toList();
                      final result = await GenreSelectorPage.show(
                        context: context,
                        title: '选择编剧',
                        existingTagsFuture: compute(_collectUnique, data),
                        initialSelected: _writers,
                        hint: '如：刘慈欣、王家卫',
                      );
                      if (result != null) setState(() => _writers = result);
                    },
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
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final data = provider.movies.map((m) => m.actors).toList();
                      final result = await GenreSelectorPage.show(
                        context: context,
                        title: '选择主演',
                        existingTagsFuture: compute(_collectUnique, data),
                        initialSelected: _actors,
                        hint: '如：梁朝伟、周星驰',
                      );
                      if (result != null) setState(() => _actors = result);
                    },
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
                      final tags = await provider.getTags('movie_genre', excludeHidden: true);
                      final existingNames = tags.map((t) => t['name'] as String).toList();
                      if (!mounted) return;
                      final result = await GenreSelectorPage.show(
                        context: context,
                        title: '选择类型',
                        existingTags: existingNames,
                        initialSelected: _genres,
                        hint: '如：剧情、科幻、悬疑',
                      );
                      if (result != null) setState(() => _genres = result);
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
                    trailing: _watchDate != null
                        ? GestureDetector(
                            onTap: () => setState(() => _watchDate = null),
                            child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                          )
                        : null,
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
                    height: 160,
                    scrollable: true,
                    onTap: () => _editSummary(),
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
    Widget? trailing,
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
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
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

  /// 全屏编辑剧情简介
  Future<void> _editSummary() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _SummaryEditorPage(initialText: _summaryController.text),
      ),
    );
    if (result != null) {
      setState(() => _summaryController.text = result);
    }
  }

  /// 构建状态 + 评分合并行
  Widget _buildStatusRatingRow() {
    final colors = Theme.of(context).colorScheme;
    final currentRating = double.tryParse(_ratingController.text) ?? 0;
    final starRating = currentRating / 2;
    final hasRating = _ratingController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          // 状态
          Row(
            children: [
              Text('状态', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
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
          ),
          const SizedBox(height: 12),
          // 评分
          Row(
            children: [
              Text('评分', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
              const SizedBox(width: 12),
              // 星星
              ...List.generate(5, (index) {
                final starValue = index + 1;
                final isFilled = starValue <= starRating;
                final isHalf = starValue == starRating.ceil() && starRating % 1 != 0;
                return GestureDetector(
                  onTap: () => setState(() => _ratingController.text = (starValue * 2).toString()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      isHalf ? Icons.star_half : (isFilled ? Icons.star : Icons.star_border),
                      size: 22,
                      color: (isFilled || isHalf) ? const Color(0xFFFFB800) : colors.outline,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // 输入框
              Container(
                width: 48, height: 28,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: TextFormField(
                  controller: _ratingController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  inputFormatters: [_RatingInputFormatter()],
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                  decoration: InputDecoration(
                    hintText: '0-10',
                    hintStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (hasRating) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _ratingController.clear()),
                  child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                ),
              ],
            ],
          ),
        ],
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasPoster)
                  FadeInLocalImage(path: _posterPath, fit: BoxFit.cover)
                else
                  _buildCoverPlaceholder(),
                if (_isDownloading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
              ],
            ),
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
      builder: (ctx) {
        final colors = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('添加网络图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请输入图片链接地址', style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.primary, width: 1)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('取消', style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    final url = urlController.text.trim();
    urlController.dispose();

    if (confirmed != true || url.isEmpty) return;

    await _downloadCoverFromUrl(url);
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

/// 剧情简介全屏编辑页
class _SummaryEditorPage extends StatefulWidget {
  final String initialText;
  const _SummaryEditorPage({required this.initialText});

  @override
  State<_SummaryEditorPage> createState() => _SummaryEditorPageState();
}

class _SummaryEditorPageState extends State<_SummaryEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('剧情简介'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: Text('完成', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary,
            )),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 15, color: colors.onSurface, height: 1.6),
        decoration: InputDecoration(
          hintText: '写下剧情简介...',
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/// 评分输入格式化器：只允许 0-10，最多1位小数
class _RatingInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (!RegExp(r'^\d{0,2}\.?\d{0,1}$').hasMatch(text)) return oldValue;
    final n = double.tryParse(text);
    if (n != null && n > 10) return oldValue;
    return newValue;
  }
}
