/// ML Form Classifier
/// ==================
/// Runs the trained TFLite model on a single frame of pose landmarks.
/// Mirrors the feature extraction from tools/train_classifier.py exactly.
///
/// Output labels (from assets/models/pushup_labels.txt):
///   0 = bad_form
///   1 = good_form
///   2 = not_exercise
library;

import 'dart:io';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';

class FormPrediction {
  final String label;      // 'good_form' | 'bad_form' | 'not_exercise'
  final double confidence; // 0.0 – 1.0
  final List<double> allScores; // [bad_form, good_form, not_exercise]

  const FormPrediction(this.label, this.confidence, this.allScores);

  bool get isGoodForm    => label == 'good_form';
  bool get isBadForm     => label == 'bad_form';
  bool get isNotExercise => label == 'not_exercise';

  double get badScore        => allScores[0];
  double get goodScore       => allScores[1];
  double get notExerciseScore => allScores[2];
}

class MLFormClassifier {
  Interpreter? _interpreter;

  // Must match the order used during training (see train_classifier.py)
  static const _labels = ['bad_form', 'good_form', 'not_exercise'];

  // The 15 landmarks saved by the app, in the same order as the training script
  static const _landmarkNames = [
    'NOSE',
    'LEFT_EAR',  'RIGHT_EAR',
    'LEFT_SHOULDER', 'RIGHT_SHOULDER',
    'LEFT_ELBOW',    'RIGHT_ELBOW',
    'LEFT_WRIST',    'RIGHT_WRIST',
    'LEFT_HIP',      'RIGHT_HIP',
    'LEFT_KNEE',     'RIGHT_KNEE',
    'LEFT_ANKLE',    'RIGHT_ANKLE',
  ];

  // Indices into _landmarkNames for the normalisation anchors
  static const _iLeftShoulder  = 3;
  static const _iRightShoulder = 4;
  static const _iLeftHip       = 9;
  static const _iRightHip      = 10;

  Future<void> initialize() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/pushup_classifier.tflite',
    );
  }

  bool get isReady => _interpreter != null;

  /// Run inference on one frame. Returns null if landmarks are incomplete
  /// or the person is not visible enough.
  FormPrediction? classify(Map<String, Map<String, double>> landmarks) {
    // On iOS, the TFLite model was trained on Android (NV21) landmark
    // coordinates and produces garbage predictions on iOS (bgra8888) frames.
    // Use geometric form analysis instead until the model is retrained on iOS data.
    if (Platform.isIOS) return _geometricClassify(landmarks);

    if (_interpreter == null) return null;

    final features = _extractFeatures(landmarks);
    if (features == null) return null;

    // Shape: input [1, 30]  output [1, 3]
    final input  = [features];
    final output = List.generate(1, (_) => List.filled(3, 0.0));

    _interpreter!.run(input, output);

    final probs  = List<double>.from(output[0]);
    final maxIdx = probs.indexOf(probs.reduce(max));
    return FormPrediction(_labels[maxIdx], probs[maxIdx], probs);
  }

  /// Extracts a 30-float feature vector, normalised to body size + position.
  /// Must exactly match the Python training script.
  List<double>? _extractFeatures(Map<String, Map<String, double>> landmarks) {
    // Collect (x, y) for every required landmark
    final coords = <List<double>>[];
    for (final name in _landmarkNames) {
      final lm = landmarks[name];
      if (lm == null) return null;
      coords.add([lm['x']!, lm['y']!]);
    }

    // Reject frames where shoulders or hips aren't clearly visible.
    // iOS bgra8888 produces lower confidence scores so uses a lower threshold.
    // Android NV21 keeps the original stricter threshold.
    final visThreshold = Platform.isIOS ? 0.1 : 0.3;
    final shoulderVis = ((landmarks['LEFT_SHOULDER']?['visibility'] ?? 0.0) +
                         (landmarks['RIGHT_SHOULDER']?['visibility'] ?? 0.0)) / 2;
    final hipVis      = ((landmarks['LEFT_HIP']?['visibility'] ?? 0.0) +
                         (landmarks['RIGHT_HIP']?['visibility'] ?? 0.0)) / 2;
    if (shoulderVis < visThreshold || hipVis < visThreshold) return null;

    // Normalise: centre on mid-hip, scale by shoulder→hip torso length
    final midHipX      = (coords[_iLeftHip][0]  + coords[_iRightHip][0])  / 2;
    final midHipY      = (coords[_iLeftHip][1]  + coords[_iRightHip][1])  / 2;
    final midShouldX   = (coords[_iLeftShoulder][0] + coords[_iRightShoulder][0]) / 2;
    final midShouldY   = (coords[_iLeftShoulder][1] + coords[_iRightShoulder][1]) / 2;

    final torsoSize = sqrt(
      pow(midShouldX - midHipX, 2) + pow(midShouldY - midHipY, 2),
    );
    if (torsoSize < 1e-4) return null;

    final features = <double>[];
    for (final c in coords) {
      features.add((c[0] - midHipX) / torsoSize);
      features.add((c[1] - midHipY) / torsoSize);
    }
    return features; // 30 values
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  /// Public wrapper so workout_state can call geometric classify directly on iOS.
  FormPrediction? classifyGeometric(
    Map<String, Map<String, double>> landmarks, {
    double deviceAngle = 0,
  }) =>
      _geometricClassify(landmarks, deviceAngle: deviceAngle);

  /// Geometric form classifier for iOS — uses landmark positions instead of
  /// the TFLite model (which was trained on Android data and doesn't generalise).
  ///
  /// Supports two viewing angles:
  ///   - Side view (landscape, full body): body-horizontal + elbow angle checks
  ///   - Front view (portrait, facing camera): shoulder-spread + nose-shoulder checks
  ///
  /// Detects the viewing angle from shoulder spread: in front view, left and
  /// right shoulders are far apart; in side view, they overlap.
  FormPrediction? _geometricClassify(
    Map<String, Map<String, double>> landmarks, {
    double deviceAngle = 0,
  }) {
    final lS = landmarks['LEFT_SHOULDER'];
    final rS = landmarks['RIGHT_SHOULDER'];
    final lH = landmarks['LEFT_HIP'];
    final rH = landmarks['RIGHT_HIP'];
    final lE = landmarks['LEFT_ELBOW'];
    final rE = landmarks['RIGHT_ELBOW'];
    final lW = landmarks['LEFT_WRIST'];
    final rW = landmarks['RIGHT_WRIST'];
    final nose = landmarks['NOSE'];

    final lSvis = lS?['visibility'] ?? 0.0;
    final rSvis = rS?['visibility'] ?? 0.0;
    final lHvis = lH?['visibility'] ?? 0.0;
    final rHvis = rH?['visibility'] ?? 0.0;
    final shoulderVis = (lSvis + rSvis) / 2;
    final hipVis = (lHvis + rHvis) / 2;

    // Must have at least both shoulders visible
    if (shoulderVis < 0.2) return null;
    if (lS == null || rS == null) return null;

    // ── Detect viewing angle ─────────────────────────────────────────────────
    // Front view: left and right shoulders are spread apart in the image.
    // Side view: shoulders overlap (both at similar position).
    final shoulderSpread = sqrt(
      pow(lS['x']! - rS['x']!, 2) + pow(lS['y']! - rS['y']!, 2),
    );
    final isFrontView = shoulderSpread > 0.08;

    if (isFrontView) {
      return _classifyFrontView(landmarks, lS, rS, lH, rH, lE, rE, lW, rW,
          nose, hipVis, deviceAngle);
    } else {
      return _classifySideView(landmarks, lS, rS, lH, rH, lE, rE, lW, rW,
          nose, hipVis, deviceAngle);
    }
  }

  /// Front-view classification: person is facing the camera (typical portrait).
  /// Hips may be hidden behind the body. Uses nose-shoulder relationship,
  /// elbow angles, hip sag, and head position to classify form.
  ///
  /// Bad-form checks (matching Android TFLite training labels):
  ///   - Hip sag: hips drop well below shoulder line
  ///   - Bad head position: nose too far above or below shoulders
  ///   - Bad arm extension: elbows flared out or at extreme angles
  FormPrediction? _classifyFrontView(
    Map<String, Map<String, double>> landmarks,
    Map<String, double> lS,
    Map<String, double> rS,
    Map<String, double>? lH,
    Map<String, double>? rH,
    Map<String, double>? lE,
    Map<String, double>? rE,
    Map<String, double>? lW,
    Map<String, double>? rW,
    Map<String, double>? nose,
    double hipVis,
    double deviceAngle,
  ) {
    final shoulderY = (lS['y']! + rS['y']!) / 2;

    // ── 1. Standing / not-exercise detection ─────────────────────────────────
    if (nose != null && hipVis > 0.2 && lH != null && rH != null) {
      final noseY = nose['y']!;
      final hipY = (lH['y']! + rH['y']!) / 2;
      final verticalSpan = (hipY - noseY).abs();
      if (noseY < hipY && verticalSpan > 0.30) {
        return const FormPrediction('not_exercise', 0.8, [0.05, 0.05, 0.9]);
      }
    }

    // Nose way above shoulders = upright, not in push-up position
    if (nose != null) {
      final noseAboveShoulders = shoulderY - nose['y']!;
      if (noseAboveShoulders > 0.20) {
        return const FormPrediction('not_exercise', 0.7, [0.05, 0.1, 0.85]);
      }
    }

    // Shoulders high in frame = standing/sitting
    if (shoulderY < 0.3) {
      return const FormPrediction('not_exercise', 0.55, [0.1, 0.15, 0.75]);
    }

    // ── 2. Form quality checks ───────────────────────────────────────────────
    // Collect form issues — if any are found, it's bad form.
    bool hasBadForm = false;

    // ── 2a. Hip sag detection ────────────────────────────────────────────────
    // From the front: if hips are visible and significantly below shoulders,
    // the person's core is sagging (hips dropping toward floor).
    if (hipVis > 0.2 && lH != null && rH != null) {
      final hipY = (lH['y']! + rH['y']!) / 2;
      final hipBelowShoulders = hipY - shoulderY;
      // In front-view push-up, hips and shoulders should be at similar Y.
      // A large positive gap means hips are sagging (bad form).
      if (hipBelowShoulders > 0.12) {
        hasBadForm = true;
      }
    }

    // ── 2b. Head position check ──────────────────────────────────────────────
    // Nose should be roughly at or slightly below shoulder level during push-up.
    // Too far below (head drooping) or above (looking up) = bad head position.
    if (nose != null) {
      final noseRelShoulder = nose['y']! - shoulderY;
      // Head drooping significantly below shoulders
      if (noseRelShoulder > 0.15) {
        hasBadForm = true;
      }
    }

    // ── 2c. Elbow angle + flare check ────────────────────────────────────────
    final leftArmVis  = min(lE?['visibility'] ?? 0.0, lW?['visibility'] ?? 0.0);
    final rightArmVis = min(rE?['visibility'] ?? 0.0, rW?['visibility'] ?? 0.0);

    double? elbowAngle;
    if (leftArmVis > 0.2 && lE != null && lW != null) {
      elbowAngle = _angle(lS, lE, lW);
    } else if (rightArmVis > 0.2 && rE != null && rW != null) {
      elbowAngle = _angle(rS, rE, rW);
    }

    if (elbowAngle != null) {
      // Elbow outside push-up range = bad arm extension
      if (elbowAngle <= 40 || elbowAngle >= 170) {
        hasBadForm = true;
      }

      // From front view: check elbow flare. Elbows should stay relatively
      // close to the body. If elbows are far outside the shoulder line (X),
      // they're flared out (bad form / injury risk).
      if (lE != null && rE != null) {
        final lEvis = lE['visibility'] ?? 0.0;
        final rEvis = rE['visibility'] ?? 0.0;
        if (lEvis > 0.2 && rEvis > 0.2) {
          final elbowSpread = (lE['x']! - rE['x']!).abs();
          final shoulderWidth = (lS['x']! - rS['x']!).abs();
          // Elbows spread > 1.8x shoulder width = excessive flare
          if (shoulderWidth > 0.01 && elbowSpread > shoulderWidth * 1.8) {
            hasBadForm = true;
          }
        }
      }

      return hasBadForm
          ? const FormPrediction('bad_form', 0.65, [0.65, 0.15, 0.2])
          : const FormPrediction('good_form', 0.65, [0.1, 0.65, 0.25]);
    }

    // No arm data but passed not-exercise checks — allow cautiously.
    return hasBadForm
        ? const FormPrediction('bad_form', 0.5, [0.5, 0.15, 0.35])
        : const FormPrediction('good_form', 0.5, [0.15, 0.5, 0.35]);
  }

  /// Side-view classification: full body visible from the side (typical landscape).
  /// Both shoulders and hips should be visible for body-angle checks.
  ///
  /// Bad-form checks (matching Android TFLite training labels):
  ///   - Hip sag: hips drop below the shoulder-ankle line
  ///   - Bad head position: nose far above or below the shoulder line
  ///   - Bad arm extension: elbow angle outside push-up range
  ///   - Not deep enough: detected by pushup_analyzer via movement threshold,
  ///     but elbow angle at bottom < ~70° is a proxy from the side
  FormPrediction? _classifySideView(
    Map<String, Map<String, double>> landmarks,
    Map<String, double> lS,
    Map<String, double> rS,
    Map<String, double>? lH,
    Map<String, double>? rH,
    Map<String, double>? lE,
    Map<String, double>? rE,
    Map<String, double>? lW,
    Map<String, double>? rW,
    Map<String, double>? nose,
    double hipVis,
    double deviceAngle,
  ) {
    // Side view requires hips for body-horizontal check
    if (hipVis < 0.2 || lH == null || rH == null) return null;

    final shoulderY = (lS['y']! + rS['y']!) / 2;
    final hipY = (lH['y']! + rH['y']!) / 2;
    final shoulderX = (lS['x']! + rS['x']!) / 2;
    final hipX = (lH['x']! + rH['x']!) / 2;

    final isLandscape = deviceAngle == 90 || deviceAngle == 270;
    final double gravityGap;
    final double alongBodyGap;
    if (isLandscape) {
      gravityGap = (hipX - shoulderX).abs();
      alongBodyGap = (hipY - shoulderY).abs();
    } else {
      gravityGap = (hipY - shoulderY).abs();
      alongBodyGap = (hipX - shoulderX).abs();
    }

    // ── 1. Standing / not-exercise detection ─────────────────────────────────
    if (nose != null) {
      final double noseGravity;
      final double hipGravity;
      if (isLandscape) {
        noseGravity = nose['x']!;
        hipGravity = (lH['x']! + rH['x']!) / 2;
      } else {
        noseGravity = nose['y']!;
        hipGravity = hipY;
      }
      final noseToHipGravity = (hipGravity - noseGravity).abs();
      if (noseGravity < hipGravity && noseToHipGravity > 0.30) {
        return const FormPrediction('not_exercise', 0.8, [0.05, 0.05, 0.9]);
      }
    }

    if (gravityGap > 0.25 && gravityGap > alongBodyGap * 1.5) {
      return const FormPrediction('not_exercise', 0.75, [0.05, 0.1, 0.85]);
    }

    final bodyHorizontal = gravityGap < 0.15 || alongBodyGap >= gravityGap;
    if (!bodyHorizontal) {
      return const FormPrediction('not_exercise', 0.65, [0.1, 0.1, 0.8]);
    }

    // ── 2. Form quality checks ───────────────────────────────────────────────
    bool hasBadForm = false;

    // ── 2a. Hip sag detection ────────────────────────────────────────────────
    // From the side: in a good push-up the body is a straight plank —
    // shoulder, hip, and ankle should be roughly aligned along the gravity axis.
    // If hips drop below the shoulder-ankle line, core is sagging.
    final double shoulderGrav;
    final double hipGrav;
    if (isLandscape) {
      shoulderGrav = shoulderX;
      hipGrav = hipX;
    } else {
      shoulderGrav = shoulderY;
      hipGrav = hipY;
    }

    // Check ankle if available for a proper plank-line check
    final lA = landmarks['LEFT_ANKLE'];
    final rA = landmarks['RIGHT_ANKLE'];
    final lAvis = lA?['visibility'] ?? 0.0;
    final rAvis = rA?['visibility'] ?? 0.0;

    if (lAvis > 0.15 || rAvis > 0.15) {
      // Use the more visible ankle
      final ankle = (lAvis > rAvis) ? lA! : rA!;
      final double ankleGrav = isLandscape ? ankle['x']! : ankle['y']!;
      // Expected hip position = midpoint between shoulder and ankle on gravity axis
      final expectedHipGrav = (shoulderGrav + ankleGrav) / 2;
      // If hip is significantly below (higher gravity value) the expected line → sag
      final hipDeviation = hipGrav - expectedHipGrav;
      if (hipDeviation > 0.06) {
        hasBadForm = true;
      }
    } else {
      // No ankle data — fall back to shoulder-hip gravity gap.
      // In a plank, shoulder and hip should be close on the gravity axis.
      // If hip drops far below shoulder, it's sagging.
      final hipSag = hipGrav - shoulderGrav;
      if (hipSag > 0.10) {
        hasBadForm = true;
      }
    }

    // ── 2b. Head position check ──────────────────────────────────────────────
    // From the side: nose should be roughly aligned with the shoulder on the
    // gravity axis. Head drooping (nose below shoulder) or craning up (nose
    // way above shoulder) = bad head position.
    if (nose != null) {
      final double noseGrav = isLandscape ? nose['x']! : nose['y']!;
      final headDrop = noseGrav - shoulderGrav; // positive = below shoulder
      final headCrane = shoulderGrav - noseGrav; // positive = above shoulder
      if (headDrop > 0.08 || headCrane > 0.12) {
        hasBadForm = true;
      }
    }

    // ── 2c. Elbow angle check ────────────────────────────────────────────────
    final leftArmVis  = min(lE?['visibility'] ?? 0.0, lW?['visibility'] ?? 0.0);
    final rightArmVis = min(rE?['visibility'] ?? 0.0, rW?['visibility'] ?? 0.0);

    double? elbowAngle;
    if (leftArmVis > 0.2 && lE != null && lW != null) {
      elbowAngle = _angle(lS, lE, lW);
    } else if (rightArmVis > 0.2 && rE != null && rW != null) {
      elbowAngle = _angle(rS, rE, rW);
    }

    if (elbowAngle != null) {
      // Arms at extreme angles = bad extension
      if (elbowAngle <= 40 || elbowAngle >= 170) {
        hasBadForm = true;
      }

      return hasBadForm
          ? const FormPrediction('bad_form', 0.7, [0.7, 0.1, 0.2])
          : const FormPrediction('good_form', 0.7, [0.1, 0.7, 0.2]);
    }

    // Body is horizontal but no arm data — if we detected other form issues,
    // flag as bad; otherwise return not_exercise to prevent ghost reps.
    if (hasBadForm) {
      return const FormPrediction('bad_form', 0.55, [0.55, 0.15, 0.3]);
    }
    return const FormPrediction('not_exercise', 0.5, [0.15, 0.15, 0.7]);
  }

  /// Calculate angle at point B given three landmarks A, B, C (in degrees).
  double _angle(
    Map<String, double> a,
    Map<String, double> b,
    Map<String, double> c,
  ) {
    final ax = a['x']! - b['x']!;
    final ay = a['y']! - b['y']!;
    final cx = c['x']! - b['x']!;
    final cy = c['y']! - b['y']!;
    final dot = ax * cx + ay * cy;
    final magA = sqrt(ax * ax + ay * ay);
    final magC = sqrt(cx * cx + cy * cy);
    if (magA == 0 || magC == 0) return 0;
    final cosAngle = (dot / (magA * magC)).clamp(-1.0, 1.0);
    return acos(cosAngle) * 180 / pi;
  }
}
