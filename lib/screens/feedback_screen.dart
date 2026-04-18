/// Feedback Screen
/// ===============
/// Anonymous feedback submission to Firestore. Stores only: type, message,
/// and a server timestamp. No user identifiers or device info collected.
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum FeedbackType { featureRequest, bugReport }

class FeedbackScreen extends StatefulWidget {
  final FeedbackType type;

  const FeedbackScreen({super.key, required this.type});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _title =>
      widget.type == FeedbackType.featureRequest ? 'Feature Request' : 'Report an Issue';

  String get _hint => widget.type == FeedbackType.featureRequest
      ? 'Describe the feature you\'d like to see…'
      : 'Describe the issue you encountered…';

  String get _typeKey => widget.type == FeedbackType.featureRequest
      ? 'feature_request'
      : 'bug_report';

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'type': _typeKey,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() { _sending = false; _sent = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send feedback. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _sent ? _buildSuccess(theme) : _buildForm(theme),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.type == FeedbackType.featureRequest
                ? 'Have an idea? Share it — all feedback is anonymous and appreciated.'
                : 'Something not working? Let us know — all feedback is anonymous.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrl,
            minLines: 5,
            maxLines: 12,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _hint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your feedback is anonymous. We only store the message and feedback type — no account, device, or personal information.',
            style: TextStyle(fontSize: 12, color: theme.hintColor),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (_sending || _ctrl.text.trim().isEmpty) ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          // Re-listen so the button enables when text is non-empty
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctrl,
            builder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 40, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 24),
          Text(
            'Thanks for the feedback!',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your message has been sent. We read every submission and use it to improve the app.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Done',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type chooser ─────────────────────────────────────────────────────────────

/// Shows a bottom sheet asking Feature Request vs Report Issue, then pushes
/// the appropriate FeedbackScreen. Call this from Settings.
Future<void> showFeedbackChooser(BuildContext context) async {
  final type = await showModalBottomSheet<FeedbackType>(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      final handle = isDark ? Colors.white24 : const Color(0xFFCBD5E1);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: handle,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Send Feedback',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('What would you like to share?',
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),
              _FeedbackOption(
                icon: Icons.lightbulb_outline_rounded,
                color: const Color(0xFF7C3AED),
                label: 'Feature Request',
                subtitle: "Suggest something you'd like to see",
                onTap: () => Navigator.pop(ctx, FeedbackType.featureRequest),
              ),
              const SizedBox(height: 10),
              _FeedbackOption(
                icon: Icons.bug_report_outlined,
                color: const Color(0xFFDC2626),
                label: 'Report an Issue',
                subtitle: "Tell us what's not working",
                onTap: () => Navigator.pop(ctx, FeedbackType.bugReport),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );

  if (type == null || !context.mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute<void>(
        builder: (_) => FeedbackScreen(type: type)),
  );
}

class _FeedbackOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _FeedbackOption({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
      trailing: const Icon(Icons.chevron_right),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
