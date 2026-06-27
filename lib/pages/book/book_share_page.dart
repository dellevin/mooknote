import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';

/// 书籍分享海报页面
class BookSharePage extends StatefulWidget {
  final Book book;

  const BookSharePage({super.key, required this.book});

  @override
  State<BookSharePage> createState() => _BookSharePageState();
}

class _BookSharePageState extends State<BookSharePage> {
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
          '分享海报',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isGenerating ? null : _generateAndShare,
            child: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '分享',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
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

  /// 构建海报 Widget
  Widget _buildPosterWidget() {
    final colors = Theme.of(context).colorScheme;
    final book = widget.book;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图片
          if (hasCover)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: FadeInLocalImage(
                path: book.coverPath,
                width: 320,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),

          // 内容区域
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 书名
                Text(
                  book.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),

                // 别名
                if (book.alternateTitles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    book.alternateTitles.join(' / '),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 评分
                if (book.rating != null && book.rating! > 0) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 18,
                        color: Color(0xFFFFB800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        book.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFFB800),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ 10',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 作者
                if (book.authors.isNotEmpty)
                  _buildInfoRow('作者', book.authors.join(' / '), colors),

                // 出版社
                if (book.publisher != null && book.publisher!.isNotEmpty)
                  _buildInfoRow('出版社', book.publisher!, colors),

                // 出版时间
                if (book.publishDate != null)
                  _buildInfoRow(
                    '出版',
                    '${book.publishDate!.year}.${book.publishDate!.month.toString().padLeft(2, '0')}.${book.publishDate!.day.toString().padLeft(2, '0')}',
                    colors,
                  ),

                // 类型
                if (book.genres.isNotEmpty)
                  _buildInfoRow('类型', book.genres.join(' / '), colors),

                // ISBN
                if (book.isbn != null && book.isbn!.isNotEmpty)
                  _buildInfoRow('ISBN', book.isbn!, colors),

                const SizedBox(height: 16),

                // 简介
                if (book.summary != null && book.summary!.isNotEmpty) ...[
                  Text(
                    '简介',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.summary!,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.6),
                      height: 1.6,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 20),

                // 底部标识
                Divider(height: 1, color: colors.outline),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 14,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '来自 MookNote',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
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

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label：',
            style: TextStyle(
              fontSize: 13,
              color: colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 生成并分享海报
  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
      // 捕获海报图片
      final boundary = _posterKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('无法获取海报边界');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('无法生成图片数据');
      }

      final bytes = byteData.buffer.asUint8List();

      // 保存到临时文件
      final tempDir = await getTemporaryDirectory();
      final fileName = 'book_poster_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // 分享
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '分享书籍：${widget.book.title}',
      );
    } catch (e) {
      if (mounted) {
        ToastUtil.show(context, '生成海报失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
