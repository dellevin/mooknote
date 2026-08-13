import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/toast_util.dart';

/// 豆瓣官方 logo（绿色）
const _doubanSvg = '''
<svg t="1786602404744" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="6079" width="32" height="32"><path d="M411.52 574.72a969.92 969.92 0 0 1 59.84 117.28h83.36a668.16 668.16 0 0 0 60.8-117.28z" fill="#61CD72" p-id="6080"></path><path d="M512 73.28A438.72 438.72 0 1 0 950.72 512 438.72 438.72 0 0 0 512 73.28z m-215.36 228.8h434.88v44.16H296.64zM741.6 736H283.52v-44h136.96A612.8 612.8 0 0 0 368 597.44l35.2-22.72h-62.4v-176h348v176H624l35.36 23.2A633.12 633.12 0 0 1 608 692h134.24z" fill="#61CD72" p-id="6081"></path><path d="M389.44 443.68H640v86.56H389.44z" fill="#61CD72" p-id="6082"></path></svg>
''';

const _doubanColor = Color(0xFF319C4A);
const _fanqieColor = Color(0xFFF44336);

/// 番茄阅读 logo（红色）— 红色描边轮廓
const _fanqieSvg = '''
<svg t="1786603427917" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="8080" width="32" height="32"><path d="M747.52 122.88c87.04 0 158.72 71.68 158.72 158.72v471.04c0 87.04-71.68 158.72-158.72 158.72H276.48c-87.04 0-158.72-71.68-158.72-158.72V276.48c0-87.04 71.68-158.72 158.72-158.72l471.04 5.12z m0-20.48H276.48C179.2 102.4 102.4 179.2 102.4 276.48v471.04C102.4 844.8 179.2 921.6 276.48 921.6h471.04c97.28 0 174.08-76.8 174.08-174.08V276.48C921.6 179.2 844.8 102.4 747.52 102.4z" fill="#FF0000" p-id="8081"></path><path d="M614.4 102.4v174.08l66.56-35.84 66.56 35.84V102.4H614.4z m-102.4 291.84c-168.96 0-317.44 71.68-409.6 184.32v163.84c0 102.4 76.8 179.2 174.08 179.2h471.04c97.28 0 174.08-76.8 174.08-174.08v-168.96c-92.16-112.64-240.64-184.32-409.6-184.32z m-194.56 399.36c-30.72 0-46.08-10.24-46.08-25.6s15.36-25.6 46.08-25.6c30.72 0 66.56 25.6 66.56 25.6s-35.84 25.6-66.56 25.6z m25.6-133.12c-20.48-20.48-25.6-40.96-15.36-51.2 10.24-10.24 30.72-10.24 51.2 15.36 25.6 20.48 30.72 66.56 30.72 66.56s-40.96-10.24-66.56-30.72z m168.96-15.36s-25.6-35.84-25.6-66.56c0-30.72 10.24-46.08 25.6-46.08s25.6 15.36 25.6 46.08c0 30.72-25.6 66.56-25.6 66.56z m133.12-20.48c20.48-20.48 40.96-20.48 51.2-15.36 10.24 10.24 10.24 30.72-15.36 51.2-20.48 20.48-66.56 25.6-66.56 25.6s5.12-40.96 30.72-61.44z m61.44 168.96c-30.72 0-66.56-25.6-66.56-25.6s35.84-25.6 66.56-25.6c30.72 0 46.08 10.24 46.08 25.6-5.12 15.36-15.36 25.6-46.08 25.6z" fill="#FF0000" p-id="8082"></path></svg>
''';

/// 快捷添加页 — 选择分类 + 输入豆瓣链接，解析后跳转到对应添加表单
class QuickAddPage extends StatefulWidget {
  const QuickAddPage({super.key});

  @override
  State<QuickAddPage> createState() => _QuickAddPageState();
}

class _QuickAddPageState extends State<QuickAddPage> {
  static const _categories = [
    ('影视', 'movie', Icons.movie_outlined),
    ('书籍', 'book', Icons.menu_book_outlined),
    ('游戏', 'game', Icons.sports_esports_outlined),
  ];

  String _category = 'movie';
  final _doubanController = TextEditingController();
  final _fanqieController = TextEditingController();
  bool _parsing = false;
  bool _doubanExpanded = false;
  bool _fanqieExpanded = false;

  @override
  void dispose() {
    _doubanController.dispose();
    _fanqieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('快捷添加'),
        backgroundColor: colors.surface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: SegmentedButton<String>(
                segments: _categories
                    .map((c) => ButtonSegment(
                          value: c.$2,
                          icon: Icon(c.$3, size: 18),
                        ))
                    .toList(),
                selected: {_category},
                onSelectionChanged: (v) => setState(() => _category = v.first),
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10)),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return colors.primary;
                    }
                    return colors.surfaceContainerHighest.withValues(alpha: 0.5);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return colors.onPrimary;
                    }
                    return colors.onSurface.withValues(alpha: 0.6);
                  }),
                  side: const WidgetStatePropertyAll(BorderSide.none),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _buildSourceCard(
            colors: colors,
            icon: SizedBox(
                width: 20,
                height: 20,
                child: SvgPicture.string(_doubanSvg, fit: BoxFit.contain)),
            iconTileColor: _doubanColor,
            title: '豆瓣',
            subtitle: '输入豆瓣链接，自动解析并填充信息',
            controller: _doubanController,
            expanded: _doubanExpanded,
            onToggle: () => setState(() => _doubanExpanded = !_doubanExpanded),
            onParse: () => _parseDouban(),
          ),
          if (_category == 'book') ...[
            const SizedBox(height: 12),
            _buildSourceCard(
              colors: colors,
              icon: SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.string(_fanqieSvg, fit: BoxFit.contain)),
              iconTileColor: _fanqieColor,
              title: '番茄阅读',
              subtitle: '输入番茄小说链接，自动解析并填充信息',
              controller: _fanqieController,
              expanded: _fanqieExpanded,
              onToggle: () => setState(() => _fanqieExpanded = !_fanqieExpanded),
              onParse: _parseFanqie,
            ),
          ],
          const SizedBox(height: 12),
          Text('点击右侧箭头展开，填入链接后点「解析」，跳转到对应表单',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ),
    );
  }

  /// 添加来源列表项 — 右侧箭头展开后填入链接解析
  Widget _buildSourceCard({
    required ColorScheme colors,
    required Widget icon,
    required Color iconTileColor,
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required bool expanded,
    required VoidCallback onToggle,
    required VoidCallback onParse,
  }) {
    return Container(
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
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconTileColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: icon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurface.withValues(alpha: 0.4))),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more,
                        color: colors.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, thickness: 0.6),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.url,
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'https://...',
                      hintStyle: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.25)),
                      prefixIcon: Icon(Icons.link, size: 18, color: colors.onSurface.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _parsing ? null : onParse,
                      icon: _parsing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_fix_high_outlined, size: 18),
                      label: Text(_parsing ? '解析中...' : '解析'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _parseDouban() async {
    final url = _doubanController.text.trim();
    if (url.isEmpty) {
      ToastUtil.show(context, '请输入豆瓣链接');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _parsing = true);
    try {
      final result = await Navigator.of(context).pushNamed(
        '/douban-webview',
        arguments: {'url': url, 'category': _category},
      ) as Map<String, dynamic>?;
      if (!mounted || result == null) return;
      await _openForm(result);
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _parseFanqie() async {
    final url = _fanqieController.text.trim();
    if (url.isEmpty) {
      ToastUtil.show(context, '请输入番茄小说链接');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _parsing = true);
    try {
      final result = await Navigator.of(context).pushNamed(
        '/douban-webview',
        arguments: {'url': url, 'category': 'book', 'source': 'fanqie'},
      ) as Map<String, dynamic>?;
      if (!mounted || result == null) return;
      await _openBookFromInfo(result);
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  /// 番茄结果 → 书籍表单预填充
  Future<void> _openBookFromInfo(Map<String, dynamic> info) async {
    final id = const Uuid().v4();
    final authorRaw = info['author']?.toString().trim() ?? '';
    final authors = authorRaw
        .replaceAll(RegExp(r'[（(]?著[）)]?$'), '')
        .split(RegExp(r'[/、,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final coverPath = await _downloadCover(info['coverUrl']?.toString() ?? '', id);

    if (!mounted) return;

    final prefill = <String, dynamic>{
      'title': info['title']?.toString().trim() ?? '',
      'authors': authors,
      'genres': _splitList(info['genres']),
      'summary': info['summary']?.toString().trim() ?? '',
      'coverPath': coverPath,
    };
    Navigator.of(context).pushNamed('/book-form', arguments: {'prefill': prefill});
  }

  Future<void> _openForm(Map<String, dynamic> info) async {
    final id = const Uuid().v4();
    final title = info['title']?.toString().trim() ?? '';
    final rating = double.tryParse(info['rating']?.toString() ?? '');
    final genres = _splitList(info['genres']);
    final summary = info['summary']?.toString().trim() ?? '';
    final releaseDate = _parseDate(info['releaseDate']?.toString());

    // 尽力下载封面，失败不阻塞
    final coverPath = await _downloadCover(info['coverUrl']?.toString() ?? '', id);

    if (!mounted) return;

    // 预填充字段（不传模型，保持表单为「添加」模式）
    final prefill = <String, dynamic>{
      'title': title,
      'rating': rating,
      'genres': genres,
      'summary': summary,
      'releaseDate': releaseDate,
      'coverPath': coverPath,
    };

    switch (_category) {
      case 'book':
        prefill['authors'] = _splitList(info['author']);
        prefill['translators'] = _splitList(info['translator']);
        prefill['publisher'] = info['publisher']?.toString().trim() ?? '';
        prefill['isbn'] = info['isbn']?.toString().trim() ?? '';
        prefill['publishDate'] = releaseDate;
        Navigator.of(context).pushNamed('/book-form', arguments: {'prefill': prefill});
      case 'game':
        prefill['developer'] = _splitList(info['developer']);
        prefill['platforms'] = _splitList(info['platforms']);
        Navigator.of(context).pushNamed('/game-form', arguments: {'prefill': prefill});
      default:
        prefill['directors'] = info['director']?.toString().trim().isNotEmpty == true
            ? [info['director'].toString().trim()]
            : const [];
        prefill['writers'] = (info['writers'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        prefill['actors'] = (info['actors'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        prefill['alternateTitles'] = (info['alternateTitles'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        Navigator.of(context).pushNamed('/movie-form', arguments: {'prefill': prefill});
    }
  }

  List<String> _splitList(Object? value) {
    if (value == null) return const [];
    final s = value.toString();
    if (s.trim().isEmpty) return const [];
    return s.split(RegExp(r'[/、,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      final clean = s.trim().split('(').first.trim();
      return DateTime.parse(clean);
    } catch (_) {
      return null;
    }
  }

  /// 下载封面到本地，返回本地路径；失败返回 null
  Future<String?> _downloadCover(String url, String id) async {
    if (url.isEmpty || !url.startsWith('http')) return null;
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Referer': Uri.parse(url).replace(path: '/').toString(),
        },
      );
      if (response.statusCode != 200) return null;
      final contentType = response.headers['content-type'];
      if (contentType != null && !contentType.startsWith('image/')) return null;

      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String targetPath;
      switch (_category) {
        case 'book':
          targetPath = await ImagePathHelper.instance.getBookCoverPath(id, fileName);
        case 'game':
          targetPath = await ImagePathHelper.instance.getGameCoverPath(id, fileName);
        default:
          targetPath = await ImagePathHelper.instance.getMoviePosterPath(id, fileName);
      }
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);
      return targetPath;
    } catch (e) {
      debugPrint('封面下载失败: $e');
      return null;
    }
  }
}