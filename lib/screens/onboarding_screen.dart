/// Onboarding Screen
/// ==================
/// 5-screen personalised intro shown on first launch.
/// Landscape-optimised: each page uses a horizontal split layout so nothing
/// needs scrolling on a standard phone held sideways (~360 px tall viewport).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const int _totalPages = 6;

  // Fitness level state
  String? _selectedFitnessLevel; // "beginner" | "intermediate" | "advanced"

  // Goal setter state — weekly reps
  int _weeklyReps = 50;
  static const int _repMin = 10;
  static const int _repMax = 99999;
  static const int _repStep = 10;

  // Goal setter state — days per week
  int _goalDays = 5;
  static const int _daysMin = 1;
  static const int _daysMax = 7;

  /// Reps per day (ceiling division)
  int get _repsPerDay => (_weeklyReps + _goalDays - 1) ~/ _goalDays;

  // ── Finish ────────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    final fitnessLevel = _selectedFitnessLevel ?? 'beginner';

    await prefs.setString('fitness_level', fitnessLevel);
    await prefs.setInt('onboarding_goal_reps', _weeklyReps);
    await prefs.setInt('onboarding_goal_days', _goalDays);
    await prefs.setBool('onboarding_done', true);

    // Save goal to database with daily breakdown
    if (mounted) {
      final db = context.read<DatabaseService>();
      await db.saveGoal(_weeklyReps, 'week', breakdown: 'daily:$_repsPerDay');
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 250),
        ),
        (_) => false,
      );
    }
  }

  /// Skip — saves defaults and navigates immediately.
  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fitness_level', 'beginner');
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 250),
        ),
        (_) => false,
      );
    }
  }

  void _nextPage() {
    // If leaving the fitness level page with nothing selected, default to beginner
    if (_page == 1 && _selectedFitnessLevel == null) {
      setState(() {
        _selectedFitnessLevel = 'beginner';
        _weeklyReps = 50;
      });
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Show a dialog to type a custom number, clamped to [min]..[max].
  /// Uses a bottom sheet so it clears the keyboard in all orientations.
  Future<void> _showNumberDialog({
    required String title,
    required int current,
    required int min,
    required int max,
    required ValueChanged<int> onConfirm,
  }) async {
    final ctrl = TextEditingController(text: '$current');
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '$min – $max',
                      hintStyle: const TextStyle(color: Colors.white38),
                      enabledBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: Colors.white24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                            color: Color(0xFF2563EB), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white54,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final v = int.tryParse(ctrl.text) ?? current;
                            Navigator.pop(ctx, v.clamp(min, max));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('OK',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result != null) onConfirm(result);
  }

  // ── Page wrapper — scrollable + vertically centred (portrait fallback) ──

  Widget _scrollPage({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — compact in landscape
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const PageScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildWelcomePage(),
                  _buildFitnessLevelPage(),
                  _buildPhonePlacementPage(),
                  _buildPermissionPrimerPage(),
                  _buildFollowTheDingPage(),
                  _buildGoalSetterPage(),
                ],
              ),
            ),

            // Dot indicators — smaller in landscape
            Padding(
              padding: EdgeInsets.only(bottom: isLandscape ? 6.0 : 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 24 : 8,
                    height: isLandscape ? 6.0 : 8.0,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? const Color(0xFF2563EB)
                          : Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom button — hidden on goal setter page (has its own Start button).
            if (_page != 5)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, isLandscape ? 8.0 : 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: isLandscape ? 44.0 : 56.0,
                  child: ElevatedButton(
                    onPressed:
                        _page < _totalPages - 1 ? _nextPage : _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      minimumSize: const Size(double.infinity, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _page < _totalPages - 1 ? 'Next' : 'Get Started',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  // ── Page 1: Welcome ───────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _welcomeLandscape();
        }
        return _welcomePortrait();
      },
    );
  }

  Widget _welcomePortrait() {
    return _scrollPage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _welcomeIcon(size: 100, iconSize: 38),
            const SizedBox(height: 40),
            _welcomeTitle(),
            const SizedBox(height: 16),
            _welcomeSubtitle(),
            const SizedBox(height: 24),
            _welcomeThemeHint(),
          ],
        ),
      ),
    );
  }

  Widget _welcomeLandscape() {
    return LayoutBuilder(builder: (context, constraints) {
      final iconSz = (constraints.maxHeight * 0.25).clamp(0.0, 64.0);
      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left ~40%: icon
                      Expanded(
                        flex: 4,
                        child: Center(
                            child: _welcomeIcon(
                                size: iconSz, iconSize: iconSz * 0.4)),
                      ),
                      const SizedBox(width: 16),
                      // Right ~60%: text
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _welcomeTitle(textAlign: TextAlign.left),
                            const SizedBox(height: 6),
                            _welcomeSubtitle(textAlign: TextAlign.left),
                            const SizedBox(height: 6),
                            _welcomeThemeHint(textAlign: TextAlign.left),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _welcomeIcon({required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.fitness_center,
          size: iconSize, color: const Color(0xFF2563EB)),
    );
  }

  Widget _welcomeTitle({TextAlign textAlign = TextAlign.center}) {
    return Text(
      'Welcome to Rep AI',
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  Widget _welcomeSubtitle({TextAlign textAlign = TextAlign.center}) {
    return Text(
      'AI-powered rep counting that only counts perfect form.\nEvery rep matters.',
      textAlign: textAlign,
      style: const TextStyle(fontSize: 16, color: Colors.white60, height: 1.5),
    );
  }

  Widget _welcomeThemeHint({TextAlign textAlign = TextAlign.center}) {
    return Text(
      'Theme matches your system. Tap ⚙ Settings on the home screen to change it anytime.',
      textAlign: textAlign,
      style: const TextStyle(fontSize: 12, color: Colors.white38),
    );
  }

  // ── Page 2: Fitness Level ─────────────────────────────────────────────────

  Widget _buildFitnessLevelPage() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _fitnessLandscape();
        }
        return _fitnessPortrait();
      },
    );
  }

  Widget _fitnessPortrait() {
    return _scrollPage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _fitnessTitleBlock(),
            const SizedBox(height: 40),
            ..._fitnessCards(compact: false),
          ],
        ),
      ),
    );
  }

  Widget _fitnessLandscape() {
    return LayoutBuilder(builder: (context, constraints) {
      final iconSz = (constraints.maxHeight * 0.25).clamp(0.0, 64.0);
      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left ~40%: icon + title
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: iconSz,
                              height: iconSz,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.emoji_events_rounded,
                                  size: iconSz * 0.45,
                                  color: const Color(0xFF2563EB)),
                            ),
                            const SizedBox(height: 6),
                            _fitnessTitleBlock(compact: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right ~60%: 3 cards
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: _fitnessCards(compact: true),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _fitnessTitleBlock({bool compact = false}) {
    return Column(
      children: [
        Text(
          'Where are you right now?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 18 : 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: compact ? 4 : 8),
        Text(
          'We\'ll tailor your experience.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compact ? 13 : 15,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  List<Widget> _fitnessCards({required bool compact}) {
    final items = [
      (
        emoji: '🟢',
        level: 'beginner',
        title: 'Beginner',
        subtitle: 'New to training'
      ),
      (
        emoji: '🟡',
        level: 'intermediate',
        title: 'Intermediate',
        subtitle: 'Train occasionally'
      ),
      (
        emoji: '🔴',
        level: 'advanced',
        title: 'Advanced',
        subtitle: 'Train regularly'
      ),
    ];
    final widgets = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (i > 0) widgets.add(SizedBox(height: compact ? 6 : 12));
      widgets.add(_fitnessCard(
        emoji: item.emoji,
        level: item.level,
        title: item.title,
        subtitle: item.subtitle,
        compact: compact,
      ));
    }
    return widgets;
  }

  Widget _fitnessCard({
    required String emoji,
    required String level,
    required String title,
    required String subtitle,
    bool compact = false,
  }) {
    final selected = _selectedFitnessLevel == level;
    return GestureDetector(
      onTap: () async {
        final preset = level == 'advanced'
            ? 300
            : level == 'intermediate'
                ? 150
                : 50;
        setState(() {
          _selectedFitnessLevel = level;
          _weeklyReps = preset;
        });
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _nextPage();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 20,
          vertical: compact ? 6 : 16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: TextStyle(fontSize: compact ? 20 : 24)),
            SizedBox(width: compact ? 10 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 13 : 17,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  ),
                  SizedBox(height: compact ? 1 : 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: compact ? 11 : 14,
                      color: selected ? Colors.white60 : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded,
                  color: const Color(0xFF2563EB), size: compact ? 18 : 22),
          ],
        ),
      ),
    );
  }

  // ── Page 3: Phone Placement ───────────────────────────────────────────────

  Widget _buildPhonePlacementPage() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _phonePlacementLandscape();
        }
        return _phonePlacementPortrait();
      },
    );
  }

  Widget _phonePlacementPortrait() {
    return LayoutBuilder(
      builder: (context, outerConstraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: outerConstraints.maxHeight),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Set up your camera',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, c) {
                    final maxW = c.maxWidth.clamp(0.0, 300.0);
                    return SizedBox(
                      width: maxW,
                      height: 140,
                      child: _portraitIllustration(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Side view — ~2m away',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB).withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Prop your phone up so the camera can see your full body. About 2 metres away works best.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16, color: Colors.white60, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phonePlacementLandscape() {
    return LayoutBuilder(builder: (context, constraints) {
      final illustrationSz = (constraints.maxHeight * 0.7)
          .clamp(0.0, constraints.maxWidth * 0.35)
          .clamp(0.0, 120.0);
      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left ~40%: illustration (clipped, size-constrained)
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: ClipRect(
                            child: SizedBox(
                              width: illustrationSz,
                              height: illustrationSz,
                              child: _landscapeIllustration(
                                  containerSize: illustrationSz),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right ~60%: title + label + description
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Set up your camera',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'From below — ~2m away',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Prop your phone up so the camera can see your full body. About 2 metres away works best.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white60,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Portrait illustration: Phone LEFT → arrow → Person CENTRE-RIGHT
  Widget _portraitIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _phoneWidget(),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (_) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 18, color: Color(0xFF2563EB)),
              ),
            ),
          ),
        ),
        _personWidget(),
      ],
    );
  }

  /// Landscape illustration: Person TOP → arrow ↑ → Phone BOTTOM
  /// [containerSize] drives proportional sizing so nothing overflows.
  Widget _landscapeIllustration({double containerSize = 100}) {
    final arrowSz = (containerSize * 0.14).clamp(8.0, 16.0);
    final arrowCount = containerSize >= 80 ? 3 : 2;
    return ClipRect(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _personWidget(containerSize: containerSize),
          Column(
            children: List.generate(
              arrowCount,
              (_) => Icon(Icons.arrow_upward_rounded,
                  size: arrowSz, color: const Color(0xFF2563EB)),
            ),
          ),
          _phoneWidget(containerSize: containerSize),
        ],
      ),
    );
  }

  Widget _phoneWidget({double containerSize = 100}) {
    final w = (containerSize * 0.3).clamp(20.0, 36.0);
    final h = (containerSize * 0.46).clamp(32.0, 56.0);
    final iconSz = (containerSize * 0.18).clamp(12.0, 22.0);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
        border: Border.all(color: const Color(0xFF2563EB), width: 2),
      ),
      child: Icon(Icons.phone_android, size: iconSz, color: const Color(0xFF2563EB)),
    );
  }

  Widget _personWidget({double containerSize = 100}) {
    final headSz = (containerSize * 0.23).clamp(16.0, 28.0);
    final bodySz = (containerSize * 0.43).clamp(24.0, 52.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: headSz,
          height: headSz,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
            border: Border.all(color: Colors.white38, width: 2),
          ),
        ),
        const SizedBox(height: 2),
        Icon(Icons.accessibility_new, size: bodySz, color: Colors.white54),
      ],
    );
  }

  // ── Page 4: Permission Primer ─────────────────────────────────────────────

  Widget _buildPermissionPrimerPage() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _permissionLandscape();
        }
        return _permissionPortrait();
      },
    );
  }

  Widget _permissionPortrait() {
    return _scrollPage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _permissionIcon(size: 100, iconSize: 48),
            const SizedBox(height: 40),
            _permissionTitle(),
            const SizedBox(height: 16),
            _permissionSubtitle(),
            const SizedBox(height: 32),
            _privacyBadgesWrap(),
          ],
        ),
      ),
    );
  }

  Widget _permissionLandscape() {
    return LayoutBuilder(builder: (context, constraints) {
      final iconSz = (constraints.maxHeight * 0.25).clamp(0.0, 64.0);
      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left ~40%: icon
                      Expanded(
                        flex: 4,
                        child: Center(
                            child: _permissionIcon(
                                size: iconSz, iconSize: iconSz * 0.49)),
                      ),
                      const SizedBox(width: 16),
                      // Right ~60%: title + subtitle + badges
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _permissionTitle(textAlign: TextAlign.left),
                            const SizedBox(height: 6),
                            _permissionSubtitle(textAlign: TextAlign.left),
                            const SizedBox(height: 8),
                            _privacyBadgesRow(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _permissionIcon({required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.videocam_rounded,
          size: iconSize, color: const Color(0xFF2563EB)),
    );
  }

  Widget _permissionTitle({TextAlign textAlign = TextAlign.center}) {
    return Text(
      'Rep AI needs your camera',
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    );
  }

  Widget _permissionSubtitle({TextAlign textAlign = TextAlign.center}) {
    return Text(
      'We use it to track your movement in real time — nothing is recorded or stored. We\'ll ask for permission next.',
      textAlign: textAlign,
      style: const TextStyle(fontSize: 16, color: Colors.white60, height: 1.5),
    );
  }

  /// Portrait: Wrap (centred)
  Widget _privacyBadgesWrap() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        _privacyBadge(Icons.lock_outline_rounded, 'Private'),
        _privacyBadge(Icons.no_photography_outlined, 'Not stored'),
        _privacyBadge(Icons.phone_android, 'On-device'),
      ],
    );
  }

  /// Landscape: Row (left-aligned)
  Widget _privacyBadgesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _privacyBadge(Icons.lock_outline_rounded, 'Private'),
        const SizedBox(width: 16),
        _privacyBadge(Icons.no_photography_outlined, 'Not stored'),
        const SizedBox(width: 16),
        _privacyBadge(Icons.phone_android, 'On-device'),
      ],
    );
  }

  Widget _privacyBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white54),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  // ── Page 5: Follow the Ding ───────────────────────────────────────────────

  Widget _buildFollowTheDingPage() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _followTheDingLandscape();
        }
        return _followTheDingPortrait();
      },
    );
  }

  Widget _followTheDingPortrait() {
    return _scrollPage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded,
                  size: 48, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 40),
            const Text(
              'Follow the ding',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Only move to the next rep when you hear the sound and see the number change.\n\nGo at a steady, controlled pace — the AI needs to clearly see each rep to count it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white60, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _followTheDingLandscape() {
    return LayoutBuilder(builder: (context, constraints) {
      final iconSz = (constraints.maxHeight * 0.25).clamp(0.0, 64.0);
      return SizedBox(
        height: constraints.maxHeight,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left ~40%: icon
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: Container(
                            width: iconSz,
                            height: iconSz,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.volume_up_rounded,
                                size: iconSz * 0.49,
                                color: const Color(0xFF2563EB)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Right ~60%: title + subtitle
                      const Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Follow the ding',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Only move to the next rep when you hear the sound and see the number change.\n\nGo at a steady, controlled pace — the AI needs to clearly see each rep to count it.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white60,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Page 6: Goal Setter ───────────────────────────────────────────────────

  Widget _buildGoalSetterPage() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _goalSetterLandscape();
        }
        return _goalSetterPortrait();
      },
    );
  }

  Widget _goalSetterPortrait() {
    return _scrollPage(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Set your first goal',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'How many reps this week?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white54),
            ),
            const SizedBox(height: 40),

            // ── Weekly reps picker ────────────────────────────────────────
            _weeklyRepsPicker(large: true),
            const SizedBox(height: 6),
            Text(
              'reps / week',
              style: TextStyle(
                  fontSize: 15, color: Colors.white.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap the number to type a custom value',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),

            const SizedBox(height: 32),

            // ── Days per week picker ──────────────────────────────────────
            const Text(
              'How many days per week?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.white70),
            ),
            const SizedBox(height: 16),
            _daysPerWeekPicker(large: true),
            const SizedBox(height: 6),
            const Text(
              'Tap the number to type a custom value',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
            const SizedBox(height: 12),

            // Live calculation label
            _repsPerDayLabel(),

            const SizedBox(height: 40),

            // Start training button
            _startButton(),
          ],
        ),
      ),
    );
  }

  /// Landscape: compact layout — title + side-by-side pickers + reps/day + button.
  /// No scrolling needed. Card is ~10% larger via reduced external padding.
  Widget _goalSetterLandscape() {
    return LayoutBuilder(builder: (context, constraints) {
      final h = constraints.maxHeight;
      return SizedBox(
        height: h,
        child: Column(
          children: [
            // Title block — ultra compact
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Set your first goal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '·',
                    style: TextStyle(color: Colors.white24, fontSize: 18),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'How many reps this week?',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 2),

            // Side-by-side pickers — Expanded to fill available space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: weekly reps
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Reps / week',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white70),
                          ),
                          const SizedBox(height: 3),
                          _weeklyRepsPicker(large: false, tiny: true),
                          const SizedBox(height: 1),
                          const Text(
                            'Tap to edit',
                            style: TextStyle(
                                fontSize: 9, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Container(
                      width: 1,
                      height: 50,
                      color: Colors.white12,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),

                    // Right: days per week
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Days / week',
                            style: TextStyle(
                                fontSize: 11, color: Colors.white70),
                          ),
                          const SizedBox(height: 3),
                          _daysPerWeekPicker(large: false, tiny: true),
                          const SizedBox(height: 1),
                          const Text(
                            'Tap to edit',
                            style: TextStyle(
                                fontSize: 9, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Reps/day label centred
            _repsPerDayLabel(),

            const SizedBox(height: 3),

            // Start button full-width
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: _startButton(),
            ),
          ],
        ),
      );
    });
  }

  // ── Goal setter sub-widgets ───────────────────────────────────────────────

  Widget _weeklyRepsPicker({required bool large, bool tiny = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pickerButton(
          icon: Icons.remove_rounded,
          onTap: _weeklyReps > _repMin
              ? () => setState(() => _weeklyReps -= _repStep)
              : null,
          large: large,
          tiny: tiny,
        ),
        SizedBox(width: large ? 24 : 12),
        GestureDetector(
          onTap: () => _showNumberDialog(
            title: 'Weekly reps',
            current: _weeklyReps,
            min: _repMin,
            max: _repMax,
            onConfirm: (v) => setState(() => _weeklyReps = v),
          ),
          child: SizedBox(
            width: 140,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$_weeklyReps',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: large ? 48 : (tiny ? 36 : 38),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF2563EB),
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: large ? 24 : 12),
        _pickerButton(
          icon: Icons.add_rounded,
          onTap: _weeklyReps < _repMax
              ? () => setState(() => _weeklyReps += _repStep)
              : null,
          large: large,
          tiny: tiny,
        ),
      ],
    );
  }

  Widget _daysPerWeekPicker({required bool large, bool tiny = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pickerButton(
          icon: Icons.remove_rounded,
          onTap: _goalDays > _daysMin
              ? () => setState(() => _goalDays--)
              : null,
          large: large,
          tiny: tiny,
        ),
        SizedBox(width: large ? 20 : 12),
        GestureDetector(
          onTap: () => _showNumberDialog(
            title: 'Days per week',
            current: _goalDays,
            min: _daysMin,
            max: _daysMax,
            onConfirm: (v) => setState(() => _goalDays = v),
          ),
          child: SizedBox(
            width: large ? 80 : (tiny ? 50 : 60),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$_goalDays',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: large ? 44 : (tiny ? 36 : 38),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                  decoration: TextDecoration.underline,
                  decorationColor: const Color(0xFF2563EB),
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: large ? 20 : 12),
        _pickerButton(
          icon: Icons.add_rounded,
          onTap: _goalDays < _daysMax
              ? () => setState(() => _goalDays++)
              : null,
          large: large,
          tiny: tiny,
        ),
      ],
    );
  }

  Widget _repsPerDayLabel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        '= $_repsPerDay reps per day',
        key: ValueKey('$_weeklyReps-$_goalDays'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _finish,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          minimumSize: const Size(double.infinity, 44),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Start training →',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Button helpers ────────────────────────────────────────────────────────

  /// Unified picker button — [large] for portrait, [tiny] for compact landscape.
  Widget _pickerButton({
    required IconData icon,
    VoidCallback? onTap,
    bool large = false,
    bool tiny = false,
  }) {
    final enabled = onTap != null;
    final double sz = large ? 60 : (tiny ? 36 : 44);
    final double iconSz = large ? 28 : (tiny ? 18 : 22);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: sz,
        height: sz,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF2563EB).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? const Color(0xFF2563EB) : Colors.white12,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: iconSz,
          color: enabled ? const Color(0xFF2563EB) : Colors.white24,
        ),
      ),
    );
  }

}
