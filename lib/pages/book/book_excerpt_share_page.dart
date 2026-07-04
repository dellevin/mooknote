import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';

/// 摘抄分享海报页面
class BookExcerptSharePage extends StatefulWidget {
  final BookExcerpt excerpt;
  final Book book;

  const BookExcerptSharePage({super.key, required this.excerpt, required this.book});

  @override
  State<BookExcerptSharePage> createState() => _BookExcerptSharePageState();
}

class _BookExcerptSharePageState extends State<BookExcerptSharePage> {
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
          '分享摘抄',
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
    final excerpt = widget.excerpt;
    final book = widget.book;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;
    final dateStr = '${excerpt.createdAt.year}.${excerpt.createdAt.month.toString().padLeft(2, '0')}.${excerpt.createdAt.day.toString().padLeft(2, '0')}';

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
          // 顶部：书籍信息条
          if (hasCover || book.title.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  // 小封面
                  if (hasCover)
                    Container(
                      width: 36,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: colors.surfaceContainerHighest,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FadeInLocalImage(
                        path: book.coverPath,
                        fit: BoxFit.cover,
                        errorWidget: const SizedBox.shrink(),
                      ),
                    ),
                  if (hasCover) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.onSurface),
                        ),
                        if (book.authors.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            book.authors.join(' / '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4)),
                          ),
                        ],
                      ],
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

          // 摘抄内容
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 想法
                if (excerpt.comment.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 14, color: colors.primary.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          excerpt.comment,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurface.withValues(alpha: 0.5),
                            height: 1.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                // 引号 + 内容
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u201C',
                      style: TextStyle(
                        fontSize: 28,
                        color: colors.primary.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        excerpt.content,
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.onSurface.withValues(alpha: 0.85),
                          height: 1.9,
                        ),
                      ),
                    ),
                  ],
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
                    if (excerpt.chapter.isNotEmpty) ...[
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            excerpt.chapter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: colors.primary.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(dateStr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3))),
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
      final fileName = 'excerpt_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '分享摘抄：${widget.book.title}',
      );
    } catch (e) {
      if (mounted) ToastUtil.show(context, '生成海报失败：$e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
