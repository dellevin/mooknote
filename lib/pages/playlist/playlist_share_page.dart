import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';

/// 片单条目（由片单详情页解析后传入，分享页不再关心作品来源）
class PlaylistShareEntry {
  final String title;
  final String? coverPath;
  const PlaylistShareEntry({required this.title, this.coverPath});
}

/// 片单分享海报页：全量封面拼贴 + 片单信息，与影视/游戏分享海报同款交互
class PlaylistSharePage extends StatefulWidget {
  final Playlist playlist;
  final List<PlaylistShareEntry> entries;
  const PlaylistSharePage({super.key, required this.playlist, required this.entries});

  @override
  State<PlaylistSharePage> createState() => _PlaylistSharePageState();
}

class _PlaylistSharePageState extends State<PlaylistSharePage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;
  int _coverStyle = 0; // 0: 斜向拼贴（拍立得卡片） 1: 竖向网格

  // 海报固定浅色配色，不随暗色主题变化，保证导出图片观感一致
  static const _ink = Color(0xFF1A1A1E);
  static const _subInk = Color(0xFF8A8A8E);

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
            onPressed: () => Navigator.pop(context)),
        title: Text('分享海报'.tr,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isGenerating ? null : _generateAndShare,
            child: _isGenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('分享'.tr,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _posterKey,
                child: _buildPoster(),
              ),
              const SizedBox(height: 20),
              _buildStyleSwitch(colors),
            ],
          ),
        ),
      ),
    );
  }

  /// 斜向拼贴 / 竖向网格切换（不影响海报外截图内容）
  Widget _buildStyleSwitch(ColorScheme colors) {
    final items = [
      (Icons.auto_awesome_motion_outlined, '斜向拼贴'),
      (Icons.grid_view_outlined, '竖向网格'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          GestureDetector(
            onTap: () => setState(() => _coverStyle = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _coverStyle == i ? Colors.black : colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: _coverStyle == i ? Colors.black : colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(items[i].$1,
                      size: 15,
                      color: _coverStyle == i
                          ? Colors.white
                          : colors.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 5),
                  Text(items[i].$2.tr,
                      style: TextStyle(
                          fontSize: 12,
                          color: _coverStyle == i
                              ? Colors.white
                              : colors.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPoster() {
    final playlist = widget.playlist;
    final now = DateTime.now();
    final date =
        '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';

    return Container(
      width: 340,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F5F1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEAE4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('MOOKNOTE PLAYLIST',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2.5,
                        color: _subInk,
                        fontWeight: FontWeight.w600)),
              ),
              Container(width: 22, height: 3, color: _ink),
            ],
          ),
          const SizedBox(height: 10),
          Text(playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: _ink, height: 1.25)),
          if (playlist.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(playlist.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _subInk, height: 1.4)),
          ],
          const SizedBox(height: 18),
          _buildCovers(),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE8E4DD)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('MookNote',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: _ink, letterSpacing: 0.5)),
              const Spacer(),
              Text(date, style: const TextStyle(fontSize: 11, color: _subInk)),
            ],
          ),
        ],
      ),
    );
  }

  /// 封面区：两种排版都全量展示条目（有几个显示几个）
  /// 一次性构建（shrinkWrap 非懒加载），RepaintBoundary 才能完整光栅化长海报
  Widget _buildCovers() {
    final entries = widget.entries;
    if (_coverStyle == 1) {
      return GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.68,
        children: [
          for (final e in entries)
            ClipRRect(borderRadius: BorderRadius.circular(10), child: _coverContent(e)),
        ],
      );
    }
    // 斜向拼贴：白边卡片 + 交替倾角与中列错位，像摊在桌面上的照片
    const angles = [-0.07, 0.05, -0.04, 0.06, -0.05, 0.04];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 10,
      childAspectRatio: 0.62,
      children: [
        for (var i = 0; i < entries.length; i++)
          Transform.translate(
            offset: Offset(0, i % 3 == 1 ? 6 : 0),
            child: Transform.rotate(
              angle: angles[i % angles.length],
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: _coverContent(entries[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _coverContent(PlaylistShareEntry e) {
    if (e.coverPath != null && e.coverPath!.isNotEmpty) {
      return FadeInLocalImage(
        path: e.coverPath!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }
    // 无封面：浅底 + 片名占位，保证条目一个不少
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF1EFEA),
      padding: const EdgeInsets.all(6),
      alignment: Alignment.center,
      child: Text(e.title,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _subInk, height: 1.35)),
    );
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);
    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取海报边界'.tr);
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据'.tr);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/playlist_poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)],
          text: '分享片单：{name}'.trf({'name': widget.playlist.name}));
    } catch (e) {
      if (mounted) ToastUtil.show(context, '生成海报失败：{e}'.trf({'e': e}));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}
