import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/book_annotation.dart';
import '../../../utils/reader/book_annotation_dao.dart';

/// 阅读笔记面板 — 显示当前书籍的高亮和下划线批注
class ReadingNotesPanel extends StatefulWidget {
  final String bookId;
  final void Function(String cfi)? onNavigate;

  const ReadingNotesPanel({
    super.key,
    required this.bookId,
    this.onNavigate,
  });

  @override
  State<ReadingNotesPanel> createState() => _ReadingNotesPanelState();
}

class _ReadingNotesPanelState extends State<ReadingNotesPanel> {
  final _dao = BookAnnotationDao();
  List<BookAnnotation> _annotations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnnotations();
  }

  Future<void> _loadAnnotations() async {
    final list = await _dao.getAnnotations(widget.bookId);
    if (mounted) {
      setState(() {
        _annotations = list;
        _loading = false;
      });
    }
  }

  Future<void> _deleteAnnotation(BookAnnotation anno) async {
    await _dao.deleteById(anno.id!);
    await _loadAnnotations();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_annotations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_note, size: 40, color: colors.onSurfaceVariant.withAlpha(80)),
            const SizedBox(height: 12),
            Text('暂无笔记', style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(
              '选中文字后可添加高亮、下划线和笔记',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant.withAlpha(150)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '笔记 (${_annotations.length})',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
          ),
        ),
        ...List.generate(_annotations.length, (i) {
          final anno = _annotations[i];
          final annoColor = Color(int.parse('0x${anno.color}'));
          final isHighlight = anno.type == 'highlight';

          return ListTile(
            dense: true,
            leading: Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: annoColor.withAlpha(180),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(
              anno.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                decoration: isHighlight ? null : TextDecoration.underline,
                decorationColor: annoColor.withAlpha(120),
                decorationThickness: 2,
              ),
            ),
            subtitle: anno.chapter.isNotEmpty
                ? Text(anno.chapter,
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)
                : null,
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: colors.onSurfaceVariant),
              onSelected: (action) async {
                if (action == 'copy') {
                  await Clipboard.setData(ClipboardData(text: anno.content));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                    );
                  }
                } else if (action == 'delete') {
                  await _deleteAnnotation(anno);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'copy', child: Text('复制')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
            onTap: widget.onNavigate != null ? () => widget.onNavigate!(anno.cfi) : null,
          );
        }),
      ],
    );
  }
}
