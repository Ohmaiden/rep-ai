/// History Screen
/// ===============
/// Scrollable month/week calendar views + session list with multi-select delete.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/workout_models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WorkoutSession> _allSessions = [];
  List<Map<String, dynamic>> _monthlyTotals = [];
  bool _loading = true;

  // Calendar view toggle
  bool _weekView = false; // false = month, true = week

  // Multi-select
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = context.read<DatabaseService>();
    final all = await db.getAllSessions();
    final monthly = await db.getMonthlyRepTotals();
    if (!mounted) return;
    setState(() {
      _allSessions = all;
      _monthlyTotals = monthly;
      _loading = false;
    });
  }

  // ── Select mode ─────────────────────────────────────────────────────────

  void _enterSelectMode(String id) {
    setState(() {
      _selectMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final db = context.read<DatabaseService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Sessions?'),
        content: Text('Delete $count session${count == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in _selectedIds) {
      await db.deleteSession(id);
    }
    _exitSelectMode();
    if (!mounted) return;
    await _loadData();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _selectMode
              ? Text('${_selectedIds.length} selected')
              : const Text('Workout History'),
          actions: [
            if (_selectMode) ...[
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.red),
                onPressed: _deleteSelected,
                tooltip: 'Delete selected',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectMode,
              ),
            ] else if (_allSessions.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmClearAll(context),
              ),
          ],
        ),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _allSessions.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom:
                              MediaQuery.of(context).padding.bottom + 80,
                        ),
                        children: [
                          // Calendar section
                          _buildCalendarSection(),
                          const SizedBox(height: 24),

                          // Session list
                          Text(
                            'All Sessions',
                            style:
                                Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          ..._allSessions.map((s) => _buildSessionCard(s)),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // ── Calendar section ──────────────────────────────────────────────────────

  Widget _buildCalendarSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Progress', style: theme.textTheme.headlineMedium),
            const Spacer(),
            _viewToggle(),
          ],
        ),
        const SizedBox(height: 12),
        _weekView ? _buildWeekView() : _buildMonthView(),
      ],
    );
  }

  Widget _viewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleBtn('Month', !_weekView, () => setState(() => _weekView = false)),
          _toggleBtn('Week', _weekView, () => setState(() => _weekView = true)),
        ],
      ),
    );
  }

  Widget _toggleBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : null,
          ),
        ),
      ),
    );
  }

  // ── Month view ─────────────────────────────────────────────────────────────

  Widget _buildMonthView() {
    if (_monthlyTotals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No data yet')),
        ),
      );
    }
    final now = DateTime.now();
    final currentKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Sort descending so most recent is first
    final sorted = List<Map<String, dynamic>>.from(_monthlyTotals)
      ..sort((a, b) {
        final aKey =
            '${a['year']}-${(a['month'] as int).toString().padLeft(2, '0')}';
        final bKey =
            '${b['year']}-${(b['month'] as int).toString().padLeft(2, '0')}';
        return bKey.compareTo(aKey);
      });

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final item = sorted[i];
          final year = item['year'] as int;
          final month = item['month'] as int;
          final reps = item['totalReps'] as int;
          final key =
              '$year-${month.toString().padLeft(2, '0')}';
          final isCurrent = key == currentKey;
          final dt = DateTime(year, month);
          final label = DateFormat('MMM yyyy').format(dt);

          return _monthCard(label, reps, isCurrent);
        },
      ),
    );
  }

  Widget _monthCard(String label, int reps, bool isCurrent) {
    final theme = Theme.of(context);
    return Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF2563EB)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isCurrent ? Colors.white70 : theme.textTheme.bodyMedium?.color,
            ),
          ),
          const Spacer(),
          Text(
            '$reps',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isCurrent ? Colors.white : theme.textTheme.headlineLarge?.color,
            ),
          ),
          Text(
            'reps',
            style: TextStyle(
              fontSize: 12,
              color: isCurrent ? Colors.white60 : theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Week view ─────────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    // Build list of weeks scrollable backwards from current week
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Current week starts on Monday
    final currentMonday = today.subtract(Duration(days: today.weekday - 1));

    // How many weeks of history do we have?
    int weeksToShow = 12;
    if (_allSessions.isNotEmpty) {
      final oldest = _allSessions.last.startedAt;
      final diff = today.difference(DateTime(oldest.year, oldest.month, oldest.day));
      weeksToShow = (diff.inDays ~/ 7) + 2;
      if (weeksToShow < 4) weeksToShow = 4;
    }

    // Build session lookup by date
    final dayTotals = <String, int>{};
    for (final s in _allSessions) {
      final d = s.startedAt;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      dayTotals[key] = (dayTotals[key] ?? 0) + s.goodFormReps;
    }

    final weeks = <DateTime>[];
    for (var i = 0; i < weeksToShow; i++) {
      weeks.add(currentMonday.subtract(Duration(days: i * 7)));
    }

    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: weeks.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) => _weekCard(weeks[i], dayTotals, today),
      ),
    );
  }

  void _showWeekDetail(DateTime monday, Map<String, int> dayTotals) {
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final weekTotal = days.fold<int>(0, (sum, d) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return sum + (dayTotals[key] ?? 0);
    });
    final sunday = monday.add(const Duration(days: 6));
    final rangeLabel =
        '${DateFormat('EEE dd MMM').format(monday)} – ${DateFormat('EEE dd MMM').format(sunday)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  rangeLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$weekTotal reps this week',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                ...days.map((d) {
                  final key =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  final reps = dayTotals[key] ?? 0;
                  final hasReps = reps > 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('EEEE').format(d),
                          style: TextStyle(
                            color: hasReps ? Colors.white : Colors.white38,
                            fontSize: 15,
                            fontWeight: hasReps
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        Text(
                          '$reps rep${reps == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: hasReps
                                ? const Color(0xFF2563EB)
                                : Colors.white24,
                            fontSize: 15,
                            fontWeight: hasReps
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _weekCard(
      DateTime monday, Map<String, int> dayTotals, DateTime today) {
    final theme = Theme.of(context);
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final weekTotal = days.fold<int>(0, (sum, d) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return sum + (dayTotals[key] ?? 0);
    });
    final sunday = monday.add(const Duration(days: 6));
    final isCurrentWeek = monday == today.subtract(Duration(days: today.weekday - 1));
    final maxReps = days.fold<int>(1, (m, d) {
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final v = dayTotals[key] ?? 0;
      return v > m ? v : m;
    });

    return GestureDetector(
      onTap: () => _showWeekDetail(monday, dayTotals),
      child: Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentWeek
            ? const Color(0xFF2563EB)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentWeek
            ? null
            : Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateFormat('d MMM').format(monday)} – ${DateFormat('d MMM').format(sunday)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isCurrentWeek ? Colors.white70 : theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$weekTotal reps',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isCurrentWeek ? Colors.white : theme.textTheme.headlineLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          // Day bars
          Row(
            children: days.map((d) {
              final key =
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              final reps = dayTotals[key] ?? 0;
              final frac = reps > 0 ? (reps / maxReps).clamp(0.1, 1.0) : 0.0;
              final isToday = d == today;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: frac > 0 ? frac : 0.08,
                            child: Container(
                              decoration: BoxDecoration(
                                color: reps > 0
                                    ? (isCurrentWeek
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : const Color(0xFF2563EB))
                                    : (isCurrentWeek
                                        ? Colors.white.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('E').format(d).substring(0, 1),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                          color: isCurrentWeek
                              ? (isToday ? Colors.white : Colors.white60)
                              : (isToday
                                  ? const Color(0xFF2563EB)
                                  : theme.textTheme.bodyMedium?.color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      ),
    );
  }

  // ── Session card with multi-select ────────────────────────────────────────

  Widget _buildSessionCard(WorkoutSession session) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEE, MMM d - h:mm a').format(session.startedAt);
    final formColor = session.formScore >= 80
        ? const Color(0xFF16A34A)
        : session.formScore >= 50
            ? const Color(0xFFEA580C)
            : const Color(0xFFDC2626);
    final isSelected = _selectedIds.contains(session.id);

    return GestureDetector(
      onLongPress: () => _enterSelectMode(session.id),
      onTap: _selectMode ? () => _toggleSelect(session.id) : null,
      child: Dismissible(
        key: Key(session.id),
        direction: _selectMode
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => _deleteSession(session),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: const Color(0xFF2563EB), width: 2)
                : null,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              session.exercise,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    theme.textTheme.headlineLarge?.color,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: formColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${session.formScore.round()}% form',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: formColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(dateStr,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _infoChip(
                                Icons.repeat, '${session.totalReps} reps'),
                            const SizedBox(width: 12),
                            _infoChip(Icons.check_circle,
                                '${session.goodFormReps} good'),
                            const SizedBox(width: 12),
                            _infoChip(Icons.timer,
                                _formatDuration(session.duration)),
                          ],
                        ),
                        if (session.formIssues.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: session.formIssues.map((issue) {
                              return Chip(
                                label: Text(issue,
                                    style:
                                        const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                backgroundColor:
                                    const Color(0xFFFEF2F2),
                                labelStyle: const TextStyle(
                                    color: Color(0xFFDC2626)),
                                side: BorderSide.none,
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No workout history yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a workout to see your progress',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    if (mins > 0) return '${mins}m ${secs}s';
    return '${secs}s';
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final db = context.read<DatabaseService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
            'This will permanently delete all your workout sessions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final s in _allSessions) {
        await db.deleteSession(s.id);
      }
      if (!mounted) return;
      await _loadData();
    }
  }

  Future<void> _deleteSession(WorkoutSession session) async {
    final db = context.read<DatabaseService>();
    await db.deleteSession(session.id);
    if (!mounted) return;
    await _loadData();
  }
}
