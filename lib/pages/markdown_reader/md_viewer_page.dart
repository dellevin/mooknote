import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Markdown 文件查看页面
class MdViewerPage extends StatefulWidget {
  final String filePath;

  const MdViewerPage({super.key, required this.filePath});

  @override
  State<MdViewerPage> createState() => _MdViewerPageState();
}

class _MdViewerPageState extends State<MdViewerPage> {
  String _content = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  /// 加载 Markdown 文件内容
  Future<void> _loadFile() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _error = '文件不存在';
          _isLoading = false;
        });
        return;
      }

      final content = await file.readAsString();
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '读取文件失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fileName = widget.filePath.split('/').last;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(ColorScheme colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (_error != null) {
      return _buildErrorState(colors);
    }

    return Markdown(
      data: _content,
      padding: const EdgeInsets.all(20),
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
          height: 1.4,
        ),
        h2: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
          height: 1.4,
        ),
        h3: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
          height: 1.4,
        ),
        p: TextStyle(
          fontSize: 15,
          color: colors.onSurface,
          height: 1.8,
        ),
        code: TextStyle(
          fontSize: 13,
          color: colors.onSurface,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: TextStyle(
          fontSize: 15,
          color: colors.onSurface.withValues(alpha: 0.6),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
              left: BorderSide(
                  color: colors.onSurface.withValues(alpha: 0.4), width: 4)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
        listBullet: TextStyle(
          fontSize: 15,
          color: colors.onSurface,
        ),
        listIndent: 24,
        a: const TextStyle(
          fontSize: 15,
          color: Color(0xFF4A90D9),
          decoration: TextDecoration.underline,
        ),
      ),
      // ignore: deprecated_member_use
      imageBuilder: (uri, title, alt) => _buildImage(colors, uri.toString(), alt),
    );
  }

  /// 构建图片显示
  Widget _buildImage(ColorScheme colors, String uri, String? alt) {
    if (uri.isEmpty) return const SizedBox.shrink();

    // 处理相对路径：基于 md 文件所在目录
    String imagePath = uri;
    if (!uri.startsWith('/')) {
      final baseDir = File(widget.filePath).parent.path;
      imagePath = '$baseDir/$uri';
    }

    final file = File(imagePath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.broken_image_outlined,
                    size: 20, color: colors.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alt ?? '图片加载失败',
                    style:
                        TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(ColorScheme colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48, color: colors.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}
