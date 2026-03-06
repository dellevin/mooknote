import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 书籍列表项组件 - 极简主义设计
class BookListItem extends StatelessWidget {
  final Book book;
  
  const BookListItem({super.key, required this.book});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/book-detail', arguments: book);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            _buildCover(),
            
            const SizedBox(width: 16),
            
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 书名
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // 作者
                  if (book.authors.isNotEmpty)
                    Text(
                      book.authors.join(' / '),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 8),
                  
                  // 评分和状态
                  Row(
                    children: [
                      if (book.rating != null) ...[
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          book.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      _buildStatusTag(),
                    ],
                  ),
                  
                  // 类型
                  if (book.genres.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      book.genres.take(3).join(' · '),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // 操作按钮
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: const Color(0xFF666666),
                  onPressed: () {
                    Navigator.pushNamed(context, '/book-form', arguments: book);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                  onPressed: () => _showDeleteDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建封面
  Widget _buildCover() {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      child: book.coverPath != null && book.coverPath!.isNotEmpty
          ? Image.file(
              File(book.coverPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
            )
          : _buildCoverPlaceholder(),
    );
  }
  
  Widget _buildCoverPlaceholder() {
    return const Center(
      child: Icon(
        Icons.menu_book,
        size: 24,
        color: Color(0xFFCCCCCC),
      ),
    );
  }
  
  /// 构建状态标签
  Widget _buildStatusTag() {
    String label;
    Color color;
    switch (book.status) {
      case 'read':
        label = '已读';
        color = const Color(0xFF1A1A1A);
        break;
      case 'reading':
        label = '在读';
        color = const Color(0xFF666666);
        break;
      case 'want_to_read':
        label = '想读';
        color = const Color(0xFF999999);
        break;
      default:
        label = '未知';
        color = const Color(0xFFCCCCCC);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('确认删除'),
        content: Text('确定要删除"${book.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(book.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已删除')),
              );
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
