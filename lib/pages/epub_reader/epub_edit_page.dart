import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../data/epub/reader_dao.dart';
import '../../widgets/genre_selector_page.dart';
import '../../widgets/text_input_panel.dart';

/// EPUB 书籍编辑页
class EpubEditPage extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> book;

  const EpubEditPage({
    super.key,
    required this.bookId,
    required this.book,
  });

  @override
  State<EpubEditPage> createState() => _EpubEditPageState();
}

class _EpubEditPageState extends State<EpubEditPage> {
  final ReaderDao _dao = ReaderDao();

  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late TextEditingController _publisherCtrl;
  late TextEditingController _isbnCtrl;
  List<String> _authors = [];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.book['title'] as String? ?? '');
    _summaryCtrl = TextEditingController(text: widget.book['summary'] as String? ?? '');
    _publisherCtrl = TextEditingController(text: widget.book['publisher'] as String? ?? '');
    _isbnCtrl = TextEditingController(text: widget.book['isbn'] as String? ?? '');

    // 解析多作者：优先用 authors（JSON 数组），否则从 author（逗号分隔）解析
    final authorsJson = widget.book['authors'] as String? ?? '';
    if (authorsJson.isNotEmpty) {
      try {
        _authors = List<String>.from(jsonDecode(authorsJson));
      } catch (_) {
        _authors = _parseAuthorField(authorsJson);
      }
    } else {
      final authorStr = widget.book['author'] as String? ?? '';
      _authors = _parseAuthorField(authorStr);
    }
  }

  List<String> _parseAuthorField(String text) {
    if (text.isEmpty) return [];
    return text.split(RegExp(r'[,、/]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _publisherCtrl.dispose();
    _isbnCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isEmpty) return;
    await _dao.updateReaderBook(widget.bookId, {
      'title': newTitle,
      'author': _authors.join('、'),
      'authors': jsonEncode(_authors),
      'summary': _summaryCtrl.text.trim(),
      'publisher': _publisherCtrl.text.trim(),
      'isbn': _isbnCtrl.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory(p.join(appDir.path, 'epub_books', widget.bookId));
    if (!await bookDir.exists()) await bookDir.create(recursive: true);

    final existing = bookDir.listSync().whereType<File>().where((f) {
      final name = p.basenameWithoutExtension(f.path);
      return name.startsWith('cover_') && RegExp(r'^cover_\d+$').hasMatch(name);
    }).toList();
    int nextIndex = 1;
    if (existing.isNotEmpty) {
      final indices = existing.map((f) {
        return int.tryParse(p.basenameWithoutExtension(f.path).substring(6)) ?? 0;
      }).toList();
      indices.sort();
      nextIndex = indices.last + 1;
    }

    final ext = p.extension(picked.path).toLowerCase();
    final destPath = p.join(bookDir.path, 'cover_$nextIndex$ext');
    await File(picked.path).copy(destPath);

    await _dao.updateReaderBook(widget.bookId, {
      'cover_path': destPath,
      'updated_at': DateTime.now().toIso8601String(),
    });
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _revertCover() async {
    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory(p.join(appDir.path, 'epub_books', widget.bookId));

    final existing = bookDir.listSync().whereType<File>().where((f) {
      final name = p.basenameWithoutExtension(f.path);
      return name.startsWith('cover_') && RegExp(r'^cover_\d+$').hasMatch(name);
    }).toList();

    if (existing.isEmpty) return;

    existing.sort((a, b) {
      final ia = int.tryParse(p.basenameWithoutExtension(a.path).substring(6)) ?? 0;
      final ib = int.tryParse(p.basenameWithoutExtension(b.path).substring(6)) ?? 0;
      return ia.compareTo(ib);
    });
    final currentMax = existing.last;
    final currentIndex = int.tryParse(p.basenameWithoutExtension(currentMax.path).substring(6)) ?? 0;
    await currentMax.delete();

    if (currentIndex <= 1) {
      final coverFile = bookDir.listSync().whereType<File>().where((f) {
        final name = p.basenameWithoutExtension(f.path);
        return name == 'cover';
      }).firstOrNull;
      await _dao.updateReaderBook(widget.bookId, {
        'cover_path': coverFile?.path ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
    } else {
      final prev = existing.where((f) {
        final idx = int.tryParse(p.basenameWithoutExtension(f.path).substring(6)) ?? 0;
        return idx == currentIndex - 1;
      }).firstOrNull;
      await _dao.updateReaderBook(widget.bookId, {
        'cover_path': prev?.path ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    if (mounted) Navigator.pop(context, true);
  }

  bool get _hasLinkedBook => (widget.book['book_id'] as String? ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final coverPath = widget.book['cover_path'] as String?;
    final halfWidth = (MediaQuery.of(context).size.width - 52) / 2;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text('编辑书籍信息',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface)),
        leading: IconButton(
          icon: Icon(Icons.close, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('保存', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.primary)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 封面
          Center(child: _buildCoverPicker(coverPath, colors)),
          const SizedBox(height: 24),
          // 信息卡片
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // 标题
              SizedBox(
                width: halfWidth,
                height: 90,
                child: _buildInfoCard(
                  label: '标题',
                  value: _titleCtrl.text,
                  required: true,
                  icon: Icons.auto_stories_outlined,
                  onTap: () async {
                    final result = await TextInputPanel.show(
                      context: context,
                      title: '书名',
                      initialValue: _titleCtrl.text,
                      hint: '请输入书名',
                    );
                    if (result != null) setState(() => _titleCtrl.text = result);
                  },
                  colors: colors,
                ),
              ),
              // 作者（多选）
              SizedBox(
                width: halfWidth,
                height: 90,
                child: _buildInfoCard(
                  label: '作者',
                  value: _authors.isEmpty ? '' : '${_authors.length}人：${_authors.join('、')}',
                  icon: Icons.person_outline,
                  onTap: () async {
                    final provider = context.read<AppProvider>();
                    final data = provider.books.map((b) => b.authors).toList();
                    final result = await GenreSelectorPage.show(
                      context: context,
                      title: '选择作者',
                      existingTagsFuture: compute(_collectUnique, data),
                      initialSelected: _authors,
                      hint: '如：余华、莫言',
                    );
                    if (result != null) setState(() => _authors = result);
                  },
                  colors: colors,
                ),
              ),
              // 出版社
              SizedBox(
                width: halfWidth,
                height: 90,
                child: _buildInfoCard(
                  label: '出版社',
                  value: _publisherCtrl.text,
                  icon: Icons.business_outlined,
                  onTap: () async {
                    final result = await TextInputPanel.show(
                      context: context,
                      title: '出版社',
                      initialValue: _publisherCtrl.text,
                      hint: '请输入出版社',
                    );
                    if (result != null) setState(() => _publisherCtrl.text = result);
                  },
                  colors: colors,
                ),
              ),
              // ISBN
              SizedBox(
                width: halfWidth,
                height: 90,
                child: _buildInfoCard(
                  label: 'ISBN',
                  value: _isbnCtrl.text,
                  icon: Icons.qr_code_outlined,
                  onTap: () async {
                    final result = await TextInputPanel.show(
                      context: context,
                      title: 'ISBN',
                      initialValue: _isbnCtrl.text,
                      hint: '请输入ISBN编号',
                      keyboardType: TextInputType.number,
                    );
                    if (result != null) setState(() => _isbnCtrl.text = result);
                  },
                  colors: colors,
                ),
              ),
              // 简介（全宽）
              SizedBox(
                width: double.infinity,
                child: _buildInfoCard(
                  label: '简介',
                  value: _summaryCtrl.text,
                  icon: Icons.description_outlined,
                  height: 160,
                  scrollable: true,
                  onTap: () async {
                    final result = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _SummaryEditorPage(initialText: _summaryCtrl.text),
                      ),
                    );
                    if (result != null) setState(() => _summaryCtrl.text = result);
                  },
                  colors: colors,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // ─── 构建组件 ────────────────────────────────────────────────

  Widget _buildCoverPicker(String? coverPath, ColorScheme colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 110,
          height: 154,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: coverPath != null && coverPath.isNotEmpty && File(coverPath).existsSync()
              ? Image.file(File(coverPath), fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_outlined, size: 36,
                        color: colors.onSurface.withValues(alpha: 0.2)),
                  ],
                ),
        ),
        if (!_hasLinkedBook) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickCover,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 14,
                          color: colors.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('更换封面',
                          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _revertCover,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.undo, size: 14,
                          color: colors.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('恢复上次',
                          style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_hasLinkedBook) ...[
          const SizedBox(height: 8),
          Text('封面由关联书籍提供',
              style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
        ],
      ],
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colors,
    bool required = false,
    double? height,
    bool scrollable = false,
  }) {
    final hasValue = value.isNotEmpty;

    Widget buildContent() {
      if (scrollable && height != null) {
        return Flexible(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Text(
              hasValue ? value : '点击填写',
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.2),
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      }
      return Text(
        hasValue ? value : '未设置',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
          color: hasValue ? colors.onSurface : colors.onSurface.withValues(alpha: 0.2),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 11,
                    color: required ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4),
                    fontWeight: required ? FontWeight.w500 : FontWeight.normal,
                  )),
              if (required)
                Text(' *', style: TextStyle(fontSize: 11, color: colors.error)),
            ]),
            const Spacer(),
            buildContent(),
          ],
        ),
      ),
    );
  }
}

/// 简介 编辑页
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
        title: const Text('简介'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: Text('完成',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.primary)),
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
          hintText: '写下书籍简介...',
          hintStyle: TextStyle(color: colors.onSurface.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.all(20),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

/// 从多值字段列表中提取去重排序的唯一值（供 compute 使用）
List<String> _collectUnique(List<List<String>> lists) {
  final s = <String>{};
  for (final l in lists) {
    s.addAll(l);
  }
  return s.toList()..sort();
}
