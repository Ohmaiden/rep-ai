/// Pre-Workout Guide Screen
/// ========================
/// Shown before every workout session so the user can see exactly how to
/// perform each push-up variation before the camera starts.
///
/// • Animated side-view diagram for the selected variation
/// • Swipeable variation chips to browse all 6 guides
/// • Key form points listed below the animation
/// • "Let's Go" button starts the actual workout
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/workout_state.dart';
import '../widgets/pushup_animation.dart';

class PreWorkoutGuideScreen extends StatefulWidget {
  /// True when launched from the custom-workout setup flow.
  /// The "Let's Go" button will start a custom session instead of a free one.
  final bool isCustom;

  const PreWorkoutGuideScreen({super.key, this.isCustom = false});

  @override
  State<PreWorkoutGuideScreen> createState() => _PreWorkoutGuideScreenState();
}

class _PreWorkoutGuideScreenState extends State<PreWorkoutGuideScreen> {
  PushUpVariation _selected = PushUpVariation.standard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.headlineLarge?.color ?? Colors.black;
    final subtextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = theme.cardTheme.color ?? theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Before You Start'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    children: [
                      // Header blurb
                      Text(
                        'Good form = more reps counted.',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Watch the guide below, then start when ready.',
                        style: TextStyle(fontSize: 14, color: subtextColor),
                      ),
                      const SizedBox(height: 20),

                      // Animation card
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            PushUpAnimationWidget(
                              key: ValueKey(_selected),
                              variation: _selected,
                              height: 190,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selected.displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Variation chips
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: PushUpVariation.values.map((v) {
                            final selected = v == _selected;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selected = v),
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
                                          : theme.dividerColor
                                              .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    v.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : subtextColor,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Key points
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Key points',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2563EB),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ..._selected.keyPoints.map(
                              (point) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          top: 5, right: 10),
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
                                        point,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: textColor,
                                            height: 1.4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Let's Go button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _startWorkout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Let's Go",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startWorkout() {
    if (!widget.isCustom) {
      context.read<WorkoutState>().startSession(exercise: 'Push-ups');
    }
    // Custom session was already started by WorkoutSetupScreen before
    // navigating here — just push the workout screen.
    Navigator.pushReplacementNamed(context, '/workout');
  }
}
