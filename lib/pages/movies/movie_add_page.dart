import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/genre_selector_page.dart';

class MovieAddPage extends StatefulWidget {
  final VoidCallback? onCancel;
  final String? initialStatus;
  const MovieAddPage({super.key, this.onCancel, this.initialStatus});

  @override
  State<MovieAddPage> createState() => _MovieAddPageState();
}

class _MovieAddPageState extends State<MovieAddPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _ratingCtrl;
  List<String> _directors = [];
  List<String> _writers = [];
  List<String> _actors = [];
  List<String> _genres = [];
  List<String> _alternateTitles = [];
  String? _posterPath;
  String _status = 'want_to_watch';
  String _category = 'movie';
  DateTime? _releaseDate;
  DateTime? _watchDate;
  bool _isDownloading = false;
  String? _tempId;

  static const _categories = [
    ('电影', 'movie'), ('电视剧', 'tv'), ('动漫', 'anime'),
    ('综艺', 'variety'), ('纪录片', 'documentary'), ('微短剧', 'short'), ('其他', 'other'),
  ];

  @override
  void initState() {
    super.initState();
    _tempId = const Uuid().v4();
    _status = widget.initialStatus ?? 'want_to_watch';
    _titleCtrl = TextEditingController();
    _summaryCtrl = TextEditingController();
    _ratingCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _ratingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasPoster = _posterPath != null && _posterPath!.isNotEmpty;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // 顶栏
            Container(height: 48,
              decoration: BoxDecoration(color: colors.surface,
                border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
              child: Row(children: [
                IconButton(icon: Icon(Icons.close, color: colors.onSurface, size: 18),
                  onPressed: () => widget.onCancel?.call()),
                Expanded(child: Text('添加影视',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
                FilledButton.icon(onPressed: _save,
                  icon: const Icon(Icons.check, size: 16), label: const Text('保存'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
                const SizedBox(width: 12),
              ]),
            ),
            // 主体：左封面+右表单
            Expanded(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 左侧
                Container(width: 240, padding: const EdgeInsets.all(20), child: Column(children: [
                  GestureDetector(onTap: _showCoverOptions, child: Container(
                    width: 200, height: 280,
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(alignment: Alignment.center, children: [
                      hasPoster ? FadeInLocalImage(path: _posterPath, fit: BoxFit.cover)
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.image_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
                            const SizedBox(height: 8),
                            Text('点击添加海报', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
                          ]),
                      if (_isDownloading) Container(color: Colors.black.withValues(alpha: 0.4),
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    ]),
                  )),
                  if (hasPoster) Padding(padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(onTap: () => setState(() => _posterPath = null),
                      child: Text('移除海报', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))))),
                  const SizedBox(height: 20),
                  _label('状态', colors), const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                    child: Wrap(spacing: 0, runSpacing: 4, children: [
                      _statusChip('想看', 'want_to_watch', colors), _statusChip('在看', 'watching', colors), _statusChip('已看', 'watched', colors),
                    ])),
                  const SizedBox(height: 16),
                  _label('评分', colors), const SizedBox(height: 6),
                  _buildRatingRow(colors),
                  const SizedBox(height: 16),
                  _label('分类', colors), const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: _categories.map((c) {
                    final sel = _category == c.$2;
                    return GestureDetector(onTap: () => setState(() => _category = c.$2),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: sel ? colors.primary : colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                        child: Text(c.$1, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w500 : FontWeight.normal,
                          color: sel ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.5)))));
                  }).toList()),
                ])),
                // 右侧表单
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 20, 24, 80),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _field('名称', _titleCtrl, hint: '影视名称', required: true), const SizedBox(height: 16),
                    _chipField('别名', _alternateTitles, onTap: () async {
                      final r = await GenreSelectorPage.show(context: context, title: '添加别名', existingTags: [], initialSelected: _alternateTitles, hint: '输入别名');
                      if (r != null) setState(() => _alternateTitles = r);
                    }), const SizedBox(height: 16),
                    _chipField('导演', _directors, onTap: () async {
                      final p = context.read<AppProvider>(); final d = p.movies.map((m) => m.directors).toList();
                      final r = await GenreSelectorPage.show(context: context, title: '选择导演', existingTagsFuture: compute(_collectUnique, d), initialSelected: _directors, hint: '如：张艺谋');
                      if (r != null) setState(() => _directors = r);
                    }), const SizedBox(height: 16),
                    _chipField('编剧', _writers, onTap: () async {
                      final p = context.read<AppProvider>(); final d = p.movies.map((m) => m.writers).toList();
                      final r = await GenreSelectorPage.show(context: context, title: '选择编剧', existingTagsFuture: compute(_collectUnique, d), initialSelected: _writers, hint: '如：刘慈欣');
                      if (r != null) setState(() => _writers = r);
                    }), const SizedBox(height: 16),
                    _chipField('主演', _actors, onTap: () async {
                      final p = context.read<AppProvider>(); final d = p.movies.map((m) => m.actors).toList();
                      final r = await GenreSelectorPage.show(context: context, title: '选择主演', existingTagsFuture: compute(_collectUnique, d), initialSelected: _actors, hint: '如：梁朝伟');
                      if (r != null) setState(() => _actors = r);
                    }), const SizedBox(height: 16),
                    _chipField('类型', _genres, onTap: () async {
                      final p = context.read<AppProvider>();
                      final tags = await p.getTags('movie_genre', excludeHidden: true);
                      final names = tags.map((t) => t['name'] as String).toList();
                      if (!mounted) return;
                      final r = await GenreSelectorPage.show(context: context, title: '选择类型', existingTags: names, initialSelected: _genres, hint: '如：剧情、科幻');
                      if (r != null) setState(() => _genres = r);
                    }), const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _dateField('上映日期', _releaseDate, (d) => setState(() => _releaseDate = d))),
                      const SizedBox(width: 12),
                      Expanded(child: _dateField('观看日期', _watchDate, (d) => setState(() => _watchDate = d), clearable: true)),
                    ]), const SizedBox(height: 16),
                    _label('剧情简介', colors), const SizedBox(height: 6),
                    Container(constraints: const BoxConstraints(minHeight: 120),
                      child: TextFormField(controller: _summaryCtrl, maxLines: null,
                        style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
                        decoration: InputDecoration(hintText: '写下剧情简介...', hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.25)),
                          filled: true, fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.all(12)))),
                  ]),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String l, ColorScheme c) => Text(l, style: TextStyle(fontSize: 12, color: c.onSurface.withValues(alpha: 0.4)));
  Widget _statusChip(String label, String value, ColorScheme c) {
    final sel = _status == value;
    return GestureDetector(onTap: () => setState(() => _status = value),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: sel ? c.surface : Colors.transparent, borderRadius: BorderRadius.circular(6),
          boxShadow: sel ? [BoxShadow(color: c.onSurface.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))] : null),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w500 : FontWeight.normal,
          color: sel ? c.onSurface : c.onSurface.withValues(alpha: 0.4)))));
  }

  Widget _buildRatingRow(ColorScheme colors) {
    return Row(children: [
      ...List.generate(5, (i) {
        final sv = i + 1; final cr = double.tryParse(_ratingCtrl.text) ?? 0; final sr = cr / 2;
        final f = sv <= sr; final h = sv == sr.ceil() && sr % 1 != 0;
        return GestureDetector(onTap: () => setState(() => _ratingCtrl.text = (sv * 2).toString()),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(h ? Icons.star_half : (f ? Icons.star : Icons.star_border), size: 20, color: (f || h) ? const Color(0xFFFFB800) : colors.outline)));
      }),
      const SizedBox(width: 8),
      Container(width: 48, height: 28, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
        child: TextFormField(controller: _ratingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center, inputFormatters: [_RatingInputFormatter()],
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
          decoration: InputDecoration(hintText: '0-10', hintStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25)),
            border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 6), isDense: true),
          onChanged: (_) => setState(() {}))),
      if (_ratingCtrl.text.isNotEmpty) ...[
        const SizedBox(width: 4),
        GestureDetector(onTap: () => setState(() => _ratingCtrl.clear()),
          child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3))),
      ],
    ]);
  }

  Widget _field(String label, TextEditingController ctrl, {String hint = '', bool required = false}) {
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(required ? '$label *' : label, style: TextStyle(fontSize: 12, color: c.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 6),
      TextFormField(controller: ctrl, style: TextStyle(fontSize: 14, color: c.onSurface),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? '请输入$label' : null : null,
        decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: c.onSurface.withValues(alpha: 0.25)),
          filled: true, fillColor: c.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), isDense: true)),
    ]);
  }

  Widget _chipField(String label, List<String> chips, {required VoidCallback onTap}) {
    final c = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: c.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 6),
      GestureDetector(onTap: onTap,
        child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: c.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
          child: chips.isEmpty
            ? Text('点击选择$label', style: TextStyle(fontSize: 14, color: c.onSurface.withValues(alpha: 0.25)))
            : Wrap(spacing: 4, runSpacing: 4, children: chips.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(4)),
                child: Text(e, style: TextStyle(fontSize: 12, color: c.onSurface)))).toList()))),
    ]);
  }

  Widget _dateField(String label, DateTime? date, ValueChanged<DateTime?> onChanged, {bool clearable = false}) {
    final c = Theme.of(context).colorScheme; final has = date != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12, color: c.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 6),
      GestureDetector(onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: date ?? DateTime.now(),
          firstDate: DateTime(1900), lastDate: DateTime.now().add(const Duration(days: 365 * 5)));
        if (picked != null) onChanged(picked);
      }, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: c.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Text(has ? '${date!.year}.${date!.month.toString().padLeft(2, '0')}.${date!.day.toString().padLeft(2, '0')}' : '选择日期',
            style: TextStyle(fontSize: 14, color: has ? c.onSurface : c.onSurface.withValues(alpha: 0.25))),
          const Spacer(),
          if (clearable && has) GestureDetector(onTap: () => onChanged(null),
            child: Icon(Icons.close, size: 14, color: c.onSurface.withValues(alpha: 0.3))),
        ]))),
    ]);
  }

  void _showCoverOptions() {
    final c = Theme.of(context).colorScheme;
    showModalBottomSheet(context: context, backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.outline, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft,
            child: Text('添加海报', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.onSurface)))),
          const SizedBox(height: 16),
          ListTile(leading: Icon(Icons.photo_library_outlined, color: c.onSurface.withValues(alpha: 0.6)),
            title: Text('从相册选择'), onTap: () { Navigator.pop(ctx); _pickCover(); }),
          ListTile(leading: Icon(Icons.link_outlined, color: c.onSurface.withValues(alpha: 0.6)),
            title: Text('网络链接'), onTap: () { Navigator.pop(ctx); _pickCoverFromUrl(); }),
        ]))));
  }

  Future<void> _pickCover() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 1200, imageQuality: 85);
      if (picked == null) return;
      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(_tempId!, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(picked.path).copy(targetPath);
      if (mounted) setState(() => _posterPath = targetPath);
    } catch (e) { if (mounted) ToastUtil.show(context, '选择海报失败: $e'); }
  }

  Future<void> _pickCoverFromUrl() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) {
      final c = Theme.of(ctx).colorScheme;
      return AlertDialog(backgroundColor: c.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('添加网络图片', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.onSurface)),
        content: TextField(controller: ctrl, keyboardType: TextInputType.url, style: TextStyle(fontSize: 14, color: c.onSurface),
          decoration: InputDecoration(hintText: 'https://example.com/image.jpg', filled: true, fillColor: c.surfaceContainerHigh,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ]);
    });
    final url = ctrl.text.trim(); ctrl.dispose();
    if (ok != true || url.isEmpty) return;
    await _downloadCover(url);
  }

  Future<void> _downloadCover(String url) async {
    setState(() => _isDownloading = true);
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0', 'Accept': 'image/*,*/*;q=0.8', 'Referer': Uri.parse(url).replace(path: '/').toString(),
      });
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final fileName = 'poster_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = await ImagePathHelper.instance.getMoviePosterPath(_tempId!, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(res.bodyBytes);
      if (mounted) setState(() => _posterPath = targetPath);
    } catch (e) { if (mounted) ToastUtil.show(context, '下载失败: $e'); }
    finally { if (mounted) setState(() => _isDownloading = false); }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final noteId = const Uuid().v4();
      // 移动封面到正式目录
      String? finalPosterPath;
      if (_posterPath != null) {
        final normalized = _posterPath!.replaceAll('\\', '/');
        if (!normalized.contains('/movies/$noteId/')) {
          final fileName = p.basename(_posterPath!);
          final newPath = await ImagePathHelper.instance.getMoviePosterPath(noteId, fileName);
          await ImagePathHelper.instance.ensureDirExists(p.dirname(newPath));
          final src = File(_posterPath!);
          if (await src.exists()) { await src.rename(newPath); finalPosterPath = newPath; }
          // 清理临时目录
          final tempDir = Directory(p.dirname(_posterPath!));
          if (await tempDir.exists()) { try { await tempDir.delete(recursive: true); } catch (_) {} }
        } else { finalPosterPath = _posterPath; }
      }
      final rating = _ratingCtrl.text.isNotEmpty ? double.tryParse(_ratingCtrl.text) : null;
      final now = DateTime.now();
      final movie = Movie(
        id: noteId, title: _titleCtrl.text.trim(), posterPath: finalPosterPath,
        releaseDate: _releaseDate, directors: _directors, writers: _writers, actors: _actors,
        genres: _genres, alternateTitles: _alternateTitles, summary: _summaryCtrl.text.trim(),
        rating: rating, status: _status, category: _category, watchDate: _watchDate,
        createdAt: now, updatedAt: now,
      );
      await context.read<AppProvider>().addMovie(movie);
      await context.read<AppProvider>().loadMovies();
      if (!mounted) return;
      context.read<AppProvider>().finishAdding();
      ToastUtil.show(context, '添加成功');
    } catch (e) { if (mounted) ToastUtil.show(context, '保存失败: $e'); }
  }

  static List<String> _collectUnique(List<List<String>> lists) {
    final s = <String>{}; for (final l in lists) { s.addAll(l); } return s.toList()..sort();
  }
}

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
