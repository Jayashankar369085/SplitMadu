import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../core/constants/app_constants.dart';
import '../core/utils/error_mapper.dart';
import '../core/utils/formatters.dart';
import '../core/utils/fs_debug.dart';
import '../models/settlement_model.dart';

class SettlementRepository {
  SettlementRepository(
    this._firestore, {
    this._auth,
  });

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  CollectionReference<Map<String, dynamic>> get _settlements =>
      _firestore.collection(AppConstants.settlementsCollection);

  String? get currentUid => _auth?.currentUser?.uid;

  /// Record money actually paid from [from] to [to].
  ///
  /// [outstanding] is the current |balance| the client computed via the
  /// balance engine; the repo refuses settlements that overpay.
  Future<String> recordSettlement({
    required String from,
    required String to,
    required num amount,
    required num outstanding,
  }) async {
    final uid = currentUid;
    if (uid == null) throw const AppException('Please log in again.');
    if (from == to) {
      throw const AppException('A settlement needs two different people.');
    }
    if (amount <= 0) {
      throw const AppException('Amount must be greater than zero.');
    }
    if (MoneyUtils.round2(amount) >
        MoneyUtils.round2(outstanding) + AppConstants.epsilon) {
      throw AppException(
        'That\'s more than the outstanding '
        '${Formatters.money(outstanding)}.',
      );
    }
    if (uid != from && uid != to) {
      throw const AppException('You can only record your own settlements.');
    }

    final settlement = SettlementModel(
      id: '',
      from: from,
      to: to,
      amount: amount,
      createdBy: uid,
      createdAt: DateTime.now(),
    );

    try {
      final doc = await _settlements.add(settlement.toMap());
      return doc.id;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Real-time settlements involving the current user, newest first —
  /// single OR query, no composite index needed.
  Stream<List<SettlementModel>> watchMySettlements() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
return _settlements
        .where(
          Filter.or(
            Filter('from', isEqualTo: uid),
            Filter('to', isEqualTo: uid),
          ),
        )
        .snapshots()
        .handleError((Object e, StackTrace s) => FsDebug.error('SETTLE', e, s))
        .map((snap) => snap.docs
            .map((d) => SettlementModel.fromFirestore(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  /// All settlements between the current user and [otherUid], live.
  Stream<List<SettlementModel>> watchSettlementsWith(String otherUid) {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return _settlements
        .where(
          Filter.or(
            Filter('from', isEqualTo: uid),
            Filter('to', isEqualTo: uid),
          ),
        )
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SettlementModel.fromFirestore(d.data(), d.id))
            .where((s) =>
                (s.from == uid && s.to == otherUid) ||
                (s.from == otherUid && s.to == uid))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  Future<List<SettlementModel>> fetchMySettlements() async {
    final uid = currentUid;
    if (uid == null) return const [];
    try {
      final snaps = await Future.wait([
        _settlements.where('from', isEqualTo: uid).get(),
        _settlements.where('to', isEqualTo: uid).get(),
      ]);
      final map = <String, SettlementModel>{};
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          map[doc.id] = SettlementModel.fromFirestore(doc.data(), doc.id);
        }
      }
      final list = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}

