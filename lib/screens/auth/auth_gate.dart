import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_screen.dart';
import '../splash/splash_screen.dart';
import 'login_screen.dart';

/// Listens to auth state and routes:
///   restoring           -> Splash
///   signed out          -> Login
///   signed in, new user -> Onboarding (once per account, flag on profile)
///   signed in, existing -> HomeShell
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.initialized) {
      return const SplashScreen();
    }
    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }
    if (auth.profileLoading) {
      return const SplashScreen(message: 'Loading your profile...');
    }
    if (auth.shouldShowOnboarding) {
      return const OnboardingScreen();
    }
    return const HomeShell();
  }
}
