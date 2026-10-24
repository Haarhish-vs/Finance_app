import '../../../core/network/api_client.dart';
import '../models/payment_model.dart';

class PaymentRepository {
  final ApiClient _client;

  PaymentRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Get list of recorded payments with optional filters
  Future<List<PaymentModel>> getPayments({
    String? customerId,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (customerId != null && customerId.isNotEmpty) {
      query['customer_id'] = customerId;
    }

    final response = await _client.get('/payments', queryParameters: query);
    final list = (response['data'] as List<dynamic>?) ?? [];
    return list.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
