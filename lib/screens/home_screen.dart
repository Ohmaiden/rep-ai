/// Home Screen
/// ============
/// Main screen with streak calendar, stats, and workout buttons.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/workout_state.dart';
import '../models/workout_models.dart';
import '../widgets/tappable_number.dart';
import 'stats_detail_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkoutSession> _recentSessions = [];
  Map<String, dynamic> _stats = {};
  int _streak = 0;
  Set<DateTime> _workoutDates = {};
  bool _loading = true;
  bool _calendarExpanded = false;
  Map<String, dynamic> _records = {};
  Map<String, int> _repsByPeriod = {};
  int _currentMonthReps = 0;
  Set<String> _earnedBadges = {};
  Map<String, String> _badgeDates = {};
  // Daily target (base — no carry-over)
  int _adjustedDailyTarget = 0;
  int _todayRepsCompleted = 0;
  int _weekRepsCompleted = 0;
  int _weeklyGoalReps = 0;

  bool _goalsEnabled = true;
  int _weekStartDay = 1; // 1=Mon … 7=Sun

  static const _weekDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final sessions = await db.getRecentSessions(limit: 5);
    final stats = await db.getOverallStats();
    final dates = await db.getWorkoutDates();
    final records = await db.getPersonalRecords();
    final repsPeriod = await db.getRepsByPeriod();
    final goal = await db.getGoal();
    final goalTarget = goal['target'] as int;
    final goalPeriod = goal['period'] as String;
    final goalProgress = repsPeriod[goalPeriod == 'daily'
            ? 'today'
            : goalPeriod == 'monthly'
                ? 'thisMonth'
                : 'thisWeek'] ??
        0;
    if (goalTarget > 0 && goalProgress >= goalTarget) {
      await db.saveGoalCompletion(goalTarget, goalPeriod);
    }
    final currentMonthReps = repsPeriod['thisMonth'] ?? 0;
    await db.checkAndAwardBadges();
    final badges = await db.getEarnedBadges();
    final badgeDates = await db.getEarnedBadgeDates();

    // Load targets — custom_ keys always win; fall back to onboarding values
    final prefs = await SharedPreferences.getInstance();
    final goalsEnabled = prefs.getBool('goals_enabled') ?? true;
    final weekStartDay = prefs.getInt('week_start_day') ?? 1;
    final onboardingReps = prefs.getInt('onboarding_goal_reps') ?? 0;
    final onboardingDays = prefs.getInt('onboarding_goal_days') ?? 0;
    final customWeekly = prefs.getInt('custom_weekly_target');
    final customDaily = prefs.getInt('custom_daily_target');

    // Weekly goal: custom_weekly_target → onboarding_goal_reps → 0
    final effectiveWeeklyReps = customWeekly ?? (onboardingReps > 0 ? onboardingReps : 0);

    // Daily target: custom_daily_target → derived from weekly/days → 0 (no carry-over)
    final baseDailyTarget = customDaily ??
        ((effectiveWeeklyReps > 0 && onboardingDays > 0)
            ? (effectiveWeeklyReps / onboardingDays).ceil()
            : 0);

    // Reset streak if last workout was before yesterday
    await db.checkAndResetStaleStreak();

    // Count today's and this week's reps
    int todayRepsCompleted = 0;
    int weekRepsCompleted = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysBack = (now.weekday - weekStartDay) % 7;
    final weekStart = today.subtract(Duration(days: daysBack));
    final allSessions = await db.getAllSessions();
    for (final s in allSessions) {
      final d = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      if (!d.isBefore(weekStart)) {
        weekRepsCompleted += s.goodFormReps;
        if (d == today) todayRepsCompleted += s.goodFormReps;
      }
    }

    // Re-read streak after potential reset
    final freshStreakData = await db.getStreakData();

    setState(() {
      _currentMonthReps = currentMonthReps;
      _earnedBadges = badges;
      _badgeDates = badgeDates;
      _recentSessions = sessions;
      _stats = stats;
      _streak = freshStreakData['currentStreak'] as int;
      _repsByPeriod = repsPeriod;
      _workoutDates = dates;
      _records = records;
      _goalsEnabled = goalsEnabled;
      _weekStartDay = weekStartDay;
      _adjustedDailyTarget = baseDailyTarget;
      _todayRepsCompleted = todayRepsCompleted;
      _weekRepsCompleted = weekRepsCompleted;
      _weeklyGoalReps = effectiveWeeklyReps;
      _loading = false;
    });
  }

  Future<void> _resetAndShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/onboarding');
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replay onboarding tutorial?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This will restart the setup walkthrough where you can update your fitness level and weekly goal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetAndShowOnboarding();
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: Center(
                  child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text('Rep AI',
                                        style: theme
                                            .textTheme.headlineLarge),
                                    const SizedBox(height: 2),
                                    Text('AI-powered rep counting',
                                        style:
                                            theme.textTheme.bodyMedium),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: _showHelp,
                                icon: const Icon(
                                    Icons.help_outline_rounded),
                                color: theme.textTheme.bodyMedium?.color,
                                tooltip: 'Help',
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Streak card + calendar
                      if (_streak > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: _buildStreakSection(),
                          ),
                        ),

                      // Monthly rep summary card
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _buildMonthlyRepCard(),
                        ),
                      ),

                      // Daily goal carry-over card (tap-to-edit)
                      if (_goalsEnabled)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: _buildDailyGoalCard(),
                          ),
                        ),

                      // Badges
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _buildBadgesRow(),
                        ),
                      ),

                      // Personal records
                      if (_records['mostReps'] != null &&
                          (_records['mostReps'] as int) > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 12, 20, 0),
                            child: _buildRecordsCard(),
                          ),
                        ),

                      // Stats
                      if (_stats['totalSessions'] != null &&
                          _stats['totalSessions'] > 0)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: _buildStatsRow(),
                          ),
                        ),

                      // Workout buttons
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                          child: _buildWorkoutButtons(context),
                        ),
                      ),

                      // Recent workouts header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Recent Workouts',
                                  style:
                                      theme.textTheme.headlineMedium),
                              if (_recentSessions.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                            context, '/history')
                                        .then((_) => _loadData());
                                  },
                                  child: const Text('See All'),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Session list
                      if (_recentSessions.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Icon(Icons.fitness_center,
                                        size: 38,
                                        color: Colors.grey[300]),
                                    const SizedBox(height: 12),
                                    Text('No workouts yet',
                                        style: theme
                                            .textTheme.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start your first session to see your history here',
                                      style:
                                          theme.textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              child: _buildSessionCard(
                                  _recentSessions[index]),
                            ),
                            childCount: _recentSessions.length,
                          ),
                        ),

                      const SliverToBoxAdapter(
                          child: SizedBox(height: 40)),
                    ],
                  ),
                  ),
                  ),
                ),
        ),
      ),
    );
  }

  // ── Streak + Calendar ─────────────────────────────────────────────────

  Widget _buildStreakSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _calendarExpanded = !_calendarExpanded),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF4500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('\u{1F525}',
                    style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_streak Day Streak!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _streak >= 7
                            ? 'Unstoppable!'
                            : 'Don\'t break the chain',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _calendarExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        if (_calendarExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildCalendar(),
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth =
        DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7; // 0=Sun
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = ((constraints.maxWidth - 32) / 7).clamp(36.0, 52.0);
            final fontSize = (cellSize * 0.36).clamp(12.0, 16.0);
            return Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(now),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                // Day labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map((d) => SizedBox(
                            width: cellSize,
                            child: Center(
                              child: Text(d,
                                  style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyMedium
                                          ?.color)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                // Calendar grid
                ...List.generate(
                  ((daysInMonth + startWeekday + 6) ~/ 7),
                  (week) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (dow) {
                        final dayNum = week * 7 + dow - startWeekday + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return SizedBox(width: cellSize, height: cellSize);
                        }
                        final date =
                            DateTime(now.year, now.month, dayNum);
                        final hasWorkout = _workoutDates.contains(date);
                        final isToday = dayNum == now.day;

                        return GestureDetector(
                          onTap: hasWorkout
                              ? () => _openCalendarDay(date)
                              : null,
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: hasWorkout
                                  ? const Color(0xFF2563EB)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: isToday && !hasWorkout
                                  ? Border.all(
                                      color: const Color(0xFF2563EB),
                                      width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: hasWorkout || isToday
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: hasWorkout
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF334155)),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────

  void _openRepBreakdown() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => _RepBreakdownScreen(repsByPeriod: _repsByPeriod)),
    );
  }

  Future<void> _openMostReps() async {
    final db = context.read<DatabaseService>();
    final all = await db.getAllSessions();
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MostRepsDetailScreen(sessions: all)));
  }

  Future<void> _openCalendarDay(DateTime date) async {
    final db = context.read<DatabaseService>();
    final all = await db.getAllSessions();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => CalendarDayDetailSheet(date: date, sessions: all),
    );
  }

  Widget _buildStatsRow() {
    final todayReps = _repsByPeriod['today'] ?? 0;
    final dailySubtitle = (!_goalsEnabled)
        ? 'This week: ${_repsByPeriod['thisWeek'] ?? 0}'
        : (_adjustedDailyTarget > 0
            ? '$todayReps / $_adjustedDailyTarget reps today'
            : 'This week: ${_repsByPeriod['thisWeek'] ?? 0}');

    return Row(
      children: [
        _buildStatCard('${_stats['totalSessions']}', 'Sessions',
            Icons.calendar_today, const Color(0xFF2563EB)),
        const SizedBox(width: 12),
        _buildStatCard(
            '$todayReps',
            'Today\'s Reps',
            Icons.repeat,
            const Color(0xFF16A34A),
            onTap: _openRepBreakdown,
            subtitle: dailySubtitle),
        const SizedBox(width: 12),
        _buildStatCard('${_stats['averageFormScore']}%', 'Form Score',
            Icons.check_circle_outline, const Color(0xFFEA580C)),
      ],
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color,
      {VoidCallback? onTap, String? subtitle}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 8),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Badges ─────────────────────────────────────────────────────────────

  static const _badgeDefs = <String, (String, String, IconData, String)>{
    'first_workout': ('\u{1F3CB}', 'First Workout', Icons.fitness_center, 'Complete your first workout'),
    'week_warrior': ('\u{1F525}', 'Week Warrior', Icons.local_fire_department, 'Complete a 7 day workout streak'),
    'century_club': ('\u{1F4AF}', '100 Club', Icons.military_tech, 'Complete 100 total good form reps'),
    'perfect_form': ('\u{2B50}', 'Perfect Form', Icons.star, 'Finish a workout with 100% good form (min 10 reps)'),
    'consistent': ('\u{1F3C6}', 'Consistent', Icons.emoji_events, 'Maintain a 30 day workout streak'),
    'goal_crusher': ('\u{1F4A5}', 'Goal Crusher', Icons.bolt, 'Complete 5 goals'),
  };

  Widget _buildBadgesRow() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Badges', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _badgeDefs.entries.map((e) {
              final earned = _earnedBadges.contains(e.key);
              final (emoji, label, icon, requirement) = e.value;
              return GestureDetector(
                onTap: () => _showBadgeDialog(
                    e.key, emoji, label, requirement, earned),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: earned
                              ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                              : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: earned
                              ? Text(emoji, style: const TextStyle(fontSize: 22))
                              : Icon(Icons.lock_outline,
                                  size: 18,
                                  color: theme.textTheme.bodyMedium?.color),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: earned ? FontWeight.w600 : FontWeight.w400,
                        color: earned
                            ? theme.textTheme.titleMedium?.color
                            : theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showBadgeDialog(String id, String emoji, String label,
      String requirement, bool earned) {
    final dateStr = _badgeDates[id];
    String? formattedDate;
    if (dateStr != null) {
      try {
        final dt = DateTime.parse(dateStr);
        formattedDate = DateFormat('d MMM yyyy').format(dt);
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(earned ? emoji : '\u{1F512}',
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              earned
                  ? 'Earned${formattedDate != null ? ' on $formattedDate' : ''}!'
                  : requirement,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: earned
                    ? const Color(0xFF16A34A)
                    : Theme.of(ctx).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  // ── Monthly Rep Summary Card ──────────────────────────────────────────────

  Widget _buildMonthlyRepCard() {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthLabel = '${_monthName(now.month)} ${now.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_rounded,
                color: Color(0xFF7C3AED), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(monthLabel,
                      style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(height: 2),
                  Text('This month',
                      style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            Text(
              '$_currentMonthReps',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 4),
            Text('reps', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return names[month];
  }

  // ── Daily Goal Card with tap-to-edit ─────────────────────────────────────

  Widget _buildDailyGoalCard() {
    // Always show so users can set a goal even if onboarding was skipped
    final theme = Theme.of(context);
    final hasDaily = _adjustedDailyTarget > 0;
    final hasWeekly = _weeklyGoalReps > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.today_rounded, color: Color(0xFF2563EB), size: 20),
                const SizedBox(width: 8),
                Text('Daily Progress', style: theme.textTheme.titleMedium),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),

            // ── Today row — tappable ───────────────────────────────────────
            InkWell(
              onTap: _editDailyGoal,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            hasDaily
                                ? '$_todayRepsCompleted / $_adjustedDailyTarget reps'
                                : '$_todayRepsCompleted reps — tap to set target',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // iOS keeps the "tap to edit" hint; on Android we drop it
                    // for a sleeker look (the row is still tappable).
                    if (!Platform.isAndroid) ...[
                      const SizedBox(height: 2),
                      Text(
                        '✎ tap to edit',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.5)),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (hasDaily) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_todayRepsCompleted / _adjustedDailyTarget).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Week row — tappable ────────────────────────────────────────
            InkWell(
              onTap: _editWeeklyGoal,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Week',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            hasWeekly
                                ? '$_weekRepsCompleted / $_weeklyGoalReps reps'
                                : '$_weekRepsCompleted reps — tap to set target',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // iOS keeps the "tap to edit" hint; on Android we drop it
                    // for a sleeker look (the row is still tappable).
                    if (!Platform.isAndroid) ...[
                      const SizedBox(height: 2),
                      Text(
                        '✎ tap to edit',
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.5)),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (hasWeekly) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_weekRepsCompleted / _weeklyGoalReps).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: const Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Resets ${_weekDayNames[_weekStartDay - 1]}',
                style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.5)),
              ),
            ],


          ],
        ),
      ),
    );
  }

  // ── Shared rep-count prompt ────────────────────────────────────────────────
  // On iPad, iOS shows a tiny floating numeric keypad in the corner for
  // TextInputType.number. To match the phone experience, on iPad we suppress
  // the system keyboard and render an in-app numeric keypad inside the sheet.

  bool _isIPad(BuildContext context) {
    if (!Platform.isIOS) return false;
    return MediaQuery.of(context).size.shortestSide >= 600;
  }

  Future<int?> _promptForRepCount({
    required String title,
    required String hint,
    required int current,
  }) {
    final ctrl = TextEditingController(text: '$current');
    final useInAppKeypad = _isIPad(context);

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        void submit() {
          final v = int.tryParse(ctrl.text) ?? current;
          Navigator.pop(ctx, v.clamp(1, 99999));
        }

        final sheetTheme = Theme.of(ctx);
        final handleColor = sheetTheme.brightness == Brightness.dark
            ? Colors.white24
            : const Color(0xFFCBD5E1);

        return SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: handleColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: !useInAppKeypad,
                    readOnly: useInAppKeypad,
                    showCursor: true,
                    keyboardType: TextInputType.number,
                    textAlign: useInAppKeypad ? TextAlign.center : TextAlign.start,
                    style: useInAppKeypad
                        ? const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)
                        : null,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      hintText: hint,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  if (useInAppKeypad) ...[
                    const SizedBox(height: 16),
                    _InAppNumericKeypad(controller: ctrl, maxLength: 5),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: submit,
                    child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Tap-to-edit: daily target ──────────────────────────────────────────────

  Future<void> _editDailyGoal() async {
    final current = _adjustedDailyTarget > 0 ? _adjustedDailyTarget : 20;
    final result = await _promptForRepCount(
      title: 'Daily target (reps)',
      hint: 'e.g. 20',
      current: current,
    );

    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('custom_daily_target', result);
      // Recompute from saved value
      setState(() {
        _adjustedDailyTarget = result;
      });
    }
  }

  // ── Tap-to-edit: weekly goal ───────────────────────────────────────────────

  Future<void> _editWeeklyGoal() async {
    final current = _weeklyGoalReps > 0 ? _weeklyGoalReps : 100;
    final result = await _promptForRepCount(
      title: 'Weekly goal (reps)',
      hint: 'e.g. 100',
      current: current,
    );

    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('custom_weekly_target', result);
      // Only derive a new daily target if the user hasn't set one explicitly.
      // If custom_daily_target exists, leave it untouched — it's their override.
      final hasCustomDaily = prefs.containsKey('custom_daily_target');
      if (!hasCustomDaily) {
        final days = prefs.getInt('onboarding_goal_days') ?? 7;
        final newDaily = (result / days).ceil();
        await prefs.setInt('custom_daily_target', newDaily);
      }
      await _loadData();
    }
  }

  // ── Personal Records ───────────────────────────────────────────────────

  Widget _buildRecordsCard() {
    final bestStreak = _records['bestStreak'] as int? ?? 0;
    final mostReps = _records['mostReps'] as int? ?? 0;
    final bestForm = (_records['bestFormScore'] as double? ?? 0).round();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Color(0xFFEAB308), size: 20),
                const SizedBox(width: 8),
                Text('Personal Records',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _recordItem(
                      '\u{1F525}', '$bestStreak days', 'Best Streak'),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _openMostReps,
                    child: _recordItem(
                        '\u{1F4AA}', '$mostReps reps', 'Most Reps'),
                  ),
                ),
                Expanded(
                  child: _recordItem(
                      '\u{2B50}', '$bestForm%', 'Best Form'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label,
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  // ── Workout Buttons ───────────────────────────────────────────────────

  Future<void> _launchWorkout({String exercise = 'Push-ups', bool setup = false}) async {
    // Request camera permission before navigating — so iOS shows the dialog
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isPermanentlyDenied) {
      // User has permanently denied — show a dialog pointing them to settings
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Camera Access Required'),
          content: const Text(
            'Rep AI needs camera access to count your reps.\n\n'
            'Go to: Settings → Privacy & Security → Camera → Rep AI, then toggle it on.',
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
    context.read<WorkoutState>().startSession(exercise: exercise);
    if (setup) {
      Navigator.pushNamed(context, '/setup').then((_) => _loadData());
    } else {
      Navigator.pushNamed(context, '/workout').then((_) => _loadData());
    }
  }

  Widget _buildWorkoutButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => _launchWorkout(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
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
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () => _launchWorkout(setup: true),
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
    );
  }

  // ── Session Cards ─────────────────────────────────────────────────────

  Widget _buildSessionCard(WorkoutSession session) {
    final theme = Theme.of(context);
    final dateStr =
        DateFormat('MMM d, yyyy - h:mm a').format(session.startedAt);
    final formColor = session.formScore >= 80
        ? const Color(0xFF16A34A)
        : session.formScore >= 50
            ? const Color(0xFFEA580C)
            : const Color(0xFFDC2626);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: formColor.withValues(alpha: 0.1),
              ),
              child: Center(
                child: Text('${session.formScore.round()}%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: formColor)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      session.exercise,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.headlineLarge?.color)),
                  const SizedBox(height: 2),
                  Text(
                    '${session.totalReps} reps  \u00b7  ${_formatDuration(session.duration)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
}



// ── Rep Breakdown Screen ────────────────────────────────────────────────

class _RepBreakdownScreen extends StatelessWidget {
  final Map<String, int> repsByPeriod;

  const _RepBreakdownScreen({required this.repsByPeriod});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      ('Today', repsByPeriod['today'] ?? 0, const Color(0xFF2563EB)),
      ('This Week', repsByPeriod['thisWeek'] ?? 0, const Color(0xFF16A34A)),
      ('This Month', repsByPeriod['thisMonth'] ?? 0, const Color(0xFF7C3AED)),
      ('This Year', repsByPeriod['thisYear'] ?? 0, const Color(0xFFEA580C)),
      ('All Time', repsByPeriod['allTime'] ?? 0, const Color(0xFF64748B)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Rep Breakdown')),
      body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (label, count, color) = items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(' reps', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          );
        },
      ),
      ),
      ),
    );
  }
}

// ── Goal Breakdown Screen ───────────────────────────────────────────────

class _GoalBreakdownScreen extends StatefulWidget {
  final int target;
  final String period; // 'weekly' or 'monthly'

  const _GoalBreakdownScreen({required this.target, required this.period});

  @override
  State<_GoalBreakdownScreen> createState() => _GoalBreakdownScreenState();
}

class _GoalBreakdownScreenState extends State<_GoalBreakdownScreen> {
  late List<int> _values;
  late List<String> _labels;

  @override
  void initState() {
    super.initState();
    if (widget.period == 'weekly') {
      _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final perDay = widget.target ~/ 7;
      final remainder = widget.target % 7;
      _values = List.generate(7, (i) => perDay + (i < remainder ? 1 : 0));
    } else {
      _labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
      final perWeek = widget.target ~/ 4;
      final remainder = widget.target % 4;
      _values = List.generate(4, (i) => perWeek + (i < remainder ? 1 : 0));
    }
  }


  int get _total => _values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeekly = widget.period == 'weekly';
    final totalMatch = _total == widget.target;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(isWeekly ? 'Daily Breakdown' : 'Weekly Breakdown'),
      ),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            Center(
              child: Text(
                '${widget.target} reps ${isWeekly ? 'this week' : 'this month'}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                totalMatch
                    ? 'Total matches target'
                    : 'Total: $_total / ${widget.target}',
                style: TextStyle(
                  fontSize: 13,
                  color: totalMatch
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(
              _values.length,
              (i) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(_labels[i],
                            style: theme.textTheme.titleMedium),
                      ),
                      const Spacer(),
                      TappableNumber(
                        value: _values[i],
                        min: 0,
                        max: widget.target,
                        step: 5,
                        fontSize: 18,
                        onChanged: (v) => setState(() => _values[i] = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _values.join(','));
                },
                child: const Text('Save Breakdown',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
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

// ── In-app numeric keypad (used on iPad) ─────────────────────────────────────
// Shown inside the daily/weekly goal bottom sheet on iPad, where iOS would
// otherwise pop a tiny floating numeric keyboard in the corner.

class _InAppNumericKeypad extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;

  const _InAppNumericKeypad({
    required this.controller,
    this.maxLength = 5,
  });

  void _append(String digit) {
    final text = controller.text;
    if (text.length >= maxLength) return;
    // Avoid leading zeros (so "0" + "5" doesn't become "05").
    final next = (text == '0') ? digit : '$text$digit';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _backspace() {
    final text = controller.text;
    if (text.isEmpty) return;
    final next = text.substring(0, text.length - 1);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _clear() {
    controller.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
  }

  Widget _key(BuildContext context, {required Widget child, required VoidCallback onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: onTap,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _digitKey(BuildContext context, String d) =>
      _key(context, onTap: () => _append(d), child: Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)));

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [_digitKey(context, '1'), _digitKey(context, '2'), _digitKey(context, '3')]),
          Row(children: [_digitKey(context, '4'), _digitKey(context, '5'), _digitKey(context, '6')]),
          Row(children: [_digitKey(context, '7'), _digitKey(context, '8'), _digitKey(context, '9')]),
          Row(children: [
            _key(context, onTap: _clear, child: const Text('C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
            _digitKey(context, '0'),
            _key(context, onTap: _backspace, child: const Icon(Icons.backspace_outlined)),
          ]),
        ],
      ),
    );
  }
}
