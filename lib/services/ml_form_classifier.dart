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
  final String label;           // 'good_form' | 'bad_form' | 'not_exercise'
  final double confidence;      // 0.0 – 1.0
  final List<double> allScores; // [bad_form, good_form, not_exercise]
  final List<String> issues;    // specific reasons when bad_form

  const FormPrediction(this.label, this.confidence, this.allScores,
      {this.issues = const []});

  bool get isGoodForm    => label == 'good_form';
  bool get isBadForm     => label == 'bad_form';
  bool get isNotExercise => label == 'not_exercise';

  double get badScore         => allScores[0];
  double get goodScore        => allScores[1];
  double get notExerciseScore => allScores[2];
}

class MLFormClassifier {
  Interpreter? _interpreter;

  /// Set externally from the workout screen. Currently only used to decide
  /// whether the workout screen should force portrait orientation on iPad —
  /// the classifier itself runs the same iPhone-tuned logic on both devices.
  bool isTablet = false;

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

  /// Diagnoses specific form issues using geometric analysis.
  /// Used on Android alongside the TFLite model — the model says *whether*
  /// form is bad; this says *why* (e.g. 'Hips too low', 'Arms too wide').
  List<String> diagnoseIssues(
    Map<String, Map<String, double>> landmarks, {
    double deviceAngle = 0,
  }) {
    final prediction = _geometricClassify(landmarks, deviceAngle: deviceAngle);
    return prediction?.issues ?? [];
  }

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

    // ── Viewing angle ────────────────────────────────────────────────────────
    // The app is portrait-only so the camera always faces the user head-on.
    // Side-view classification is shelved (kept below but not called) — it was
    // written for landscape mode which is no longer supported.
    // Previously this branched on shoulderSpread > 0.08 to detect side-vs-front;
    // now we always take the front-view path.
    return _classifyFrontView(landmarks, lS, rS, lH, rH, lE, rE, lW, rW,
        nose, hipVis, deviceAngle);
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

    // Nose way above shoulders = upright, not in push-up position.
    // Threshold raised from 0.20 → 0.35: looking at the camera during a push-up
    // (natural) or doing knee push-ups with head tilted up can put the nose
    // 0.15–0.25 above shoulders without it being a standing position.
    if (nose != null) {
      final noseAboveShoulders = shoulderY - nose['y']!;
      if (noseAboveShoulders > 0.35) {
        return const FormPrediction('not_exercise', 0.7, [0.05, 0.1, 0.85]);
      }
    }

    // Shoulders high in frame = standing/sitting.
    // Threshold lowered from 0.30 → 0.18: a close camera on the floor can put
    // shoulders at 0.20–0.28 even during a genuine push-up.
    if (shoulderY < 0.18) {
      return const FormPrediction('not_exercise', 0.55, [0.1, 0.15, 0.75]);
    }

    // ── 1b. Wrist visibility check ───────────────────────────────────────────
    // Arms must be engaged (wrists visible) to count as a push-up.
    // Hands behind back, bowing, or arms out of frame = wrists not visible = not exercise.
    final lWvis = lW?['visibility'] ?? 0.0;
    final rWvis = rW?['visibility'] ?? 0.0;
    final bestWristVis = max(lWvis, rWvis);
    if (bestWristVis < 0.2) {
      return const FormPrediction('not_exercise', 0.7, [0.05, 0.1, 0.85]);
    }

    // Wrists above shoulders = cat pose / stretch, not a push-up.
    if (lW != null && rW != null && min(lWvis, rWvis) > 0.2) {
      final wristY = (lW['y']! + rW['y']!) / 2;
      if (wristY < shoulderY - 0.06) {
        return const FormPrediction('not_exercise', 0.7, [0.05, 0.1, 0.85]);
      }
    }

    // ── 2. Form quality check: elbow flare only ──────────────────────────────
    // Elbows flared = elbows at or past shoulder width when viewed from the front.
    final issues = <String>[];

    if (lE != null && rE != null) {
      final lEvis = lE['visibility'] ?? 0.0;
      final rEvis = rE['visibility'] ?? 0.0;
      if (lEvis > 0.2 && rEvis > 0.2) {
        final elbowSpread  = (lE['x']! - rE['x']!).abs();
        final shoulderWidth = (lS['x']! - rS['x']!).abs();
        if (shoulderWidth > 0.01 && elbowSpread >= shoulderWidth) {
          issues.add('Elbows flared out');
        }
      }
    }

    // No arm data — only accept as exercise if hips are also visible.
    if (lE == null && rE == null) {
      if (hipVis < 0.2) {
        return const FormPrediction('not_exercise', 0.7, [0.05, 0.05, 0.9]);
      }
    }

    return issues.isNotEmpty
        ? FormPrediction('bad_form', 0.65, [0.65, 0.15, 0.2], issues: issues)
        : const FormPrediction('good_form', 0.65, [0.1, 0.65, 0.25]);
  }

  /// [SHELVED — portrait-only] Side-view classification for landscape mode.
  /// Not called while the app is portrait-locked. Kept for potential future use.
  ///
  /// Side-view classification: full body visible from the side (typical landscape).
  /// Both shoulders and hips should be visible for body-angle checks.
  ///
  /// Bad-form checks (matching Android TFLite training labels):
  ///   - Hip sag: hips drop below the shoulder-ankle line
  ///   - Bad head position: nose far above or below the shoulder line
  ///   - Bad arm extension: elbow angle outside push-up range
  ///   - Not deep enough: detected by pushup_analyzer via movement threshold,
  ///     but elbow angle at bottom < ~70° is a proxy from the side
  // ignore: unused_element
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

    // Side view — elbow flare can't be reliably detected from this angle.
    // Body is horizontal = good form. No specific issue checks.
    return const FormPrediction('good_form', 0.7, [0.1, 0.7, 0.2]);
  }

}
