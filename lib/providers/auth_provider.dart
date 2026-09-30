import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../core/utils/error_mapper.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import 'data_providers.dart';

/// Holds authentication state and the signed-in user's profile.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authRepo, this._userRepo);

  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  StreamSubscription<fb.User?>? _sub;

  bool _initialized = false;
  bool get initialized => _initialized;

  fb.User? _fbUser;
  UserModel? _profile;
  bool _profileLoading = false;

  bool get isLoggedIn => _fbUser != null;
  UserModel? get profile => _profile;
  bool get profileLoading => _profileLoading;
  String? get uid => _fbUser?.uid;

  /// Wire lifecycle hooks from main.dart once all providers exist.
  /// Friends/expenses live streams restart on every login/logout, and the
  /// initial auth restoration flows through the same handler.
  void attach({
    required FriendsProvider friends,
    required ExpensesProvider expenses,
  }) {
    _sub ??= _authRepo.authStateChanges.listen((user) {
      if (user != null) {
        friends.start();
        expenses.start(user.uid);
      } else {
        friends.stop();
        expenses.stop();
      }
      _onAuthChanged(user);
    });
  }

  Future<void> _onAuthChanged(fb.User? user) async {
    _fbUser = user;
    _profile = null;
    if (user != null) {
      _profileLoading = true;
      notifyListeners();
      try {
        _profile = await _userRepo.getById(user.uid);
        if (_profile == null) {
          // Right after registration the profile doc may still be writing —
          // give it a moment and retry once.
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          _profile = await _userRepo.getById(user.uid);
        }
      } on AppException {
        // Profile read failed (rules/permission/network); stay logged in,
        // screens handle a null profile gracefully.
        _profile = null;
      }
      _profileLoading = false;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _authRepo.register(
      name: name,
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user == null) {
      throw const AppException('Registration failed. Please try again.');
    }
    await _authRepo.updateDisplayName(name);

    final profile = UserModel(
      uid: user.uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      createdAt: DateTime.now(),
    );
    await _userRepo.createProfile(profile);
    // Merge onto any concurrent auth-listener state instead of overwriting.
    _profile = profile;
    _onboardingRoutePending = true;
    notifyListeners();
  }

  /// Show onboarding exactly once per account.
  bool _onboardingRoutePending = false;

  /// Called by the onboarding screen's Skip / Get Started.
  Future<void> completeOnboarding() async {
    final uid = _fbUser?.uid;
    if (uid == null) return;
    _onboardingRoutePending = false;
    // Optimistic local update; Firestore write follows.
    _profile = _profile?.copyWith(onboardingCompleted: true) ??
        UserModel(
          uid: uid,
          name: 'User',
          email: _fbUser?.email ?? '',
          createdAt: DateTime.now(),
          onboardingCompleted: true,
        );
    notifyListeners();
    await _userRepo.setOnboardingCompleted(uid);
  }

  /// Whether onboarding should be shown for the current profile state.
  bool get shouldShowOnboarding {
    if (_onboardingRoutePending) return true;
    final p = _profile;
    return p != null && !p.onboardingCompleted;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _authRepo.login(email: email, password: password);
    // Profile loads via the authStateChanges listener.
  }

  Future<void> logout() async {
    await _authRepo.logout();
    _profile = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    final uid = _fbUser?.uid;
    if (uid == null) return;
    _profile = await _userRepo.getById(uid);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
