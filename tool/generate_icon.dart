// ignore_for_file: avoid_print
// Generates a 512x512 PNG icon using raw pixel manipulation.
// No dart:ui dependency — runs with plain `dart run`.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

void main() {
  const int sz = 512;
  // RGBA buffer
  final pixels = Uint8List(sz * sz * 4);

  // Fill blue background
  for (int i = 0; i < sz * sz; i++) {
    pixels[i * 4 + 0] = 0x25; // R
    pixels[i * 4 + 1] = 0x63; // G
    pixels[i * 4 + 2] = 0xEB; // B
    pixels[i * 4 + 3] = 0xFF; // A
  }

  // Dumbbell geometry (centered, pre-rotation coordinates)
  const double cx = sz / 2;
  const double cy = sz / 2;
  const double barW = 152, barH = 38;
  const double lpW = 42, lpH = 152; // large plate
  const double spW = 32, spH = 114; // small plate
  const double r = 6; // corner radius

  // Define rectangles relative to center
  final rects = <List<double>>[
    // [cx, cy, width, height] of each piece
    [cx, cy, barW, barH],
    [cx - barW / 2 - lpW / 2 - 2, cy, lpW, lpH],
    [cx - barW / 2 - lpW - spW / 2 - 6, cy, spW, spH],
    [cx + barW / 2 + lpW / 2 + 2, cy, lpW, lpH],
    [cx + barW / 2 + lpW + spW / 2 + 6, cy, spW, spH],
  ];

  const double angle = pi / 4; // 45 degrees
  final cosA = cos(angle);
  final sinA = sin(angle);

  // For each pixel, check if it falls inside any rotated rectangle
  for (int y = 0; y < sz; y++) {
    for (int x = 0; x < sz; x++) {
      // Rotate point back to pre-rotation space
      final dx = x - cx;
      final dy = y - cy;
      final rx = dx * cosA + dy * sinA + cx;
      final ry = -dx * sinA + dy * cosA + cy;

      for (final rect in rects) {
        final rcx = rect[0], rcy = rect[1];
        final hw = rect[2] / 2, hh = rect[3] / 2;
        final left = rcx - hw, right = rcx + hw;
        final top = rcy - hh, bottom = rcy + hh;

        // Rounded rect check
        if (rx >= left && rx <= right && ry >= top && ry <= bottom) {
          // Check corners for rounding
          bool inside = true;
          if (rx < left + r && ry < top + r) {
            inside = _dist(rx, ry, left + r, top + r) <= r;
          } else if (rx > right - r && ry < top + r) {
            inside = _dist(rx, ry, right - r, top + r) <= r;
          } else if (rx < left + r && ry > bottom - r) {
            inside = _dist(rx, ry, left + r, bottom - r) <= r;
          } else if (rx > right - r && ry > bottom - r) {
            inside = _dist(rx, ry, right - r, bottom - r) <= r;
          }

          if (inside) {
            final idx = (y * sz + x) * 4;
            pixels[idx + 0] = 0xFF; // R (white)
            pixels[idx + 1] = 0xFF; // G
            pixels[idx + 2] = 0xFF; // B
            pixels[idx + 3] = 0xFF; // A
            break;
          }
        }
      }
    }
  }

  // Encode as PNG
  final png = _encodePng(sz, sz, pixels);
  final file = File('store_assets/app_icon_512.png');
  file.writeAsBytesSync(png);
  print('Generated ${file.path} (${png.length} bytes)');
}

double _dist(double x1, double y1, double x2, double y2) {
  return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

// Minimal PNG encoder for RGBA data
Uint8List _encodePng(int w, int h, Uint8List rgba) {
  // Build IDAT raw data (filter byte 0 = None for each row)
  final raw = BytesBuilder();
  for (int y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final rawBytes = raw.toBytes();
  final compressed = zlib.encode(rawBytes);

  final out = BytesBuilder();

  // PNG signature
  out.add([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR
  final ihdr = ByteData(13);
  ihdr.setUint32(0, w);
  ihdr.setUint32(4, h);
  ihdr.setUint8(8, 8); // bit depth
  ihdr.setUint8(9, 6); // color type: RGBA
  ihdr.setUint8(10, 0); // compression
  ihdr.setUint8(11, 0); // filter
  ihdr.setUint8(12, 0); // interlace
  _writeChunk(out, 'IHDR', ihdr.buffer.asUint8List());

  // IDAT
  _writeChunk(out, 'IDAT', Uint8List.fromList(compressed));

  // IEND
  _writeChunk(out, 'IEND', Uint8List(0));

  return out.toBytes();
}

void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  final lenBytes = ByteData(4)..setUint32(0, data.length);
  out.add(lenBytes.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);

  // CRC32 over type + data
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
