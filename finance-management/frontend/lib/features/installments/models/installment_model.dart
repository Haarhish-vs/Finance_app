/// Model representing a single installment schedule item
class InstallmentModel {
  final String id;
  final String planId;
  final String? customerId;
  final String? customerName;
  final String? planCode;
  final int installmentNumber;
  final String periodLabel;
  final String dueDate;
  final double amountDue;
  final double amountPaid;
  final double outstandingBalance;
  final String status;
  final String? paidAt;
  final DateTime createdAt;

  const InstallmentModel({
    required this.id,
    required this.planId,
    this.customerId,
    this.customerName,
    this.planCode,
    required this.installmentNumber,
    required this.periodLabel,
    required this.dueDate,
    required this.amountDue,
    this.amountPaid = 0.0,
    required this.outstandingBalance,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  bool get isPaid => status.toLowerCase() == 'paid' || amountPaid >= amountDue;
  bool get isPartiallyPaid => status.toLowerCase() == 'partially_paid' || (amountPaid > 0 && amountPaid < amountDue);
  bool get isOverdue => status.toLowerCase() == 'overdue';
  bool get isPending => status.toLowerCase() == 'pending' && !isOverdue;

  factory InstallmentModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final plan = json['plan'] as Map<String, dynamic>?;

    final due = (json['amount_due'] as num?)?.toDouble() ?? 0.0;
    final paid = (json['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final outstanding = (json['outstanding_balance'] as num?)?.toDouble() ??
        (due > paid ? due - paid : 0.0);

    return InstallmentModel(
      id: json['id'] as String? ?? '',
      planId: json['plan_id'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ??
          (customer != null ? customer['full_name'] as String? : null),
      planCode: json['plan_code'] as String? ??
          (plan != null ? plan['plan_code'] as String? : null),
      installmentNumber: (json['installment_number'] as num?)?.toInt() ?? 1,
      periodLabel: json['period_label'] as String? ?? 'Month ${json['installment_number'] ?? 1}',
      dueDate: json['due_date'] as String? ?? '',
      amountDue: due,
      amountPaid: paid,
      outstandingBalance: outstanding,
      status: json['status'] as String? ?? 'pending',
      paidAt: json['paid_at'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  InstallmentModel copyWith({
    String? dueDate,
    double? amountDue,
    double? amountPaid,
    String? status,
  }) {
    final newDue = amountDue ?? this.amountDue;
    final newPaid = amountPaid ?? this.amountPaid;
    return InstallmentModel(
      id: id,
      planId: planId,
      customerId: customerId,
      customerName: customerName,
      planCode: planCode,
      installmentNumber: installmentNumber,
      periodLabel: periodLabel,
      dueDate: dueDate ?? this.dueDate,
      amountDue: newDue,
      amountPaid: newPaid,
      outstandingBalance: Math.max(0.0, newDue - newPaid),
      status: status ?? this.status,
      paidAt: paidAt,
      createdAt: createdAt,
    );
  }
}

class Math {
  static double max(double a, double b) => a > b ? a : b;
}
