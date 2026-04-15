/// Settings Screen
/// ================
/// Theme toggle and app settings.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _goalsEnabled = true;
  int _weekStartDay = 1; // 1=Mon … 7=Sun (matches DateTime.weekday)

  static const _dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _goalsEnabled = prefs.getBool('goals_enabled') ?? true;
      _weekStartDay = prefs.getInt('week_start_day') ?? 1;
    });
  }

  Future<void> _setGoalsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('goals_enabled', value);
    setState(() => _goalsEnabled = value);
  }

  Future<void> _setWeekStartDay(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('week_start_day', value);
    setState(() => _weekStartDay = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Goals ────────────────────────────────────────────────────
          Text('Goals', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _goalsEnabled,
            onChanged: _setGoalsEnabled,
            title: const Text('Enable goals'),
            subtitle: const Text('Track daily and weekly rep targets'),
            activeThumbColor: const Color(0xFF2563EB),
            activeTrackColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Week starts on'),
            subtitle: Text(_dayNames[_weekStartDay - 1]),
            trailing: DropdownButton<int>(
              value: _weekStartDay,
              underline: const SizedBox.shrink(),
              onChanged: (v) { if (v != null) _setWeekStartDay(v); },
              items: List.generate(7, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_dayNames[i]),
              )),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 24),

          // ── Theme ─────────────────────────────────────────────────────
          Text('Theme', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _themeTile(context, themeProvider, 'System Default',
              ThemeMode.system, Icons.brightness_auto),
          _themeTile(context, themeProvider, 'Light', ThemeMode.light,
              Icons.light_mode),
          _themeTile(context, themeProvider, 'Dark', ThemeMode.dark,
              Icons.dark_mode),

          const SizedBox(height: 24),

          // ── FAQ ───────────────────────────────────────────────────────
          Text('FAQ', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._faq.map((qa) => _faqTile(qa.$1, qa.$2)),
        ],
      ),
      ),
      ),
    );
  }

  // ── FAQ data ──────────────────────────────────────────────────────────
  static const List<(String, String)> _faq = [
    (
      'How fast should I do reps?',
      'Perform controlled reps at a steady pace. Very fast reps may not always be detected — think of it as encouragement to focus on quality over speed.',
    ),
    (
      'Why wasn\'t my rep counted?',
      'Rep AI only counts reps it detects as good form. If a rep wasn\'t counted, try slowing down, going lower, or keeping your body straighter.',
    ),
    (
      'Is the tracking 100% accurate?',
      'Rep AI is a training tool to help you stay consistent and improve over time. It works best with standard push-ups and good lighting. Accuracy may vary with different variations and setups.',
    ),
    (
      'Does it work with other exercises?',
      'Currently Rep AI supports push-ups including several variations. More exercises are coming in future updates.',
    ),
    (
      'Can I use it without looking at the screen?',
      'Yes — you\'ll hear a ding sound for each good rep and feel a vibration so you don\'t need to watch the screen.',
    ),
  ];

  Widget _faqTile(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeTile(BuildContext context, ThemeProvider themeProvider,
      String label, ThemeMode mode, IconData icon) {
    final selected = themeProvider.mode == mode;
    return ListTile(
      leading: Icon(icon,
          color: selected ? const Color(0xFF2563EB) : null),
      title: Text(label,
          style: TextStyle(
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w400)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF2563EB))
          : null,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () => themeProvider.setMode(mode),
    );
  }
}
