import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../customers/models/customer_model.dart';
import '../../customers/repositories/customer_repository.dart';
import '../../customers/screens/customer_details_screen.dart';
import '../../customers/screens/customer_form_dialog.dart';
import '../../installments/repositories/installment_repository.dart';
import '../../payment_plans/models/loan_model.dart';
import '../../payment_plans/repositories/loan_repository.dart';
import '../../payment_plans/screens/loan_details_screen.dart';

/// Clean Executive Dashboard displaying financial metrics, active loans, and real customer activity
class DashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;

  const DashboardScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final CustomerRepository _customerRepo = CustomerRepository();
  final LoanRepository _loanRepo = LoanRepository();
  final InstallmentRepository _installmentRepo = InstallmentRepository();

  bool _isLoadingData = true;
  List<CustomerModel> _recentCustomers = [];
  List<LoanModel> _recentLoans = [];
  int _totalCustomerCount = 0;
  int _activeLoansCount = 0;
  int _overdueInstallmentsCount = 0;
  double _totalInitialCollected = 0.0;
  double _totalLoanCollected = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingData = true);

    try {
      final customerResult = await _customerRepo.getCustomers(page: 1, limit: 5);
      double initialCollected = 0.0;
      for (final c in customerResult.customers) {
        initialCollected += c.initialAmountCollected;
      }

      final loanResult = await _loanRepo.getLoans(page: 1, limit: 5);
      double loanCollected = 0.0;
      for (final l in loanResult.loans) {
        loanCollected += l.amountCollected;
      }

      final overdueResult = await _installmentRepo.getInstallments(status: 'overdue', limit: 1);

      if (mounted) {
        setState(() {
          _recentCustomers = customerResult.customers;
          _totalCustomerCount = customerResult.pagination.totalRecords;
          _totalInitialCollected = initialCollected;

          _recentLoans = loanResult.loans;
          _activeLoansCount = loanResult.totalRecords;
          _totalLoanCollected = loanCollected;

          _overdueInstallmentsCount = overdueResult.totalRecords;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  void _openAddCustomerAndLoanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        onSaved: _loadDashboardData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < AppSpacing.tabletBreakpoint;

          return RefreshIndicator(
            onRefresh: _loadDashboardData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: isMobile ? AppSpacing.pagePaddingMobile : AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Financial Overview Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Financial Overview',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _loadDashboardData,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // KPI Metrics Grid
                  _buildKpiGrid(context, constraints.maxWidth),
                  const SizedBox(height: AppSpacing.lg),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildQuickActions(context),
                  const SizedBox(height: AppSpacing.lg),

                  // Recent Active Loans Section
                  _buildRecentLoansSection(context),
                  const SizedBox(height: AppSpacing.lg),

                  // Recent Customers Section
                  _buildRecentCustomersSection(context),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiGrid(BuildContext context, double maxWidth) {
    final int crossAxisCount = maxWidth > 1000 ? 4 : (maxWidth > 650 ? 2 : 1);

    final cards = [
      _buildMetricCard(
        context,
        title: 'Loan Payments Collected',
        value: CurrencyFormatter.format(_totalLoanCollected),
        subtitle: 'Recurring collections across loans',
        icon: Icons.currency_rupee_rounded,
        accentColor: AppColors.success,
        bgColor: AppColors.successContainer,
      ),
      _buildMetricCard(
        context,
        title: 'Total Borrowers',
        value: '$_totalCustomerCount Registered',
        subtitle: '$_totalCustomerCount profiles • ${CurrencyFormatter.format(_totalInitialCollected)} deposits',
        icon: Icons.people_alt_rounded,
        accentColor: AppColors.primary,
        bgColor: AppColors.primaryContainer,
      ),
      _buildMetricCard(
        context,
        title: 'Originated Loans',
        value: '$_activeLoansCount Active Plans',
        subtitle: 'Weekly & monthly loans running',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: AppColors.info,
        bgColor: AppColors.infoContainer,
      ),
      _buildMetricCard(
        context,
        title: 'Overdue Installments',
        value: '$_overdueInstallmentsCount Overdue',
        subtitle: _overdueInstallmentsCount > 0 ? 'Requires follow-up action' : 'No delinquent balances',
        icon: _overdueInstallmentsCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
        accentColor: _overdueInstallmentsCount > 0 ? AppColors.error : AppColors.success,
        bgColor: _overdueInstallmentsCount > 0 ? AppColors.errorContainer : AppColors.successContainer,
      ),
    ];

    if (crossAxisCount == 1) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: c,
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth =
            (constraints.maxWidth - ((crossAxisCount - 1) * AppSpacing.md)) / crossAxisCount;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: cards
              .map((c) => SizedBox(
                    width: itemWidth,
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textMutedLight,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: AppSpacing.roundedSm,
                  ),
                  child: Icon(icon, color: accentColor, size: 18.0),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2.0),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMutedLight,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppButton(
          text: 'Add Customer / Loan',
          icon: Icons.person_add_rounded,
          onPressed: _openAddCustomerAndLoanDialog,
        ),
        AppButton(
          text: 'View Customers',
          icon: Icons.people_outline,
          variant: AppButtonVariant.outlined,
          onPressed: () => widget.onNavigateTab?.call(1),
        ),
        AppButton(
          text: 'Loan Plans',
          icon: Icons.account_balance_wallet_outlined,
          variant: AppButtonVariant.outlined,
          onPressed: () => widget.onNavigateTab?.call(2),
        ),
        AppButton(
          text: 'Reports',
          icon: Icons.bar_chart_rounded,
          variant: AppButtonVariant.secondary,
          onPressed: () => widget.onNavigateTab?.call(3),
        ),
      ],
    );
  }

  Widget _buildRecentLoansSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent Loans Originated',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(2),
                  child: const Text('View All Plans'),
                ),
              ],
            ),
            const Divider(),
            if (_isLoadingData) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: AppLoadingIndicator(),
                ),
              ),
            ] else if (_recentLoans.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: AppEmptyState(
                    title: 'No Loans Originated',
                    subtitle: 'Click "+ Add Customer / Loan" to create your first loan plan.',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentLoans.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final loan = _recentLoans[index];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => LoanDetailsScreen(
                            loanId: loan.id,
                            initialLoan: loan,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryContainer,
                      child: Icon(Icons.currency_rupee_rounded, color: AppColors.primary, size: 18.0),
                    ),
                    title: Text(
                      loan.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${loan.planCode} • ${loan.frequency.toUpperCase()} (${loan.totalInstallments} Periods)',
                      style: const TextStyle(fontSize: 12.0),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(loan.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${loan.progressPercentage.toStringAsFixed(0)}% collected',
                          style: const TextStyle(fontSize: 11.0, color: AppColors.success),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCustomersSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Recent Registered Borrowers',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigateTab?.call(1),
                  child: const Text('View All Customers'),
                ),
              ],
            ),
            const Divider(),
            if (_isLoadingData) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: AppLoadingIndicator(),
                ),
              ),
            ] else if (_recentCustomers.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: AppEmptyState(
                    title: 'No Customers Found',
                    subtitle: 'Borrowers added to the platform will be listed here.',
                    icon: Icons.people_outline,
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentCustomers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final customer = _recentCustomers[index];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => CustomerDetailsScreen(
                            customerId: customer.id,
                            initialCustomer: customer,
                          ),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondaryContainer,
                      child: Text(
                        customer.fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    title: Text(
                      customer.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      customer.phone ?? 'No phone provided',
                      style: const TextStyle(fontSize: 12.0),
                    ),
                    trailing: Text(
                      CurrencyFormatter.format(customer.initialAmountCollected),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
