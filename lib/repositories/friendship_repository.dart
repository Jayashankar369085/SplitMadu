import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../core/constants/app_constants.dart';
import '../core/utils/error_mapper.dart';
import '../core/utils/fs_debug.dart';
import '../models/friendship_model.dart';
import '../models/user_model.dart';
import 'user_repository.dart';

class FriendshipRepository {
  FriendshipRepository(this._firestore, {FirebaseAuth? auth})
      : _auth = auth,
        _users = UserRepository(_firestore, auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final UserRepository _users;

  CollectionReference<Map<String, dynamic>> get _friendships =>
      _firestore.collection(AppConstants.friendshipsCollection);

  String? get currentUid => _auth?.currentUser?.uid;

  /// Real-time list of the current user's friendships (either side).
  ///
  /// Uses two simple equality queries merged client-side instead of one
  /// Filter.or() disjunction: rules-friendly (each query is individually
  /// provable against `allow get, list: if involvesMe()`), and avoids the
  /// permission-denied the OR form triggered at runtime.
  Stream<List<FriendshipModel>> watchMyFriendships() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
final controller = StreamController<List<FriendshipModel>>();
    final byId = <String, FriendshipModel>{};
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) controller.add(merged);
    }

    void onSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final d in snap.docs) {
        byId[d.id] = FriendshipModel.fromFirestore(d.data(), d.id);
      }
      emit();
    }

    void onError(Object e, StackTrace s) {
      FsDebug.error('FRIENDS', e, s);
      if (!controller.isClosed) controller.addError(e, s);
    }

    controller.onListen = () {
      subs.add(_friendships.where('user1', isEqualTo: uid).snapshots().listen(
            onSnapshot,
            onError: onError,
          ));
      subs.add(_friendships.where('user2', isEqualTo: uid).snapshots().listen(
            onSnapshot,
            onError: onError,
          ));
    };
    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
      subs.clear();
    };
    return controller.stream;
  }

  /// Stream the current user's friends as [UserModel]s, reacting live to
  /// friendship changes.
  Stream<List<UserModel>> watchFriends() {
    final uid = currentUid;
    if (uid == null) return const Stream.empty();
    return watchMyFriendships().asyncMapFirst((friendships) async {
      final friendIds = friendships
          .map((f) => f.otherUser(uid))
          .where((id) => id.isNotEmpty && id != uid)
          .toSet()
          .toList();
      if (friendIds.isEmpty) return <UserModel>[];
      return _users.getByIds(friendIds);
    });
  }

  Future<List<FriendshipModel>> fetchMyFriendships() async {
    final uid = currentUid;
    if (uid == null) return const [];
    try {
      // Two targeted queries (user1 / user2) — avoids per-friend reads.
      final results = await Future.wait([
        _friendships.where('user1', isEqualTo: uid).get(),
        _friendships.where('user2', isEqualTo: uid).get(),
      ]);
      final map = <String, FriendshipModel>{};
      for (final snap in results) {
        for (final doc in snap.docs) {
          map[doc.id] = FriendshipModel.fromFirestore(doc.data(), doc.id);
        }
      }
      return map.values.toList();
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// All friendship docs that involve [uidA] or [uidB] — used by the balance
  /// engine to preresolve participants. Two reads no matter the friend count.
  Future<List<FriendshipModel>> fetchFriendshipsOf(String uid) async {
    try {
      final results = await Future.wait([
        _friendships.where('user1', isEqualTo: uid).get(),
        _friendships.where('user2', isEqualTo: uid).get(),
      ]);
      return [
        for (final snap in results)
          for (final doc in snap.docs)
            FriendshipModel.fromFirestore(doc.data(), doc.id),
      ];
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Adds [friendUid] as an accepted friend of the current user.
  ///
  /// Throws [AppException] on self-add or duplicate (guards are client-side;
  /// rules enforce the rest).
  Future<void> addFriend(String friendUid) async {
    final uid = currentUid;
    if (uid == null) {
      throw const AppException('Please log in again.');
    }
    if (friendUid == uid) {
      throw const AppException('You can\'t add yourself as a friend.');
    }
    final id = FriendshipModel.docIdFor(uid, friendUid);
    try {
      final existing = await _friendships.doc(id).get();
      if (existing.exists) {
        throw const AppException('You\'re already friends with this person.');
      }
      final friendship = FriendshipModel(
        id: id,
        user1: uid,
        user2: friendUid,
        status: FriendshipStatus.accepted,
        createdAt: DateTime.now(),
      );
      await _friendships.doc(id).set(friendship.toMap());
    } on AppException {
      rethrow;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Convenience: add a friend directly from a searched [UserModel].
  Future<void> addFriendFromUser(UserModel user) => addFriend(user.uid);
}

// ---- tiny stream helper ----

extension _StreamX<T> on Stream<T> {
  /// Maps each item through an async function.
  Stream<R> asyncMapFirst<R>(Future<R> Function(T) mapper) async* {
    await for (final item in this) {
      yield await mapper(item);
    }
  }
}
