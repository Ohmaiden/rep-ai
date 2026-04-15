/// Rep AI — AI-powered rep counter
/// ================================
/// Main entry point. Sets up themes, providers, and navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/database_service.dart';
import 'services/workout_state.dart';
import 'services/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/workout_setup_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait-only across all devices (iPhone, iPad, Android phone & tablet).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final dbService = DatabaseService();
  await dbService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final savedTheme = prefs.getString('theme_mode');

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        ChangeNotifierProvider(create: (_) => WorkoutState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(savedTheme)),
      ],
      child: RepCounterApp(showOnboarding: !onboardingDone),
    ),
  );
}

class RepCounterApp extends StatelessWidget {
  final bool showOnboarding;

  const RepCounterApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Rep AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeProvider.lightTheme,
      darkTheme: ThemeProvider.darkTheme,
      themeMode: themeProvider.mode,
      home: showOnboarding ? const OnboardingScreen() : const MainShell(),
      onGenerateRoute: _generateRoute,
    );
  }

  static Route<dynamic> _generateRoute(RouteSettings settings) {
    final Widget page;

    switch (settings.name) {
      case '/':
        page = const MainShell();
      case '/workout':
        return PageRouteBuilder<dynamic>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WorkoutScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final tween = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      case '/onboarding':
        page = const OnboardingScreen();
      case '/setup':
        page = const WorkoutSetupScreen();
      default:
        page = const MainShell();
    }

    return PageRouteBuilder<dynamic>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

// ── Main Shell — persistent bottom nav ─────────────────────────────────────
// Tab indices: 0=Home, 1=Workout (full-screen push), 2=History, 3=Settings
// IndexedStack contains [Home, History, Settings] → mapped indices [0,2,3]

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 0=Home, 2=History, 3=Settings  (1=Workout is full-screen, no persistent state)
  int _selectedIndex = 0;

  // Maps nav bar tab index → IndexedStack index
  // Tab 0=Home → stack 0, Tab 2=History → stack 1, Tab 3=Settings → stack 2
  int get _stackIndex {
    if (_selectedIndex == 2) return 1;
    if (_selectedIndex == 3) return 2;
    return 0;
  }

  void _onTap(int navIndex) {
    if (navIndex == 1) {
      // Workout — launch full-screen, don't update _selectedIndex
      context.read<WorkoutState>().startSession(exercise: 'Push-ups');
      Navigator.pushNamed(context, '/workout');
      return;
    }
    final tabIndex = navIndex > 1 ? navIndex : navIndex; // 0, 2, 3
    setState(() => _selectedIndex = tabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final navBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final navUnselected = isDark ? Colors.white54 : const Color(0xFF64748B);
    // Show a subtle top border only on phones in light mode. On iPad we drop
    // the border (and the default Material elevation shadow below) so the bar
    // blends into the page.
    final navTopBorder =
        (isDark || isTablet) ? null : const Color(0xFFE2E8F0);

    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: const [
          HomeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: navTopBorder == null
              ? null
              : Border(top: BorderSide(color: navTopBorder, width: 1)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onTap,
              type: BottomNavigationBarType.fixed,
              backgroundColor: navBg,
              elevation: isTablet ? 0 : 8,
              selectedItemColor: const Color(0xFF2563EB),
              unselectedItemColor: navUnselected,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center_rounded),
                  label: 'Workout',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
