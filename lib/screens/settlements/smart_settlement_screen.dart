import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/data_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/user_avatar.dart';

/// Debt simplification: suggests the minimal set of transfers that clears
/// everyone's balance within the user's circle.
class SmartSettlementScreen extends StatelessWidget {
  const SmartSettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpensesProvider>();
    final friends = context.watch<FriendsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final transfers = expenses.smartSettlement();

    return Scaffold(
      appBar: AppBar(title: const Text('Smart Settlement ✨')),
      body: transfers.isEmpty
          ? EmptyState(
              emoji: '🎉',
              title: 'Hisabu Clear!',
              message:
                  'Nothing to simplify — everyone is already settled up.',
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: AppSpacing.s),
                      Text(
                        'You can simplify these payments',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${transfers.length} transfer${transfers.length == 1 ? '' : 's'} '
                        'instead of tracking every debt individually.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.l),
                for (final t in transfers)
                  Builder(
                    builder: (context) {
                      final fromName = friends.displayName(t.from);
                      final toName = friends.displayName(t.to);
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              UserAvatar(name: fromName, radius: 18),
                              Expanded(
                                child: Center(
                                  child: Icon(Icons.arrow_forward_rounded,
                                      color: scheme.primary),
                                ),
                              ),
                              UserAvatar(name: toName, radius: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$fromName → $toName',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(
                                      Formatters.money(t.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.indigo,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  'Record these payments with Settle Up on each friend, '
                  'and everyone\'s balance becomes zero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}
