import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/app_back_button.dart';
import '../../models/data_models.dart';
import '../../utils/image_saver.dart';
import '../../widgets/image_rename_dialog.dart';
import 'note_share_page.dart';
import '../../widgets/app_overlay.dart';
import '../../l10n/app_strings.dart';

/// 笔记详情页
class NoteDetailPage extends StatefulWidget {
  final Note note;
  final bool embedded;

  const NoteDetailPage({super.key, required this.note, this.embedded = false});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  List<String> get _weekdays => [
    '周一'.tr, '周二'.tr, '周三'.tr, '周四'.tr, '周五'.tr, '周六'.tr, '周日'.tr,
  ];

  // ─── 编辑模式 ───
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.note.title);
    _contentCtrl = TextEditingController(text: widget.note.content);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 只订阅当前这一条：无关的 provider 变更不再重建整个详情页
    final note = context.select<AppProvider, Note?>(
      (p) => p.notes.where((n) => n.id == widget.note.id).firstOrNull,
    ) ?? widget.note;
    final contentAlign =
        context.select<AppProvider, int>((p) => p.noteContentAlign);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        leading: widget.embedded ? const AppBackButton() : null,
        titleSpacing: 0,
        title: note.title.isNotEmpty
            ? Text(note.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))
            : null,
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
                          '{y}/{m} {w}'.trf({
                            'y': note.createdAt.year,
                            'm': note.createdAt.month.toString().padLeft(2, '0'),
                            'w': _weekdays[note.createdAt.weekday - 1],
                          }),
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
                      '{n} 字'.trf({'n': note.content.length}),
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
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Markdown 正文
                    Markdown(
                      data: note.content,
                      styleSheet: _buildMarkdownStyleSheet(colors, contentAlign),
                      builders: contentAlign == 1
                          ? {'p': _DistributedParagraphBuilder(colors)}
                          : const {},
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // ignore: deprecated_member_use
                      imageBuilder: (uri, title, alt) => _buildMarkdownImage(uri, note),
                    ),
                    // 附加图片（不在 markdown 中的独立图片）
                    if (note.images.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInlineImageGrid(note.images),
                    ],
                  ],
                ),
              ),
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

  /// 内嵌图片网格（移动端正文后展示）
  Widget _buildInlineImageGrid(List<String> images) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: images.map((path) {
        return GestureDetector(
          onTap: () => _showImagePreview(images, images.indexOf(path)),
          child: Container(
            width: (MediaQuery.of(context).size.width - 48) / 3,
            height: (MediaQuery.of(context).size.width - 48) / 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: FadeInLocalImage(
              path: path,
              fit: BoxFit.cover,
              errorWidget: Container(
                color: colors.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.25)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(
      ColorScheme colors, int contentAlign) {
    return MarkdownStyleSheet(
      // spaceBetween 会被 flutter_markdown_plus 映射为 TextAlign.justify
      textAlign: switch (contentAlign) {
        1 => WrapAlignment.spaceBetween,
        2 => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      h1: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      h2: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      h4: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.onSurface, height: 1.4),
      p: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75), height: 1.8),
      code: TextStyle(fontSize: 12, color: colors.onSurface, backgroundColor: colors.surfaceContainerHighest, fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic, height: 1.8),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.onSurface.withValues(alpha: 0.4), width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: TextStyle(fontSize: 13, color: colors.onSurface),
      listIndent: 24,
      a: const TextStyle(fontSize: 13, color: Color(0xFF4A90D9), decoration: TextDecoration.underline),
      tableHead: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.onSurface),
      tableBody: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75)),
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
    appDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        onLongPress: () => ImageSaver.showSaveFromFileSheet(
          images[initialIndex],
          context: context,
          extraAction: (
            icon: Icons.edit_outlined,
            label: '重命名'.tr,
            onTap: () => ImageRenameDialog.show(context, images[initialIndex]),
          ),
        ),
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
          tooltip: '编辑'.tr,
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除'.tr,
          backgroundColor: colors.error,
          foregroundColor: colors.onError,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.share_outlined,
          onPressed: _shareNote,
          tooltip: '分享'.tr,
          backgroundColor: const Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),
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
    appDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除笔记'.tr),
        content: Text('删除后将移至回收站，确定要删除吗？'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'.tr),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().removeNote(widget.note.id);
              Navigator.pop(context);
            },
            child: Text('删除'.tr, style: TextStyle(color: errorColor)),
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

/// 分散对齐段落：在正文末尾添加一个占满行宽、零高度的占位符，
/// 让可见的末行不再被文本引擎视为段落最后一行，从而也参与 justify。
class _DistributedParagraphBuilder extends MarkdownElementBuilder {
  _DistributedParagraphBuilder(this.colors);

  final ColorScheme colors;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    // 图片仍交给 Markdown 默认构建器，避免改变图片展示与点击行为。
    if (_containsImage(element)) return null;

    return LayoutBuilder(
      builder: (_, constraints) => RichText(
        textAlign: TextAlign.justify,
        text: TextSpan(
          style: preferredStyle,
          children: [
            for (final child in element.children ?? const <md.Node>[])
              _buildSpan(child),
            WidgetSpan(
              child: SizedBox(width: constraints.maxWidth, height: 0.1),
            ),
          ],
        ),
      ),
    );
  }

  bool _containsImage(md.Node node) {
    if (node is! md.Element) return false;
    if (node.tag == 'img') return true;
    return node.children?.any(_containsImage) ?? false;
  }

  InlineSpan _buildSpan(md.Node node) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return TextSpan(text: node.textContent);

    if (node.tag == 'br') return const TextSpan(text: '\n');

    final style = switch (node.tag) {
      'strong' || 'b' => const TextStyle(fontWeight: FontWeight.w600),
      'em' || 'i' => const TextStyle(fontStyle: FontStyle.italic),
      'del' || 's' => TextStyle(
          decoration: TextDecoration.lineThrough,
          color: colors.onSurface.withValues(alpha: 0.4),
        ),
      'code' => TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest,
        ),
      'a' => const TextStyle(
          color: Color(0xFF4A90D9),
          decoration: TextDecoration.underline,
        ),
      _ => null,
    };

    return TextSpan(
      style: style,
      children: [
        for (final child in node.children ?? const <md.Node>[])
          _buildSpan(child),
      ],
    );
  }
}
