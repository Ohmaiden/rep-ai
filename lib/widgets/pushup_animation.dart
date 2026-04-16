/// Push-Up Animation Widget
/// =========================
/// Animated side-view stick-figure demonstrating each push-up variation,
/// with per-variation form callout labels and a subtle camera placement
/// indicator showing where to position the phone.
///
/// Uses CustomPainter + AnimationController. Nothing is recorded or stored.
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
          'Keep hands shoulder-width apart',
          'Keep your body in a straight line from head to heels',
          'Push your shoulder blades apart as you press up',
          'Lower your chest to just above the floor',
        ];
      case PushUpVariation.wide:
        return [
          'Hands wider than shoulder-width',
          'Elbows flare to the sides as you lower',
          'Keep hips level at all times',
          'Focuses more on the outer chest',
        ];
      case PushUpVariation.diamond:
        return [
          'Hands under your chest, fingers forming a diamond',
          'Elbows stay close to your sides as you lower',
          'Push your shoulder blades apart at the top',
          'The hardest variation, great for building the triceps',
        ];
      case PushUpVariation.knee:
        return [
          'Knees on the floor, body straight from knees to shoulders',
          'Keep hips down, no sagging or rising',
          'Same chest and arm movement as a full push-up',
          'Good starting point before progressing to full push-ups',
        ];
      case PushUpVariation.pike:
        return [
          'Start in an upside-down V with hips raised high',
          'Lower your head toward the floor between your hands',
          'Push your shoulder blades apart at the top of each rep',
          'Works the shoulders more than any other variation',
        ];
      case PushUpVariation.decline:
        return [
          'Feet elevated on a bench or step',
          'Body in a straight line from shoulders to heels',
          'Lower your chest forward and down toward the floor',
          'Push your shoulder blades apart as you press up',
        ];
    }
  }
}

// ── Pose data (normalised 0–1 coords, origin = top-left) ─────────────────────
// Ground line at y = 0.78.  All poses share the same coordinate space so
// the painter can lerp directly between them.
//
// Body alignment rules:
//   - Non-pike top: shoulder, hip, knee, ankle must be collinear (plank line)
//   - Non-pike top: elbow must be collinear with shoulder and hand (straight arm)
//   - All bottom poses: elbow must form an ACUTE angle (upper arm and forearm
//     vectors have a positive dot product at the elbow joint)
//   - Pike: figure faces RIGHT (same as all others); hips at apex of inverted V

class _Pose {
  final Offset hand;
  final Offset elbow;
  final Offset shoulder;
  final Offset hip;
  final Offset knee;
  final Offset ankle;
  final Offset head;
  final double headR;

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

// ── Standard ──────────────────────────────────────────────────────────────────
const _kTopStandard = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.72, 0.64),
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.66),
  knee:     Offset(0.28, 0.72),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotStandard = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.61, 0.74),   // acute: elbow draws back behind shoulder
  shoulder: Offset(0.66, 0.67),
  hip:      Offset(0.37, 0.74),
  knee:     Offset(0.28, 0.76),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.57),
);

// ── Wide ──────────────────────────────────────────────────────────────────────
// Hand is at x=0.80 (vs standard 0.76) — clearly wider without making the arm
// look unrealistically long.  At the bottom the elbow draws BACK behind the
// shoulder (same direction as all other variations), so the joint moves toward
// the ground rather than forward.
const _kTopWide = _Pose(
  hand:     Offset(0.80, _kG),    // wider than standard (0.76) but not extreme
  elbow:    Offset(0.74, 0.64),   // collinear on shoulder(0.66,0.47)→hand(0.80,0.78) line
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.66),
  knee:     Offset(0.28, 0.72),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotWide = _Pose(
  hand:     Offset(0.80, _kG),
  elbow:    Offset(0.63, 0.73),   // acute: elbow draws back behind shoulder — same direction as standard, points toward ground
  shoulder: Offset(0.66, 0.70),   // drops slightly lower than standard (wider ROM)
  hip:      Offset(0.37, 0.75),   // on plank line shoulder(0.66,0.70)→ankle(0.18,0.78)
  knee:     Offset(0.28, 0.76),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.60),
);

// ── Diamond ───────────────────────────────────────────────────────────────────
const _kTopDiamond = _Pose(
  hand:     Offset(0.66, _kG),
  elbow:    Offset(0.66, 0.64),
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.66),
  knee:     Offset(0.28, 0.72),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotDiamond = _Pose(
  hand:     Offset(0.66, _kG),
  elbow:    Offset(0.52, 0.73),   // acute: elbow draws back
  shoulder: Offset(0.66, 0.67),
  hip:      Offset(0.37, 0.74),
  knee:     Offset(0.28, 0.76),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.57),
);

// ── Knee ──────────────────────────────────────────────────────────────────────
const _kTopKnee = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.72, 0.65),
  shoulder: Offset(0.66, 0.50),
  hip:      Offset(0.42, 0.67),
  knee:     Offset(0.27, _kG),
  ankle:    Offset(0.20, 0.69),
  head:     Offset(0.73, 0.40),
);
const _kBotKnee = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.61, 0.74),   // acute: elbow draws back
  shoulder: Offset(0.66, 0.68),
  hip:      Offset(0.42, 0.74),
  knee:     Offset(0.27, _kG),
  ankle:    Offset(0.20, 0.69),
  head:     Offset(0.73, 0.58),
);

// ── Pike ──────────────────────────────────────────────────────────────────────
// Faces RIGHT (same as all other variations). Hands right, feet left.
// Inverted-V with ~40° angle at hip. Head hangs near hands, moves forward
// and down toward floor as figure lowers.
const _kTopPike = _Pose(
  hand:     Offset(0.67, _kG),
  elbow:    Offset(0.63, 0.66),   // on line shoulder(0.57,0.52)→hand(0.67,0.78) — straight arm
  shoulder: Offset(0.57, 0.52),
  hip:      Offset(0.50, 0.35),   // apex of inverted V — elevated
  knee:     Offset(0.41, 0.61),   // on hip→ankle line
  ankle:    Offset(0.35, _kG),
  head:     Offset(0.64, 0.60),   // hanging near hands
);
const _kBotPike = _Pose(
  hand:     Offset(0.67, _kG),
  elbow:    Offset(0.57, 0.73),   // acute: elbow draws back and down like decline — points toward ground
  shoulder: Offset(0.62, 0.68),
  hip:      Offset(0.50, 0.47),   // hips lower as figure descends
  knee:     Offset(0.41, 0.66),
  ankle:    Offset(0.35, _kG),
  head:     Offset(0.71, 0.75),   // moves forward and down toward floor
);

// ── Decline ───────────────────────────────────────────────────────────────────
const _kTopDecline = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.72, 0.66),
  shoulder: Offset(0.67, 0.52),
  hip:      Offset(0.42, 0.37),
  knee:     Offset(0.30, 0.29),
  ankle:    Offset(0.20, 0.23),
  head:     Offset(0.77, 0.44),
);
const _kBotDecline = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.63, 0.73),   // acute: elbow draws back
  shoulder: Offset(0.67, 0.70),
  hip:      Offset(0.42, 0.45),
  knee:     Offset(0.30, 0.33),
  ankle:    Offset(0.20, 0.23),
  head:     Offset(0.79, 0.72),
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

// ── Callout annotations ───────────────────────────────────────────────────────

class _CalloutDef {
  final String text;
  final Offset anchor;
  final Offset label;
  const _CalloutDef({required this.text, required this.anchor, required this.label});
}

List<_CalloutDef> _calloutsFor(PushUpVariation v) {
  switch (v) {
    case PushUpVariation.standard:
      return [
        _CalloutDef(text: 'Flat back',      anchor: const Offset(0.51, 0.57), label: const Offset(0.24, 0.20)),
        _CalloutDef(text: 'Shoulder-width', anchor: const Offset(0.76, _kG),  label: const Offset(0.68, 0.90)),
      ];
    case PushUpVariation.wide:
      return [
        _CalloutDef(text: 'Arms wide',  anchor: const Offset(0.80, _kG),  label: const Offset(0.72, 0.90)),
        _CalloutDef(text: 'Hips level', anchor: const Offset(0.37, 0.66), label: const Offset(0.24, 0.20)),
      ];
    case PushUpVariation.diamond:
      return [
        _CalloutDef(text: 'Hands close', anchor: const Offset(0.66, _kG),  label: const Offset(0.57, 0.90)),
        _CalloutDef(text: 'Elbows back', anchor: const Offset(0.59, 0.65), label: const Offset(0.24, 0.28)),
      ];
    case PushUpVariation.knee:
      return [
        _CalloutDef(text: 'Knee pivot',    anchor: const Offset(0.27, _kG),  label: const Offset(0.24, 0.90)),
        _CalloutDef(text: 'Body straight', anchor: const Offset(0.54, 0.60), label: const Offset(0.24, 0.18)),
      ];
    case PushUpVariation.pike:
      // Figure now faces right: hip x=0.50 (symmetric), head x=0.64 (right side)
      return [
        _CalloutDef(text: 'Hips high', anchor: const Offset(0.50, 0.35), label: const Offset(0.38, 0.20)),
        _CalloutDef(text: 'Head down', anchor: const Offset(0.64, 0.60), label: const Offset(0.76, 0.48)),
      ];
    case PushUpVariation.decline:
      return [
        _CalloutDef(text: 'Feet up',     anchor: const Offset(0.20, 0.23), label: const Offset(0.27, 0.07)),
        _CalloutDef(text: 'Upper chest', anchor: const Offset(0.67, 0.52), label: const Offset(0.66, 0.13)),
      ];
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

  static const _downMs  = 1200;
  static const _holdBot =  600;
  static const _upMs    = 1000;
  static const _holdTop = 1200;
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

  double _progress(double t) {
    const pDownEnd    = _downMs  / _cycleMs;
    const pHoldBotEnd = (_downMs + _holdBot) / _cycleMs;
    const pUpEnd      = (_downMs + _holdBot + _upMs) / _cycleMs;

    if (t < pDownEnd) {
      return Curves.easeInOut.transform(t / pDownEnd);
    } else if (t < pHoldBotEnd) {
      return 1.0;
    } else if (t < pUpEnd) {
      return 1.0 - Curves.easeInOut.transform((t - pHoldBotEnd) / (_upMs / _cycleMs));
    } else {
      return 0.0;
    }
  }

  double _calloutOpacity(double t) {
    const pDownEnd    = _downMs  / _cycleMs;
    const pHoldBotEnd = (_downMs + _holdBot) / _cycleMs;
    const pUpEnd      = (_downMs + _holdBot + _upMs) / _cycleMs;

    if (t < pDownEnd) {
      return 1.0 - (t / pDownEnd) * 0.4;
    } else if (t < pHoldBotEnd) {
      return 0.6;
    } else if (t < pUpEnd) {
      return 0.6 + 0.4 * ((t - pHoldBotEnd) / (_upMs / _cycleMs));
    } else {
      return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF93C5FD)
        : const Color(0xFF2563EB);
    final groundColor = Theme.of(context).dividerColor;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _PushUpPainter(
            variation: widget.variation,
            progress: _progress(t),
            calloutOpacity: _calloutOpacity(t),
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
  final double progress;
  final double calloutOpacity;
  final Color color;
  final Color groundColor;

  const _PushUpPainter({
    required this.variation,
    required this.progress,
    required this.calloutOpacity,
    required this.color,
    required this.groundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = _posesFor(variation);
    final pose = data.top.lerp(data.bottom, progress);

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

    // ── Ground line ──────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(0, _kG * size.height),
      Offset(size.width, _kG * size.height),
      groundPaint,
    );

    // ── Decline platform ─────────────────────────────────────────────────────
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

    // ── Knee contact dot ─────────────────────────────────────────────────────
    if (data.kneeOnGround) {
      canvas.drawCircle(s(pose.knee), size.width * 0.025, dotPaint);
    }

    // ── Stick figure ─────────────────────────────────────────────────────────

    final legPath = Path()
      ..moveTo(s(pose.hip).dx, s(pose.hip).dy)
      ..lineTo(s(pose.knee).dx, s(pose.knee).dy)
      ..lineTo(s(pose.ankle).dx, s(pose.ankle).dy);
    canvas.drawPath(legPath, thinPaint);

    canvas.drawLine(s(pose.hip), s(pose.shoulder), bodyPaint);

    final armPath = Path()
      ..moveTo(s(pose.shoulder).dx, s(pose.shoulder).dy)
      ..lineTo(s(pose.elbow).dx, s(pose.elbow).dy)
      ..lineTo(s(pose.hand).dx, s(pose.hand).dy);
    canvas.drawPath(armPath, bodyPaint);

    canvas.drawCircle(s(pose.hand), size.width * 0.022, dotPaint);

    final headPx = s(pose.head);
    final headRPx = pose.headR * size.height;
    canvas.drawCircle(headPx, headRPx, headFill);
    canvas.drawCircle(headPx, headRPx, bodyPaint..style = PaintingStyle.stroke);
    bodyPaint.style = PaintingStyle.stroke;

    // ── Phone indicator (sits on the ground line) ────────────────────────────
    _drawPhoneIndicator(canvas, size);

    // ── Callout labels ───────────────────────────────────────────────────────
    for (final c in _calloutsFor(variation)) {
      _drawCallout(canvas, size, c.text, c.anchor, c.label);
    }
  }

  /// Normalised x-position of the phone indicator.
  /// Phone always sits on the ground line in front of the figure (right side).
  double _phoneX() {
    // Pike hands are at x=0.67 — give a bit more clearance on the right
    return variation == PushUpVariation.pike ? 0.86 : 0.91;
  }

  void _drawPhoneIndicator(Canvas canvas, Size size) {
    final pw = (size.width * 0.036).clamp(8.0, 14.0);
    final ph = pw * 1.9;
    final cx = _phoneX() * size.width;
    // Bottom of the phone rests on the ground line
    final cy = _kG * size.height - ph / 2;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: pw, height: ph),
      Radius.circular(pw * 0.22),
    );
    canvas.drawRRect(phoneRect, fillPaint);
    canvas.drawRRect(phoneRect, strokePaint);

    // Camera lens dot
    canvas.drawCircle(
      Offset(cx, cy - ph * 0.33),
      pw * 0.13,
      Paint()..color = color.withValues(alpha: 0.30)..style = PaintingStyle.fill,
    );

    // "Cam" micro-label — drawn just below the phone (at floor level)
    final fontSize = (size.height * 0.062).clamp(7.5, 10.0);
    final tp = TextPainter(
      text: TextSpan(
        text: 'Cam',
        style: TextStyle(
          color: color.withValues(alpha: 0.40),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy + ph / 2 + 2));
  }

  void _drawCallout(
    Canvas canvas,
    Size size,
    String text,
    Offset anchorNorm,
    Offset labelNorm,
  ) {
    final anchorPx = Offset(anchorNorm.dx * size.width, anchorNorm.dy * size.height);
    final labelPx  = Offset(labelNorm.dx  * size.width, labelNorm.dy  * size.height);

    final alpha = calloutOpacity;
    final fontSize = (size.height * 0.072).clamp(9.0, 12.5);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.42);

    const hPad = 7.0;
    const vPad = 4.5;
    final pillW = tp.width + hPad * 2;
    final pillH = tp.height + vPad * 2;

    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: labelPx, width: pillW, height: pillH),
      const Radius.circular(7),
    );

    canvas.drawCircle(
      anchorPx,
      (size.width * 0.014).clamp(2.5, 5.0),
      Paint()
        ..color = color.withValues(alpha: alpha * 0.55)
        ..style = PaintingStyle.fill,
    );

    canvas.drawLine(
      anchorPx,
      labelPx,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.22)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );

    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.88)
        ..style = PaintingStyle.fill,
    );

    tp.paint(
      canvas,
      Offset(labelPx.dx - tp.width / 2, labelPx.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PushUpPainter old) =>
      old.progress != progress ||
      old.calloutOpacity != calloutOpacity ||
      old.variation != variation ||
      old.color != color;
}
