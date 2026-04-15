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
  static const int _totalPages = 6;

  late _Palette _p;

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
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
          'Your AI-powered rep counter. Only perfect-form reps count — every rep matters.',
    );
  }

  // ── Page 2: How it works ──────────────────────────────────────────────────

  Widget _buildHowItWorksPage() {
    return _buildInfoPage(
      icon: Icons.phone_android,
      title: 'How it works',
      bullets: [
        'Prop your phone up so your full body is visible',
        'Side view works best, 1–2 metres away',
        'Phone at roughly chest height for best detection',
        'Press Start and begin your workout',
      ],
    );
  }

  // ── Page 3: What you can do ───────────────────────────────────────────────

  Widget _buildWhatYouCanDoPage() {
    return _buildInfoPage(
      icon: Icons.dashboard_rounded,
      title: 'What you can do',
      bullets: [
        'Quick workouts or custom sets, reps and rest timers',
        'Track streaks, set daily and weekly goals',
        'Earn badges and beat personal records',
        'Full workout history with form scores',
      ],
    );
  }

  // ── Page 4: Push-ups supported ────────────────────────────────────────────

  Widget _buildPushUpsPage() {
    return _buildInfoPage(
      icon: Icons.sports_gymnastics,
      title: 'Push-ups supported',
      subtitle:
          'Standard, wide, diamond, pike and more. Accuracy works best with standard push-ups. More exercises coming soon.',
    );
  }

  // ── Page 5: Tips for best results ────────────────────────────────────────

  Widget _buildTipsPage() {
    return _buildInfoPage(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Tips for best results',
      bullets: [
        'Controlled, steady pace — the AI needs to see each rep clearly',
        'Good lighting helps accuracy significantly',
        'Make sure your full body stays in frame',
        "You'll hear a ding for each good rep counted",
      ],
    );
  }

  // ── Page 6: You're ready! ─────────────────────────────────────────────────

  Widget _buildReadyPage() {
    return _buildInfoPage(
      icon: Icons.check_circle_outline_rounded,
      title: "You're ready!",
      subtitle:
          "Start your first workout and see what you're capable of.",
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
            'Get Started',
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
