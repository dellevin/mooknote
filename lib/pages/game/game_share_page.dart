import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_strings.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';
import '../../widgets/app_overlay.dart';

class GameSharePage extends StatefulWidget {
  final Game game;
  const GameSharePage({super.key, required this.game});

  @override
  State<GameSharePage> createState() => _GameSharePageState();
}

class _GameSharePageState extends State<GameSharePage> with SingleTickerProviderStateMixin {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;
  int _currentStyle = 0;
  int _ticketColorIndex = 0;
  late final AnimationController _holoController;

  static const _styleNames = ['海报', '游戏卡', '镭射票根'];

  // 票根底色主题
  static const _ticketThemes = [
    _TicketTheme('暗夜紫', Color(0xFF16141F), Color(0xFF262038)),
    _TicketTheme('暗金', Color(0xFF1A1408), Color(0xFF33270F)),
    _TicketTheme('黑色', Color(0xFF101013), Color(0xFF1F1F26)),
    _TicketTheme('蓝色', Color(0xFF0E1730), Color(0xFF1B2B4E)),
  ];

  @override
  void initState() {
    super.initState();
    // 默认不是票根样式，先不启动动画
    _holoController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _holoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerHighest,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close, color: colors.onSurface), onPressed: () => Navigator.pop(context)),
        title: Text('分享海报'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.onSurface)),
        centerTitle: true,
        actions: [
          IconButton(icon: Icon(Icons.palette_outlined, color: colors.onSurface, size: 22), tooltip: '选择样式'.tr, onPressed: _showStylePicker),
          TextButton(
            onPressed: _isGenerating ? null : _generateAndShare,
            child: _isGenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('分享'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            RepaintBoundary(
              key: _posterKey,
              child: _currentStyle == 2
                  ? _buildTicketStub()
                  : _currentStyle == 1
                      ? _buildGameCard()
                      : _buildPosterWidget(),
            ),
            // 票根底色选择
            if (_currentStyle == 2) ...[
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < _ticketThemes.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _ticketColorIndex = i),
                    child: Tooltip(
                      message: _ticketThemes[i].name.tr,
                      child: Container(
                        width: 26, height: 26,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: _ticketThemes[i].body,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _ticketColorIndex == i ? colors.primary : colors.outlineVariant,
                            width: _ticketColorIndex == i ? 2 : 1,
                          ),
                        ),
                        child: _ticketColorIndex == i
                            ? Icon(Icons.check, size: 14, color: colors.primary)
                            : null,
                      ),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    const icons = [Icons.image_outlined, Icons.sports_esports_outlined, Icons.confirmation_number_outlined];
    const subtitles = ['简约海报风格', '游戏信息卡风格', '全息镭射票根风格'];
    appModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: colors.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Align(alignment: Alignment.centerLeft, child: Text('选择样式'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface))),
          const SizedBox(height: 12),
          for (int i = 0; i < _styleNames.length; i++) ...[
            if (i > 0) Divider(height: 0.5, color: colors.outlineVariant),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icons[i], size: 20, color: _currentStyle == i ? colors.primary : colors.onSurface.withValues(alpha: 0.6))),
              title: Text(_styleNames[i].tr, style: TextStyle(fontSize: 13, fontWeight: _currentStyle == i ? FontWeight.w600 : FontWeight.w500, color: colors.onSurface)),
              subtitle: Text(subtitles[i].tr, style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4))),
              trailing: _currentStyle == i
                  ? Icon(Icons.check_circle, size: 20, color: colors.primary)
                  : Icon(Icons.chevron_right, color: colors.onSurface.withValues(alpha: 0.25)),
              onTap: () {
                setState(() {
                  _currentStyle = i;
                  // 只有票根样式才转动画，其他样式停掉省资源
                  if (i == 2) {
                    _holoController.repeat();
                  } else {
                    _holoController.stop();
                  }
                });
                Navigator.pop(ctx);
              },
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
            _infoRow('时长', '{h}时{m}分'.trf({'h': game.playTimeHours, 'm': game.playTimeMinutes}), colors),
          if (game.purchasePrice != null && game.purchasePrice!.isNotEmpty)
            _infoRow('价格', game.purchasePrice!, colors),
          if (game.summary != null && game.summary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('简介'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text(game.summary!, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6), maxLines: 5, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.outline),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.sports_esports_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text('来自 MookNote'.tr, style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
          ]),
        ]),
      ),
      ]),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme colors) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${label.tr}：', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
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

  // ─── 样式 2：镭射票根 ───

  // 低饱和珠光全息色（真实镭射票根的银彩感）
  static const _holoColors = [
    Color(0xFFF2C4D8), Color(0xFFC9C3EE), Color(0xFFB4D9EE),
    Color(0xFFC4EAD9), Color(0xFFF0E6C4), Color(0xFFEED2C0),
  ];

  Widget _buildTicketStub() {
    final game = widget.game;
    final hasCover = game.coverPath != null && game.coverPath!.isNotEmpty;
    const ink = Color(0xFFEDEAF6);
    final serial = 'NO.${game.id.replaceAll('-', '').substring(0, 8).toUpperCase()}';
    final theme = _ticketThemes[_ticketColorIndex];

    // 裁剪缺口位置（与撕票线对齐，距底部为票根高度）
    const stubHeight = 62.0;

    // 外层 AnimatedBuilder 每帧只重建渐变装饰（描边 + 高光），
    // 静态内容通过 child 传入，不随动画重建
    return AnimatedBuilder(
      animation: _holoController,
      child: _buildTicketContent(game, hasCover, ink, serial, stubHeight, theme),
      builder: (context, content) {
        final t = _holoController.value;
        // 移动的镭射高光带位置
        final sheen = -2.0 + 4.0 * t;
        return ClipPath(
          clipper: _TicketClipper(notchFromBottom: stubHeight, notchRadius: 7),
          child: Container(
            width: 216,
            decoration: BoxDecoration(
              // 旋转的全息彩虹描边
              gradient: SweepGradient(
                colors: [..._holoColors, _holoColors.first],
                transform: GradientRotation(t * 2 * math.pi),
              ),
            ),
            padding: const EdgeInsets.all(1.5),
            child: ClipPath(
              clipper: _TicketClipper(notchFromBottom: stubHeight, notchRadius: 6.5),
              child: Container(
                color: theme.body,
                child: Stack(children: [
                  // 斜向扫动的彩虹高光带（镭射反光感）
                  Positioned.fill(child: IgnorePointer(child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          _holoColors[0].withValues(alpha: 0.14),
                          _holoColors[2].withValues(alpha: 0.14),
                          _holoColors[4].withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.38, 0.47, 0.56, 1.0],
                        begin: Alignment(sheen, sheen), end: Alignment(sheen + 1.2, sheen + 1.2),
                      ),
                    ),
                  ))),
                  content!,
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 票根静态内容（不随动画重建，仅封面框和标题各自挂小 AnimatedBuilder）
  Widget _buildTicketContent(Game game, bool hasCover, Color ink, String serial, double stubHeight, _TicketTheme theme) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // 票头
      Padding(padding: const EdgeInsets.fromLTRB(16, 13, 16, 10), child: Row(children: [
        Container(width: 14, height: 0.8, color: _holoColors[2].withValues(alpha: 0.5)),
        const SizedBox(width: 5),
        Text('GAME TICKET', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 3, color: _holoColors[2].withValues(alpha: 0.85))),
        const SizedBox(width: 5),
        Container(width: 14, height: 0.8, color: _holoColors[2].withValues(alpha: 0.5)),
        const Spacer(),
        Text(serial, style: TextStyle(fontSize: 7.5, letterSpacing: 1, color: ink.withValues(alpha: 0.35))),
      ])),
      // 封面（竖版海报比例，无封面时用占位块保持比例）
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: AnimatedBuilder(
        animation: _holoController,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: _holoColors, begin: Alignment(-1 + 2 * _holoController.value, -1), end: Alignment(1 + 2 * _holoController.value, 1)),
          ),
          padding: const EdgeInsets.all(1),
          child: child,
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(9),
          child: Stack(children: [
            hasCover
                ? FadeInLocalImage(path: game.coverPath, width: 186, height: 248, fit: BoxFit.cover)
                : Container(
                    width: 186, height: 248,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [theme.placeholder, theme.body], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                    child: Icon(Icons.sports_esports_outlined, size: 44, color: ink.withValues(alpha: 0.15)),
                  ),
            // 底部光影渐变，让封面与票体衔接
            Positioned(left: 0, right: 0, bottom: 0, height: 90, child: IgnorePointer(child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, theme.body.withValues(alpha: 0.85)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ))),
          ]))),
      ),
      // 主信息区
      Padding(padding: const EdgeInsets.fromLTRB(16, 13, 16, 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnimatedBuilder(
          animation: _holoController,
          builder: (context, child) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(colors: _holoColors, begin: Alignment(-1 + 2 * _holoController.value, 0), end: Alignment(1 + 2 * _holoController.value, 0)).createShader(bounds),
            child: child,
          ),
          child: Text(game.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
        ),
        const SizedBox(height: 9),
        // 彩虹渐变分隔线（向右侧淡出）
        Container(height: 1, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _holoColors[0].withValues(alpha: 0.55),
            _holoColors[2].withValues(alpha: 0.55),
            Colors.transparent,
          ]),
        )),
        const SizedBox(height: 10),
        if (game.platforms.isNotEmpty) _holoRow('PLATFORM', game.platforms.join(' / '), ink),
        if (game.genres.isNotEmpty) _holoRow('GENRE', game.genres.join(' / '), ink),
        if (game.playTimeHours > 0 || game.playTimeMinutes > 0)
          _holoRow('TIME', '${game.playTimeHours}h ${game.playTimeMinutes}m', ink),
        const SizedBox(height: 8),
        Row(children: [
          if (game.rating != null && game.rating! > 0) ...[
            const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF0DCA8)),
            const SizedBox(width: 3),
            Text(game.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF0DCA8))),
            Text(' / 10', style: TextStyle(fontSize: 10, color: ink.withValues(alpha: 0.4))),
            const Spacer(),
          ] else
            const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _holoColors[2].withValues(alpha: 0.55), width: 0.8),
            ),
            child: Text(_statusEN(game.status), style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 2, color: _holoColors[2].withValues(alpha: 0.9))),
          ),
        ]),
      ])),
      // 底部票根（固定高度，撕票线在其顶部，与裁剪缺口对齐）
      SizedBox(height: stubHeight, child: Stack(children: [
        // 裁剪线：剪刀 + 虚线
        Positioned(top: 0, left: 12, right: 10, child: Row(children: [
          Padding(padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.content_cut, size: 9, color: ink.withValues(alpha: 0.35))),
          const SizedBox(width: 4),
          Expanded(child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: ink.withValues(alpha: 0.25)))),
        ])),
        // 条形码 + 票号 + 品牌
        Positioned.fill(top: 10, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final w in _barcodePattern(game.id))
              Container(width: w, height: 20, margin: const EdgeInsets.symmetric(horizontal: 0.8),
                color: ink.withValues(alpha: 0.6)),
          ]),
          const SizedBox(height: 3),
          Text(serial, style: TextStyle(fontSize: 7, letterSpacing: 2.5, color: ink.withValues(alpha: 0.5))),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.sports_esports_outlined, size: 8, color: ink.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            Text('MOOKNOTE', style: TextStyle(fontSize: 6.5, letterSpacing: 3, color: ink.withValues(alpha: 0.3))),
          ]),
        ])),
      ])),
    ]);
  }

  /// 由游戏 ID 生成伪随机条形码条纹宽度
  List<double> _barcodePattern(String seed) {
    var h = seed.hashCode;
    return List.generate(24, (_) {
      h = (h * 1103515245 + 12345) & 0x7fffffff;
      return 1.0 + (h % 3).toDouble();
    });
  }

  Widget _holoRow(String label, String value, Color ink) {
    return Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 58, child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: ink.withValues(alpha: 0.35)))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ink.withValues(alpha: 0.85), height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]));
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
      if (boundary == null) throw Exception('无法获取海报边界'.tr);
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据'.tr);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/game_poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '分享游戏：{title}'.trf({'title': widget.game.title}));
    } catch (e) {
      if (mounted) ToastUtil.show(context, '生成海报失败：{e}'.trf({'e': e}));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

/// 票根底色主题
class _TicketTheme {
  final String name;
  final Color body;         // 票体背景色
  final Color placeholder;  // 无封面占位块的渐变顶色
  const _TicketTheme(this.name, this.body, this.placeholder);
}

/// 票根形状裁剪：上下锯齿撕边 + 撕票线两端的半圆裁剪缺口
class _TicketClipper extends CustomClipper<Path> {
  final double notchFromBottom;
  final double notchRadius;
  _TicketClipper({required this.notchFromBottom, required this.notchRadius});

  static const _toothH = 4.0;
  static const _toothW = 7.0;

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    var path = Path()..moveTo(0, _toothH);
    // 上边锯齿（三角齿）
    var x = 0.0;
    var up = true;
    while (x < w) {
      x += _toothW / 2;
      path.lineTo(x > w ? w : x, up ? 0 : _toothH);
      up = !up;
    }
    path.lineTo(w, h - _toothH);
    // 下边锯齿（从右往左）
    x = w;
    up = true;
    while (x > 0) {
      x -= _toothW / 2;
      path.lineTo(x < 0 ? 0 : x, up ? h : h - _toothH);
      up = !up;
    }
    path.close();
    // 撕票线两端的半圆缺口
    final notchY = h - notchFromBottom;
    for (final cx in [0.0, w]) {
      final notch = Path()..addOval(Rect.fromCircle(center: Offset(cx, notchY), radius: notchRadius));
      path = Path.combine(PathOperation.difference, path, notch);
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _TicketClipper old) =>
      old.notchFromBottom != notchFromBottom || old.notchRadius != notchRadius;
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final paint = Paint()..color = color..strokeWidth = 1..style = PaintingStyle.stroke;
    double x = 0;
    while (x < size.width) { canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint); x += dashWidth + dashSpace; }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
