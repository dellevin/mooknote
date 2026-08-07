import 'package:flutter/material.dart';

/// 已阅印章图标 — 双圈外圆 + 内框 + "已阅"文字
class ReviewedStampIcon extends StatelessWidget {
  final double size;
  final Color color;

  const ReviewedStampIcon({super.key, this.size = 20, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ReviewedStampPainter(color: color),
    );
  }
}

class _ReviewedStampPainter extends CustomPainter {
  final Color color;
  _ReviewedStampPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 1;

    // 外圈
    final outerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;
    canvas.drawCircle(Offset(cx, cy), r, outerPaint);

    // 内圈
    final innerPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03;
    canvas.drawCircle(Offset(cx, cy), r * 0.82, innerPaint);

    // "已阅" 文字
    final fontSize = size.width * 0.32;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '已阅',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          height: 1.1,
          letterSpacing: fontSize * 0.1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ReviewedStampPainter old) => old.color != color;
}
