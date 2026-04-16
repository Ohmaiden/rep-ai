/// Workout Hub Screen
/// ==================
/// Persistent tab screen reachable from the Workout bottom-nav item.
/// Shows Quick Workout and Custom Workout buttons. Camera permission is
/// requested here before handing off to the guide / setup flow.
library;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
                    'Choose how you want to train today',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),

                  // Quick Workout
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _launchWorkout(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 24),
                          SizedBox(width: 8),
                          Text('Quick Workout',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom Workout
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => _launchWorkout(context, setup: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tune_rounded, size: 22),
                          SizedBox(width: 8),
                          Text('Custom Workout',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
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
