import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../customers/screens/customer_form_dialog.dart';
import '../models/loan_model.dart';
import '../repositories/loan_repository.dart';
import 'loan_details_screen.dart';

/// Screen listing real Loans & Payment Plans with live search, status filtering, and origination dialog
class PaymentPlansScreen extends StatefulWidget {
  const PaymentPlansScreen({super.key});

  @override
  State<PaymentPlansScreen> createState() => _PaymentPlansScreenState();
}

class _PaymentPlansScreenState extends State<PaymentPlansScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  final TextEditingController _searchController = TextEditingController();

  List<LoanModel> _loans = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedStatus = 'all';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchLoans();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLoans({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _loanRepository.getLoans(
        search: _searchController.text.trim(),
        status: _selectedStatus,
        page: _currentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _loans = res.loans;
          _totalRecords = res.totalRecords;
          _totalPages = res.totalPages;
          _currentPage = res.currentPage;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load loans: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openOriginateLoanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSaved: () => _fetchLoans(resetPage: true),
      ),
    );
  }

  void _navigateToLoanDetails(LoanModel loan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => LoanDetailsScreen(
          loanId: loan.id,
          initialLoan: loan,
        ),
      ),
    );
    // Refresh after returning in case payments were recorded
    _fetchLoans();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppSpacing.tabletBreakpoint;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openOriginateLoanDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Originate Loan'),
          ),
          body: SafeArea(
            child: Padding(
              padding: isMobile ? AppSpacing.pagePaddingMobile : AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Loan Management',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Active loans, weekly/monthly schedules, and repayment progress.',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile)
                        AppButton(
                          text: 'Originate Loan',
                          icon: Icons.add_rounded,
                          onPressed: _openOriginateLoanDialog,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Search Bar & Filter Controls
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _searchController,
                          hint: 'Search loans by code, borrower name...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          onSubmitted: (_) => _fetchLoans(resetPage: true),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.search_rounded),
                        onPressed: () => _fetchLoans(resetPage: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Status Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatusFilterChip('all', 'All Plans ($_totalRecords)'),
                        const SizedBox(width: AppSpacing.xs),
                        _buildStatusFilterChip('active', 'Active'),
                        const SizedBox(width: AppSpacing.xs),
                        _buildStatusFilterChip('completed', 'Completed'),
                        const SizedBox(width: AppSpacing.xs),
                        _buildStatusFilterChip('defaulted', 'Defaulted'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Main Content: List, Loading, Error, or Empty
                  Expanded(
                    child: _buildContent(),
                  ),

                  // Pagination Footer
                  if (!_isLoading && _loans.isNotEmpty && _totalPages > 1) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _buildPaginationControls(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusFilterChip(String status, String label) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = status);
          _fetchLoans(resetPage: true);
        }
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading && _loans.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null && _loans.isEmpty) {
      return AppErrorView(
        message: _errorMessage!,
        onRetry: () => _fetchLoans(resetPage: true),
      );
    }

    if (_loans.isEmpty) {
      return AppEmptyState(
        title: _searchController.text.isNotEmpty
            ? 'No Loans Found'
            : 'No Loans Originated Yet',
        subtitle: _searchController.text.isNotEmpty
            ? 'Try searching with a different borrower name or loan code.'
            : 'Click "+ Originate Loan" or "Add Customer" to disburse your first loan.',
        icon: Icons.account_balance_wallet_outlined,
        actionText: 'Originate Loan',
        onAction: _openOriginateLoanDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchLoans(),
      child: ListView.separated(
        itemCount: _loans.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, idx) {
          final loan = _loans[idx];
          return _buildLoanCard(loan);
        },
      ),
    );
  }

  Widget _buildLoanCard(LoanModel loan) {
    final isCompleted = loan.isCompleted;
    final progress = loan.progressPercentage;

    return Card(
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedSm),
      child: InkWell(
        onTap: () => _navigateToLoanDetails(loan),
        borderRadius: AppSpacing.roundedSm,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Borrower Name, Plan Code, and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${loan.planCode} • ${loan.frequency.toUpperCase()} (${loan.totalInstallments} Periods)',
                          style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.successContainer : AppColors.primaryContainer.withAlpha(50),
                      borderRadius: AppSpacing.roundedXs,
                    ),
                    child: Text(
                      loan.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.0,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? AppColors.onSuccessContainer : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Row 2: Financial Metrics
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Principal', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                        Text(
                          CurrencyFormatter.format(loan.principalAmount),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.0),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Repayment', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                        Text(
                          CurrencyFormatter.format(loan.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Outstanding', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                        Text(
                          CurrencyFormatter.format(loan.outstandingBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.0,
                            color: loan.outstandingBalance > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Row 3: Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Collected: ${CurrencyFormatter.format(loan.amountCollected)}',
                    style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
                  ),
                  Text(
                    '${progress.toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              ClipRRect(
                borderRadius: AppSpacing.roundedXs,
                child: LinearProgressIndicator(
                  value: (progress / 100.0).clamp(0.0, 1.0),
                  minHeight: 6.0,
                  backgroundColor: AppColors.outlineVariantLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Page $_currentPage of $_totalPages ($_totalRecords loans)',
          style: const TextStyle(fontSize: 12.0, color: AppColors.textMutedLight),
        ),
        Row(
          children: [
            IconButton.outlined(
              icon: const Icon(Icons.chevron_left_rounded, size: 18.0),
              visualDensity: VisualDensity.compact,
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _fetchLoans();
                    }
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.outlined(
              icon: const Icon(Icons.chevron_right_rounded, size: 18.0),
              visualDensity: VisualDensity.compact,
              onPressed: _currentPage < _totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _fetchLoans();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
