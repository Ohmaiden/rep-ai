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

  /// Geometric form classifier for iOS — uses landmark angles instead of the
  /// TFLite model (which was trained on Android data and doesn't generalise).
  /// Returns null if not enough landmarks are visible to make a judgement.
  FormPrediction? _geometricClassify(Map<String, Map<String, double>> landmarks) {
    final lS = landmarks['LEFT_SHOULDER'];
    final rS = landmarks['RIGHT_SHOULDER'];
    final lE = landmarks['LEFT_ELBOW'];
    final rE = landmarks['RIGHT_ELBOW'];
    final lW = landmarks['LEFT_WRIST'];
    final rW = landmarks['RIGHT_WRIST'];
    final lH = landmarks['LEFT_HIP'];
    final rH = landmarks['RIGHT_HIP'];

    // Need at minimum: both shoulders, one elbow+wrist pair, both hips
    final shoulderVis = ((lS?['visibility'] ?? 0.0) + (rS?['visibility'] ?? 0.0)) / 2;
    final hipVis      = ((lH?['visibility'] ?? 0.0) + (rH?['visibility'] ?? 0.0)) / 2;
    final leftArmVis  = min(lE?['visibility'] ?? 0.0, lW?['visibility'] ?? 0.0);
    final rightArmVis = min(rE?['visibility'] ?? 0.0, rW?['visibility'] ?? 0.0);
    final hasArm      = leftArmVis > 0.15 || rightArmVis > 0.15;

    if (shoulderVis < 0.2 || hipVis < 0.2 || !hasArm) return null;

    // Calculate elbow angle (shoulder → elbow → wrist)
    // In a push-up: arm should be somewhat bent (not fully extended)
    double? elbowAngle;
    if (leftArmVis > rightArmVis && lS != null && lE != null && lW != null) {
      elbowAngle = _angle(lS, lE, lW);
    } else if (rS != null && rE != null && rW != null) {
      elbowAngle = _angle(rS, rE, rW);
    }

    // Calculate body alignment (shoulder midpoint to hip midpoint should be roughly horizontal)
    double? bodyAngle;
    if (lS != null && rS != null && lH != null && rH != null) {
      final midShoulderX = (lS['x']! + rS['x']!) / 2;
      final midShoulderY = (lS['y']! + rS['y']!) / 2;
      final midHipX = (lH['x']! + rH['x']!) / 2;
      final midHipY = (lH['y']! + rH['y']!) / 2;
      final dx = midHipX - midShoulderX;
      final dy = midHipY - midShoulderY;
      bodyAngle = (atan2(dy.abs(), dx.abs()) * 180 / pi);
    }

    // Determine form:
    // Good form: body roughly horizontal (push-up position) + elbow somewhat bent
    // Not exercise: body vertical (standing)
    if (bodyAngle != null && bodyAngle < 30) {
      // Body too vertical — standing up, not in push-up position
      return const FormPrediction('not_exercise', 0.7, [0.1, 0.1, 0.8]);
    }

    if (elbowAngle != null) {
      // Elbow angle: < 90° = too bent (going down), 90-160° = good form range, > 160° = arms too straight
      if (elbowAngle > 50 && elbowAngle < 170) {
        return FormPrediction('good_form', 0.7, [0.1, 0.7, 0.2]);
      } else {
        return FormPrediction('bad_form', 0.6, [0.6, 0.2, 0.2]);
      }
    }

    // Visible pose but can't determine form clearly
    return const FormPrediction('good_form', 0.5, [0.2, 0.5, 0.3]);
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
