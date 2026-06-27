/// 将归一化坐标 (0-1) 映射到 3x3 九宫格区域 (0-8)
///
/// ```
/// 0  1  2
/// 3  4  5
/// 6  7  8
/// ```
int coordinatesToPart(double x, double y) {
  final col = x < 0.33 ? 0 : (x < 0.66 ? 1 : 2);
  final row = y < 0.33 ? 0 : (y < 0.66 ? 1 : 2);
  return row * 3 + col;
}
