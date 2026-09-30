import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_value.dart';

/// Firestore: friendRequests/{id}
/// { senderId, receiverId, status, createdAt }
/// Document id is canonical: "{senderId}_{receiverId}".
class FriendRequestModel {
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusDeclined = 'declined';

  const FriendRequestModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;

  static String docIdFor(String senderId, String receiverId) =>
      '${senderId}_$receiverId';

  bool get isPending => status == statusPending;

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'receiverId': receiverId,
        'status': status,

        // Use Firebase's actual server timestamp sentinel.
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory FriendRequestModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    return FriendRequestModel(
      id: id,
      senderId: (data['senderId'] as String?) ?? '',
      receiverId: (data['receiverId'] as String?) ?? '',
      status: (data['status'] as String?) ?? statusPending,
      createdAt: readFirestoreDate(data['createdAt']) ?? DateTime.now(),
    );
  }
}