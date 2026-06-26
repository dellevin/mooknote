import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/data_models.dart';
import '../../utils/toast_util.dart';
import '../../widgets/fade_in_local_image.dart';

class MovieSharePage extends StatefulWidget {
  final Movie movie;
  const MovieSharePage({super.key, required this.movie});

  @override
  State<MovieSharePage> createState() => _MovieSharePageState();
}

class _MovieSharePageState extends State<MovieSharePage> {
  final GlobalKey _posterKey = GlobalKey();
  bool _isGenerating = false;
  int _currentStyle = 0;

  static const _styleNames = ['海报', '经典票根', '喵眼电影票根', '收藏版票根'];

  // 影院信息（可编辑）
  late TextEditingController _cinemaCtrl;
  late TextEditingController _hallCtrl;
  late TextEditingController _seatRowCtrl;
  late TextEditingController _seatNumCtrl;
  late TextEditingController _screeningDateCtrl;
  late TextEditingController _screeningTimeCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _serviceFeeCtrl;
  late TextEditingController _issueTimeCtrl;
  late TextEditingController _platformCtrl;
  late TextEditingController _ticketCodeCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final dateStr = '${now.year}年${now.month}月${now.day}日';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final issueStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final codeStr = 'MK${now.millisecondsSinceEpoch.toString().substring(1)}';

    _cinemaCtrl = TextEditingController(text: '万达影城');
    _hallCtrl = TextEditingController(text: '3号厅');
    _seatRowCtrl = TextEditingController(text: '8');
    _seatNumCtrl = TextEditingController(text: '12');
    _screeningDateCtrl = TextEditingController(text: dateStr);
    _screeningTimeCtrl = TextEditingController(text: timeStr);
    _priceCtrl = TextEditingController(text: '39.90');
    _serviceFeeCtrl = TextEditingController(text: '5.00');
    _issueTimeCtrl = TextEditingController(text: issueStr);
    _platformCtrl = TextEditingController(text: '喵眼电影');
    _ticketCodeCtrl = TextEditingController(text: codeStr);
  }

  @override
  void dispose() {
    _cinemaCtrl.dispose();
    _hallCtrl.dispose();
    _seatRowCtrl.dispose();
    _seatNumCtrl.dispose();
    _screeningDateCtrl.dispose();
    _screeningTimeCtrl.dispose();
    _priceCtrl.dispose();
    _serviceFeeCtrl.dispose();
    _issueTimeCtrl.dispose();
    _platformCtrl.dispose();
    _ticketCodeCtrl.dispose();
    super.dispose();
  }

  bool get _isCinemaStyle => _currentStyle >= 2;

  Widget _buildBody() {
    switch (_currentStyle) {
      case 0: return _buildPosterWidget();
      case 1: return _buildTicketClassic();
      case 2: return _buildTicketCinema();
      case 3: return _buildTicketCollectible();
      default: return _buildPosterWidget();
    }
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
      body: Column(children: [
        // 预览
        Expanded(child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: RepaintBoundary(key: _posterKey, child: _buildBody()),
          ),
        )),
        // 底部编辑按钮（仅票根样式）
        if (_isCinemaStyle) _buildBottomEditBar(colors),
      ]),
    );
  }

  // ─── 样式选择 ───

  void _showStylePicker() {
    final colors = Theme.of(context).colorScheme;
    const icons = [Icons.image_outlined, Icons.confirmation_num_outlined, Icons.local_movies_outlined, Icons.card_giftcard_outlined];
    const subtitles = ['简约海报风格', '经典复古票根', '电影票票根样式', '高端收藏版票根'];
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

  // ─── 底部编辑栏 ───

  Widget _buildBottomEditBar(ColorScheme colors) {
    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, bottom: MediaQuery.of(context).padding.bottom + 12, top: 8),
      color: colors.surface,
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: _showEditSheet,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('编辑票根信息'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  void _showEditSheet() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('编辑票根信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface)),
            const SizedBox(height: 16),
            _sheetField('影院名称', _cinemaCtrl),
            _sheetField('影厅', _hallCtrl),
            Row(children: [
              Expanded(child: _sheetField('排', _seatRowCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _sheetField('座', _seatNumCtrl)),
            ]),
            Row(children: [
              Expanded(child: _sheetField('票价 (¥)', _priceCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _sheetField('服务费 (¥)', _serviceFeeCtrl)),
            ]),
            _sheetDatePicker('出票日期', _issueTimeCtrl, ctx),
            _sheetCodeField(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity, height: 44,
              child: ElevatedButton(
                onPressed: () { setState(() {}); Navigator.pop(ctx); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary, foregroundColor: colors.onPrimary, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('完成'),
              ),
            ),
          ],
        )),
      ),
    );
  }

  Widget _sheetField(String label, TextEditingController ctrl) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 14, color: colors.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: true, fillColor: colors.surfaceContainerHighest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary, width: 1)),
        ),
      ),
    );
  }

  Widget _sheetDatePicker(String label, TextEditingController ctrl, BuildContext sheetCtx) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: sheetCtx,
            initialDate: now,
            firstDate: DateTime(1900),
            lastDate: DateTime(now.year + 10),
            locale: const Locale('zh'),
          );
          if (picked != null) {
            ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
          }
        },
        child: AbsorbPointer(child: TextField(
          controller: ctrl,
          style: TextStyle(fontSize: 14, color: colors.onSurface),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true, fillColor: colors.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary, width: 1)),
            suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: colors.onSurface.withValues(alpha: 0.4)),
          ),
        )),
      ),
    );
  }

  Widget _sheetCodeField() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _ticketCodeCtrl,
          style: TextStyle(fontSize: 14, color: colors.onSurface, fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: '编码',
            labelStyle: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true, fillColor: colors.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: colors.primary, width: 1)),
          ),
        )),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            _ticketCodeCtrl.text = 'MK${DateTime.now().millisecondsSinceEpoch.toString().substring(1)}';
          },
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.casino_outlined, size: 20, color: colors.onSurface.withValues(alpha: 0.6)),
          ),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 样式 0：海报
  // ═══════════════════════════════════════════════════════════

  Widget _buildPosterWidget() {
    final colors = Theme.of(context).colorScheme;
    final movie = widget.movie;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;

    return Container(
      width: 320,
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasPoster)
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: FadeInLocalImage(path: movie.posterPath, width: 320, height: 200, fit: BoxFit.cover)),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(movie.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.onSurface)),
          if (movie.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(movie.alternateTitles.join(' / '), style: TextStyle(fontSize: 14, color: colors.onSurface.withValues(alpha: 0.6))),
          ],
          const SizedBox(height: 16),
          if (movie.rating != null && movie.rating! > 0) ...[
            Row(children: [
              const Icon(Icons.star, size: 18, color: Color(0xFFFFB800)),
              const SizedBox(width: 4),
              Text(movie.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFFFB800))),
              const SizedBox(width: 4),
              Text('/ 10', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            ]),
            const SizedBox(height: 12),
          ],
          if (movie.directors.isNotEmpty) _infoRow('导演', movie.directors.join(' / '), colors),
          if (movie.writers.isNotEmpty) _infoRow('编剧', movie.writers.join(' / '), colors),
          if (movie.actors.isNotEmpty) _infoRow('主演', movie.actors.take(3).join(' / '), colors),
          if (movie.genres.isNotEmpty) _infoRow('类型', movie.genres.join(' / '), colors),
          if (movie.releaseDate != null) _infoRow('上映', _fmtDate(movie.releaseDate!), colors),
          if (movie.summary != null && movie.summary!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('简介', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Text(movie.summary!, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6), height: 1.6), maxLines: 5, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 20),
          Divider(height: 1, color: colors.outline),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.movie_outlined, size: 14, color: colors.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text('来自 MookNote', style: TextStyle(fontSize: 12, color: colors.onSurface.withValues(alpha: 0.5))),
          ]),
        ])),
      ]),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme colors) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$label：', style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.4))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.75)))),
    ]));
  }

  // ═══════════════════════════════════════════════════════════
  // 样式 1：经典票根
  // ═══════════════════════════════════════════════════════════

  Widget _buildTicketClassic() {
    final movie = widget.movie;
    final hasPoster = movie.posterPath != null && movie.posterPath!.isNotEmpty;
    const c = Color(0xFF2D2D2D);

    return Container(
      width: 300,
      decoration: BoxDecoration(color: const Color(0xFFFFFBF5), borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          if (hasPoster) ClipRRect(borderRadius: BorderRadius.circular(4),
            child: FadeInLocalImage(path: movie.posterPath, width: 268, height: 160, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Text(movie.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c, letterSpacing: 1)),
          if (movie.alternateTitles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(movie.alternateTitles.join(' / '), textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.withValues(alpha: 0.4))),
          ],
        ])),
        _dashedLine(c.withValues(alpha: 0.15)),
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 16), child: Column(children: [
          _classicRow('DIRECTED BY', movie.directors.isNotEmpty ? movie.directors.join(', ') : '--'),
          const SizedBox(height: 10),
          _classicRow('STARRING', movie.actors.isNotEmpty ? movie.actors.take(3).join(', ') : '--'),
          const SizedBox(height: 10),
          _classicRow('GENRE', movie.genres.isNotEmpty ? movie.genres.join(' / ') : '--'),
          const SizedBox(height: 10),
          _classicRow('RELEASE', movie.releaseDate != null ? _fmtDate(movie.releaseDate!) : '--'),
          if (movie.rating != null && movie.rating! > 0) ...[
            const SizedBox(height: 10),
            _classicRow('RATING', '${movie.rating!.toStringAsFixed(1)} / 10'),
          ],
          const SizedBox(height: 14),
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.2), width: 0.5)),
              child: Text(_statusEN(movie.status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 2, color: c.withValues(alpha: 0.5)))),
            const Spacer(),
            Icon(Icons.movie_outlined, size: 12, color: c.withValues(alpha: 0.3)),
            const SizedBox(width: 4),
            Text('MookNote', style: TextStyle(fontSize: 9, letterSpacing: 1, color: c.withValues(alpha: 0.3))),
          ]),
        ])),
      ]),
    );
  }

  Widget _classicRow(String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: const Color(0xFF2D2D2D).withValues(alpha: 0.35)))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D), height: 1.4))),
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // 样式 2：电影票（参考票根.html）
  // ═══════════════════════════════════════════════════════════

  Widget _buildTicketCinema() {
    final movie = widget.movie;
    const bg = Color(0xFFFFFDF7);
    const text = Color(0xFF1A1A1A);
    const muted = Color(0xFF999999);

    return Container(
      width: 340,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 6))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 14), child: Row(children: [
          Image.asset('assets/images/ticket/maoyan.png', width: 36, height: 36, errorBuilder: (_, __, ___) => Icon(Icons.local_movies, size: 36, color: text)),
          const SizedBox(width: 10),
          Text(_platformCtrl.text.isNotEmpty ? _platformCtrl.text : 'MookNote', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text, letterSpacing: 0.5)),
        ])),
        Container(height: 0.5, color: const Color(0xFFF0EDE5)),

        // Body
        Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 影院
          Text(_cinemaCtrl.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: text, letterSpacing: 0.5)),
          const SizedBox(height: 14),
          // 片名
          Text(movie.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: text, letterSpacing: 0.5, height: 1.3)),
          const SizedBox(height: 4),
          Text(_subtitleText(movie), style: const TextStyle(fontSize: 12, color: Color(0xFF666666), letterSpacing: 0.5)),
          const SizedBox(height: 16),
          // 场次
          Row(children: [
            Icon(Icons.desktop_windows_outlined, size: 15, color: text.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Text(_hallCtrl.text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: text.withValues(alpha: 0.8))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Text('${_seatRowCtrl.text}排${_seatNumCtrl.text}座', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: text.withValues(alpha: 0.8))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('|', style: TextStyle(color: const Color(0xFFD0CCC0), fontWeight: FontWeight.w300))),
            Text(widget.movie.releaseDate != null ? '${widget.movie.releaseDate!.year}年${widget.movie.releaseDate!.month}月${widget.movie.releaseDate!.day}日' : '待定', style: TextStyle(fontSize: 14, color: text.withValues(alpha: 0.6))),
          ]),
        ])),

        // 撕票线
        _tearScissors(bg),

        // Footer
        Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 16), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 100, height: 100, decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8E4DA), width: 0.5)),
            child: Image.asset('assets/images/ticket/qr.png', fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ticketDetail('票价', _priceCtrl.text, isPrice: true),
            _ticketDetail('服务费', _serviceFeeCtrl.text),
            _ticketDetail('出票日期', _issueTimeCtrl.text),
            _ticketDetail(_platformCtrl.text.isNotEmpty ? _platformCtrl.text : '平台', '已出票'),
            const SizedBox(height: 4),
            Text(_ticketCodeCtrl.text, style: TextStyle(fontFamily: 'monospace', fontSize: 9, letterSpacing: 0.8, color: muted)),
          ])),
        ])),
      ]),
    );
  }

  Widget _ticketDetail(String label, String value, {bool isPrice = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
      const Spacer(),
      Text(value, style: TextStyle(
        fontSize: isPrice ? 16 : 12,
        fontWeight: isPrice ? FontWeight.w700 : FontWeight.w500,
        color: isPrice ? const Color(0xFFE5342F) : const Color(0xFF1A1A1A),
      )),
    ]));
  }

  // ═══════════════════════════════════════════════════════════
  // 样式 3：收藏版票根（参考票根收藏版.html）
  // ═══════════════════════════════════════════════════════════

  Widget _buildTicketCollectible() {
    final movie = widget.movie;
    const red = Color(0xFFC0392B);
    const text = Color(0xFF1A1A1A);
    const light = Color(0xFF8C8C8C);
    const line = Color(0xFFE8E2D8);

    return Container(
      width: 360,
      decoration: BoxDecoration(color: const Color(0xFFFFFFFB),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 2)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 40, offset: const Offset(0, 8)),
        ]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // 红色头部
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: red,
          child: Row(children: [
            const Text('MookNote', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
            const Spacer(),
            Text('收藏纪念\nCOLLECTIBLE', textAlign: TextAlign.right,
              style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 0.5, height: 1.5)),
          ]),
        ),

        // 主体
        Padding(padding: const EdgeInsets.fromLTRB(24, 22, 24, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 影院
          Row(children: [
            Icon(Icons.location_on_outlined, size: 14, color: red),
            const SizedBox(width: 4),
            Text(_cinemaCtrl.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF6B6B6B), letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 16),
          // 标题
          Text(movie.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: text, letterSpacing: 0.5, height: 1.15)),
          const SizedBox(height: 6),
          // 标签
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (movie.genres.isNotEmpty) ...movie.genres.take(3).map((g) => _tagChip(g)),
            if (movie.releaseDate != null) _tagChip(_fmtDate(movie.releaseDate!)),
          ]),
          const SizedBox(height: 20),
          // 三列网格
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: line, width: 0.5), bottom: BorderSide(color: line, width: 0.5))),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              _gridCol('影厅', _hallCtrl.text, red),
              Container(width: 0.5, height: 36, color: const Color(0xFFF2EDE5)),
              _gridCol('座位', '${_seatRowCtrl.text}排${_seatNumCtrl.text}座', text),
              Container(width: 0.5, height: 36, color: const Color(0xFFF2EDE5)),
              _gridCol('上映', movie.releaseDate != null ? _fmtDate(movie.releaseDate!) : '--', red),
            ]),
          ),
        ])),

        // 撕票线（圆形缺口）
        _tearCircles(),

        // 底部信息
        Padding(padding: const EdgeInsets.fromLTRB(24, 10, 24, 0), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 120, height: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE8E2D8), width: 0.5)),
            child: Image.asset('assets/images/ticket/qr.png', fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox.shrink())),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [
            _collectInfo('票价', '¥${_priceCtrl.text}', isPrice: true),
            _collectInfo('服务费', '¥${_serviceFeeCtrl.text}'),
            _collectInfo('时间', _issueTimeCtrl.text),
            _collectInfo('平台', 'MookNote'),
            _collectInfo('编码', _ticketCodeCtrl.text, isCode: true),
          ])),
        ])),

        // 底部条
        Padding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 14), child: Row(children: [
          Text('MOOKNOTE MOVIE · TICKET', style: TextStyle(fontSize: 9, letterSpacing: 1, color: light.withValues(alpha: 0.7))),
          const Spacer(),
          Text(_ticketCodeCtrl.text, style: TextStyle(fontSize: 9, letterSpacing: 0.5, color: light.withValues(alpha: 0.7))),
        ])),
      ]),
    );
  }

  Widget _tagChip(String text) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEBE5D9), width: 0.5), borderRadius: BorderRadius.circular(3)),
      child: Text(text, style: const TextStyle(fontSize: 10, color: Color(0xFF6B6B6B), letterSpacing: 0.5)));
  }

  Widget _gridCol(String label, String value, Color valueColor) {
    return Expanded(child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8C8C8C), letterSpacing: 1)),
      const SizedBox(height: 4),
      Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor, letterSpacing: 0.5)),
    ]));
  }

  Widget _collectInfo(String label, String value, {bool isPrice = false, bool isCode = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [
      SizedBox(width: 32, child: Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8C8C8C), letterSpacing: 0.5))),
      Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(
        fontSize: isPrice ? 15 : 10,
        fontWeight: isPrice ? FontWeight.w700 : FontWeight.w500,
        color: isPrice ? const Color(0xFFC0392B) : const Color(0xFF1A1A1A).withValues(alpha: 0.8),
        fontFamily: isCode ? 'monospace' : null,
        letterSpacing: isCode ? 0.5 : 0,
      ))),
    ]));
  }

  // ─── 通用组件 ───

  Widget _dashedLine(Color color) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: color)));
  }

  Widget _tearScissors(Color bg) {
    return SizedBox(height: 28, child: Stack(children: [
      Positioned(left: 20, right: 20, top: 13, child: CustomPaint(
        size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: const Color(0xFFC8C4B8), dashWidth: 6, dashSpace: 8))),
      Positioned(left: 2, top: 4, child: Icon(Icons.content_cut, size: 16, color: const Color(0xFF999999))),
    ]));
  }

  Widget _tearCircles() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: SizedBox(height: 24, child: Stack(children: [
      Positioned(left: 0, right: 0, top: 11, child: CustomPaint(
        size: const Size(double.infinity, 1), painter: _DashedLinePainter(color: const Color(0xFFD8D0C0), dashWidth: 9, dashSpace: 9))),
      Positioned(left: -30, top: 5.5, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: const Color(0xFFEBE5DB), shape: BoxShape.circle))),
      Positioned(right: -30, top: 5.5, child: Container(width: 13, height: 13, decoration: BoxDecoration(color: const Color(0xFFEBE5DB), shape: BoxShape.circle))),
    ])));
  }

  String _fmtDate(DateTime d) => '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';

  String _subtitleText(Movie m) {
    final parts = <String>[];
    if (m.genres.isNotEmpty) parts.add(m.genres.join(' / '));
    return parts.join(' · ');
  }

  String _statusEN(String s) {
    switch (s) { case 'watched': return 'ADMITTED'; case 'watching': return 'NOW PLAYING'; default: return 'RESERVED'; }
  }

  // ─── 生成分享 ───

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);
    try {
      final boundary = _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('无法获取海报边界');
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('无法生成图片数据');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/movie_poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: '分享影视：${widget.movie.title}');
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
