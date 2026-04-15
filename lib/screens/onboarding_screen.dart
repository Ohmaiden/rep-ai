/// Onboarding Screen
/// ==================
/// 6-screen informational intro shown on first launch.
/// Swipeable with dot indicators. Portrait + landscape aware.
/// Saves onboarding_done to SharedPreferences on completion.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const int _totalPages = 9;

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

  // ── Page 7: You're ready! ─────────────────────────────────────────────────

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
