/// Exercise Guide Screen
/// =====================
/// Animated reference guides for all push-up variations, plus camera
/// setup tips. Reachable from the dumbbell icon on the home screen.
///
/// Layout: chips + PageView live in a fixed Column at the top so horizontal
/// swipes on the animation are never consumed by an outer vertical ListView.
/// Key-points card and camera tips scroll in an Expanded ListView below.
library;

import 'package:flutter/material.dart';
import '../widgets/pushup_animation.dart';

class ExerciseGuideScreen extends StatefulWidget {
  const ExerciseGuideScreen({super.key});

  @override
  State<ExerciseGuideScreen> createState() => _ExerciseGuideScreenState();
}

class _ExerciseGuideScreenState extends State<ExerciseGuideScreen> {
  static final _variations = PushUpVariation.values;

  int _selectedIndex = 0;
  PushUpVariation get _selected => _variations[_selectedIndex];

  late final PageController _pageController;
  final _chipScrollController = ScrollController();
  late final List<GlobalKey> _chipKeys;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _chipKeys = List.generate(_variations.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  void _scrollChipIntoView(int index) {
    final ctx = _chipKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: 0.5,
    );
  }

  void _selectVariation(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    _scrollChipIntoView(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Guide')),
      body: GestureDetector(
        // Translucent: inner widgets (PageView, chip ListView) still handle
        // their own gestures; areas with no horizontal recogniser (key-points
        // card, camera section, dots) also navigate on a horizontal swipe.
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
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Variation header ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: _SectionHeader(
                  icon: Icons.fitness_center_rounded,
                  title: 'Push-Up Variations',
                ),
              ),

              // ── Chip selector ──────────────────────────────────────────────
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
                          key: _chipKeys[i],
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
                            _variations[i].displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : subtextColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ── Animation PageView ─────────────────────────────────────────
              // Kept outside any vertical scrollable so horizontal swipes are
              // never ambiguous and always handled by the PageView.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 248,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _variations.length,
                      onPageChanged: (i) {
                        setState(() => _selectedIndex = i);
                        _scrollChipIntoView(i);
                      },
                      itemBuilder: (ctx, i) => Container(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5FF),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: PushUpAnimationWidget(
                          variation: _variations[i],
                          height: 200,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Page-indicator dots ────────────────────────────────────────
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

              // ── Scrollable lower section ───────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [

                    // Key points card
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
                              const SizedBox(height: 12),
                              ..._selected.keyPoints.map(
                                (point) => _BulletItem(text: point),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Camera setup
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
                                    'Keep about 1 to 2 metres distance from the phone.'),
                            _BulletItem(text: 'Good lighting helps detection.'),
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
