/// Geometry Utilities
/// ===================
/// Angle calculations, smoothing, hysteresis, debouncing.
/// Direct port from the Python version.
library;

import 'dart:math';

/// Calculate the angle at point B formed by points A-B-C.
///
/// Think of it like your elbow: A=shoulder, B=elbow, C=wrist.
/// Returns the angle in degrees (0-180).
///
/// [ax, ay] = point A coordinates
/// [bx, by] = point B coordinates (vertex)
/// [cx, cy] = point C coordinates
double calcAngle(
  double ax, double ay,
  double bx, double by,
  double cx, double cy,
) {
  // Vectors from B to A and from B to C
  final bax = ax - bx;
  final bay = ay - by;
  final bcx = cx - bx;
  final bcy = cy - by;

  // Dot product: BA . BC
  final dot = bax * bcx + bay * bcy;

  // Magnitudes: |BA| and |BC|
  final magBA = sqrt(bax * bax + bay * bay);
  final magBC = sqrt(bcx * bcx + bcy * bcy);

  // Avoid division by zero
  if (magBA < 1e-9 || magBC < 1e-9) return 0;

  // cos(theta) = dot / (|BA| * |BC|)
  double cosine = dot / (magBA * magBC);

  // Clamp to [-1, 1] for floating point safety
  cosine = cosine.clamp(-1.0, 1.0);

  // Convert to degrees
  return acos(cosine) * 180 / pi;
}

/// Exponential Moving Average filter for smoothing noisy signals.
///
/// smoothed = alpha * newValue + (1 - alpha) * oldSmoothed
///
/// alpha close to 1.0 = responsive but noisy
/// alpha close to 0.0 = smooth but laggy
class SmoothedValue {
  final double alpha;
  double? _value;

  SmoothedValue({this.alpha = 0.4});

  double update(double newValue) {
    if (_value == null) {
      _value = newValue;
    } else {
      _value = alpha * newValue + (1 - alpha) * _value!;
    }
    return _value!;
  }

  double? get value => _value;

  void reset() => _value = null;
}

/// Prevents rapid toggling between states using a dead zone.
///
/// Must go BELOW lowThreshold to enter "down" state.
/// Must go ABOVE highThreshold to enter "up" state.
/// Between the two thresholds: stays in whatever state it was in.
class HysteresisTracker {
  final double lowThreshold;
  final double highThreshold;
  String state;

  HysteresisTracker({
    required this.lowThreshold,
    required this.highThreshold,
    this.state = "up",
  });

  String update(double value) {
    if (state == "up" && value < lowThreshold) {
      state = "down";
    } else if (state == "down" && value > highThreshold) {
      state = "up";
    }
    return state;
  }

  void reset() => state = "up";
}

/// Prevents double-counting reps by enforcing a minimum time between reps.
class RepDebouncer {
  Duration minInterval;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  RepDebouncer({this.minInterval = const Duration(milliseconds: 400)});

  bool canCount() {
    final now = DateTime.now();
    if (now.difference(_lastRepTime) >= minInterval) {
      _lastRepTime = now;
      return true;
    }
    return false;
  }

  void reset() => _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
}
