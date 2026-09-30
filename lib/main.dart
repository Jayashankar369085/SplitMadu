import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/data_providers.dart';
import 'repositories/auth_repository.dart';
import 'repositories/expense_repository.dart';
import 'repositories/friend_request_repository.dart';
import 'repositories/friendship_repository.dart';
import 'repositories/settlement_repository.dart';
import 'repositories/user_repository.dart';
import 'screens/auth/auth_gate.dart';
import 'services/balance_service.dart';
import 'services/user_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Sensible Firestore defaults: offline cache + no debug logging.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const SplitMaduApp());
}

class SplitMaduApp extends StatelessWidget {
  const SplitMaduApp({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final firebaseAuth = FirebaseAuth.instance;

    final userCache = UserCache();
    final authRepo = AuthRepository(firebaseAuth);
    final userRepo = UserRepository(firestore, auth: firebaseAuth);

    return MultiProvider(
      providers: [
        Provider<UserCache>.value(value: userCache),
        Provider<AuthRepository>.value(value: authRepo),
        Provider<UserRepository>.value(value: userRepo),
        Provider<FriendshipRepository>(
          create: (_) => FriendshipRepository(firestore, auth: firebaseAuth),
        ),
        Provider<FriendRequestRepository>(
          create: (_) => FriendRequestRepository(firestore, auth: firebaseAuth),
        ),
        Provider<ExpenseRepository>(
          create: (_) => ExpenseRepository(firestore, auth: firebaseAuth),
        ),
        Provider<SettlementRepository>(
          create: (_) => SettlementRepository(firestore, auth: firebaseAuth),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepo, userRepo),
        ),
        ChangeNotifierProvider<FriendsProvider>(
          create: (context) => FriendsProvider(
            context.read<FriendshipRepository>(),
            context.read<UserRepository>(),
            context.read<UserCache>(),
            context.read<FriendRequestRepository>(),
          ),
        ),
        ChangeNotifierProvider<ExpensesProvider>(
          create: (context) => ExpensesProvider(
            context.read<ExpenseRepository>(),
            context.read<SettlementRepository>(),
            const BalanceService(),
            context.read<UserRepository>(),
            context.read<UserCache>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'SplitMadu',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: _AuthWiring(child: const AuthGate()),
      ),
    );
  }
}

/// Kicks off provider lifecycle wiring once all providers exist.
class _AuthWiring extends StatefulWidget {
  const _AuthWiring({required this.child});

  final Widget child;

  @override
  State<_AuthWiring> createState() => _AuthWiringState();
}

class _AuthWiringState extends State<_AuthWiring> {
  @override
  void initState() {
    super.initState();
    context.read<AuthProvider>().attach(
          friends: context.read<FriendsProvider>(),
          expenses: context.read<ExpensesProvider>(),
        );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
