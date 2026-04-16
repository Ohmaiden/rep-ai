/// Exercise Guide Screen
/// =====================
/// Animated reference guides for all push-up variations, plus camera
/// setup tips. Reachable from the book icon on the home screen.
library;

import 'package:flutter/material.dart';
import '../widgets/pushup_animation.dart';

class ExerciseGuideScreen extends StatefulWidget {
  const ExerciseGuideScreen({super.key});

  @override
  State<ExerciseGuideScreen> createState() => _ExerciseGuideScreenState();
}

class _ExerciseGuideScreenState extends State<ExerciseGuideScreen> {
  PushUpVariation _selected = PushUpVariation.standard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Guide')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // ── Variation section header ─────────────────────────────
              _SectionHeader(
                icon: Icons.fitness_center_rounded,
                title: 'Push-Up Variations',
              ),
              const SizedBox(height: 12),

              // Variation chip selector
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: PushUpVariation.values.map((v) {
                    final selected = v == _selected;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF2563EB)
                                : (isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF2563EB)
                                  : theme.dividerColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            v.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  selected ? Colors.white : subtextColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Animation card
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: PushUpAnimationWidget(
                  key: ValueKey(_selected),
                  variation: _selected,
                  height: 200,
                ),
              ),
              const SizedBox(height: 16),

              // Key points card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selected.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ..._selected.keyPoints.map(
                        (point) => _BulletItem(text: point),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Camera setup ─────────────────────────────────────────
              _SectionHeader(
                icon: Icons.camera_alt_rounded,
                title: 'Best setup for tracking',
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2563EB), size: 22),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem({required this.text});

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}
