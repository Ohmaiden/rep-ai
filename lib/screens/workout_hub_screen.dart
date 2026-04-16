/// Workout Hub Screen
/// ==================
/// Persistent tab screen reachable from the Workout bottom-nav item.
/// Shows a list of exercise categories. Tapping one opens a bottom sheet
/// with three options: Form Guide, Quick Workout, Custom Workout.
library;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'exercise_guide_screen.dart';

class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  Future<void> _launchWorkout(BuildContext context, {bool setup = false}) async {
    final status = await Permission.camera.request();
    if (!context.mounted) return;

    if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Camera Access Required'),
          content: const Text(
            'Rep AI needs camera access to count your reps.\n\n'
            'Go to: Settings → Privacy & Security → Camera → Rep AI, '
            'then toggle it on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return;
    }

    if (setup) {
      Navigator.pushNamed(context, '/setup');
    } else {
      Navigator.pushNamed(context, '/guide');
    }
  }

  void _showPushUpOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ExerciseOptionsSheet(
        title: 'Push Ups',
        onFormGuide: () {
          Navigator.pop(ctx);
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ExerciseGuideScreen(),
            ),
          );
        },
        onQuickWorkout: () {
          Navigator.pop(ctx);
          _launchWorkout(context);
        },
        onCustomWorkout: () {
          Navigator.pop(ctx);
          _launchWorkout(context, setup: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workout', style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Select an exercise to get started',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),

                  // Push Ups exercise card
                  _ExerciseCard(
                    title: 'Push Ups',
                    subtitle: '6 variations · Upper body',
                    icon: Icons.fitness_center_rounded,
                    onTap: () => _showPushUpOptions(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF2563EB),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Exercise options bottom sheet ─────────────────────────────────────────────

class _ExerciseOptionsSheet extends StatelessWidget {
  final String title;
  final VoidCallback onFormGuide;
  final VoidCallback onQuickWorkout;
  final VoidCallback onCustomWorkout;

  const _ExerciseOptionsSheet({
    required this.title,
    required this.onFormGuide,
    required this.onQuickWorkout,
    required this.onCustomWorkout,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'What would you like to do?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // Form Guide
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onFormGuide,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_outline_rounded, size: 22),
                  SizedBox(width: 8),
                  Text('Form Guide',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Workout
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onQuickWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 22),
                  SizedBox(width: 8),
                  Text('Quick Workout',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Custom Workout
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onCustomWorkout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 22),
                  SizedBox(width: 8),
                  Text('Custom Workout',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
