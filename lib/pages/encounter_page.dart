import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/user_prefs.dart';

/// 相遇统计页
class EncounterPage extends StatelessWidget {
  const EncounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final userPrefs = UserPrefs();
    final firstUse = userPrefs.firstUseDate;
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(firstUse.year, firstUse.month, firstUse.day))
        .inDays + 1;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('统计')),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          final movies = provider.movies.where((m) => !m.isDeleted).toList();
          final books = provider.books.where((b) => !b.isDeleted).toList();
          final notes = provider.notes.where((n) => !n.isDeleted).toList();

          final noteWords = notes.fold<int>(0, (sum, n) => sum + n.content.length);
          int imageCount = 0;
          for (final m in movies) {
            if (m.posterPath != null && m.posterPath!.isNotEmpty) imageCount++;
          }
          for (final b in books) {
            if (b.coverPath != null && b.coverPath!.isNotEmpty) imageCount++;
          }
          for (final n in notes) {
            imageCount += n.images.length;
          }

          final totalRecords = movies.length + books.length + notes.length;

          return CustomScrollView(
            slivers: [
              // 上半部分：与你 + 天数
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      Text(
                        '与你',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '相遇的第',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            TextSpan(
                              text: '$days',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: colors.primary,
                              ),
                            ),
                            TextSpan(
                              text: '天',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${firstUse.year}年${firstUse.month}月${firstUse.day}日 — ${now.year}年${now.month}月${now.day}日',
                        style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.3)),
                      ),
                    ],
                  ),
                ),
              ),
              // 下半部分：用 SliverFillRemaining 推到底部
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Divider(color: colors.outlineVariant, thickness: 0.5),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statItem(context, '${movies.length}', '影视', Icons.movie_outlined),
                          _statItem(context, '${books.length}', '书籍', Icons.menu_book_outlined),
                          _statItem(context, '${notes.length}', '笔记', Icons.note_outlined),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Divider(color: colors.outlineVariant, thickness: 0.5),
                      const SizedBox(height: 24),
                      Text(
                        '已记录',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface.withValues(alpha: 0.5),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _recordItem(context, '$totalRecords', '条记录'),
                          _recordItem(context, _formatCount(noteWords), '文字'),
                          _recordItem(context, '$imageCount', '张图片'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Divider(color: colors.outlineVariant, thickness: 0.5),
                      const SizedBox(height: 32),
                      _buildCuteAnimation(colors),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }

  Widget _statItem(BuildContext context, String value, String label, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: colors.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: colors.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
        ),
      ],
    );
  }

  Widget _recordItem(BuildContext context, String value, String label) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: colors.primary),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: colors.onSurface.withValues(alpha: 0.4)),
        ),
      ],
    );
  }

  /// 慢速滚动城市天际线
  Widget _buildCuteAnimation(ColorScheme colors) {
    return SizedBox(
      height: 72,
      child: _CityScape(colors: colors),
    );
  }
}

class _CityScape extends StatefulWidget {
  final ColorScheme colors;
  const _CityScape({required this.colors});

  @override
  State<_CityScape> createState() => _CityScapeState();
}

class _CityScapeState extends State<_CityScape> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(double.infinity, 72),
          painter: _CityPainter(_controller.value, widget.colors),
        );
      },
    );
  }
}

class _CityPainter extends CustomPainter {
  final double t;
  final ColorScheme colors;
  _CityPainter(this.t, this.colors);

  // 后层建筑数据（高度比, 宽度, 是否尖顶）
  static const _buildings = <(double, double, bool)>[
    (0.30, 16, false),
    (0.48, 10, true),
    (0.22, 20, false),
    (0.55, 10, true),
    (0.35, 14, false),
    (0.42, 10, true),
    (0.25, 18, false),
  ];

  // 前层绿植数据（高度比, 宽度, 类型: 0=圆冠, 1=松树, 2=灌木）
  static const _plants = <(double, double, int)>[
    (0.35, 10, 0),
    (0.50, 8, 1),
    (0.22, 14, 2),
    (0.45, 8, 0),
    (0.30, 12, 1),
    (0.20, 10, 2),
    (0.52, 8, 1),
    (0.28, 14, 2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final groundY = size.height - 2;

    // 星星
    _drawStars(canvas, paint, size, t);

    // 后层建筑（慢 0.3x，浅色）
    _drawBuildings(canvas, paint, size, groundY, t * 0.6);

    // 前层绿植（快 1.5x，深色）
    _drawPlants(canvas, paint, size, groundY, t * 1.0);

    // 地面线
    paint.color = colors.onSurface.withValues(alpha: 0.10);
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.width, 1), paint);
  }

  // ── 后层：建筑 ──

  void _drawBuildings(Canvas canvas, Paint paint, Size size, double groundY, double scrollT) {
    double totalW = 0;
    for (final b in _buildings) {
      totalW += b.$2 + 4;
    }
    final offset = (scrollT * totalW) % totalW;

    double x = -offset;
    int i = 0;
    while (x < size.width + 20) {
      final (hR, w, spire) = _buildings[i % _buildings.length];
      final h = hR * (size.height - 8);
      final bx = x;
      final by = groundY - h;

      if (bx + w > -10 && bx < size.width + 10) {
        final a = 0.06 + hR * 0.05;
        paint.color = colors.onSurface.withValues(alpha: a);
        canvas.drawRect(Rect.fromLTWH(bx, by, w, h), paint);

        // 窗户
        if (h > 18) {
          paint.color = colors.onSurface.withValues(alpha: 0.04);
          for (int r = 0; r < ((h - 6) / 5).floor(); r++) {
            for (int c = 0; c < ((w - 4) / 4).floor(); c++) {
              if ((i * 13 + r * 7 + c * 11) % 4 == 0) continue;
              canvas.drawRect(Rect.fromLTWH(bx + 3 + c * 4.0, by + 4 + r * 5.0, 2, 2), paint);
            }
          }
        }

        if (spire) {
          paint.color = colors.onSurface.withValues(alpha: a);
          final sh = h * 0.18;
          canvas.drawPath(
            Path()
              ..moveTo(bx + w / 2 - 2, by)
              ..lineTo(bx + w / 2, by - sh)
              ..lineTo(bx + w / 2 + 2, by)
              ..close(),
            paint,
          );
        }

        if (!spire && hR > 0.4 && i % 3 == 0) {
          paint.color = colors.onSurface.withValues(alpha: a * 0.5);
          canvas.drawRect(Rect.fromLTWH(bx + w / 2 - 0.5, by - 6, 1, 6), paint);
          canvas.drawCircle(Offset(bx + w / 2, by - 6), 1.2, paint);
        }
      }
      x += w + 16;
      i++;
    }
  }

  // ── 前层：绿植 ──

  void _drawPlants(Canvas canvas, Paint paint, Size size, double groundY, double scrollT) {
    double totalW = 0;
    for (final p in _plants) {
      totalW += p.$2 + 6;
    }
    final offset = (scrollT * totalW) % totalW;

    double x = -offset;
    int i = 0;
    while (x < size.width + 20) {
      final (hR, w, type) = _plants[i % _plants.length];
      final h = hR * (size.height - 10);
      final bx = x;
      final by = groundY;

      if (bx + w > -10 && bx < size.width + 10) {
        final alpha = 0.18 + hR * 0.10;

        if (type == 0) {
          // 圆冠树
          final trunkH = h * 0.4;
          final crownR = w * 0.45;
          paint.color = colors.onSurface.withValues(alpha: alpha * 0.7);
          canvas.drawRect(Rect.fromLTWH(bx + w / 2 - 1.5, by - trunkH, 3, trunkH), paint);
          paint.color = colors.onSurface.withValues(alpha: alpha);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(bx + w / 2, by - trunkH - crownR * 0.6), width: crownR * 2, height: crownR * 1.6),
            paint,
          );
        } else if (type == 1) {
          // 松树
          final trunkH = h * 0.25;
          paint.color = colors.onSurface.withValues(alpha: alpha * 0.7);
          canvas.drawRect(Rect.fromLTWH(bx + w / 2 - 1.5, by - trunkH, 3, trunkH), paint);
          paint.color = colors.onSurface.withValues(alpha: alpha);
          for (int layer = 0; layer < 3; layer++) {
            final layerW = w * (1.0 - layer * 0.2);
            final layerBottom = by - trunkH - layer * (h * 0.2);
            final layerTop = layerBottom - h * 0.28;
            canvas.drawPath(
              Path()
                ..moveTo(bx + w / 2 - layerW / 2, layerBottom)
                ..lineTo(bx + w / 2, layerTop)
                ..lineTo(bx + w / 2 + layerW / 2, layerBottom)
                ..close(),
              paint,
            );
          }
        } else {
          // 灌木
          paint.color = colors.onSurface.withValues(alpha: alpha);
          canvas.drawOval(Rect.fromLTWH(bx, by - h, w, h), paint);
          paint.color = colors.onSurface.withValues(alpha: alpha * 0.8);
          canvas.drawOval(Rect.fromLTWH(bx + w * 0.2, by - h * 0.7, w * 0.6, h * 0.6), paint);
        }
      }
      x += w + 14;
      i++;
    }
  }

  void _drawStars(Canvas canvas, Paint paint, Size size, double t) {
    const stars = [
      (12.0, 5.0, 1.2), (38.0, 12.0, 0.8), (65.0, 3.0, 1.0),
      (95.0, 16.0, 1.4), (130.0, 7.0, 0.9), (165.0, 14.0, 1.1),
      (200.0, 4.0, 1.3), (235.0, 18.0, 0.7), (270.0, 9.0, 1.0),
      (310.0, 2.0, 1.2), (345.0, 15.0, 0.9), (380.0, 6.0, 1.1),
      (420.0, 11.0, 0.8), (460.0, 3.0, 1.0), (500.0, 17.0, 1.3),
    ];
    for (int i = 0; i < stars.length; i++) {
      final (sx, sy, r) = stars[i];
      if (sx > size.width) continue;
      final flicker = 0.15 + 0.12 * sin(t * 2 * pi + i * 1.1);
      paint.color = colors.onSurface.withValues(alpha: flicker);
      canvas.drawCircle(Offset(sx, sy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) => old.t != t;
}
