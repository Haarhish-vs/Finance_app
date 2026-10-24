/// Model representing a payment transaction record
class PaymentModel {
  final String id;
  final String paymentReference;
  final String? customerId;
  final String customerName;
  final String? planId;
  final String? planCode;
  final String? installmentId;
  final double amount;
  final String paymentDate;
  final String paymentMethod;
  final String? notes;
  final String? receiptUrl;

  const PaymentModel({
    required this.id,
    required this.paymentReference,
    this.customerId,
    required this.customerName,
    this.planId,
    this.planCode,
    this.installmentId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.notes,
    this.receiptUrl,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'] as Map<String, dynamic>?;
    final plan = json['payment_plans'] as Map<String, dynamic>?;

    return PaymentModel(
      id: json['id'] as String? ?? '',
      paymentReference: json['payment_reference'] as String? ?? 'RCP',
      customerId: json['customer_id'] as String?,
      customerName: json['customer_name'] as String? ??
          (customer != null ? customer['full_name'] as String? ?? 'Borrower' : 'Borrower'),
      planId: json['plan_id'] as String?,
      planCode: json['plan_code'] as String? ??
          (plan != null ? plan['plan_code'] as String? : null),
      installmentId: json['installment_id'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: json['payment_date'] as String? ?? '',
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      notes: json['notes'] as String?,
      receiptUrl: json['receipt_url'] as String?,
    );
  }
}
