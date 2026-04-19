/// Onboarding Screen
/// ==================
/// 6-screen informational intro shown on first launch.
/// Swipeable with dot indicators. Portrait + landscape aware.
/// Saves onboarding_done to SharedPreferences on completion.
library;

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const int _totalPages = 10;

  // Auth page state
  bool _authIsSignUp = false;
  bool _authLoading = false;
  String? _authError;
  final _authEmailCtrl = TextEditingController();
  final _authPasswordCtrl = TextEditingController();
  final _authNameCtrl = TextEditingController();
  bool _authObscurePassword = true;

  // Goals page inputs — optional; zero means "skip / no goal set".
  int _dailyGoal = 20;

  // Fitness level — null means user skipped without selecting.
  String? _fitnessLevel;

  // Active workout days — 1=Mon … 7=Sun. Defaults to all 7 selected.
  final Set<int> _activeDays = {1, 2, 3, 4, 5, 6, 7};

  late _Palette _p;

  int get _weeklyGoal => _dailyGoal * _activeDays.length;

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    // Persist fitness level only when the user actually selected one.
    if (_fitnessLevel != null) {
      await prefs.setString('fitness_level', _fitnessLevel!);
    }
    // Persist active workout days — always write, even if unchanged from
    // default, so downstream readers can rely on the key existing.
    final daysCsv = (_activeDays.toList()..sort()).join(',');
    await prefs.setString('active_workout_days', daysCsv);
    // Persist goals only when the user actually set something — a value of 0
    // (or lower) means they skipped, and we must leave any existing goal alone.
    if (_weeklyGoal > 0) {
      await prefs.setInt('onboarding_goal_reps', _weeklyGoal);
      // Derive the days/week value the home screen uses to fall back to a
      // daily target if no explicit custom_daily_target is saved.
      final derivedDays = _activeDays.isNotEmpty ? _activeDays.length : 7;
      await prefs.setInt('onboarding_goal_days', derivedDays);
    }
    if (_dailyGoal > 0) {
      await prefs.setInt('custom_daily_target', _dailyGoal);
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

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _authEmailCtrl.dispose();
    _authPasswordCtrl.dispose();
    _authNameCtrl.dispose();
    super.dispose();
  }

  // ── Scaffold ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _p = _Palette.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isLastPage = _page == _totalPages - 1;

    return Scaffold(
      backgroundColor: _p.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — top right
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    'Skip',
                    style: TextStyle(color: _p.muted, fontSize: 15),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const PageScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _buildWelcomePage(),
                  _buildHowItWorksPage(),
                  _buildWhatYouCanDoPage(),
                  _buildPushUpsPage(),
                  _buildTipsPage(),
                  _buildFitnessLevelPage(),
                  _buildActiveDaysPage(),
                  _buildGoalsPage(),
                  _buildAccountPage(),
                  _buildReadyPage(),
                ],
              ),
            ),

            // Dot indicators
            Padding(
              padding:
                  EdgeInsets.only(bottom: isLandscape ? 6.0 : 16.0),
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
                          : _p.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Next button — hidden on last page (has its own Get Started)
            if (!isLastPage)
              Padding(
                padding: EdgeInsets.fromLTRB(
                    24, 0, 24, isLandscape ? 8.0 : 32.0),
                child: SizedBox(
                  width: double.infinity,
                  height: isLandscape ? 44.0 : 56.0,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      minimumSize: const Size(double.infinity, 44),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Next',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
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

  // ── Reusable page builder ─────────────────────────────────────────────────

  /// Builds a consistent portrait + landscape info page with optional bullets.
  Widget _buildInfoPage({
    required IconData icon,
    required String title,
    String? subtitle,
    List<String>? bullets,
    Widget? trailing,
  }) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _infoLandscape(
              icon: icon,
              title: title,
              subtitle: subtitle,
              bullets: bullets,
              trailing: trailing);
        }
        return _infoPortrait(
            icon: icon,
            title: title,
            subtitle: subtitle,
            bullets: bullets,
            trailing: trailing);
      },
    );
  }

  Widget _infoPortrait({
    required IconData icon,
    required String title,
    String? subtitle,
    List<String>? bullets,
    Widget? trailing,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconCircle(icon, size: 100, iconSize: 48),
                const SizedBox(height: 32),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _p.primary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, color: _p.tertiary, height: 1.5),
                  ),
                ],
                if (bullets != null) ...[
                  const SizedBox(height: 20),
                  ...bullets.map(
                    (b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '•  ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: _p.tertiary,
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...[
                  const SizedBox(height: 32),
                  trailing,
                ],
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoLandscape({
    required IconData icon,
    required String title,
    String? subtitle,
    List<String>? bullets,
    Widget? trailing,
  }) {
    return LayoutBuilder(builder: (context, constraints) {
      final iconSz = (constraints.maxHeight * 0.25).clamp(0.0, 64.0);
      return SizedBox(
        height: constraints.maxHeight,
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
                  child: _iconCircle(icon,
                      size: iconSz, iconSize: iconSz * 0.48),
                ),
              ),
              const SizedBox(width: 16),
              // Right ~60%: text
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _p.primary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                              fontSize: 14,
                              color: _p.tertiary,
                              height: 1.4),
                        ),
                      ],
                      if (bullets != null) ...[
                        const SizedBox(height: 8),
                        ...bullets.map(
                          (b) => Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '•  ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    b,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: _p.tertiary,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (trailing != null) ...[
                        const SizedBox(height: 12),
                        trailing,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _iconCircle(IconData icon,
      {required double size, required double iconSize}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child:
          Icon(icon, size: iconSize, color: const Color(0xFF2563EB)),
    );
  }

  // ── Page 1: Welcome ───────────────────────────────────────────────────────

  Widget _buildWelcomePage() {
    return _buildInfoPage(
      icon: Icons.fitness_center,
      title: 'Welcome to Rep AI',
      subtitle:
          'This app counts your push-ups using your phone camera. Swipe right to learn how.',
    );
  }

  // ── Page 2: How it works ──────────────────────────────────────────────────

  Widget _buildHowItWorksPage() {
    return _buildInfoPage(
      icon: Icons.phone_android,
      title: 'Set up your phone',
      subtitle:
          'Place your phone so the camera can see all of you. Then press start.',
      bullets: [
        'Stand your phone up on the floor or a low surface.',
        'Place it 1 to 2 metres to your side.',
        'Point the camera at chest height.',
        'Check your whole body fits in the preview.',
      ],
    );
  }

  // ── Page 3: What you can do ───────────────────────────────────────────────

  Widget _buildWhatYouCanDoPage() {
    return _buildInfoPage(
      icon: Icons.dashboard_rounded,
      title: 'What you can do',
      subtitle: 'Pick any of these from the home screen.',
      bullets: [
        'Start a quick workout with no limit.',
        'Build custom sets with reps and rest times.',
        'Track streaks and daily goals.',
        'See past workouts in the history tab.',
      ],
    );
  }

  // ── Page 4: Push-ups supported ────────────────────────────────────────────

  Widget _buildPushUpsPage() {
    return _buildInfoPage(
      icon: Icons.sports_gymnastics,
      title: 'What gets counted',
      subtitle:
          'Each full push-up counts as one rep. Standard, wide, diamond and pike all work. Only clean reps are counted.',
    );
  }

  // ── Page 5: Tips for best results ────────────────────────────────────────

  Widget _buildTipsPage() {
    return _buildInfoPage(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Tips',
      subtitle: 'Follow these for the most accurate count.',
      bullets: [
        'Move at a steady pace so each rep is clear.',
        'Use a well lit room.',
        'Keep your whole body in the camera view.',
        'Listen for the ding on each counted rep.',
      ],
    );
  }

  // ── Page 6: Goals ─────────────────────────────────────────────────────────

  Widget _buildGoalsPage() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconCircle(Icons.flag_rounded, size: 88, iconSize: 42),
                const SizedBox(height: 24),
                Text(
                  'Your daily goal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _p.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pick how many push-ups you want to do each training day. Set it to zero to skip.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: _p.tertiary, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the plus and minus buttons to change the number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: _p.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                _goalStepper(
                  label: 'Daily goal',
                  suffix: 'push-ups a day',
                  value: _dailyGoal,
                  step: 5,
                  onChanged: (v) => setState(() => _dailyGoal = v),
                ),
                const SizedBox(height: 12),
                _weeklyTotalCard(),
                const SizedBox(height: 20),
                Text(
                  'You can change this later in the settings tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: _p.muted, height: 1.4),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalStepper({
    required String label,
    required String suffix,
    required int value,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _p.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$value $suffix',
                  style: TextStyle(
                    fontSize: 13,
                    color: _p.tertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: value <= 0
                ? null
                : () => onChanged((value - step).clamp(0, 9999)),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: const Color(0xFF2563EB),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _p.primary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + step),
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }

  Widget _weeklyTotalCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _p.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_dailyGoal push-ups across ${_activeDays.length} days',
                  style: TextStyle(
                    fontSize: 13,
                    color: _p.tertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$_weeklyGoal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _p.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Fitness level page ────────────────────────────────────────────────────

  Widget _buildFitnessLevelPage() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconCircle(Icons.trending_up_rounded, size: 88, iconSize: 42),
                const SizedBox(height: 24),
                Text(
                  'Your fitness level',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _p.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This sets your starting daily goal. You can change it on the next page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: _p.tertiary, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a level.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: _p.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                _fitnessLevelTile(
                  value: 'beginner',
                  title: 'Beginner',
                  subtitle: '20 push-ups a day',
                  icon: Icons.looks_one_rounded,
                ),
                const SizedBox(height: 10),
                _fitnessLevelTile(
                  value: 'intermediate',
                  title: 'Intermediate',
                  subtitle: '50 push-ups a day',
                  icon: Icons.looks_two_rounded,
                ),
                const SizedBox(height: 10),
                _fitnessLevelTile(
                  value: 'advanced',
                  title: 'Advanced',
                  subtitle: '100 push-ups a day',
                  icon: Icons.looks_3_rounded,
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fitnessLevelTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _fitnessLevel == value;
    return InkWell(
      onTap: () {
        setState(() {
          _fitnessLevel = value;
          switch (value) {
            case 'beginner':
              _dailyGoal = 20;
              break;
            case 'intermediate':
              _dailyGoal = 50;
              break;
            case 'advanced':
              _dailyGoal = 100;
              break;
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
              : const Color(0xFF2563EB).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : const Color(0xFF2563EB).withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2563EB), size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _p.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        fontSize: 13, color: _p.tertiary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF2563EB), size: 24),
          ],
        ),
      ),
    );
  }

  // ── Active workout days page ──────────────────────────────────────────────

  Widget _buildActiveDaysPage() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _iconCircle(Icons.calendar_month_rounded,
                    size: 88, iconSize: 42),
                const SizedBox(height: 24),
                Text(
                  'Your training days',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: _p.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pick the days you plan to work out. This sets your weekly goal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: _p.tertiary, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a day to turn it on or off.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: _p.muted, height: 1.4),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      _dayChip(i, _activeDays.contains(i), (sel) {
                        setState(() {
                          if (sel) {
                            _activeDays.add(i);
                          } else if (_activeDays.length > 1) {
                            _activeDays.remove(i);
                          }
                        });
                      }),
                  ],
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dayChip(int day, bool selected, ValueChanged<bool> onToggle) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return FilterChip(
      selected: selected,
      label: Text(labels[day - 1]),
      onSelected: onToggle,
      showCheckmark: false,
      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.2),
      backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.05),
      labelStyle: TextStyle(
        fontSize: 14,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? const Color(0xFF2563EB) : _p.tertiary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? const Color(0xFF2563EB)
              : const Color(0xFF2563EB).withValues(alpha: 0.25),
          width: selected ? 2 : 1,
        ),
      ),
    );
  }

  // ── Page 9: Account (sign in / create / skip) ────────────────────────────

  Future<void> _handleOnboardingAuth() async {
    final auth = context.read<AuthService>();
    final email = _authEmailCtrl.text.trim();
    final password = _authPasswordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _authError = 'Enter your email and password.');
      return;
    }
    if (_authIsSignUp && password.length < 6) {
      setState(() => _authError = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _authLoading = true; _authError = null; });
    try {
      if (_authIsSignUp) {
        await auth.signUpWithEmail(email, password,
            displayName: _authNameCtrl.text.trim().isNotEmpty
                ? _authNameCtrl.text.trim()
                : null);
      } else {
        await auth.signInWithEmail(email, password);
      }
      if (mounted) _nextPage();
    } catch (e) {
      if (mounted) {
        setState(() => _authError = _authFriendlyError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _handleOnboardingGoogle() async {
    final auth = context.read<AuthService>();
    setState(() { _authLoading = true; _authError = null; });
    try {
      await auth.signInWithGoogle();
      if (mounted) _nextPage();
    } catch (e) {
      if (mounted) {
        if (!e.toString().contains('cancelled')) {
          setState(() => _authError = _authFriendlyError(e.toString()));
        }
      }
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  Future<void> _handleOnboardingApple() async {
    final auth = context.read<AuthService>();
    setState(() { _authLoading = true; _authError = null; });
    try {
      await auth.signInWithApple();
      if (mounted) _nextPage();
    } catch (e) {
      if (mounted) {
        if (!e.toString().contains('cancelled')) {
          setState(() => _authError = _authFriendlyError(e.toString()));
        }
      }
    } finally {
      if (mounted) setState(() => _authLoading = false);
    }
  }

  String _authFriendlyError(String raw) {
    if (raw.contains('invalid-email')) { return 'Invalid email address.'; }
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) { return 'Incorrect email or password.'; }
    if (raw.contains('email-already-in-use')) { return 'An account with this email already exists.'; }
    if (raw.contains('weak-password')) { return 'Choose a stronger password.'; }
    if (raw.contains('network-request-failed')) { return 'No internet connection.'; }
    return 'Something went wrong. Please try again.';
  }

  Widget _buildAccountPage() {
    final auth = context.watch<AuthService>();

    // Already signed in — show a confirmation and let them continue.
    if (auth.isSignedIn) {
      return _buildInfoPage(
        icon: Icons.check_circle_rounded,
        title: 'You\'re signed in',
        subtitle: 'Signed in as ${auth.displayName ?? auth.userEmail ?? 'you'}. '
            'Your workouts will be backed up to the cloud.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _iconCircle(Icons.cloud_rounded, size: 88, iconSize: 42),
                    const SizedBox(height: 24),
                    Text(
                      'Save your progress',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _p.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create a free account to back up your workouts '
                      'and access them across devices.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, color: _p.tertiary, height: 1.5),
                    ),
                    const SizedBox(height: 28),

                    if (!auth.isAvailable) ...[
                      Text(
                        'Account sign-in is not available right now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: _p.muted),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      // ── Google ────────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _authLoading ? null : _handleOnboardingGoogle,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _p.primary,
                            side: BorderSide(
                                color: _p.divider),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const _GoogleLogo(),
                          label: const Text('Continue with Google',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      // ── Apple (iOS only) ───────────────────────────────────
                      if (Platform.isIOS) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _authLoading ? null : _handleOnboardingApple,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _p.primary,
                              side: BorderSide(color: _p.divider),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: Icon(Icons.apple, color: _p.primary, size: 22),
                            label: const Text('Continue with Apple',
                                style: TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // ── Divider ────────────────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: Divider(color: _p.divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('or',
                                style: TextStyle(
                                    color: _p.muted, fontSize: 13)),
                          ),
                          Expanded(child: Divider(color: _p.divider)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Sign-up / sign-in toggle label ─────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _authIsSignUp ? 'Create account' : 'Sign in with email',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _p.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => setState(() {
                              _authIsSignUp = !_authIsSignUp;
                              _authError = null;
                            }),
                            child: Text(
                              _authIsSignUp ? 'Sign in instead' : 'Create one instead',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Email fields ───────────────────────────────────────
                      if (_authIsSignUp)
                        _authField(
                          controller: _authNameCtrl,
                          hint: 'Name (optional)',
                          icon: Icons.person_outline_rounded,
                        ),
                      if (_authIsSignUp) const SizedBox(height: 8),
                      _authField(
                        controller: _authEmailCtrl,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 8),
                      _authField(
                        controller: _authPasswordCtrl,
                        hint: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _authObscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _authObscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: _p.muted,
                          ),
                          onPressed: () => setState(
                              () => _authObscurePassword = !_authObscurePassword),
                        ),
                      ),

                      if (_authError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _authError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── Submit ─────────────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _authLoading ? null : _handleOnboardingAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _authLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text(
                                  _authIsSignUp ? 'Create account' : 'Sign in',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],

                    // ── Skip ──────────────────────────────────────────────────
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _nextPage,
                      child: Text(
                        'Skip for now',
                        style: TextStyle(
                            color: _p.muted,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: _p.primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _p.muted),
        prefixIcon: Icon(icon, color: _p.muted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFF2563EB).withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
      ),
    );
  }

  // ── Page 10: You're ready! ────────────────────────────────────────────────

  Widget _buildReadyPage() {
    return _buildInfoPage(
      icon: Icons.check_circle_outline_rounded,
      title: "You're all set",
      subtitle:
          'Tap the question mark button on the home screen any time to come back to this guide.',
      trailing: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _finish,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text(
            "Let's go!",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ── Google logo widget ──────────────────────────────────────────────────────
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..style = PaintingStyle.fill;

    // Blue (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -1.0472, 2.0944, true, paint);

    // Red (top-left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), -2.618, 1.5708, true, paint);

    // Yellow (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 2.618, 0.5236, true, paint);

    // Green (bottom-right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromLTWH(0, 0, s, s), 2.618 + 0.5236, 0.5236, true, paint);

    // White centre circle
    paint.color = Colors.white;
    canvas.drawCircle(Offset(s / 2, s / 2), s * 0.35, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Theme palette ───────────────────────────────────────────────────────────
// Resolved once per build so the onboarding adapts to light / dark mode.
class _Palette {
  final Color bg;
  final Color primary;
  final Color tertiary;
  final Color muted;
  final Color divider;

  const _Palette({
    required this.bg,
    required this.primary,
    required this.tertiary,
    required this.muted,
    required this.divider,
  });

  static _Palette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const _Palette(
        bg: Color(0xFF0F172A),
        primary: Colors.white,
        tertiary: Colors.white60,
        muted: Colors.white54,
        divider: Colors.white24,
      );
    }
    return const _Palette(
      bg: Color(0xFFF8FAFC),
      primary: Color(0xFF0F172A),
      tertiary: Color(0xFF475569),
      muted: Color(0xFF64748B),
      divider: Color(0xFFCBD5E1),
    );
  }
}
