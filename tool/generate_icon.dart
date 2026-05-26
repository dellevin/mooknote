import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  final outputDir = Directory('assets/icon');
  if (!outputDir.existsSync()) outputDir.createSync(recursive: true);

  final bytes1024 = generateIcon(1024);
  File('${outputDir.path}/app_icon_m.png').writeAsBytesSync(bytes1024);
  print('Generated app_icon_m.png (1024×1024)');

  final androidMipmapDir = 'android/app/src/main/res';
  final densities = {
    'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192,
  };
  for (final entry in densities.entries) {
    final dir = Directory('$androidMipmapDir/${entry.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('${dir.path}/ic_launcher_m.png').writeAsBytesSync(generateIcon(entry.value));
    print('Generated ${entry.key}/ic_launcher_m.png');
  }
  print('Done!');
}

Uint8List generateIcon(int size) {
  final bm = _Bitmap(size, size);

  // 透明背景
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      bm.setPixel(x, y, 0, 0, 0, 0);
    }
  }

  // 圆角黑底
  final cr = (size * 0.22).round();
  _fillRoundedRect(bm, 0, 0, size, size, cr, 0, 0, 0, 255);

  // 绘制标准 M
  _drawStandardM(bm);

  return _encodePng(bm);
}

/// 用扫描线 + 区间运算绘制标准 M
void _drawStandardM(_Bitmap bm) {
  const int r = 255, g = 255, b = 255, a = 255;
  final size = bm.width;

  final letterW = size * 0.36;
  final letterH = size * 0.38;
  final stroke = letterW * 0.24;

  final cx = size / 2.0;
  final cy = size / 2.0;
  final hw = letterW / 2.0;
  final hh = letterH / 2.0;
  final hs = stroke / 2.0;

  final top = cy - hh;
  final bot = cy + hh;
  final leftOuter  = cx - hw - hs;
  final leftInner  = cx - hw + hs;
  final rightInner = cx + hw - hs;
  final rightOuter = cx + hw + hs;
  final botC = bot; // 对角线与竖笔底边齐平

  // V 形切口的底端 y
  final vBotY = cy - hh * 0.15;
  // V 形在 vBotY 处的半宽
  final vBotHW = hw * 0.30;

  final minY = top.floor().clamp(0, size - 1);
  final maxY = botC.ceil().clamp(0, size - 1);

  for (int y = minY; y <= maxY; y++) {
    // 该行的像素掩码
    final row = List.filled(size, false);

    // ── 填充各部件 ──

    // 左竖笔
    if (y >= top && y <= bot) {
      _setRange(row, leftOuter, leftInner);
    }
    // 右竖笔
    if (y >= top && y <= bot) {
      _setRange(row, rightInner, rightOuter);
    }
    // 左对角线（左边缘从 bar 外缘开始，保持连续无断裂）
    if (y >= top && y <= botC) {
      final t = (y - top) / (botC - top);
      final l = leftOuter + (cx - hs - leftOuter) * t;
      final r = leftInner + (cx + hs - leftInner) * t;
      _setRange(row, l, r);
    }
    // 右对角线（右边缘从 bar 外缘开始，保持连续无断裂）
    if (y >= top && y <= botC) {
      final t = (y - top) / (botC - top);
      final l = rightInner + (cx - hs - rightInner) * t;
      final r = rightOuter + (cx + hs - rightOuter) * t;
      _setRange(row, l, r);
    }
    // V 形切口（清除中心区域）
    if (y >= top && y <= vBotY) {
      final vt = (y - top) / (vBotY - top);
      final vw = vBotHW * vt; // V 宽度随 y 增大而增大
      _clearRange(row, cx - vw, cx + vw);
    }

    // ── 输出 ──
    _fillRowFromMask(bm, row, y, r, g, b, a);
  }
}

void _setRange(List<bool> row, double from, double to) {
  final a = from.round().clamp(0, row.length - 1);
  final b = to.round().clamp(0, row.length - 1);
  final start = math.min(a, b);
  final end = math.max(a, b);
  for (int i = start; i <= end; i++) {
    row[i] = true;
  }
}

void _clearRange(List<bool> row, double from, double to) {
  final a = from.round().clamp(0, row.length - 1);
  final b = to.round().clamp(0, row.length - 1);
  final start = math.min(a, b);
  final end = math.max(a, b);
  for (int i = start; i <= end; i++) {
    row[i] = false;
  }
}

void _fillRowFromMask(_Bitmap bm, List<bool> row, int y, int r, int g, int b, int a) {
  for (int x = 0; x < row.length; x++) {
    if (row[x]) bm.setPixel(x, y, r, g, b, a);
  }
}

// ═══════════════════════════════════════════════════════════════════

void _fillRoundedRect(_Bitmap bm, int x, int y, int w, int h, int rr, int r, int g, int b, int a) {
  final radius = rr.clamp(0, math.min(w, h) ~/ 2);
  for (int dy = 0; dy < h; dy++) {
    for (int dx = 0; dx < w; dx++) {
      bool inside = true;
      if (dx < radius && dy < radius) {
        inside = math.sqrt((radius - dx) * (radius - dx) + (radius - dy) * (radius - dy)) <= radius;
      } else if (dx >= w - radius && dy < radius) {
        inside = math.sqrt((dx - (w - radius - 1)) * (dx - (w - radius - 1)) + (radius - dy) * (radius - dy)) <= radius;
      } else if (dx < radius && dy >= h - radius) {
        inside = math.sqrt((radius - dx) * (radius - dx) + (dy - (h - radius - 1)) * (dy - (h - radius - 1))) <= radius;
      } else if (dx >= w - radius && dy >= h - radius) {
        inside = math.sqrt((dx - (w - radius - 1)) * (dx - (w - radius - 1)) + (dy - (h - radius - 1)) * (dy - (h - radius - 1))) <= radius;
      }
      if (inside) bm.setPixel(x + dx, y + dy, r, g, b, a);
    }
  }
}

// ── Bitmap ────────────────────────────────────────────────────────

class _Bitmap {
  final int width, height;
  final Uint8List data;
  _Bitmap(this.width, this.height) : data = Uint8List(width * height * 4);
  void setPixel(int x, int y, int r, int g, int b, int a) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    final o = (y * width + x) * 4;
    data[o] = r; data[o + 1] = g; data[o + 2] = b; data[o + 3] = a;
  }
}

// ── PNG Encoder ───────────────────────────────────────────────────

Uint8List _encodePng(_Bitmap bm) {
  final w = bm.width, h = bm.height;
  final raw = <int>[];
  for (int y = 0; y < h; y++) {
    raw.add(0);
    raw.addAll(bm.data.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final deflated = ZLibEncoder().convert(raw);
  final buf = BytesBuilder();
  buf.add(_chunk('IHDR', [..._be32(w), ..._be32(h), 8, 6, 0, 0, 0]));
  buf.add(_chunk('IDAT', deflated));
  buf.add(_chunk('IEND', []));
  return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, ...buf.toBytes()]);
}

List<int> _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  return [..._be32(data.length), ...body, ..._be32(_crc32(body))];
}

List<int> _be32(int v) => [(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];

int _crc32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (final b in data) { crc ^= b; for (int i = 0; i < 8; i++) crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : (crc >> 1); }
  return crc ^ 0xFFFFFFFF;
}
