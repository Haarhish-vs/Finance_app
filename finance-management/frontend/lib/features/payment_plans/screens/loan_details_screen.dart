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
import '../../installments/models/installment_model.dart';
import '../../installments/repositories/installment_repository.dart';
import '../../payments/models/payment_model.dart';
import '../models/loan_model.dart';
import '../repositories/loan_repository.dart';

/// Screen displaying complete financial breakdown of a Loan, its installment schedule,
/// and interactive payment recording and schedule editing
class LoanDetailsScreen extends StatefulWidget {
  final String loanId;
  final LoanModel? initialLoan;

  const LoanDetailsScreen({
    super.key,
    required this.loanId,
    this.initialLoan,
  });

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  final LoanRepository _loanRepository = LoanRepository();
  final InstallmentRepository _installmentRepository = InstallmentRepository();

  LoanModel? _loan;
  List<InstallmentModel> _installments = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loan = widget.initialLoan;
    _fetchLoanDetails();
  }

  Future<void> _fetchLoanDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _loanRepository.getLoanById(widget.loanId);
      if (mounted) {
        setState(() {
          _loan = res['loan'] as LoanModel;
          _installments = res['installments'] as List<InstallmentModel>;
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
          _errorMessage = 'Failed to load loan details: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Open Payment Entry Dialog to record full or partial payment
  Future<void> _openRecordPaymentDialog(InstallmentModel inst) async {
    final amountController = TextEditingController(
      text: inst.outstandingBalance.toStringAsFixed(2),
    );
    final notesController = TextEditingController();
    String paymentMethod = 'cash';
    DateTime paymentDate = DateTime.now();
    bool isSubmittingPayment = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.payments_rounded, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Record Payment - ${inst.periodLabel}',
                    style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440.0,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: AppSpacing.roundedSm,
                        ),
                        child: Text(
                          dialogError!,
                          style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 12.0),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Balance overview
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowestLight,
                        borderRadius: AppSpacing.roundedSm,
                        border: Border.all(color: AppColors.outlineVariantLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Amount Due', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                              Text(CurrencyFormatter.format(inst.amountDue), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Already Paid', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                              Text(CurrencyFormatter.format(inst.amountPaid), style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Outstanding Balance', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                              Text(
                                CurrencyFormatter.format(inst.outstandingBalance),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Amount Received Field
                    AppTextField(
                      controller: amountController,
                      label: 'Amount Received (${CurrencyFormatter.symbol}) *',
                      hint: '0.00',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Enter full balance (${CurrencyFormatter.format(inst.outstandingBalance)}) or any partial amount.',
                      style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Payment Method Dropdown
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Payment Method',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: paymentMethod,
                          isDense: true,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'upi', child: Text('UPI / GPay / PhonePe')),
                            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer / NEFT')),
                            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => paymentMethod = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Payment Date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setDialogState(() => paymentDate = picked);
                        }
                      },
                      borderRadius: AppSpacing.roundedSm,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date',
                          prefixIcon: Icon(Icons.calendar_today_rounded, size: 18.0),
                        ),
                        child: Text(
                          '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Notes
                    AppTextField(
                      controller: notesController,
                      label: 'Notes / Reference',
                      hint: 'e.g. Receipt #, UPI Reference ID',
                      maxLines: 2,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmittingPayment ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                text: 'Confirm Payment',
                icon: Icons.check_circle_rounded,
                isLoading: isSubmittingPayment,
                onPressed: () async {
                  final entered = double.tryParse(amountController.text.trim());
                  if (entered == null || entered <= 0) {
                    setDialogState(() => dialogError = 'Please enter a valid positive payment amount');
                    return;
                  }
                  if (entered > inst.outstandingBalance + 0.01) {
                    setDialogState(() => dialogError = 'Payment amount cannot exceed outstanding balance (${CurrencyFormatter.format(inst.outstandingBalance)})');
                    return;
                  }

                  setDialogState(() {
                    isSubmittingPayment = true;
                    dialogError = null;
                  });

                  try {
                    final dateStr = '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
                    await _installmentRepository.recordPayment(
                      installmentId: inst.id,
                      amount: entered,
                      paymentDate: dateStr,
                      paymentMethod: paymentMethod,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    );

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      _fetchLoanDetails();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('Payment of ${CurrencyFormatter.format(entered)} recorded successfully!'),
                        ),
                      );
                    }
                  } on ApiException catch (e) {
                    setDialogState(() {
                      dialogError = e.message;
                      isSubmittingPayment = false;
                    });
                  } catch (e) {
                    setDialogState(() {
                      dialogError = 'Failed to record payment: $e';
                      isSubmittingPayment = false;
                    });
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// Open Edit Installment Dialog to adjust due date or amount
  Future<void> _openEditInstallmentDialog(InstallmentModel inst) async {
    final amountController = TextEditingController(text: inst.amountDue.toStringAsFixed(2));
    DateTime dueDate = DateTime.tryParse(inst.dueDate) ?? DateTime.now();
    bool isSaving = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final currentInputAmount = double.tryParse(amountController.text.trim()) ?? inst.amountDue;
          final diff = currentInputAmount - inst.amountDue;
          final hasDiff = diff.abs() > 0.01;

          return AlertDialog(
            title: Text('Edit ${inst.periodLabel} Schedule'),
            content: SizedBox(
              width: 420.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (dialogError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 12.0),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Notice about already paid amount
                  if (inst.amountPaid > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer.withAlpha(50),
                        borderRadius: AppSpacing.roundedSm,
                        border: Border.all(color: AppColors.secondary),
                      ),
                      child: Text(
                        'Already received: ${CurrencyFormatter.format(inst.amountPaid)}. Amount due cannot be less than amount already paid.',
                        style: const TextStyle(fontSize: 11.0, color: AppColors.textPrimaryLight),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Due Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) {
                        setDialogState(() => dueDate = picked);
                      }
                    },
                    borderRadius: AppSpacing.roundedSm,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Due Date',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      child: Text(
                        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Amount Due
                  AppTextField(
                    controller: amountController,
                    label: 'Amount Due (${CurrencyFormatter.symbol}) *',
                    hint: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (val) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 6.0),

                  if (hasDiff) ...[
                    Text(
                      'Schedule difference: ${diff > 0 ? '+' : ''}${CurrencyFormatter.format(diff)}. Loan total will be updated automatically.',
                      style: TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: diff > 0 ? AppColors.error : AppColors.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                text: 'Save Changes',
                isLoading: isSaving,
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text.trim());
                  if (newAmount == null || newAmount < 0) {
                    setDialogState(() => dialogError = 'Enter a valid amount');
                    return;
                  }
                  if (newAmount < inst.amountPaid) {
                    setDialogState(() => dialogError = 'Amount due cannot be less than already paid (${CurrencyFormatter.format(inst.amountPaid)})');
                    return;
                  }

                  setDialogState(() {
                    isSaving = true;
                    dialogError = null;
                  });

                  try {
                    final dateStr = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
                    await _installmentRepository.updateInstallment(
                      inst.id,
                      dueDate: dateStr,
                      amountDue: newAmount,
                    );

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      _fetchLoanDetails();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('Installment schedule updated successfully.'),
                        ),
                      );
                    }
                  } on ApiException catch (e) {
                    setDialogState(() {
                      dialogError = e.message;
                      isSaving = false;
                    });
                  } catch (e) {
                    setDialogState(() {
                      dialogError = 'Failed to update installment: $e';
                      isSaving = false;
                    });
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// View payment history receipts for an installment
  Future<void> _viewPaymentsHistory(InstallmentModel inst) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            return FutureBuilder<List<PaymentModel>>(
              future: _installmentRepository.getPayments(inst.id),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoadingIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading payments: ${snapshot.error}'));
                }

                final payments = snapshot.data ?? [];

                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Receipts - ${inst.periodLabel}',
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const Divider(),
                      if (payments.isEmpty) ...[
                        const Expanded(
                          child: Center(
                            child: Text('No payment receipts recorded yet for this installment.'),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: ListView.separated(
                            controller: scrollController,
                            itemCount: payments.length,
                            separatorBuilder: (ctx, idx) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final p = payments[idx];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.successContainer,
                                  child: Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 20.0),
                                ),
                                title: Text(
                                  CurrencyFormatter.format(p.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Ref: ${p.paymentReference} • ${p.paymentDate} • ${p.paymentMethod.toUpperCase()}',
                                  style: const TextStyle(fontSize: 11.0),
                                ),
                                trailing: p.notes != null ? Text(p.notes!, style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)) : null,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan Details')),
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    if (_errorMessage != null && _loan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loan Details')),
        body: AppErrorView(
          message: _errorMessage!,
          onRetry: _fetchLoanDetails,
        ),
      );
    }

    final loan = _loan!;
    final progress = loan.progressPercentage;

    // Filter installments
    final filteredInstallments = _installments.where((inst) {
      if (_statusFilter == 'all') return true;
      return inst.status.toLowerCase() == _statusFilter.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loan.title,
              style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Code: ${loan.planCode} • Borrower: ${loan.customerName}',
              style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchLoanDetails,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLoanDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.pagePaddingMobile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Loan Overview & Financial Summary Card
              _buildFinancialSummaryCard(loan, progress),
              const SizedBox(height: AppSpacing.md),

              // Customer / Borrower Quick Info Card
              _buildBorrowerInfoCard(loan),
              const SizedBox(height: AppSpacing.md),

              // Installment Schedule Header & Filter Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Installment Schedule',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_installments.length} Total',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMutedLight),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Complete payment schedule with live tracking of Paid, Partially Paid, Pending, and Overdue statuses.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMutedLight),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'All (${_installments.length})'),
                    const SizedBox(width: AppSpacing.xs),
                    _buildFilterChip('pending', 'Pending (${_installments.where((i) => i.isPending).length})'),
                    const SizedBox(width: AppSpacing.xs),
                    _buildFilterChip('partially_paid', 'Partially Paid (${_installments.where((i) => i.isPartiallyPaid).length})'),
                    const SizedBox(width: AppSpacing.xs),
                    _buildFilterChip('overdue', 'Overdue (${_installments.where((i) => i.isOverdue).length})'),
                    const SizedBox(width: AppSpacing.xs),
                    _buildFilterChip('paid', 'Paid (${_installments.where((i) => i.isPaid).length})'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Installments List
              if (filteredInstallments.isEmpty) ...[
                const AppEmptyState(
                  title: 'No Installments Match Filter',
                  subtitle: 'Select another filter chip to view installments.',
                  icon: Icons.filter_list_off_rounded,
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredInstallments.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (ctx, idx) {
                    final inst = filteredInstallments[idx];
                    return _buildInstallmentCard(inst);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _statusFilter = value);
      },
    );
  }

  Widget _buildFinancialSummaryCard(LoanModel loan, double progress) {
    return Card(
      elevation: 1,
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status badge and Frequency
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: loan.isActive ? AppColors.successContainer : AppColors.secondaryContainer,
                        borderRadius: AppSpacing.roundedXs,
                      ),
                      child: Text(
                        loan.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.bold,
                          color: loan.isActive ? AppColors.onSuccessContainer : AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${loan.frequency.toUpperCase()} • ${loan.totalInstallments} Periods',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.0),
                    ),
                  ],
                ),
                Text(
                  'Started ${loan.startDate}',
                  style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Principal Amount',
                    CurrencyFormatter.format(loan.principalAmount),
                    AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Monthly Rate',
                    '${loan.interestRate.toStringAsFixed(1)}% / mo',
                    AppColors.textPrimaryLight,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total Interest',
                    CurrencyFormatter.format(loan.totalInterest),
                    AppColors.secondary,
                  ),
                ),
              ],
            ),
            const Divider(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Repayment',
                    CurrencyFormatter.format(loan.totalAmount),
                    AppColors.primary,
                    isLarge: true,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Amount Collected',
                    CurrencyFormatter.format(loan.amountCollected),
                    AppColors.success,
                    isLarge: true,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Outstanding Balance',
                    CurrencyFormatter.format(loan.outstandingBalance),
                    AppColors.error,
                    isLarge: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Repayment Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Repayment Progress', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600)),
                Text('${progress.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 6.0),
            ClipRRect(
              borderRadius: AppSpacing.roundedSm,
              child: LinearProgressIndicator(
                value: (progress / 100.0).clamp(0.0, 1.0),
                minHeight: 8.0,
                backgroundColor: AppColors.outlineVariantLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color, {bool isLarge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2.0),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 15.0 : 13.0,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildBorrowerInfoCard(LoanModel loan) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowestLight,
      shape: const RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedMd,
        side: BorderSide(color: AppColors.outlineVariantLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.person, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                  ),
                  if (loan.customerPhone != null && loan.customerPhone!.isNotEmpty)
                    Text(
                      'Phone: ${loan.customerPhone}',
                      style: const TextStyle(fontSize: 12.0, color: AppColors.textMutedLight),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstallmentCard(InstallmentModel inst) {
    Color statusBg;
    Color statusFg;
    String statusDisplay;

    if (inst.isPaid) {
      statusBg = AppColors.successContainer;
      statusFg = AppColors.onSuccessContainer;
      statusDisplay = 'PAID';
    } else if (inst.isPartiallyPaid) {
      statusBg = AppColors.secondaryContainer;
      statusFg = AppColors.onSecondaryContainer;
      statusDisplay = 'PARTIALLY PAID';
    } else if (inst.isOverdue) {
      statusBg = AppColors.errorContainer;
      statusFg = AppColors.onErrorContainer;
      statusDisplay = 'OVERDUE';
    } else {
      statusBg = AppColors.surfaceContainerLowestLight;
      statusFg = AppColors.textPrimaryLight;
      statusDisplay = 'PENDING';
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedSm,
        side: BorderSide(
          color: inst.isOverdue ? AppColors.error : AppColors.outlineVariantLight,
          width: inst.isOverdue ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Period label, due date, status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(50),
                        borderRadius: AppSpacing.roundedXs,
                      ),
                      child: Text(
                        inst.periodLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14.0,
                          color: inst.isOverdue ? AppColors.error : AppColors.textMutedLight,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          'Due: ${inst.dueDate}',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: inst.isOverdue ? FontWeight.bold : FontWeight.w500,
                            color: inst.isOverdue ? AppColors.error : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: AppSpacing.roundedXs,
                  ),
                  child: Text(
                    statusDisplay,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: statusFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Row 2: Amounts breakdown
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount Due', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                      Text(CurrencyFormatter.format(inst.amountDue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Amount Paid', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                      Text(
                        CurrencyFormatter.format(inst.amountPaid),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.success),
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
                        CurrencyFormatter.format(inst.outstandingBalance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                          color: inst.outstandingBalance > 0 ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),

            // Row 3: Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // View receipt history link
                TextButton.icon(
                  onPressed: () => _viewPaymentsHistory(inst),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16.0),
                  label: const Text('Receipts', style: TextStyle(fontSize: 12.0)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                ),
                Row(
                  children: [
                    // Edit installment button
                    if (!inst.isPaid) ...[
                      OutlinedButton.icon(
                        onPressed: () => _openEditInstallmentDialog(inst),
                        icon: const Icon(Icons.edit_rounded, size: 14.0),
                        label: const Text('Edit', style: TextStyle(fontSize: 12.0)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],

                    // Mark as Paid / Record Payment Action
                    if (!inst.isPaid) ...[
                      ElevatedButton.icon(
                        onPressed: () => _openRecordPaymentDialog(inst),
                        icon: const Icon(Icons.payments_rounded, size: 14.0),
                        label: Text(
                          inst.isPartiallyPaid ? 'Pay Remaining' : 'Mark as Paid',
                          style: const TextStyle(fontSize: 12.0),
                        ),
                        style: ElevatedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        ),
                      ),
                    ] else ...[
                      const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16.0),
                          SizedBox(width: 4.0),
                          Text('Settled', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12.0)),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
