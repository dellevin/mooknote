import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
    final fileName = widget.filePath.split('/').last;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A)));
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Markdown(
      data: _content,
      padding: const EdgeInsets.all(20),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 22,
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
        p: const TextStyle(
          fontSize: 15,
          color: Color(0xFF1A1A1A),
          height: 1.8,
        ),
        code: const TextStyle(
          fontSize: 13,
          color: Color(0xFF1A1A1A),
          backgroundColor: Color(0xFFF5F5F5),
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border.all(color: const Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockPadding: const EdgeInsets.all(12),
        blockquote: const TextStyle(
          fontSize: 15,
          color: Color(0xFF666666),
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFF999999), width: 4)),
        ),
        blockquotePadding: const EdgeInsets.only(left: 12),
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
      ),
      sizedImageBuilder: (config) => _buildImage(config.uri.toString(), config.alt),
    );
  }

  /// 构建图片显示
  Widget _buildImage(String uri, String? alt) {
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
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.broken_image_outlined, size: 20, color: Color(0xFF999999)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    alt ?? '图片加载失败',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFCCCCCC)),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 14, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}
