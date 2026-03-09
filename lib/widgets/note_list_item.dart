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
        Navigator.pushNamed(context, '/note-detail', arguments: note);
      },
      onLongPress: () => _showDeleteDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部：格式标记 + 时间
            Row(
              children: [
                // 格式标记
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: Text(
                    isPlainText ? 'TXT' : 'MD',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
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
                    size: 11,
                    color: Color(0xFF999999),
                  ),
                  const SizedBox(width: 2),
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
                height: isPlainText ? 1.6 : 1.5,
              ),
              maxLines: isPlainText ? 4 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            // 图片预览区域（显示前2张图片）
            if (note.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: note.images.length > 2 ? 2 : note.images.length,
                  physics: const NeverScrollableScrollPhysics(), // 禁用滚动，提高性能
                  itemBuilder: (context, index) {
                    return _NoteImage(
                      imagePath: note.images[index],
                      index: index,
                    );
                  },
                ),
              ),
            ],
            
            // 底部标签
            if (note.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: note.tags.take(3).map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
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
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: const Text('确定要删除这条笔记吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeNote(note.id);
              Navigator.pop(context);
              ToastUtil.show(context, '已删除');
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 笔记图片组件 - 独立出来便于优化
class _NoteImage extends StatelessWidget {
  final String imagePath;
  final int index;

  const _NoteImage({
    required this.imagePath,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      margin: EdgeInsets.only(right: index < 1 ? 8 : 0),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        // 使用低内存缓存
        cacheWidth: 120,
        cacheHeight: 120,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.broken_image,
          size: 24,
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
