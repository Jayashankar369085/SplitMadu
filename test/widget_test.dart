import 'package:flutter_test/flutter_test.dart';

import 'package:splitmadu/core/utils/error_mapper.dart';
import 'package:splitmadu/core/utils/formatters.dart';
import 'package:splitmadu/models/expense_model.dart';
import 'package:splitmadu/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('initials are derived from name', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Jay Kumar',
        email: 'jay@test.dev',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(user.initials, 'JK');
    });

    test('toMap normalizes nameSearch', () {
      final user = UserModel(
        uid: 'u1',
        name: 'Rahul',
        email: 'rahul@test.dev',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(user.toMap()['nameSearch'], 'rahul');
    });

    test('fromFirestore tolerates missing photoUrl', () {
      final user = UserModel.fromFirestore({
        'name': 'Anish',
        'email': 'anish@test.dev',
        'photoUrl': '',
      }, 'u2');
      expect(user.photoUrl, isNull);
      expect(user.name, 'Anish');
    });
  });

  group('ExpenseModel', () {
    test('toLedger maps shares to debtor→payer debts', () {
      final expense = ExpenseModel(
        id: 'e1',
        title: 'Dinner',
        amount: 1200,
        category: 'food',
        paidBy: 'jay',
        createdBy: 'jay',
        participants: {'jay': 400, 'rahul': 400, 'anish': 400},
        createdAt: DateTime(2026, 1, 1),
      );
      final ledger = expense.toLedger();
      expect(ledger['rahul']!['jay'], 400);
      expect(ledger['anish']!['jay'], 400);
      expect(ledger.containsKey('jay'), isFalse);
    });
  });

  group('Formatters', () {
    test('money formats whole rupees compactly', () {
      expect(Formatters.money(1200), '₹1,200');
    });

    test('money keeps paise when present', () {
      expect(Formatters.money(33.33), '₹33.33');
    });

    test('moneySigned uses proper signs', () {
      expect(Formatters.moneySigned(1650), '+₹1,650');
      expect(Formatters.moneySigned(-800), '−₹800');
      expect(Formatters.moneySigned(0), '₹0');
    });

    test('greeting follows time of day', () {
      expect(Formatters.greeting(DateTime(2026, 1, 1, 9)), 'Good morning');
      expect(Formatters.greeting(DateTime(2026, 1, 1, 14)), 'Good afternoon');
      expect(Formatters.greeting(DateTime(2026, 1, 1, 20)), 'Good evening');
    });

    test('equalSplit sums exactly to total', () {
      final shares = MoneyUtils.equalSplit(100, 3);
      expect(shares.fold<num>(0, (a, b) => a + b), 100);
    });
  });

  group('ErrorMapper', () {
    test('maps auth codes to friendly copy', () {
      expect(
        ErrorMapper.map(_FakeError('email-already-in-use')).message,
        'An account already exists with this email.',
      );
      expect(
        ErrorMapper.map(_FakeError('wrong-password')).message,
        'Incorrect password. Please try again.',
      );
    });

    test('strips firestore/ prefix from codes', () {
      expect(
        ErrorMapper.map(_FakeError('firestore/permission-denied')).message,
        'You don\'t have permission for that. Please log in again.',
      );
    });

    test('falls back to generic message', () {
      expect(
        ErrorMapper.map(_FakeError('some-unknown-code')).message,
        'Something went wrong. Please try again.',
      );
    });
  });
}

class _FakeError implements Exception {
  _FakeError(this.code);

  final String code;
}
