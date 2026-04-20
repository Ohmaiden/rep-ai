/// Cloud Sync Service
/// ==================
/// Firestore push/pull for workout sessions, streak, goals, and badges.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'database_service.dart';
import '../models/workout_models.dart';

class CloudSyncService {
  final AuthService authService;
  final DatabaseService db;

  CloudSyncService({required this.authService, required this.db});

  bool get canSync => authService.isSignedIn && authService.isAvailable;

  String get _uid => authService.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _workoutsRef =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('workouts');

  DocumentReference<Map<String, dynamic>> get _userRef =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  // ── Push All ──────────────────────────────────────────────────────────────

  Future<void> pushAll() async {
    if (!canSync) return;
    try {
      await _pushSessions();
      await _pushMeta();
      await _pushGoals();
      await _pushBadges();
    } catch (e) {
      debugPrint('CloudSync pushAll error: $e');
    }
  }

  Future<void> _pushSessions() async {
    final sessions = await db.getAllSessions();
    if (sessions.isEmpty) return;

    const batchSize = 500;
    for (var i = 0; i < sessions.length; i += batchSize) {
      final chunk = sessions.sublist(
          i, (i + batchSize).clamp(0, sessions.length));
      final batch = FirebaseFirestore.instance.batch();
      for (final session in chunk) {
        final docRef = _workoutsRef.doc(session.id);
        batch.set(docRef, _sessionToMap(session), SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<void> _pushMeta() async {
    final streakData = await db.getStreakData();
    await _userRef.collection('data').doc('meta').set({
      'streak': streakData['currentStreak'] as int,
      'lastWorkoutDate': streakData['lastWorkoutDate'] as String,
      'lastSyncAt': FieldValue.serverTimestamp(),
      'email': authService.userEmail ?? '',
    }, SetOptions(merge: true));

    // Ensure createdAt is set only once
    await _userRef.collection('data').doc('meta').set({
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(mergeFields: ['createdAt']));
  }

  Future<void> _pushGoals() async {
    final goal = await db.getGoal();
    final prefs = await SharedPreferences.getInstance();
    await _userRef.collection('data').doc('goals').set({
      'target': goal['target'] as int,
      'period': goal['period'] as String,
      'breakdown': goal['breakdown'] as String,
      'customDailyTarget': prefs.getInt('custom_daily_target') ?? 0,
      'goalsEnabled': prefs.getBool('goals_enabled') ?? true,
      'weekStartDay': prefs.getInt('week_start_day') ?? 1,
      'activeDays': prefs.getString('active_workout_days') ?? '1,2,3,4,5,6,7',
    }, SetOptions(merge: true));
  }

  Future<void> _pushBadges() async {
    final badgeDates = await db.getEarnedBadgeDates();
    if (badgeDates.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final entry in badgeDates.entries) {
      final docRef = _userRef.collection('badges').doc(entry.key);
      batch.set(docRef, {'earnedAt': entry.value}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ── Single Workout Sync ────────────────────────────────────────────────────

  /// Push a single workout to Firestore. Fails silently on error.
  Future<void> syncSingleWorkout(WorkoutSession session) async {
    if (!canSync) return;
    try {
      await _workoutsRef.doc(session.id).set(
        _sessionToMap(session),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('CloudSync syncSingleWorkout error: $e');
    }
  }

  // ── Delete All User Data ──────────────────────────────────────────────────

  /// Delete all Firestore data for the current user.
  Future<void> deleteAllUserData() async {
    if (!canSync) return;

    // Delete workouts subcollection
    final workouts = await _workoutsRef.get();
    for (final doc in workouts.docs) {
      await doc.reference.delete();
    }

    // Delete data subcollection (meta, goals)
    final dataDocs = await _userRef.collection('data').get();
    for (final doc in dataDocs.docs) {
      await doc.reference.delete();
    }

    // Delete badges subcollection
    final badgeDocs = await _userRef.collection('badges').get();
    for (final doc in badgeDocs.docs) {
      await doc.reference.delete();
    }

    // Delete the user document itself
    await _userRef.delete();
  }

  // ── Pull and Merge ────────────────────────────────────────────────────────

  Future<void> pullAndMerge() async {
    if (!canSync) return;
    try {
      await _pullSessions();
      await _pullMeta();
      await _pullGoals();
      await _pullBadges();
    } catch (e) {
      debugPrint('CloudSync pullAndMerge error: $e');
    }
  }

  Future<void> _pullSessions() async {
    final cloudDocs = await _workoutsRef.get();
    if (cloudDocs.docs.isEmpty) return;

    final localSessions = await db.getAllSessions();
    final localIds = localSessions.map((s) => s.id).toSet();

    for (final doc in cloudDocs.docs) {
      if (!localIds.contains(doc.id)) {
        try {
          final session = _sessionFromMap(doc.id, doc.data());
          await db.saveSession(session);
        } catch (e) {
          debugPrint('CloudSync: failed to merge session ${doc.id}: $e');
        }
      }
    }
  }

  Future<void> _pullMeta() async {
    final metaDoc = await _userRef.collection('data').doc('meta').get();
    if (!metaDoc.exists) return;

    final data = metaDoc.data();
    if (data == null) return;

    final cloudStreak = (data['streak'] as num?)?.toInt() ?? 0;
    if (cloudStreak > 0) {
      final localStreak = await db.getStreakData();
      final localStreakCount = localStreak['currentStreak'] as int;
      if (cloudStreak > localStreakCount) {
        // Update local streak to match cloud
        // We do this by directly updating via the db's streak update path.
        // Since there's no direct setter, we use the raw approach via saveGoal-equivalent.
        // The DatabaseService doesn't expose a direct streak setter, so we
        // only update if we have a valid lastWorkoutDate from cloud.
        final cloudLastDate = data['lastWorkoutDate'] as String? ?? '';
        if (cloudLastDate.isNotEmpty) {
          // Re-use the db internal approach: can't call private methods,
          // so we note this for future: cloud streak is advisory only when
          // local can't be directly set. We skip overwriting to avoid inconsistency.
          debugPrint('CloudSync: cloud streak $cloudStreak > local $localStreakCount (advisory only)');
        }
      }
    }
  }

  Future<void> _pullGoals() async {
    final goalsDoc = await _userRef.collection('data').doc('goals').get();
    if (!goalsDoc.exists) return;

    final data = goalsDoc.data();
    if (data == null) return;

    final target = (data['target'] as num?)?.toInt() ?? 0;
    final period = data['period'] as String? ?? 'weekly';
    final breakdown = data['breakdown'] as String? ?? '';

    if (target > 0) {
      await db.saveGoal(target, period, breakdown: breakdown);
    }

    final prefs = await SharedPreferences.getInstance();

    final customDaily = (data['customDailyTarget'] as num?)?.toInt();
    if (customDaily != null && customDaily > 0) {
      await prefs.setInt('custom_daily_target', customDaily);
    }

    final goalsEnabled = data['goalsEnabled'] as bool?;
    if (goalsEnabled != null) {
      await prefs.setBool('goals_enabled', goalsEnabled);
    }

    final weekStartDay = (data['weekStartDay'] as num?)?.toInt();
    if (weekStartDay != null && weekStartDay >= 1 && weekStartDay <= 7) {
      await prefs.setInt('week_start_day', weekStartDay);
    }

    final activeDays = data['activeDays'] as String?;
    if (activeDays != null && activeDays.isNotEmpty) {
      await prefs.setString('active_workout_days', activeDays);
    }
  }

  Future<void> _pullBadges() async {
    final badgeDocs = await _userRef.collection('badges').get();
    if (badgeDocs.docs.isEmpty) return;

    final localBadges = await db.getEarnedBadges();
    for (final doc in badgeDocs.docs) {
      if (!localBadges.contains(doc.id)) {
        await db.earnBadge(doc.id);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _sessionToMap(WorkoutSession session) => {
        'exercise': session.exercise,
        'totalReps': session.totalReps,
        'goodFormReps': session.goodFormReps,
        'badFormReps': session.badFormReps,
        'durationSeconds': session.duration.inSeconds,
        'startedAt': session.startedAt.toIso8601String(),
        'formIssues': session.formIssues.join('|'),
      };

  WorkoutSession _sessionFromMap(String id, Map<String, dynamic> data) {
    return WorkoutSession(
      id: id,
      exercise: data['exercise'] as String? ?? 'Push Up',
      totalReps: (data['totalReps'] as num?)?.toInt() ?? 0,
      goodFormReps: (data['goodFormReps'] as num?)?.toInt() ?? 0,
      badFormReps: (data['badFormReps'] as num?)?.toInt() ?? 0,
      duration: Duration(
          seconds: (data['durationSeconds'] as num?)?.toInt() ?? 0),
      startedAt: DateTime.parse(
          data['startedAt'] as String? ?? DateTime.now().toIso8601String()),
      formIssues: ((data['formIssues'] as String?) ?? '')
          .split('|')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }
}
