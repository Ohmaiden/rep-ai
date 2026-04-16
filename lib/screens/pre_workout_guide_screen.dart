/// Pre-Workout Guide Screen
/// ========================
/// Shown before every workout session. Layout mirrors the Exercise Guide:
/// chips + PageView live outside any vertical ListView so horizontal swipes
/// are never consumed by an outer scroll. The whole screen is also wrapped
/// in a translucent GestureDetector so swiping anywhere changes the variation.
///
/// • Swipeable animated diagrams for all 6 variations
/// • Page-indicator dots
/// • Key form points in a scrollable card below
/// • "Let's Go" button fixed at the bottom
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/workout_state.dart';
import '../widgets/pushup_animation.dart';

class PreWorkoutGuideScreen extends StatefulWidget {
  /// True when launched from the custom-workout setup flow.
  final bool isCustom;

  const PreWorkoutGuideScreen({super.key, this.isCustom = false});

  @override
  State<PreWorkoutGuideScreen> createState() => _PreWorkoutGuideScreenState();
}

class _PreWorkoutGuideScreenState extends State<PreWorkoutGuideScreen> {
  static final _variations = PushUpVariation.values;

  int _selectedIndex = 0;
  PushUpVariation get _selected => _variations[_selectedIndex];

  late final PageController _pageController;
  final _chipScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _selectVariation(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.headlineLarge?.color ?? Colors.black;
    final subtextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Before You Start'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final v = details.primaryVelocity ?? 0;
            if (v < -300) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
              );
            } else if (v > 300) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOut,
              );
            }
          },
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── Header blurb ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good form = more reps counted.',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Swipe to browse variations, then tap Let\'s Go.',
                          style: TextStyle(fontSize: 14, color: subtextColor),
                        ),
                      ],
                    ),
                  ),

                  // ── Chip selector ──────────────────────────────────────
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      controller: _chipScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _variations.length,
                      itemBuilder: (context, i) {
                        final selected = i == _selectedIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _selectVariation(i),
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
                                _variations[i].displayName,
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
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Animation PageView ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 230,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _variations.length,
                          onPageChanged: (i) =>
                              setState(() => _selectedIndex = i),
                          itemBuilder: (ctx, i) => Container(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5FF),
                            padding:
                                const EdgeInsets.symmetric(vertical: 20),
                            child: PushUpAnimationWidget(
                              variation: _variations[i],
                              height: 190,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Page-indicator dots ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_variations.length, (i) {
                        final active = i == _selectedIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 20 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFF2563EB)
                                : theme.dividerColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),

                  // ── Key points (scrollable) ────────────────────────────
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                          child: Card(
                            key: ValueKey(_selected),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selected.displayName,
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 10),
                                  ..._selected.keyPoints.map(
                                    (point) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8),
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
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Let's Go button ────────────────────────────────────
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
      ),
    );
  }

  void _startWorkout() {
    if (!widget.isCustom) {
      context.read<WorkoutState>().startSession(exercise: 'Push-ups');
    }
    Navigator.pushReplacementNamed(context, '/workout');
  }
}
