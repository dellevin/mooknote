import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 笔记列表项组件 - 极简主义设计
class NoteListItem extends StatelessWidget {
  final Note note;

  const NoteListItem({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/note-detail', arguments: note);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 内容摘要
            Text(
              note.summary,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // 底部信息：标签 + 时间 + 操作
            Row(
              children: [
                // 标签
                if (note.tags.isNotEmpty) ...[
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: note.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  ),
                ] else
                  const Spacer(),
                
                // 时间
                Text(
                  _formatDate(note.updatedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}
