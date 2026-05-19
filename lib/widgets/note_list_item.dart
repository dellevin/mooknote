import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';
import '../utils/toast_util.dart';

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
    final isPlainText = note.contentType == 'plain_text';
    
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
            // 顶部：格式标记 + 时间 + 图片数
            Row(
              children: [
                // 格式标记
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                  ),
                  child: Text(
                    isPlainText ? 'TXT' : 'MD',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF999999),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 时间 - 使用缓存的格式化结果
                Text(
                  _formatDateCached(note.updatedAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF999999),
                  ),
                ),
                const Spacer(),
                // 图片数量（如果有图片）
                if (note.images.isNotEmpty) ...[
                  const Icon(
                    Icons.image_outlined,
                    size: 12,
                    color: Color(0xFF999999),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${note.images.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // 内容摘要（去除首尾空格）
            Text(
              note.summary.trim(),
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF1A1A1A),
                height: isPlainText ? 1.5 : 1.45,
              ),
              maxLines: isPlainText ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),

            // 图片预览区域（显示前4张图片）
            if (note.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: note.images.length > 4 ? 4 : note.images.length,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return _NoteImage(
                      imagePath: note.images[index],
                      index: index,
                      totalCount: note.images.length,
                      showMore: index == 3 && note.images.length > 4,
                    );
                  },
                ),
              ),
            ],

            // 底部标签
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: note.tags.take(3).map((tag) {
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
          ],
        ),
      ),
    );
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

/// 笔记图片组件 - 独立出来便于优化
class _NoteImage extends StatelessWidget {
  final String imagePath;
  final int index;
  final int totalCount;
  final bool showMore;

  const _NoteImage({
    required this.imagePath,
    required this.index,
    this.totalCount = 0,
    this.showMore = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: showMore
          ? Container(
              color: const Color(0xFFF5F5F5),
              child: Center(
                child: Text(
                  '+${totalCount - 4}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
            )
          : Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              cacheWidth: 104,
              cacheHeight: 104,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image,
                size: 20,
                color: Color(0xFFCCCCCC),
              ),
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
