import '../../../core/network/api_client.dart';
import '../../customers/repositories/customer_repository.dart';
import '../../installments/repositories/installment_repository.dart';
import '../../payment_plans/repositories/loan_repository.dart';
import '../models/report_model.dart';

class ReportsRepository {
  final ApiClient _apiClient;
  final CustomerRepository _customerRepo = CustomerRepository();
  final LoanRepository _loanRepo = LoanRepository();
  final InstallmentRepository _installmentRepo = InstallmentRepository();

  ReportsRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Map UI range labels to query parameters
  String toRangeParam(String label) {
    switch (label.toLowerCase()) {
      case 'this month':
        return 'this_month';
      case 'last month':
        return 'last_month';
      case 'this quarter':
        return 'this_quarter';
      case 'year to date':
        return 'year_to_date';
      case 'all time':
      default:
        return 'all_time';
    }
  }

  /// Fetch financial report with date range filtering and client fallback
  Future<ReportData> getReport({String range = 'This Month'}) async {
    final rangeParam = toRangeParam(range);

    // 1. Try backend report endpoint first
    try {
      final res = await _apiClient.get('reports', queryParameters: {'range': rangeParam});
      if (res is Map<String, dynamic> && res['success'] == true && res['data'] != null) {
        return ReportData.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      // Graceful fallback to client aggregation below
    }

    // 2. Client-side aggregation fallback
    return _aggregateClientReport(range, rangeParam);
  }

  /// Client-side report calculation when server endpoint is unavailable
  Future<ReportData> _aggregateClientReport(String label, String rangeParam) async {
    final customersRes = await _customerRepo.getCustomers(page: 1, limit: 100);
    final loansRes = await _loanRepo.getLoans(page: 1, limit: 100);
    final instRes = await _installmentRepo.getInstallments(limit: 200);

    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    if (rangeParam == 'this_month') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else if (rangeParam == 'last_month') {
      startDate = DateTime(now.year, now.month - 1, 1);
      endDate = DateTime(now.year, now.month, 0, 23, 59, 59);
    } else if (rangeParam == 'this_quarter') {
      final quarter = (now.month - 1) ~/ 3;
      startDate = DateTime(now.year, quarter * 3 + 1, 1);
      endDate = DateTime(now.year, (quarter + 1) * 3 + 1, 0, 23, 59, 59);
    } else if (rangeParam == 'year_to_date') {
      startDate = DateTime(now.year, 1, 1);
      endDate = now;
    }

    bool isWithinRange(DateTime? dt) {
      if (startDate == null || endDate == null || dt == null) return true;
      return dt.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(endDate.add(const Duration(seconds: 1)));
    }

    // Filter customers
    final filteredCustomers = customersRes.customers.where((c) {
      if (startDate == null) return true;
      return isWithinRange(c.createdAt);
    }).toList();

    // Filter loans
    final filteredLoans = loansRes.loans.where((l) {
      if (startDate == null) return true;
      final loanDate = DateTime.tryParse(l.startDate) ?? l.createdAt;
      return isWithinRange(loanDate);
    }).toList();

    // Filter installments
    final filteredInsts = instRes.installments.where((i) {
      if (startDate == null) return true;
      final instDate = DateTime.tryParse(i.dueDate) ?? i.createdAt;
      return isWithinRange(instDate);
    }).toList();

    double totalPrincipal = 0.0;
    double totalRepayment = 0.0;
    double totalCollected = 0.0;
    int activeBorrowers = 0;

    for (final l in filteredLoans) {
      totalPrincipal += l.principalAmount;
      totalRepayment += l.totalAmount;
      totalCollected += l.amountCollected;
    }

    for (final c in filteredCustomers) {
      if (c.isActive) activeBorrowers++;
      totalCollected += c.initialAmountCollected;
    }

    final double outstanding = (totalPrincipal - totalCollected).clamp(0.0, double.infinity);

    final metrics = ReportMetrics(
      totalCustomers: filteredCustomers.isNotEmpty ? filteredCustomers.length : customersRes.pagination.totalRecords,
      activeCustomers: activeBorrowers > 0 ? activeBorrowers : (customersRes.customers.where((c) => c.isActive).length),
      totalLoans: filteredLoans.isNotEmpty ? filteredLoans.length : loansRes.totalRecords,
      totalPrincipalDisbursed: totalPrincipal,
      totalRepaymentExpected: totalRepayment,
      totalCollected: totalCollected,
      outstandingPrincipal: outstanding,
      totalInstallments: filteredInsts.isNotEmpty ? filteredInsts.length : instRes.totalRecords,
    );

    return ReportData(
      range: label,
      startDate: startDate?.toIso8601String(),
      endDate: endDate?.toIso8601String(),
      metrics: metrics,
      customers: customersRes.customers.map((c) => c.toJson()).toList(),
      loans: loansRes.loans.map((l) => {
        'id': l.id,
        'plan_code': l.planCode,
        'customer_id': l.customerId,
        'customer_name': l.customerName,
        'customer_phone': l.customerPhone,
        'title': l.title,
        'principal_amount': l.principalAmount,
        'interest_rate': l.interestRate,
        'total_amount': l.totalAmount,
        'frequency': l.frequency,
        'total_installments': l.totalInstallments,
        'start_date': l.startDate,
        'end_date': l.endDate,
        'status': l.status,
        'amount_collected': l.amountCollected,
      }).toList(),
      installments: instRes.installments.map((i) => {
        'id': i.id,
        'plan_id': i.planId,
        'plan_code': i.planCode,
        'customer_name': i.customerName,
        'installment_number': i.installmentNumber,
        'due_date': i.dueDate,
        'amount_due': i.amountDue,
        'amount_paid': i.amountPaid,
        'status': i.status,
        'paid_at': i.paidAt,
      }).toList(),
    );
  }

  /// Generate full CSV string from ReportData
  String buildCsvString(ReportData report) {
    final buffer = StringBuffer();

    String escape(dynamic val) {
      if (val == null) return '';
      final str = val.toString();
      if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
        return '"${str.replaceAll('"', '""')}"';
      }
      return str;
    }

    // Header metadata
    buffer.writeln('# ==============================================================================');
    buffer.writeln('# FINANCE MANAGEMENT SYSTEM - PORTFOLIO FINANCIAL REPORT');
    buffer.writeln('# Selected Range: ${escape(report.range)}');
    buffer.writeln('# Generated Date: ${escape(DateTime.now().toLocal().toString().split('.')[0])}');
    buffer.writeln('# Currency: INR (₹)');
    buffer.writeln('# ==============================================================================');
    buffer.writeln();

    // Summary KPIs
    buffer.writeln('# --- EXECUTIVE PORTFOLIO SUMMARY ---');
    buffer.writeln('Metric,Value');
    buffer.writeln('Date Range,${escape(report.range)}');
    buffer.writeln('Total Registered Borrowers,${report.metrics.totalCustomers}');
    buffer.writeln('Active Borrowers,${report.metrics.activeCustomers}');
    buffer.writeln('Total Originated Loans,${report.metrics.totalLoans}');
    buffer.writeln('Total Principal Disbursed (INR),${report.metrics.totalPrincipalDisbursed.toStringAsFixed(2)}');
    buffer.writeln('Total Collections Received (INR),${report.metrics.totalCollected.toStringAsFixed(2)}');
    buffer.writeln('Outstanding Principal (INR),${report.metrics.outstandingPrincipal.toStringAsFixed(2)}');
    buffer.writeln('Total Installments Count,${report.metrics.totalInstallments}');
    buffer.writeln();

    // Section 1: Customers
    buffer.writeln('# --- 1. BORROWER DIRECTORY ---');
    buffer.writeln('Customer ID,Full Name,Phone Number,Email,Status,Registration Date');
    for (final c in report.customers) {
      if (c is Map) {
        buffer.writeln([
          escape(c['id'] ?? ''),
          escape(c['full_name'] ?? c['name'] ?? ''),
          escape(c['phone'] ?? 'N/A'),
          escape(c['email'] ?? 'N/A'),
          escape(c['status'] ?? 'active'),
          escape(c['created_at'] != null ? c['created_at'].toString().split('T')[0] : ''),
        ].join(','));
      }
    }
    buffer.writeln();

    // Section 2: Loans
    buffer.writeln('# --- 2. LOANS & PAYMENT PLANS ---');
    buffer.writeln('Plan Code,Borrower Name,Phone,Principal Amount (INR),Rate (%),Tenure,Frequency,Total Repayment (INR),Status,Start Date,End Date');
    for (final l in report.loans) {
      if (l is Map) {
        final cust = l['customers'] is Map ? l['customers'] as Map : {};
        final principal = (l['principal_amount'] ?? l['total_amount'] ?? 0).toDouble();
        final total = (l['total_amount'] ?? 0).toDouble();
        final rate = (l['interest_rate'] ?? 0).toDouble();
        final freq = l['frequency']?.toString() ?? 'monthly';
        final duration = l['total_installments']?.toString() ?? '';

        buffer.writeln([
          escape(l['plan_code'] ?? 'N/A'),
          escape(cust['full_name'] ?? l['customer_name'] ?? 'N/A'),
          escape(cust['phone'] ?? l['customer_phone'] ?? 'N/A'),
          principal.toStringAsFixed(2),
          rate.toStringAsFixed(1),
          '$duration ${freq == 'weekly' ? 'Weeks' : 'Months'}',
          escape(freq),
          total.toStringAsFixed(2),
          escape(l['status'] ?? 'active'),
          escape(l['start_date'] ?? ''),
          escape(l['end_date'] ?? ''),
        ].join(','));
      }
    }
    buffer.writeln();

    // Section 3: Installments
    buffer.writeln('# --- 3. RECOVERY & INSTALLMENTS LEDGER ---');
    buffer.writeln('Plan Code,Borrower Name,Installment Number,Due Date,Amount Due (INR),Amount Paid (INR),Status,Paid Date');
    for (final i in report.installments) {
      if (i is Map) {
        final cust = i['customers'] is Map ? i['customers'] as Map : {};
        final plan = i['payment_plans'] is Map ? i['payment_plans'] as Map : {};
        final due = (i['amount_due'] ?? 0).toDouble();
        final paid = (i['amount_paid'] ?? 0).toDouble();

        buffer.writeln([
          escape(plan['plan_code'] ?? 'N/A'),
          escape(cust['full_name'] ?? i['customer_name'] ?? 'N/A'),
          i['installment_number'] ?? '',
          escape(i['due_date'] ?? ''),
          due.toStringAsFixed(2),
          paid.toStringAsFixed(2),
          escape(i['status'] ?? 'pending'),
          escape(i['paid_at'] != null ? i['paid_at'].toString().split('T')[0] : '-'),
        ].join(','));
      }
    }

    return buffer.toString();
  }
}
