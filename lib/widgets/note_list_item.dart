import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';
import 'fade_in_local_image.dart';

/// 笔记列表项组件 - 极简主义设计
class NoteListItem extends StatelessWidget {
  final Note note;

  const NoteListItem({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _NoteListItemContent(note: note),
    );
  }
}

class _NoteListItemContent extends StatelessWidget {
  final Note note;

  const _NoteListItemContent({required this.note});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/note-detail', arguments: note).then((_) async {
          await context.read<AppProvider>().loadNotes();
        });
      },
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _formatDate(note.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: colors.outlineVariant, width: 0.5),
                  ),
                  child: Text(
                    'MD',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (note.title.isNotEmpty) ...[
              Text(
                note.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],

            if (_collapseBlankLines(_cleanMarkdown(note.content).trim()).isNotEmpty)
              Text(
                _collapseBlankLines(_cleanMarkdown(note.content).trim()),
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurface.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: note.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: colors.outlineVariant, width: 0.5),
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

            if (note.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildImagePreviewRow(colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewRow(ColorScheme colors) {
    final images = note.images;
    final count = images.length.clamp(0, 3);
    return Row(
      children: [
        for (int i = 0; i < count; i++)
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.outlineVariant, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: FadeInLocalImage(
              path: images[i],
              fit: BoxFit.cover,
              errorWidget: Container(
                color: colors.surfaceContainerHighest,
              ),
            ),
          ),
        if (images.length > 3)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '+${images.length - 3}',
                style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
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

  void _showDeleteDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        content: Text(
          '确定要删除这条笔记吗？删除后可在回收站恢复。',
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
            onPressed: () async {
              await context.read<AppProvider>().removeNote(note.id);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
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
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.isNegative) {
    // 服务端时间比本地快（时钟偏差），显示绝对日期
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
