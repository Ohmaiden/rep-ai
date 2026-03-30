/// Audio Service
/// ==============
/// Plays sound effects for workout feedback.
/// Creates fresh AudioPlayer instances per play call to avoid pool exhaustion.
/// Uses mp3 assets if available, otherwise generates tones programmatically.
library;

import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class WorkoutAudioService {
  bool _muted = false;
  bool _useAssets = false;

  Uint8List? _goodWav;
  Uint8List? _badWav;

  bool get isMuted => _muted;

  void toggleMute() => _muted = !_muted;

  Future<void> init() async {
    try {
      final testPlayer = AudioPlayer();
      await testPlayer.setSource(AssetSource('sounds/good_rep.mp3'));
      await testPlayer.dispose();
      _useAssets = true;
    } catch (_) {
      _useAssets = false;
      _goodWav = _generateDing();
      _badWav = _generateBuzzBuzz();
    }
  }

  void playGoodRep() {
    if (_muted) return;
    if (_useAssets) {
      _playFresh('sounds/good_rep.mp3');
    } else if (_goodWav != null) {
      _playFreshBytes(_goodWav!);
    }
  }

  void playBadRep() {
    if (_muted) return;
    if (_useAssets) {
      _playFresh('sounds/bad_rep.mp3');
    } else if (_badWav != null) {
      _playFreshBytes(_badWav!);
    }
  }

  void playSetComplete() {
    if (_muted) return;
    _playFresh('sounds/set_complete.mp3');
  }

  /// Create a fresh player, play, auto-dispose on complete.
  void _playFresh(String asset) {
    final player = AudioPlayer();
    player.play(AssetSource(asset)).catchError((_) {});
    player.onPlayerComplete.listen((_) => player.dispose());
  }

  void _playFreshBytes(Uint8List wav) {
    final player = AudioPlayer();
    player.play(BytesSource(wav)).catchError((_) {});
    player.onPlayerComplete.listen((_) => player.dispose());
  }

  void dispose() {
    // Nothing to dispose — fresh players self-dispose
  }

  // ── Fallback generated tones ──────────────────────────────────────────

  Uint8List _generateDing({int sr = 44100}) {
    final n = (sr * 0.12).round();
    final s = Int16List(n);
    for (int i = 0; i < n; i++) {
      final t = i / sr;
      final p = i / n;
      final env = p < 0.02 ? p / 0.02 : exp(-6.0 * (p - 0.02));
      final w =
          sin(2 * pi * 1200 * t) * 0.75 + sin(2 * pi * 2400 * t) * 0.25;
      s[i] = (w * 32767 * 0.55 * env).round().clamp(-32767, 32767);
    }
    return _wav(s, sr);
  }

  Uint8List _generateBuzzBuzz({int sr = 44100}) {
    final pulse = (sr * 0.08).round();
    final gap = (sr * 0.04).round();
    final n = pulse * 2 + gap;
    final s = Int16List(n);
    for (int i = 0; i < n; i++) {
      final t = i / sr;
      final inFirst = i < pulse;
      final inSecond = i >= pulse + gap;
      if (!inFirst && !inSecond) continue;
      final li = inFirst ? i : i - pulse - gap;
      final fl = (pulse * 0.08).round().clamp(1, pulse);
      double env = 1.0;
      if (li < fl) env = li / fl;
      if (li > pulse - fl) env = (pulse - li) / fl;
      final w = sin(2 * pi * 250 * t) * 0.6 +
          sin(2 * pi * 750 * t) * 0.25 +
          sin(2 * pi * 1250 * t) * 0.15;
      s[i] = (w * 32767 * 0.45 * env).round().clamp(-32767, 32767);
    }
    return _wav(s, sr);
  }

  Uint8List _wav(Int16List samples, int sr) {
    final ds = samples.length * 2;
    final h = ByteData(44);
    h.setUint8(0, 0x52); h.setUint8(1, 0x49);
    h.setUint8(2, 0x46); h.setUint8(3, 0x46);
    h.setUint32(4, 36 + ds, Endian.little);
    h.setUint8(8, 0x57); h.setUint8(9, 0x41);
    h.setUint8(10, 0x56); h.setUint8(11, 0x45);
    h.setUint8(12, 0x66); h.setUint8(13, 0x6D);
    h.setUint8(14, 0x74); h.setUint8(15, 0x20);
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, sr, Endian.little);
    h.setUint32(28, sr * 2, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    h.setUint8(36, 0x64); h.setUint8(37, 0x61);
    h.setUint8(38, 0x74); h.setUint8(39, 0x61);
    h.setUint32(40, ds, Endian.little);
    final w = Uint8List(44 + ds);
    w.setAll(0, h.buffer.asUint8List());
    w.setAll(44, samples.buffer.asUint8List());
    return w;
  }
}
