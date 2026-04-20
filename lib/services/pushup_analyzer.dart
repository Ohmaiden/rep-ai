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
/// Elbow angle AND gate
/// --------------------
/// A rep only completes when BOTH conditions are met:
///   1. Vertical signal (shoulder/head Y) drops past down threshold then rises
///   2. Average elbow angle decreased by ≥25° during the down phase
/// This prevents false reps from head nods, body shifts, or going on all fours
/// without actual arm bending.
///
/// Upside-down detection
/// ---------------------
/// ML Kit returns normalised Y coords (0 = top of frame, 1 = bottom).
/// When the phone is upside-down the nose appears BELOW the hips in the frame
/// (nose Y > hip Y). A 10-frame debounce avoids false positives mid-rep.
library;

import 'dart:io';
import 'dart:math';
import '../models/workout_models.dart';
import '../utils/geometry.dart';

class PushUpAnalyzer {
  /// Good-form reps only — matches the on-screen counter.
  int repCount = 0;

  /// Total completed attempts (good + bad).
  int attemptCount = 0;

  /// Set from WorkoutState. Currently carried for symmetry with the rest of
  /// the pipeline; the rep-counter thresholds are the same on phone and iPad.
  bool isTablet = false;

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

  // Issue votes accumulated during current rep (issue → frame count)
  final Map<String, int> _issueVotes = {};

  // Frame counter to lock _topValue after settling
  int _upFrameCount = 0;

  // Lowest point tracking during DOWN phase
  double? _bottomValue;

  // Hip sag tracking during DOWN phase (Change 2: detect humping)
  double? _hipYAtDownStart;  // hip Y when DOWN phase begins
  double? _hipYAtDownBottom; // max hip Y seen during DOWN phase

  // Elbow angle tracking during DOWN phase (Change 3: reject shallow reps)
  double? _elbowAngleAtDownStart;   // elbow angle when DOWN phase begins
  double? _minElbowAngleDuringDown; // tracks how deep elbows bent during rep

  // Thresholds scale with torso length so sensitivity adapts to camera distance.
  // Floor of 0.025 / 0.018 prevents micro-movements (head nods, pose jitter)
  // from triggering state transitions when _torsoLength is small.
  double get _downThreshold => max((_torsoLength ?? 0.15) * 0.15, 0.025);
  double get _upThreshold   => max((_torsoLength ?? 0.15) * 0.10, 0.018);

  static double get _minVis => Platform.isIOS ? 0.35 : 0.4;

  // Consecutive frames with no form classification (null) — go idle if too many
  int _nullFormFrames = 0;
  static const int _maxNullFormFrames = 12;

  // Consecutive not_exercise frames needed before going idle mid-rep.
  // A single flickered frame (common during fast reps) no longer resets state.
  int _notExerciseFrames = 0;
  static const int _maxNotExerciseFrames = 4;

  // Consecutive exercise frames needed in IDLE before we actually activate.
  // Prevents single-frame classifier blips (common on iPad where the form
  // classifier has more noise) from kicking off a fake rep cycle.
  // Raised from 4 → 6 to require more ML confirmation before activating,
  // reducing false starts from cat pose / stretching motions.
  int _idleExerciseStreak = 0;
  static const int _idleActivationFrames = 6;

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

  /// The most-voted form issue during the current rep's frames.
  /// Returns null when no issues have been seen yet (e.g. in idle or good form).
  String? get currentLiveIssue {
    if (_issueVotes.isEmpty) return null;
    return _issueVotes.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Process one frame.
  ///
  /// [mlFormLabel]   ML model output: 'good_form' | 'bad_form' | 'not_exercise' | null
  /// [mlFormIssues]  Specific issues identified in this frame (e.g. ['Hips too low'])
  /// [deviceAngle]   Current device rotation in degrees:
  ///                   0   = portrait (default)
  ///                   90  = landscape, rotated clockwise from portrait
  ///                   270 = landscape, rotated counter-clockwise from portrait
  int update(
    Map<String, Map<String, double>> landmarks, {
    String? mlFormLabel,
    List<String> mlFormIssues = const [],
    double deviceAngle = 0,
  }) {
    // [SHELVED — portrait-only] Landscape debounce / vote adjustments.
    // deviceAngle is always 0 while the app is portrait-locked, so _isLandscape
    // stays false and the landscape branches below are never reached.
    // Kept for potential future use without deletion.
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
    if (mlFormLabel == 'bad_form') {
      _badFormFrames++;
      for (final issue in mlFormIssues) {
        _issueVotes[issue] = (_issueVotes[issue] ?? 0) + 1;
      }
    }

    final isExercise = mlFormLabel == 'good_form' || mlFormLabel == 'bad_form';

    // Track consecutive null-classification frames to prevent ghost reps
    if (mlFormLabel == null) {
      _nullFormFrames++;
    } else {
      _nullFormFrames = 0;
    }

    // Track consecutive not_exercise frames — a brief flicker during fast reps
    // should not reset the state machine. Require a sustained streak first.
    if (mlFormLabel == 'not_exercise') {
      _notExerciseFrames++;
    } else {
      _notExerciseFrames = 0;
    }

    // ── 4. State machine ────────────────────────────────────────────────────
    switch (phase) {
      case ExercisePhase.idle:
        if (isExercise) {
          _idleExerciseStreak++;
          if (_idleExerciseStreak >= _idleActivationFrames) {
            phase = ExercisePhase.up;
            _topValue = signal;
            _upFrameCount = 0;
            _goodFormFrames = 0;
            _badFormFrames  = 0;
          }
        } else {
          _idleExerciseStreak = 0;
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

        if (_notExerciseFrames >= _maxNotExerciseFrames || _nullFormFrames >= _maxNullFormFrames) {
          _goIdle();
        } else if (isExercise && _topValue != null && signal > _topValue! + _downThreshold) {
          // Seed hip Y at the start of the DOWN phase
          final lH = landmarks['LEFT_HIP'];
          final rH = landmarks['RIGHT_HIP'];
          if (lH != null && rH != null) {
            final hv = ((lH['visibility'] ?? 0.0) + (rH['visibility'] ?? 0.0)) / 2;
            if (hv >= _minVis) {
              _hipYAtDownStart = (lH['y']! + rH['y']!) / 2;
            }
          }
          // Seed elbow angle at the start of the DOWN phase
          _elbowAngleAtDownStart = _computeElbowAngle(landmarks);
          phase = ExercisePhase.down;
          _bottomValue = signal;
          _hipYAtDownBottom = _hipYAtDownStart; // seed
        }

      case ExercisePhase.down:
        // Track the lowest position (largest vertical coordinate)
        if (_bottomValue == null) {
          _bottomValue = signal;
        } else if (signal > _bottomValue!) {
          _bottomValue = signal;
        }

        // Track hip Y during DOWN phase (for humping detection)
        final lHd = landmarks['LEFT_HIP'];
        final rHd = landmarks['RIGHT_HIP'];
        if (lHd != null && rHd != null) {
          final hv = ((lHd['visibility'] ?? 0.0) + (rHd['visibility'] ?? 0.0)) / 2;
          if (hv >= _minVis) {
            final hipY = (lHd['y']! + rHd['y']!) / 2;
            _hipYAtDownBottom = (_hipYAtDownBottom == null) ? hipY : max(_hipYAtDownBottom!, hipY);
          }
        }

        // Track minimum elbow angle during DOWN phase (for shallow rep detection)
        final elbowAngle = _computeElbowAngle(landmarks);
        if (elbowAngle != null) {
          if (_minElbowAngleDuringDown == null || elbowAngle < _minElbowAngleDuringDown!) {
            _minElbowAngleDuringDown = elbowAngle;
          }
        }

        if (_notExerciseFrames >= _maxNotExerciseFrames || _nullFormFrames >= _maxNullFormFrames) {
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
    _notExerciseFrames = 0;
    _idleExerciseStreak = 0;
    _hipYAtDownStart = null;
    _hipYAtDownBottom = null;
    _elbowAngleAtDownStart = null;
    _minElbowAngleDuringDown = null;
    _issueVotes.clear();
  }

  void _finishRep(double currentSignal) {
    if (!_debouncer.canCount()) return;

    // ── Minimum shoulder travel ─────────────────────────────────────────────
    // Reject micro-movements: head nods, pose estimation jitter, and small
    // weight shifts can produce a full UP→DOWN→UP cycle when thresholds are
    // tiny. Require at least 3.5% of frame height of real shoulder movement.
    if (_topValue != null && _bottomValue != null) {
      final shoulderTravel = _bottomValue! - _topValue!;
      if (shoulderTravel < 0.035) {
        _goIdle();
        return;
      }
    }

    // ── Reject shallow reps silently (don't count, don't record as bad) ───
    if (_minElbowAngleDuringDown != null && _minElbowAngleDuringDown! > 150.0) {
      _goIdle();
      return;
    }

    // ── Elbow angle AND gate ────────────────────────────────────────────────
    // A rep only counts when the vertical signal (head/shoulder drop + rise)
    // AND real arm bending both occur. This prevents false reps from head
    // nods, body shifts, or going on all fours without actual push-up motion.
    // Require average elbow angle to decrease by at least 25° during the
    // down phase compared to the angle at the start of the rep cycle.
    // If neither arm was visible at any point, reject the rep.
    if (_elbowAngleAtDownStart == null || _minElbowAngleDuringDown == null) {
      _goIdle();
      return;
    }
    final elbowBend = _elbowAngleAtDownStart! - _minElbowAngleDuringDown!;
    if (elbowBend < 25.0) {
      _goIdle();
      return;
    }

    // A rep is good unless bad frames are a clear majority of exercise frames.
    // Bad must exceed 60% of frames to fail the rep — isolated false-positive
    // frames (e.g. a couple of hip-sag detections mid-rep) no longer flip an
    // otherwise clean rep to bad.
    // [SHELVED] The landscape branch (55% threshold) is kept but never reached
    // while the app is portrait-only (_isLandscape is always false).
    final totalExercise = _goodFormFrames + _badFormFrames;
    final badThreshold = _isLandscape ? 0.55 : 0.60;
    final goodRep = totalExercise == 0 ||
        _badFormFrames < totalExercise * badThreshold;

    // ── Humping detection: hips dropping significantly during DOWN phase ───
    bool humpingDetected = false;
    if (_hipYAtDownStart != null && _hipYAtDownBottom != null &&
        _topValue != null && _bottomValue != null) {
      final hipDrop = _hipYAtDownBottom! - _hipYAtDownStart!;
      final shoulderDrop = (_bottomValue! - _topValue!).abs();
      if (hipDrop > 0.04 && shoulderDrop > 0 && hipDrop > shoulderDrop * 0.60) {
        humpingDetected = true;
      }
    }

    attemptCount++;
    final repGood = goodRep && !humpingDetected;
    if (repGood) repCount++;

    // Pick the top issues by vote count (minimum 2 frames to avoid noise)
    final topIssues = (_issueVotes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .where((e) => e.value >= 2)
        .take(2)
        .map((e) => e.key)
        .toList();
    if (humpingDetected && !topIssues.contains('Hips dropping')) {
      topIssues.insert(0, 'Hips dropping');
    }

    lastRepValid    = repGood;
    lastRepTime     = DateTime.now();
    lastRepFeedback = repGood
        ? ['Good rep!']
        : (topIssues.isNotEmpty ? topIssues : ['Work on form']);

    repHistory.add(RepResult(
      repNumber: attemptCount,
      goodForm:  repGood,
      issues:    repGood ? [] : (topIssues.isNotEmpty ? topIssues : ['Bad form']),
      repDuration: Duration.zero,
    ));

    phase     = ExercisePhase.up;
    _topValue = null;
    _upFrameCount = 0;
    _bottomValue = null;
    _goodFormFrames = 0;
    _badFormFrames  = 0;
    _hipYAtDownStart = null;
    _hipYAtDownBottom = null;
    _elbowAngleAtDownStart = null;
    _minElbowAngleDuringDown = null;
    _issueVotes.clear();
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
    _notExerciseFrames = 0;
    _idleExerciseStreak = 0;
    _hipYAtDownStart = null;
    _hipYAtDownBottom = null;
    _elbowAngleAtDownStart = null;
    _minElbowAngleDuringDown = null;
    _issueVotes.clear();
  }

  // ── Elbow angle helpers ──────────────────────────────────────────────────

  /// Computes the average elbow angle (shoulder→elbow→wrist) from visible arms.
  /// Averages left and right when both visible; uses whichever is visible if
  /// only one arm is detected. Returns null if neither arm is visible enough.
  double? _computeElbowAngle(Map<String, Map<String, double>> landmarks) {
    final lS = landmarks['LEFT_SHOULDER'];
    final lE = landmarks['LEFT_ELBOW'];
    final lW = landmarks['LEFT_WRIST'];
    final rS = landmarks['RIGHT_SHOULDER'];
    final rE = landmarks['RIGHT_ELBOW'];
    final rW = landmarks['RIGHT_WRIST'];

    double? leftAngle;
    double? rightAngle;

    // Left arm
    if (lS != null && lE != null && lW != null) {
      final vis = min(lE['visibility'] ?? 0.0, lW['visibility'] ?? 0.0);
      if (vis >= _minVis) leftAngle = _angleDeg(lS, lE, lW);
    }
    // Right arm
    if (rS != null && rE != null && rW != null) {
      final vis = min(rE['visibility'] ?? 0.0, rW['visibility'] ?? 0.0);
      if (vis >= _minVis) rightAngle = _angleDeg(rS, rE, rW);
    }

    if (leftAngle != null && rightAngle != null) {
      return (leftAngle + rightAngle) / 2;
    }
    return leftAngle ?? rightAngle;
  }

  double _angleDeg(Map<String, double> a, Map<String, double> b, Map<String, double> c) {
    final ax = a['x']! - b['x']!; final ay = a['y']! - b['y']!;
    final cx = c['x']! - b['x']!; final cy = c['y']! - b['y']!;
    final dot = ax * cx + ay * cy;
    final mag = sqrt(ax * ax + ay * ay) * sqrt(cx * cx + cy * cy);
    if (mag < 1e-6) return 180.0;
    return acos((dot / mag).clamp(-1.0, 1.0)) * 180 / pi;
  }
}
