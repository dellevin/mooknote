import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/data_models.dart';
import 'note_share_page.dart';

/// 笔记详情页
class NoteDetailPage extends StatefulWidget {
  final Note note;

  const NoteDetailPage({super.key, required this.note});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final note = context.watch<AppProvider>().notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          note.title.isNotEmpty
              ? note.title
              : _truncateContent(note.content),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 日期 + 字数
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${note.createdAt.day}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w200,
                        color: Color(0xFF333333),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')} 周${_weekdays[note.createdAt.weekday - 1]}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF777777)),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      '${note.content.length} 字',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA)),
                    ),
                  ],
                ),
              ),

              // 标签行
              if (note.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: _buildTagRow(note.tags),
                ),

              // 内容
              Expanded(
                child: Markdown(
                  data: note.content,
                  styleSheet: _buildMarkdownStyleSheet(),
                  padding: const EdgeInsets.all(16),
                  // ignore: deprecated_member_use
                  imageBuilder: (uri, title, alt) => _buildMarkdownImage(uri, note),
                ),
              ),

              // 图片行
              if (note.images.isNotEmpty) _buildImageRow(note.images),
            ],
          ),

          // 右下角悬浮按钮组
          Positioned(
            right: 16,
            bottom: 24,
            child: _buildFloatingActionButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildTagRow(List<String> tags) {
    return Container(
      height: 28,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tags[index],
              style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageRow(List<String> images) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE8E8E8), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () => _showImagePreview(images, index),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E8E8), width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.file(
                File(images[index]),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF5F5F5),
                  child: const Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFFCCCCCC)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.4),
      h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.4),
      h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.4),
      h4: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A), height: 1.4),
      p: const TextStyle(fontSize: 15, color: Color(0xFF333333), height: 1.8),
      code: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A), backgroundColor: Color(0xFFF5F5F5), fontFamily: 'monospace'),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(6),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: const TextStyle(fontSize: 15, color: Color(0xFF666666), fontStyle: FontStyle.italic, height: 1.8),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF999999), width: 4)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      listIndent: 24,
      a: const TextStyle(fontSize: 15, color: Color(0xFF4A90D9), decoration: TextDecoration.underline),
      tableHead: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
      tableBody: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
      tableBorder: TableBorder.all(color: const Color(0xFFE5E5E5), width: 0.5),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsDecoration: const BoxDecoration(color: Colors.white),
      tablePadding: const EdgeInsets.all(8),
      strong: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
      em: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF333333)),
      del: const TextStyle(decoration: TextDecoration.lineThrough, color: Color(0xFF999999)),
    );
  }

  Widget _buildMarkdownImage(Uri uri, Note note) {
    final path = uri.toString();
    if (path.isEmpty) return const SizedBox.shrink();

    for (final imgPath in note.images) {
      if (imgPath.contains(path) || path.contains(imgPath)) {
        if (File(imgPath).existsSync()) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(imgPath), fit: BoxFit.cover),
          );
        }
      }
    }

    if (path.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      );
    }

    return const SizedBox.shrink();
  }

  void _showImagePreview(List<String> images, int initialIndex) {
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
              child: Image.file(File(images[initialIndex]), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  /// 截取内容前N个字作为标题
  String _truncateContent(String content) {
    final cleaned = content
        .replaceAll(RegExp(r'^#+\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
        .replaceAll(RegExp(r'`(.+?)`'), r'$1')
        .replaceAll(RegExp(r'^\s*[-*+]\s', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*>\s', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), '')
        .trim();
    if (cleaned.isEmpty) return '无标题';
    return cleaned.length > 20 ? '${cleaned.substring(0, 20)}…' : cleaned;
  }

  void _navigateToEdit(BuildContext context) {
    final currentNote = context.read<AppProvider>().notes.firstWhere(
      (n) => n.id == widget.note.id,
      orElse: () => widget.note,
    );
    Navigator.pushNamed(context, '/note-form', arguments: currentNote).then((_) async {
      await context.read<AppProvider>().loadNotes();
    });
  }

  /// 右下角悬浮按钮组
  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFloatingButton(
          icon: Icons.edit_outlined,
          onPressed: () => _navigateToEdit(context),
          tooltip: '编辑',
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.delete_outline,
          onPressed: () => _showDeleteDialog(context),
          tooltip: '删除',
          backgroundColor: Colors.red,
        ),
        const SizedBox(height: 12),
        _buildFloatingButton(
          icon: Icons.share_outlined,
          onPressed: _shareNote,
          tooltip: '分享',
          backgroundColor: const Color(0xFF4CAF50),
        ),
      ],
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color backgroundColor = const Color(0xFF1A1A1A),
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, size: 18, color: Colors.white),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          tooltip: tooltip,
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除笔记'),
        content: const Text('删除后将移至回收站，确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AppProvider>().removeNote(widget.note.id);
              Navigator.pop(context);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _shareNote() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteSharePage(note: widget.note)),
    );
  }
}
