import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;

import '../core/constants/app_constants.dart';
import '../core/utils/error_mapper.dart';
import '../models/user_model.dart';

/// Firestore-backed user profiles + search.
class UserRepository {
  UserRepository(this._firestore, {this._auth});

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(AppConstants.usersCollection);

  String? get currentUid => _auth?.currentUser?.uid;

  /// Create the profile document right after registration.
  Future<void> createProfile(UserModel user) async {
  try {
    await _users.doc(user.uid).set(user.toMap());
  } catch (e) {
    throw ErrorMapper.map(e);
  }
}

  Future<UserModel?> getById(String uid) async {
    try {
      final snap = await _users.doc(uid).get();
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap.data()!, snap.id);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Stream<UserModel?> watchById(String uid) {
    return _users.doc(uid).snapshots().map(
          (s) => s.exists && s.data() != null
              ? UserModel.fromFirestore(s.data()!, s.id)
              : null,
        );
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? photoUrl,
    bool? onboardingCompleted,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': ?name,
        'nameSearch': ?(name?.toLowerCase()),
        'photoUrl': ?photoUrl,
        'onboardingCompleted': ?onboardingCompleted,
      };
      if (data.isEmpty) return;
      await _users.doc(uid).update(data);
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Persist onboarding completion for the current user's profile doc.
  Future<void> setOnboardingCompleted(String uid) async {
    try {
      await _users.doc(uid).update({'onboardingCompleted': true});
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  /// Search users by name prefix or exact email. Excludes [excludeUid] and
  /// users already in [friendUids]. Firestore has no case-insensitive search,
  /// so we filter client-side over a bounded set.
  Future<List<UserModel>> search({
    required String query,
    required String excludeUid,
    Set<String> friendUids = const {},
    int limit = AppConstants.searchResultLimit,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    try {
      final snap = await _users
          .orderBy('nameSearch')
          .limit(300)
          .get(const GetOptions(source: Source.serverAndCache));
      final results = <UserModel>[];
      for (final doc in snap.docs) {
        if (doc.id == excludeUid || friendUids.contains(doc.id)) continue;
        final user = UserModel.fromFirestore(doc.data(), doc.id);
        final matches =
            user.nameSearch.startsWith(q) || user.email.toLowerCase() == q;
        if (matches) {
          results.add(user);
          if (results.length >= limit) break;
        }
      }
      return results;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }

  Future<List<UserModel>> getByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    try {
      final uniqueUids = uids.toSet().toList();
      final chunks = <List<String>>[];
      for (var i = 0; i < uniqueUids.length; i += 10) {
        chunks.add(
          uniqueUids.sublist(i, (i + 10).clamp(0, uniqueUids.length)),
        );
      }
      final users = <UserModel>[];
      for (final chunk in chunks) {
        final snap = await _users
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        users.addAll(
          snap.docs.map((d) => UserModel.fromFirestore(d.data(), d.id)),
        );
      }
      return users;
    } catch (e) {
      throw ErrorMapper.map(e);
    }
  }
}
