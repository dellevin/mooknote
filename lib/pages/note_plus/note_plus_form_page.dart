import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import '../../providers/note_plus_provider.dart';
import '../../utils/toast_util.dart';

/// Note Plus 编辑页
class NotePlusFormPage extends StatefulWidget {
  final String documentId;

  const NotePlusFormPage({super.key, required this.documentId});

  @override
  State<NotePlusFormPage> createState() => _NotePlusFormPageState();
}

class _NotePlusFormPageState extends State<NotePlusFormPage> {
  final _titleController = TextEditingController();
  final _titleFocus = FocusNode();
  final _scrollController = ScrollController();
  final _editorFocus = FocusNode();
  quill.QuillController? _controller;
  bool _isInitialized = false;
  Timer? _autoSaveTimer;
  int _charCount = 0;

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _titleFocus.dispose();
    _scrollController.dispose();
    _editorFocus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ─── 初始化 ─────────────────────────────────────

  void _initDocument(NotePlusProvider provider) {
    if (_isInitialized) return;
    _isInitialized = true;

    provider.loadDocumentById(widget.documentId).then((_) {
      if (!mounted || provider.currentDocument == null) return;

      _titleController.text = provider.currentDocument!.title;

      quill.Document doc;
      final raw = provider.currentDocument!.blocksJson;
      if (raw != null && raw.isNotEmpty && raw.startsWith('[')) {
        try {
          final parsed = jsonDecode(raw) as List;
          if (parsed.isNotEmpty &&
              parsed.first is Map &&
              (parsed.first as Map).containsKey('insert')) {
            doc = quill.Document.fromJson(parsed);
          } else {
            doc = quill.Document();
          }
        } catch (_) {
          doc = quill.Document();
        }
      } else {
        doc = quill.Document();
      }

      setState(() {
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        _controller!.addListener(_onDocChanged);
        _charCount = _controller!.document.length - 1; // 去掉末尾 \n
      });
    });
  }

  // ─── 文档变化监听 ─────────────────────────────────

  void _onDocChanged() {
    if (_controller == null) return;
    final newCount = _controller!.document.length - 1;
    if (newCount != _charCount) {
      setState(() => _charCount = newCount);
    }
    // 自动保存（防抖 2 秒）
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _autoSave();
    });
  }

  void _autoSave() {
    final provider = context.read<NotePlusProvider>();
    if (_controller == null) return;
    provider.setTitle(_titleController.text);
    final deltaJson = jsonEncode(_controller!.document.toDelta().toJson());
    provider.saveDocument(deltaJson: deltaJson);
  }

  void _save(NotePlusProvider provider) async {
    _autoSaveTimer?.cancel();
    if (_controller == null) return;
    provider.setTitle(_titleController.text);
    final deltaJson = jsonEncode(_controller!.document.toDelta().toJson());
    await provider.saveDocument(deltaJson: deltaJson);
    if (mounted) ToastUtil.show(context, '已保存');
  }

  // ─── 构建 ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Consumer<NotePlusProvider>(
      builder: (context, provider, _) {
        _initDocument(provider);

        return PopScope(
          canPop: !provider.isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && provider.isDirty) {
              _showSaveDialog(provider);
            } else {
              _autoSave(); // 退出时自动保存
            }
          },
          child: Scaffold(
            backgroundColor: colors.surface,
            appBar: _buildAppBar(provider, colors),
            body: _controller == null
                ? const Center(child: CircularProgressIndicator())
                : GestureDetector(
                    // 点击空白区域聚焦编辑器
                    onTap: () => _editorFocus.requestFocus(),
                    behavior: HitTestBehavior.translucent,
                    child: Column(
                      children: [
                        // 标题区
                        _buildTitleArea(colors),
                        // 分隔线
                        Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.3)),
                        // 编辑器
                        Expanded(child: _buildEditor(colors)),
                        // 工具栏
                        _buildToolbar(colors),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ─── AppBar ─────────────────────────────────────

  PreferredSizeWidget _buildAppBar(NotePlusProvider provider, ColorScheme colors) {
    return AppBar(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 22),
        onPressed: () {
          _autoSave();
          Navigator.pop(context);
        },
      ),
      title: Text(
        '$_charCount 字',
        style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.35)),
      ),
      centerTitle: true,
      actions: [
        // 未保存指示
        if (provider.isDirty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.undo, size: 20),
          onPressed: _controller != null ? () => _controller!.undo() : null,
          tooltip: '撤销',
        ),
        IconButton(
          icon: const Icon(Icons.redo, size: 20),
          onPressed: _controller != null ? () => _controller!.redo() : null,
          tooltip: '重做',
        ),
        IconButton(
          icon: Icon(Icons.check, size: 22, color: colors.primary),
          onPressed: () => _save(provider),
          tooltip: '保存',
        ),
      ],
    );
  }

  // ─── 标题区 ─────────────────────────────────────

  Widget _buildTitleArea(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TextField(
        controller: _titleController,
        focusNode: _titleFocus,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
          height: 1.3,
        ),
        decoration: InputDecoration(
          hintText: '输入标题...',
          hintStyle: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.15),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        onChanged: (_) => context.read<NotePlusProvider>().setTitle(_titleController.text),
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _editorFocus.requestFocus(),
      ),
    );
  }

  // ─── 编辑器 ─────────────────────────────────────

  Widget _buildEditor(ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextSelectionTheme(
        data: TextSelectionThemeData(
          selectionColor: colors.primary.withValues(alpha: 0.12),
          selectionHandleColor: colors.primary,
          cursorColor: colors.primary,
        ),
        child: quill.QuillEditor.basic(
          controller: _controller!,
          focusNode: _editorFocus,
          scrollController: _scrollController,
          config: const quill.QuillEditorConfig(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            autoFocus: false,
            expands: true,
          ),
        ),
      ),
    );
  }

  // ─── 工具栏 ─────────────────────────────────────

  Widget _buildToolbar(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: quill.QuillSimpleToolbar(
            controller: _controller!,
            config: quill.QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              color: Colors.transparent,
              toolbarSize: 30,
              buttonOptions: const quill.QuillSimpleToolbarButtonOptions(
                base: quill.QuillToolbarBaseButtonOptions(iconSize: 17),
              ),
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: true,
              showHeaderStyle: false,
              showListBullets: true,
              showListNumbers: true,
              showListCheck: true,
              showCodeBlock: true,
              showQuote: true,
              showInlineCode: true,
              showUndo: false,
              showRedo: false,
              showLink: false,
              showSearchButton: false,
              showFontSize: false,
              showFontFamily: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: false,
              showAlignmentButtons: false,
              showDirection: false,
              showIndent: false,
              showSubscript: false,
              showSuperscript: false,
              customButtons: [
                quill.QuillToolbarCustomButtonOptions(
                  icon: const Icon(Icons.text_fields, size: 17, color: Color(0xFF555555)),
                  onPressed: () => _showHeaderPicker(colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 标题选择 ─────────────────────────────────

  void _showHeaderPicker(ColorScheme colors) {
    final current = _controller?.getSelectionStyle().attributes ?? {};
    final currentHeader = current['header']?.value;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示条
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _headerOption('正文', null, currentHeader == null, colors),
              _headerOption('标题 1', 1, currentHeader == 1, colors),
              _headerOption('标题 2', 2, currentHeader == 2, colors),
              _headerOption('标题 3', 3, currentHeader == 3, colors),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerOption(String label, int? level, bool isActive, ColorScheme colors) {
    final sizes = {null: 15.0, 1: 22.0, 2: 18.0, 3: 15.0};
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (_controller == null) return;
        if (level == null) {
          _controller!.formatSelection(quill.Attribute.header);
        } else {
          _controller!.formatSelection(quill.Attribute.clone(quill.Attribute.header, level));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(
                fontSize: sizes[level] ?? 15,
                fontWeight: level == null ? FontWeight.w400 : FontWeight.w600,
                color: isActive ? colors.primary : colors.onSurface,
              )),
            ),
            if (isActive)
              Icon(Icons.check, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }

  // ─── 保存对话框 ─────────────────────────────────

  void _showSaveDialog(NotePlusProvider provider) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('未保存的更改',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        content: Text('是否保存当前文档？',
            style: TextStyle(fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: Text('不保存', style: TextStyle(color: colors.error)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消',
                style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6))),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _save(provider); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary, foregroundColor: colors.onPrimary,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
