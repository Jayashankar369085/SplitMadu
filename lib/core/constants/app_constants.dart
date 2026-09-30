/// App-wide constants for SplitMadu.
class AppConstants {
  AppConstants._();

  static const String appName = 'SplitMadu';
  static const String tagline = 'Eshtu aaytu? — split it, settle it, done.';

  // ---------- Firestore collections ----------
  static const String usersCollection = 'users';
  static const String friendshipsCollection = 'friendships';
  static const String friendRequestsCollection = 'friendRequests';
  static const String expensesCollection = 'expenses';
  static const String settlementsCollection = 'settlements';

  // ---------- Money ----------
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  /// Amounts are stored as rupees with decimals (num). All arithmetic goes
  /// through a penny-safe rounding helper in [MoneyUtils].
  static const double epsilon = 0.005;

  // ---------- Validation ----------
  static const int maxTitleLength = 120;
  static const int maxNameLength = 60;
  static const double maxExpenseAmount = 10000000; // ₹1 crore sanity cap
  static const int minParticipants = 2;

  // ---------- Search ----------
  static const int searchResultLimit = 20;
}

/// Expense categories with icons and display names.
enum ExpenseCategory {
  food('Food', '🍛'),
  travel('Travel', '🚗'),
  shopping('Shopping', '🛍️'),
  entertainment('Entertainment', '🎬'),
  rent('Rent', '🏠'),
  utilities('Utilities', '💡'),
  other('Other', '📦');

  const ExpenseCategory(this.label, this.emoji);

  final String label;
  final String emoji;

  /// Firestore string id (lowercase).
  String get id => name;

  static ExpenseCategory fromId(String id) => ExpenseCategory.values
      .firstWhere((c) => c.id == id, orElse: () => ExpenseCategory.other);

  /// [IconData] equivalents live in [CategoryIcons] to keep this class
  /// free of Flutter imports (models stay testable).
}

/// friendship status values.
class FriendshipStatus {
  FriendshipStatus._();

  static const String accepted = 'accepted';
  static const String pending = 'pending';
}
