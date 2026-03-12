import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/data_models.dart';
import '../providers/app_provider.dart';
import '../utils/toast_util.dart';

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
      onLongPress: () => _showDeleteDialog(context),
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

          // 评分 - 5星显示
          if (book.rating != null)
            _buildStarRating(book.rating!)
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

  /// 构建5星评分显示（评分范围1-10，每星2分）
  Widget _buildStarRating(double rating) {
    // 将10分制转换为5星制
    final starValue = rating / 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 5个星星
        ...List.generate(5, (index) {
          final starIndex = index + 1;
          IconData iconData;

          if (starValue >= starIndex) {
            // 满星
            iconData = Icons.star;
          } else if (starValue >= starIndex - 0.5) {
            // 半星
            iconData = Icons.star_half;
          } else {
            // 空星
            iconData = Icons.star_border;
          }

          return Icon(
            iconData,
            size: 12,
            color: const Color(0xFFFFB800),
          );
        }),
        const SizedBox(width: 4),
        // 评分数字
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
          ),
        ),
      ],
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
        content: Text('确定要删除《${book.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(book.id);
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
