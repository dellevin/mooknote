import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../utils/responsive.dart';
import '../../widgets/tag_side_panel.dart';
import 'note_share_page.dart';

/// 笔记详情页
class NoteDetailPage extends StatefulWidget {
  final Note note;
  final bool embedded;

  const NoteDetailPage({super.key, required this.note, this.embedded = false});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  // ─── 编辑模式 ───
  bool _isEditing = false;
  String _editMode = 'edit'; // 'edit' | 'preview'
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  List<String> _editTags = [];
  List<String> _editImages = [];
  Timer? _autoSaveTimer;
  String _saveStatus = '';
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
    _editTags = List.from(widget.note.tags);
    _editImages = List.from(widget.note.images);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    final latest = context.read<AppProvider>().notes
        .where((n) => n.id == widget.note.id).firstOrNull ?? widget.note;
    _titleCtrl.text = latest.title;
    _contentCtrl.text = latest.content;
    _editTags = List.from(latest.tags);
    _editImages = List.from(latest.images);
    _saveStatus = '';
    setState(() => _isEditing = true);
  }

  void _onContentChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _autoSave();
    });
  }

  Future<void> _autoSave() async {
    final content = _contentCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return;
    try {
      final latest = context.read<AppProvider>().notes
          .where((n) => n.id == widget.note.id).firstOrNull ?? widget.note;
      final updated = latest.copyWith(
        title: title, content: content, tags: _editTags, images: _editImages,
        updatedAt: DateTime.now(),
      );
      await context.read<AppProvider>().updateNote(updated);
      if (mounted) {
        setState(() => _saveStatus = 'saved');
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _saveStatus == 'saved') setState(() => _saveStatus = '');
        });
      }
    } catch (_) {}
  }

  Future<void> _saveEdit() async {
    _autoSaveTimer?.cancel();
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ToastUtil.show(context, '标题或内容不能为空');
      return;
    }
    try {
      final latest = context.read<AppProvider>().notes
          .where((n) => n.id == widget.note.id).firstOrNull ?? widget.note;
      final updated = latest.copyWith(
        title: title, content: content, tags: _editTags, images: _editImages,
        updatedAt: DateTime.now(),
      );
      await context.read<AppProvider>().updateNote(updated);
      if (!mounted) return;
      ToastUtil.show(context, '保存成功');
      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) ToastUtil.show(context, '保存失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = context.watch<AppProvider>().notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );

    if (Breakpoint.isDesktop(context)) {
      return _buildDesktopStyle(note, colors);
    }
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: widget.embedded
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.read<AppProvider>().selectNote(null),
              )
            : null,
        titleSpacing: 0,
        title: Text(
          note.title.isNotEmpty
              ? note.title
              : _truncateContent(note.content),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.outlineVariant, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${note.createdAt.day}',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w200,
                        color: colors.onSurface.withValues(alpha: 0.75),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')} 周${_weekdays[note.createdAt.weekday - 1]}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.55)),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${note.content.length} 字',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
                    ),
                  ],
                ),
              ),

              if (note.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _buildTagRow(note.tags),
                ),

              Expanded(
                child: Markdown(
                  data: note.content,
                  styleSheet: _buildMarkdownStyleSheet(colors),
                  padding: const EdgeInsets.all(16),
                  // ignore: deprecated_member_use
                  imageBuilder: (uri, title, alt) => _buildMarkdownImage(uri, note),
                ),
              ),

              if (note.images.isNotEmpty) _buildImageRow(note.images),
            ],
          ),

          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(),
          ),
        ],
      ),
    );
  }

  /// 桌面端布局
  Widget _buildDesktopStyle(Note note, ColorScheme colors) {
    if (_isEditing) return _buildDesktopEditStyle(note, colors);
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
                icon: Icon(Icons.arrow_back, color: colors.onSurface, size: 18),
                onPressed: widget.embedded
                    ? () => context.read<AppProvider>().selectNote(null)
                    : () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  note.title.isNotEmpty ? note.title : _truncateContent(note.content),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
            ]),
          ),
          // 日期信息栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
            ),
            child: Row(
              children: [
                Text('${note.createdAt.day}',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w200, color: colors.onSurface.withValues(alpha: 0.75), height: 1.0)),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')} 周${_weekdays[note.createdAt.weekday - 1]}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colors.onSurface.withValues(alpha: 0.55))),
                  const SizedBox(height: 1),
                  Text('${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                ]),
                const Spacer(),
                Text('${note.content.length} 字',
                  style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
              ],
            ),
          ),
          if (note.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 24, right: 24),
              child: _buildTagRow(note.tags),
            ),
          // 内容
          Expanded(
            child: Markdown(
              data: note.content,
              styleSheet: _buildMarkdownStyleSheet(colors),
              padding: const EdgeInsets.all(24),
              // ignore: deprecated_member_use
              imageBuilder: (uri, title, alt) => _buildMarkdownImage(uri, note),
            ),
          ),
          if (note.images.isNotEmpty) _buildImageRow(note.images),
          // 底部操作栏
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDeleteDialog(context),
                  icon: Icon(Icons.delete_outline, size: 16, color: colors.error),
                  label: Text('删除', style: TextStyle(color: colors.error)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _enterEditMode,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('编辑'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── 桌面端编辑模式：左编辑 + 右预览 ────────────────────────────

  Widget _buildDesktopEditStyle(Note note, ColorScheme colors) {
    return Scaffold(
      backgroundColor: colors.surface,
      body: Column(
        children: [
          // 顶栏
          Container(
            height: 48,
            decoration: BoxDecoration(color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
            child: Row(children: [
              IconButton(icon: Icon(Icons.close, color: colors.onSurface, size: 18),
                onPressed: () { _autoSaveTimer?.cancel(); if (_saveStatus == 'saved') _autoSave(); setState(() => _isEditing = false); }),
              Expanded(child: Text(_titleCtrl.text.isNotEmpty ? _titleCtrl.text : '编辑笔记',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
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
              if (_saveStatus == 'saved')
                Padding(padding: const EdgeInsets.only(right: 8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text('已保存', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                  ])),
              FilledButton.icon(onPressed: _saveEdit,
                icon: const Icon(Icons.check, size: 16), label: const Text('保存'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(width: 12),
            ]),
          ),
          // 主体
          Expanded(
            child: _editMode == 'edit' ? _buildEditArea(colors, note) : _buildPreviewArea(colors, note),
          ),
        ],
      ),
    );
  }

  Widget _editModeChip(IconData icon, String label, String mode, ColorScheme colors) {
    final active = _editMode == mode;
    return GestureDetector(onTap: () => setState(() => _editMode = mode),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          boxShadow: active ? [BoxShadow(color: colors.onSurface.withValues(alpha: 0.03), blurRadius: 2)] : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w500 : FontWeight.normal,
            color: active ? colors.onSurface : colors.onSurface.withValues(alpha: 0.4))),
        ])));
  }

  Widget _buildEditArea(ColorScheme colors, Note note) {
    final isWin = Platform.isWindows;
    return Column(children: [
      // 标题输入
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5))),
        child: TextField(controller: _titleCtrl, maxLines: 1,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface),
          decoration: InputDecoration(hintText: '添加标题',
            hintStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.2)),
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          onChanged: (_) => setState(() {})),
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
                for (int i = 0; i < _editTags.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_editTags[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6))),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: () => setState(() => _editTags.removeAt(i)),
                          child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.3)),
                        ),
                      ]),
                    ),
                  ),
                GestureDetector(
                  onTap: _showEditTagPanel,
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
        child: TextField(controller: _contentCtrl, maxLines: null, expands: true,
          textAlignVertical: TextAlignVertical.top,
          strutStyle: const StrutStyle(forceStrutHeight: true, height: 1.6, fontSize: 14),
          style: TextStyle(fontSize: 14, color: colors.onSurface, height: 1.6),
          decoration: InputDecoration(hintText: '使用 Markdown 格式书写...',
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25), height: 1.6),
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.all(16)),
          onChanged: (_) => _onContentChanged()),
      ),
      // 图片网格
      if (_editImages.isNotEmpty) _buildEditImageGrid(colors),
      // 底部标签 + 字数 + 工具栏（仅非 Windows）
      if (!isWin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.outlineVariant, width: 0.5))),
          child: Column(children: [
            // 标签行
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (int i = 0; i < _editTags.length; i++) Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_editTags[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(width: 3),
                  GestureDetector(onTap: () => setState(() => _editTags.removeAt(i)),
                    child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.3))),
                ])),
              GestureDetector(onTap: _showEditTagPanel,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: colors.onSurface.withValues(alpha: 0.25), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 12, color: colors.onSurface.withValues(alpha: 0.35)),
                    const SizedBox(width: 2),
                    Text('标签', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
                  ]))),
            ]),
            const SizedBox(height: 6),
            // 工具栏
            Row(children: [
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _editToolBtn(Icons.title, '标题', _insertHeading),
                _editToolBtn(Icons.format_bold, '粗体', () => _insertMarkdown('**', '**')),
                _editToolBtn(Icons.format_italic, '斜体', () => _insertMarkdown('*', '*')),
                _editToolBtn(Icons.format_strikethrough, '删除线', () => _insertMarkdown('~~', '~~')),
                _editToolGap(colors),
                _editToolBtn(Icons.format_list_bulleted, '无序列表', () => _insertMarkdown('- ', '')),
                _editToolBtn(Icons.format_list_numbered, '有序列表', () => _insertMarkdown('1. ', '')),
                _editToolBtn(Icons.format_quote, '引用', () => _insertMarkdown('> ', '')),
                _editToolBtn(Icons.insert_link, '链接', () => _insertMarkdown('[', '](url)')),
                _editToolGap(colors),
                _editToolBtn(Icons.code, '行内代码', () => _insertMarkdown('`', '`')),
                _editToolBtn(Icons.data_object, '代码块', () => _insertMarkdown('```\n', '\n```')),
                _editToolBtn(Icons.horizontal_rule, '分割线', () => _insertMarkdown('---\n', '')),
                _editToolGap(colors),
                _editToolBtn(Icons.add_photo_alternate_outlined, '图片', _pickEditImage),
              ]))),
              const SizedBox(width: 8),
              Text('${_contentCtrl.text.length} 字', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
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

  Widget _buildPreviewArea(ColorScheme colors, Note note) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_titleCtrl.text.isNotEmpty) ...[
          Text(_titleCtrl.text, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.3)),
          const SizedBox(height: 16),
        ],
        Markdown(
          data: _contentCtrl.text,
          styleSheet: _buildMarkdownStyleSheet(colors),
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // ignore: deprecated_member_use
          imageBuilder: (uri, title, alt) => _buildMarkdownImage(uri, note),
        ),
        if (_editImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildImageRow(_editImages),
        ],
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _editToolBtn(IconData icon, String tooltip, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Material(color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(6),
        child: Tooltip(message: tooltip,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.6))))));
  }

  Widget _editToolGap(ColorScheme colors) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 3),
      child: SizedBox(height: 12, child: VerticalDivider(width: 0, thickness: 0.5, color: colors.outline)));
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
    _onContentChanged();
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
        selection: TextSelection.collapsed(offset: lineStart + newPrefix.length));
    } else if (hashCount >= 6) {
      _contentCtrl.value = TextEditingValue(
        text: text.substring(0, lineStart) + text.substring(pos),
        selection: TextSelection.collapsed(offset: lineStart));
    } else {
      _contentCtrl.value = TextEditingValue(
        text: text.substring(0, lineStart) + '# ' + text.substring(lineStart),
        selection: TextSelection.collapsed(offset: lineStart + 2));
    }
    _onContentChanged();
  }

  Future<void> _pickEditImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
      if (image == null) return;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetDir = await ImagePathHelper.instance.getNoteImagesDir(widget.note.id);
      await ImagePathHelper.instance.ensureDirExists(targetDir);
      final targetPath = p.join(targetDir, fileName);
      await File(image.path).copy(targetPath);
      if (mounted) setState(() => _editImages.add(targetPath));
      _onContentChanged();
    } catch (e) {
      if (mounted) ToastUtil.show(context, '选择图片失败: $e');
    }
  }

  Future<void> _showEditTagPanel() async {
    final provider = context.read<AppProvider>();
    final tagRows = await provider.getTags('note_tag');
    final allTags = tagRows.map((t) => t['name'] as String).toSet();
    for (final note in provider.notes) { allTags.addAll(note.tags); }
    if (!mounted) return;
    TagSidePanel.show(context: context, selectedTags: List.from(_editTags),
      allAvailableTags: allTags.toList()..sort(),
      onTagsChanged: (newTags) => setState(() => _editTags = newTags));
  }

  Widget _buildEditImageGrid(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      height: 72,
      child: ListView.separated(scrollDirection: Axis.horizontal,
        itemCount: _editImages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (ctx, i) {
          if (i < _editImages.length) {
            return Stack(children: [
              InkWell(onTap: () => _showImagePreview(_editImages, i),
                child: Container(width: 56, height: 56,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: colors.outlineVariant, width: 0.5)),
                  clipBehavior: Clip.antiAlias,
                  child: FadeInLocalImage(path: _editImages[i], fit: BoxFit.cover))),
              Positioned(top: -4, right: -4,
                child: GestureDetector(onTap: () => setState(() => _editImages.removeAt(i)),
                  child: Container(width: 16, height: 16,
                    decoration: BoxDecoration(color: colors.surface, shape: BoxShape.circle, border: Border.all(color: colors.outline)),
                    child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.5))))),
            ]);
          }
          return InkWell(onTap: _pickEditImage,
            child: Container(width: 56, height: 56,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: colors.surfaceContainerHighest,
                border: Border.all(color: colors.outlineVariant)),
              child: Icon(Icons.add_photo_alternate_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.3))));
        }),
    );
  }

  Widget _buildTagRow(List<String> tags) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 28,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tags[index],
              style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageRow(List<String> images) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () => _showImagePreview(images, index),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.outlineVariant, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: FadeInLocalImage(
                path: images[index],
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: colors.surfaceContainerHighest,
                  child: Icon(Icons.broken_image_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
                ),
              ),
            ),
          );
        },
      ),
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

  Widget _buildMarkdownImage(Uri uri, Note note) {
    final path = uri.toString();
    if (path.isEmpty) return const SizedBox.shrink();

    for (final imgPath in note.images) {
      if (imgPath.contains(path) || path.contains(imgPath)) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FadeInLocalImage(path: imgPath, fit: BoxFit.cover),
          );
      }
    }

    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      );
    }

    return const SizedBox.shrink();
  }

  void _showImagePreview(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: FadeInLocalImage(path: images[initialIndex], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _truncateContent(String content) {
    final cleaned = content
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        .replaceAll(RegExp(r'^\s*[-*+]\s', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*>\s', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '')
        .trim();
    if (cleaned.isEmpty) return '无标题';
    return cleaned.length > 20 ? '${cleaned.substring(0, 20)}…' : cleaned;
  }

  void _navigateToEdit(BuildContext context) {
    final currentNote = context.read<AppProvider>().notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );
    final provider = context.read<AppProvider>();
    Navigator.pushNamed(context, '/note-form', arguments: currentNote).then((_) async {
      provider.setEditRefresh(currentNote.id);
      await provider.loadNotes();
    });
  }

  Widget _buildFloatingActionButtons() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        if (!Platform.isWindows) ...[
          const SizedBox(height: 12),
          _buildFloatingButton(
            icon: Icons.share_outlined,
            onPressed: _shareNote,
            tooltip: '分享',
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
        ],
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: foregroundColor),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('删除后将移至回收站，确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().removeNote(widget.note.id);
              if (widget.embedded) {
                context.read<AppProvider>().selectNote(null);
              } else {
                Navigator.pop(context);
              }
            },
            child: Text('删除', style: TextStyle(color: errorColor)),
          ),
        ],
      ),
    );
  }

  void _shareNote() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteSharePage(note: widget.note)),
    );
  }
}
