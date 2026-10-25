import '../../../core/network/api_client.dart';
import '../models/customer_model.dart';

/// Customer Repository executing backend API calls via ApiClient
class CustomerRepository {
  final ApiClient _apiClient;

  CustomerRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Retrieve paginated customer list with optional search and status filter
  Future<CustomerListResult> getCustomers({
    String? search,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status != 'all') 'status': status,
    };

    final response = await _apiClient.get('/customers', queryParameters: queryParams);

    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      final data = response['data'] as Map<String, dynamic>;
      final rawList = data['customers'] as List<dynamic>? ?? [];
      final customers = rawList
          .map((item) => CustomerModel.fromJson(item as Map<String, dynamic>))
          .toList();
      final pagination = CustomerPagination.fromJson(data['pagination'] as Map<String, dynamic>?);

      return CustomerListResult(customers: customers, pagination: pagination);
    }

    return const CustomerListResult(customers: [], pagination: CustomerPagination());
  }

  /// Retrieve single customer by UUID
  Future<CustomerModel> getCustomerById(String id) async {
    final response = await _apiClient.get('/customers/$id');
    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return CustomerModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Invalid customer response format from server');
  }

  /// Create a new customer
  Future<CustomerModel> createCustomer(Map<String, dynamic> customerData) async {
    final response = await _apiClient.post('/customers', body: customerData);
    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return CustomerModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to create customer');
  }

  /// Update existing customer details
  Future<CustomerModel> updateCustomer(String id, Map<String, dynamic> customerData) async {
    final response = await _apiClient.patch('/customers/$id', body: customerData);
    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return CustomerModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to update customer');
  }

  /// Update customer active status
  Future<CustomerModel> updateCustomerStatus(String id, String status) async {
    final response = await _apiClient.patch('/customers/$id/status', body: {'status': status});
    if (response is Map<String, dynamic> && response['data'] is Map<String, dynamic>) {
      return CustomerModel.fromJson(response['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to update customer status');
  }

  /// Permanently delete customer from database
  Future<void> deleteCustomer(String id) async {
    await _apiClient.delete('/customers/$id');
  }
}
