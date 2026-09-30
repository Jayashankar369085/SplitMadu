import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../services/balance_service.dart';
import '../../widgets/user_avatar.dart';
import '../settlements/smart_settlement_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final expenses = context.watch<ExpensesProvider>();
    final scheme = Theme.of(context).colorScheme;

    final profile = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.m),
        children: [
          const SizedBox(height: AppSpacing.m),
          Column(
            children: [
              UserAvatar(
                name: profile?.name ?? '?',
                photoUrl: profile?.photoUrl,
                radius: 44,
              ),
              const SizedBox(height: AppSpacing.m),
              Text(profile?.name ?? '—',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(
                profile?.email ?? auth.uid ?? '',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _SummaryCard(net: expenses.netBalance()),
          const SizedBox(height: AppSpacing.l),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome_rounded),
                  title: const Text('Smart Settlement'),
                  subtitle: const Text('Simplify who pays whom'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SmartSettlementScreen()),
                  ),
                ),
                Divider(color: scheme.outline.withValues(alpha: 0.3)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Log out'),
                  titleTextStyle: TextStyle(
                    color: AppColors.negative,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in anytime.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
            ),
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final auth = context.read<AuthProvider>();
              navigator.pop();
              try {
                await auth.logout();
              } on AppException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.net});

  final NetBalance net;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'You owe',
                value: Formatters.money(net.iOweThem),
                color: AppColors.negative,
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _Stat(
                label: 'You\'re owed',
                value: Formatters.money(net.totalOwedToMe),
                color: AppColors.positive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
