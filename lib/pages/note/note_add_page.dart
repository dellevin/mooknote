import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/tag_side_panel.dart';

class NoteAddPage extends StatefulWidget {
  final VoidCallback? onCancel;
  const NoteAddPage({super.key, this.onCancel});

  @override
  State<NoteAddPage> createState() => _NoteAddPageState();
}

class _NoteAddPageState extends State<NoteAddPage> {
  final ImagePicker _picker = ImagePicker();
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  List<String> _tags = [];
  List<String> _images = [];
  String _editMode = 'edit'; // 'edit' | 'preview'
  late String _tempId;

  @override
  void initState() {
    super.initState();
    _tempId = const Uuid().v4();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          // 顶栏
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
            ),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.close, color: colors.onSurface, size: 18),
                onPressed: () => widget.onCancel?.call(),
              ),
              Expanded(
                child: Text('添加笔记',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
              ),
              // 编辑/预览切换
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _editModeChip(Icons.edit_outlined, '编辑', 'edit', colors),
                  _editModeChip(Icons.visibility_outlined, '预览', 'preview', colors),
                ]),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('保存'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
            ]),
          ),
          // 主体
          Expanded(
            child: _editMode == 'edit' ? _buildEditArea(colors) : _buildPreviewArea(colors),
          ),
        ],
      ),
    );
  }

  Widget _editModeChip(IconData icon, String label, String mode, ColorScheme colors) {
    final active = _editMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _editMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: active ? [BoxShadow(color: colors.onSurface.withValues(alpha: 0.03), blurRadius: 2)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w500 : FontWeight.normal,
            color: active ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4))),
        ]),
      ),
    );
  }

  Widget _buildEditArea(ColorScheme colors) {
    final isWin = Platform.isWindows;
    return Column(children: [
      // 标题输入
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
        child: TextField(
          controller: _titleCtrl,
          maxLines: 1,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '添加标题',
            hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.2)),
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      // Windows: 标签栏移到标题下方（靠左）
      if (isWin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (int i = 0; i < _tags.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_tags[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: () => setState(() => _tags.removeAt(i)),
                          child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.3)),
                        ),
                      ]),
                    ),
                  ),
                GestureDetector(
                  onTap: _showTagPanel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.onSurface.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                      const SizedBox(width: 2),
                      Text('标签', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      // 内容编辑
      Expanded(
        child: TextField(
          controller: _contentCtrl,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.6, fontSize: 14),
          style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
          decoration: InputDecoration(
            hintText: '使用 Markdown 格式书写...',
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25), height: 1.6),
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      // 图片行
      if (_images.isNotEmpty) _buildImageRow(colors),
      // 底部标签 + 工具栏（仅非 Windows）
      if (!isWin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5))),
          child: Column(children: [
            // 标签行
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (int i = 0; i < _tags.length; i++) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_tags[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(width: 3),
                  GestureDetector(
                    onTap: () => setState(() => _tags.removeAt(i)),
                    child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.3)),
                  ),
                ]),
              ),
              GestureDetector(
                onTap: _showTagPanel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.onSurface.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                    const SizedBox(width: 2),
                    Text('标签', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            // 工具栏
            Row(children: [
              Expanded(
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                  _toolBtn(Icons.title, '标题', _insertHeading),
                  _toolBtn(Icons.format_bold, '粗体', () => _insertMarkdown('**', '**')),
                  _toolBtn(Icons.format_italic, '斜体', () => _insertMarkdown('*', '*')),
                  _toolBtn(Icons.format_strikethrough, '删除线', () => _insertMarkdown('~~', '~~')),
                  _toolGap(colors),
                  _toolBtn(Icons.format_list_bulleted, '无序列表', () => _insertMarkdown('- ', '')),
                  _toolBtn(Icons.format_list_numbered, '有序列表', () => _insertMarkdown('1. ', '')),
                  _toolBtn(Icons.format_quote, '引用', () => _insertMarkdown('> ', '')),
                  _toolBtn(Icons.insert_link, '链接', () => _insertMarkdown('[', '](url)')),
                  _toolGap(colors),
                  _toolBtn(Icons.code, '行内代码', () => _insertMarkdown('`', '`')),
                  _toolBtn(Icons.data_object, '代码块', () => _insertMarkdown('```\n', '\n```')),
                  _toolBtn(Icons.horizontal_rule, '分割线', () => _insertMarkdown('---\n', '')),
                  _toolGap(colors),
                  _toolBtn(Icons.add_photo_alternate_outlined, '图片', _pickImage),
                ])),
              ),
              const SizedBox(width: 8),
              Text('${_contentCtrl.text.length} 字',
                style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
            ]),
          ]),
        ),
      // Windows: 底部只显示字数
      if (isWin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('${_contentCtrl.text.length} 字', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
          ]),
        ),
    ]);
  }

  Widget _buildPreviewArea(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_titleCtrl.text.isNotEmpty) ...[
          Text(_titleCtrl.text,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3)),
          const SizedBox(height: 16),
        ],
        Markdown(
          data: _contentCtrl.text,
          styleSheet: _buildMarkdownStyleSheet(colors),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildPreviewImageRow(colors),
        ],
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildImageRow(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          if (i < _images.length) {
            return Stack(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.outlineVariant, width: 0.5)),
                clipBehavior: Clip.antiAlias,
                child: FadeInLocalImage(path: _images[i], fit: BoxFit.cover),
              ),
              Positioned(top: -4, right: -4,
                child: GestureDetector(
                  onTap: () => setState(() => _images.removeAt(i)),
                  child: Container(width: 16, height: 16,
                    decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle, border: Border.all(color: colors.outline)),
                    child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.5))),
                ),
              ),
            ]);
          }
          return InkWell(
            onTap: _pickImage,
            child: Container(width: 56, height: 56,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: colors.surfaceContainerHighest,
                border: Border.all(color: colors.outlineVariant)),
              child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.3))),
          );
        },
      ),
    );
  }

  Widget _buildPreviewImageRow(ColorScheme colors) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: FadeInLocalImage(
              path: _images[index],
              fit: BoxFit.cover,
              errorWidget: Container(
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ),
    );
  }

  Widget _toolGap(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(height: 12, child: VerticalDivider(width: 0, thickness: 0.5, color: colors.outline)),
    );
  }

  void _insertMarkdown(String left, String right) {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    final start = selection.start;
    final end = selection.end;
    String selectedText = end > start ? text.substring(start, end) : '';
    final insertion = '$left$selectedText$right';
    _contentCtrl.value = TextEditingValue(
      text: text.substring(0, start) + insertion + text.substring(end),
      selection: TextSelection.collapsed(
        offset: selectedText.isEmpty ? start + left.length : start + left.length + selectedText.length + right.length,
      ),
    );
    setState(() {});
  }

  void _insertHeading() {
    final text = _contentCtrl.text;
    final selection = _contentCtrl.selection;
    final start = selection.start;
    int lineStart = start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') lineStart--;
    int hashCount = 0;
    int pos = lineStart;
    while (pos < text.length && text[pos] == '#') { hashCount++; pos++; }
    if (pos < text.length && text[pos] == ' ') pos++;
    if (hashCount > 0 && hashCount < 6) {
      hashCount++;
      final newPrefix = '${'#' * hashCount} ';
      _contentCtrl.value = TextEditingValue(
        text: text.substring(0, lineStart) + newPrefix + text.substring(pos),
        selection: TextSelection.collapsed(offset: lineStart + newPrefix.length),
      );
    } else if (hashCount >= 6) {
      _contentCtrl.value = TextEditingValue(
        text: text.substring(0, lineStart) + text.substring(pos),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    } else {
      _contentCtrl.value = TextEditingValue(
        text: text.substring(0, lineStart) + '# ' + text.substring(lineStart),
        selection: TextSelection.collapsed(offset: lineStart + 2),
      );
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
      if (image == null) return;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetDir = await ImagePathHelper.instance.getNoteImagesDir(_tempId);
      await ImagePathHelper.instance.ensureDirExists(targetDir);
      final targetPath = p.join(targetDir, fileName);
      await File(image.path).copy(targetPath);
      if (mounted) setState(() => _images.add(targetPath));
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: $e');
    }
  }

  Future<void> _showTagPanel() async {
    final provider = context.read<AppProvider>();
    final tagRows = await provider.getTags('note_tag');
    final allTags = tagRows.map((t) => t['name'] as String).toSet();
    for (final note in provider.notes) { allTags.addAll(note.tags); }
    if (!mounted) return;
    TagSidePanel.show(
      context: context,
      selectedTags: List.from(_tags),
      allAvailableTags: allTags.toList()..sort(),
      onTagsChanged: (newTags) => setState(() => _tags = newTags),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(ColorScheme colors) {
    return MarkdownStyleSheet(
      h1: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      h2: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      h3: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      h4: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      p: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.75), height: 1.8),
      code: TextStyle(fontSize: 14, color: colors.onSurface, backgroundColor: colors.surfaceContainerHighest, fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: TextStyle(fontSize: 15, color: colors.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic, height: 1.8),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.onSurface.withValues(alpha: 0.4), width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: TextStyle(fontSize: 15, color: colors.onSurface),
      listIndent: 24,
      a: const TextStyle(fontSize: 15, color: Color(0xFF4A90D9), decoration: TextDecoration.underline),
      tableHead: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
      tableBody: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.75)),
      tableBorder: TableBorder.all(color: colors.outline, width: 0.5),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsDecoration: BoxDecoration(color: colors.surface),
      tablePadding: const EdgeInsets.all(8),
      strong: TextStyle(fontWeight: FontWeight.w600, color: colors.onSurface),
      em: TextStyle(fontStyle: FontStyle.italic, color: colors.onSurface.withValues(alpha: 0.75)),
      del: TextStyle(decoration: TextDecoration.lineThrough, color: colors.onSurface.withValues(alpha: 0.4)),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ToastUtil.show(context, '标题或内容不能为空');
      return;
    }
    try {
      final noteId = const Uuid().v4();
      // 移动图片从临时目录到正式目录
      List<String> finalImages = [];
      if (_images.isNotEmpty) {
        final newDir = await ImagePathHelper.instance.getNoteImagesDir(noteId);
        for (final imgPath in _images) {
          final normalized = imgPath.replaceAll('\\', '/');
          if (normalized.contains('/notes/${_tempId}/')) {
            final fileName = p.basename(imgPath);
            final newPath = p.join(newDir, fileName);
            await ImagePathHelper.instance.ensureDirExists(newDir);
            final src = File(imgPath);
            if (await src.exists()) { await src.rename(newPath); finalImages.add(newPath); }
          } else {
            finalImages.add(imgPath);
          }
        }
        // 清理临时目录
        try { await ImagePathHelper.instance.deleteNoteImages(_tempId); } catch (_) {}
      }
      final note = Note(
        id: noteId,
        title: title,
        content: content,
        tags: _tags,
        images: finalImages.isNotEmpty ? finalImages : _images,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await context.read<AppProvider>().addNote(note);
      await context.read<AppProvider>().loadNotes();
      if (!mounted) return;
      context.read<AppProvider>().finishAdding();
      ToastUtil.show(context, '添加成功');
    } catch (e) {
      if (mounted) ToastUtil.show(context, '保存失败: $e');
    }
  }

  static List<String> _collectUnique(List<List<String>> lists) {
    final s = <String>{};
    for (final l in lists) { s.addAll(l); }
    return s.toList()..sort();
  }
}
