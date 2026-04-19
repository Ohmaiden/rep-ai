/// Rep AI — AI-powered rep counter
/// ================================
/// Main entry point. Sets up themes, providers, and navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/audio_service.dart';
import 'services/database_service.dart';
import 'services/workout_state.dart';
import 'services/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'screens/home_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/workout_setup_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/pre_workout_guide_screen.dart';
import 'screens/workout_hub_screen.dart';
import 'screens/whats_new_screen.dart';

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

  // Auth + cloud sync (graceful — app works fully offline if Firebase not configured).
  final authService = AuthService();
  await authService.initialize();
  final syncService = CloudSyncService(authService: authService, db: dbService);
  authService.setOnSignIn(() => syncService.pullAndMerge());

  // Audio service — shared provider so workout hub, workout screen, and summary
  // screen all see the same mute state.
  final audioService = WorkoutAudioService();
  await audioService.loadMuted();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: dbService),
        ChangeNotifierProvider(create: (_) => WorkoutState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(savedTheme)),
        ChangeNotifierProvider<AuthService>.value(value: authService),
        Provider<CloudSyncService>.value(value: syncService),
        ChangeNotifierProvider<WorkoutAudioService>.value(value: audioService),
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
      case '/guide':
        final isCustom = settings.arguments == true;
        page = PreWorkoutGuideScreen(isCustom: isCustom);
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
// Tab indices: 0=Home, 1=Workout, 2=History, 3=Settings
// All four tabs are in the IndexedStack; _stackIndex = _selectedIndex directly.

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  // Direct 1-to-1 mapping now that all tabs are in the stack.
  int get _stackIndex => _selectedIndex;

  @override
  void initState() {
    super.initState();
    // Show What's New popup once after the first frame if version changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WhatsNewScreen.showIfNeeded(context);
    });
  }

  void _onTap(int navIndex) {
    if (navIndex == 2) {
      _historyKey.currentState?.refresh();
    } else if (navIndex == 0) {
      _homeKey.currentState?.refresh();
    }
    setState(() => _selectedIndex = navIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    final navBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final navUnselected = isDark ? Colors.white54 : const Color(0xFF64748B);
    final navTopBorder =
        (isDark || isTablet) ? null : const Color(0xFFE2E8F0);

    return Scaffold(
      body: IndexedStack(
        index: _stackIndex,
        children: [
          HomeScreen(key: _homeKey),
          const WorkoutHubScreen(),
          HistoryScreen(key: _historyKey),
          const SettingsScreen(),
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
