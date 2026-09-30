import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/data_providers.dart';

/// Shows the Settle Up bottom sheet for [friend].
Future<void> showSettleUpSheet(BuildContext context, UserModel friend) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => SettleUpSheet(friend: friend),
  );
}

class SettleUpSheet extends StatefulWidget {
  const SettleUpSheet({super.key, required this.friend});

  final UserModel friend;

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  final _amountCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = num.tryParse(_amountCtrl.text.trim());
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<ExpensesProvider>().settleUp(
            otherUid: widget.friend.uid,
            amount: parsed,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Hisabu clear with ${widget.friend.name.split(' ').first} ✨')),
      );
    } on AppException catch (e) {
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.read<ExpensesProvider>();
    final pair = expenses.pairBalanceWith(widget.friend.uid);
    final outstanding = pair?.settlementAmount ?? 0;
    final theyOweMe = (pair?.net ?? 0) > 0;
    final firstName = widget.friend.name.split(' ').first;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.l,
        right: AppSpacing.l,
        top: AppSpacing.s,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            theyOweMe ? '$firstName pays you back' : 'You pay $firstName',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Outstanding: ${Formatters.money(outstanding)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          TextField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'Eshtu? Amount in ₹',
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.m),
          Wrap(
            spacing: AppSpacing.s,
            children: [
              for (final fraction in const [1.0, 0.5])
                ActionChip(
                  label: Text(
                    fraction == 1.0
                        ? 'Full ${Formatters.money(outstanding)}'
                        : 'Half ${Formatters.money(outstanding * 0.5)}',
                  ),
                  onPressed: () {
                    setState(() {
                      _amountCtrl.text =
                          (outstanding * fraction).toStringAsFixed(2);
                      _error = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: _saving ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.positive,
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Text('Record Settlement'),
          ),
        ],
      ),
    );
  }
}
