/// Database Service
/// =================
/// SQLite database for persisting workout history and streak data.
library;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/workout_models.dart';

class DatabaseService {
  Database? _database;

  Future<void> initialize() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    if (kIsWeb) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rep_counter.db');

    _database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE workout_sessions (
            id TEXT PRIMARY KEY,
            exercise TEXT NOT NULL,
            total_reps INTEGER NOT NULL,
            good_form_reps INTEGER NOT NULL,
            bad_form_reps INTEGER NOT NULL,
            duration_seconds INTEGER NOT NULL,
            started_at TEXT NOT NULL,
            form_issues TEXT DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE streak_data (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            current_streak INTEGER NOT NULL DEFAULT 0,
            last_workout_date TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.insert('streak_data', {
          'id': 1,
          'current_streak': 0,
          'last_workout_date': '',
        });
        await db.execute('''
          CREATE TABLE goals (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            target INTEGER NOT NULL DEFAULT 0,
            period TEXT NOT NULL DEFAULT 'weekly',
            breakdown TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.execute('''
          CREATE TABLE badges (
            id TEXT PRIMARY KEY,
            earned_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE goal_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target INTEGER NOT NULL,
            period TEXT NOT NULL,
            completed_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 5) {
          try {
            await db.execute("ALTER TABLE goals ADD COLUMN breakdown TEXT NOT NULL DEFAULT ''");
          } catch (_) {} // column may already exist
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS badges (
              id TEXT PRIMARY KEY,
              earned_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS goal_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              target INTEGER NOT NULL,
              period TEXT NOT NULL,
              completed_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS goals (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              target INTEGER NOT NULL DEFAULT 0,
              period TEXT NOT NULL DEFAULT 'weekly'
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS badges (
              id TEXT PRIMARY KEY,
              earned_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS goal_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              target INTEGER NOT NULL,
              period TEXT NOT NULL,
              completed_at TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS streak_data (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              current_streak INTEGER NOT NULL DEFAULT 0,
              last_workout_date TEXT NOT NULL DEFAULT ''
            )
          ''');
          final rows = await db.query('streak_data');
          if (rows.isEmpty) {
            await db.insert('streak_data', {
              'id': 1,
              'current_streak': 0,
              'last_workout_date': '',
            });
          }
        }
      },
    );
  }

  // ── Streak ──────────────────────────────────────────────────────────────

  /// Update streak after a workout is saved. Call this after saveSession.
  Future<void> updateStreak() async {
    if (_database == null) return;

    final rows = await _database!.query('streak_data', where: 'id = 1');
    if (rows.isEmpty) return;

    final todayStr = _dateOnly(DateTime.now());
    final lastDate = rows.first['last_workout_date'] as String;
    final currentStreak = rows.first['current_streak'] as int;

    if (lastDate == todayStr) return; // Already worked out today

    final yesterdayStr = _dateOnly(DateTime.now().subtract(const Duration(days: 1)));
    final newStreak = (lastDate == yesterdayStr) ? currentStreak + 1 : 1;

    await _database!.update(
      'streak_data',
      {'current_streak': newStreak, 'last_workout_date': todayStr},
      where: 'id = 1',
    );
  }

  /// Resets streak to 0 if the last workout was before yesterday (stale streak).
  /// Call on app load / home screen refresh.
  Future<void> checkAndResetStaleStreak() async {
    if (_database == null) return;
    final rows = await _database!.query('streak_data', where: 'id = 1');
    if (rows.isEmpty) return;
    final lastDate = rows.first['last_workout_date'] as String;
    final currentStreak = rows.first['current_streak'] as int;
    if (currentStreak == 0) return; // Nothing to reset

    final yesterdayStr = _dateOnly(DateTime.now().subtract(const Duration(days: 1)));
    final todayStr = _dateOnly(DateTime.now());
    // If last workout was neither today nor yesterday, the streak is broken
    if (lastDate != todayStr && lastDate != yesterdayStr) {
      await _database!.update(
        'streak_data',
        {'current_streak': 0},
        where: 'id = 1',
      );
    }
  }

  /// Returns {currentStreak: int, lastWorkoutDate: String}
  Future<Map<String, dynamic>> getStreakData() async {
    if (_database == null) return {'currentStreak': 0, 'lastWorkoutDate': ''};

    final rows = await _database!.query('streak_data', where: 'id = 1');
    if (rows.isEmpty) return {'currentStreak': 0, 'lastWorkoutDate': ''};

    return {
      'currentStreak': rows.first['current_streak'] as int,
      'lastWorkoutDate': rows.first['last_workout_date'] as String,
    };
  }

  // ── Goals ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGoal() async {
    if (_database == null) return {'target': 0, 'period': 'weekly', 'breakdown': ''};
    final rows = await _database!.query('goals', where: 'id = 1');
    if (rows.isEmpty) return {'target': 0, 'period': 'weekly', 'breakdown': ''};
    return {
      'target': rows.first['target'] as int,
      'period': rows.first['period'] as String,
      'breakdown': (rows.first['breakdown'] as String?) ?? '',
    };
  }

  Future<void> saveGoal(int target, String period, {String breakdown = ''}) async {
    if (_database == null) return;
    await _database!.insert(
      'goals',
      {'id': 1, 'target': target, 'period': period, 'breakdown': breakdown},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Badges ─────────────────────────────────────────────────────────────

  Future<Set<String>> getEarnedBadges() async {
    if (_database == null) return {};
    final rows = await _database!.query('badges');
    return rows.map((r) => r['id'] as String).toSet();
  }

  Future<Map<String, String>> getEarnedBadgeDates() async {
    if (_database == null) return {};
    final rows = await _database!.query('badges');
    return {for (final r in rows) r['id'] as String: r['earned_at'] as String};
  }

  Future<void> earnBadge(String id) async {
    if (_database == null) return;
    await _database!.insert('badges', {
      'id': id,
      'earned_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> saveGoalCompletion(int target, String period) async {
    if (_database == null) return;
    await _database!.insert('goal_history', {
      'target': target,
      'period': period,
      'completed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> getGoalCompletionCount() async {
    if (_database == null) return 0;
    final rows = await _database!.query('goal_history');
    return rows.length;
  }

  /// Check and award badges based on current stats.
  Future<List<String>> checkAndAwardBadges() async {
    final earned = await getEarnedBadges();
    final newBadges = <String>[];
    final sessions = await getAllSessions();
    final records = await getPersonalRecords();
    final goalCount = await getGoalCompletionCount();

    // First Workout
    if (!earned.contains('first_workout') && sessions.isNotEmpty) {
      await earnBadge('first_workout');
      newBadges.add('first_workout');
    }

    // Week Warrior — 7 day streak
    final bestStreak = records['bestStreak'] as int? ?? 0;
    if (!earned.contains('week_warrior') && bestStreak >= 7) {
      await earnBadge('week_warrior');
      newBadges.add('week_warrior');
    }

    // Century Club — 100 total good reps
    int totalGood = 0;
    for (final s in sessions) {
      totalGood += s.goodFormReps;
    }
    if (!earned.contains('century_club') && totalGood >= 100) {
      await earnBadge('century_club');
      newBadges.add('century_club');
    }

    // Perfect Form — 100% form with 10+ reps
    if (!earned.contains('perfect_form')) {
      for (final s in sessions) {
        if (s.totalReps >= 10 && s.goodFormReps == s.totalReps) {
          await earnBadge('perfect_form');
          newBadges.add('perfect_form');
          break;
        }
      }
    }

    // Consistent — 30 day streak
    if (!earned.contains('consistent') && bestStreak >= 30) {
      await earnBadge('consistent');
      newBadges.add('consistent');
    }

    // Goal Crusher — 5 completed goals
    if (!earned.contains('goal_crusher') && goalCount >= 5) {
      await earnBadge('goal_crusher');
      newBadges.add('goal_crusher');
    }

    return newBadges;
  }

  String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Returns personal records: {bestStreak, mostReps, bestFormScore}
  Future<Map<String, dynamic>> getPersonalRecords() async {
    if (_database == null) {
      return {'bestStreak': 0, 'mostReps': 0, 'bestFormScore': 0.0};
    }

    // Best streak: compute from all workout dates
    final dates = await getWorkoutDates();
    int bestStreak = 0;
    if (dates.isNotEmpty) {
      final sorted = dates.toList()..sort();
      int current = 1;
      for (int i = 1; i < sorted.length; i++) {
        if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
          current++;
        } else {
          current = 1;
        }
        if (current > bestStreak) bestStreak = current;
      }
      if (current > bestStreak) bestStreak = current;
    }

    // Most reps and best form from sessions
    final sessions = await getAllSessions();
    int mostReps = 0;
    double bestForm = 0;
    for (final s in sessions) {
      if (s.goodFormReps > mostReps) mostReps = s.goodFormReps;
      if (s.formScore > bestForm) bestForm = s.formScore;
    }

    return {
      'bestStreak': bestStreak,
      'mostReps': mostReps,
      'bestFormScore': bestForm,
    };
  }

  /// Returns rep counts by time period: today, thisWeek, thisMonth, thisYear, allTime.
  Future<Map<String, int>> getRepsByPeriod() async {
    final all = await getAllSessions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekday = now.weekday; // 1=Mon, 7=Sun
    final monday = today.subtract(Duration(days: weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int todayReps = 0, weekReps = 0, monthReps = 0, yearReps = 0, allReps = 0;
    for (final s in all) {
      final d = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
      final reps = s.goodFormReps;
      allReps += reps;
      if (!d.isBefore(yearStart)) yearReps += reps;
      if (!d.isBefore(monthStart)) monthReps += reps;
      if (!d.isBefore(monday)) weekReps += reps;
      if (d == today) todayReps += reps;
    }
    return {
      'today': todayReps,
      'thisWeek': weekReps,
      'thisMonth': monthReps,
      'thisYear': yearReps,
      'allTime': allReps,
    };
  }

  /// Returns all dates (as DateTime, date-only) that had at least one workout.
  Future<Set<DateTime>> getWorkoutDates() async {
    if (_database == null) return {};
    final maps = await _database!.query('workout_sessions', columns: ['started_at']);
    final dates = <DateTime>{};
    for (final m in maps) {
      final dt = DateTime.parse(m['started_at'] as String);
      dates.add(DateTime(dt.year, dt.month, dt.day));
    }
    return dates;
  }

  // ── Sessions ────────────────────────────────────────────────────────────

  Future<void> saveSession(WorkoutSession session) async {
    if (_database == null) return;
    await _database!.insert('workout_sessions', session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    if (_database == null) return [];
    final maps = await _database!.query('workout_sessions', orderBy: 'started_at DESC');
    return maps.map((m) => WorkoutSession.fromMap(m)).toList();
  }

  Future<List<WorkoutSession>> getRecentSessions({int limit = 10}) async {
    if (_database == null) return [];
    final maps = await _database!.query('workout_sessions', orderBy: 'started_at DESC', limit: limit);
    return maps.map((m) => WorkoutSession.fromMap(m)).toList();
  }

  Future<List<WorkoutSession>> getSessionsByExercise(String exercise) async {
    if (_database == null) return [];
    final maps = await _database!.query('workout_sessions',
        where: 'exercise = ?', whereArgs: [exercise], orderBy: 'started_at DESC');
    return maps.map((m) => WorkoutSession.fromMap(m)).toList();
  }

  Future<Map<String, dynamic>> getOverallStats() async {
    final sessions = await getAllSessions();
    int totalReps = 0, totalGoodReps = 0, totalSeconds = 0;
    for (final s in sessions) {
      totalReps += s.totalReps;
      totalGoodReps += s.goodFormReps;
      totalSeconds += s.duration.inSeconds;
    }
    return {
      'totalSessions': sessions.length,
      'totalReps': totalReps,
      'totalGoodReps': totalGoodReps,
      'averageFormScore': totalReps > 0 ? (totalGoodReps / totalReps * 100).round() : 0,
      'totalMinutes': (totalSeconds / 60).round(),
    };
  }

  Future<List<WorkoutSession>> getSessionsLastDays(int days) async {
    if (_database == null) return [];
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final maps = await _database!.query('workout_sessions',
        where: 'started_at > ?', whereArgs: [cutoff.toIso8601String()], orderBy: 'started_at ASC');
    return maps.map((m) => WorkoutSession.fromMap(m)).toList();
  }

  Future<void> deleteSession(String id) async {
    if (_database == null) return;
    await _database!.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns monthly rep totals for all months that have session data.
  /// Each item: {year, month, totalReps}
  Future<List<Map<String, dynamic>>> getMonthlyRepTotals() async {
    if (_database == null) return [];
    final maps = await _database!.query(
      'workout_sessions',
      columns: ['started_at', 'good_form_reps'],
      orderBy: 'started_at ASC',
    );
    final totals = <String, int>{};
    for (final m in maps) {
      final dt = DateTime.parse(m['started_at'] as String);
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      totals[key] = (totals[key] ?? 0) + (m['good_form_reps'] as int);
    }
    return totals.entries.map((e) {
      final parts = e.key.split('-');
      return {
        'year': int.parse(parts[0]),
        'month': int.parse(parts[1]),
        'totalReps': e.value,
      };
    }).toList();
  }

  /// Returns sessions in a date range [start, end).
  Future<List<WorkoutSession>> getSessionsByDateRange(
      DateTime start, DateTime end) async {
    if (_database == null) return [];
    final maps = await _database!.query(
      'workout_sessions',
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'started_at ASC',
    );
    return maps.map((m) => WorkoutSession.fromMap(m)).toList();
  }

  /// Delete all local workout history, streak, goals, badges, and goal history.
  Future<void> deleteAllLocalData() async {
    if (_database == null) return;
    await _database!.delete('workout_sessions');
    await _database!.update('streak_data', {
      'current_streak': 0,
      'last_workout_date': '',
    }, where: 'id = 1');
    await _database!.delete('goals');
    await _database!.delete('badges');
    await _database!.delete('goal_history');
  }

  Future<void> close() async {
    await _database?.close();
  }
}
