import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Penny-safe money helpers. Amounts are stored as `num` rupees; every
/// comparison and aggregation rounds through [round2] to avoid float drift.
class MoneyUtils {
  MoneyUtils._();

  static double round2(num value) =>
      (value * 100).roundToDouble() / 100;

  static bool nearlyEqual(num a, num b) =>
      (a - b).abs() < AppConstants.epsilon;

  /// Split [total] into [count] equal shares; distribute leftover paise
  /// deterministically so shares always sum exactly to [total].
  static List<double> equalSplit(num total, int count) {
    if (count <= 0) return const [];
    final per = round2(total / count);
    final shares = List<double>.filled(count, per);
    var remainder = round2(total - per * count);
    // Spread remainder in 0.01 steps across the first participants.
    var i = 0;
    while (remainder.abs() >= 0.01 && i < count) {
      final step = remainder.isNegative ? -0.01 : 0.01;
      shares[i] = round2(shares[i] + step);
      remainder = round2(remainder - step);
      i++;
    }
    return shares;
  }

  static bool isValidAmount(num? value) =>
      value != null && value > 0 && value <= AppConstants.maxExpenseAmount;
}

/// Display formatters.
class Formatters {
  Formatters._();

  static final NumberFormat _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _moneyCompact = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// ₹1,234.50
  static String money(num value) {
    if (value == value.roundToDouble()) return _moneyCompact.format(value);
    return _money.format(value);
  }

  /// +₹1,650 / −₹800 (uses proper minus sign).
  static String moneySigned(num value) {
    final sign = value > 0 ? '+' : (value < 0 ? '−' : '');
    return '$sign${money(value.abs())}';
  }

  /// "Today", "Yesterday", "12 Mar", "12 Mar 2025".
  static String date(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (dt.year == now.year) return DateFormat('d MMM').format(dt);
    return DateFormat('d MMM yyyy').format(dt);
  }

  /// "Good morning/afternoon/evening".
  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// "JRK" style initials for avatars (max 2 letters).
  static String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
