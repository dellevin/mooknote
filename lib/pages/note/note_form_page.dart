import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/tag_side_panel.dart';

/// 添加/编辑笔记页面 - 极简书写界面
class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late DateTime _createdAt;
  List<String> _tags = [];
  List<String> _images = []; // 图片路径列表
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();
  String? _tempNoteId; // 新建模式时使用的临时笔记ID
  String _editorMode = 'edit'; // 'edit' | 'preview'
  Timer? _autoSaveTimer;
  Timer? _saveStatusTimer;
  String _saveStatus = ''; // '', 'saved'
  Note? _savedNote; // 新建模式首次自动保存后的笔记引用

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    final text = note?.content ?? '';
    _contentController = TextEditingController(text: text);
    _createdAt = note?.createdAt ?? DateTime.now();
    _tags = note != null ? List.from(note.tags) : [];
    _images = note != null ? List.from(note.images) : [];
    _isEditing = note != null;
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _saveStatusTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _autoSave();
    });
  }

  Future<void> _autoSave() async {
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    try {
      final now = DateTime.now();
      if (_isEditing) {
        final updatedNote = widget.note!.copyWith(
          title: title,
          content: content,
          tags: _tags,
          images: _images,
          updatedAt: now,
        );
        await context.read<AppProvider>().updateNote(updatedNote);
      } else if (_savedNote != null) {
        final updatedNote = _savedNote!.copyWith(
          title: title,
          content: content,
          tags: _tags,
          images: _images,
          updatedAt: now,
        );
        await context.read<AppProvider>().updateNote(updatedNote);
        _savedNote = updatedNote;
      } else {
        final noteId = now.millisecondsSinceEpoch.toString();
        List<String> finalImages = [];
        if (_images.isNotEmpty) {
          final oldNoteId = _tempNoteId ?? noteId;
          finalImages = await _moveImagesToNewId(oldNoteId, noteId);
        }
        final newNote = Note(
          id: noteId,
          title: title,
          content: content,
          tags: _tags,
          images: finalImages.isNotEmpty ? finalImages : _images,
          createdAt: _createdAt,
          updatedAt: now,
        );
        await context.read<AppProvider>().addNote(newNote);
        _savedNote = newNote;
        _isEditing = true;
      }
      if (mounted) {
        setState(() => _saveStatus = 'saved');
        _saveStatusTimer?.cancel();
        _saveStatusTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _saveStatus == 'saved') setState(() => _saveStatus = '');
        });
      }
    } catch (_) {
      // 自动保存失败静默处理
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmLeave();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final keyboardH = MediaQuery.of(context).viewInsets.bottom;
          final contentH = constraints.maxHeight * 0.4;
          return Stack(
            children: [
              Column(
                children: [
                  // 顶部区域 — 固定不动
                  _buildHeader(colors, topPadding),

                  // 可滚动内容
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // 标题行（点击编辑）
                        SliverToBoxAdapter(child: _buildTitleInput(colors)),

                        // 编辑区域 — 固定高度
                        SliverToBoxAdapter(
                          child: SizedBox(height: contentH, child: _buildContentArea()),
                        ),

                        // 图片 + 标签 + 字数 — 随内容撑开
                        SliverToBoxAdapter(child: _buildImageGrid()),
                        SliverToBoxAdapter(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: _buildTagChips(),
                        )),
                        SliverToBoxAdapter(child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Text(
                            '一共${_contentController.text.length}字',
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.3)),
                          ),
                        )),

                        // 与工具栏的间距
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ],
              ),

              // 底部浮动工具栏 — 跟随键盘上移
              Positioned(
                left: 0,
                right: 0,
                bottom: keyboardH,
                child: _buildFloatingToolbar(),
              ),
            ],
          );
        },
      ),
    ),
    );
  }

  /// 顶部区域：返回 / 年月日 周几 / 保存按钮
  Widget _buildHeader(ColorScheme colors, double topPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, topPadding + 4, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              final shouldPop = await _confirmLeave();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_ios_new, size: 20, color: colors.onSurface.withValues(alpha: 0.7)),
          ),
          Expanded(
            child: Text(
              '${_createdAt.year}年${_createdAt.month}月${_createdAt.day}日 周${_weekdays[_createdAt.weekday - 1]}',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface),
            ),
          ),
          if (_saveStatus == 'saved')
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('已保存', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            ),
          GestureDetector(
            onTap: _saveNote,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }

  /// 在光标处插入 Markdown 语法，光标自动放到正确位置
  void _insertMarkdown(String left, String right) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    String selectedText = '';
    if (end > start) {
      selectedText = text.substring(start, end);
    }

    final insertion = '$left$selectedText$right';
    // 原子更新：一次性设置 text 和 selection，避免分步操作导致光标跳动
    _contentController.value = TextEditingValue(
      text: text.substring(0, start) + insertion + text.substring(end),
      selection: TextSelection.collapsed(
        offset: selectedText.isEmpty
            ? start + left.length
            : start + left.length + selectedText.length + right.length,
      ),
    );
  }

  /// 现代极简底部工具栏
  Widget _buildFloatingToolbar() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 格式按钮组
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _toolBtn(Icons.title, '标题', _insertHeading),
                  _toolBtn(Icons.format_bold, '粗体', () => _insertMarkdown('**', '**')),
                  _toolBtn(Icons.format_italic, '斜体', () => _insertMarkdown('*', '*')),
                  _toolBtn(Icons.format_strikethrough, '删除线', () => _insertMarkdown('~~', '~~')),
                  _toolGap(),
                  _toolBtn(Icons.format_list_bulleted, '无序列表', () => _insertMarkdown('- ', '')),
                  _toolBtn(Icons.format_list_numbered, '有序列表', () => _insertMarkdown('1. ', '')),
                  _toolBtn(Icons.format_quote, '引用', () => _insertMarkdown('> ', '')),
                  _toolBtn(Icons.insert_link, '链接', () => _insertMarkdown('[', '](url)')),
                  _toolGap(),
                  _toolBtn(Icons.code, '行内代码', () => _insertMarkdown('`', '`')),
                  _toolBtn(Icons.data_object, '代码块', () => _insertMarkdown('```\n', '\n```')),
                  _toolBtn(Icons.horizontal_rule, '分割线', () => _insertMarkdown('---\n', '')),
                ],
              ),
            ),
          ),
          // 视图模式切换
          const SizedBox(width: 8),
          Container(
            width: 1, height: 20, color: colors.outline,
          ),
          const SizedBox(width: 8),
          _modeSwitch(Icons.edit, 'edit'),
          _modeSwitch(Icons.visibility, 'preview'),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String tooltip, VoidCallback onTap) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Icon(icon, size: 21, color: colors.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );
  }

  Widget _toolGap() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 18,
        child: VerticalDivider(width: 0, thickness: 0.5, color: colors.outline),
      ),
    );
  }

  Widget _modeSwitch(IconData icon, String mode) {
    final colors = Theme.of(context).colorScheme;
    final active = _editorMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _editorMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: active ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? colors.onPrimary : colors.onSurface.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }

  /// 插入标题（在当前行首插入 # ，如果已有则升级 ## → ### → ####）
  void _insertHeading() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;

    // 找到当前行起始位置
    int lineStart = start;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    // 计算当前行的 # 前缀
    int hashCount = 0;
    int pos = lineStart;
    while (pos < text.length && text[pos] == '#') {
      hashCount++;
      pos++;
    }
    // 跳过 # 后的空格
    if (pos < text.length && text[pos] == ' ') pos++;

    String newPrefix;
    int cursorOffset;
    if (hashCount > 0 && hashCount < 6) {
      // 升级标题级别
      hashCount++;
      newPrefix = '${'#' * hashCount} ';
      cursorOffset = newPrefix.length;
      // 替换旧前缀
      _contentController.value = TextEditingValue(
        text: text.substring(0, lineStart) + newPrefix + text.substring(pos),
        selection: TextSelection.collapsed(offset: lineStart + cursorOffset),
      );
    } else if (hashCount >= 6) {
      // 已经是 H6，重置为普通文本
      _contentController.value = TextEditingValue(
        text: text.substring(0, lineStart) + text.substring(pos),
        selection: TextSelection.collapsed(offset: lineStart),
      );
    } else {
      // 没有 # 前缀，添加 H1
      newPrefix = '# ';
      _contentController.value = TextEditingValue(
        text: text.substring(0, lineStart) + newPrefix + text.substring(lineStart),
        selection: TextSelection.collapsed(offset: lineStart + 2),
      );
    }
  }

  /// 根据 _editorMode 构建内容区域
  Widget _buildContentArea() {
    switch (_editorMode) {
      case 'preview':
        return _buildPreview();
      case 'edit':
      default:
        return _buildEditor();
    }
  }

  /// 编辑器
  Widget _buildEditor() {
    final colors = Theme.of(context).colorScheme;
    return TextField(
      controller: _contentController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      strutStyle: const StrutStyle(
        forceStrutHeight: true,
        height: 1.6,
        fontSize: 14,
      ),
      style: TextStyle(
        fontSize: 14,
        color: colors.onSurface,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText: '使用 Markdown 格式书写...',
        hintStyle: TextStyle(
          fontSize: 14,
          color: colors.onSurface.withValues(alpha: 0.25),
          height: 1.6,
        ),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  /// 实时 Markdown 预览（点击回到编辑）
  Widget _buildPreview() {
    final colors = Theme.of(context).colorScheme;
    final text = _contentController.text;
    return GestureDetector(
      onTap: () => setState(() => _editorMode = 'edit'),
      behavior: HitTestBehavior.opaque,
      child: Container(
      color: colors.surfaceContainerHigh,
      child: text.isEmpty
          ? Center(
              child: Text(
                '预览区域',
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface.withValues(alpha: 0.25),
                ),
              ),
            )
          : Markdown(
              data: text,
              selectable: true,
              padding: const EdgeInsets.all(16),
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  height: 1.4,
                ),
                h2: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  height: 1.4,
                ),
                h3: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  height: 1.4,
                ),
                p: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.75),
                  height: 1.7,
                ),
                code: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
                  backgroundColor: colors.outlineVariant,
                ),
                codeblockDecoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                blockquote: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface.withValues(alpha: 0.6),
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: colors.onSurface.withValues(alpha: 0.25), width: 3),
                  ),
                ),
              ),
            ),
    ));
  }

  /// 标签 chips 行（右侧展示）
  Widget _buildTagChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (int i = 0; i < _tags.length; i++) _buildTagChip(i),
        _buildAddTagButton(),
      ],
    );
  }

  Widget _buildTagChip(int index) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tags[index],
            style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: () => setState(() => _tags.removeAt(index)),
            child: Icon(Icons.close, size: 10, color: colors.onSurface.withValues(alpha: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTagButton() {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _showTagPanel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.onSurface.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 12, color: colors.onSurface.withValues(alpha: 0.35)),
            const SizedBox(width: 2),
            Text('标签', style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35))),
          ],
        ),
      ),
    );
  }

  /// 显示标签侧边面板
  Future<void> _showTagPanel() async {
    final provider = context.read<AppProvider>();
    final tagRows = await provider.getTags('note_tag');
    final allTags = tagRows.map((t) => t['name'] as String).toSet();
    for (final note in provider.notes) {
      allTags.addAll(note.tags);
    }

    if (!mounted) return;
    TagSidePanel.show(
      context: context,
      selectedTags: List.from(_tags),
      allAvailableTags: allTags.toList()..sort(),
      onTagsChanged: (newTags) {
        setState(() => _tags = newTags);
      },
    );
  }

  /// 标题输入行
  Widget _buildTitleInput(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _titleController,
        maxLines: 1,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface),
        decoration: InputDecoration(
          hintText: '添加标题',
          hintStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.onSurface.withValues(alpha: 0.2)),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// 检查表单是否有内容
  bool _hasContent() {
    if (_isEditing) return true;
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_contentController.text.trim().isNotEmpty) return true;
    if (_images.isNotEmpty) return true;
    if (_tags.isNotEmpty) return true;
    return false;
  }

  /// 离开确认（自动保存后直接返回）
  Future<bool> _confirmLeave() async {
    _autoSaveTimer?.cancel();
    if (_hasContent()) await _autoSave();
    return true;
  }

  Future<void> _saveNote() async {
    _autoSaveTimer?.cancel();
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ToastUtil.show(context, '标题或内容不能为空');
      return;
    }

    try {
    final now = DateTime.now();

    if (_isEditing) {
      // 更新现有笔记
      final updatedNote = widget.note!.copyWith(
        title: _titleController.text.trim(),
        content: content,
        tags: _tags,
        images: _images,
        updatedAt: now,
      );
      await context.read<AppProvider>().updateNote(updatedNote);
    } else {
      // 添加新笔记 - 先创建笔记获取ID
      final noteId = now.millisecondsSinceEpoch.toString();

      // 如果有图片，需要移动到正确的ID目录
      List<String> finalImages = [];
      if (_images.isNotEmpty) {
        // 使用保存的临时ID，如果没有则使用当前noteId（理论上不会走到这里）
        final oldNoteId = _tempNoteId ?? noteId;
        final newNoteId = noteId;
        finalImages = await _moveImagesToNewId(oldNoteId, newNoteId);
      }

      final title = _titleController.text.trim();

      final newNote = Note(
        id: noteId,
        title: title,
        content: content,
        tags: _tags,
        images: finalImages.isNotEmpty ? finalImages : _images,
        createdAt: _createdAt,
        updatedAt: now,
      );
      await context.read<AppProvider>().addNote(newNote);
    }

    if (!mounted) return;

    ToastUtil.show(context, _isEditing ? '保存成功' : '添加成功');

    // 刷新笔记列表
    await context.read<AppProvider>().loadNotes();

    if (!mounted) return;
    Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ToastUtil.show(context, '保存失败: $e');
    }
  }

  /// 将图片从临时ID目录移动到新ID目录
  Future<List<String>> _moveImagesToNewId(String oldNoteId, String newNoteId) async {
    final List<String> newPaths = [];

    final newDir = await ImagePathHelper.instance.getNoteImagesDir(newNoteId);

    for (final imagePath in _images) {
      // 使用路径分隔符检查，兼容 Windows 和 Unix
      final normalizedPath = imagePath.replaceAll('\\', '/');
      if (normalizedPath.contains('/notes/$oldNoteId/')) {
        // 需要移动的文件
        final fileName = p.basename(imagePath);
        final newPath = p.join(newDir, fileName);

        await ImagePathHelper.instance.ensureDirExists(newDir);

        // 检查源文件是否存在
        final sourceFile = File(imagePath);
        if (await sourceFile.exists()) {
          await sourceFile.rename(newPath);
          newPaths.add(newPath);
        }
      } else {
        // 已经在正确位置的文件
        newPaths.add(imagePath);
      }
    }

    // 删除旧目录
    try {
      await ImagePathHelper.instance.deleteNoteImages(oldNoteId);
    } catch (e) {
      // 忽略删除失败
    }

    return newPaths;
  }

  /// 选择图片
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        // 生成唯一的文件名
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

        // 如果是编辑模式，使用现有笔记ID；如果是新建模式，使用临时ID（保存时会替换）
        String noteId;
        if (_isEditing) {
          noteId = widget.note!.id;
        } else {
          // 新建模式：使用已存在的临时ID或生成新的
          noteId = _tempNoteId ?? DateTime.now().millisecondsSinceEpoch.toString();
          _tempNoteId = noteId;
        }

        // 复制图片到应用目录: images/notes/{noteId}/{fileName}
        final targetDir = await ImagePathHelper.instance.getNoteImagesDir(noteId);
        await ImagePathHelper.instance.ensureDirExists(targetDir);
        final targetPath = p.join(targetDir, fileName);

        await File(image.path).copy(targetPath);

        setState(() => _images.add(targetPath));
      }
    } catch (e) {
      ToastUtil.show(context, '选择图片失败: $e');
    }
  }

  /// 构建图片网格（一行三个）
  Widget _buildImageGrid() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (int i = 0; i < _images.length; i++) _buildGridImageItem(i),
          _buildAddImageButton(),
        ],
      ),
    );
  }

  Widget _buildGridImageItem(int index) {
    final colors = Theme.of(context).colorScheme;
    final size = (MediaQuery.of(context).size.width - 16 * 2 - 10 * 2) / 3;
    return InkWell(
      onTap: () => _showImagePreview(index),
      onLongPress: () => _showDeleteImageDialog(index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outline, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: FadeInLocalImage(
          path: _images[index],
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 添加图片按钮
  Widget _buildAddImageButton() {
    final colors = Theme.of(context).colorScheme;
    final size = (MediaQuery.of(context).size.width - 16 * 2 - 10 * 2) / 3;
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.outline, width: 0.5),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 28,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// 显示图片预览
  void _showImagePreview(int index) {
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
              child: FadeInLocalImage(
                path: _images[index],
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示删除图片确认对话框
  void _showDeleteImageDialog(int index) {
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '确定要删除这张图片吗？此操作不可恢复。',
          style: TextStyle(
            fontSize: 14,
            color: colors.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _images.removeAt(index));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('删除'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
      },
    );
  }
}
