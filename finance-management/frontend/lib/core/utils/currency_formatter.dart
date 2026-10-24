import 'package:intl/intl.dart';

/// Central currency formatter enforcing Indian Rupee (INR - ₹) formatting across the entire app
class CurrencyFormatter {
  CurrencyFormatter._();

  static const String symbol = '₹';
  static const String locale = 'en_IN';

  static final NumberFormat _inrWithDecimals = NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: 2,
  );

  static final NumberFormat _inrCompact = NumberFormat.currency(
    locale: locale,
    symbol: symbol,
    decimalDigits: 0,
  );

  /// Formats amount in Indian Rupees with 2 decimal places (e.g. ₹500.00, ₹1,500.00, ₹25,000.00, ₹1,25,000.00)
  static String format(dynamic amount, {bool showDecimals = true}) {
    final num numAmount = _toNum(amount);
    if (showDecimals) {
      return _inrWithDecimals.format(numAmount);
    }
    return _inrCompact.format(numAmount);
  }

  /// Formats amount dropping decimals if it is a whole number (e.g. ₹500, ₹1,500, ₹25,000, ₹1,25,000, ₹12,50,000)
  static String formatSmart(dynamic amount) {
    final num numAmount = _toNum(amount);
    if (numAmount % 1 == 0) {
      return _inrCompact.format(numAmount);
    }
    return _inrWithDecimals.format(numAmount);
  }

  static num _toNum(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val;
    if (val is String) {
      return num.tryParse(val.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
    }
    return 0;
  }
}
