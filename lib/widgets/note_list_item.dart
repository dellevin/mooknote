import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import 'fade_in_local_image.dart';

/// 笔记列表项组件 - 卡片式设计，内容展示在卡片内
class NoteListItem extends StatelessWidget {
  final Note note;
  final bool selected;
  final VoidCallback? onTap;

  const NoteListItem({super.key, required this.note, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _NoteListItemContent(note: note, selected: selected, onTap: onTap),
    );
  }
}

class _NoteListItemContent extends StatelessWidget {
  final Note note;
  final bool selected;
  final VoidCallback? onTap;

  const _NoteListItemContent({required this.note, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final previewText = _getPreviewText(note);

    return GestureDetector(
      onTap: onTap ?? () async {
        final provider = context.read<AppProvider>();
        await Navigator.pushNamed(context, '/note-detail', arguments: note);
        await provider.loadNotes();
      },
      onLongPress: () => _showActions(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: selected ? Border.all(color: colors.primary, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题行（带置顶图标 + 时间）
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (note.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.push_pin, size: 14, color: colors.primary),
                  ),
                Expanded(
                  child: Text(
                    note.title.isNotEmpty ? note.title : previewText.isNotEmpty ? previewText : '(无内容)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDate(note.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),

            // 内容预览
            if (previewText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                previewText,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.5),
                  height: 1.5,
                ),
                maxLines: note.title.isNotEmpty ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // 图片预览
            if (note.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: note.images.length > 4 ? 4 : note.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    if (index == 3 && note.images.length > 4) {
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: colors.surfaceContainerHighest,
                        ),
                        child: Center(
                          child: Text(
                            '+${note.images.length - 3}',
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
                          ),
                        ),
                      );
                    }
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.outlineVariant, width: 0.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FadeInLocalImage(
                        path: note.images[index],
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: colors.surfaceContainerHighest,
                          child: Icon(Icons.broken_image_outlined, size: 16, color: colors.onSurface.withValues(alpha: 0.25)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // 标签
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: note.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPreviewText(Note note) {
    return _collapseBlankLines(_cleanMarkdown(note.content).trim());
  }

  void _showActions(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(
                    note.isPinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                    size: 20,
                    color: colors.onSurface.withValues(alpha: 0.6))),
            title: Text(note.isPinned ? '取消置顶' : '置顶',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.onSurface)),
            subtitle: Text(
                note.isPinned ? '取消置顶后按时间排序' : '置顶后始终显示在最前',
                style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              context
                  .read<AppProvider>()
                  .toggleNotePin(note.id, !note.isPinned);
            },
          ),
          Divider(height: 0.5, color: colors.outlineVariant),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.delete_outline,
                    size: 20, color: colors.error)),
            title: Text('删除',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.error)),
            subtitle: Text('删除后可在回收站恢复',
                style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.4))),
            trailing: Icon(Icons.chevron_right,
                color: colors.onSurface.withValues(alpha: 0.25)),
            onTap: () {
              Navigator.pop(ctx);
              _showDeleteConfirm(context);
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text('确认删除',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.onSurface)),
        content: Text('确定要删除这条笔记吗？删除后可在回收站恢复。',
            style: TextStyle(
                fontSize: 14,
                color: colors.onSurface.withValues(alpha: 0.6),
                height: 1.5)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(
                      color: colors.onSurface.withValues(alpha: 0.6)))),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppProvider>().removeNote(note.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8)),
            child: const Text('删除'),
          ),
        ],
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        .replaceAll(RegExp(r'^\s*[-*+]\s', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*>\s', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '')
        .trim();
  }

  String _collapseBlankLines(String text) {
    return text.replaceAll(RegExp(r'\n\s*\n+'), '\n');
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.isNegative) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  if (difference.inDays == 0) {
    if (difference.inHours == 0) {
      if (difference.inMinutes == 0) {
        return '刚刚';
      }
      return '${difference.inMinutes}分钟前';
    }
    return '${difference.inHours}小时前';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}天前';
  } else {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
