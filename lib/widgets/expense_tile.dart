import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/expense_model.dart';
import 'user_avatar.dart';

/// List tile for an expense in history / shared lists.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.payerName,
    this.onTap,
    this.showDate = true,
  });

  final ExpenseModel expense;
  final String payerName;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final category = ExpenseCategory.fromId(expense.category);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(category.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        showDate
                            ? '$payerName paid · ${Formatters.date(expense.createdAt)}'
                            : '$payerName paid',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                Formatters.money(expense.amount),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact row for "People to settle" on the dashboard.
class SettlePersonTile extends StatelessWidget {
  const SettlePersonTile({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.theyOweMe,
    required this.amount,
    this.onTap,
  });

  final String name;
  final String? photoUrl;
  final bool theyOweMe;
  final num amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final positive = theyOweMe;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              UserAvatar(name: name, photoUrl: photoUrl, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: Theme.of(context).textTheme.titleMedium),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.money(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: positive ? AppColors.positive : AppColors.negative,
                    ),
                  ),
                  Text(
                    positive ? 'owes you' : 'you owe',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
