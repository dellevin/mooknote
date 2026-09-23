import 'dart:convert';
import 'package:path/path.dart' as p;
import 'inc_entities.dart';

/// 行内图片路径的逻辑化/本地化处理
class IncRowCodec {
  /// 本机 images 根目录绝对路径
  final String imagesRoot;

  IncRowCodec(this.imagesRoot);

  /// 任意设备的绝对路径 → images/ 下逻辑路径
  static String toLogical(String absPath) {
    final normalized = absPath.replaceAll('\\', '/');
    final idx = normalized.indexOf('/images/');
    if (idx >= 0) return normalized.substring(idx + 8); // skip '/images/'
    return p.basename(absPath);
  }

  /// 逻辑路径 → 本机绝对路径
  String localPathOf(String logical) => p.join(imagesRoot, logical);

  /// 将远程行内图片路径改写为本机绝对路径
  Map<String, dynamic> localize(Map<String, dynamic> row, IncEntitySpec spec) {
    final out = Map<String, dynamic>.from(row);
    for (final col in spec.imageColumns) {
      final v = out[col];
      if (v is String && v.isNotEmpty) {
        out[col] = localPathOf(toLogical(v));
      }
    }
    final jsonCol = spec.imageJsonColumn;
    if (jsonCol != null) {
      final v = out[jsonCol];
      if (v is String && v.isNotEmpty) {
        try {
          final list = jsonDecode(v) as List;
          out[jsonCol] = jsonEncode(list
              .whereType<String>()
              .map((e) => localPathOf(toLogical(e)))
              .toList());
        } catch (_) {}
      }
    }
    return out;
  }

  /// 将子表行内图片路径改写为本机绝对路径
  List<Map<String, dynamic>> localizeGroupRows(
    String groupTable,
    List<Map<String, dynamic>> rows,
  ) {
    final imgCol = groupTable == 'movie_posters'
        ? 'poster_path'
        : groupTable == 'game_screenshots'
            ? 'screenshot_path'
            : null;
    if (imgCol == null) return rows;
    return rows.map((r) {
      final out = Map<String, dynamic>.from(r);
      final v = out[imgCol];
      if (v is String && v.isNotEmpty) {
        out[imgCol] = localPathOf(toLogical(v));
      }
      return out;
    }).toList();
  }

  /// 收集行当前引用的逻辑路径
  List<String> referencedLogical(Map<String, dynamic> row, IncEntitySpec spec) {
    final result = <String>{};
    for (final col in spec.imageColumns) {
      final v = row[col];
      if (v is String && v.isNotEmpty) result.add(toLogical(v));
    }
    final jsonCol = spec.imageJsonColumn;
    if (jsonCol != null) {
      final v = row[jsonCol];
      if (v is String && v.isNotEmpty) {
        try {
          for (final e in jsonDecode(v) as List) {
            if (e is String && e.isNotEmpty) result.add(toLogical(e));
          }
        } catch (_) {}
      }
    }
    return result.toList();
  }
}
