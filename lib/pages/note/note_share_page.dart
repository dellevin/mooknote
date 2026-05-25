import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';

/// 笔记分享海报页面
class NoteSharePage extends StatefulWidget {
  final Note note;

  const NoteSharePage({super.key, required this.note});

  @override
  State<NoteSharePage> createState() => _NoteSharePageState();
}

class _NoteSharePageState extends State<NoteSharePage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;

  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

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
          '分享笔记',
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

  Widget _buildPosterWidget() {
    final colors = Theme.of(context).colorScheme;
    final note = widget.note;
    final hasImages = note.images.isNotEmpty;
    final dateStr =
        '${note.createdAt.year}/${note.createdAt.month.toString().padLeft(2, '0')}/${note.createdAt.day.toString().padLeft(2, '0')} '
        '周${_weekdays[note.createdAt.weekday - 1]} '
        '${note.createdAt.hour.toString().padLeft(2, '0')}:${note.createdAt.minute.toString().padLeft(2, '0')}';

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
          // 首张图片
          if (hasImages && File(note.images.first).existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(note.images.first),
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
                if (note.title.isNotEmpty) ...[
                  Text(
                    note.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // 日期
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.4),
                  ),
                ),

                // 标签
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: note.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.5)),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 16),
                Container(height: 0.5, color: colors.outline),
                const SizedBox(height: 16),

                // 正文内容
                Text(
                  note.content,
                  maxLines: 12,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface.withValues(alpha: 0.75),
                    height: 1.8,
                  ),
                ),

                // 字数和图片数
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMetaChip(Icons.text_fields_outlined, '${note.content.length} 字'),
                    if (hasImages) ...[
                      const SizedBox(width: 12),
                      _buildMetaChip(Icons.image_outlined, '${note.images.length} 图'),
                    ],
                    const Spacer(),
                    // Mooknote 品牌
                    Text(
                      'Mooknote',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurface.withValues(alpha: 0.25),
                        fontWeight: FontWeight.w500,
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

  Widget _buildMetaChip(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.35)),
        ),
      ],
    );
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
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

      final tempDir = await getTemporaryDirectory();
      final fileName = 'note_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '分享笔记：${widget.note.title.isNotEmpty ? widget.note.title : '无标题'}',
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
