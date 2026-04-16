/// Workout Setup Screen
/// =====================
/// Configure custom workout: sets, reps per set, rest time.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/workout_state.dart';
import '../widgets/tappable_number.dart';

class WorkoutSetupScreen extends StatefulWidget {
  const WorkoutSetupScreen({super.key});

  @override
  State<WorkoutSetupScreen> createState() => _WorkoutSetupScreenState();
}

class _WorkoutSetupScreenState extends State<WorkoutSetupScreen> {
  int _sets = 3;
  int _reps = 10;
  int _rest = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Custom Workout')),
      body: SafeArea(
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text('Configure Your Workout',
                        style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 32),
                    _buildCounter(
                      label: 'Sets',
                      value: _sets,
                      min: 1,
                      max: 20,
                      onChanged: (v) => setState(() => _sets = v),
                    ),
                    const SizedBox(height: 24),
                    _buildCounter(
                      label: 'Reps per Set',
                      value: _reps,
                      min: 1,
                      max: 100,
                      onChanged: (v) => setState(() => _reps = v),
                    ),
                    const SizedBox(height: 24),
                    _buildCounter(
                      label: 'Rest (seconds)',
                      value: _rest,
                      min: 10,
                      max: 300,
                      step: 10,
                      onChanged: (v) => setState(() => _rest = v),
                    ),
                    const SizedBox(height: 32),
                    // Summary
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text('Workout Summary',
                                style: theme.textTheme.titleMedium),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _summaryItem('$_sets', 'sets'),
                                _summaryItem('${_sets * _reps}',
                                    'total reps'),
                                _summaryItem(
                                    '~${((_sets * _reps * 3 + (_sets - 1) * _rest) / 60).ceil()}',
                                    'min'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Start button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<WorkoutState>().startCustomSession(
                          sets: _sets,
                          reps: _reps,
                          restSeconds: _rest,
                        );
                    // Show the form guide before the workout starts.
                    // Pass isCustom=true so the guide skips re-starting the session.
                    Navigator.pushReplacementNamed(
                        context, '/guide',
                        arguments: true);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 24),
                      SizedBox(width: 8),
                      Text('Start Workout',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ],
                  ),
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

  Widget _buildCounter({
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(label, style: theme.textTheme.titleMedium)),
                TappableNumber(
                  value: value,
                  min: min,
                  max: max,
                  step: step,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tap the number to type a custom value',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB))),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
