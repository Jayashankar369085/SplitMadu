import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_value.dart';
import '../core/utils/formatters.dart';

/// Firestore: users/{uid}
///
/// {
///   uid, name, email, photoUrl, createdAt, nameSearch,
///   onboardingCompleted
/// }
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    this.onboardingCompleted = false,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final bool onboardingCompleted;

  String get initials => Formatters.initials(name);

  String get nameSearch => name.toLowerCase();

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'photoUrl': photoUrl ?? '',
        'nameSearch': nameSearch,
        'onboardingCompleted': onboardingCompleted,

        // REAL Firestore server timestamp.
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory UserModel.fromFirestore(
    Map<String, dynamic> data,
    String uid,
  ) {
    return UserModel(
      uid: uid,
      name: (data['name'] as String?) ?? 'Unnamed',
      email: (data['email'] as String?) ?? '',
      photoUrl: () {
        final url = data['photoUrl'];

        if (url is String && url.isNotEmpty) {
          return url;
        }

        return null;
      }(),
      createdAt:
          readFirestoreDate(data['createdAt']) ?? DateTime.now(),
      onboardingCompleted:
          (data['onboardingCompleted'] as bool?) ?? false,
    );
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    bool? onboardingCompleted,
  }) =>
      UserModel(
        uid: uid,
        name: name ?? this.name,
        email: email,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt,
        onboardingCompleted:
            onboardingCompleted ?? this.onboardingCompleted,
      );
}