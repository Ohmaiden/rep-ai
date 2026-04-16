/// Push-Up Animation Widget
/// =========================
/// Animated side-view stick-figure demonstrating each push-up variation.
/// Uses CustomPainter to draw the figure and AnimationController to loop
/// smoothly between the top (arms extended) and bottom (arms bent) positions.
///
/// Nothing is recorded or stored — this is purely a visual guide.
library;

import 'package:flutter/material.dart';

// ── Variation enum & metadata ─────────────────────────────────────────────────

enum PushUpVariation { standard, wide, diamond, knee, pike, decline }

extension PushUpVariationInfo on PushUpVariation {
  String get displayName {
    switch (this) {
      case PushUpVariation.standard: return 'Standard';
      case PushUpVariation.wide:     return 'Wide Grip';
      case PushUpVariation.diamond:  return 'Diamond';
      case PushUpVariation.knee:     return 'Knee';
      case PushUpVariation.pike:     return 'Pike';
      case PushUpVariation.decline:  return 'Decline';
    }
  }

  List<String> get keyPoints {
    switch (this) {
      case PushUpVariation.standard:
        return [
          'Hands shoulder-width apart',
          'Body in a straight line from head to heels',
          'Lower your chest toward the floor',
          'Keep elbows at roughly 45° to your body',
        ];
      case PushUpVariation.wide:
        return [
          'Hands wider than shoulder-width',
          'Targets the outer chest and shoulders',
          'Elbows track outward as you lower',
          'Keep hips level throughout',
        ];
      case PushUpVariation.diamond:
        return [
          'Hands form a triangle shape under your chest',
          'Targets the triceps and inner chest',
          'Elbows draw back along your sides as you lower',
          'The most challenging push-up variation',
        ];
      case PushUpVariation.knee:
        return [
          'Knees rest on the floor, feet raised',
          'Keep a straight line from knees to shoulders',
          'Great starting point for beginners',
          'Same chest and arm movement as standard',
        ];
      case PushUpVariation.pike:
        return [
          'Start with hips raised high — inverted V shape',
          'Targets the shoulders more than the chest',
          'Bend elbows to lower your head toward the floor',
          'Feet and hands stay planted throughout',
        ];
      case PushUpVariation.decline:
        return [
          'Feet elevated on a chair, step, or bench',
          'Targets the upper chest and front shoulders',
          'Body is angled downward throughout',
          'More demanding than the standard push-up',
        ];
    }
  }
}

// ── Pose data (normalised 0–1 coords, origin = top-left) ─────────────────────
// Ground line at y = 0.78.  All poses are in the same coordinate space so
// the painter can lerp directly between them.

class _Pose {
  final Offset hand;      // hand contact with floor
  final Offset elbow;     // elbow joint
  final Offset shoulder;  // shoulder joint
  final Offset hip;       // hip joint
  final Offset knee;      // knee joint
  final Offset ankle;     // foot/ankle contact (or elevated for decline)
  final Offset head;      // centre of head circle
  final double headR;     // head radius (fraction of canvas height)

  const _Pose({
    required this.hand,
    required this.elbow,
    required this.shoulder,
    required this.hip,
    required this.knee,
    required this.ankle,
    required this.head,
    this.headR = 0.075,
  });

  _Pose lerp(_Pose b, double t) => _Pose(
        hand:     Offset.lerp(hand,     b.hand,     t)!,
        elbow:    Offset.lerp(elbow,    b.elbow,    t)!,
        shoulder: Offset.lerp(shoulder, b.shoulder, t)!,
        hip:      Offset.lerp(hip,      b.hip,      t)!,
        knee:     Offset.lerp(knee,     b.knee,     t)!,
        ankle:    Offset.lerp(ankle,    b.ankle,    t)!,
        head:     Offset.lerp(head,     b.head,     t)!,
        headR:    headR,
      );
}

const double _kG = 0.78; // ground Y

// Pose definitions — person facing right, side view.
// TOP  = arms fully extended.   BOTTOM = arms bent ~90°.

const _kTopStandard = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.73, 0.60),
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.47),
  knee:     Offset(0.28, 0.67),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotStandard = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.61, 0.74),
  shoulder: Offset(0.66, 0.67),
  hip:      Offset(0.37, 0.67),
  knee:     Offset(0.28, 0.73),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.57),
);

const _kTopWide = _Pose(
  hand:     Offset(0.83, _kG),
  elbow:    Offset(0.81, 0.60),
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.47),
  knee:     Offset(0.28, 0.67),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotWide = _Pose(
  hand:     Offset(0.83, _kG),
  elbow:    Offset(0.79, 0.71),  // elbows flare out for wide grip
  shoulder: Offset(0.66, 0.67),
  hip:      Offset(0.37, 0.67),
  knee:     Offset(0.28, 0.73),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.57),
);

const _kTopDiamond = _Pose(
  hand:     Offset(0.66, _kG),   // hands close under chest
  elbow:    Offset(0.63, 0.60),
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.47),
  knee:     Offset(0.28, 0.67),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotDiamond = _Pose(
  hand:     Offset(0.66, _kG),
  elbow:    Offset(0.52, 0.73),  // elbows flare wide
  shoulder: Offset(0.66, 0.67),
  hip:      Offset(0.37, 0.67),
  knee:     Offset(0.28, 0.73),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.57),
);

const _kTopKnee = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.73, 0.62),
  shoulder: Offset(0.66, 0.50),
  hip:      Offset(0.42, 0.53),  // body at slight angle, knees as pivot
  knee:     Offset(0.27, _kG),   // KNEE ON GROUND
  ankle:    Offset(0.20, 0.69),  // feet raised
  head:     Offset(0.73, 0.40),
);
const _kBotKnee = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.61, 0.74),
  shoulder: Offset(0.66, 0.68),
  hip:      Offset(0.42, 0.71),
  knee:     Offset(0.27, _kG),   // stays on ground
  ankle:    Offset(0.20, 0.69),  // stays raised
  head:     Offset(0.73, 0.58),
);

const _kTopPike = _Pose(
  hand:     Offset(0.42, _kG),
  elbow:    Offset(0.41, 0.58),
  shoulder: Offset(0.44, 0.47),
  hip:      Offset(0.50, 0.22),  // hips HIGH — apex of the V
  knee:     Offset(0.54, 0.49),
  ankle:    Offset(0.57, _kG),
  head:     Offset(0.38, 0.60),  // head between/below arms, looking down
);
const _kBotPike = _Pose(
  hand:     Offset(0.42, _kG),
  elbow:    Offset(0.35, 0.70),  // elbows bend — head goes toward floor
  shoulder: Offset(0.44, 0.62),
  hip:      Offset(0.50, 0.34),  // hips drop somewhat
  knee:     Offset(0.54, 0.53),
  ankle:    Offset(0.57, _kG),
  head:     Offset(0.38, 0.74),  // close to ground
);

const _kTopDecline = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.74, 0.62),
  shoulder: Offset(0.67, 0.52),
  hip:      Offset(0.42, 0.39),  // body angled (feet up, head down)
  knee:     Offset(0.30, 0.28),
  ankle:    Offset(0.20, 0.23),  // ELEVATED
  head:     Offset(0.74, 0.62),  // head is lower than shoulder in decline
);
const _kBotDecline = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.63, 0.73),
  shoulder: Offset(0.67, 0.70),
  hip:      Offset(0.42, 0.53),
  knee:     Offset(0.30, 0.28),  // stays elevated
  ankle:    Offset(0.20, 0.23),  // stays elevated
  head:     Offset(0.74, 0.76),  // near floor
);

({_Pose top, _Pose bottom, bool showPlatform, bool kneeOnGround})
    _posesFor(PushUpVariation v) {
  switch (v) {
    case PushUpVariation.standard:
      return (top: _kTopStandard, bottom: _kBotStandard,
              showPlatform: false, kneeOnGround: false);
    case PushUpVariation.wide:
      return (top: _kTopWide, bottom: _kBotWide,
              showPlatform: false, kneeOnGround: false);
    case PushUpVariation.diamond:
      return (top: _kTopDiamond, bottom: _kBotDiamond,
              showPlatform: false, kneeOnGround: false);
    case PushUpVariation.knee:
      return (top: _kTopKnee, bottom: _kBotKnee,
              showPlatform: false, kneeOnGround: true);
    case PushUpVariation.pike:
      return (top: _kTopPike, bottom: _kBotPike,
              showPlatform: false, kneeOnGround: false);
    case PushUpVariation.decline:
      return (top: _kTopDecline, bottom: _kBotDecline,
              showPlatform: true, kneeOnGround: false);
  }
}

// ── Animation widget ──────────────────────────────────────────────────────────

class PushUpAnimationWidget extends StatefulWidget {
  final PushUpVariation variation;
  final double height;

  const PushUpAnimationWidget({
    required this.variation,
    this.height = 180,
    super.key,
  });

  @override
  State<PushUpAnimationWidget> createState() => _PushUpAnimationWidgetState();
}

class _PushUpAnimationWidgetState extends State<PushUpAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Durations for each phase
  static const _downMs  = 1200; // top → bottom
  static const _holdBot =  600; // pause at bottom
  static const _upMs    = 1000; // bottom → top
  static const _holdTop = 1200; // pause at top
  static const _cycleMs = _downMs + _holdBot + _upMs + _holdTop;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _cycleMs),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Maps controller value (0→1 linear) to pose progress (0=top, 1=bottom).
  double _progress(double t) {
    // Phase boundaries in [0,1]
    const pDownEnd   = _downMs  / _cycleMs;
    const pHoldBotEnd = (_downMs + _holdBot) / _cycleMs;
    const pUpEnd     = (_downMs + _holdBot + _upMs) / _cycleMs;

    if (t < pDownEnd) {
      // Going down
      return Curves.easeInOut.transform(t / pDownEnd);
    } else if (t < pHoldBotEnd) {
      // Hold at bottom
      return 1.0;
    } else if (t < pUpEnd) {
      // Going up
      return 1.0 - Curves.easeInOut.transform((t - pHoldBotEnd) / (_upMs / _cycleMs));
    } else {
      // Hold at top
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF93C5FD) // lighter blue in dark mode
        : const Color(0xFF2563EB);
    final groundColor = Theme.of(context).dividerColor;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final progress = _progress(_ctrl.value);
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _PushUpPainter(
            variation: widget.variation,
            progress: progress,
            color: color,
            groundColor: groundColor,
          ),
        );
      },
    );
  }
}

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _PushUpPainter extends CustomPainter {
  final PushUpVariation variation;
  final double progress; // 0 = top (arms extended), 1 = bottom (arms bent)
  final Color color;
  final Color groundColor;

  const _PushUpPainter({
    required this.variation,
    required this.progress,
    required this.color,
    required this.groundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = _posesFor(variation);
    final pose = data.top.lerp(data.bottom, progress);

    // Scale helper: normalised → canvas pixel
    Offset s(Offset o) => Offset(o.dx * size.width, o.dy * size.height);

    final bodyPaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.028
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final thinPaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.020
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final groundPaint = Paint()
      ..color = groundColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final headFill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    // Ground line
    canvas.drawLine(
      Offset(0, _kG * size.height),
      Offset(size.width, _kG * size.height),
      groundPaint,
    );

    // Decline platform (small box under elevated feet)
    if (data.showPlatform) {
      final px = pose.ankle.dx * size.width;
      final py = _kG * size.height;
      final platformTop = pose.ankle.dy * size.height;
      final platformW = size.width * 0.10;
      final platformPaint = Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.40)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final rect = Rect.fromLTRB(
        px - platformW / 2, platformTop,
        px + platformW / 2, py,
      );
      final rRect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rRect, platformPaint);
      canvas.drawRRect(rRect, borderPaint);
    }

    // Knee contact dot (for knee push-up)
    if (data.kneeOnGround) {
      canvas.drawCircle(s(pose.knee), size.width * 0.025, dotPaint);
    }

    // Leg: hip → knee → ankle
    final legPath = Path()
      ..moveTo(s(pose.hip).dx, s(pose.hip).dy)
      ..lineTo(s(pose.knee).dx, s(pose.knee).dy)
      ..lineTo(s(pose.ankle).dx, s(pose.ankle).dy);
    canvas.drawPath(legPath, thinPaint);

    // Body: hip → shoulder
    canvas.drawLine(s(pose.hip), s(pose.shoulder), bodyPaint);

    // Arm: shoulder → elbow → hand
    final armPath = Path()
      ..moveTo(s(pose.shoulder).dx, s(pose.shoulder).dy)
      ..lineTo(s(pose.elbow).dx, s(pose.elbow).dy)
      ..lineTo(s(pose.hand).dx, s(pose.hand).dy);
    canvas.drawPath(armPath, bodyPaint);

    // Hand contact dot
    canvas.drawCircle(s(pose.hand), size.width * 0.022, dotPaint);

    // Head: filled circle + outline
    final headPx = s(pose.head);
    final headRPx = pose.headR * size.height;
    canvas.drawCircle(headPx, headRPx, headFill);
    canvas.drawCircle(headPx, headRPx, bodyPaint..style = PaintingStyle.stroke);
    bodyPaint.style = PaintingStyle.stroke; // restore
  }

  @override
  bool shouldRepaint(_PushUpPainter old) =>
      old.progress != progress ||
      old.variation != variation ||
      old.color != color;
}
