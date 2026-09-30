/// App-level exception with a user-safe message.
///
/// Repositories translate raw Firebase exceptions into [AppException] so the
/// UI never surfaces SDK internals.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;

  /// Machine-readable code (mostly for logging).
  final String? code;

  @override
  String toString() => message;
}

/// Maps Firebase Auth / Firestore errors to friendly copy.
class ErrorMapper {
  ErrorMapper._();

  /// Debug-only: surface unknown/unknown-mapped codes in the log so errors
  /// are never silently swallowed during development.
  static void _logUnknown(String? code, String message) {
    assert(() {
      // ignore: avoid_print
      print('[ErrorMapper] unmapped error code=$code message=$message');
      return true;
    }());
  }

  static const Map<String, String> _authMessages = {
    'invalid-email': 'That email address doesn\'t look right.',
    'user-disabled': 'This account has been disabled. Contact support.',
    'user-not-found': 'No account found with that email.',
    'wrong-password': 'Incorrect password. Please try again.',
    'invalid-credential': 'Incorrect email or password.',
    'email-already-in-use': 'An account already exists with this email.',
    'weak-password': 'Password is too weak — use at least 6 characters.',
    'too-many-requests': 'Too many attempts. Please wait a moment.',
    'network-request-failed': 'Network error. Check your connection.',
    'operation-not-allowed': 'Email sign-in is not enabled yet.',
    'requires-recent-login': 'Please log in again and retry.',
  };

  static const Map<String, String> _firestoreMessages = {
    'permission-denied':
        'You don\'t have permission for that. Please log in again.',
    'unavailable': 'Service is unreachable. Check your connection.',
    'deadline-exceeded': 'The request timed out. Please try again.',
    'aborted': 'The operation conflicted with another change. Retry.',
    'not-found': 'That record no longer exists.',
    'already-exists': 'That record already exists.',
    'resource-exhausted': 'Too many requests. Please wait a moment.',
    'failed-precondition':
        'This needs a database index that\'s still building. Try again shortly.',
  };

  /// Map any error object to a friendly [AppException].
  static AppException map(Object error) {
    if (error is AppException) return error;

    final code = _extractCode(error);
    if (code == null) {
      _logUnknown(null, error.toString());
      return const AppException('Something went wrong. Please try again.');
    }

    final friendly = _authMessages[code] ?? _firestoreMessages[code];
    if (friendly == null) {
      _logUnknown(code, error.toString());
      return AppException(
        'Something went wrong. Please try again.',
        code: code,
      );
    }
    return AppException(friendly, code: code);
  }

  /// Pull the `code` out of FirebaseAuthException / FirebaseException-like
  /// objects without importing the Firebase packages here.
  static String? _extractCode(Object error) {
    // ignore: avoid_dynamic_calls
    final dynamic e = error;
    final code = e.code;
    if (code is String && code.isNotEmpty) {
      // Firestore codes can look like "firestore/permission-denied".
      final slash = code.indexOf('/');
      return slash >= 0 ? code.substring(slash + 1) : code;
    }
    return null;
  }
}
