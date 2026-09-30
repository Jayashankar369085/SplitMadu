import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_value.dart';

/// Firestore: expenses/{id}
///
/// {
///   title, amount, category, paidBy, createdBy,
///   participants: { uid: share },
///   participantIds: [uid, ...],
///   createdAt
/// }
class ExpenseModel {
  const ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.paidBy,
    required this.createdBy,
    required this.participants,
    required this.createdAt,
  });

  final String id;
  final String title;
  final num amount;
  final String category;
  final String paidBy;
  final String createdBy;

  /// UID -> amount owed by that participant.
  final Map<String, num> participants;

  final DateTime createdAt;

  List<String> get participantIds => participants.keys.toList();

  /// Per-expense ledger:
  /// debtor -> creditor -> amount
  Map<String, Map<String, double>> toLedger() {
    final ledger = <String, Map<String, double>>{};

    participants.forEach((uid, share) {
      if (uid == paidBy) return;

      final amt = share.toDouble();
      if (amt <= 0) return;

      ledger.putIfAbsent(uid, () => {});

      ledger[uid]!.update(
        paidBy,
        (v) => v + amt,
        ifAbsent: () => amt,
      );
    });

    return ledger;
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'amount': amount,
        'category': category,
        'paidBy': paidBy,
        'createdBy': createdBy,
        'participants': participants,
        'participantIds': participants.keys.toList(),

        // REAL Firestore server timestamp.
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory ExpenseModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    final rawParticipants =
        (data['participants'] as Map?) ?? const {};

    return ExpenseModel(
      id: id,
      title: (data['title'] as String?) ?? '',
      amount: (data['amount'] as num?) ?? 0,
      category: (data['category'] as String?) ?? 'other',
      paidBy: (data['paidBy'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      participants: rawParticipants.map(
        (k, v) => MapEntry(
          k as String,
          (v as num?) ?? 0,
        ),
      ),
      createdAt:
          readFirestoreDate(data['createdAt']) ?? DateTime.now(),
    );
  }
}