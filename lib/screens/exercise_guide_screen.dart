/// Exercise Guide Screen
/// =====================
/// Static reference content for proper push-up form, supported variations,
/// and the recommended camera setup. Theme-aware and scrollable. Reachable
/// from the book icon next to the help button on the home screen.
library;

import 'package:flutter/material.dart';

class ExerciseGuideScreen extends StatelessWidget {
  const ExerciseGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Guide')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Push-Up Guide ─────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.fitness_center_rounded,
                title: 'Push-Up Guide',
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to do a proper push-up',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const _NumberedStep(
                      number: 1,
                      text:
                          'Place hands shoulder-width apart on the floor.',
                    ),
                    const _NumberedStep(
                      number: 2,
                      text:
                          'Extend legs back, body in a straight line from head to heels.',
                    ),
                    const _NumberedStep(
                      number: 3,
                      text:
                          'Lower your chest toward the floor by bending your elbows.',
                    ),
                    const _NumberedStep(
                      number: 4,
                      text:
                          'Push back up until arms are fully extended.',
                    ),
                    const _NumberedStep(
                      number: 5,
                      text:
                          'Keep your core tight and hips level throughout.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Variations ───────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.list_alt_rounded,
                title: 'Supported variations',
              ),
              const SizedBox(height: 12),
              const _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletItem(text: 'Standard push-ups'),
                    _BulletItem(text: 'Wide push-ups'),
                    _BulletItem(text: 'Diamond push-ups'),
                    _BulletItem(text: 'Pike push-ups'),
                    _BulletItem(text: 'Decline push-ups'),
                    SizedBox(height: 12),
                    _NoteBox(
                      text:
                          'Rep AI can track all push-up variations. Accuracy may vary between them. Standard push-ups give the most reliable tracking.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Setup tips ───────────────────────────────────────────
              const _SectionHeader(
                icon: Icons.camera_alt_rounded,
                title: 'Best setup for tracking',
              ),
              const SizedBox(height: 12),
              const _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletItem(text: 'Prop your phone at chest height.'),
                    _BulletItem(
                        text:
                            'Make sure your full body is visible in the camera.'),
                    _BulletItem(
                        text:
                            'Side view gives the best results but any angle works.'),
                    _BulletItem(
                        text:
                            'Keep about 1–2 metres distance from the phone.'),
                    _BulletItem(text: 'Good lighting helps detection.'),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable bits ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 22),
        const SizedBox(width: 10),
        Text(title, style: theme.textTheme.headlineMedium),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;

  const _NumberedStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 10),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String text;
  const _NoteBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Color(0xFF2563EB), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
