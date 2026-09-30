import 'package:flutter_test/flutter_test.dart';

import 'package:splitmadu/core/utils/formatters.dart';
import 'package:splitmadu/models/expense_model.dart';
import 'package:splitmadu/models/settlement_model.dart';
import 'package:splitmadu/services/balance_service.dart';

ExpenseModel exp({
  required String id,
  required String paidBy,
  required num amount,
  Map<String, num> shares = const {},
}) =>
    ExpenseModel(
      id: id,
      title: 'E$id',
      amount: amount,
      category: 'food',
      paidBy: paidBy,
      createdBy: paidBy,
      participants: shares,
      createdAt: DateTime(2026, 1, 1),
    );

SettlementModel stl({
  required String from,
  required String to,
  required num amount,
}) =>
    SettlementModel(
      id: 's_${from}_$to',
      from: from,
      to: to,
      amount: amount,
      createdBy: from,
      createdAt: DateTime(2026, 1, 2),
    );

void main() {
  const svc = BalanceService();

  group('single expense', () {
    test('Jay pays 1200, three equal shares', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 1200,
            shares: {'jay': 400, 'rahul': 400, 'anish': 400}),
      ];
      final pairs = svc.computePairBalances(
          myUid: 'jay', expenses: expenses, settlements: const []);
      expect(pairs, hasLength(2));
      for (final p in pairs) {
        expect(p.theyOweMe, 400);
        expect(p.iOweThem, 0);
        expect(p.net, 400);
      }
      final net = svc.computeNetBalance(
          myUid: 'jay', expenses: expenses, settlements: const []);
      expect(net.totalOwedToMe, 800);
      expect(net.iOweThem, 0);
      expect(net.net, 800);
    });

    test('direction flips for the debtor', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 1200,
            shares: {'jay': 400, 'rahul': 400, 'anish': 400}),
      ];
      final pairs = svc.computePairBalances(
          myUid: 'rahul', expenses: expenses, settlements: const []);
      expect(pairs.single.otherUid, 'jay');
      expect(pairs.single.iOweThem, 400);
      expect(pairs.single.theyOweMe, 0);
    });
  });

  group('aggregation', () {
    test('multiple expenses accumulate per pair', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 600,
            shares: {'jay': 200, 'rahul': 200, 'anish': 200}),
        exp(id: 'e2', paidBy: 'jay', amount: 450,
            shares: {'jay': 150, 'rahul': 300}),
        exp(id: 'e3', paidBy: 'rahul', amount: 300,
            shares: {'jay': 100, 'rahul': 200}),
      ];
      final pairs = svc.computePairBalances(
          myUid: 'jay', expenses: expenses, settlements: const []);
      final rahul = pairs.firstWhere((p) => p.otherUid == 'rahul');
      expect(rahul.theyOweMe, 500);
      expect(rahul.iOweThem, 100);
      expect(rahul.net, 400);
    });
  });

  group('settlements', () {
    test('full settlement zeroes the balance', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 500,
            shares: {'jay': 0, 'rahul': 500}),
      ];
      final settlements = [stl(from: 'rahul', to: 'jay', amount: 500)];
      final pairs = svc.computePairBalances(
          myUid: 'jay', expenses: expenses, settlements: settlements);
      expect(pairs, isEmpty);
    });

    test('partial settlement leaves the remainder', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 500,
            shares: {'jay': 0, 'rahul': 500}),
      ];
      final settlements = [stl(from: 'rahul', to: 'jay', amount: 200)];
      final pairs = svc.computePairBalances(
          myUid: 'jay', expenses: expenses, settlements: settlements);
      expect(pairs.single.theyOweMe, 300);
    });

    test('settlement nets across opposite debts', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 500,
            shares: {'jay': 100, 'rahul': 400}),
        exp(id: 'e2', paidBy: 'rahul', amount: 250,
            shares: {'jay': 250, 'rahul': 0}),
      ];
      final settlements = [stl(from: 'rahul', to: 'jay', amount: 150)];
      final pairs = svc.computePairBalances(
          myUid: 'jay', expenses: expenses, settlements: settlements);
      expect(pairs, isEmpty);
    });

    test('overpayment flips the direction', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 500,
            shares: {'jay': 0, 'rahul': 500}),
      ];
      final settlements = [stl(from: 'rahul', to: 'jay', amount: 700)];
      final pairs = svc.computePairBalances(
          myUid: 'jay', expenses: expenses, settlements: settlements);
      expect(pairs.single.iOweThem, 200);
      expect(pairs.single.theyOweMe, 0);
    });
  });

  group('smart settlement', () {
    test('star debts stay minimal', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'anish', amount: 500,
            shares: {'jay': 500, 'anish': 0}),
        exp(id: 'e2', paidBy: 'anish', amount: 300,
            shares: {'jay': 300, 'anish': 0}),
        exp(id: 'e3', paidBy: 'anish', amount: 200,
            shares: {'rahul': 200, 'anish': 0}),
      ];
      final transfers = svc.computeSmartSettlement(
          expenses: expenses, settlements: const []);
      expect(transfers, hasLength(2));
      expect(transfers.every((t) => t.to == 'anish'), isTrue);
      expect(transfers.fold<num>(0, (a, t) => a + t.amount), 1000);
    });

    test('cycle simplifies to two transfers', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'rahul', amount: 500,
            shares: {'jay': 500, 'rahul': 0}),
        exp(id: 'e2', paidBy: 'anish', amount: 300,
            shares: {'jay': 300, 'anish': 0}),
        exp(id: 'e3', paidBy: 'anish', amount: 200,
            shares: {'rahul': 200, 'anish': 0}),
      ];
      final transfers = svc.computeSmartSettlement(
          expenses: expenses, settlements: const []);
      // Nets: Jay −800, Rahul +300, Anish +500 → 2 transfers, ₹800 total.
      expect(transfers, hasLength(2));
      final total = transfers.fold<num>(0, (a, t) => a + t.amount);
      expect(total, 800);
    });

    test('already settled group yields no transfers', () {
      final expenses = [
        exp(id: 'e1', paidBy: 'jay', amount: 100,
            shares: {'jay': 50, 'rahul': 50}),
      ];
      final settlements = [stl(from: 'rahul', to: 'jay', amount: 50)];
      expect(
        svc.computeSmartSettlement(
            expenses: expenses, settlements: settlements),
        isEmpty,
      );
    });
  });

  group('equal split helper', () {
    test('splits 100 into 3 with remainder distribution', () {
      final shares = MoneyUtils.equalSplit(100, 3);
      expect(shares, [33.34, 33.33, 33.33]);
      expect(shares.fold<num>(0, (a, b) => a + b), 100);
    });

    test('handles amount smaller than people', () {
      final shares = MoneyUtils.equalSplit(1, 3);
      expect(shares.fold<num>(0, (a, b) => a + b), 1);
    });
  });
}
