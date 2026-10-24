import '../../../core/network/api_client.dart';
import '../../installments/models/installment_model.dart';
import '../models/loan_model.dart';

class LoanListResult {
  final List<LoanModel> loans;
  final int totalRecords;
  final int totalPages;
  final int currentPage;

  const LoanListResult({
    required this.loans,
    required this.totalRecords,
    required this.totalPages,
    required this.currentPage,
  });
}

class LoanCalculationPreview {
  final double principal;
  final double monthlyInterestRate;
  final String frequency;
  final int totalInstallments;
  final double durationInMonths;
  final double monthlyInterest;
  final double totalInterest;
  final double totalRepayment;
  final double baseInstallment;
  final String startDate;
  final String firstDueDate;
  final String finalDueDate;
  final List<Map<String, dynamic>> installments;

  const LoanCalculationPreview({
    required this.principal,
    required this.monthlyInterestRate,
    required this.frequency,
    required this.totalInstallments,
    required this.durationInMonths,
    required this.monthlyInterest,
    required this.totalInterest,
    required this.totalRepayment,
    required this.baseInstallment,
    required this.startDate,
    required this.firstDueDate,
    required this.finalDueDate,
    required this.installments,
  });

  factory LoanCalculationPreview.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? json;
    final instList = (json['installments'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return LoanCalculationPreview(
      principal: (summary['principal'] as num?)?.toDouble() ?? 0.0,
      monthlyInterestRate: (summary['monthlyInterestRate'] as num?)?.toDouble() ?? 0.0,
      frequency: summary['frequency'] as String? ?? 'monthly',
      totalInstallments: (summary['totalInstallments'] as num?)?.toInt() ?? 1,
      durationInMonths: (summary['durationInMonths'] as num?)?.toDouble() ?? 0.0,
      monthlyInterest: (summary['monthlyInterest'] as num?)?.toDouble() ?? 0.0,
      totalInterest: (summary['totalInterest'] as num?)?.toDouble() ?? 0.0,
      totalRepayment: (summary['totalRepayment'] as num?)?.toDouble() ?? 0.0,
      baseInstallment: (summary['baseInstallment'] as num?)?.toDouble() ?? 0.0,
      startDate: summary['startDate'] as String? ?? '',
      firstDueDate: summary['firstDueDate'] as String? ?? '',
      finalDueDate: summary['finalDueDate'] as String? ?? '',
      installments: instList,
    );
  }
}

class LoanRepository {
  final ApiClient _client;

  LoanRepository({ApiClient? client}) : _client = client ?? ApiClient();

  /// Live calculation preview
  Future<LoanCalculationPreview> previewLoan({
    required double principal,
    required double interestRate,
    required String frequency,
    required int totalInstallments,
    required String startDate,
    required String firstDueDate,
    List<Map<String, dynamic>>? customInstallments,
  }) async {
    final response = await _client.post(
      '/loans/preview',
      body: {
        'principal': principal,
        'interest_rate': interestRate,
        'frequency': frequency,
        'total_installments': totalInstallments,
        'start_date': startDate,
        'first_due_date': firstDueDate,
        'custom_installments': ?customInstallments,
      },
    );

    return LoanCalculationPreview.fromJson(response['data'] as Map<String, dynamic>);
  }

  /// Create a new loan and generate schedule
  Future<LoanModel> createLoan(Map<String, dynamic> loanData) async {
    final response = await _client.post('/loans', body: loanData);
    final data = response['data'] as Map<String, dynamic>;
    final loanJson = data['loan'] as Map<String, dynamic>? ?? data;
    return LoanModel.fromJson(loanJson);
  }

  /// Get loans with pagination and search
  Future<LoanListResult> getLoans({
    String? search,
    String? status,
    String? customerId,
    int page = 1,
    int limit = 10,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status != 'all') query['status'] = status;
    if (customerId != null) query['customer_id'] = customerId;

    final response = await _client.get('/loans', queryParameters: query);
    final dataList = (response['data'] as List<dynamic>?) ?? [];
    final pagination = response['pagination'] as Map<String, dynamic>?;

    final loans = dataList.map((e) => LoanModel.fromJson(e as Map<String, dynamic>)).toList();

    return LoanListResult(
      loans: loans,
      totalRecords: pagination?['totalRecords'] as int? ?? loans.length,
      totalPages: pagination?['totalPages'] as int? ?? 1,
      currentPage: pagination?['page'] as int? ?? page,
    );
  }

  /// Get single loan details with installments
  Future<Map<String, dynamic>> getLoanById(String id) async {
    final response = await _client.get('/loans/$id');
    final data = response['data'] as Map<String, dynamic>;

    final loan = LoanModel.fromJson(data['loan'] as Map<String, dynamic>);
    final installmentsList = (data['installments'] as List<dynamic>?)
            ?.map((e) => InstallmentModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return {
      'loan': loan,
      'installments': installmentsList,
    };
  }

  /// Get customer loans
  Future<List<LoanModel>> getLoansByCustomerId(String customerId) async {
    final response = await _client.get('/customers/$customerId/loans');
    final data = (response['data'] as List<dynamic>?) ?? [];
    return data.map((e) => LoanModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
