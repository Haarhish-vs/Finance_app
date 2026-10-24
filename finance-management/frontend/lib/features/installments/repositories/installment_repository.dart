import '../../../core/network/api_client.dart';
import '../../payments/models/payment_model.dart';
import '../models/installment_model.dart';

class InstallmentListResult {
  final List<InstallmentModel> installments;
  final int totalRecords;
  final int totalPages;
  final int currentPage;

  const InstallmentListResult({
    required this.installments,
    required this.totalRecords,
    required this.totalPages,
    required this.currentPage,
  });
}

class InstallmentRepository {
  final ApiClient _client;

  InstallmentRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// List installments with filters & pagination
  Future<InstallmentListResult> getInstallments({
    String? planId,
    String? customerId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (planId != null && planId.isNotEmpty) query['plan_id'] = planId;
    if (customerId != null && customerId.isNotEmpty) query['customer_id'] = customerId;
    if (status != null && status.isNotEmpty && status != 'all') query['status'] = status;

    final response = await _client.get('/installments', queryParameters: query);
    final dataList = (response['data'] as List<dynamic>?) ?? [];
    final pagination = response['pagination'] as Map<String, dynamic>?;

    final installments = dataList
        .map((e) => InstallmentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return InstallmentListResult(
      installments: installments,
      totalRecords: pagination?['totalRecords'] as int? ?? installments.length,
      totalPages: pagination?['totalPages'] as int? ?? 1,
      currentPage: pagination?['page'] as int? ?? page,
    );
  }

  /// Get single installment details
  Future<InstallmentModel> getInstallmentById(String id) async {
    final response = await _client.get('/installments/$id');
    final data = response['data'] as Map<String, dynamic>;
    return InstallmentModel.fromJson(data);
  }

  /// Update permitted installment details (due date and amount)
  Future<InstallmentModel> updateInstallment(
    String id, {
    String? dueDate,
    double? amountDue,
  }) async {
    final body = <String, dynamic>{};
    if (dueDate != null) body['due_date'] = dueDate;
    if (amountDue != null) body['amount_due'] = amountDue;

    final response = await _client.patch('/installments/$id', body: body);
    final data = response['data'] as Map<String, dynamic>;
    return InstallmentModel.fromJson(data);
  }

  /// Record a payment towards an installment
  Future<Map<String, dynamic>> recordPayment({
    required String installmentId,
    required double amount,
    required String paymentDate,
    String paymentMethod = 'cash',
    String? notes,
  }) async {
    final response = await _client.post(
      '/installments/$installmentId/payments',
      body: {
        'amount': amount,
        'payment_date': paymentDate,
        'payment_method': paymentMethod,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    final payment = PaymentModel.fromJson(data['payment'] as Map<String, dynamic>);
    final installment = InstallmentModel.fromJson(data['installment'] as Map<String, dynamic>);

    return {
      'payment': payment,
      'installment': installment,
    };
  }

  /// Get payment history for an installment
  Future<List<PaymentModel>> getPayments(String installmentId) async {
    final response = await _client.get('/installments/$installmentId/payments');
    final list = (response['data'] as List<dynamic>?) ?? [];
    return list.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
