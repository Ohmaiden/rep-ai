/// Workout Summary Screen
/// =======================
/// Full-screen post-workout summary with stats, per-set and per-rep breakdown.
/// Includes a confetti burst animation on load.
library;

import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/workout_models.dart';

// ── Confetti particle data ────────────────────────────────────────────────────

class _ConfettiParticle {
  final double startX;   // 0–1 fraction of screen width
  final double startY;   // 0–1 fraction of screen height (starts near 0)
  final double size;
  final bool isCircle;
  final Color color;
  final double drift;      // horizontal drift multiplier (can be negative)
  final double fallSpeed;  // how far down it falls over the full animation

  const _ConfettiParticle({
    required this.startX,
    required this.startY,
    required this.size,
    required this.isCircle,
    required this.color,
    required this.drift,
    required this.fallSpeed,
  });
}

// ── Confetti painter ──────────────────────────────────────────────────────────

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  const _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final x = (p.startX + p.drift * progress).clamp(0.0, 1.0) * size.width;
      final y = (p.startY + p.fallSpeed * progress) * size.height;

      // Fade out in the last 30% of the animation
      final opacity =
          progress > 0.7 ? ((1.0 - progress) / 0.3).clamp(0.0, 1.0) : 1.0;
      paint.color = p.color.withValues(alpha: opacity);

      if (p.isCircle) {
        canvas.drawCircle(Offset(x, y), p.size / 2, paint);
      } else {
        // Rotated rectangle for a more dynamic look
        final angle = p.drift * progress * math.pi * 6;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WorkoutSummaryScreen extends StatefulWidget {
  final WorkoutSession session;
  final List<RepResult> repHistory;
  final List<int>? setGoodReps;
  final List<int>? setBadReps;
  final bool newRepRecord;
  final bool newFormRecord;

  const WorkoutSummaryScreen({
    super.key,
    required this.session,
    this.repHistory = const [],
    this.setGoodReps,
    this.setBadReps,
    this.newRepRecord = false,
    this.newFormRecord = false,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final Animation<double> _confettiAnim;
  late final List<_ConfettiParticle> _particles;

  static const List<Color> _confettiColors = [
    Color(0xFF2563EB), // accent blue
    Colors.white,
    Color(0xFF22C55E), // bright green
    Color(0xFFFFBF00), // gold
  ];

  @override
  void initState() {
    super.initState();

    // Build controller — 2 seconds, plays once
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _confettiAnim = CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    );

    // Generate particles
    final rng = math.Random();
    final count = 40 + rng.nextInt(21); // 40–60
    _particles = List.generate(count, (_) {
      final color = _confettiColors[rng.nextInt(_confettiColors.length)];
      return _ConfettiParticle(
        startX: rng.nextDouble(),
        startY: -0.05 - rng.nextDouble() * 0.15, // burst from just above top
        size: 6 + rng.nextDouble() * 8,
        isCircle: rng.nextBool(),
        color: color,
        drift: (rng.nextDouble() - 0.5) * 0.4, // ±0.2 drift
        fallSpeed: 0.8 + rng.nextDouble() * 0.5, // fall 80–130% of screen height
      );
    });

    // Play audio then start confetti
    final player = AudioPlayer();
    player.play(AssetSource('sounds/set_complete.mp3'));
    player.onPlayerComplete.listen((_) => player.dispose());

    _confettiController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // Forward widget fields for convenience
  WorkoutSession get session => widget.session;
  List<RepResult> get repHistory => widget.repHistory;
  List<int>? get setGoodReps => widget.setGoodReps;
  List<int>? get setBadReps => widget.setBadReps;
  bool get newRepRecord => widget.newRepRecord;
  bool get newFormRecord => widget.newFormRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.headlineLarge?.color ?? Colors.black;
    final subtextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        children: [
                          // Title
                          Center(
                            child: Text('Workout Complete!',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: textColor)),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text(session.exercise,
                                style: TextStyle(
                                    fontSize: 16, color: subtextColor)),
                          ),

                          // New record badge
                          if (newRepRecord || newFormRecord) ...[
                            const SizedBox(height: 16),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFEAB308),
                                      Color(0xFFF59E0B)
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('\u{1F3C6}',
                                        style: TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      newRepRecord && newFormRecord
                                          ? 'New Records!'
                                          : newRepRecord
                                              ? 'New Rep Record!'
                                              : 'New Form Record!',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),

                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _stat('${session.goodFormReps}', 'Good Reps',
                                  const Color(0xFF16A34A)),
                              _stat('${session.badFormReps}', 'Bad Form',
                                  const Color(0xFFDC2626)),
                              _stat(_fmtDuration(session.duration), 'Duration',
                                  const Color(0xFF7C3AED)),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Attempts bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      theme.dividerColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.fitness_center,
                                    color: subtextColor, size: 13),
                                const SizedBox(width: 8),
                                Text(
                                  '${session.totalReps} total attempts  \u00b7  '
                                  '${session.goodFormReps} counted',
                                  style: TextStyle(
                                      fontSize: 14, color: subtextColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Per-set breakdown
                          if (setGoodReps != null &&
                              setGoodReps!.isNotEmpty) ...[
                            Text('Set Breakdown',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor)),
                            const SizedBox(height: 12),
                            ...List.generate(setGoodReps!.length, (i) {
                              final good = setGoodReps![i];
                              final bad = (setBadReps != null &&
                                      i < setBadReps!.length)
                                  ? setBadReps![i]
                                  : 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: theme.dividerColor
                                          .withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB)
                                            .withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF2563EB))),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('Set ${i + 1}',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: textColor)),
                                    ),
                                    Text('$good good',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF16A34A),
                                            fontWeight: FontWeight.w600)),
                                    if (bad > 0) ...[
                                      const SizedBox(width: 12),
                                      Text('$bad bad',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Per-rep breakdown
                          if (repHistory.isNotEmpty) ...[
                            Text('Rep Breakdown',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor)),
                            const SizedBox(height: 12),
                            ...repHistory.map((rep) {
                              final isGood = rep.goodForm;
                              final color = isGood
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626);
                              final bg = isGood
                                  ? const Color(0xFF16A34A)
                                      .withValues(alpha: 0.08)
                                  : const Color(0xFFDC2626)
                                      .withValues(alpha: 0.08);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${rep.repNumber}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: color)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                          isGood ? 'Good form' : 'Form issues',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: color)),
                                    ),
                                    Icon(
                                        isGood
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: color,
                                        size: 20),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),

                    // Done button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () =>
                              Navigator.popUntil(context, (r) => r.isFirst),
                          child: const Text('Done',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Confetti overlay (pointer-transparent, renders on top) ──────
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _confettiAnim,
                  builder: (context, _) => CustomPaint(
                    painter: _ConfettiPainter(
                      progress: _confettiAnim.value,
                      particles: _particles,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  String _fmtDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
}
