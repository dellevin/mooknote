import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils/toast_util.dart';

/// 句读分享海报页面
class HighlightSharePage extends StatefulWidget {
  final String content;
  final String bookTitle;
  final String chapter;
  final String dateStr;

  const HighlightSharePage({
    super.key,
    required this.content,
    required this.bookTitle,
    this.chapter = '',
    this.dateStr = '',
  });

  @override
  State<HighlightSharePage> createState() => _HighlightSharePageState();
}

class _HighlightSharePageState extends State<HighlightSharePage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHighest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '分享句读',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isGenerating ? null : _generateAndShare,
            child: _isGenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('分享', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RepaintBoundary(
            key: _posterKey,
            child: _buildPosterWidget(),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterWidget() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：书名
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Icon(Icons.book_outlined, size: 16, color: const Color(0xFFFFC107)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                ),
              ],
            ),
          ),

          // 分隔线
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(height: 0.5, color: colors.outline),
          ),

          // 引号 + 内容
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\u201C',
                  style: TextStyle(
                    fontSize: 28,
                    color: const Color(0xFFFFC107).withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.onSurface.withValues(alpha: 0.85),
                      height: 1.9,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 底部：章节 + 日期 + 品牌
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                Container(height: 0.5, color: colors.outline),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.chapter.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEB3B).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.chapter,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.dateStr.isNotEmpty)
                      Text(widget.dateStr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
                    const Spacer(),
                    Text(
                      'MookNote',
                      style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.25), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取海报边界');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据');

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName = 'highlight_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '分享句读：${widget.bookTitle}',
      );
    } catch (e) {
      if (mounted) ToastUtil.show(context, '生成海报失败：$e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
