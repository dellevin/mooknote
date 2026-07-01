import 'package:flutter/material.dart';

/// 选区手柄（起点和终点各一个），可拖动调整选区范围
///
/// 样式：光标竖线 + 大圆点
/// - 起点手柄：圆点在上，竖线向下连接到选区起点
/// - 终点手柄：竖线从选区终点向下延伸，圆点在下
class SelectionHandles extends StatelessWidget {
  final Offset? startPosition;
  final Offset? endPosition;
  final Function(DragUpdateDetails) onDragStart;
  final Function(DragUpdateDetails) onDragEnd;

  static const double _circleSize = 12.0;
  static const double _lineHeight = 20.0;
  static const double _lineWidth = 2.0;
  static const Color _handleColor = Color(0xFF4A90D9);

  const SelectionHandles({
    super.key,
    required this.startPosition,
    required this.endPosition,
    required this.onDragStart,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (startPosition != null) _buildStartHandle(startPosition!),
        if (endPosition != null) _buildEndHandle(endPosition!),
      ],
    );
  }

  /// 起点手柄：圆点在上 + 竖线向下
  /// startPosition 在文字行底部，手柄线覆盖文字行，圆点在文字上方
  Widget _buildStartHandle(Offset pos) {
    final totalHeight = _circleSize + _lineHeight;
    return Positioned(
      left: pos.dx - _circleSize / 2,
      top: pos.dy - totalHeight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onDragStart,
        child: SizedBox(
          width: _circleSize,
          height: totalHeight,
          child: Column(
            children: [
              _buildCircle(),
              _buildLine(),
            ],
          ),
        ),
      ),
    );
  }

  /// 终点手柄：竖线向下 + 圆点在下
  /// endPosition 在文字行顶部，手柄线覆盖文字行，圆点在文字下方
  Widget _buildEndHandle(Offset pos) {
    final totalHeight = _lineHeight + _circleSize;
    return Positioned(
      left: pos.dx - _circleSize / 2,
      top: pos.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: onDragEnd,
        child: SizedBox(
          width: _circleSize,
          height: totalHeight,
          child: Column(
            children: [
              _buildLine(),
              _buildCircle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircle() {
    return Container(
      width: _circleSize,
      height: _circleSize,
      decoration: BoxDecoration(
        color: _handleColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildLine() {
    return Container(
      width: _lineWidth,
      height: _lineHeight,
      color: _handleColor,
    );
  }
}
