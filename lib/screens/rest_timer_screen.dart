/// Rest Timer Screen
/// ==================
/// Countdown timer between sets. Fully responsive.
library;

import 'dart:async';
import 'package:flutter/material.dart';

class RestTimerScreen extends StatefulWidget {
  final int seconds;
  final int nextSet;
  final int totalSets;

  const RestTimerScreen({
    super.key,
    required this.seconds,
    required this.nextSet,
    required this.totalSets,
  });

  @override
  State<RestTimerScreen> createState() => _RestTimerScreenState();
}

class _RestTimerScreenState extends State<RestTimerScreen> {
  late int _remaining;
  late int _total;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _total = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        if (mounted) Navigator.pop(context, true);
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _adjust(int delta) {
    setState(() {
      _remaining = (_remaining + delta).clamp(0, 600);
      if (_remaining > _total) _total = _remaining;
    });
    if (_remaining <= 0) {
      _timer?.cancel();
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mins = (_remaining ~/ 60).toString().padLeft(2, '0');
    final secs = (_remaining % 60).toString().padLeft(2, '0');
    final progress = _total > 0 ? (1.0 - (_remaining / _total)) : 1.0;
    final mq = MediaQuery.of(context);
    final isLand = mq.size.width > mq.size.height;
    final circleSize =
        (isLand ? mq.size.height * 0.35 : mq.size.width * 0.38)
            .clamp(80.0, 180.0);
    final timerFont = circleSize * 0.24;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 32, vertical: isLand ? 8 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Rest', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Set ${widget.nextSet} of ${widget.totalSets} coming up',
                      style: theme.textTheme.bodyLarge,
                    ),
                    SizedBox(height: isLand ? 12 : 32),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _pillButton('-10s', () => _adjust(-10), theme),
                        SizedBox(width: isLand ? 12 : 20),
                        SizedBox(
                          width: circleSize,
                          height: circleSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: isLand ? 4 : 6,
                                  backgroundColor: theme
                                      .colorScheme.surfaceContainerHighest,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                              Text(
                                '$mins:$secs',
                                style: TextStyle(
                                  fontSize: timerFont,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: isLand ? 12 : 20),
                        _pillButton('+10s', () => _adjust(10), theme),
                      ],
                    ),
                    SizedBox(height: isLand ? 12 : 32),
                    SizedBox(
                      width: 110,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () {
                          _timer?.cancel();
                          Navigator.pop(context, true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side:
                              const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: const Text('Skip',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton(String label, VoidCallback onTap, ThemeData theme) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color)),
      ),
    );
  }
}
