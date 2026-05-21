import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';

/// 笔记详情页 - 极简主义设计
class NoteDetailPage extends StatefulWidget {
  final Note note;

  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  @override
  Widget build(BuildContext context) {
    // 从 Provider 获取最新的笔记数据
    final note = context.watch<AppProvider>().notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          note.title.isNotEmpty ? note.title : '无标题',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _navigateToEdit(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 标签区域
          if (note.tags.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
                        ),
                        child: Text(
                          tag,
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
            ),

          // 内容区域 - Markdown 渲染
          Expanded(
            child: _buildMarkdownContent(note),
          ),
        ],
      ),
    );
  }

  /// 构建 Markdown 内容
  Widget _buildMarkdownContent(Note note) {
    return Markdown(
      data: note.content,
      styleSheet: _buildMarkdownStyleSheet(),
      padding: const EdgeInsets.all(16),
      // TODO: migrate to sizedImageBuilder when flutter_markdown is updated
      // ignore: deprecated_member_use
      imageBuilder: (uri, title, alt) => _buildMarkdownImage(uri),
    );
  }

  /// 构建 Markdown 样式表
  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      h1: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      h2: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      h3: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      h4: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
        height: 1.4,
      ),
      p: const TextStyle(
        fontSize: 15,
        color: Color(0xFF333333),
        height: 1.8,
      ),
      code: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A1A1A),
        backgroundColor: Color(0xFFF5F5F5),
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: const TextStyle(
        fontSize: 15,
        color: Color(0xFF666666),
        fontStyle: FontStyle.italic,
        height: 1.8,
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF999999), width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: const TextStyle(
        fontSize: 15,
        color: Color(0xFF1A1A1A),
      ),
      listIndent: 24,
      a: const TextStyle(
        fontSize: 15,
        color: Color(0xFF4A90D9),
        decoration: TextDecoration.underline,
      ),
      tableHead: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      tableBody: const TextStyle(
        fontSize: 14,
        color: Color(0xFF333333),
      ),
      tableBorder: TableBorder.all(
        color: const Color(0xFFE5E5E5),
        width: 0.5,
      ),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsDecoration: const BoxDecoration(
        color: Colors.white,
      ),
      tablePadding: const EdgeInsets.all(8),
      strong: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1A1A1A),
      ),
      em: const TextStyle(
        fontStyle: FontStyle.italic,
        color: Color(0xFF333333),
      ),
      del: const TextStyle(
        decoration: TextDecoration.lineThrough,
        color: Color(0xFF999999),
      ),
    );
  }

  /// 构建 Markdown 中的图片
  Widget _buildMarkdownImage(Uri uri) {
    // 检查是否是本地图片路径
    final path = uri.toString();
    if (path.isEmpty) return const SizedBox.shrink();

    // 尝试从笔记图片列表中查找
    final noteImages = widget.note.images;
    String? matchedPath;
    for (final imgPath in noteImages) {
      if (imgPath.contains(path) || path.contains(imgPath)) {
        matchedPath = imgPath;
        break;
      }
    }

    if (matchedPath != null && File(matchedPath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(matchedPath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorWidget();
          },
        ),
      );
    }

    // 如果是网络图片
    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          path,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildImageErrorWidget();
          },
        ),
      );
    }

    return _buildImageErrorWidget();
  }

  /// 构建图片错误状态
  Widget _buildImageErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFF999999)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '图片加载失败',
              style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 跳转到编辑页面
  void _navigateToEdit(BuildContext context) {
    // 从 Provider 获取最新的笔记数据，确保图片等字段是最新的
    final currentNote = context.read<AppProvider>().notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );
    Navigator.pushNamed(context, '/note-form', arguments: currentNote).then((_) async {
      // 返回时刷新笔记列表
      await context.read<AppProvider>().loadNotes();
    });
  }

  /// 显示图片预览
  void _showImagePreview(BuildContext context, List<String> images, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                File(images[initialIndex]),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
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
              await context.read<AppProvider>().removeNote(widget.note.id);
              // 刷新笔记列表
              await context.read<AppProvider>().loadNotes();
              if (!mounted) return;
              Navigator.pop(context);
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
