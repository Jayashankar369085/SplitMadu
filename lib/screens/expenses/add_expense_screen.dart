import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/formatters.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/user_avatar.dart';

/// Create-expense flow: Eshtu aaytu? → title/category → payer → Hanchu (split).
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.preselectedFriend});

  final UserModel? preselectedFriend;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _customCtrls = <String, TextEditingController>{};

  ExpenseCategory _category = ExpenseCategory.food;
  String? _paidBy;
  final Set<String> _selected = {};
  bool _equalSplit = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final friends = context.read<FriendsProvider>();
      setState(() {
        _paidBy = auth.uid;
        _selected.add(auth.uid!);
        if (widget.preselectedFriend != null) {
          _selected.add(widget.preselectedFriend!.uid);
        }
      });
      // Warm the cache so avatars resolve instantly.
      for (final f in friends.friends) {
        friends.getUser(f.uid);
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrlFor(String uid) =>
      _customCtrls.putIfAbsent(uid, () => TextEditingController());

  num get _amount => num.tryParse(_amountCtrl.text.trim()) ?? 0;

  Map<String, num> get _participants {
    final map = <String, num>{};
    if (_amount <= 0 || _selected.isEmpty) return map;
    if (_equalSplit) {
      final shares = MoneyUtils.equalSplit(_amount, _selected.length);
      var i = 0;
      for (final uid in _selected) {
        map[uid] = shares[i++];
      }
      return map;
    }
    for (final uid in _selected) {
      final v = num.tryParse(_ctrlFor(uid).text.trim()) ?? 0;
      if (v > 0) map[uid] = v;
    }
    return map;
  }

  num get _customTotal {
    var total = 0.0;
    for (final uid in _selected) {
      total += num.tryParse(_ctrlFor(uid).text.trim()) ?? 0;
    }
    return MoneyUtils.round2(total);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final participants = _participants;
    if (_paidBy == null || !_selected.contains(_paidBy)) {
      setState(() => _error = 'Pick who paid (must be a participant).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<ExpensesProvider>().addExpense(
            title: _titleCtrl.text,
            amount: _amount,
            category: _category.id,
            paidBy: _paidBy!,
            participants: participants,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Expense saved ✅')),
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
    final auth = context.watch<AuthProvider>();
    final friends = context.watch<FriendsProvider>();
    final scheme = Theme.of(context).colorScheme;

    final me = UserModel(
      uid: auth.uid ?? 'me',
      name: auth.profile?.name ?? 'You',
      email: auth.profile?.email ?? '',
      createdAt: DateTime.now(),
    );

    // Everyone selectable: me + friends (preselected friend included).
    final selectable = <UserModel>[me, ...friends.friends];

    final participants = _participants;
    final splitError = _equalSplit
        ? null
        : (participants.isEmpty || _customTotal != _amount.roundToDouble()
            ? 'Split must add up to ${Formatters.money(_amount)}'
            : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: friends.friends.isEmpty && widget.preselectedFriend == null
          ? EmptyState(
              emoji: '👥',
              title: 'Add a friend first',
              message:
                  'Expenses are shared with friends. Add one from the Friends tab and come back.',
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.m),
                children: [
                  TextFormField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: Theme.of(context).textTheme.headlineMedium,
                    decoration: InputDecoration(
                      hintText: '0',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Icon(Icons.currency_rupee_rounded, size: 28),
                      ),
                      helperText: 'Eshtu aaytu?',
                      errorText: _error,
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final value = num.tryParse(v?.trim() ?? '');
                      if (value == null || value <= 0) {
                        return 'Enter a valid amount';
                      }
                      if (!MoneyUtils.isValidAmount(value)) {
                        return 'Amount looks too large';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.m),
                  TextFormField(
                    controller: _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'What was it for? e.g. Dinner at Empire',
                      prefixIcon: Icon(Icons.restaurant_menu_rounded),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Give it a title' : null,
                  ),
                  const SizedBox(height: AppSpacing.m),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in ExpenseCategory.values)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.s),
                            child: ChoiceChip(
                              label: Text('${c.emoji} ${c.label}'),
                              selected: _category == c,
                              onSelected: (_) =>
                                  setState(() => _category = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text('Who paid?', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.s),
                  Wrap(
                    spacing: AppSpacing.s,
                    runSpacing: AppSpacing.s,
                    children: [
                      for (final u in selectable.where((u) => _selected.contains(u.uid)))
                        ChoiceChip(
                          avatar: UserAvatar(name: u.name, photoUrl: u.photoUrl, radius: 12),
                          label: Text(u.uid == auth.uid ? 'You' : u.name.split(' ').first),
                          selected: _paidBy == u.uid,
                          onSelected: (_) => setState(() => _paidBy = u.uid),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.l),
                  Text('Hanchu — split between',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.s),
                  ...selectable.map((u) => CheckboxListTile(
                        value: _selected.contains(u.uid),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selected.add(u.uid);
                            } else {
                              _selected.remove(u.uid);
                              if (_paidBy == u.uid) _paidBy = null;
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        secondary: UserAvatar(name: u.name, photoUrl: u.photoUrl, radius: 18),
                        title: Text(u.uid == auth.uid ? 'You' : u.name),
                        subtitle: _equalSplit
                            ? null
                            : TextField(
                                controller: _ctrlFor(u.uid),
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'Share ₹',
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                      )),
                  if (_selected.length >= 2) ...[
                    const SizedBox(height: AppSpacing.m),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Equal')),
                        ButtonSegment(value: false, label: Text('Custom')),
                      ],
                      selected: {_equalSplit},
                      onSelectionChanged: (v) =>
                          setState(() => _equalSplit = v.first),
                    ),
                    const SizedBox(height: AppSpacing.s),
                    if (!_equalSplit && splitError != null)
                      Text(
                        splitError,
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
                      ),
                    if (_selected.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                        child: Text(
                          _equalSplit
                              ? '${Formatters.money(_amount / _selected.length)} each · '
                                  '${_selected.length} people'
                              : 'Split total: ${Formatters.money(_customTotal)}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                  const SizedBox(height: AppSpacing.l),
                  PrimaryButton(
                    label: 'Save Expense',
                    loading: _saving,
                    onPressed: (_selected.length >= 2 &&
                            (_equalSplit || splitError == null))
                        ? _save
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
