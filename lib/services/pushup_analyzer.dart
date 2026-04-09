/// Push-Up Analyzer
/// =================
/// Counts reps by tracking the vertical position of the shoulder midpoint.
/// Falls back to hip midpoint if shoulders aren't visible.
/// Works from any camera angle: the entire upper body rises and falls
/// during a push-up regardless of which direction the camera faces.
///
/// Rotation handling
/// -----------------
/// In portrait mode (phone upright): "down toward floor" = increasing Y.
/// In landscape mode (phone sideways): the camera sensor is rotated 90°,
/// so "down toward floor" maps onto the X axis instead.
/// The caller passes [deviceAngle] (0 = portrait, 90 = landscape-right,
/// 270 = landscape-left) so this analyzer picks the right axis.
///
/// Form quality comes entirely from the ML model — no angle checks.
///
/// State machine:
///   IDLE → UP (in push-up position) → DOWN (shoulders drop) → UP (rep counted)
///
/// Upside-down detection
/// ---------------------
/// ML Kit returns normalised Y coords (0 = top of frame, 1 = bottom).
/// When the phone is upside-down the nose appears BELOW the hips in the frame
/// (nose Y > hip Y). A 10-frame debounce avoids false positives mid-rep.
library;

import 'dart:io';
import '../models/workout_models.dart';
import '../utils/geometry.dart';

class PushUpAnalyzer {
  /// Good-form reps only — matches the on-screen counter.
  int repCount = 0;

  /// Total completed attempts (good + bad).
  int attemptCount = 0;

  ExercisePhase phase = ExercisePhase.idle;

  // Smoothing
  final _shoulderSmoother = SmoothedValue(alpha: 0.4);
  final _debouncer = RepDebouncer(minInterval: const Duration(milliseconds: 700));

  // Landscape mode: reduced debounce + smaller majority-vote window
  bool _isLandscape = false;

  // Position tracking
  double? _topValue;    // smoothed vertical coordinate at the top of a rep
  double? _torsoLength; // smoothed scale reference (shoulder-to-hip distance)

  // Form quality accumulation during current rep
  int _goodFormFrames = 0;
  int _badFormFrames = 0;

  // Frame counter to lock _topValue after settling
  int _upFrameCount = 0;

  // Lowest point tracking during DOWN phase
  double? _bottomValue;

  // Thresholds scale with torso length so sensitivity adapts to camera distance
  double get _downThreshold => (_torsoLength ?? 0.15) * 0.15; // 15% of torso
  double get _upThreshold   => (_torsoLength ?? 0.15) * 0.10; // 10% of torso

  static double get _minVis => Platform.isIOS ? 0.35 : 0.4;

  // Consecutive frames with no form classification (null) — go idle if too many
  int _nullFormFrames = 0;
  static const int _maxNullFormFrames = 12;

  // ── Upside-down detection ────────────────────────────────────────────────────
  int _upsideDownFrames = 0;
  static const int _upsideDownDebounce = 10;
  double _lastDeviceAngle = 0;

  bool get isUpsideDown => _upsideDownFrames >= _upsideDownDebounce;

  /// Title shown on the flip overlay, varies by which bad angle was detected.
  String get flipMessageTitle {
    if (_lastDeviceAngle == 180) return 'Flip your phone';
    return 'Flip your phone 180°';
  }

  /// Subtitle shown on the flip overlay.
  String get flipMessageSubtitle {
    if (_lastDeviceAngle == 180) return 'Camera should be at the top';
    return 'Camera should be on your right';
  }

  // Results
  List<RepResult> repHistory = [];
  bool? lastRepValid;
  DateTime? lastRepTime;
  PoseMetrics latestMetrics = PoseMetrics();
  List<String> feedback = [];
  List<String> lastRepFeedback = [];

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Process one frame.
  ///
  /// [mlFormLabel]  ML model output: 'good_form' | 'bad_form' | 'not_exercise' | null
  /// [deviceAngle]  Current device rotation in degrees:
  ///                  0   = portrait (default)
  ///                  90  = landscape, rotated clockwise from portrait
  ///                  270 = landscape, rotated counter-clockwise from portrait
  int update(
    Map<String, Map<String, double>> landmarks, {
    String? mlFormLabel,
    double deviceAngle = 0,
  }) {
    // Adapt debounce and vote window to orientation
    final landscape = deviceAngle == 90 || deviceAngle == 270;
    if (landscape != _isLandscape) {
      _isLandscape = landscape;
      _debouncer.minInterval = Duration(
        milliseconds: landscape ? 500 : 700,
      );
    }

    // ── 1. Pick tracking point ──────────────────────────────────────────────
    final trackResult = _getVerticalSignal(landmarks, deviceAngle);
    if (trackResult == null) {
      latestMetrics = PoseMetrics(poseDetected: false);
      // Can't determine orientation without a pose — reset upside-down counter
      _upsideDownFrames = 0;
      return repCount;
    }
    final (rawSignal, _, torso) = trackResult;

    // Smooth the signal
    final signal = _shoulderSmoother.update(rawSignal);

    // Smooth torso length
    _torsoLength = _torsoLength == null
        ? torso
        : 0.1 * torso + 0.9 * _torsoLength!;

    latestMetrics = PoseMetrics(poseDetected: true, side: 'FRONT');

    // ── 2. Upside-down detection ────────────────────────────────────────────
    _updateUpsideDown(landmarks, deviceAngle);

    // ── 3. Accumulate ML form votes ─────────────────────────────────────────
    if (mlFormLabel == 'good_form') _goodFormFrames++;
    if (mlFormLabel == 'bad_form')  _badFormFrames++;

    final isExercise = mlFormLabel == 'good_form' || mlFormLabel == 'bad_form';

    // Track consecutive null-classification frames to prevent ghost reps
    if (mlFormLabel == null) {
      _nullFormFrames++;
    } else {
      _nullFormFrames = 0;
    }

    // ── 4. State machine ────────────────────────────────────────────────────
    switch (phase) {
      case ExercisePhase.idle:
        if (isExercise) {
          phase = ExercisePhase.up;
          _topValue = signal;
          _upFrameCount = 0;
          _goodFormFrames = 0;
          _badFormFrames  = 0;
        }

      case ExercisePhase.up:
        // Track the highest position, but lock after 8 frames to prevent drift
        _upFrameCount++;
        if (_topValue == null) {
          _topValue = signal;
          _upFrameCount = 1;
        } else if (_upFrameCount <= 8) {
          if (signal < _topValue!) _topValue = signal;
        }

        if (mlFormLabel == 'not_exercise' || _nullFormFrames >= _maxNullFormFrames) {
          _goIdle();
        } else if (isExercise && _topValue != null && signal > _topValue! + _downThreshold) {
          phase = ExercisePhase.down;
          _bottomValue = signal;
        }

      case ExercisePhase.down:
        // Track the lowest position (largest vertical coordinate)
        if (_bottomValue == null) {
          _bottomValue = signal;
        } else if (signal > _bottomValue!) {
          _bottomValue = signal;
        }

        if (mlFormLabel == 'not_exercise' || _nullFormFrames >= _maxNullFormFrames) {
          _goIdle();
        } else if (isExercise && _bottomValue != null && signal < _bottomValue! - _upThreshold) {
          // Rising back up from bottom → rep complete
          _finishRep(signal);
        }
    }

    return repCount;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  void _updateUpsideDown(
      Map<String, Map<String, double>> landmarks, double deviceAngle) {
    _lastDeviceAngle = deviceAngle;

    // iOS: landmark orientation depends on ML Kit's internal handling which
    // differs from Android. Disable upside-down detection on iOS to prevent
    // false flip warnings.
    if (Platform.isIOS) {
      if (_upsideDownFrames > 0) _upsideDownFrames--;
      return;
    }

    final nose = landmarks['NOSE'];
    final lH   = landmarks['LEFT_HIP'];
    final rH   = landmarks['RIGHT_HIP'];

    if (nose == null || lH == null || rH == null) {
      if (_upsideDownFrames > 0) _upsideDownFrames--;
      return;
    }

    final noseY = nose['y'] ?? 0.0;
    final hipY  = ((lH['y'] ?? 0.0) + (rH['y'] ?? 0.0)) / 2;

    final bool isFlipped = noseY > hipY + 0.05;

    if (isFlipped) {
      if (_upsideDownFrames < _upsideDownDebounce) _upsideDownFrames++;
    } else {
      if (_upsideDownFrames > 0) _upsideDownFrames--;
    }
  }

  void _goIdle() {
    phase = ExercisePhase.idle;
    _topValue = null;
    _bottomValue = null;
    _upFrameCount = 0;
    _goodFormFrames = 0;
    _badFormFrames  = 0;
    _nullFormFrames = 0;
  }

  void _finishRep(double currentSignal) {
    if (!_debouncer.canCount()) return;

    // In landscape, use a slightly looser majority: weight good frames by 30%
    // less (i.e. require fewer good frames relative to bad to still call it good).
    final effectiveGood = _isLandscape
        ? (_goodFormFrames * 0.7).round()
        : _goodFormFrames;
    final goodRep = effectiveGood >= _badFormFrames || _goodFormFrames > _badFormFrames;
    attemptCount++;
    if (goodRep) repCount++;

    lastRepValid    = goodRep;
    lastRepTime     = DateTime.now();
    lastRepFeedback = goodRep ? ['Good rep!'] : ['Work on form'];

    repHistory.add(RepResult(
      repNumber: attemptCount,
      goodForm:  goodRep,
      issues:    goodRep ? [] : ['Bad form'],
      repDuration: Duration.zero,
    ));

    phase     = ExercisePhase.up;
    _topValue = null;
    _upFrameCount = 0;
    _bottomValue = null;
    _goodFormFrames = 0;
    _badFormFrames  = 0;
  }

  /// Returns (verticalSignal, sourceName, torsoLength) or null if pose is invalid.
  (double, String, double)? _getVerticalSignal(
    Map<String, Map<String, double>> landmarks,
    double deviceAngle,
  ) {
    final lS = landmarks['LEFT_SHOULDER'];
    final rS = landmarks['RIGHT_SHOULDER'];
    final lH = landmarks['LEFT_HIP'];
    final rH = landmarks['RIGHT_HIP'];

    if (lH == null || rH == null) return null;

    final hipVis = ((lH['visibility'] ?? 0.0) + (rH['visibility'] ?? 0.0)) / 2;
    if (hipVis < _minVis) return null;

    final hipY = ((lH['y']! + rH['y']!) / 2);

    final shouldersOk = lS != null && rS != null &&
        (lS['visibility'] ?? 0.0) >= _minVis &&
        (rS['visibility'] ?? 0.0) >= _minVis;

    late double midV;
    late double torso;
    late String trackLabel;

    if (shouldersOk) {
      final midShoulderY = (lS['y']! + rS['y']!) / 2;
      torso = (hipY - midShoulderY).abs().clamp(0.02, double.infinity);
      midV  = _axisValue(lS['x']!, lS['y']!, rS['x']!, rS['y']!, deviceAngle);
      trackLabel = 'shoulders';
    } else {
      torso = 0.15;
      midV  = _axisValue(lH['x']!, lH['y']!, rH['x']!, rH['y']!, deviceAngle);
      trackLabel = 'hips(fallback)';
    }

    return (midV, trackLabel, torso);
  }

  double _axisValue(
    double lx, double ly, double rx, double ry, double deviceAngle,
  ) {
    // After coordinate rotation in pose_service.dart the "vertical" body axis
    // that changes during a push-up is always Y for portrait (deviceAngle == 0)
    // and also Y for deviceAngle == 270 (rotation already applied upstream).
    // However when pose_service does NOT apply rotation (e.g. raw coords passed
    // through), landscape side-view movement is on the X axis.
    // We therefore also support the explicit landscape fallback here:
    // for deviceAngle 90 or 270 use X midpoint as the tracking signal.
    final isLandscape = deviceAngle == 90 || deviceAngle == 270;
    if (isLandscape) {
      return (lx + rx) / 2;
    }
    return (ly + ry) / 2;
  }

  // ── Getters ─────────────────────────────────────────────────────────────────

  int get goodFormReps => repHistory.where((r) => r.goodForm).length;
  int get badFormReps  => repHistory.where((r) => !r.goodForm).length;

  Map<String, int> get formIssueSummary {
    final counts = <String, int>{};
    for (final rep in repHistory) {
      for (final issue in rep.issues) {
        counts[issue] = (counts[issue] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ── Reset ───────────────────────────────────────────────────────────────────

  void reset() {
    repCount     = 0;
    attemptCount = 0;
    phase        = ExercisePhase.idle;
    _shoulderSmoother.reset();
    _debouncer.reset();
    _topValue       = null;
    _bottomValue    = null;
    _torsoLength    = null;
    _upFrameCount   = 0;
    _goodFormFrames = 0;
    _badFormFrames  = 0;
    feedback        = [];
    lastRepFeedback = [];
    lastRepValid    = null;
    lastRepTime     = null;
    repHistory      = [];
    latestMetrics   = PoseMetrics();
    _upsideDownFrames = 0;
    _nullFormFrames = 0;
  }
}
