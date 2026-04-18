/// What's New Screen
/// =================
/// Shows a changelog popup once per app version and is also accessible
/// on demand via the news icon on the home screen.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Changelog data ────────────────────────────────────────────────────────────

class _ChangeEntry {
  final String version;
  final List<(String, List<String>)> groups; // (groupTitle, bullets)

  const _ChangeEntry({required this.version, required this.groups});
}

const _changelog = <_ChangeEntry>[
  _ChangeEntry(
    version: '2.3.0',
    groups: [
      (
        'Bad Form Screenshot',
        [
          'Worst form moment from your workout is now captured',
          'See exactly where your form broke down after each session',
          'All processing stays on your device, nothing is uploaded',
        ],
      ),
      (
        'How To Animations',
        [
          'New setup guide before each workout',
          'Clean animations showing exactly how to do each push up variation',
          'Covers standard, wide grip, diamond, knee, pike and decline',
        ],
      ),
      (
        'General',
        [
          'Some UI changes',
        ],
      ),
    ],
  ),
  _ChangeEntry(
    version: '2.2.0',
    groups: [
      (
        'Specific Form Feedback',
        [
          'Bad reps are now explained',
          'Form tips during your workout',
          'Form issue summary shown after each session',
        ],
      ),
    ],
  ),
  _ChangeEntry(
    version: '2.1.0',
    groups: [
      (
        'Onboarding & Goals',
        [
          'New onboarding to get you set up in under a minute',
          'Pick your fitness level',
          'Choose which days you train',
          'Improved daily and weekly rep goals',
          'Workout history now updates automatically after every session',
        ],
      ),
    ],
  ),
];

// ── Public API ─────────────────────────────────────────────────────────────────

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  // The version string checked against SharedPreferences.
  static const String _currentVersion = '2.6.0';
  static const String _prefKey = 'whats_new_last_seen';

  /// Call from the home shell after the first frame to show the popup once.
  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeen = prefs.getString(_prefKey) ?? '';
    if (lastSeen == _currentVersion) return;

    if (!context.mounted) return;
    await _show(context);
    await prefs.setString(_prefKey, _currentVersion);
  }

  /// Open on demand (from the news icon button).
  static Future<void> showOnDemand(BuildContext context) => _show(context);

  static Future<void> _show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _WhatsNewSheet(),
    );
  }

  /// Full-screen route version (navigation target).
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text("What's New")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildContent(theme),
        ),
      ),
    );
  }

  static Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        for (final entry in _changelog) ...[
          _VersionBlock(entry: entry),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ── Bottom sheet wrapper ──────────────────────────────────────────────────────

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final handleColor =
        isDark ? Colors.white24 : const Color(0xFFCBD5E1);
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.85),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.new_releases_rounded,
                      size: 22, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's New",
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Recent updates to Rep AI',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ],
            ),
          ),

          const Divider(height: 24, indent: 20, endIndent: 20),

          // Changelog list
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              shrinkWrap: true,
              children: [
                for (final entry in _changelog) ...[
                  _VersionBlock(entry: entry),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Version block ─────────────────────────────────────────────────────────────

class _VersionBlock extends StatelessWidget {
  final _ChangeEntry entry;

  const _VersionBlock({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
        : const Color(0xFFF8FAFC);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Version ${entry.version}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Groups
          for (final (title, bullets) in entry.groups) ...[
            _GroupSection(title: title, bullets: bullets, theme: theme),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final ThemeData theme;

  const _GroupSection({
    required this.title,
    required this.bullets,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: theme.textTheme.titleMedium?.color,
          ),
        ),
        const SizedBox(height: 4),
        for (final bullet in bullets)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    bullet,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
