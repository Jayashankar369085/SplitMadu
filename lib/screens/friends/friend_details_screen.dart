import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/data_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/user_avatar.dart';
import '../expenses/add_expense_screen.dart';
import '../settlements/settle_up_sheet.dart';

class FriendDetailsScreen extends StatelessWidget {
  const FriendDetailsScreen({super.key, required this.friend});

  final UserModel friend;

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpensesProvider>();
    final friends = context.watch<FriendsProvider>();
    final scheme = Theme.of(context).colorScheme;

    final pair = expenses.pairBalanceWith(friend.uid);
    final shared = expenses.expensesWith(friend.uid);
    final settlements = expenses.settlementsWith(friend.uid);

    final isSettled = pair == null || pair.isSettled;
    final theyOweMe = (pair?.net ?? 0) > 0;
    final amount = pair?.settlementAmount ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(friend.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Column(
            children: [
              UserAvatar(name: friend.name, photoUrl: friend.photoUrl, radius: 36),
              const SizedBox(height: AppSpacing.s),
              Text(friend.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(
                friend.email,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.l),
            decoration: BoxDecoration(
              color: isSettled
                  ? scheme.primaryContainer.withValues(alpha: 0.5)
                  : theyOweMe
                      ? AppColors.positiveSoft
                      : AppColors.negativeSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Text(
                  isSettled
                      ? 'Hisabu clear ✨'
                      : theyOweMe
                          ? '${friend.name.split(' ').first} owes you'
                          : 'You owe ${friend.name.split(' ').first}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isSettled ? '₹0' : Formatters.money(amount),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: isSettled
                        ? scheme.primary
                        : theyOweMe
                            ? AppColors.positive
                            : AppColors.negative,
                  ),
                ),
              ],
            ),
          ),
          if (!isSettled) ...[
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              onPressed: () => showSettleUpSheet(context, friend),
              icon: const Icon(Icons.handshake_rounded),
              label: const Text('Settle Up'),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          Text('Shared expenses', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s),
          if (shared.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.l),
              child: EmptyState(
                emoji: '🧾',
                title: 'Nothing shared yet',
                message: 'Add an expense with ${friend.name.split(' ').first} to see it here.',
                actionLabel: 'Add Expense',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(preselectedFriend: friend),
                  ),
                ),
              ),
            )
          else
            for (final e in shared)
              ExpenseTile(
                expense: e,
                payerName: friends.displayName(e.paidBy),
                onTap: () {},
              ),
          if (settlements.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.m),
            Text('Settlement history', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s),
            for (final s in settlements)
              Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.s),
                child: ListTile(
                  leading: Icon(
                    Icons.handshake_rounded,
                    color: AppColors.positive,
                  ),
                  title: Text(
                    s.from == expenses.myUid
                        ? 'You paid ${friends.displayName(s.to)}'
                        : '${friends.displayName(s.from)} paid you',
                  ),
                  subtitle: Text(Formatters.date(s.createdAt)),
                  trailing: Text(
                    Formatters.money(s.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.positive,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
