/// Stats Detail Screens
/// =====================
/// Interactive detail views for tapping stats on the home screen.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/workout_models.dart';

/// Shows all workout days with rep counts, sorted most recent first.
class TotalRepsDetailScreen extends StatelessWidget {
  final List<WorkoutSession> sessions;

  const TotalRepsDetailScreen({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    // Group sessions by date
    final byDate = <String, int>{};
    final dateKeys = <String, DateTime>{};
    for (final s in sessions) {
      final key = DateFormat('yyyy-MM-dd').format(s.startedAt);
      byDate[key] = (byDate[key] ?? 0) + s.goodFormReps;
      dateKeys[key] = DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day);
    }
    final sorted = byDate.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      appBar: AppBar(title: const Text('Reps by Day')),
      body: sorted.isEmpty
          ? const Center(child: Text('No workouts yet'))
          : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final entry = sorted[i];
                final date = dateKeys[entry.key]!;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${entry.value}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB))),
                      ),
                    ),
                    title: Text(DateFormat('EEE d MMM').format(date),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${entry.value} reps'),
                  ),
                );
              },
            ),
            ),
            ),
    );
  }
}

/// Shows workouts ranked by rep count — personal leaderboard.
class MostRepsDetailScreen extends StatelessWidget {
  final List<WorkoutSession> sessions;

  const MostRepsDetailScreen({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final ranked = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => b.goodFormReps.compareTo(a.goodFormReps));

    return Scaffold(
      appBar: AppBar(title: const Text('Rep Leaderboard')),
      body: ranked.isEmpty
          ? const Center(child: Text('No workouts yet'))
          : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ranked.length,
              itemBuilder: (context, i) {
                final s = ranked[i];
                final medal = i == 0
                    ? '\u{1F947}'
                    : i == 1
                        ? '\u{1F948}'
                        : i == 2
                            ? '\u{1F949}'
                            : '#${i + 1}';
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: SizedBox(
                      width: 40,
                      child: Center(
                        child: Text(medal,
                            style: TextStyle(
                                fontSize: i < 3 ? 24 : 16,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                    title: Text('${s.goodFormReps} reps',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    subtitle: Text(
                        DateFormat('EEE d MMM - h:mm a').format(s.startedAt)),
                    trailing: Text('${s.formScore.round()}%',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: s.formScore >= 80
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEA580C))),
                  ),
                );
              },
            ),
            ),
            ),
    );
  }
}

/// Shows workout details for a specific calendar day.
class CalendarDayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<WorkoutSession> sessions;

  const CalendarDayDetailSheet(
      {super.key, required this.date, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daySessions = sessions
        .where((s) =>
            s.startedAt.year == date.year &&
            s.startedAt.month == date.month &&
            s.startedAt.day == date.day)
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final totalReps =
        daySessions.fold<int>(0, (sum, s) => sum + s.goodFormReps);
    final totalDuration = daySessions.fold<Duration>(
        Duration.zero, (sum, s) => sum + s.duration);
    final avgForm = daySessions.isEmpty
        ? 0.0
        : daySessions.fold<double>(0, (sum, s) => sum + s.formScore) /
            daySessions.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(DateFormat('EEEE, d MMMM').format(date),
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _dayStat('$totalReps', 'Reps', const Color(0xFF2563EB)),
                  _dayStat('${avgForm.round()}%', 'Form',
                      const Color(0xFF16A34A)),
                  _dayStat(_fmtDuration(totalDuration), 'Time',
                      const Color(0xFF7C3AED)),
                ],
              ),
              if (daySessions.length > 1) ...[
                const SizedBox(height: 20),
                Text('${daySessions.length} Sessions',
                    style: theme.textTheme.titleMedium),
              ],
              const SizedBox(height: 12),
              ...daySessions.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              theme.dividerColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              DateFormat('h:mm a').format(s.startedAt),
                              style: theme.textTheme.bodyMedium),
                        ),
                        Text('${s.goodFormReps} reps',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        Text('${s.formScore.round()}%',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: s.formScore >= 80
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFEA580C))),
                        const SizedBox(width: 12),
                        Text(_fmtDuration(s.duration),
                            style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  )),
            ],
          ),
          ),
          ),
        );
      },
    );
  }

  Widget _dayStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  String _fmtDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
}
