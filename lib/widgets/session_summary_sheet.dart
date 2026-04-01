/// Session Summary Sheet
/// ======================
/// Post-workout summary with per-rep and per-set breakdown.
library;

import 'package:flutter/material.dart';
import '../models/workout_models.dart';

class SessionSummarySheet extends StatelessWidget {
  final WorkoutSession session;
  final List<RepResult> repHistory;
  final List<int>? setGoodReps;
  final List<int>? setBadReps;
  final bool newRepRecord;
  final bool newFormRecord;

  const SessionSummarySheet({
    super.key,
    required this.session,
    this.repHistory = const [],
    this.setGoodReps,
    this.setBadReps,
    this.newRepRecord = false,
    this.newFormRecord = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF16213E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : Colors.grey[500];
    final surfaceColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8FAFC);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Text('Workout Complete!',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textColor)),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(session.exercise,
                    style: TextStyle(fontSize: 16, color: subtextColor)),
              ),
              if (newRepRecord || newFormRecord) ...[
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEAB308), Color(0xFFF59E0B)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('\u{1F3C6}',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          newRepRecord && newFormRecord
                              ? 'New Records!'
                              : newRepRecord
                                  ? 'New Rep Record!'
                                  : 'New Form Record!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatColumn('${session.goodFormReps}', 'Good Reps',
                      const Color(0xFF16A34A)),
                  _buildStatColumn('${session.badFormReps}', 'Bad Form',
                      const Color(0xFFDC2626)),
                  _buildStatColumn(_formatDuration(session.duration),
                      'Duration', const Color(0xFF7C3AED)),
                ],
              ),
              const SizedBox(height: 16),

              // Attempts bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center,
                        color: subtextColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${session.totalReps} total attempts  \u00b7  '
                      '${session.goodFormReps} counted',
                      style: TextStyle(fontSize: 14, color: subtextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Per-set breakdown (custom workouts)
              if (setGoodReps != null && setGoodReps!.isNotEmpty) ...[
                Text('Set Breakdown',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const SizedBox(height: 12),
                ...List.generate(setGoodReps!.length, (i) {
                  final good = setGoodReps![i];
                  final bad =
                      (setBadReps != null && i < setBadReps!.length)
                          ? setBadReps![i]
                          : 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text('${i + 1}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Set ${i + 1}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                        ),
                        Text('$good good',
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w600)),
                        if (bad > 0) ...[
                          const SizedBox(width: 12),
                          Text('$bad bad',
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],

              // Per-rep breakdown
              if (repHistory.isNotEmpty) ...[
                Text('Rep Breakdown',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const SizedBox(height: 12),
                ...repHistory.map((rep) => _buildRepCard(rep, isDark)),
                const SizedBox(height: 16),
              ],

              // Areas to improve
              if (session.formIssues.isNotEmpty) ...[
                Text('Areas to Improve',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor)),
                const SizedBox(height: 12),
                ...session.formIssues.map((issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center,
                              color: Color(0xFFEA580C), size: 14),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(issue,
                                style: TextStyle(
                                    fontSize: 14, color: subtextColor)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
              ],

              // Done button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildRepCard(RepResult rep, bool isDark) {
    final isGood = rep.goodForm;
    final color =
        isGood ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final bgColor = isDark
        ? (isGood
            ? const Color(0xFF16A34A).withValues(alpha: 0.1)
            : const Color(0xFFDC2626).withValues(alpha: 0.1))
        : (isGood ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('${rep.repNumber}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isGood ? 'Good form' : 'Form issues',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color)),
                if (!isGood && rep.issues.isNotEmpty)
                  Text(rep.issues.join(', '),
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[600])),
              ],
            ),
          ),
          Icon(isGood ? Icons.check_circle : Icons.cancel,
              color: color, size: 22),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }
}
