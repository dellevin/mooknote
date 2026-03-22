import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';

/// 影视分享海报页面
class MovieSharePage extends StatefulWidget {
  final Movie movie;

  const MovieSharePage({super.key, required this.movie});

  @override
  State<MovieSharePage> createState() => _MovieSharePageState();
}

class _MovieSharePageState extends State<MovieSharePage> {
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
    final movie = widget.movie;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;

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
          // 海报图片
          if (hasPoster)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(movie.posterPath!),
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
                // 标题
                Text(
                  movie.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),

                // 别名
                if (movie.alternateTitles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    movie.alternateTitles.join(' / '),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 评分
                if (movie.rating != null && movie.rating! > 0) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 18,
                        color: Color(0xFFFFB800),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        movie.rating!.toStringAsFixed(1),
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

                // 导演
                if (movie.directors.isNotEmpty)
                  _buildInfoRow('导演', movie.directors.join(' / ')),

                // 编剧
                if (movie.writers.isNotEmpty)
                  _buildInfoRow('编剧', movie.writers.join(' / ')),

                // 主演
                if (movie.actors.isNotEmpty)
                  _buildInfoRow('主演', movie.actors.take(3).join(' / ')),

                // 类型
                if (movie.genres.isNotEmpty)
                  _buildInfoRow('类型', movie.genres.join(' / ')),

                // 上映日期
                if (movie.releaseDate != null)
                  _buildInfoRow(
                    '上映',
                    '${movie.releaseDate!.year}.${movie.releaseDate!.month.toString().padLeft(2, '0')}.${movie.releaseDate!.day.toString().padLeft(2, '0')}',
                  ),

                const SizedBox(height: 16),

                // 简介
                if (movie.summary != null && movie.summary!.isNotEmpty) ...[
                  const Text(
                    '简介',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.summary!,
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
                      Icons.movie_outlined,
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
      final fileName = 'movie_poster_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // 分享
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '分享影视：${widget.movie.title}',
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
