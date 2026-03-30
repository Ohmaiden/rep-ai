// ignore_for_file: avoid_print
// Generates a 1024x500 feature graphic PNG for Google Play Store.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  const int w = 1024;
  const int h = 500;
  final pixels = Uint8List(w * h * 4);

  // Gradient background: #2563EB at top → #1D4ED8 at bottom
  for (int y = 0; y < h; y++) {
    final t = y / h;
    final r = _lerp(0x25, 0x1D, t);
    final g = _lerp(0x63, 0x4E, t);
    final b = _lerp(0xEB, 0xD8, t);
    for (int x = 0; x < w; x++) {
      final idx = (y * w + x) * 4;
      pixels[idx + 0] = r;
      pixels[idx + 1] = g;
      pixels[idx + 2] = b;
      pixels[idx + 3] = 0xFF;
    }
  }

  // Draw "Rep AI" text — large bold block letters on the left
  _drawText(pixels, w, h, 'Rep AI', 120, 155, 80);
  // Tagline
  _drawText(pixels, w, h, 'Only good form counts', 120, 265, 28);

  // Dumbbell on the right side, 120px from right edge
  _drawDumbbell(pixels, w, h, 816, 220, 0.55);

  final png = _encodePng(w, h, pixels);
  final file = File('store_assets/feature_graphic.png');
  file.writeAsBytesSync(png);
  print('Generated ${file.path} (${png.length} bytes)');
}

int _lerp(int a, int b, double t) => (a + (b - a) * t).round().clamp(0, 255);

// Simple bitmap font renderer using hardcoded 5x7 pixel font
void _drawText(Uint8List pixels, int imgW, int imgH, String text, int startX,
    int startY, int fontSize) {
  // Scale factor from base 7px height
  final scale = (fontSize / 7).round().clamp(1, 20);
  var curX = startX;

  for (final ch in text.split('')) {
    final glyph = _glyphs[ch.toUpperCase()] ?? _glyphs[' ']!;
    for (int gy = 0; gy < 7; gy++) {
      for (int gx = 0; gx < 5; gx++) {
        if (glyph[gy][gx] == 1) {
          // Draw a scale x scale block
          for (int dy = 0; dy < scale; dy++) {
            for (int dx = 0; dx < scale; dx++) {
              final px = curX + gx * scale + dx;
              final py = startY + gy * scale + dy;
              if (px >= 0 && px < imgW && py >= 0 && py < imgH) {
                final idx = (py * imgW + px) * 4;
                pixels[idx + 0] = 0xFF;
                pixels[idx + 1] = 0xFF;
                pixels[idx + 2] = 0xFF;
                pixels[idx + 3] = 0xFF;
              }
            }
          }
        }
      }
    }
    curX += 6 * scale; // 5 wide + 1 gap
  }
}

void _drawDumbbell(
    Uint8List pixels, int imgW, int imgH, double cx, double cy, double sc) {
  const double barW = 152, barH = 38;
  const double lpW = 42, lpH = 152;
  const double spW = 32, spH = 114;
  const double r = 6;

  final rects = <List<double>>[
    [cx, cy, barW * sc, barH * sc],
    [cx - barW * sc / 2 - lpW * sc / 2 - 2 * sc, cy, lpW * sc, lpH * sc],
    [cx - barW * sc / 2 - lpW * sc - spW * sc / 2 - 6 * sc, cy, spW * sc, spH * sc],
    [cx + barW * sc / 2 + lpW * sc / 2 + 2 * sc, cy, lpW * sc, lpH * sc],
    [cx + barW * sc / 2 + lpW * sc + spW * sc / 2 + 6 * sc, cy, spW * sc, spH * sc],
  ];

  const double angle = pi / 4;
  final cosA = cos(angle);
  final sinA = sin(angle);
  final rs = r * sc;

  // Bounding box for dumbbell area
  final minX = (cx - 160 * sc).floor().clamp(0, imgW);
  final maxX = (cx + 160 * sc).ceil().clamp(0, imgW);
  final minY = (cy - 160 * sc).floor().clamp(0, imgH);
  final maxY = (cy + 160 * sc).ceil().clamp(0, imgH);

  for (int y = minY; y < maxY; y++) {
    for (int x = minX; x < maxX; x++) {
      final dx = x - cx;
      final dy = y - cy;
      final rx = dx * cosA + dy * sinA + cx;
      final ry = -dx * sinA + dy * cosA + cy;

      for (final rect in rects) {
        final rcx = rect[0], rcy = rect[1];
        final hw = rect[2] / 2, hh = rect[3] / 2;
        final left = rcx - hw, right = rcx + hw;
        final top = rcy - hh, bottom = rcy + hh;

        if (rx >= left && rx <= right && ry >= top && ry <= bottom) {
          bool inside = true;
          if (rx < left + rs && ry < top + rs) {
            inside = _dist(rx, ry, left + rs, top + rs) <= rs;
          } else if (rx > right - rs && ry < top + rs) {
            inside = _dist(rx, ry, right - rs, top + rs) <= rs;
          } else if (rx < left + rs && ry > bottom - rs) {
            inside = _dist(rx, ry, left + rs, bottom - rs) <= rs;
          } else if (rx > right - rs && ry > bottom - rs) {
            inside = _dist(rx, ry, right - rs, bottom - rs) <= rs;
          }

          if (inside) {
            final idx = (y * imgW + x) * 4;
            pixels[idx + 0] = 0xFF;
            pixels[idx + 1] = 0xFF;
            pixels[idx + 2] = 0xFF;
            pixels[idx + 3] = 0xFF;
            break;
          }
        }
      }
    }
  }
}

double _dist(double x1, double y1, double x2, double y2) =>
    sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

// 5x7 pixel font glyphs
final Map<String, List<List<int>>> _glyphs = {
  'A': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1]],
  'B': [[1,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,0]],
  'C': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,1],[0,1,1,1,0]],
  'D': [[1,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,0]],
  'E': [[1,1,1,1,1],[1,0,0,0,0],[1,0,0,0,0],[1,1,1,1,0],[1,0,0,0,0],[1,0,0,0,0],[1,1,1,1,1]],
  'F': [[1,1,1,1,1],[1,0,0,0,0],[1,0,0,0,0],[1,1,1,1,0],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0]],
  'G': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,0],[1,0,1,1,1],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
  'H': [[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1]],
  'I': [[1,1,1,1,1],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[1,1,1,1,1]],
  'L': [[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0],[1,1,1,1,1]],
  'M': [[1,0,0,0,1],[1,1,0,1,1],[1,0,1,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1]],
  'N': [[1,0,0,0,1],[1,1,0,0,1],[1,0,1,0,1],[1,0,0,1,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1]],
  'O': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
  'P': [[1,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,0],[1,0,0,0,0],[1,0,0,0,0],[1,0,0,0,0]],
  'R': [[1,1,1,1,0],[1,0,0,0,1],[1,0,0,0,1],[1,1,1,1,0],[1,0,1,0,0],[1,0,0,1,0],[1,0,0,0,1]],
  'S': [[0,1,1,1,0],[1,0,0,0,1],[1,0,0,0,0],[0,1,1,1,0],[0,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
  'T': [[1,1,1,1,1],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0]],
  'U': [[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[1,0,0,0,1],[0,1,1,1,0]],
  'Y': [[1,0,0,0,1],[1,0,0,0,1],[0,1,0,1,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0],[0,0,1,0,0]],
  ' ': [[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0],[0,0,0,0,0]],
};

// PNG encoder
Uint8List _encodePng(int w, int h, Uint8List rgba) {
  final raw = BytesBuilder();
  for (int y = 0; y < h; y++) {
    raw.addByte(0);
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final compressed = zlib.encode(raw.toBytes());
  final out = BytesBuilder();
  out.add([137, 80, 78, 71, 13, 10, 26, 10]);
  final ihdr = ByteData(13);
  ihdr.setUint32(0, w);
  ihdr.setUint32(4, h);
  ihdr.setUint8(8, 8);
  ihdr.setUint8(9, 6);
  ihdr.setUint8(10, 0);
  ihdr.setUint8(11, 0);
  ihdr.setUint8(12, 0);
  _writeChunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _writeChunk(out, 'IDAT', Uint8List.fromList(compressed));
  _writeChunk(out, 'IEND', Uint8List(0));
  return out.toBytes();
}

void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  final lenBytes = ByteData(4)..setUint32(0, data.length);
  out.add(lenBytes.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);
  final crcData = Uint8List(typeBytes.length + data.length);
  crcData.setAll(0, typeBytes);
  crcData.setAll(typeBytes.length, data);
  final crc = ByteData(4)..setUint32(0, _crc32(crcData));
  out.add(crc.buffer.asUint8List());
}

int _crc32(Uint8List data) {
  var crc = 0xFFFFFFFF;
  for (final b in data) {
    crc ^= b;
    for (int i = 0; i < 8; i++) {
      if (crc & 1 != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc ^ 0xFFFFFFFF;
}
