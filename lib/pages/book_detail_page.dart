import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/data_models.dart';

/// 书籍详情页 - 极简主义设计
class BookDetailPage extends StatefulWidget {
  final Book book;
  
  const BookDetailPage({super.key, required this.book});
  
  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 顶部封面区域
          _buildSliverAppBar(),
          
          // 内容区域
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本信息
                _buildBasicInfo(),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 作者信息
                _buildAuthorsSection(),
                
                // 出版社
                if (widget.book.publisher != null && widget.book.publisher!.isNotEmpty)
                  _buildPublisherSection(),
                
                // 类型
                if (widget.book.genres.isNotEmpty)
                  _buildGenresSection(),
                
                const Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
                
                // 简介
                if (widget.book.summary != null && widget.book.summary!.isNotEmpty)
                  _buildSummarySection(),
                
                // 别名
                if (widget.book.alternateTitles.isNotEmpty)
                  _buildAlternateTitlesSection(),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
      
      // 底部操作栏
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  
  /// 构建顶部 AppBar
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: _buildCoverSection(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _navigateToEdit(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
  
  /// 构建封面区域
  Widget _buildCoverSection() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      child: widget.book.coverPath != null && widget.book.coverPath!.isNotEmpty
          ? Image.file(
              File(widget.book.coverPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
            )
          : _buildCoverPlaceholder(),
    );
  }
  
  Widget _buildCoverPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book,
            size: 64,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 16),
          Text(
            '暂无封面',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建基本信息
  Widget _buildBasicInfo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 书名
          Text(
            widget.book.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 评分和状态
          Row(
            children: [
              if (widget.book.rating != null) ...[
                const Icon(
                  Icons.star,
                  size: 20,
                  color: Color(0xFF1A1A1A),
                ),
                const SizedBox(width: 4),
                Text(
                  widget.book.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _buildStatusTag(),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 时间信息
          Text(
            '添加于 ${_formatDate(widget.book.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建状态标签
  Widget _buildStatusTag() {
    String label;
    Color color;
    switch (widget.book.status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  /// 构建作者区域
  Widget _buildAuthorsSection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '作者',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.book.authors.map((author) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  author,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建出版社区域
  Widget _buildPublisherSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '出版社',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.book.publisher!,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建类型区域
  Widget _buildGenresSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '类型',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.book.genres.map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建简介区域
  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '简介',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.book.summary!,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF1A1A1A),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建别名区域
  Widget _buildAlternateTitlesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '别名',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.book.alternateTitles.map((title) {
              return Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF666666),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  /// 构建底部操作栏
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5E5), width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _navigateToEdit(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A1A1A),
                    side: const BorderSide(color: Color(0xFF1A1A1A)),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('编辑'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showDeleteDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('删除'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    Navigator.pushNamed(context, '/book-form', arguments: widget.book).then((_) {
      context.read<AppProvider>().loadBooks();
    });
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
        content: Text('确定要删除"${widget.book.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () async {
              await context.read<AppProvider>().removeBook(widget.book.id);
              if (!mounted) return;
              Navigator.pop(context);
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
