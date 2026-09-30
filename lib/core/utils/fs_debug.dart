import 'package:flutter/foundation.dart';

/// TEMPORARY diagnostics: logs the exact Firestore query each listener
/// issues and the precise exception origin. Debug builds only — release
/// builds compile these calls to no-ops.
///
/// Remove once the permission-denied source is confirmed.
class FsDebug {
  FsDebug._();

  static String _short(String? uid) {
    if (uid == null) return 'NULL!';
    return uid.length > 10 ? '${uid.substring(0, 10)}…' : uid;
  }

  /// Log the query a listener is about to start.
  static void query(
    String tag, {
    required String collection,
    required String? uid,
    required String filters,
    String orderBy = '-',
    Object? limit = '-',
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[FS][$tag] LISTEN $collection | uid=${_short(uid)} | where=($filters) '
      '| orderBy=$orderBy | limit=$limit',
    );
  }

  /// Log a one-shot read.
  static void get(String tag, String description) {
    if (!kDebugMode) return;
    debugPrint('[FS][$tag] GET $description');
  }

  /// Log the exact error + origin for a failing listener.
  static void error(String tag, Object error, StackTrace stack) {
    if (!kDebugMode) return;
    final origin = stack
        .toString()
        .split('\n')
        .where((l) => l.contains('package:splitmadu'))
        .take(3)
        .join(' <- ');
    debugPrint('[FS][$tag] ERROR ${error.runtimeType}: $error');
    debugPrint('[FS][$tag] origin: $origin');
  }
}
