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
    // 使用 RepaintBoundary 减少重绘
    return RepaintBoundary(
      child: _NoteListItemContent(note: note),
    );
  }
}

/// 笔记列表项内容 - 分离出来便于优化
class _NoteListItemContent extends StatelessWidget {
  final Note note;

  const _NoteListItemContent({required this.note});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/note-detail', arguments: note).then((_) async {
          // 返回时刷新笔记列表
          await context.read<AppProvider>().loadNotes();
        });
      },
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部：时间 + MD标记
            Row(
              children: [
                // 时间
                Text(
                  _formatDateCached(note.updatedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
                const SizedBox(width: 8),
                // MD标记
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                  ),
                  child: const Text(
                    'MD',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 标题
            if (note.title.isNotEmpty) ...[
              Text(
                note.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],

            // 内容摘要（去除Markdown标记），内容为空则不显示
            if (_collapseBlankLines(_cleanMarkdown(note.content).trim()).isNotEmpty)
              Text(
                _collapseBlankLines(_cleanMarkdown(note.content).trim()),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            // 底部标签
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: note.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF666666),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            // 图片预览
            if (note.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildImagePreviewRow(),
            ],
          ],
        ),
      ),
    );
  }

  /// 图片预览行
  Widget _buildImagePreviewRow() {
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
              border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: FadeInLocalImage(
              path: images[i],
              fit: BoxFit.cover,
              errorWidget: Container(
                color: const Color(0xFFF5F5F5),
              ),
            ),
          ),
        if (images.length > 3)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '+${images.length - 3}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999), fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
    );
  }

  /// 清理 Markdown 标记，提取纯文本
  String _cleanMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '') // 标题
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1') // 粗体
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1') // 斜体
        .replaceAll(RegExp(r'`(.+?)`'), r'$1') // 行内代码
        .replaceAll(RegExp(r'^\s*[-*+]\s', multiLine: true), '') // 列表
        .replaceAll(RegExp(r'^\s*>\s', multiLine: true), '') // 引用
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1') // 链接
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '') // 图片
        .trim();
  }

  /// 合并连续空行为单行
  String _collapseBlankLines(String text) {
    return text.replaceAll(RegExp(r'\n\s*\n+'), '\n');
  }

  /// 显示删除确认对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          '确认删除',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '确定要删除这条笔记吗？删除后可在回收站恢复。',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF666666),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
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

// 日期格式化缓存
final Map<DateTime, String> _dateFormatCache = {};

/// 格式化日期（带缓存）
String _formatDateCached(DateTime date) {
  // 使用日期部分作为缓存键（忽略时分秒）
  final cacheKey = DateTime(date.year, date.month, date.day);
  
  if (_dateFormatCache.containsKey(cacheKey)) {
    return _dateFormatCache[cacheKey]!;
  }
  
  final result = _formatDate(date);
  _dateFormatCache[cacheKey] = result;
  return result;
}

/// 格式化日期
String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);
  
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
