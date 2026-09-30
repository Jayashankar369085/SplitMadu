import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads a Firestore timestamp safely.
///
/// Firestore normally returns a Timestamp, but this helper also handles
/// DateTime values for local/test data.
DateTime? readFirestoreDate(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}