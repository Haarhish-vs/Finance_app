/// Models representing Financial Reports and Executive Summary metrics
class ReportMetrics {
  final int totalCustomers;
  final int activeCustomers;
  final int totalLoans;
  final double totalPrincipalDisbursed;
  final double totalRepaymentExpected;
  final double totalCollected;
  final double outstandingPrincipal;
  final int totalInstallments;

  const ReportMetrics({
    this.totalCustomers = 0,
    this.activeCustomers = 0,
    this.totalLoans = 0,
    this.totalPrincipalDisbursed = 0.0,
    this.totalRepaymentExpected = 0.0,
    this.totalCollected = 0.0,
    this.outstandingPrincipal = 0.0,
    this.totalInstallments = 0,
  });

  factory ReportMetrics.fromJson(Map<String, dynamic> json) {
    return ReportMetrics(
      totalCustomers: (json['totalCustomers'] as num?)?.toInt() ?? 0,
      activeCustomers: (json['activeCustomers'] as num?)?.toInt() ?? 0,
      totalLoans: (json['totalLoans'] as num?)?.toInt() ?? 0,
      totalPrincipalDisbursed: (json['totalPrincipalDisbursed'] as num?)?.toDouble() ?? 0.0,
      totalRepaymentExpected: (json['totalRepaymentExpected'] as num?)?.toDouble() ?? 0.0,
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0.0,
      outstandingPrincipal: (json['outstandingPrincipal'] as num?)?.toDouble() ?? 0.0,
      totalInstallments: (json['totalInstallments'] as num?)?.toInt() ?? 0,
    );
  }
}

class ReportData {
  final String range;
  final String? startDate;
  final String? endDate;
  final ReportMetrics metrics;
  final List<dynamic> customers;
  final List<dynamic> loans;
  final List<dynamic> installments;

  const ReportData({
    required this.range,
    this.startDate,
    this.endDate,
    required this.metrics,
    this.customers = const [],
    this.loans = const [],
    this.installments = const [],
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      range: json['range']?.toString() ?? 'All Time',
      startDate: json['startDate']?.toString(),
      endDate: json['endDate']?.toString(),
      metrics: json['metrics'] != null
          ? ReportMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : const ReportMetrics(),
      customers: (json['customers'] as List?) ?? [],
      loans: (json['loans'] as List?) ?? [],
      installments: (json['installments'] as List?) ?? [],
    );
  }
}
