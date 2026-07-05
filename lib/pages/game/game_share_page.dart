import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';

class GameSharePage extends StatefulWidget {
  final Game game;
  const GameSharePage({super.key, required this.game});

  @override
  State<GameSharePage> createState() => _GameSharePageState();
}

class _GameSharePageState extends State<GameSharePage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;
  int _currentStyle = 0;

  static const _styleNames = ['海报', '游戏卡'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHighest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close, color: colors.onSurface), onPressed: () => Navigator.pop(context)),
        title: Text('分享海报', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.palette_outlined, color: colors.onSurface, size: 22), tooltip: '选择样式', onPressed: _showStylePicker),
          TextButton(
            onPressed: _isGenerating ? null : _generateAndShare,
            child: _isGenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('分享', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: RepaintBoundary(
            key: _posterKey,
            child: _currentStyle == 1 ? _buildGameCard() : _buildPosterWidget(),
          ),
        ),
      ),
    );
  }

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    const icons = [Icons.image_outlined, Icons.sports_esports_outlined];
    const subtitles = ['简约海报风格', '游戏信息卡风格'];
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Text('选择样式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          const SizedBox(height: 12),
          for (int i = 0; i < _styleNames.length; i++) ...[
            if (i > 0) Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icons[i], size: 20, color: _currentStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(_styleNames[i], style: TextStyle(fontSize: 13, fontWeight: _currentStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i], style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: _currentStyle == i
                  ? Icon(Icons.check_circle, size: 20, color: colors.primary)
                  : Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () { setState(() => _currentStyle = i); Navigator.pop(ctx); },
            ),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  // ─── 样式 0：海报 ───

  Widget _buildPosterWidget() {
    final colors = Theme.of(context).colorScheme;
    final game = widget.game;
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;

    return Container(
      width: 320,
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasCover)
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: FadeInLocalImage(path: game.coverPath, width: 320, height: 200, fit: BoxFit.cover)),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(game.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.onSurface)),
          const SizedBox(height: 16),
          if (game.rating != null && game.rating! > 0) ...[
            Row(children: [
              const Icon(Icons.star, size: 18, color: Color(0xFFFFB800)),
              const SizedBox(width: 4),
              Text(game.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
              const SizedBox(width: 4),
              Text('/ 10', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            ]),
            const SizedBox(height: 12),
          ],
          if (game.platforms.isNotEmpty) _infoRow('平台', game.platforms.join(' / '), colors),
          if (game.genres.isNotEmpty) _infoRow('类型', game.genres.join(' / '), colors),
          if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
            _infoRow('时长', '${game.playTimeHours}时${game.playTimeMinutes}分', colors),
          if (game.purchasePrice != null && game.purchasePrice!.isNotEmpty)
            _infoRow('价格', game.purchasePrice!, colors),
          if (game.summary != null && game.summary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('简介', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text(game.summary!, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6), maxLines: 5, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.outline),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.sports_esports_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text('来自 MookNote', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
          ]),
        ]),
      ),
      ]),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme colors) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label：', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75)))),
    ]));
  }

  // ─── 样式 1：游戏卡 ───

  Widget _buildGameCard() {
    final game = widget.game;
    const c = Color(0xFF2D2D2D);

    return Container(
      width: 300,
      decoration: BoxDecoration(color: const Color(0xFFFFFBF5), borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          if (game.coverPath != null && game.coverPath!.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: FadeInLocalImage(path: game.coverPath, width: 268, height: 160, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Text(game.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c, letterSpacing: 1)),
        ])),
        _dashedLine(c.withValues(alpha: 0.15)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 16), child: Column(children: [
          _classicRow('PLATFORM', game.platforms.isNotEmpty ? game.platforms.join(', ') : '--'),
          const SizedBox(height: 10),
          _classicRow('GENRE', game.genres.isNotEmpty ? game.genres.join(' / ') : '--'),
          const SizedBox(height: 10),
          _classicRow('STATUS', _statusEN(game.status)),
          if (game.playTimeHours > 0 || game.playTimeMinutes > 0) ...[
            const SizedBox(height: 10),
            _classicRow('PLAY TIME', '${game.playTimeHours}h ${game.playTimeMinutes}m'),
          ],
          if (game.rating != null && game.rating! > 0) ...[
            const SizedBox(height: 10),
            _classicRow('RATING', '${game.rating!.toStringAsFixed(1)} / 10'),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.2), width: 0.5)),
              child: Text(_statusEN(game.status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2, color: c.withValues(alpha: 0.5)))),
            const Spacer(),
            Icon(Icons.sports_esports_outlined, size: 12, color: c.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            Text('MookNote', style: TextStyle(fontSize: 9, letterSpacing: 1, color: c.withValues(alpha: 0.3))),
          ]),
          ]),
        ),
      ]),
    );
  }

  Widget _classicRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: const Color(0xFF2D2D2D).withValues(alpha: 0.35)))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D), height: 1.4))),
    ]);
  }

  Widget _dashedLine(Color color) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: color)));
  }

  String _statusEN(String s) {
    switch (s) {
      case 'completed': return 'COMPLETED';
      case 'playing': return 'PLAYING';
      case 'want_to_play': return 'WISHLIST';
      case 'abandoned': return 'DROPPED';
      default: return s.toUpperCase();
    }
  }

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);
    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取海报边界');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/game_poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '分享游戏：${widget.game.title}');
    } catch (e) {
      if (mounted) ToastUtil.show(context, '生成海报失败：$e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;
  _DashedLinePainter({required this.color, this.dashWidth = 4, this.dashSpace = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    double x = 0;
    while (x < size.width) { canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint); x += dashWidth + dashSpace; }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
