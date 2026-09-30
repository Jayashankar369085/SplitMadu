import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../core/constants/app_constants.dart';
import '../core/utils/error_mapper.dart';
import '../core/utils/fs_debug.dart';
import '../models/friend_request_model.dart';
import '../models/friendship_model.dart';

/// Request/accept friend flow.
///
/// Firestore:
///   friendRequests/{senderId}_{receiverId}
///   friendships/{user1}_{user2}
///
/// Existence checks use queries instead of direct document GETs.
/// This is important because Firestore security rules cannot evaluate
/// resource.data for a document that does not exist.
class FriendRequestRepository {
  FriendRequestRepository(this._firestore, {this._auth});

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(AppConstants.friendRequestsCollection);

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection(AppConstants.friendshipsCollection);

  String? get currentUid => _auth?.currentUser?.uid;

  /// Live list of pending requests received by the current user.
  Stream<List<FriendRequestModel>> watchIncoming() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    return _requests
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: FriendRequestModel.statusPending)
        .snapshots()
        .handleError(
          (Object e, StackTrace s) => FsDebug.error('REQ-IN', e, s),
        )
        .map(
          (snap) => snap.docs
              .map(
                (d) => FriendRequestModel.fromFirestore(d.data(), d.id),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// Live list of pending requests sent by the current user.
  Stream<List<FriendRequestModel>> watchOutgoing() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();

    return _requests
        .where('senderId', isEqualTo: uid)
        .where('status', isEqualTo: FriendRequestModel.statusPending)
        .snapshots()
        .handleError(
          (Object e, StackTrace s) => FsDebug.error('REQ-OUT', e, s),
        )
        .map(
          (snap) => snap.docs
              .map(
                (d) => FriendRequestModel.fromFirestore(d.data(), d.id),
              )
              .toList(),
        );
  }

  /// Outcome of [send]: what the UI should display.
  Future<SendRequestOutcome> send(String receiverUid) async {
    final uid = currentUid;

    if (uid == null) {
      throw const AppException('Please log in again.');
    }

    if (receiverUid == uid) {
      throw const AppException(
        'You can\'t send a request to yourself.',
      );
    }

    if (receiverUid.isEmpty) {
      throw const AppException(
        'That user doesn\'t exist anymore.',
      );
    }

    try {
      // ------------------------------------------------------------
      // CASE 1: Already friends?
      //
      // DO NOT use:
      //   _friendships.doc(friendshipId).get()
      //
      // because a missing document cannot satisfy a rule that uses
      // resource.data.
      //
      // Instead, perform a constrained query.
      // ------------------------------------------------------------

      final user1 =
          uid.compareTo(receiverUid) <= 0 ? uid : receiverUid;

      final user2 =
          uid.compareTo(receiverUid) <= 0 ? receiverUid : uid;

      FsDebug.get(
        'SEND-FRIEND',
        'QUERY friendships where user1=$user1 AND user2=$user2',
      );

      final friendshipQuery = await _friendships
          .where('user1', isEqualTo: user1)
          .where('user2', isEqualTo: user2)
          .limit(1)
          .get();

      if (friendshipQuery.docs.isNotEmpty) {
        return SendRequestOutcome.alreadyFriends;
      }

      // ------------------------------------------------------------
      // CASE 2: The other user already sent me a pending request?
      //
      // Again, use a query instead of GET because the document may
      // not exist.
      // ------------------------------------------------------------

      FsDebug.get(
        'SEND-FRIEND',
        'QUERY incoming request sender=$receiverUid receiver=$uid',
      );

      final incomingQuery = await _requests
          .where('senderId', isEqualTo: receiverUid)
          .where('receiverId', isEqualTo: uid)
          .where(
            'status',
            isEqualTo: FriendRequestModel.statusPending,
          )
          .limit(1)
          .get();

      if (incomingQuery.docs.isNotEmpty) {
        return SendRequestOutcome.incomingRequestExists;
      }

      // ------------------------------------------------------------
      // CASE 3: I already sent them a pending request?
      // ------------------------------------------------------------

      FsDebug.get(
        'SEND-FRIEND',
        'QUERY outgoing request sender=$uid receiver=$receiverUid',
      );

      final outgoingQuery = await _requests
          .where('senderId', isEqualTo: uid)
          .where('receiverId', isEqualTo: receiverUid)
          .where(
            'status',
            isEqualTo: FriendRequestModel.statusPending,
          )
          .limit(1)
          .get();

      if (outgoingQuery.docs.isNotEmpty) {
        return SendRequestOutcome.requestAlreadySent;
      }

      // ------------------------------------------------------------
      // CASE 4: Create new request.
      // ------------------------------------------------------------

      final outgoingId =
          FriendRequestModel.docIdFor(uid, receiverUid);

      final request = FriendRequestModel(
        id: outgoingId,
        senderId: uid,
        receiverId: receiverUid,
        status: FriendRequestModel.statusPending,
        createdAt: DateTime.now(),
      );

      FsDebug.get(
        'SEND-FRIEND',
        'CREATE friendRequests/$outgoingId',
      );

      await _requests
          .doc(outgoingId)
          .set(request.toMap());

      return SendRequestOutcome.sent;
    } catch (e, s) {
      FsDebug.error('SEND-FRIEND', e, s);
      throw ErrorMapper.map(e);
    }
  }

  /// Accept an incoming pending request.
  ///
  /// Updates the request to accepted and creates the canonical
  /// friendship document atomically.
  Future<void> accept(FriendRequestModel request) async {
    final uid = currentUid;

    if (uid == null) {
      throw const AppException('Please log in again.');
    }

    if (request.receiverId != uid) {
      throw const AppException(
        'This request wasn\'t sent to you.',
      );
    }

    if (!request.isPending) {
      throw const AppException(
        'This request was already handled.',
      );
    }

    try {
      final batch = _firestore.batch();

      final requestRef = _requests.doc(
        FriendRequestModel.docIdFor(
          request.senderId,
          uid,
        ),
      );

      batch.update(requestRef, {
        'status': FriendRequestModel.statusAccepted,
      });

      final friendship = FriendshipModel(
        id: FriendshipModel.docIdFor(
          uid,
          request.senderId,
        ),
        user1: uid,
        user2: request.senderId,
        status: FriendshipStatus.accepted,
        createdAt: DateTime.now(),
      );

      batch.set(
        _friendships.doc(friendship.id),
        friendship.toMap(),
      );

      await batch.commit();
    } catch (e, s) {
      FsDebug.error('ACCEPT-FRIEND', e, s);
      throw ErrorMapper.map(e);
    }
  }

  /// Decline an incoming pending request.
  Future<void> decline(FriendRequestModel request) async {
    final uid = currentUid;

    if (uid == null) {
      throw const AppException('Please log in again.');
    }

    if (request.receiverId != uid) {
      throw const AppException(
        'This request wasn\'t sent to you.',
      );
    }

    try {
      await _requests
          .doc(
            FriendRequestModel.docIdFor(
              request.senderId,
              uid,
            ),
          )
          .update({
            'status': FriendRequestModel.statusDeclined,
          });
    } catch (e, s) {
      FsDebug.error('DECLINE-FRIEND', e, s);
      throw ErrorMapper.map(e);
    }
  }

  /// Cancel a request I previously sent.
  Future<void> cancel(FriendRequestModel request) async {
    final uid = currentUid;

    if (uid == null || request.senderId != uid) {
      throw const AppException(
        'You can only cancel your own requests.',
      );
    }

    try {
      await _requests.doc(request.id).update({
        'status': FriendRequestModel.statusDeclined,
      });
    } catch (e, s) {
      FsDebug.error('CANCEL-FRIEND', e, s);
      throw ErrorMapper.map(e);
    }
  }
}

/// What the UI should show after attempting to send a request.
enum SendRequestOutcome {
  sent,
  requestAlreadySent,
  incomingRequestExists,
  alreadyFriends,
}