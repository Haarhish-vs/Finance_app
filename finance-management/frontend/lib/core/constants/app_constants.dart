/// Global constants matching domain values and database schema definitions
class AppConstants {
  AppConstants._();

  // Formatting defaults
  static const String currencySymbol = '₹';
  static const String currencyLocale = 'en_IN';
  static const String defaultDateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'dd MMM yyyy';

  // Customer Status Values
  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';

  // Payment Plan Status Values
  static const String planStatusActive = 'active';
  static const String planStatusCompleted = 'completed';
  static const String planStatusCancelled = 'cancelled';

  // Installment Status Values
  static const String installmentStatusPending = 'pending';
  static const String installmentStatusPaid = 'paid';
  static const String installmentStatusOverdue = 'overdue';

  // Payment Methods
  static const List<String> paymentMethods = [
    'cash',
    'bank_transfer',
    'check',
    'card',
    'upi',
  ];

  // Plan Frequencies
  static const List<String> frequencies = [
    'weekly',
    'biweekly',
    'monthly',
  ];
}
