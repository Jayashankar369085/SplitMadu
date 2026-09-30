import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show Firebase;
import 'package:flutter/foundation.dart';

import '../core/utils/error_mapper.dart';

/// Thin wrapper around FirebaseAuth; UI never touches the SDK directly.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Emits on every auth state change; null when signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Diagnostic logging (debug builds only — never in release).
  void _logContext(String operation) {
    if (!kDebugMode) return;
    // ignore: avoid_dynamic_calls
    debugPrint('[AUTH] $operation on project=${Firebase.app().options.projectId} '
        'appId=${Firebase.app().options.appId} '
        'initializedApps=${Firebase.apps.length}');
  }

  void _logError(String operation, Object error, StackTrace stack) {
    if (!kDebugMode) return;
    if (error is FirebaseAuthException) {
      debugPrint('[AUTH] $operation FAILED: '
          'code=${error.code} message=${error.message} plugin=${error.plugin}');
    } else {
      debugPrint('[AUTH] $operation FAILED (non-FirebaseAuthException): '
          '${error.runtimeType}: $error');
    }
    debugPrint('[AUTH] stack: $stack');
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _logContext('register');
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stack) {
      _logError('register', e, stack);
      throw ErrorMapper.map(e);
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    _logContext('login');
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e, stack) {
      _logError('login', e, stack);
      throw ErrorMapper.map(e);
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<void> updateDisplayName(String name) async {
    try {
      await currentUser?.updateDisplayName(name);
      await currentUser?.reload();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
