import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '分享海报',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
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
                : const Text(
                    '分享',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
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
    final book = widget.book;
    final hasCover = book.coverPath != null && book.coverPath!.isNotEmpty;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              child: Image.file(
                File(book.coverPath!),
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                // 别名
                if (book.alternateTitles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    book.alternateTitles.join(' / '),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
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
                      const Text(
                        '/ 10',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 作者
                if (book.authors.isNotEmpty)
                  _buildInfoRow('作者', book.authors.join(' / ')),

                // 出版社
                if (book.publisher != null && book.publisher!.isNotEmpty)
                  _buildInfoRow('出版社', book.publisher!),

                // 出版时间
                if (book.publishDate != null)
                  _buildInfoRow(
                    '出版',
                    '${book.publishDate!.year}.${book.publishDate!.month.toString().padLeft(2, '0')}.${book.publishDate!.day.toString().padLeft(2, '0')}',
                  ),

                // 类型
                if (book.genres.isNotEmpty)
                  _buildInfoRow('类型', book.genres.join(' / ')),

                // ISBN
                if (book.isbn != null && book.isbn!.isNotEmpty)
                  _buildInfoRow('ISBN', book.isbn!),

                const SizedBox(height: 16),

                // 简介
                if (book.summary != null && book.summary!.isNotEmpty) ...[
                  const Text(
                    '简介',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.summary!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                      height: 1.6,
                    ),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 20),

                // 底部标识
                const Divider(height: 1, color: Color(0xFFE8E8E8)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 14,
                      color: const Color(0xFF1A1A1A).withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '来自 MookNote',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF1A1A1A).withOpacity(0.5),
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
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label：',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF999999),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF333333),
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
