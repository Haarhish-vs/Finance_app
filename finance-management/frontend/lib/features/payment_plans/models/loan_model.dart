/// Model representing a Loan / Financing Agreement
class LoanModel {
  final String id;
  final String planCode;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String title;
  final double principalAmount;
  final double interestRate;
  final double totalAmount;
  final double totalRepayment;
  final double totalInterest;
  final double monthlyInterestAmount;
  final double? durationInMonths;
  final double downPayment;
  final int totalInstallments;
  final String frequency;
  final String startDate;
  final String? endDate;
  final String status;
  final String notes;
  final double amountCollected;
  final double outstandingBalance;
  final double progress;
  final int paidInstallmentsCount;
  final int overdueInstallmentsCount;
  final String? nextDueDate;
  final double nextDueAmount;
  final DateTime createdAt;

  const LoanModel({
    required this.id,
    required this.planCode,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.title,
    required this.principalAmount,
    required this.interestRate,
    required this.totalAmount,
    required this.totalRepayment,
    required this.totalInterest,
    required this.monthlyInterestAmount,
    this.durationInMonths,
    this.downPayment = 0.0,
    required this.totalInstallments,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.status,
    this.notes = '',
    this.amountCollected = 0.0,
    this.outstandingBalance = 0.0,
    this.progress = 0.0,
    this.paidInstallmentsCount = 0,
    this.overdueInstallmentsCount = 0,
    this.nextDueDate,
    this.nextDueAmount = 0.0,
    required this.createdAt,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isWeekly => frequency.toLowerCase() == 'weekly';
  double get progressPercentage => progress > 1.0 ? progress : (progress * 100.0);

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;

    return LoanModel(
      id: json['id'] as String? ?? '',
      planCode: json['plan_code'] as String? ?? json['loan_code'] as String? ?? '',
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ??
          (customer != null ? customer['full_name'] as String? ?? '' : 'Borrower'),
      customerPhone: json['customer_phone'] as String? ??
          (customer != null ? customer['phone'] as String? : null),
      title: json['title'] as String? ?? 'Personal Loan',
      principalAmount: (json['principal_amount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      totalRepayment: (json['total_repayment'] as num?)?.toDouble() ??
          (json['total_amount'] as num?)?.toDouble() ??
          0.0,
      totalInterest: (json['total_interest'] as num?)?.toDouble() ?? 0.0,
      monthlyInterestAmount: (json['monthly_interest_amount'] as num?)?.toDouble() ?? 0.0,
      durationInMonths: (json['duration_in_months'] as num?)?.toDouble(),
      downPayment: (json['down_payment'] as num?)?.toDouble() ?? 0.0,
      totalInstallments: (json['total_installments'] as num?)?.toInt() ?? 1,
      frequency: (json['frequency'] as String? ?? 'monthly').toLowerCase(),
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String?,
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String? ?? '',
      amountCollected: (json['amount_collected'] as num?)?.toDouble() ??
          (json['total_collected'] as num?)?.toDouble() ??
          0.0,
      outstandingBalance: (json['outstanding_balance'] as num?)?.toDouble() ?? 0.0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      paidInstallmentsCount: (json['paid_installments_count'] as num?)?.toInt() ?? 0,
      overdueInstallmentsCount: (json['overdue_installments_count'] as num?)?.toInt() ?? 0,
      nextDueDate: json['next_due_date'] as String?,
      nextDueAmount: (json['next_due_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
