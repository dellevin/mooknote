import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../utils/image_path_helper.dart';
import '../../widgets/markdown_editing_controller.dart';

/// Typora 风格 Markdown 编辑器
/// 所见即所得，输入 # 标题自动渲染，**粗体** 自动加粗等
class NoteFormPage extends StatefulWidget {
  final Note? note;

  const NoteFormPage({super.key, this.note});

  @override
  State<NoteFormPage> createState() => _NoteFormPageState();
}

class _NoteFormPageState extends State<NoteFormPage> {
  late MarkdownEditingController _contentController;
  late TextEditingController _titleController;
  late DateTime _createdAt;
  List<String> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _isPreviewMode = false;
  late final ScrollController _scrollController;
  late final FocusNode _contentFocusNode;

  bool get _isNewNote => widget.note == null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _createdAt = note?.createdAt ?? DateTime.now();
    _images = note != null ? List.from(note.images) : [];
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = MarkdownEditingController(text: note?.content ?? '');
    _scrollController = ScrollController();
    _contentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 预览/编辑切换
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit_outlined : Icons.visibility_outlined,
              color: const Color(0xFF333333),
            ),
            onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
          ),
          // 保存
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF333333)),
            onPressed: _saveNote,
          ),
        ],
      ),
      body: Column(
        children: [
          // 标题输入
          _buildTitleField(),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // 内容区域
          Expanded(
            child: _isPreviewMode ? _buildPreview() : _buildEditor(),
          ),

          // 图片区域
          if (_images.isNotEmpty) _buildImageSection(),

          // 底部工具栏 - 键盘弹出时自动上移
          if (!_isPreviewMode) _buildMarkdownToolbarContent(),
        ],
      ),
    );
  }

  // ==================== 标题输入 ====================

  /// 构建标题输入框
  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
          height: 1.4,
        ),
        decoration: const InputDecoration(
          hintText: '笔记标题',
          hintStyle: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Color(0xFFCCCCCC),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: 1,
      ),
    );
  }

  // ==================== Markdown 快捷工具栏 ====================

  /// 构建 Markdown 快捷工具栏
  Widget _buildMarkdownToolbarContent() {
    return Container(
      height: 48,
      color: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文本格式
              _buildToolbarButton(Icons.format_bold, '粗体', _insertBold),
              _buildToolbarButton(Icons.format_italic, '斜体', _insertItalic),
              _buildToolbarButton(Icons.format_strikethrough, '删除线', _insertStrikethrough),
              _buildToolbarDivider(),
              // 段落
              _buildToolbarButton(Icons.title, '标题', () => _insertHeader(1)),
              _buildToolbarButton(Icons.format_quote, '引用', _insertQuote),
              _buildToolbarButton(Icons.code, '代码块', _insertCodeBlock),
              _buildToolbarButton(Icons.horizontal_rule, '分割线', _insertDivider),
              _buildToolbarDivider(),
              // 列表
              _buildToolbarButton(Icons.format_list_bulleted, '无序列表', _insertUnorderedList),
              _buildToolbarButton(Icons.format_list_numbered, '有序列表', _insertOrderedList),
              _buildToolbarDivider(),
              // 插入
              _buildToolbarButton(Icons.link, '链接', _insertLink),
              _buildToolbarButton(Icons.image, '图片', _pickImage),
              _buildToolbarButton(Icons.calendar_today, '日期', _insertDate),
              _buildToolbarButton(Icons.access_time, '时间', _insertTime),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建工具栏分隔线
  Widget _buildToolbarDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: const Color(0xFFDCDCDC),
    );
  }

  /// 构建工具栏按钮
  Widget _buildToolbarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          splashColor: const Color(0x1F000000),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF666666),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 编辑器主体 ====================

  /// 构建编辑器主体 - 使用 MarkdownEditingController 实现所见即所得
  Widget _buildEditor() {
    return TextField(
      controller: _contentController,
      scrollController: _scrollController,
      focusNode: _contentFocusNode,
      style: const TextStyle(
        fontSize: 16,
        color: Color(0xFF333333),
        height: 1.8,
      ),
      decoration: const InputDecoration(
        hintText: '开始书写 Markdown...\n'
            '支持 # 标题、**粗体**、*斜体*、\`代码\` 等',
        hintStyle: TextStyle(
          fontSize: 16,
          color: Color(0xFFCCCCCC),
          height: 1.8,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(16),
      ),
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      keyboardType: TextInputType.multiline,
    );
  }

  // ==================== 预览区域 ====================

  /// 构建预览区域
  Widget _buildPreview() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: MarkdownBody(
        data: _contentController.text.isEmpty
            ? '*预览区域 - 开始输入 Markdown 内容...*'
            : _contentController.text,
        styleSheet: _buildMarkdownStyleSheet(),
      ),
    );
  }

  /// 构建 Markdown 样式表
  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      h1: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      h2: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      h3: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      h4: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      p: const TextStyle(
        fontSize: 15,
        color: Color(0xFF333333),
        height: 1.8,
      ),
      code: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A1A1A),
        backgroundColor: Color(0xFFF5F5F5),
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: const TextStyle(
        fontSize: 15,
        color: Color(0xFF666666),
        fontStyle: FontStyle.italic,
        height: 1.8,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF999999), width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A1A),
      ),
      listIndent: 24,
      a: const TextStyle(
        fontSize: 15,
        color: Color(0xFF4A90D9),
        decoration: TextDecoration.underline,
      ),
      tableHead: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      tableBody: const TextStyle(
        fontSize: 14,
        color: Color(0xFF333333),
      ),
      tableBorder: TableBorder.all(
        color: const Color(0xFFE5E5E5),
        width: 0.5,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsDecoration: const BoxDecoration(
        color: Colors.white,
      ),
      tablePadding: const EdgeInsets.all(8),
      strong: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Color(0xFF333333),
      ),
      del: const TextStyle(
        decoration: TextDecoration.lineThrough,
        color: Color(0xFF999999),
      ),
    );
  }

  // ==================== 图片区域 ====================

  /// 构建图片区域
  Widget _buildImageSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        border: Border(
          top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '附件图片',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _images.map((path) => _buildImageItem(path)).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建单个图片项
  Widget _buildImageItem(String imagePath) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 80,
                height: 80,
                color: const Color(0xFFF5F5F5),
                child: const Icon(Icons.broken_image, size: 24, color: Color(0xFFCCCCCC)),
              );
            },
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _images.remove(imagePath)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建添加图片的浮动按钮

  // ==================== 图片选择 ====================

  /// 选择图片
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final fileName = 'note_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final noteId = widget.note?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

        final targetPath = await ImagePathHelper.instance.getNoteImagePath(noteId, fileName);
        await ImagePathHelper.instance.ensureDirExists(p.dirname(targetPath));

        await File(pickedFile.path).copy(targetPath);

        setState(() => _images.add(targetPath));

        // 在 Markdown 内容中插入图片链接
        _insertImageLink(targetPath, fileName);
      }
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '选择图片失败: $e');
      }
    }
  }

  // ==================== Markdown 快捷插入 ====================

  /// 在光标位置插入文本
  void _insertText(String text, {String? wrapPrefix, String? wrapSuffix}) {
    final currentText = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) {
      // 没有焦点，直接追加到末尾
      if (wrapPrefix != null) {
        final suffix = wrapSuffix ?? wrapPrefix;
        final newText = '$wrapPrefix$text$suffix';
        _contentController.text = currentText + newText;
        _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
      } else {
        _contentController.text = currentText + text;
        _contentController.selection = TextSelection.collapsed(offset: _contentController.text.length);
      }
      _contentFocusNode.requestFocus();
      return;
    }

    final before = currentText.substring(0, start);
    final selected = start < end ? currentText.substring(start, end) : null;
    final after = currentText.substring(end);

    if (wrapPrefix != null) {
      final suffix = wrapSuffix ?? wrapPrefix;
      final content = selected ?? text;
      final newText = '$before$wrapPrefix$content$suffix$after';
      _contentController.text = newText;
      final cursorOffset = before.length + wrapPrefix.length + content.length + suffix.length;
      _contentController.selection = TextSelection.collapsed(offset: cursorOffset);
    } else {
      _contentController.text = '$before$text$after';
      _contentController.selection = TextSelection.collapsed(offset: before.length + text.length);
    }
    // 重新请求焦点，确保键盘弹出且光标位置正确
    _contentFocusNode.requestFocus();
  }

  /// 插入粗体
  void _insertBold() {
    _insertText('粗体', wrapPrefix: '**', wrapSuffix: '**');
  }

  /// 插入斜体
  void _insertItalic() {
    _insertText('斜体', wrapPrefix: '*', wrapSuffix: '*');
  }

  /// 插入删除线
  void _insertStrikethrough() {
    _insertText('删除线', wrapPrefix: '~~', wrapSuffix: '~~');
  }

  /// 插入标题
  void _insertHeader(int level) {
    final prefix = '#' * level + ' ';
    _insertText('$prefix标题\n', wrapPrefix: null);
  }

  /// 插入引用
  void _insertQuote() {
    _insertText('> 引用内容\n', wrapPrefix: null);
  }

  /// 插入日期
  void _insertDate() {
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _insertText(date);
  }

  /// 插入时间
  void _insertTime() {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _insertText(time);
  }

  /// 插入无序列表
  void _insertUnorderedList() {
    _insertText('- 列表项\n', wrapPrefix: null);
  }

  /// 插入有序列表
  void _insertOrderedList() {
    _insertText('1. 列表项\n', wrapPrefix: null);
  }

  /// 插入行内代码
  void _insertInlineCode() {
    _insertText('code', wrapPrefix: '`', wrapSuffix: '`');
  }

  /// 插入代码块
  void _insertCodeBlock() {
    final currentText = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;
    final before = start < 0 ? currentText : currentText.substring(0, start);
    final after = start < 0 ? '' : currentText.substring(start);

    const codeBlock = '\n```\n// 代码块\n```\n';
    _contentController.text = '$before$codeBlock$after';
    _contentController.selection = TextSelection.collapsed(
      offset: before.length + codeBlock.length - 5,
    );
  }

  /// 插入链接
  void _insertLink() {
    _insertText('[链接文本](https://example.com)', wrapPrefix: null);
  }

  /// 插入分割线
  void _insertDivider() {
    _insertText('\n---\n', wrapPrefix: null);
  }

  /// 插入图片链接
  void _insertImageLink(String path, String fileName) {
    final imageMarkdown = '![$fileName]($path)\n';
    final currentText = _contentController.text;
    final selection = _contentController.selection;
    final start = selection.start;

    if (start >= 0) {
      final before = currentText.substring(0, start);
      final after = currentText.substring(start);
      _contentController.text = '$before\n$imageMarkdown$after';
      _contentController.selection = TextSelection.collapsed(
        offset: before.length + imageMarkdown.length + 1,
      );
    } else {
      _contentController.text = '$currentText\n$imageMarkdown';
    }
  }

  // ==================== 保存笔记 ====================

  /// 保存笔记
  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty && title.isEmpty) {
      ToastUtil.show(context, '笔记内容不能为空');
      return;
    }

    // 自动提取标签
    final tags = _extractTags('$title\n$content');

    final now = DateTime.now();

    if (!_isNewNote) {
      final updatedNote = widget.note!.copyWith(
        title: title.isEmpty ? widget.note!.title : title,
        content: content,
        contentType: 'markdown',
        tags: tags.isEmpty ? widget.note!.tags : tags,
        images: _images,
        updatedAt: now,
      );
      await context.read<AppProvider>().updateNote(updatedNote);
    } else {
      final noteId = now.millisecondsSinceEpoch.toString();
      final newNote = Note(
        id: noteId,
        title: title.isEmpty ? '无标题笔记' : title,
        content: content,
        contentType: 'markdown',
        tags: tags,
        images: _images,
        createdAt: _createdAt,
        updatedAt: now,
      );
      await context.read<AppProvider>().addNote(newNote);
    }

    if (!mounted) return;

    ToastUtil.show(context, _isNewNote ? '添加成功' : '保存成功');
    await context.read<AppProvider>().loadNotes();

    if (!mounted) return;
    Navigator.pop(context);
  }

  /// 从内容中提取标签
  List<String> _extractTags(String content) {
    final tags = <String>{};
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(content);

    for (final match in matches) {
      final tag = match.group(1);
      if (tag != null && tag.isNotEmpty) {
        tags.add(tag);
      }
    }

    return tags.toList();
  }
}
