import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_value.dart';

/// Firestore: friendships/{id}
/// { user1, user2, status, createdAt } — user1 < user2 (canonical UID order).
class FriendshipModel {
  const FriendshipModel({
    required this.id,
    required this.user1,
    required this.user2,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String user1;
  final String user2;
  final String status;
  final DateTime createdAt;

  /// Canonical Firestore document id for a pair.
  static String docIdFor(String uidA, String uidB) {
    final a = uidA.compareTo(uidB) <= 0 ? uidA : uidB;
    final b = uidA.compareTo(uidB) <= 0 ? uidB : uidA;
    return '${a}_$b';
  }

  /// The other participant, given one side of the friendship.
  String otherUser(String uid) => uid == user1 ? user2 : user1;

  bool involves(String uid) => uid == user1 || uid == user2;

  Map<String, dynamic> toMap() => {
        'user1': user1.compareTo(user2) <= 0 ? user1 : user2,
        'user2': user1.compareTo(user2) <= 0 ? user2 : user1,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory FriendshipModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return FriendshipModel(
      id: id,
      user1: (data['user1'] as String?) ?? '',
      user2: (data['user2'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'accepted',
      createdAt: readFirestoreDate(data['createdAt']) ?? DateTime.now(),
    );
  }
}