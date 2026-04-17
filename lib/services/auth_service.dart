/// Auth Service
/// ============
/// Firebase Authentication wrapper with Google and Apple sign-in support.
library;

import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class AuthService extends ChangeNotifier {
  bool _isFirebaseAvailable = false;
  User? _currentUser;
  VoidCallback? _onSignIn;

  // iOS reads CLIENT_ID from GoogleService-Info.plist automatically,
  // but setting it explicitly avoids any scene/window lookup crashes.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1056534037851-rtsr94ua66bv5pss8ds5cu137lceo683.apps.googleusercontent.com',
  );

  /// Called when auth state transitions from signed-out to signed-in.
  void setOnSignIn(VoidCallback callback) {
    _onSignIn = callback;
  }

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isFirebaseAvailable = true;

      FirebaseAuth.instance.authStateChanges().listen((user) {
        final wasSignedIn = _currentUser != null;
        _currentUser = user;
        final isSignedIn = _currentUser != null;
        if (!wasSignedIn && isSignedIn) {
          _onSignIn?.call();
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Firebase init failed (offline mode active): $e');
      _isFirebaseAvailable = false;
    }
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isAvailable => _isFirebaseAvailable;
  bool get isSignedIn => _currentUser != null;
  User? get currentUser => _currentUser;
  String? get userEmail => _currentUser?.email;

  String? get displayName {
    if (_currentUser == null) return null;
    final name = _currentUser!.displayName;
    if (name != null && name.isNotEmpty) return name;
    final email = _currentUser!.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return email;
  }

  // ── Email / Password ──────────────────────────────────────────────────────

  Future<void> signInWithEmail(String email, String password) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not configured. Please set up Firebase first.');
    }
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not configured. Please set up Firebase first.');
    }
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await credential.user?.updateDisplayName(displayName.trim());
      await credential.user?.reload();
      _currentUser = FirebaseAuth.instance.currentUser;
      notifyListeners();
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not configured. Please set up Firebase first.');
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled.');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await FirebaseAuth.instance.signInWithCredential(credential);
  }

  // ── Apple Sign In ─────────────────────────────────────────────────────────

  /// Generates a cryptographically random nonce string.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// SHA-256 hashes the nonce for sending to Firebase.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> signInWithApple() async {
    if (!_isFirebaseAvailable) {
      throw Exception('Firebase is not configured. Please set up Firebase first.');
    }
    if (!Platform.isIOS) {
      throw Exception('Apple Sign In is only available on iOS.');
    }

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      throw Exception('Apple Sign-In did not return an identity token.');
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );

    final result = await FirebaseAuth.instance.signInWithCredential(oauthCredential);

    // Apple only sends the name on first sign-in.
    final givenName = appleCredential.givenName;
    final familyName = appleCredential.familyName;
    if (givenName != null && result.user?.displayName == null) {
      final fullName = [givenName, familyName].whereType<String>().join(' ').trim();
      if (fullName.isNotEmpty) {
        await result.user?.updateDisplayName(fullName);
      }
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }
}
