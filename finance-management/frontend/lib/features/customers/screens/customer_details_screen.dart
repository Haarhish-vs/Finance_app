import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../payment_plans/models/loan_model.dart';
import '../../payment_plans/repositories/loan_repository.dart';
import '../../payment_plans/screens/loan_details_screen.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import 'customer_form_dialog.dart';

/// Screen displaying complete customer record, status actions, initial collections,
/// and associated active loan plans
class CustomerDetailsScreen extends StatefulWidget {
  final String customerId;
  final CustomerModel? initialCustomer;

  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
    this.initialCustomer,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen> {
  final CustomerRepository _repository = CustomerRepository();
  final LoanRepository _loanRepository = LoanRepository();

  CustomerModel? _customer;
  List<LoanModel> _customerLoans = [];
  bool _isLoading = true;
  bool _isLoadingLoans = true;
  bool _isTogglingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer;
    _fetchCustomer();
    _fetchCustomerLoans();
  }

  Future<void> _fetchCustomer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetched = await _repository.getCustomerById(widget.customerId);
      if (mounted) {
        setState(() {
          _customer = fetched;
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
          _errorMessage = 'Failed to load customer profile: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchCustomerLoans() async {
    setState(() => _isLoadingLoans = true);
    try {
      final loans = await _loanRepository.getLoansByCustomerId(widget.customerId);
      if (mounted) {
        setState(() {
          _customerLoans = loans;
          _isLoadingLoans = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLoans = false);
      }
    }
  }

  Future<void> _confirmStatusToggle() async {
    if (_customer == null || _isTogglingStatus) return;

    final isCurrentlyActive = _customer!.isActive;
    final targetStatus = isCurrentlyActive ? 'inactive' : 'active';
    final actionName = isCurrentlyActive ? 'Deactivate' : 'Activate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionName Customer?'),
        content: Text(
          isCurrentlyActive
              ? 'Are you sure you want to deactivate ${_customer!.fullName}? Inactive customers cannot take on new payment plans.'
              : 'Reactivate ${_customer!.fullName} to enable new plan originations?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          AppButton(
            text: actionName,
            variant: isCurrentlyActive ? AppButtonVariant.danger : AppButtonVariant.primary,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isTogglingStatus = true);

    try {
      final updated = await _repository.updateCustomerStatus(_customer!.id, targetStatus);
      if (mounted) {
        setState(() {
          _customer = updated;
          _isTogglingStatus = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: updated.isActive ? AppColors.success : AppColors.secondary,
            content: Text(
              updated.isActive
                  ? 'Customer status is now ACTIVE'
                  : 'Customer deactivated',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _isTogglingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.message),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTogglingStatus = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update status: $e'),
          ),
        );
      }
    }
  }

  void _openEditDialog() {
    if (_customer == null) return;

    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        initialCustomer: _customer,
        isEditOnly: true,
        onSaved: () {
          _fetchCustomer();
          _fetchCustomerLoans();
        },
        onDeleted: () {
          Navigator.of(context).pop(true);
        },
      ),
    );
  }

  Future<void> _confirmDeleteCustomer() async {
    if (_customer == null) return;

    final customerName = _customer!.fullName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 40.0),
        title: const Text('Delete Customer?'),
        content: Text(
          'Are you sure you want to permanently delete "$customerName" from the database?\n\n'
          'This will permanently delete this customer and all associated loan plans, installments, and payment records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_rounded, size: 16.0),
            label: const Text('Delete Permanently'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);

      try {
        await _repository.deleteCustomer(_customer!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Customer "$customerName" deleted successfully from database.'),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Failed to delete customer: $e'),
            ),
          );
        }
      }
    }
  }

  void _openOriginateLoanDialog() {
    if (_customer == null) return;

    showDialog(
      context: context,
      builder: (ctx) => CustomerFormDialog(
        initialCustomer: _customer,
        isEditOnly: false,
        onSaved: () {
          _fetchCustomer();
          _fetchCustomerLoans();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _customer?.fullName ?? 'Customer Profile',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_customer != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Profile',
              onPressed: _openEditDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              tooltip: 'Delete Customer',
              onPressed: _confirmDeleteCustomer,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: () {
                _fetchCustomer();
                _fetchCustomerLoans();
              },
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _customer == null) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null && _customer == null) {
      return AppErrorView(
        message: _errorMessage!,
        onRetry: () {
          _fetchCustomer();
          _fetchCustomerLoans();
        },
      );
    }

    if (_customer == null) {
      return const Center(child: Text('Customer not found'));
    }

    final customer = _customer!;
    final isActive = customer.isActive;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchCustomer();
        await _fetchCustomerLoans();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.pagePaddingMobile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28.0,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            customer.fullName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                            style: const TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customer.fullName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.successContainer : AppColors.secondaryContainer,
                                  borderRadius: AppSpacing.roundedXs,
                                ),
                                child: Text(
                                  customer.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? AppColors.onSuccessContainer : AppColors.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(),
                    const SizedBox(height: AppSpacing.sm),
                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Edit Profile',
                            icon: Icons.edit_rounded,
                            variant: AppButtonVariant.outlined,
                            onPressed: _openEditDialog,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppButton(
                            text: 'Originate Loan',
                            icon: Icons.account_balance_wallet_rounded,
                            onPressed: isActive ? _openOriginateLoanDialog : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Active Loans Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Associated Loans',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: isActive ? _openOriginateLoanDialog : null,
                  icon: const Icon(Icons.add_rounded, size: 16.0),
                  label: const Text('New Loan'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            if (_isLoadingLoans) ...[
              const Center(child: AppLoadingIndicator()),
            ] else if (_customerLoans.isEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      const Text(
                        'No loans currently originated for this customer.',
                        style: TextStyle(color: AppColors.textMutedLight),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: isActive ? _openOriginateLoanDialog : null,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Disburse First Loan'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customerLoans.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (ctx, idx) {
                  final loan = _customerLoans[idx];
                  return Card(
                    child: ListTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) => LoanDetailsScreen(
                              loanId: loan.id,
                              initialLoan: loan,
                            ),
                          ),
                        ).then((_) => _fetchCustomerLoans());
                      },
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryContainer,
                        child: Icon(Icons.currency_rupee_rounded, color: AppColors.primary, size: 18.0),
                      ),
                      title: Text(loan.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${loan.planCode} • ${CurrencyFormatter.format(loan.totalAmount)} • ${loan.frequency.toUpperCase()}',
                        style: const TextStyle(fontSize: 12.0),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(loan.outstandingBalance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: loan.outstandingBalance > 0 ? AppColors.error : AppColors.success,
                            ),
                          ),
                          Text(
                            loan.status.toUpperCase(),
                            style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // Initial Amount Collected Card
            Card(
              color: AppColors.successContainer.withAlpha(40),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: const BoxDecoration(
                        color: AppColors.successContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.currency_rupee_rounded,
                        color: AppColors.success,
                        size: 24.0,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Initial Deposit Collected',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSuccessContainer,
                                ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            CurrencyFormatter.format(customer.initialAmountCollected),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSuccessContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Contact Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact & Personal Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Divider(),
                    _buildInfoRow(
                      context,
                      icon: Icons.phone_outlined,
                      label: 'Phone Number',
                      value: customer.phone ?? 'Not provided',
                    ),
                    _buildInfoRow(
                      context,
                      icon: Icons.email_outlined,
                      label: 'Email Address',
                      value: customer.email ?? 'Not provided',
                    ),
                    _buildInfoRow(
                      context,
                      icon: Icons.home_outlined,
                      label: 'Residential Address',
                      value: customer.address ?? 'Not provided',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Deactivate / Reactivate Row
            Center(
              child: TextButton.icon(
                onPressed: _confirmStatusToggle,
                icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_rounded, color: isActive ? AppColors.error : AppColors.success),
                label: Text(
                  isActive ? 'Deactivate Customer' : 'Activate Customer',
                  style: TextStyle(color: isActive ? AppColors.error : AppColors.success),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.0, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMutedLight,
                      ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimaryLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
