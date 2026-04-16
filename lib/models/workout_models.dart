/// Data Models
/// ============
/// Defines the data structures used throughout the app.
library;

/// Represents a single workout session.
/// A session is one continuous block of exercise (e.g., "20 push-ups on March 9th").
class WorkoutSession {
  final String id;
  final String exercise;
  final int totalReps;
  final int goodFormReps;    // Reps with no form issues
  final int badFormReps;     // Reps with at least one form issue
  final Duration duration;
  final DateTime startedAt;
  final List<String> formIssues; // Aggregated form issues from the session

  WorkoutSession({
    required this.id,
    required this.exercise,
    required this.totalReps,
    required this.goodFormReps,
    required this.badFormReps,
    required this.duration,
    required this.startedAt,
    this.formIssues = const [],
  });

  /// Form score as a percentage (0-100)
  double get formScore {
    if (totalReps == 0) return 0;
    return (goodFormReps / totalReps) * 100;
  }

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise': exercise,
      'total_reps': totalReps,
      'good_form_reps': goodFormReps,
      'bad_form_reps': badFormReps,
      'duration_seconds': duration.inSeconds,
      'started_at': startedAt.toIso8601String(),
      'form_issues': formIssues.join('|'), // Join with pipe delimiter
    };
  }

  /// Create from database Map
  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      exercise: map['exercise'] as String,
      totalReps: map['total_reps'] as int,
      goodFormReps: map['good_form_reps'] as int,
      badFormReps: map['bad_form_reps'] as int,
      duration: Duration(seconds: map['duration_seconds'] as int),
      startedAt: DateTime.parse(map['started_at'] as String),
      formIssues: (map['form_issues'] as String?)?.isNotEmpty == true
          ? (map['form_issues'] as String).split('|')
          : [],
    );
  }
}

/// Represents a single rep within a workout.
/// Used during a live session to track per-rep form.
class RepResult {
  final int repNumber;
  final bool goodForm;
  final List<String> issues;
  final Duration repDuration;

  RepResult({
    required this.repNumber,
    required this.goodForm,
    this.issues = const [],
    required this.repDuration,
  });
}

/// Pose detection result from a single frame.
/// Contains the landmark positions and calculated metrics.
class PoseMetrics {
  final double? elbowAngle;      // Smoothed elbow angle
  final double? elbowAngleRaw;   // Raw elbow angle
  final double? hipAngle;         // Shoulder-hip-ankle angle
  final double? headOffset;       // Ear-shoulder Y offset (normalized)
  final String side;              // "LEFT" or "RIGHT"
  final bool poseDetected;        // Whether a pose was found

  PoseMetrics({
    this.elbowAngle,
    this.elbowAngleRaw,
    this.hipAngle,
    this.headOffset,
    this.side = "NONE",
    this.poseDetected = false,
  });
}

/// State of the push-up state machine.
enum ExercisePhase {
  idle,   // Waiting to start
  up,     // Arms extended (top of push-up)
  down,   // Arms bent (bottom of push-up)
}

/// A screenshot captured at the worst-form moment of a bad-form rep.
/// Saved as a PNG file in the app's documents directory so the user can
/// view and delete it. Nothing is uploaded or shared.
class BadFormCapture {
  final String filePath;     // absolute path to the on-device PNG
  final List<String> issues; // form issues detected during that rep
  final int repNumber;

  const BadFormCapture({
    required this.filePath,
    required this.issues,
    required this.repNumber,
  });
}
