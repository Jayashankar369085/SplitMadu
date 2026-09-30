import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/user_model.dart';
import '../services/balance_service.dart';
import 'user_avatar.dart';

/// Friend list row with net balance indicator.
class FriendTile extends StatelessWidget {
  const FriendTile({
    super.key,
    required this.friend,
    this.balance,
    this.onTap,
  });

  final UserModel friend;
  final PairBalance? balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final settled = balance == null || balance!.isSettled;
    final positive = (balance?.net ?? 0) > 0;
    final scheme = Theme.of(context).colorScheme;

    final subtitle = settled
        ? 'Settled up'
        : positive
            ? 'owes you ${Formatters.money(balance!.net)}'
            : 'you owe ${Formatters.money(-balance!.net)}';

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.s),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              UserAvatar(name: friend.name, photoUrl: friend.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(friend.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: settled
                            ? scheme.onSurfaceVariant
                            : positive
                                ? AppColors.positive
                                : AppColors.negative,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
