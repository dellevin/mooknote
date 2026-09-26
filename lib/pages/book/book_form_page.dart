import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
import 'package:uuid/uuid.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/genre_selector_page.dart';
import '../../widgets/alternate_titles_dialog.dart';
import '../../widgets/app_overlay.dart';
import '../../widgets/edit_sheets.dart';
import 'package:mooknote/l10n/app_strings.dart';

/// 从多值字段列表中提取去重排序的唯一值（供 compute 使用）
List<String> _collectUnique(List<List<String>> lists) {
  final s = <String>{};
  for (final l in lists) { s.addAll(l); }
  return s.toList()..sort();
}

/// 添加/编辑书籍页面
class BookFormPage extends StatefulWidget {
  final Book? book;
  final String? initialStatus;

  /// 快捷添加预填充字段（book 为 null 时生效，保持添加模式）
  final Map<String, dynamic>? prefill;

  const BookFormPage({super.key, this.book, this.initialStatus, this.prefill});

  @override
  State<BookFormPage> createState() => _BookFormPageState();
}

class _BookFormPageState extends State<BookFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _titleController;
  late TextEditingController _publisherController;
  late TextEditingController _summaryController;
  late TextEditingController _ratingController;
  late TextEditingController _isbnController;

  List<String> _authors = [];
  List<String> _translators = [];
  List<String> _alternateTitles = [];
  List<String> _genres = [];
  String? _coverPath;
  String _status = 'want_to_read';
  DateTime? _publishDate;
  DateTime? _startDate;
  DateTime? _finishDate;
  int _readCount = 0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    Book? book = widget.book;
    if (book != null) {
      final appProvider = context.read<AppProvider>();
      final latestBook = appProvider.books.where((b) => b.id == book!.id).firstOrNull;
      if (latestBook != null) book = latestBook;
    }

    _titleController = TextEditingController(text: book?.title ?? '');
    _publisherController = TextEditingController(text: book?.publisher ?? '');
    _summaryController = TextEditingController(text: book?.summary ?? '');
    _ratingController = TextEditingController(text: book?.rating?.toString() ?? '');
    _isbnController = TextEditingController(text: book?.isbn ?? '');

    if (book != null) {
      _authors = List.from(book.authors);
      _translators = List.from(book.translators);
      _alternateTitles = List.from(book.alternateTitles);
      _genres = List.from(book.genres);
      _coverPath = book.coverPath;
      _status = book.status;
      _publishDate = book.publishDate;
      _startDate = book.startDate;
      _finishDate = book.finishDate;
      _readCount = book.readCount;
    } else if (widget.initialStatus != null) {
      _status = widget.initialStatus!;
    }

    // 快捷添加预填充（保持添加模式）
    if (book == null && widget.prefill != null) {
      _fillFromPrefill(widget.prefill!);
    }
  }

  /// 从快捷添加的预填充 map 填充字段
  void _fillFromPrefill(Map<String, dynamic> prefill) {
    _titleController.text = prefill['title']?.toString() ?? '';
    _publisherController.text = prefill['publisher']?.toString() ?? '';
    _summaryController.text = prefill['summary']?.toString() ?? '';
    _ratingController.text = prefill['rating']?.toString() ?? '';
    _isbnController.text = prefill['isbn']?.toString() ?? '';
    _authors = List<String>.from(prefill['authors'] ?? const []);
    _translators = List<String>.from(prefill['translators'] ?? const []);
    _alternateTitles = List<String>.from(prefill['alternateTitles'] ?? const []);
    _genres = List<String>.from(prefill['genres'] ?? const []);
    _coverPath = prefill['coverPath'] as String?;
    _publishDate = prefill['publishDate'] as DateTime?;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _publisherController.dispose();
    _summaryController.dispose();
    _ratingController.dispose();
    _isbnController.dispose();
    super.dispose();
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed, required String tooltip}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(color: colors.surface.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(8), child: Icon(icon, color: colors.onSurface, size: 22)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isEdit = widget.book != null;

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
          title: Text(isEdit ? '编辑书籍'.tr : '添加书籍'.tr),
          actions: [
            _buildActionButton(icon: Icons.save_outlined, onPressed: _saveBook, tooltip: '保存'.tr),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 封面
              Center(child: _buildCoverPicker()),
              const SizedBox(height: 20),

              // 状态 + 评分
              _buildStatusRatingRow(),
              const SizedBox(height: 24),

              // 信息卡片网格
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // 第一行：书名 + 别名
                  _halfCard('书名'.tr, _titleController.text, Icons.book_outlined, required: true,
                    onTap: () => _editTitle(),
                  ),
                  _halfCard('别名'.tr, _alternateTitles.isEmpty ? '' : '{n}个：{tags}'.trf({'n': _alternateTitles.length, 'tags': _alternateTitles.join('、')}), Icons.alternate_email_outlined,
                    onTap: () => _editAlternateTitles(),
                  ),

                  // 第二行：作者 + 译者
                  _halfCard('作者'.tr, _authors.isEmpty ? '' : '{n}人：{names}'.trf({'n': _authors.length, 'names': _authors.join('、')}), Icons.person_outline,
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final data = provider.books.map((b) => b.authors).toList();
                      final r = await GenreSelectorPage.show(context: context, title: '选择作者'.tr, existingTagsFuture: compute(_collectUnique, data), initialSelected: _authors, hint: '如：余华、莫言'.tr, asBottomSheet: true);
                      if (!mounted) return;
                      if (r != null) setState(() => _authors = r);
                    },
                  ),
                  _halfCard('译者'.tr, _translators.isEmpty ? '' : '{n}人：{names}'.trf({'n': _translators.length, 'names': _translators.join('、')}), Icons.translate,
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final data = provider.books.map((b) => b.translators).toList();
                      final r = await GenreSelectorPage.show(context: context, title: '选择译者'.tr, existingTagsFuture: compute(_collectUnique, data), initialSelected: _translators, hint: '如：李继宏、许钧'.tr, asBottomSheet: true);
                      if (!mounted) return;
                      if (r != null) setState(() => _translators = r);
                    },
                  ),

                  // 第三行：类型 + 阅读次数
                  _halfCard('类型'.tr, _genres.isEmpty ? '' : '{n}个：{tags}'.trf({'n': _genres.length, 'tags': _genres.join('、')}), Icons.category_outlined,
                    onTap: () async {
                      final provider = context.read<AppProvider>();
                      final tags = await provider.getTags('book_genre', excludeHidden: true);
                      if (!mounted) return;
                      final r = await GenreSelectorPage.show(context: context, title: '选择类型'.tr, existingTags: tags.map((t) => t['name'] as String).toList(), initialSelected: _genres, hint: '如：小说、历史、传记'.tr, asBottomSheet: true);
                      if (!mounted) return;
                      if (r != null) setState(() => _genres = r);
                    },
                  ),
                  _buildReadCountCard(),

                  // 第四行：出版社 + 出版时间
                  _halfCard('出版社'.tr, _publisherController.text, Icons.business_outlined,
                    onTap: () async {
                      final r = await TextEditSheet.show(context: context, title: '出版社'.tr, initialText: _publisherController.text, hintText: '请输入出版社'.tr);
                      if (!mounted) return;
                      if (r != null) setState(() => _publisherController.text = r);
                    },
                  ),
                  _halfCard('出版时间'.tr, _publishDate != null ? '${_publishDate!.year}.${_publishDate!.month.toString().padLeft(2, '0')}.${_publishDate!.day.toString().padLeft(2, '0')}' : '', Icons.date_range_outlined,
                    trailing: _publishDate != null
                        ? GestureDetector(
                            onTap: () => setState(() => _publishDate = null),
                            child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                          )
                        : null,
                    onTap: () => _selectPublishDate(),
                  ),

                  // 第五行：开始阅读 + 读完日期
                  _halfCard('开始阅读'.tr, _startDate != null ? '${_startDate!.year}.${_startDate!.month.toString().padLeft(2, '0')}.${_startDate!.day.toString().padLeft(2, '0')}' : '', Icons.play_circle_outlined,
                    trailing: _startDate != null
                        ? GestureDetector(
                            onTap: () => setState(() => _startDate = null),
                            child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                          )
                        : null,
                    onTap: () => _selectStartDate(),
                  ),
                  _halfCard('读完日期'.tr, _finishDate != null ? '${_finishDate!.year}.${_finishDate!.month.toString().padLeft(2, '0')}.${_finishDate!.day.toString().padLeft(2, '0')}' : '', Icons.check_circle_outlined,
                    trailing: _finishDate != null
                        ? GestureDetector(
                            onTap: () => setState(() => _finishDate = null),
                            child: Icon(Icons.close, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                          )
                        : null,
                    onTap: () => _selectFinishDate(),
                  ),

                  // ISBN（独占一行）
                  SizedBox(
                    width: double.infinity, height: 90,
                    child: _buildInfoCard(
                      label: 'ISBN',
                      value: _isbnController.text,
                      icon: Icons.qr_code_outlined,
                      onTap: () async {
                        final r = await TextEditSheet.show(context: context, title: 'ISBN', initialText: _isbnController.text, hintText: '请输入ISBN编号'.tr);
                        if (!mounted) return;
                        if (r != null) setState(() => _isbnController.text = r);
                      },
                    ),
                  ),

                  // 书籍简介（独占一行）
                  SizedBox(
                    width: double.infinity,
                    child: _buildInfoCard(label: '书籍简介'.tr, value: _summaryController.text, icon: Icons.description_outlined, height: 160, scrollable: true, onTap: () => _editSummary()),
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

  /// 半宽卡片快捷方法
  Widget _halfCard(String label, String value, IconData icon, {bool required = false, VoidCallback? onTap, Widget? trailing}) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      height: 90,
      child: _buildInfoCard(label: label, value: value, icon: icon, required: required, onTap: onTap ?? () {}, trailing: trailing),
    );
  }

  /// 阅读次数卡片（加减号步进器）
  Widget _buildReadCountCard() {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      height: 90,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outline),
          boxShadow: [BoxShadow(color: colors.onSurface.withValues(alpha: 0.018), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.repeat_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text('阅读次数'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            ]),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepButton(icon: Icons.remove, onTap: _readCount > 0 ? () => setState(() => _readCount--) : null),
                Text('{n} 次'.trf({'n': _readCount}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
                _buildStepButton(icon: Icons.add, onTap: () => setState(() => _readCount++)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton({required IconData icon, VoidCallback? onTap}) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? colors.primary.withValues(alpha: 0.1) : colors.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: enabled ? colors.primary : colors.onSurface.withValues(alpha: 0.25)),
      ),
    );
  }

  // ─── 状态 + 评分合并行 ───

  Widget _buildStatusRatingRow() {
    final colors = Theme.of(context).colorScheme;
    final currentRating = double.tryParse(_ratingController.text) ?? 0;
    final starRating = currentRating / 2;
    final hasRating = _ratingController.text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.outlineVariant, width: 0.5)),
      child: Column(children: [
        // 状态
        Row(children: [
          Text('状态'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(width: 12),
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _buildStatusOption('想读'.tr, 'want_to_read'),
                _buildStatusOption('在读'.tr, 'reading'),
                _buildStatusOption('已读'.tr, 'read'),
                _buildStatusOption('弃读'.tr, 'abandoned'),
              ]),
            ),
          )),
        ]),
        const SizedBox(height: 12),
        // 评分
        Row(children: [
          Text('评分'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
          const SizedBox(width: 12),
          ...List.generate(5, (i) {
            final sv = i + 1;
            final filled = sv <= starRating;
            final half = sv == starRating.ceil() && starRating % 1 != 0;
            return GestureDetector(
              onTap: () => setState(() => _ratingController.text = (sv * 2).toString()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Icon(half ? Icons.star_half : (filled ? Icons.star : Icons.star_border), size: 22, color: (filled || half) ? const Color(0xFFFFB800) : colors.outline),
              ),
            );
          }),
          const SizedBox(width: 8),
          Container(
            width: 48, height: 28,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
            child: TextFormField(
              controller: _ratingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              inputFormatters: [_RatingInputFormatter()],
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
              decoration: InputDecoration(hintText: '0-10', hintStyle: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 6), isDense: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (hasRating) ...[
            const SizedBox(width: 6),
            GestureDetector(onTap: () => setState(() => _ratingController.clear()), child: Icon(Icons.close, size: 14, color: colors.onSurface.withValues(alpha: 0.3))),
          ],
        ]),
      ]),
    );
  }

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
          boxShadow: isSelected ? [BoxShadow(color: colors.onSurface.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal, color: isSelected ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4))),
      ),
    );
  }

  // ─── 封面选择器 ───

  Widget _buildCoverPicker() {
    final hasCover = _coverPath != null && _coverPath!.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: _pickCover,
        child: Container(
          width: 120, height: 170,
          decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Stack(alignment: Alignment.center, children: [
            if (hasCover) FadeInLocalImage(path: _coverPath, fit: BoxFit.cover) else _buildCoverPlaceholder(),
            if (_isDownloading) Container(color: Colors.black.withValues(alpha: 0.4), child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          ]),
        ),
      ),
      if (hasCover)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: GestureDetector(
            onTap: () => setState(() => _coverPath = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.delete_outline, size: 14, color: colors.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text('移除封面'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _buildCoverPlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_outlined, size: 32, color: colors.onSurface.withValues(alpha: 0.25)),
      const SizedBox(height: 8),
      Text('封面'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35))),
    ]);
  }

  Future<void> _pickCover() async {
    final colors = Theme.of(context).colorScheme;
    await appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: c.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('添加封面'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.onSurface)))),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.photo_library_outlined, size: 20, color: c.onSurface.withValues(alpha: 0.6))),
                title: Text('从相册选择'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurface)),
                trailing: Icon(Icons.chevron_right, color: c.onSurface.withValues(alpha: 0.25)),
                onTap: () { Navigator.pop(ctx); _pickCoverFromGallery(); },
              ),
              Divider(height: 0.5, color: c.outlineVariant),
              ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(Icons.link_outlined, size: 20, color: c.onSurface.withValues(alpha: 0.6))),
                title: Text('网络链接'.tr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.onSurface)),
                trailing: Icon(Icons.chevron_right, color: c.onSurface.withValues(alpha: 0.25)),
                onTap: () { Navigator.pop(ctx); _pickCoverFromUrl(); },
              ),
            ]),
          ),
        );
      },
    );
  }

  Future<void> _pickCoverFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 1200, imageQuality: 85);
      if (picked != null) {
        final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bookId = widget.book?.id ?? const Uuid().v4();
        final targetPath = await ImagePathHelper.instance.getBookCoverPath(bookId, fileName);
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
        await File(picked.path).copy(targetPath);
        if (!mounted) return;
        setState(() => _coverPath = targetPath);
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择封面失败: {e}'.trf({'e': e}));
    }
  }

  Future<void> _pickCoverFromUrl() async {
    final url = await TextEditSheet.show(
      context: context,
      title: '添加网络图片'.tr,
      actionLabel: '确定'.tr,
      hintText: 'https://example.com/image.jpg',
      description: '请输入图片链接地址'.tr,
      keyboardType: TextInputType.url,
    );
    if (url == null || url.trim().isEmpty) return;

    setState(() => _isDownloading = true);
    try {
      final imageUrl = url.trim();
      final response = await http.get(Uri.parse(imageUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.5 Mobile/15E148 Safari/604.1',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Referer': Uri.parse(imageUrl).replace(path: '/').toString(),
      });
      if (response.statusCode != 200) throw Exception('下载失败: HTTP {code}'.trf({'code': response.statusCode}));
      final ct = response.headers['content-type'];
      if (ct != null && !ct.startsWith('image/')) throw Exception('链接返回的不是图片');
      if (response.bodyBytes.length > 10 * 1024 * 1024) throw Exception('图片太大');

      final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bookId = widget.book?.id ?? const Uuid().v4();
      final targetPath = await ImagePathHelper.instance.getBookCoverPath(bookId, fileName);
      await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));
      await File(targetPath).writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      setState(() => _coverPath = targetPath);
    } catch (e) {
      debugPrint('封面下载失败: $e');
      if (mounted) ToastUtil.show(context, '下载失败: {e}'.trf({'e': e}));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // ─── Info Card ───

  Widget _buildInfoCard({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool required = false,
    IconData? icon,
    Widget? trailing,
    double? height,
    bool scrollable = false,
  }) {
    final hasValue = value.isNotEmpty;
    final colors = Theme.of(context).colorScheme;

    Widget buildContent() {
      if (scrollable && height != null) {
        return Flexible(
          child: SingleChildScrollView(physics: const BouncingScrollPhysics(),
            child: Text(hasValue ? value : '点击填写'.tr, style: TextStyle(fontSize: 15, color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25), fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal))),
        );
      }
      return Text(hasValue ? value : '点击填写'.tr, style: TextStyle(fontSize: 15, color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.25), fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: colors.outline),
          boxShadow: [BoxShadow(color: colors.onSurface.withValues(alpha: 0.018), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: height != null ? MainAxisSize.max : MainAxisSize.min, children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)), const SizedBox(width: 6)],
            Text(required ? '$label *' : label, style: TextStyle(fontSize: 12, color: required ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4), fontWeight: required ? FontWeight.w500 : FontWeight.normal)),
            if (trailing != null) ...[const Spacer(), trailing],
          ]),
          const SizedBox(height: 8),
          buildContent(),
        ]),
      ),
    );
  }

  // ─── 数据操作 ───

  /// 编辑书名（底部弹层）
  Future<void> _editTitle() async {
    final result = await TextEditSheet.show(
      context: context,
      title: '书名'.tr,
      initialText: _titleController.text,
      hintText: '请输入书名'.tr,
    );
    if (!mounted) return;
    if (result != null) setState(() => _titleController.text = result.trim());
  }

  /// 编辑别名（底部弹层 + 标签式输入）
  Future<void> _editAlternateTitles() async {
    final result = await AlternateTitlesDialog.showSheet(
      context: context,
      initial: _alternateTitles,
    );
    if (!mounted) return;
    if (result != null) setState(() => _alternateTitles = result);
  }

  Future<void> _selectPublishDate() async {
    final picked = await showDatePickerSheet(
      context: context,
      title: '出版时间'.tr,
      initial: _publishDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _publishDate = picked);
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePickerSheet(
      context: context,
      title: '开始阅读'.tr,
      initial: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _selectFinishDate() async {
    final picked = await showDatePickerSheet(
      context: context,
      title: '读完日期'.tr,
      initial: _finishDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (!mounted) return;
    if (picked != null) setState(() => _finishDate = picked);
  }

  /// 编辑书籍简介（底部弹层）
  Future<void> _editSummary() async {
    final result = await TextEditSheet.show(
      context: context,
      title: '书籍简介'.tr,
      initialText: _summaryController.text,
      hintText: '写下书籍简介...'.tr,
      multiline: true,
    );
    if (!mounted) return;
    if (result != null) setState(() => _summaryController.text = result);
  }

  bool _hasContent() {
    if (widget.book != null) return true;
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_summaryController.text.trim().isNotEmpty) return true;
    if (_ratingController.text.trim().isNotEmpty) return true;
    if (_isbnController.text.trim().isNotEmpty) return true;
    if (_publisherController.text.trim().isNotEmpty) return true;
    if (_coverPath != null) return true;
    if (_authors.isNotEmpty || _translators.isNotEmpty || _alternateTitles.isNotEmpty || _genres.isNotEmpty) return true;
    if (_publishDate != null) return true;
    if (_startDate != null) return true;
    if (_finishDate != null) return true;
    return false;
  }

  Future<bool> _confirmLeave() async {
    if (!_hasContent()) return true;
    final colors = Theme.of(context).colorScheme;
    final result = await appDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('未保存'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        content: Text('当前内容未保存，确定要离开吗？'.tr, style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6), height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消'.tr, style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.error, foregroundColor: colors.onError, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            child: Text('离开'.tr),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
    return result ?? false;
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final rating = _ratingController.text.isNotEmpty ? double.tryParse(_ratingController.text) : null;
      final now = DateTime.now();

      if (widget.book == null) {
        final newBookId = const Uuid().v4();
        String? finalCoverPath;
        if (_coverPath != null && _coverPath!.isNotEmpty) {
          finalCoverPath = await _moveCoverToNewId(_coverPath!, newBookId);
        }
        final newBook = Book(
          id: newBookId, title: _titleController.text.trim(), coverPath: finalCoverPath,
          authors: _authors, translators: _translators, alternateTitles: _alternateTitles, publisher: _publisherController.text.trim(),
          genres: _genres, summary: _summaryController.text.trim(), rating: rating, status: _status,
          isbn: _isbnController.text.trim().isNotEmpty ? _isbnController.text.trim() : null,
          publishDate: _publishDate, startDate: _startDate, finishDate: _finishDate, readCount: _readCount, createdAt: now, updatedAt: now,
        );
        await context.read<AppProvider>().addBook(newBook);
        await context.read<AppProvider>().loadBooks();
      } else {
        final updatedBook = widget.book!.copyWith(
          title: _titleController.text.trim(), coverPath: _coverPath,
          authors: _authors, translators: _translators, alternateTitles: _alternateTitles, publisher: _publisherController.text.trim(),
          genres: _genres, summary: _summaryController.text.trim(), rating: rating, status: _status,
          isbn: _isbnController.text.trim().isNotEmpty ? _isbnController.text.trim() : null,
          publishDate: _publishDate, startDate: _startDate, finishDate: _finishDate, readCount: _readCount, updatedAt: now,
        );
        await context.read<AppProvider>().updateBook(updatedBook);
      }

      if (!mounted) return;
      ToastUtil.show(context, widget.book == null ? '添加成功'.tr : '更新成功'.tr);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: {e}'.trf({'e': e}));
    }
  }

  Future<String?> _moveCoverToNewId(String currentPath, String newBookId) async {
    final normalizedPath = currentPath.replaceAll('\\', '/');
    if (normalizedPath.contains('/books/$newBookId/')) return currentPath;
    final fileName = p.basename(currentPath);
    final newPath = await ImagePathHelper.instance.getBookCoverPath(newBookId, fileName);
    await ImagePathHelper.instance.ensureDirExists(p.dirname(newPath));
    final currentFile = File(currentPath);
    if (await currentFile.exists()) {
      await currentFile.rename(newPath);
      try { await Directory(p.dirname(currentPath)).delete(recursive: true); } catch (_) {}
      return newPath;
    }
    return null;
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
