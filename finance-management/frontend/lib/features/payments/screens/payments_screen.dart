import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../installments/screens/installments_screen.dart';
import '../../payment_plans/screens/payment_plans_screen.dart';
import '../models/payment_model.dart';
import '../repositories/payment_repository.dart';

/// Central Payments Hub providing Tab-based navigation across Payments, Plans & Installments
class PaymentsScreen extends StatefulWidget {
  final int initialTabIndex;

  const PaymentsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PaymentRepository _paymentRepository = PaymentRepository();

  List<PaymentModel> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _fetchPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);
    try {
      final list = await _paymentRepository.getPayments();
      if (mounted) {
        setState(() {
          _payments = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isNarrow = constraints.maxWidth < 650.0;

          return Column(
            children: [
              // Tab Header
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4.0),
                child: isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payments Hub',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: _fetchPayments,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: const [
                              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18.0), text: 'Transactions'),
                              Tab(icon: Icon(Icons.assignment_outlined, size: 18.0), text: 'Payment Plans'),
                              Tab(icon: Icon(Icons.calendar_month_outlined, size: 18.0), text: 'Installments'),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TabBar(
                              controller: _tabController,
                              tabs: const [
                                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transactions'),
                                Tab(icon: Icon(Icons.assignment_outlined), text: 'Payment Plans'),
                                Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Installments'),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: _fetchPayments,
                          ),
                        ],
                      ),
              ),
              const Divider(height: 1),
              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionsTab(),
                    const PaymentPlansScreen(),
                    const InstallmentsScreen(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionsTab() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_payments.isEmpty) {
      return AppEmptyState(
        title: 'No Payments Recorded Yet',
        subtitle: 'Payments collected across loans will be tracked here with receipts, dates, and reference codes.',
        icon: Icons.receipt_long_outlined,
        actionText: 'Refresh',
        onAction: _fetchPayments,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: ListView.separated(
        padding: AppSpacing.pagePaddingMobile,
        itemCount: _payments.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final payment = _payments[index];

          return Card(
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
                      Icons.check_rounded,
                      color: AppColors.success,
                      size: 20.0,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                payment.paymentReference,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                borderRadius: AppSpacing.roundedXs,
                              ),
                              child: Text(
                                payment.paymentMethod.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          '${payment.customerName}${payment.planCode != null ? ' • Plan: ${payment.planCode}' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          payment.paymentDate,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textMutedLight,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${CurrencyFormatter.format(payment.amount)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Receipt #${payment.paymentReference} • Amount: ${CurrencyFormatter.format(payment.amount)}')),
                          );
                        },
                        child: const Text('Receipt', style: TextStyle(fontSize: 11.0)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
