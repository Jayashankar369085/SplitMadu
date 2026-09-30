import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/loading.dart';
import '../../widgets/user_avatar.dart';
import '../expenses/add_expense_screen.dart';
import '../expenses/expense_details_screen.dart';
import '../friends/friend_details_screen.dart';
import '../settlements/smart_settlement_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final expenses = context.watch<ExpensesProvider>();
    final friends = context.watch<FriendsProvider>();

    if (expenses.loading && expenses.expenses.isEmpty) {
      return const Scaffold(
        body: LoadingView(message: 'Crunching your balances...'),
      );
    }
    if (expenses.error != null && expenses.expenses.isEmpty) {
      return Scaffold(
        body: ErrorView(message: expenses.error!, onRetry: () {}),
      );
    }

    final net = expenses.netBalance();
    final pairs = expenses.pairBalances();
    final recent = expenses.expenses.take(5).toList();

    final name = auth.profile?.name ?? 'friend';
    final firstName = name.split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.m),
          children: [
            Row(
              children: [
                UserAvatar(name: name, photoUrl: auth.profile?.photoUrl, radius: 22),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SmartSettlementScreen()),
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  tooltip: 'Smart Settlement',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${Formatters.greeting()}, $firstName 👋',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Eshtu aaytu? Here\'s where you stand.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            BalanceCard(net: net),
            if (pairs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.l),
              Text('People to settle', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s),
              for (final pair in pairs.take(4))
                Builder(
                  builder: (context) {
                    final friend = friends.friends
                        .where((f) => f.uid == pair.otherUid)
                        .firstOrNull;
                    return SettlePersonTile(
                      name: friend?.name ?? 'Friend',
                      photoUrl: friend?.photoUrl,
                      theyOweMe: pair.otherPaysMe,
                      amount: pair.settlementAmount,
                      onTap: friend == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FriendDetailsScreen(friend: friend),
                                ),
                              ),
                    );
                  },
                ),
            ],
            const SizedBox(height: AppSpacing.l),
            Text('Recent expenses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: EmptyState(
                  emoji: '🍛',
                  title: 'No expenses yet',
                  message: 'Start tracking your first shared expense.',
                  actionLabel: 'Add Expense',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                  ),
                ),
              )
            else
              for (final e in recent)
                ExpenseTile(
                  expense: e,
                  payerName: friends.displayName(e.paidBy),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExpenseDetailsScreen(expenseId: e.id),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
