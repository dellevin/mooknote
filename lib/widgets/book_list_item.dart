import 'dart:io';
import 'package:flutter/material.dart';
import '../models/data_models.dart';

/// 书籍列表项组件 - 网格布局设计
class BookListItem extends StatelessWidget {
  final Book book;

  const BookListItem({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, '/book-detail', arguments: book);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: _buildCover(),
          ),

          const SizedBox(height: 8),

          // 书名
          Text(
            book.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // 评分
          if (book.rating != null)
            Row(
              children: [
                const Icon(
                  Icons.star,
                  size: 12,
                  color: Color(0xFFFFB800),
                ),
                const SizedBox(width: 2),
                Text(
                  book.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                  ),
                ),
              ],
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
  
  /// 构建封面
  Widget _buildCover() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
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
        Icons.menu_book_outlined,
        size: 32,
        color: Color(0xFFCCCCCC),
      ),
    );
  }
}
