import 'dart:math' as math;

import '../core/utils/formatters.dart';
import '../models/expense_model.dart';
import '../models/settlement_model.dart';

/// Result of the pairwise balance computation between the current user and
/// one other person.
class PairBalance {
  const PairBalance({
    required this.otherUid,
    required this.theyOweMe,
    required this.iOweThem,
  });

  final String otherUid;

  /// Total amount the other person owes me across all shared activity.
  final double theyOweMe;

  /// Total amount I owe the other person.
  final double iOweThem;

  /// Net: positive means they owe me; negative means I owe them.
  double get net => MoneyUtils.round2(theyOweMe - iOweThem);

  bool get isSettled => MoneyUtils.nearlyEqual(net, 0);

  /// Amount needed to clear this pair (always >= 0).
  double get settlementAmount => MoneyUtils.round2(net.abs());

  /// Direction of the clearing payment.
  ///
  /// If true, `other -> me` settles; if false, `me -> other` settles.
  bool get otherPaysMe => net > 0;
}

/// Global net position of a user across all shared activity.
class NetBalance {
  const NetBalance({
    required this.totalOwedToMe,
    required this.iOweThem,
  });

  final double totalOwedToMe;
  final double iOweThem;

  double get net => MoneyUtils.round2(totalOwedToMe - iOweThem);
}

/// A suggested payment after debt simplification.
class Transfer {
  const Transfer({required this.from, required this.to, required this.amount});

  final String from;
  final String to;
  final double amount;
}

/// The SplitMadu balance engine.
///
/// Pure Dart: no Firestore, no Flutter. Balances are always *derived* from
/// expenses + settlements — never stored.
///
/// Ledger semantics:
///   * Every expense contributes: for each participant p != paidBy,
///     `p owes paidBy participants[p]`.
///   * Every settlement contributes: `from owes to` reduced by amount
///     (i.e. settlement from A to B cancels debt A→B or creates B→A credit).
class BalanceService {
  const BalanceService();

  /// Pairwise balances between [myUid] and everyone they share expenses or
  /// settlements with.
  ///
  /// [debt] accumulates as `debtor -> {creditor: amount}`.
  List<PairBalance> computePairBalances({
    required String myUid,
    required List<ExpenseModel> expenses,
    required List<SettlementModel> settlements,
  }) {
    // debt[a][b] = a owes b
    final debt = <String, Map<String, double>>{};

    void addDebt(String from, String to, double amount) {
      if (MoneyUtils.nearlyEqual(amount, 0)) return;
      debt.putIfAbsent(from, () => {});
      debt[from]!.update(to, (v) => MoneyUtils.round2(v + amount),
          ifAbsent: () => MoneyUtils.round2(amount));
    }

    for (final e in expenses) {
      e.toLedger().forEach((debtor, credits) {
        credits.forEach((creditor, amount) => addDebt(debtor, creditor, amount));
      });
    }

    for (final s in settlements) {
      final amt = s.amount.toDouble();
      final current = debt[s.from]?[s.to] ?? 0;
      final settled = math.min(current, amt);
      final overflow = MoneyUtils.round2(amt - settled);

      if (settled > 0) {
        final remaining = MoneyUtils.round2(current - settled);
        if (MoneyUtils.nearlyEqual(remaining, 0)) {
          debt[s.from]!.remove(s.to);
          if (debt[s.from]!.isEmpty) debt.remove(s.from);
        } else {
          debt[s.from]![s.to] = remaining;
        }
      }
      // Overpayment flips direction: creditor now owes the payer back.
      if (overflow > 0) {
        addDebt(s.to, s.from, overflow);
      }
    }

    // Reduce my position pairwise (netting both directions).
    final partners = <String>{};
    debt.forEach((from, credits) {
      credits.forEach((to, _) {
        if (from == myUid) partners.add(to);
        if (to == myUid) partners.add(from);
      });
    });

    final result = <PairBalance>[];
    for (final other in partners) {
      final theyOweMe = debt[other]?[myUid] ?? 0;
      final iOweThem = debt[myUid]?[other] ?? 0;
      final pair = PairBalance(
        otherUid: other,
        theyOweMe: MoneyUtils.round2(theyOweMe),
        iOweThem: MoneyUtils.round2(iOweThem),
      );
      // Settled pairs (net == 0) don't need action — drop them.
      if (!pair.isSettled) result.add(pair);
    }
    result.sort((a, b) => b.net.abs().compareTo(a.net.abs()));
    return result;
  }

  /// My aggregate position (you owe / you're owed / net).
  NetBalance computeNetBalance({
    required String myUid,
    required List<ExpenseModel> expenses,
    required List<SettlementModel> settlements,
  }) {
    final pairs = computePairBalances(
      myUid: myUid,
      expenses: expenses,
      settlements: settlements,
    );
    var owedToMe = 0.0;
    var iOwe = 0.0;
    for (final p in pairs) {
      if (p.net > 0) {
        owedToMe += p.net;
      } else if (p.net < 0) {
        iOwe += -p.net;
      }
    }
    return NetBalance(
      totalOwedToMe: MoneyUtils.round2(owedToMe),
      iOweThem: MoneyUtils.round2(iOwe),
    );
  }

  /// Smart settlement: net everyone's position and suggest the minimum set of
  /// transfers that clears all debts. Greedy creditor/debtor matching —
  /// at most (n − 1) transfers for n unbalanced users.
  List<Transfer> computeSmartSettlement({
    required List<ExpenseModel> expenses,
    required List<SettlementModel> settlements,
  }) {
    // net[u]: positive => u should receive; negative => u should pay.
    final net = <String, double>{};
    void bump(String uid, double amount) =>
        net.update(uid, (v) => MoneyUtils.round2(v + amount),
            ifAbsent: () => MoneyUtils.round2(amount));

    for (final e in expenses) {
      e.toLedger().forEach((debtor, credits) {
        credits.forEach((creditor, amount) {
          bump(debtor, -amount);
          bump(creditor, amount);
        });
      });
    }
    for (final s in settlements) {
      final amt = s.amount.toDouble();
      bump(s.from, amt); // payer's obligation reduced
      bump(s.to, -amt); // receiver's credit reduced
    }

    final debtors = <_Party>[];
    final creditors = <_Party>[];
    net.forEach((uid, v) {
      final rounded = MoneyUtils.round2(v);
      if (rounded < -_epsilon) {
        debtors.add(_Party(uid, -rounded));
      } else if (rounded > _epsilon) {
        creditors.add(_Party(uid, rounded));
      }
    });

    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final transfers = <Transfer>[];
    var i = 0, j = 0;
    while (i < debtors.length && j < creditors.length) {
      final d = debtors[i];
      final c = creditors[j];
      final pay = MoneyUtils.round2(math.min(d.amount, c.amount));
      if (pay > 0) {
        transfers.add(Transfer(from: d.uid, to: c.uid, amount: pay));
      }
      d.amount = MoneyUtils.round2(d.amount - pay);
      c.amount = MoneyUtils.round2(c.amount - pay);
      if (d.amount <= _epsilon) i++;
      if (c.amount <= _epsilon) j++;
    }
    return transfers;
  }
}

class _Party {
  _Party(this.uid, this.amount);

  final String uid;
  double amount;
}

/// Amounts below this are treated as zero when netting debts.
const double _epsilon = 0.01;
