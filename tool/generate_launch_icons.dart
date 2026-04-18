// ignore_for_file: avoid_print
/// Generates squircle-masked launch screen icons for iOS at 1x, 2x, 3x.
/// Matches the App Store marketing icon: blue gradient + white dumbbell + squircle.
///
/// Run from the project root:
///   dart run tool/generate_launch_icons.dart
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';

// Gradient colours matching generate_marketing_icon.py
const _topR = 59, _topG = 130, _topB = 246; // #3B82F6
const _botR = 29, _botG = 78, _botB = 216; // #1D4ED8

// iOS squircle exponent (Apple's ~G2-continuous mask approximation)
const double _squircleN = 5.0;

void main() {
  for (final scale in [1, 2, 3]) {
    final sz = 80 * scale; // 80, 160, 240
    final filename =
        scale == 1 ? 'LaunchImage.png' : 'LaunchImage@${scale}x.png';
    final path =
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/$filename';

    final pixels = _generateIcon(sz);
    final png = _encodePng(sz, sz, pixels);
    File(path).writeAsBytesSync(png);
    print('Generated $path (${png.length} bytes)');
  }
  print('Done.');
}

Uint8List _generateIcon(int sz) {
  final pixels = Uint8List(sz * sz * 4);
  final double cx = sz / 2;
  final double cy = sz / 2;
  final double r = sz / 2;

  // --- Pass 1: gradient fill with squircle mask ---
  for (int y = 0; y < sz; y++) {
    for (int x = 0; x < sz; x++) {
      final idx = (y * sz + x) * 4;

      // Normalise to [-1, 1]
      final dx = (x - cx) / r;
      final dy = (y - cy) / r;

      // Squircle: outside = transparent
      if (pow(dx.abs(), _squircleN) + pow(dy.abs(), _squircleN) > 1.0) {
        // alpha stays 0
        continue;
      }

      // Vertical gradient
      final t = y / (sz - 1);
      pixels[idx + 0] = (_topR + (_botR - _topR) * t).round().clamp(0, 255);
      pixels[idx + 1] = (_topG + (_botG - _topG) * t).round().clamp(0, 255);
      pixels[idx + 2] = (_topB + (_botB - _topB) * t).round().clamp(0, 255);
      pixels[idx + 3] = 0xFF;
    }
  }

  // --- Pass 2: draw white dumbbell ---
  _drawDumbbell(pixels, sz, cx, cy);

  // --- Pass 3: re-apply squircle mask to clip any dumbbell overflow ---
  for (int y = 0; y < sz; y++) {
    for (int x = 0; x < sz; x++) {
      final dx = (x - cx) / r;
      final dy = (y - cy) / r;
      if (pow(dx.abs(), _squircleN) + pow(dy.abs(), _squircleN) > 1.0) {
        final idx = (y * sz + x) * 4;
        pixels[idx + 3] = 0;
      }
    }
  }

  return pixels;
}

void _drawDumbbell(Uint8List pixels, int sz, double cx, double cy) {
  // Dumbbell geometry as fractions of `sz` (matches generate_icon.dart at 45°)
  final double barW = sz * 0.40;
  final double barH = sz * 0.095;
  final double barR = barH * 0.5;

  final double innerW = sz * 0.072;
  final double innerH = sz * 0.285;
  final double innerR = innerW * 0.32;
  final double innerGap = sz * 0.018;

  final double outerW = sz * 0.062;
  final double outerH = sz * 0.185;
  final double outerR = outerW * 0.32;
  final double outerGap = sz * 0.022;

  // Collect all rounded-rect pieces (cx, cy, halfW, halfH, cornerR)
  final pieces = <List<double>>[];

  // Central bar
  pieces.add([cx, cy, barW / 2, barH / 2, barR]);

  for (final sign in [-1.0, 1.0]) {
    final barEndX = cx + sign * (barW / 2);
    final innerCX = barEndX + sign * (innerGap + innerW / 2);
    pieces.add([innerCX, cy, innerW / 2, innerH / 2, innerR]);

    final outerCX = innerCX + sign * (innerW / 2 + outerGap + outerW / 2);
    pieces.add([outerCX, cy, outerW / 2, outerH / 2, outerR]);
  }

  const double angle = -pi / 6; // -30° clockwise, matching marketing icon
  final cosA = cos(angle);
  final sinA = sin(angle);

  for (int y = 0; y < sz; y++) {
    for (int x = 0; x < sz; x++) {
      // Rotate the sample point back to dumbbell space
      final dx = x - cx;
      final dy = y - cy;
      final rx = dx * cosA + dy * sinA + cx;
      final ry = -dx * sinA + dy * cosA + cy;

      for (final p in pieces) {
        final pcx = p[0], pcy = p[1];
        final hw = p[2], hh = p[3], cr = p[4];
        final left = pcx - hw, right = pcx + hw;
        final top = pcy - hh, bottom = pcy + hh;

        if (rx >= left && rx <= right && ry >= top && ry <= bottom) {
          bool inside = true;
          if (rx < left + cr && ry < top + cr) {
            inside = _dist(rx, ry, left + cr, top + cr) <= cr;
          } else if (rx > right - cr && ry < top + cr) {
            inside = _dist(rx, ry, right - cr, top + cr) <= cr;
          } else if (rx < left + cr && ry > bottom - cr) {
            inside = _dist(rx, ry, left + cr, bottom - cr) <= cr;
          } else if (rx > right - cr && ry > bottom - cr) {
            inside = _dist(rx, ry, right - cr, bottom - cr) <= cr;
          }

          if (inside) {
            final idx = (y * sz + x) * 4;
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

// ── Minimal PNG encoder (RGBA, no external deps) ──────────────────────────

Uint8List _encodePng(int w, int h, Uint8List rgba) {
  final raw = BytesBuilder();
  for (int y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    raw.add(rgba.sublist(y * w * 4, (y + 1) * w * 4));
  }
  final compressed = zlib.encode(raw.toBytes());

  final out = BytesBuilder();
  out.add([137, 80, 78, 71, 13, 10, 26, 10]); // PNG signature

  final ihdr = ByteData(13);
  ihdr.setUint32(0, w);
  ihdr.setUint32(4, h);
  ihdr.setUint8(8, 8); // bit depth
  ihdr.setUint8(9, 6); // RGBA
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
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
