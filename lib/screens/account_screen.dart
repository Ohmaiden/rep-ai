/// Account Screen
/// ==============
/// Handles sign-in (Email, Google, Apple) and shows the signed-in profile
/// with a Sync Now button. Cloud sync is entirely optional — the app works
/// fully offline without an account.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  bool _syncing = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setError(String? msg) => setState(() => _errorMessage = msg);

  Future<void> _handleEmailAuth() async {
    final auth = context.read<AuthService>();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _setError('Please enter your email and password.');
      return;
    }
    if (_isSignUp && password.length < 6) {
      _setError('Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        await auth.signUpWithEmail(email, password,
            displayName: _nameCtrl.text.trim().isNotEmpty
                ? _nameCtrl.text.trim()
                : null);
      } else {
        await auth.signInWithEmail(email, password);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _setError(_friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogle() async {
    final auth = context.read<AuthService>();
    setState(() { _loading = true; _errorMessage = null; });
    try {
      await auth.signInWithGoogle();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        _setError(null);
      } else {
        _setError(_friendlyError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleApple() async {
    final auth = context.read<AuthService>();
    setState(() { _loading = true; _errorMessage = null; });
    try {
      await auth.signInWithApple();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled') ||
          msg.contains('AuthorizationErrorCode.canceled')) {
        _setError(null);
      } else {
        // Temporarily show raw error for debugging
        _setError(msg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSyncNow() async {
    final sync = context.read<CloudSyncService>();
    setState(() => _syncing = true);
    try {
      await sync.pushAll();
      await sync.pullAndMerge();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${_friendlyError(e.toString())}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _handleSignOut() async {
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Your data stays on this device. Sign back in any time to re-sync.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: Color(0xFFDC2626)))),
        ],
      ),
    );
    if (confirmed == true) {
      await auth.signOut();
      if (mounted) Navigator.pop(context);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('wrong-password') ||
        raw.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (raw.contains('email-already-in-use')) return 'An account already exists for this email.';
    if (raw.contains('invalid-email')) return 'Please enter a valid email address.';
    if (raw.contains('weak-password')) return 'Password is too weak. Use at least 6 characters.';
    if (raw.contains('network-request-failed')) return 'No internet connection.';
    if (raw.contains('not configured')) return 'Firebase not set up yet.';
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: !auth.isAvailable
                ? _buildNotConfigured(context)
                : auth.isSignedIn
                    ? _buildProfile(context, auth)
                    : _buildSignInForm(context, auth),
          ),
        ),
      ),
    );
  }

  // ── Firebase not configured ───────────────────────────────────────────────

  Widget _buildNotConfigured(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.cloud_off_rounded,
            size: 64, color: theme.textTheme.bodyMedium?.color),
        const SizedBox(height: 20),
        Text('Cloud Sync Not Set Up',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Firebase has not been configured for this build.\n\n'
          'The app works fully offline without an account — '
          'your data is stored locally on this device.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('To enable cloud sync:',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _setupStep('1', 'Create a Firebase project at console.firebase.google.com'),
                _setupStep('2', 'Add Android & iOS apps to the project'),
                _setupStep('3', 'Replace the placeholder google-services.json and GoogleService-Info.plist'),
                _setupStep('4', 'Run: flutterfire configure'),
                _setupStep('5', 'Enable Email, Google & Apple auth in Firebase Console'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _setupStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            margin: const EdgeInsets.only(right: 10, top: 1),
            decoration: const BoxDecoration(
                color: Color(0xFF2563EB), shape: BoxShape.circle),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ── Signed in — Profile view ──────────────────────────────────────────────

  Widget _buildProfile(BuildContext context, AuthService auth) {
    final theme = Theme.of(context);
    final initial = (auth.displayName ?? auth.userEmail ?? '?')[0].toUpperCase();

    return Column(
      children: [
        const SizedBox(height: 24),
        CircleAvatar(
          radius: 36,
          backgroundColor: const Color(0xFF2563EB),
          child: Text(initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 16),
        Text(
          auth.displayName ?? 'Account',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(auth.userEmail ?? '',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_done_rounded,
                  size: 14, color: Color(0xFF16A34A)),
              SizedBox(width: 6),
              Text('Cloud Sync Active',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A))),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Sync Now button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _syncing ? null : _handleSyncNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sync_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Sync Now',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 8),

        // Sign out
        ListTile(
          leading: const Icon(Icons.logout_rounded,
              color: Color(0xFFDC2626)),
          title: const Text('Sign Out',
              style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: _handleSignOut,
        ),
      ],
    );
  }

  // ── Sign-in / Sign-up form ────────────────────────────────────────────────

  Widget _buildSignInForm(BuildContext context, AuthService auth) {
    final theme = Theme.of(context);
    final isIOS = Platform.isIOS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Icon
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.cloud_sync_rounded,
                size: 36, color: Color(0xFF2563EB)),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isSignUp ? 'Create Account' : 'Sync Your Progress',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Keep your workouts, goals, and streaks safe across devices.'
              : 'Sign in to keep your workouts, goals, and streaks safe across devices.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Apple Sign In (iOS only)
        if (isIOS) ...[
          FutureBuilder<bool>(
            future: SignInWithApple.isAvailable(),
            builder: (context, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildSocialButton(
                  onTap: _loading ? null : _handleApple,
                  icon: const Icon(Icons.apple, size: 22),
                  label: 'Continue with Apple',
                  darkStyle: true,
                ),
              );
            },
          ),
        ],

        // Google Sign In
        _buildSocialButton(
          onTap: _loading ? null : _handleGoogle,
          icon: _GoogleIcon(),
          label: 'Continue with Google',
        ),

        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or',
                style: TextStyle(
                    color: theme.textTheme.bodyMedium?.color,
                    fontSize: 13)),
          ),
          const Expanded(child: Divider()),
        ]),
        const SizedBox(height: 20),

        // Name (sign-up only)
        if (_isSignUp) ...[
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Email
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),

        // Password
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleEmailAuth(),
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),

        // Error
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_errorMessage!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: 13)),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Primary action button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _handleEmailAuth,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Toggle sign in / sign up
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _isSignUp = !_isSignUp;
              _errorMessage = null;
            }),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign in'
                  : "New here? Create an account",
              style: const TextStyle(
                  color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onTap,
    required Widget icon,
    required String label,
    bool darkStyle = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: darkStyle
              ? (isDark ? Colors.white10 : Colors.black)
              : null,
          foregroundColor: darkStyle
              ? Colors.white
              : theme.textTheme.bodyLarge?.color,
          side: BorderSide(
            color: darkStyle
                ? Colors.transparent
                : theme.dividerColor,
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Simple Google "G" icon rendered with Text (no svg/image assets needed).
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: const Center(
        child: Text('G',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1)),
      ),
    );
  }
}
