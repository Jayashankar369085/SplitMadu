import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../core/constants/app_constants.dart';
import '../core/utils/error_mapper.dart';
import '../core/utils/fs_debug.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  ExpenseRepository(this._firestore, {this._auth});

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  CollectionReference<Map<String, dynamic>> get _expenses =>
      _firestore.collection(AppConstants.expensesCollection);

  String? get currentUid => _auth?.currentUser?.uid;

  /// Create a validated expense.
  ///
  /// Validation: non-empty title, valid positive amount, >=2 participants,
  /// payer is a participant, and shares sum exactly to the total.
  Future<String> createExpense({
    required String title,
    required num amount,
    required String category,
    required String paidBy,
    required Map<String, num> participants,
  }) async {
    final uid = currentUid;
    if (uid == null) throw const AppException('Please log in again.');

    final v = _validate(
      title: title,
      amount: amount,
      paidBy: paidBy,
      participants: participants,
      createdBy: uid,
    );
    if (v != null) throw AppException(v);

    final expense = ExpenseModel(
      id: '',
      title: title.trim(),
      amount: amount,
      category: category,
      paidBy: paidBy,
      createdBy: uid,
      participants: participants,
      createdAt: DateTime.now(),
    );

    try {
      final doc = await _expenses.add(expense.toMap());
      return doc.id;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Real-time list of expenses involving the current user (as participant
  /// or payer), newest first.
  Stream<List<ExpenseModel>> watchMyExpenses() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
return _expenses
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .handleError((Object e, StackTrace s) => FsDebug.error('EXPENSES', e, s))
        .map(
          (snap) => snap.docs
              .map((d) => ExpenseModel.fromFirestore(d.data(), d.id))
              .toList(),
        );
  }

  /// All expenses shared with [friendUid] (either direction), newest first.
  Future<List<ExpenseModel>> fetchSharedExpenses(String friendUid) async {
    final uid = currentUid;
    if (uid == null) return const [];
    try {
      final snaps = await Future.wait([
        _expenses
            .where('participantIds', arrayContains: uid)
            .orderBy('createdAt', descending: true)
            .limit(300)
            .get(),
      ]);
      final shared = snaps.first.docs
          .map((d) => ExpenseModel.fromFirestore(d.data(), d.id))
          .where((e) => e.participantIds.contains(friendUid))
          .toList();
      return shared;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Expenses involving both users (used by friend details).
  Stream<List<ExpenseModel>> watchSharedExpenses(String friendUid) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _expenses
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ExpenseModel.fromFirestore(d.data(), d.id))
              .where((e) => e.participantIds.contains(friendUid))
              .toList(),
        );
  }

  String? _validate({
    required String title,
    required num amount,
    required String paidBy,
    required Map<String, num> participants,
    required String createdBy,
  }) {
    if (title.trim().isEmpty) return 'Please give the expense a title.';
    if (title.trim().length > AppConstants.maxTitleLength) {
      return 'Title is too long (max ${AppConstants.maxTitleLength} chars).';
    }
    if (amount <= 0) return 'Amount must be greater than zero.';
    if (amount > AppConstants.maxExpenseAmount) {
      return 'That amount is too large.';
    }
    if (participants.length < AppConstants.minParticipants) {
      return 'Select at least two participants.';
    }
    if (!participants.containsKey(paidBy)) {
      return 'The payer must be one of the participants.';
    }
    final sum = participants.values.fold<num>(0, (a, b) => a + b);
    if ((sum - amount).abs() > AppConstants.epsilon) {
      return 'The split doesn\'t add up to the total yet.';
    }
    if (participants.values.any((v) => v <= 0)) {
      return 'Every participant\'s share must be positive.';
    }
    if (participants.keys.any((k) => k.isEmpty)) {
      return 'Some participants are missing.';
    }
    return null;
  }
}
