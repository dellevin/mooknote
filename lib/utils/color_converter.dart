/// Dart ARGB 颜色字符串转换为 JS RGBA 格式
/// dartColor: "FF0066FF" (AARRGGBB) → jsColor: "0066FFFF" (RRGGBBAA)
String convertDartColorToJs(String dartColor) {
  if (dartColor.length < 8) return dartColor;
  return dartColor.substring(2) + dartColor.substring(0, 2);
}
