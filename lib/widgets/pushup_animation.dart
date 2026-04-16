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
// Ground line at y = 0.78.  All poses share the same coordinate space so
// the painter can lerp directly between them.

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
  elbow:    Offset(0.79, 0.71),
  shoulder: Offset(0.66, 0.67),
  hip:      Offset(0.37, 0.67),
  knee:     Offset(0.28, 0.73),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.57),
);

const _kTopDiamond = _Pose(
  hand:     Offset(0.66, _kG),
  elbow:    Offset(0.63, 0.60),
  shoulder: Offset(0.66, 0.47),
  hip:      Offset(0.37, 0.47),
  knee:     Offset(0.28, 0.67),
  ankle:    Offset(0.18, _kG),
  head:     Offset(0.73, 0.37),
);
const _kBotDiamond = _Pose(
  hand:     Offset(0.66, _kG),
  elbow:    Offset(0.52, 0.73),
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
  hip:      Offset(0.42, 0.53),
  knee:     Offset(0.27, _kG),
  ankle:    Offset(0.20, 0.69),
  head:     Offset(0.73, 0.40),
);
const _kBotKnee = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.61, 0.74),
  shoulder: Offset(0.66, 0.68),
  hip:      Offset(0.42, 0.71),
  knee:     Offset(0.27, _kG),
  ankle:    Offset(0.20, 0.69),
  head:     Offset(0.73, 0.58),
);

const _kTopPike = _Pose(
  hand:     Offset(0.42, _kG),
  elbow:    Offset(0.41, 0.58),
  shoulder: Offset(0.44, 0.47),
  hip:      Offset(0.50, 0.22),
  knee:     Offset(0.54, 0.49),
  ankle:    Offset(0.57, _kG),
  head:     Offset(0.38, 0.60),
);
const _kBotPike = _Pose(
  hand:     Offset(0.42, _kG),
  elbow:    Offset(0.35, 0.70),
  shoulder: Offset(0.44, 0.62),
  hip:      Offset(0.50, 0.34),
  knee:     Offset(0.54, 0.53),
  ankle:    Offset(0.57, _kG),
  head:     Offset(0.38, 0.74),
);

const _kTopDecline = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.74, 0.62),
  shoulder: Offset(0.67, 0.52),
  hip:      Offset(0.42, 0.39),
  knee:     Offset(0.30, 0.28),
  ankle:    Offset(0.20, 0.23),
  head:     Offset(0.74, 0.62),
);
const _kBotDecline = _Pose(
  hand:     Offset(0.76, _kG),
  elbow:    Offset(0.63, 0.73),
  shoulder: Offset(0.67, 0.70),
  hip:      Offset(0.42, 0.53),
  knee:     Offset(0.30, 0.28),
  ankle:    Offset(0.20, 0.23),
  head:     Offset(0.74, 0.76),
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
// Each variation ships 2 callout labels that annotate key form points directly
// on the canvas. anchor = the body-part position (normalised); label = where
// the pill is centred (normalised).

class _CalloutDef {
  final String text;
  final Offset anchor; // body-part to highlight
  final Offset label;  // pill centre
  const _CalloutDef({required this.text, required this.anchor, required this.label});
}

List<_CalloutDef> _calloutsFor(PushUpVariation v) {
  switch (v) {
    case PushUpVariation.standard:
      return [
        _CalloutDef(text: 'Flat back',      anchor: const Offset(0.51, 0.47), label: const Offset(0.24, 0.18)),
        _CalloutDef(text: 'Shoulder-width', anchor: const Offset(0.76, _kG),  label: const Offset(0.70, 0.90)),
      ];
    case PushUpVariation.wide:
      return [
        _CalloutDef(text: 'Arms wide',  anchor: const Offset(0.83, _kG),  label: const Offset(0.76, 0.90)),
        _CalloutDef(text: 'Hips level', anchor: const Offset(0.37, 0.47), label: const Offset(0.24, 0.18)),
      ];
    case PushUpVariation.diamond:
      return [
        _CalloutDef(text: 'Hands close', anchor: const Offset(0.66, _kG),  label: const Offset(0.57, 0.90)),
        _CalloutDef(text: 'Elbows back', anchor: const Offset(0.63, 0.55), label: const Offset(0.24, 0.28)),
      ];
    case PushUpVariation.knee:
      return [
        _CalloutDef(text: 'Knee pivot',    anchor: const Offset(0.27, _kG),  label: const Offset(0.24, 0.90)),
        _CalloutDef(text: 'Body straight', anchor: const Offset(0.54, 0.51), label: const Offset(0.24, 0.18)),
      ];
    case PushUpVariation.pike:
      return [
        _CalloutDef(text: 'Hips high', anchor: const Offset(0.50, 0.22), label: const Offset(0.63, 0.10)),
        _CalloutDef(text: 'Head down', anchor: const Offset(0.38, 0.60), label: const Offset(0.26, 0.52)),
      ];
    case PushUpVariation.decline:
      return [
        _CalloutDef(text: 'Feet up',    anchor: const Offset(0.20, 0.23), label: const Offset(0.27, 0.07)),
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

  /// Maps controller value (0→1 linear) to pose progress (0=top, 1=bottom).
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

  /// Callout labels fade to 60 % opacity while the figure is moving and
  /// return to full opacity when holding at the top (start) position.
  double _calloutOpacity(double t) {
    const pDownEnd    = _downMs  / _cycleMs;
    const pHoldBotEnd = (_downMs + _holdBot) / _cycleMs;
    const pUpEnd      = (_downMs + _holdBot + _upMs) / _cycleMs;

    if (t < pDownEnd) {
      // Fading out as figure descends
      return 1.0 - (t / pDownEnd) * 0.4;
    } else if (t < pHoldBotEnd) {
      return 0.6;
    } else if (t < pUpEnd) {
      // Fading back in as figure rises
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
  final double progress;        // 0 = top (extended), 1 = bottom (bent)
  final double calloutOpacity;  // 0.6–1.0 driven by animation phase
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

    // Head
    final headPx = s(pose.head);
    final headRPx = pose.headR * size.height;
    canvas.drawCircle(headPx, headRPx, headFill);
    canvas.drawCircle(headPx, headRPx, bodyPaint..style = PaintingStyle.stroke);
    bodyPaint.style = PaintingStyle.stroke;

    // ── Phone placement indicator ────────────────────────────────────────────
    // A small phone outline on the left edge at chest height, showing where
    // the user should position their camera.
    _drawPhoneIndicator(canvas, size);

    // ── Callout labels ───────────────────────────────────────────────────────
    for (final c in _calloutsFor(variation)) {
      _drawCallout(canvas, size, c.text, c.anchor, c.label);
    }
  }

  /// Draws a tiny phone silhouette on the left edge at chest height.
  void _drawPhoneIndicator(Canvas canvas, Size size) {
    final cx = size.width * 0.055;
    final cy = size.height * 0.50;
    final pw = (size.width * 0.036).clamp(8.0, 14.0);
    final ph = pw * 1.9;

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

    // "Cam" micro-label
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

  /// Draws a pill-shaped callout label with a short leader line to the
  /// highlighted body part.
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

    // Anchor dot
    canvas.drawCircle(
      anchorPx,
      (size.width * 0.014).clamp(2.5, 5.0),
      Paint()
        ..color = color.withValues(alpha: alpha * 0.55)
        ..style = PaintingStyle.fill,
    );

    // Leader line (very subtle — just a visual connector)
    canvas.drawLine(
      anchorPx,
      labelPx,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.22)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke,
    );

    // Pill background
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = color.withValues(alpha: alpha * 0.88)
        ..style = PaintingStyle.fill,
    );

    // Text
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
