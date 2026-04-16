/// Workout Summary Screen
/// =======================
/// Full-screen post-workout summary with stats, per-set and per-rep breakdown.
/// Includes a confetti burst animation on load and a scrollable strip of
/// bad-form screenshots (one per bad rep) that can be tapped to view
/// full-screen and deleted from the device.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../models/workout_models.dart';

// ── Confetti particle data ────────────────────────────────────────────────────

class _ConfettiParticle {
  final double startX;
  final double startY;
  final double size;
  final bool isCircle;
  final Color color;
  final double drift;
  final double fallSpeed;

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

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final List<_ConfettiParticle> particles;

  const _ConfettiPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final x =
          (p.startX + p.drift * progress).clamp(0.0, 1.0) * size.width;
      final y = (p.startY + p.fallSpeed * progress) * size.height;
      final opacity =
          progress > 0.7 ? ((1.0 - progress) / 0.3).clamp(0.0, 1.0) : 1.0;
      paint.color = p.color.withValues(alpha: opacity);
      if (p.isCircle) {
        canvas.drawCircle(Offset(x, y), p.size / 2, paint);
      } else {
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
  final List<BadFormCapture> badFormCaptures;

  const WorkoutSummaryScreen({
    super.key,
    required this.session,
    this.repHistory = const [],
    this.setGoodReps,
    this.setBadReps,
    this.newRepRecord = false,
    this.newFormRecord = false,
    this.badFormCaptures = const [],
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final Animation<double> _confettiAnim;
  late final List<_ConfettiParticle> _particles;

  // Mutable local copy so the list updates live when the user deletes photos
  late List<BadFormCapture> _captures;

  static const List<Color> _confettiColors = [
    Color(0xFF2563EB),
    Colors.white,
    Color(0xFF22C55E),
    Color(0xFFFFBF00),
  ];

  @override
  void initState() {
    super.initState();
    _captures = List.from(widget.badFormCaptures);

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _confettiAnim = CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOut,
    );

    final rng = math.Random();
    final count = 40 + rng.nextInt(21);
    _particles = List.generate(count, (_) {
      final color = _confettiColors[rng.nextInt(_confettiColors.length)];
      return _ConfettiParticle(
        startX: rng.nextDouble(),
        startY: -0.05 - rng.nextDouble() * 0.15,
        size: 6 + rng.nextDouble() * 8,
        isCircle: rng.nextBool(),
        color: color,
        drift: (rng.nextDouble() - 0.5) * 0.4,
        fallSpeed: 0.8 + rng.nextDouble() * 0.5,
      );
    });

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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                                      borderRadius:
                                          BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('\u{1F3C6}',
                                            style:
                                                TextStyle(fontSize: 16)),
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

                              // Headline rep count
                              Center(
                                child: Text(
                                  '${session.goodFormReps}',
                                  style: const TextStyle(
                                    fontSize: 72,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF16A34A),
                                    height: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: Text(
                                  session.goodFormReps == 1
                                      ? 'Push-up counted'
                                      : 'Push-ups counted',
                                  style: TextStyle(
                                      fontSize: 14, color: subtextColor),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Stats row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _stat('${session.goodFormReps}',
                                      'Good Reps', const Color(0xFF16A34A)),
                                  _stat('${session.badFormReps}', 'Bad Form',
                                      const Color(0xFFDC2626)),
                                  _stat(_fmtDuration(session.duration),
                                      'Duration', const Color(0xFF7C3AED)),
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
                                      color: theme.dividerColor
                                          .withValues(alpha: 0.2)),
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
                                      borderRadius:
                                          BorderRadius.circular(10),
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
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: Color(
                                                        0xFF2563EB))),
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
                                                fontWeight:
                                                    FontWeight.w600)),
                                        if (bad > 0) ...[
                                          const SizedBox(width: 12),
                                          Text('$bad bad',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Color(0xFFDC2626),
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 16),
                              ],

                              // Form review card
                              ..._buildFormReviewSection(
                                repHistory,
                                textColor,
                                subtextColor,
                                surfaceColor,
                                theme,
                              ),

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
                                  final repLabel = isGood
                                      ? 'Good form'
                                      : (rep.issues.isNotEmpty &&
                                              rep.issues.first != 'Bad form'
                                          ? rep.issues.first
                                          : 'Form issues');
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                                alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text('${rep.repNumber}',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: color)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(repLabel,
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
                          padding:
                              const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => Navigator.popUntil(
                                  context, (r) => r.isFirst),
                              child: const Text('Back to Home',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Confetti overlay
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

  // ── Form review section ───────────────────────────────────────────────────

  List<Widget> _buildFormReviewSection(
    List<RepResult> repHistory,
    Color textColor,
    Color subtextColor,
    Color surfaceColor,
    ThemeData theme,
  ) {
    final hasBadReps = repHistory.any((r) => !r.goodForm);
    if (!hasBadReps) return [];

    // Aggregate specific issues across all bad reps
    final counts = <String, int>{};
    for (final rep in repHistory) {
      if (!rep.goodForm) {
        for (final issue in rep.issues) {
          if (issue != 'Bad form') counts[issue] = (counts[issue] ?? 0) + 1;
        }
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      Text('Form Review',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.18)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Screenshot strip ───────────────────────────────────────────
            if (_captures.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 15, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Text(
                      'Bad Form Captures (${_captures.length})',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  itemCount: _captures.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) =>
                      _buildThumbnail(ctx, _captures[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Tap a photo to view full screen and delete',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                ),
              ),
              Divider(
                  indent: 16,
                  endIndent: 16,
                  color: theme.dividerColor.withValues(alpha: 0.2)),
            ],

            // ── Issues list ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: sorted.isEmpty
                  ? Text(
                      'Focus on keeping a straight body line and full range of motion.',
                      style: TextStyle(fontSize: 14, color: subtextColor),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in sorted)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFDC2626), size: 15),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${entry.key} on '
                                    '${entry.value} rep${entry.value == 1 ? '' : 's'}',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: textColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            // ── Privacy note ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 13, color: subtextColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _captures.isNotEmpty
                          ? 'Photos saved on this device only. Nothing is uploaded.'
                          : 'Captured on this device only. Nothing is uploaded.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildThumbnail(BuildContext ctx, BadFormCapture capture) {
    return GestureDetector(
      onTap: () => _openCapture(ctx, capture),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 76,
          height: 112,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              Image.file(
                File(capture.filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: Colors.white38, size: 28),
                  ),
                ),
              ),
              // Rep number badge (top-left)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Rep ${capture.repNumber}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              // First issue label (bottom)
              if (capture.issues.isNotEmpty)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 4),
                    color: Colors.black.withValues(alpha: 0.65),
                    child: Text(
                      capture.issues.first,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              // Tap hint overlay (subtle magnifier icon, top-right)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.zoom_in_rounded,
                    color: Colors.white.withValues(alpha: 0.60), size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCapture(BuildContext ctx, BadFormCapture capture) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => _BadFormViewer(
          capture: capture,
          onDeleted: () {
            setState(() => _captures.remove(capture));
          },
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _stat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
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

// ── Full-screen bad-form viewer ───────────────────────────────────────────────

class _BadFormViewer extends StatefulWidget {
  final BadFormCapture capture;
  final VoidCallback onDeleted;

  const _BadFormViewer({required this.capture, required this.onDeleted});

  @override
  State<_BadFormViewer> createState() => _BadFormViewerState();
}

class _BadFormViewerState extends State<_BadFormViewer> {
  bool _deleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text(
            'This removes the photo from your device. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final file = File(widget.capture.filePath);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    widget.onDeleted();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Rep ${widget.capture.repNumber}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (!_deleting)
            TextButton.icon(
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFDC2626), size: 20),
              label: const Text('Delete',
                  style: TextStyle(
                      color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-res image with pinch-to-zoom
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: Image.file(
                File(widget.capture.filePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Image not available',
                      style: TextStyle(color: Colors.white54, fontSize: 16)),
                ),
              ),
            ),
          ),

          // Form issues overlay (bottom)
          if (widget.capture.issues.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFDC2626), size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Form Issues Detected',
                            style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 13,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final issue in widget.capture.issues)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '• $issue',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Deleting spinner
          if (_deleting)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
