/// Workout State Manager
/// ======================
/// Manages the state of a live workout session.
/// Supports both free mode and custom sets mode.
library;

import 'package:flutter/foundation.dart';
import '../models/workout_models.dart';
import 'pushup_analyzer.dart';
import 'ml_form_classifier.dart';
import 'audio_service.dart';

class WorkoutState extends ChangeNotifier {
  final PushUpAnalyzer _analyzer = PushUpAnalyzer();
  final MLFormClassifier _ml = MLFormClassifier();
  WorkoutAudioService? _audio;

  bool _isActive = false;
  DateTime? _sessionStart;
  String _exercise = 'Push-ups';
  FormPrediction? _currentForm;
  bool _usingFallback = false;
  double _deviceAngle = 0;

  // Custom workout plan
  bool _isCustom = false;
  int _totalSets = 1;
  int _targetReps = 0;
  int _restSeconds = 60;
  int _currentSet = 1;
  List<int> _setGoodReps = [];
  List<int> _setBadReps = [];
  int _setStartGoodReps = 0;
  int _setStartBadReps = 0;

  double get deviceAngle => _deviceAngle;
  void setDeviceAngle(double angle) => _deviceAngle = angle;

  /// Attach the audio service so rep sounds fire synchronously with increments.
  void setAudioService(WorkoutAudioService audio) => _audio = audio;

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isActive         => _isActive;
  int  get repCount         => _analyzer.repCount;
  int  get attemptCount     => _analyzer.attemptCount;
  ExercisePhase get phase   => _analyzer.phase;
  List<String> get feedback         => _analyzer.feedback;
  List<String> get lastRepFeedback  => _analyzer.lastRepFeedback;
  bool? get lastRepValid    => _analyzer.lastRepValid;
  DateTime? get lastRepTime => _analyzer.lastRepTime;
  PoseMetrics get metrics   => _analyzer.latestMetrics;
  String get exercise       => _exercise;
  int get goodFormReps      => _analyzer.goodFormReps;
  int get badFormReps       => _analyzer.badFormReps;
  List<RepResult> get repHistory => _analyzer.repHistory;
  // Only expose the form prediction to the badge if ML was actually confident.
  // The fallback prediction is used internally for rep counting only.
  FormPrediction? get currentForm => _usingFallback ? null : _currentForm;

  // Custom workout getters
  bool get isCustom       => _isCustom;
  int get totalSets       => _totalSets;
  int get targetReps      => _targetReps;
  int get restSeconds     => _restSeconds;
  int get currentSet      => _currentSet;
  List<int> get setGoodReps => List.unmodifiable(_setGoodReps);
  List<int> get setBadReps  => List.unmodifiable(_setBadReps);

  /// Good reps in the current set
  int get currentSetGoodReps => _analyzer.goodFormReps - _setStartGoodReps;

  /// Whether the current set's target has been reached
  bool get isSetComplete => _isCustom && currentSetGoodReps >= _targetReps;

  /// Whether all sets are done
  bool get isWorkoutComplete => _isCustom && _currentSet > _totalSets;

  /// Whether the phone appears to be upside-down (debounced, 10+ frames)
  bool get isUpsideDown => _analyzer.isUpsideDown;

  /// Title for the flip overlay (depends on which bad angle is detected)
  String get flipMessageTitle => _analyzer.flipMessageTitle;

  /// Subtitle for the flip overlay
  String get flipMessageSubtitle => _analyzer.flipMessageSubtitle;

  Duration get elapsed {
    if (_sessionStart == null) return Duration.zero;
    return DateTime.now().difference(_sessionStart!);
  }

  Future<void> initML() async {
    try {
      await _ml.initialize();
    } catch (e) {
      // ML init failed silently — will use fallback
    }
  }

  // ── Free workout ──────────────────────────────────────────────────────

  void startSession({String exercise = 'Push-ups'}) {
    _exercise = exercise;
    _isActive = true;
    _isCustom = false;
    _sessionStart = DateTime.now();
    _currentForm = null;
    _analyzer.reset();
    _resetSetTracking();
    notifyListeners();
  }

  // ── Custom workout ────────────────────────────────────────────────────

  void startCustomSession({
    required int sets,
    required int reps,
    required int restSeconds,
    String exercise = 'Push-ups',
  }) {
    _exercise = exercise;
    _isActive = true;
    _isCustom = true;
    _totalSets = sets;
    _targetReps = reps;
    _restSeconds = restSeconds;
    _currentSet = 1;
    _sessionStart = DateTime.now();
    _currentForm = null;
    _analyzer.reset();
    _setGoodReps = [];
    _setBadReps = [];
    _setStartGoodReps = 0;
    _setStartBadReps = 0;
    notifyListeners();
  }

  /// Called when a set is complete. Records set data and advances.
  void finishCurrentSet() {
    final goodInSet = _analyzer.goodFormReps - _setStartGoodReps;
    final badInSet = _analyzer.badFormReps - _setStartBadReps;
    _setGoodReps.add(goodInSet);
    _setBadReps.add(badInSet);
    _currentSet++;
    _setStartGoodReps = _analyzer.goodFormReps;
    _setStartBadReps = _analyzer.badFormReps;
    notifyListeners();
  }

  void _resetSetTracking() {
    _totalSets = 1;
    _targetReps = 0;
    _restSeconds = 60;
    _currentSet = 1;
    _setGoodReps = [];
    _setBadReps = [];
    _setStartGoodReps = 0;
    _setStartBadReps = 0;
  }

  // ── Common ────────────────────────────────────────────────────────────

  void processLandmarks(Map<String, Map<String, double>> landmarks) {
    if (!_isActive) return;

    if (_ml.isReady) {
      _currentForm = _ml.classify(landmarks);
    }

    // If ML model returns null or not_exercise but we have a valid full-body
    // pose, synthesise a prediction for rep counting only (not badge display).
    // Requires shoulders + hips + at least one knee/ankle — prevents
    // face-only or upper-body-only frames from triggering.
    final mlWasConfident = _currentForm != null && !_currentForm!.isNotExercise;
    if (!mlWasConfident) {
      final lSvis  = landmarks['LEFT_SHOULDER']?['visibility']  ?? 0.0;
      final rSvis  = landmarks['RIGHT_SHOULDER']?['visibility'] ?? 0.0;
      final lHvis  = landmarks['LEFT_HIP']?['visibility']       ?? 0.0;
      final rHvis  = landmarks['RIGHT_HIP']?['visibility']      ?? 0.0;
      final lKvis  = landmarks['LEFT_KNEE']?['visibility']      ?? 0.0;
      final rKvis  = landmarks['RIGHT_KNEE']?['visibility']     ?? 0.0;
      final lAvis  = landmarks['LEFT_ANKLE']?['visibility']     ?? 0.0;
      final rAvis  = landmarks['RIGHT_ANKLE']?['visibility']    ?? 0.0;
      final hasLegs = lKvis > 0.15 || rKvis > 0.15 || lAvis > 0.15 || rAvis > 0.15;
      final hasFullBody = lSvis > 0.2 && rSvis > 0.2 &&
                          lHvis > 0.2 && rHvis > 0.2 && hasLegs;
      if (hasFullBody) {
        _currentForm = const FormPrediction('good_form', 0.6, [0.1, 0.6, 0.3]);
        _usingFallback = true;
      } else {
        _usingFallback = false;
      }
    } else {
      _usingFallback = false;
    }

    final prevGoodReps = _analyzer.goodFormReps;
    final prevAttempts = _analyzer.attemptCount;

    // When using the pose fallback (ML didn't fire), pass null to the analyzer
    // so it doesn't count reps. Rep counting only happens when the ML model
    // is actually confident about form. This prevents false reps on iOS when
    // the model isn't generalising to bgra8888 coordinates.
    final labelForAnalyzer = _usingFallback ? null : _currentForm?.label;
    _analyzer.update(landmarks,
        mlFormLabel: labelForAnalyzer, deviceAngle: _deviceAngle);

    // Fire audio synchronously with the counter increment — before notifyListeners().
    if (_audio != null) {
      if (_analyzer.goodFormReps > prevGoodReps) {
        // Good rep: fires at the exact same moment the counter goes up
        _audio!.playGoodRep();
      } else if (_analyzer.attemptCount > prevAttempts) {
        // Bad rep: attempt went up but good count didn't
        _audio!.playBadRep();
      }
    }

    notifyListeners();
  }

  WorkoutSession? endSession() {
    if (!_isActive || _sessionStart == null) return null;

    // If custom and there are unreported set reps, record them
    if (_isCustom && _currentSet <= _totalSets) {
      final goodInSet = _analyzer.goodFormReps - _setStartGoodReps;
      final badInSet = _analyzer.badFormReps - _setStartBadReps;
      if (goodInSet > 0 || badInSet > 0) {
        _setGoodReps.add(goodInSet);
        _setBadReps.add(badInSet);
      }
    }

    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exercise: _exercise,
      totalReps: _analyzer.attemptCount,
      goodFormReps: _analyzer.goodFormReps,
      badFormReps: _analyzer.badFormReps,
      duration: DateTime.now().difference(_sessionStart!),
      startedAt: _sessionStart!,
      formIssues: _analyzer.formIssueSummary.keys.toList(),
    );

    _isActive = false;
    _sessionStart = null;
    _currentForm = null;
    notifyListeners();

    return session;
  }

  void resetSession() {
    _analyzer.reset();
    _sessionStart = DateTime.now();
    _currentForm = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ml.dispose();
    super.dispose();
  }
}
