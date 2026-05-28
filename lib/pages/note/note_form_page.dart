import 'dart:io';
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
  int _charCount = 0;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    final text = note?.content ?? '';
    _contentController = TextEditingController(text: text);
    _charCount = text.length;
    _contentController.addListener(() {
      setState(() => _charCount = _contentController.text.length);
    });
    _createdAt = note?.createdAt ?? DateTime.now();
    _tags = note != null ? List.from(note.tags) : [];
    _images = note != null ? List.from(note.images) : [];
    _isEditing = note != null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: _showTitleDialog,
          child: _buildAppBarTitle(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _saveNote,
              style: TextButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                minimumSize: Size.zero,
              ),
              child: const Text('保存', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 主内容区域 — 图片网格固定在内容下方
          Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: Column(
              children: [
                // 顶部信息栏
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colors.outline, width: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 大日号
                          Text(
                            '${_createdAt.day}',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w200,
                              color: colors.onSurface.withValues(alpha: 0.75),
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 右边：年月 + 时分 纵向排列
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_createdAt.year}/${_createdAt.month.toString().padLeft(2, '0')} 周${_weekdays[_createdAt.weekday - 1]}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: colors.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${_createdAt.hour.toString().padLeft(2, '0')}:${_createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // 字数统计
                          Text(
                            '$_charCount 字',
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurface.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 标签行
                _buildTagRow(),

                // 编辑 / 预览区域
                Expanded(
                  child: _buildContentArea(),
                ),

                // 图片区域
                _buildImageRow(),
              ],
            ),
          ),

          // 底部浮动工具栏 — 独立于主内容，键盘弹起时单独上移
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingToolbar(),
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
        fontSize: 16,
      ),
      style: TextStyle(
        fontSize: 16,
        color: colors.onSurface,
        height: 1.6,
      ),
      decoration: InputDecoration(
        hintText: '使用 Markdown 格式书写...',
        hintStyle: TextStyle(
          fontSize: 16,
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

  /// 构建标签选择器
  /// 构建标签横向滚动行
  Widget _buildTagRow() {
    return Container(
      height: 28,
      margin: const EdgeInsets.only(top: 6, bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _tags.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          if (index < _tags.length) {
            return _buildTagChip(index);
          }
          return _buildAddTagButton();
        },
      ),
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
      onTap: _showAddTagDialog,
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

  /// 显示添加标签对话框
  Future<void> _showAddTagDialog() async {
    final controller = TextEditingController();

    // 从 tags 表获取已有标签（sync 模式下走服务端 API）
    final provider = context.read<AppProvider>();
    final tagRows = await provider.getTags('note_tag');
    final allTags = tagRows.map((t) => t['name'] as String).toSet();
    // 也从当前笔记内容中收集
    for (final note in provider.notes) {
      allTags.addAll(note.tags);
    }
    // 过滤掉已添加的标签
    final availableTags = allTags.where((tag) => !_tags.contains(tag)).toList()..sort();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = Theme.of(context).colorScheme;
        return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        title: Text(
          '添加标签',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 输入框
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(fontSize: 14, color: colors.onSurface),
                cursorColor: colors.primary,
                decoration: InputDecoration(
                  hintText: '输入新标签名称',
                  hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.primary, width: 1),
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 16, color: colors.onSurface.withValues(alpha: 0.35)),
                          onPressed: () => controller.clear(),
                        )
                      : null,
                ),
                onChanged: (_) => setDialogState(() {}),
                onSubmitted: (value) {
                  _addTag(value);
                  controller.clear();
                  setDialogState(() {});
                },
              ),

              // 已有标签列表
              if (availableTags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  '或选择已有标签',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availableTags.map((tag) {
                        return InkWell(
                          onTap: () {
                            _addTag(tag);
                            Navigator.pop(ctx);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colors.outline, width: 0.5),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              if (availableTags.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Center(
                    child: Text(
                      '暂无已有标签',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              _addTag(controller.text);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text('添加', style: TextStyle(fontSize: 14)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        ),
      );
      },
    );
  }

  /// 获取所有已有标签（从所有笔记中收集）
  /// 添加标签
  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() => _tags.add(trimmed));
    }
  }

  Widget _buildAppBarTitle() {
    final colors = Theme.of(context).colorScheme;
    final base = _isEditing ? '编辑笔记' : '新建笔记';
    final t = _titleController.text.trim();
    if (t.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(base),
          const SizedBox(width: 6),
          Icon(Icons.edit, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
        ],
      );
    }
    final display = t.length > 4 ? '${t.substring(0, 4)}…' : t;
    return Text('$base（$display）');
  }

  /// 长按标题弹出标题编辑窗口
  void _showTitleDialog() {
    final controller = TextEditingController(text: _titleController.text);
    showDialog(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '编辑标题',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 16, color: colors.onSurface),
          decoration: InputDecoration(
            hintText: '输入标题...',
            hintStyle: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.25)),
            filled: true,
            fillColor: colors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.outline, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.outline, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: colors.primary, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (value) {
            setState(() => _titleController.text = value.trim());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface.withValues(alpha: 0.6),
            ),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _titleController.text = controller.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('确定'),
          ),
        ],
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
      },
    );
  }

  /// 保存笔记
  Future<void> _saveNote() async {
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ToastUtil.show(context, '标题或内容不能为空');
      return;
    }

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

  /// 构建图片横向滚动行
  Widget _buildImageRow() {
    final colors = Theme.of(context).colorScheme;
    if (_images.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: colors.surface,
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildAddImageButton(),
          ],
        ),
      );
    }

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _images.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index < _images.length) {
            return _buildImageItem(index);
          }
          return _buildAddImageButton();
        },
      ),
    );
  }

  /// 添加图片按钮
  Widget _buildAddImageButton() {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colors.surfaceContainerHigh,
          border: Border.all(color: colors.outline, width: 0.5),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 24,
          color: colors.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// 构建图片项
  Widget _buildImageItem(int index) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _showImagePreview(index),
      onLongPress: () => _showDeleteImageDialog(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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

  /// 显示图片预览
  void _showImagePreview(int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withOpacity(0.9),
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
