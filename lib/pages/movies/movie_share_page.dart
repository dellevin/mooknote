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
    final movie = widget.movie;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surface,
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),

                // 别名
                if (movie.alternateTitles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    movie.alternateTitles.join(' / '),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurface.withValues(alpha: 0.6),
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

                // 导演
                if (movie.directors.isNotEmpty)
                  _buildInfoRow('导演', movie.directors.join(' / '), colors),

                // 编剧
                if (movie.writers.isNotEmpty)
                  _buildInfoRow('编剧', movie.writers.join(' / '), colors),

                // 主演
                if (movie.actors.isNotEmpty)
                  _buildInfoRow('主演', movie.actors.take(3).join(' / '), colors),

                // 类型
                if (movie.genres.isNotEmpty)
                  _buildInfoRow('类型', movie.genres.join(' / '), colors),

                // 上映日期
                if (movie.releaseDate != null)
                  _buildInfoRow(
                    '上映',
                    '${movie.releaseDate!.year}.${movie.releaseDate!.month.toString().padLeft(2, '0')}.${movie.releaseDate!.day.toString().padLeft(2, '0')}',
                    colors,
                  ),

                const SizedBox(height: 16),

                // 简介
                if (movie.summary != null && movie.summary!.isNotEmpty) ...[
                  Text(
                    '简介',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    movie.summary!,
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
                      Icons.movie_outlined,
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
