import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/expense_model.dart';
import '../../providers/data_providers.dart';
import '../../widgets/user_avatar.dart';

/// Reads the expense from the provider by id (single source of truth).
class ExpenseDetailsScreen extends StatelessWidget {
  const ExpenseDetailsScreen({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpensesProvider>();
    final friends = context.watch<FriendsProvider>();

    ExpenseModel? expense;
    for (final e in expenses.expenses) {
      if (e.id == expenseId) {
        expense = e;
        break;
      }
    }
    if (expense == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This expense is no longer available.')),
      );
    }

    final category = ExpenseCategory.fromId(expense.category);
    final payerName = friends.displayName(expense.paidBy);
    final myUid = expenses.myUid;

    return Scaffold(
      appBar: AppBar(title: const Text('Expense')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          Text(
            '${category.emoji}  ${expense.title}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${Formatters.money(expense.amount)} · ${Formatters.date(expense.createdAt)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                children: [
                  const Text('💰', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$payerName paid ${Formatters.money(expense.amount)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          Text('Split between', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s),
          for (final entry in expense.participants.entries)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.s),
              child: ListTile(
                leading: UserAvatar(
                  name: friends.displayName(entry.key),
                  radius: 18,
                ),
                title: Text(
                  entry.key == myUid
                      ? 'You'
                      : friends.displayName(entry.key),
                ),
                trailing: Text(
                  Formatters.money(entry.value),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
