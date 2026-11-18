/// Model representing a single customer's weekly installment due record
class WeeklyDueItem {
  final String installmentId;
  final String? customerId;
  final String customerName;
  final String phoneNumber;
  final double installmentAmount;
  final double amountPaid;
  final double outstandingBalance;
  final String dueDate;
  final String status;
  final String planCode;
  final int installmentNumber;

  const WeeklyDueItem({
    required this.installmentId,
    this.customerId,
    required this.customerName,
    required this.phoneNumber,
    required this.installmentAmount,
    required this.amountPaid,
    required this.outstandingBalance,
    required this.dueDate,
    required this.status,
    required this.planCode,
    required this.installmentNumber,
  });

  bool get isPaid => status.toLowerCase() == 'paid';
  bool get isOverdue => status.toLowerCase() == 'overdue';
  bool get isPending => !isPaid && !isOverdue;

  factory WeeklyDueItem.fromJson(Map<String, dynamic> json) {
    return WeeklyDueItem(
      installmentId: json['installment_id'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ?? 'Borrower',
      phoneNumber: json['phone_number'] as String? ?? 'N/A',
      installmentAmount: (json['installment_amount'] as num?)?.toDouble() ?? 0.0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      dueDate: json['due_date'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      planCode: json['plan_code'] as String? ?? '',
      installmentNumber: (json['installment_number'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Model representing a weekday's aggregated collections
class WeekdayCollectionGroup {
  final String weekday;
  final String date;
  final int customerCount;
  final double totalDue;
  final double totalCollected;
  final List<WeeklyDueItem> items;

  const WeekdayCollectionGroup({
    required this.weekday,
    required this.date,
    required this.customerCount,
    required this.totalDue,
    required this.totalCollected,
    required this.items,
  });

  factory WeekdayCollectionGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return WeekdayCollectionGroup(
      weekday: json['weekday'] as String? ?? '',
      date: json['date'] as String? ?? '',
      customerCount: (json['customer_count'] as num?)?.toInt() ?? 0,
      totalDue: (json['total_due'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (json['total_collected'] as num?)?.toDouble() ?? 0.0,
      items: rawItems.map((e) => WeeklyDueItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// Overall weekly collection response
class WeeklyCollectionsResponse {
  final String weekStart;
  final String weekEnd;
  final int totalWeeklyCustomers;
  final double totalWeeklyAmountDue;
  final double totalWeeklyCollected;
  final List<WeekdayCollectionGroup> weekdays;

  const WeeklyCollectionsResponse({
    required this.weekStart,
    required this.weekEnd,
    required this.totalWeeklyCustomers,
    required this.totalWeeklyAmountDue,
    required this.totalWeeklyCollected,
    required this.weekdays,
  });

  factory WeeklyCollectionsResponse.fromJson(Map<String, dynamic> json) {
    final rawDays = json['weekdays'] as List<dynamic>? ?? [];
    return WeeklyCollectionsResponse(
      weekStart: json['week_start'] as String? ?? '',
      weekEnd: json['week_end'] as String? ?? '',
      totalWeeklyCustomers: (json['total_weekly_customers'] as num?)?.toInt() ?? 0,
      totalWeeklyAmountDue: (json['total_weekly_amount_due'] as num?)?.toDouble() ?? 0.0,
      totalWeeklyCollected: (json['total_weekly_collected'] as num?)?.toDouble() ?? 0.0,
      weekdays: rawDays
          .map((e) => WeekdayCollectionGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

