import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_value.dart';

/// Firestore: settlements/{id}
///
/// { from, to, amount, createdBy, createdAt }
class SettlementModel {
  const SettlementModel({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;

  /// UID of the user who paid money.
  final String from;

  /// UID of the user who received money.
  final String to;

  final num amount;
  final String createdBy;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'from': from,
        'to': to,
        'amount': amount,
        'createdBy': createdBy,

        // REAL Firestore server timestamp.
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory SettlementModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return SettlementModel(
      id: id,
      from: (data['from'] as String?) ?? '',
      to: (data['to'] as String?) ?? '',
      amount: (data['amount'] as num?) ?? 0,
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt:
          readFirestoreDate(data['createdAt']) ?? DateTime.now(),
    );
  }
}