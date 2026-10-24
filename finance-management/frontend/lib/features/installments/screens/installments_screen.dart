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
import '../../payment_plans/screens/loan_details_screen.dart';
import '../models/installment_model.dart';
import '../repositories/installment_repository.dart';

/// Screen displaying the global Installments Schedule with real-time status tracking,
/// quick payment recording, and permitted schedule edits
class InstallmentsScreen extends StatefulWidget {
  const InstallmentsScreen({super.key});

  @override
  State<InstallmentsScreen> createState() => _InstallmentsScreenState();
}

class _InstallmentsScreenState extends State<InstallmentsScreen> {
  final InstallmentRepository _repository = InstallmentRepository();

  List<InstallmentModel> _installments = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedStatus = 'all';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalRecords = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _fetchInstallments();
  }

  Future<void> _fetchInstallments({bool resetPage = false}) async {
    if (resetPage) {
      _currentPage = 1;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getInstallments(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        page: _currentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          _installments = res.installments;
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
          _errorMessage = 'Could not load installments: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Quick record payment dialog from installments hub
  Future<void> _quickRecordPayment(InstallmentModel inst) async {
    final amountController = TextEditingController(
      text: inst.outstandingBalance.toStringAsFixed(2),
    );
    final notesController = TextEditingController();
    String paymentMethod = 'cash';
    DateTime paymentDate = DateTime.now();
    bool isSubmitting = false;
    String? dialogError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Record Payment - ${inst.periodLabel}'),
            content: SizedBox(
              width: 420.0,
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
                        child: Text(dialogError!, style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 12.0)),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    Text(
                      'Borrower: ${inst.customerName ?? 'Borrower'} • Due: ${inst.dueDate}',
                      style: const TextStyle(fontSize: 12.0, color: AppColors.textMutedLight),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Balance:', style: Theme.of(ctx).textTheme.bodySmall),
                        Text(
                          CurrencyFormatter.format(inst.outstandingBalance),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    AppTextField(
                      controller: amountController,
                      label: 'Amount to Pay (${CurrencyFormatter.symbol}) *',
                      hint: '0.00',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: AppSpacing.sm),

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
                            DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                            DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => paymentMethod = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    AppTextField(
                      controller: notesController,
                      label: 'Remarks / Notes',
                      hint: 'Optional payment notes',
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                text: 'Record Payment',
                icon: Icons.check_circle_rounded,
                isLoading: isSubmitting,
                onPressed: () async {
                  final entered = double.tryParse(amountController.text.trim());
                  if (entered == null || entered <= 0) {
                    setDialogState(() => dialogError = 'Enter a valid payment amount');
                    return;
                  }
                  if (entered > inst.outstandingBalance + 0.01) {
                    setDialogState(() => dialogError = 'Amount cannot exceed balance (${CurrencyFormatter.format(inst.outstandingBalance)})');
                    return;
                  }

                  setDialogState(() {
                    isSubmitting = true;
                    dialogError = null;
                  });

                  try {
                    final dateStr = '${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
                    await _repository.recordPayment(
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
                      _fetchInstallments();
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
                      isSubmitting = false;
                    });
                  } catch (e) {
                    setDialogState(() {
                      dialogError = 'Payment failed: $e';
                      isSubmitting = false;
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

  /// Permitted edit of due date and installment amount
  Future<void> _quickEditInstallment(InstallmentModel inst) async {
    final amountController = TextEditingController(text: inst.amountDue.toStringAsFixed(2));
    DateTime dueDate = DateTime.tryParse(inst.dueDate) ?? DateTime.now();
    bool isSaving = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Edit ${inst.periodLabel}'),
            content: SizedBox(
              width: 400.0,
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
                      child: Text(dialogError!, style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 12.0)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2040),
                      );
                      if (picked != null) setDialogState(() => dueDate = picked);
                    },
                    borderRadius: AppSpacing.roundedSm,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Due Date', prefixIcon: Icon(Icons.event_rounded)),
                      child: Text(
                        '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  AppTextField(
                    controller: amountController,
                    label: 'Amount Due (${CurrencyFormatter.symbol}) *',
                    hint: '0.00',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              AppButton(
                text: 'Save',
                isLoading: isSaving,
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text.trim());
                  if (newAmount == null || newAmount < 0) {
                    setDialogState(() => dialogError = 'Enter a valid amount');
                    return;
                  }
                  if (newAmount < inst.amountPaid) {
                    setDialogState(() => dialogError = 'Amount cannot be less than paid (${CurrencyFormatter.format(inst.amountPaid)})');
                    return;
                  }

                  setDialogState(() {
                    isSaving = true;
                    dialogError = null;
                  });

                  try {
                    final dateStr = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
                    await _repository.updateInstallment(
                      inst.id,
                      dueDate: dateStr,
                      amountDue: newAmount,
                    );

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      _fetchInstallments();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('Installment schedule updated.'),
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
                      dialogError = 'Update failed: $e';
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: AppSpacing.pagePaddingMobile,
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
                        'Installments Schedule',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Timeline tracking for Paid, Partially Paid, Pending, and Overdue dues.',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => _fetchInstallments(resetPage: true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All ($_totalRecords)'),
                  const SizedBox(width: AppSpacing.xs),
                  _buildFilterChip('pending', 'Pending'),
                  const SizedBox(width: AppSpacing.xs),
                  _buildFilterChip('partially_paid', 'Partially Paid'),
                  const SizedBox(width: AppSpacing.xs),
                  _buildFilterChip('overdue', 'Overdue'),
                  const SizedBox(width: AppSpacing.xs),
                  _buildFilterChip('paid', 'Paid'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Main Content
            Expanded(
              child: _buildContent(),
            ),

            // Pagination Footer
            if (!_isLoading && _installments.isNotEmpty && _totalPages > 1) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildPaginationControls(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedStatus = value);
          _fetchInstallments(resetPage: true);
        }
      },
    );
  }

  Widget _buildContent() {
    if (_isLoading && _installments.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null && _installments.isEmpty) {
      return AppErrorView(
        message: _errorMessage!,
        onRetry: () => _fetchInstallments(resetPage: true),
      );
    }

    if (_installments.isEmpty) {
      return const AppEmptyState(
        title: 'No Installments Found',
        subtitle: 'Generated installment schedules and due dates will be tracked here.',
        icon: Icons.calendar_today_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchInstallments(),
      child: ListView.separated(
        itemCount: _installments.length,
        separatorBuilder: (ctx, idx) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (ctx, idx) {
          final inst = _installments[idx];
          return _buildInstallmentCard(inst);
        },
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
      child: InkWell(
        onTap: () {
          // Open parent loan details
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => LoanDetailsScreen(loanId: inst.planId),
            ),
          ).then((_) => _fetchInstallments());
        },
        borderRadius: AppSpacing.roundedSm,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Period Label, Borrower, and Status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withAlpha(60),
                                borderRadius: AppSpacing.roundedXs,
                              ),
                              child: Text(
                                inst.periodLabel,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0, color: AppColors.primary),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                inst.customerName ?? 'Borrower',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          'Due Date: ${inst.dueDate}${inst.isOverdue ? ' (OVERDUE)' : ''}',
                          style: TextStyle(
                            fontSize: 11.0,
                            fontWeight: inst.isOverdue ? FontWeight.bold : FontWeight.w500,
                            color: inst.isOverdue ? AppColors.error : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
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

              // Amounts Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Due', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                        Text(CurrencyFormatter.format(inst.amountDue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Paid', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                        Text(CurrencyFormatter.format(inst.amountPaid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.success)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Balance', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
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
              const SizedBox(height: AppSpacing.xs),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.xs),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!inst.isPaid) ...[
                    OutlinedButton.icon(
                      onPressed: () => _quickEditInstallment(inst),
                      icon: const Icon(Icons.edit_rounded, size: 14.0),
                      label: const Text('Edit', style: TextStyle(fontSize: 12.0)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    ElevatedButton.icon(
                      onPressed: () => _quickRecordPayment(inst),
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
                        Text('Paid in Full', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12.0)),
                      ],
                    ),
                  ],
                ],
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
          'Page $_currentPage of $_totalPages ($_totalRecords items)',
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
                      _fetchInstallments();
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
                      _fetchInstallments();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
