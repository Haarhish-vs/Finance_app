import 'package:flutter/material.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../payment_plans/repositories/loan_repository.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

/// Comprehensive modal dialog for Adding Customer and Originating Loans with:
/// 1. Customer & Loan setup with Indian Rupee formatting
/// 2. Live interest calculation preview (simple interest: P * r% * months)
/// 3. Weekly / Monthly duration conversion (52 weeks = 12 months)
/// 4. Interactive review and editing of individual installment dates & amounts before confirmation
class CustomerFormDialog extends StatefulWidget {
  final CustomerModel? initialCustomer;
  final bool isEditOnly;
  final VoidCallback onSaved;

  const CustomerFormDialog({
    super.key,
    this.initialCustomer,
    this.isEditOnly = false,
    required this.onSaved,
  });

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final CustomerRepository _customerRepository = CustomerRepository();
  final LoanRepository _loanRepository = LoanRepository();

  // Wizard Step: 0 = Customer & Loan Setup, 1 = Review & Edit Installment Schedule
  int _currentStep = 0;

  // Controllers - Customer
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  // Controllers - Loan Parameters
  late final TextEditingController _principalController;
  late final TextEditingController _interestRateController;
  late final TextEditingController _durationController;

  String _frequency = 'monthly'; // 'monthly' or 'weekly'
  DateTime _startDate = DateTime.now();
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));

  bool _isSubmitting = false;
  String? _errorMessage;

  // Schedule preview state
  List<Map<String, dynamic>> _editableInstallments = [];
  double _originalTotalRepayment = 0.0;
  double _revisedTotalRepayment = 0.0;

  bool get _isCustomerEditOnly => widget.isEditOnly && widget.initialCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCustomer;

    _nameController = TextEditingController(text: c?.fullName ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _notesController = TextEditingController(text: c?.notes ?? '');

    // Default loan values
    _principalController = TextEditingController(text: '50000');
    _interestRateController = TextEditingController(text: '5.0'); // 5% monthly (5 paisa vatti)
    _durationController = TextEditingController(text: '10'); // 10 months

    _recomputeFirstDueDate();

    _principalController.addListener(_onLoanParamsChanged);
    _interestRateController.addListener(_onLoanParamsChanged);
    _durationController.addListener(_onLoanParamsChanged);
  }

  @override
  void dispose() {
    _principalController.removeListener(_onLoanParamsChanged);
    _interestRateController.removeListener(_onLoanParamsChanged);
    _durationController.removeListener(_onLoanParamsChanged);

    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    _principalController.dispose();
    _interestRateController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _onLoanParamsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _recomputeFirstDueDate() {
    if (_frequency == 'weekly') {
      _firstDueDate = _startDate.add(const Duration(days: 7));
    } else {
      final y = _startDate.year;
      final m = _startDate.month + 1;
      final d = _startDate.day;
      final lastDayOfTargetMonth = DateTime(y, m + 1, 0).day;
      final safeDay = d > lastDayOfTargetMonth ? lastDayOfTargetMonth : d;
      _firstDueDate = DateTime(y, m, safeDay);
    }
  }

  // --- Live Calculation Preview Helpers ---
  double get _currentPrincipal => double.tryParse(_principalController.text.trim()) ?? 0.0;
  double get _currentRate => double.tryParse(_interestRateController.text.trim()) ?? 0.0;
  int get _currentDuration => int.tryParse(_durationController.text.trim()) ?? 0;

  double get _calculatedDurationInMonths {
    if (_currentDuration <= 0) return 0.0;
    if (_frequency == 'weekly') {
      return (_currentDuration * 12.0) / 52.0;
    }
    return _currentDuration.toDouble();
  }

  double get _calculatedTotalInterest {
    return _currentPrincipal * (_currentRate / 100.0) * _calculatedDurationInMonths;
  }

  double get _calculatedTotalRepayment {
    return _currentPrincipal + _calculatedTotalInterest;
  }

  double get _calculatedInstallmentAmount {
    if (_currentDuration <= 0) return 0.0;
    return _calculatedTotalRepayment / _currentDuration;
  }

  DateTime get _calculatedFinalDueDate {
    if (_currentDuration <= 1) return _firstDueDate;
    if (_frequency == 'weekly') {
      return _firstDueDate.add(Duration(days: (_currentDuration - 1) * 7));
    } else {
      final y = _firstDueDate.year;
      final m = _firstDueDate.month + (_currentDuration - 1);
      final d = _firstDueDate.day;
      final lastDay = DateTime(y, m + 1, 0).day;
      return DateTime(y, m, d > lastDay ? lastDay : d);
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Transition to Step 2: Generate and preview the full installment schedule from backend or client
  Future<void> _proceedToScheduleReview() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final preview = await _loanRepository.previewLoan(
        principal: _currentPrincipal,
        interestRate: _currentRate,
        frequency: _frequency,
        totalInstallments: _currentDuration,
        startDate: _formatDate(_startDate),
        firstDueDate: _formatDate(_firstDueDate),
      );

      final list = preview.installments.map((inst) {
        return {
          'installment_number': inst['installment_number'] ?? 1,
          'period_label': inst['period_label'] ?? 'Month 1',
          'due_date': inst['due_date'] ?? '',
          'amount_due': (inst['amount_due'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();

      final total = list.fold<double>(0.0, (sum, i) => sum + (i['amount_due'] as double));

      setState(() {
        _editableInstallments = list;
        _originalTotalRepayment = preview.totalRepayment;
        _revisedTotalRepayment = total;
        _currentStep = 1;
        _isSubmitting = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not generate schedule preview: $e';
        _isSubmitting = false;
      });
    }
  }

  void _recalculateRevisedTotal() {
    final total = _editableInstallments.fold<double>(
      0.0,
      (sum, i) => sum + (i['amount_due'] as double),
    );
    setState(() {
      _revisedTotalRepayment = double.parse(total.toStringAsFixed(2));
    });
  }

  /// Edit individual installment due date
  Future<void> _pickInstallmentDueDate(int index) async {
    final current = DateTime.tryParse(_editableInstallments[index]['due_date'] as String) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() {
        _editableInstallments[index]['due_date'] = _formatDate(picked);
      });
    }
  }

  /// Edit individual installment amount
  Future<void> _editInstallmentAmount(int index) async {
    final currentAmount = (_editableInstallments[index]['amount_due'] as double).toStringAsFixed(2);
    final controller = TextEditingController(text: currentAmount);

    final updated = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${_editableInstallments[index]['period_label']} Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify custom due amount for this installment period:',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.currency_rupee_rounded),
                labelText: 'Amount Due',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          AppButton(
            text: 'Update',
            onPressed: () {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                Navigator.of(ctx).pop(val);
              }
            },
          ),
        ],
      ),
    );

    if (updated != null) {
      setState(() {
        _editableInstallments[index]['amount_due'] = updated;
        _recalculateRevisedTotal();
      });
    }
  }

  /// Submit the full customer & loan form
  Future<void> _confirmAndDisburseLoan() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String clientRequestId = 'LN-${DateTime.now().millisecondsSinceEpoch}';

    final payload = <String, dynamic>{
      'idempotency_key': clientRequestId,
      'plan_code': clientRequestId,
      'customer_id': widget.initialCustomer?.id,
      'name': _nameController.text.trim(),
      'customer_name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'principal': _currentPrincipal,
      'interest_rate': _currentRate,
      'frequency': _frequency,
      'total_installments': _currentDuration,
      'start_date': _formatDate(_startDate),
      'first_due_date': _formatDate(_firstDueDate),
      'custom_installments': _editableInstallments.map((inst) => {
        'installment_number': inst['installment_number'],
        'due_date': inst['due_date'],
        'amount_due': inst['amount_due'],
      }).toList(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    try {
      final createdLoan = await _loanRepository.createLoan(payload);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              'Loan ${createdLoan.planCode} (${CurrencyFormatter.format(createdLoan.totalAmount)}) originated successfully!',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Loan origination failed: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  /// Submit customer-only edit
  Future<void> _saveCustomerOnly() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final customerData = <String, dynamic>{
      'full_name': _nameController.text.trim(),
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };

    try {
      await _customerRepository.updateCustomer(widget.initialCustomer!.id, customerData);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Customer profile updated successfully.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update customer: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 480.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12.0 : AppSpacing.md,
        vertical: isMobile ? 16.0 : AppSpacing.lg,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppSpacing.roundedLg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double dialogWidth = constraints.maxWidth > 640.0 ? 600.0 : double.infinity;
          final isNarrow = constraints.maxWidth < 480.0;

          return Container(
            width: dialogWidth,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            padding: EdgeInsets.all(isNarrow ? AppSpacing.md : AppSpacing.md + 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCustomerEditOnly
                                ? 'Edit Customer Profile'
                                : (_currentStep == 0
                                    ? 'Add Customer & Originate Loan'
                                    : 'Review & Edit Installment Schedule'),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isNarrow ? 17.0 : 19.0,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!_isCustomerEditOnly) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              _currentStep == 0
                                  ? 'Step 1 of 2: Borrower details & loan calculation'
                                  : 'Step 2 of 2: Confirm installment dates & amounts',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMutedLight,
                                    fontSize: 11.5,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22.0),
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),

                // Error alert box
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: AppSpacing.roundedSm,
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18.0),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 12.0,
                              color: AppColors.onErrorContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Body content based on step
                Expanded(
                  child: _isCustomerEditOnly
                      ? _buildCustomerOnlyForm(isNarrow)
                      : (_currentStep == 0
                          ? _buildStep1CustomerAndLoan(isNarrow)
                          : _buildStep2ScheduleReview(isNarrow)),
                ),

                const SizedBox(height: AppSpacing.xs),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),

                // Action buttons footer
                _buildActionButtons(isNarrow),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomerOnlyForm(bool isNarrow) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              controller: _nameController,
              label: 'Customer Name *',
              hint: 'e.g. Ramesh Kumar',
              prefixIcon: const Icon(Icons.person_outline),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Customer name is required' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _phoneController,
              label: 'Phone Number *',
              hint: '+91 98765 43210',
              prefixIcon: const Icon(Icons.phone_outlined),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone number is required';
                if (!RegExp(r'^[0-9+ ]{10,15}$').hasMatch(v.trim())) {
                  return 'Enter a valid 10-digit phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'optional',
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _addressController,
              label: 'Residential Address',
              hint: 'optional',
              maxLines: 2,
              prefixIcon: const Icon(Icons.home_outlined),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _notesController,
              label: 'Notes',
              hint: 'optional',
              maxLines: 2,
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1CustomerAndLoan(bool isNarrow) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Customer Profile Details
            Row(
              children: [
                const Icon(Icons.person_rounded, size: 18.0, color: AppColors.primary),
                const SizedBox(width: 6.0),
                Text(
                  '1. Customer Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (isNarrow) ...[
              AppTextField(
                controller: _nameController,
                label: 'Customer Name *',
                hint: 'e.g. ashok',
                prefixIcon: const Icon(Icons.person_outline),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Customer name is required';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _phoneController,
                label: 'Phone Number *',
                hint: '9876543210',
                prefixIcon: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone number is required';
                  if (!RegExp(r'^[0-9+ ]{10,15}$').hasMatch(v.trim())) {
                    return 'Valid 10-15 digits required';
                  }
                  return null;
                },
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _nameController,
                      label: 'Customer Name *',
                      hint: 'e.g. Senthil Kumar',
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Customer name is required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      hint: '9876543210',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone number is required';
                        if (!RegExp(r'^[0-9+ ]{10,15}$').hasMatch(v.trim())) {
                          return 'Valid 10-15 digits required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // Section 2: Loan Financial Parameters
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 18.0, color: AppColors.primary),
                const SizedBox(width: 6.0),
                Text(
                  '2. Loan Parameters',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Principal and Interest Rate Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    controller: _principalController,
                    label: 'Principal (${CurrencyFormatter.symbol}) *',
                    hint: '50000',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Principal required';
                      final val = double.tryParse(v.trim());
                      if (val == null || val <= 0) return 'Must be > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: _interestRateController,
                    label: 'Monthly Rate (%) *',
                    hint: '5.0',
                    prefixIcon: const Icon(Icons.percent_rounded),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Rate required';
                      final val = double.tryParse(v.trim());
                      if (val == null || val < 0) return '>= 0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              'Monthly interest rate (e.g. 5 = 5% per month or 5 paisa vatti). Simple interest applied to principal.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMutedLight,
                    fontSize: 11.0,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Payment Frequency Selection (Full width, avoids vertical label splitting)
            Text(
              'Payment Frequency',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
            ),
            const SizedBox(height: 6.0),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: true,
                segments: const [
                  ButtonSegment(
                    value: 'monthly',
                    label: Text('Monthly'),
                    icon: Icon(Icons.calendar_month_outlined, size: 16.0),
                  ),
                  ButtonSegment(
                    value: 'weekly',
                    label: Text('Weekly'),
                    icon: Icon(Icons.view_week_outlined, size: 16.0),
                  ),
                ],
                selected: {_frequency},
                onSelectionChanged: (set) {
                  setState(() {
                    _frequency = set.first;
                    _recomputeFirstDueDate();
                  });
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Duration Field
            AppTextField(
              controller: _durationController,
              label: _frequency == 'weekly' ? 'Duration (Number of Weeks) *' : 'Duration (Number of Months) *',
              hint: _frequency == 'weekly' ? 'e.g. 24' : 'e.g. 10',
              prefixIcon: const Icon(Icons.schedule_rounded),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Duration is required';
                final val = int.tryParse(v.trim());
                if (val == null || val <= 0) return 'Must be >= 1';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Dates Row (Start Date & First Due Date)
            if (isNarrow) ...[
              _buildDatePickerTile(
                label: 'Loan Start Date',
                date: _startDate,
                icon: Icons.calendar_today_rounded,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate = picked;
                      _recomputeFirstDueDate();
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildDatePickerTile(
                label: 'First Due Date',
                date: _firstDueDate,
                icon: Icons.event_available_rounded,
                helper: _frequency == 'weekly' ? '1 wk default' : '1 mo default',
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _firstDueDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setState(() {
                      _firstDueDate = picked;
                    });
                  }
                },
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: _buildDatePickerTile(
                      label: 'Loan Start Date',
                      date: _startDate,
                      icon: Icons.calendar_today_rounded,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            _recomputeFirstDueDate();
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildDatePickerTile(
                      label: 'First Due Date',
                      date: _firstDueDate,
                      icon: Icons.event_available_rounded,
                      helper: _frequency == 'weekly' ? '1 wk default' : '1 mo default',
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _firstDueDate,
                          firstDate: _startDate,
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() {
                            _firstDueDate = picked;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // Section 3: Live Calculation Preview Card
            Row(
              children: [
                const Icon(Icons.calculate_rounded, size: 18.0, color: AppColors.primary),
                const SizedBox(width: 6.0),
                Text(
                  '3. Live Calculation Preview',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            _buildLiveCalculationCard(isNarrow),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerTile({
    required String label,
    required DateTime date,
    required IconData icon,
    String? helper,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: AppSpacing.roundedSm,
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.0, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
            if (helper != null) ...[
              Text(
                helper,
                style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
              ),
              const SizedBox(width: 4.0),
            ],
            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMutedLight),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCalculationCard(bool isNarrow) {
    final principal = _currentPrincipal;
    final rate = _currentRate;
    final totalInterest = _calculatedTotalInterest;
    final totalRepayment = _calculatedTotalRepayment;
    final installmentAmount = _calculatedInstallmentAmount;
    final totalInstallments = _currentDuration;
    final firstDueStr = _formatDate(_firstDueDate);
    final finalDueStr = _formatDate(_calculatedFinalDueDate);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          // Highlight summary bar: Total Repayment & Installment Amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10.0),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(14),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusMd),
                topRight: Radius.circular(AppSpacing.radiusMd),
              ),
              border: const Border(
                bottom: BorderSide(color: AppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Repayment',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(totalRepayment),
                          style: const TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 32.0,
                  width: 1.0,
                  color: AppColors.borderLight,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _frequency == 'weekly' ? 'Weekly Due' : 'Monthly Due',
                        style: const TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMutedLight,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.format(installmentAmount),
                          style: const TextStyle(
                            fontSize: 17.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2-Column Key Financial Metrics Grid
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Principal Amount',
                        CurrencyFormatter.format(principal),
                        AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildMetricTile(
                        'Monthly Interest Rate',
                        '${rate.toStringAsFixed(1)}% / mo',
                        AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'Total Interest',
                        CurrencyFormatter.format(totalInterest),
                        AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildMetricTile(
                        'Tenure & Count',
                        '$totalInstallments ${_frequency == 'weekly' ? 'Weeks' : 'Months'}',
                        AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.md),

                // Due Dates Schedule Row (Overflow-proof)
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14.0, color: AppColors.textMutedLight),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'First Due',
                                  style: TextStyle(fontSize: 10.5, color: AppColors.textMutedLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  firstDueStr,
                                  style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.event_note_rounded, size: 14.0, color: AppColors.textMutedLight),
                          const SizedBox(width: 4.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Final Due',
                                  style: TextStyle(fontSize: 10.5, color: AppColors.textMutedLight),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  finalDueStr,
                                  style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2.0),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 14.0 : 13.0,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2ScheduleReview(bool isNarrow) {
    final diff = _revisedTotalRepayment - _originalTotalRepayment;
    final hasDiff = diff.abs() > 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary bar comparing original & revised total
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: hasDiff ? AppColors.errorContainer.withAlpha(50) : AppColors.successContainer.withAlpha(50),
            borderRadius: AppSpacing.roundedSm,
            border: Border.all(
              color: hasDiff ? AppColors.error : AppColors.success,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scheduled Repayment Total', style: TextStyle(fontSize: 11.0, color: AppColors.textMutedLight)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(_revisedTotalRepayment),
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (hasDiff) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Original: ${CurrencyFormatter.format(_originalTotalRepayment)}',
                      style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
                    ),
                    Text(
                      'Diff: ${diff > 0 ? '+' : ''}${CurrencyFormatter.format(diff)}',
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: diff > 0 ? AppColors.error : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16.0, color: AppColors.success),
                    SizedBox(width: 4.0),
                    Text(
                      'Exact Balance',
                      style: TextStyle(fontSize: 12.0, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tap any due date or amount below to customize before originating the loan.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.0, color: AppColors.textMutedLight),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Scrollable Table of Installments
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariantLight),
              borderRadius: AppSpacing.roundedSm,
            ),
            child: ListView.separated(
              itemCount: _editableInstallments.length,
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemBuilder: (ctx, index) {
                final inst = _editableInstallments[index];
                final period = inst['period_label'] as String;
                final dueDate = inst['due_date'] as String;
                final amount = (inst['amount_due'] as num).toDouble();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6.0),
                  child: Row(
                    children: [
                      // Period badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowestLight,
                          borderRadius: AppSpacing.roundedXs,
                          border: Border.all(color: AppColors.outlineVariantLight),
                        ),
                        child: Text(
                          period,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.0),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Due Date (Tap to edit)
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickInstallmentDueDate(index),
                          borderRadius: AppSpacing.roundedXs,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_calendar_rounded, size: 15.0, color: AppColors.primary),
                              const SizedBox(width: 4.0),
                              Flexible(
                                child: Text(
                                  dueDate,
                                  style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6.0),

                      // Amount (Tap to edit)
                      InkWell(
                        onTap: () => _editInstallmentAmount(index),
                        borderRadius: AppSpacing.roundedXs,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withAlpha(60),
                            borderRadius: AppSpacing.roundedXs,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(amount),
                                style: const TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4.0),
                              const Icon(Icons.edit_rounded, size: 13.0, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isNarrow) {
    if (_isCustomerEditOnly) {
      return Row(
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const Spacer(),
          AppButton(
            text: 'Save Changes',
            icon: Icons.check_circle_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _saveCustomerOnly,
          ),
        ],
      );
    }

    if (_currentStep == 0) {
      return Row(
        children: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 12.0),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: AppButton(
              text: isNarrow
                  ? 'Review Schedule'
                  : 'Review Schedule ($_currentDuration ${_frequency == 'weekly' ? 'Weeks' : 'Months'})',
              icon: Icons.arrow_forward_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _proceedToScheduleReview,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _isSubmitting ? null : () => setState(() => _currentStep = 0),
          icon: const Icon(Icons.arrow_back_rounded, size: 16.0),
          label: Text(isNarrow ? 'Back' : 'Parameters'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 12.0),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: AppButton(
            text: isNarrow ? 'Confirm Loan' : 'Confirm & Disburse Loan',
            icon: Icons.check_circle_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _confirmAndDisburseLoan,
          ),
        ),
      ],
    );
  }
}
