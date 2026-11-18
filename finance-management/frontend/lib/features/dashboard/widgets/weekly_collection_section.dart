import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../models/weekly_collections_model.dart';
import '../repositories/dashboard_repository.dart';

/// Weekly Collection Overview grouped by weekday (Monday through Sunday)
/// with interactive drill-down showing customer name, phone, weekly installment amount,
/// due date, status, and outstanding balance.
class WeeklyCollectionSection extends StatefulWidget {
  const WeeklyCollectionSection({super.key});

  @override
  State<WeeklyCollectionSection> createState() => _WeeklyCollectionSectionState();
}

class _WeeklyCollectionSectionState extends State<WeeklyCollectionSection> {
  final DashboardRepository _repository = DashboardRepository();

  DateTime _anchorDate = DateTime.now();
  WeeklyCollectionsResponse? _data;
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedWeekday = '';

  @override
  void initState() {
    super.initState();
    // Default selected weekday to today's weekday
    final now = DateTime.now();
    _selectedWeekday = _getWeekdayName(now.weekday);
    _loadWeeklyCollections();
  }

  String _getWeekdayName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

  Future<void> _loadWeeklyCollections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getWeeklyCollections(weekDate: _anchorDate);
      if (mounted) {
        setState(() {
          _data = res;
          _isLoading = false;
          // Ensure selected weekday exists in response
          if (!_data!.weekdays.any((w) => w.weekday == _selectedWeekday)) {
            _selectedWeekday = _data!.weekdays.isNotEmpty ? _data!.weekdays.first.weekday : 'Monday';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load weekly collections: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _previousWeek() {
    setState(() {
      _anchorDate = _anchorDate.subtract(const Duration(days: 7));
    });
    _loadWeeklyCollections();
  }

  void _nextWeek() {
    setState(() {
      _anchorDate = _anchorDate.add(const Duration(days: 7));
    });
    _loadWeeklyCollections();
  }

  void _resetToCurrentWeek() {
    setState(() {
      _anchorDate = DateTime.now();
    });
    _loadWeeklyCollections();
  }

  String _formatWeekRange(String startIso, String endIso) {
    try {
      final start = DateTime.parse(startIso);
      final end = DateTime.parse(endIso);
      final fmt = DateFormat('dd MMM');
      final yearFmt = DateFormat('yyyy');
      return '${fmt.format(start)} – ${fmt.format(end)} ${yearFmt.format(end)}';
    } catch (_) {
      return '$startIso to $endIso';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: AppColors.surfaceLight,
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedMd,
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Week Controls
            _buildHeader(theme),
            const SizedBox(height: AppSpacing.md),

            // Main Content
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36.0),
                child: Center(
                  child: AppLoadingIndicator(
                    message: 'Loading weekly collection overview...',
                  ),
                ),
              )
            else if (_errorMessage != null)
              _buildErrorView()
            else if (_data != null) ...[
              // Week Summary Bar
              _buildWeekSummaryBar(theme),
              const SizedBox(height: AppSpacing.md),

              // Weekday Cards Selector (Monday — 12 customers, Tuesday — 8 customers...)
              _buildWeekdaySelectorRow(theme),
              const SizedBox(height: AppSpacing.md),

              // Selected Weekday Installment List
              _buildSelectedDayDetail(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

        final titleWidget = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppSpacing.roundedSm,
              ),
              child: const Icon(
                Icons.calendar_view_week_rounded,
                color: AppColors.primary,
                size: 20.0,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Collection Overview',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Grouped by weekday for scheduled microfinance installments',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final controlsWidget = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_left_rounded, size: 20.0),
                tooltip: 'Previous Week',
                onPressed: _previousWeek,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.backgroundLight,
                  padding: const EdgeInsets.all(6.0),
                ),
              ),
              const SizedBox(width: 4.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: AppSpacing.roundedSm,
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Text(
                  _data != null
                      ? _formatWeekRange(_data!.weekStart, _data!.weekEnd)
                      : 'Selected Week',
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4.0),
              IconButton.filledTonal(
                icon: const Icon(Icons.chevron_right_rounded, size: 20.0),
                tooltip: 'Next Week',
                onPressed: _nextWeek,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.backgroundLight,
                  padding: const EdgeInsets.all(6.0),
                ),
              ),
              const SizedBox(width: 6.0),
              OutlinedButton(
                onPressed: _resetToCurrentWeek,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Current Week', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: AppSpacing.sm),
              controlsWidget,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: titleWidget),
            controlsWidget,
          ],
        );
      },
    );
  }

  Widget _buildWeekSummaryBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryStat(
            'Total Due Customers',
            '${_data!.totalWeeklyCustomers}',
            Icons.people_alt_outlined,
            AppColors.primary,
          ),
          const SizedBox(
            height: 28.0,
            child: VerticalDivider(color: AppColors.borderLight),
          ),
          _buildSummaryStat(
            'Total Scheduled',
            CurrencyFormatter.format(_data!.totalWeeklyAmountDue),
            Icons.payments_outlined,
            AppColors.primaryDark,
          ),
          const SizedBox(
            height: 28.0,
            child: VerticalDivider(color: AppColors.borderLight),
          ),
          _buildSummaryStat(
            'Total Collected',
            CurrencyFormatter.format(_data!.totalWeeklyCollected),
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.0, color: color),
        const SizedBox(width: 6.0),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11.0, color: AppColors.textSecondaryLight),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekdaySelectorRow(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _data!.weekdays.map((group) {
          final isSelected = _selectedWeekday == group.weekday;
          final hasCustomers = group.customerCount > 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: AppSpacing.roundedSm,
              onTap: () {
                setState(() {
                  _selectedWeekday = group.weekday;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 136.0,
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (hasCustomers
                          ? AppColors.primaryContainer.withValues(alpha: 0.25)
                          : AppColors.backgroundLight),
                  borderRadius: AppSpacing.roundedSm,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (hasCustomers
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.borderLight),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8.0,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          group.weekday,
                          style: TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, size: 14.0, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      _formatDatePill(group.date),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isSelected ? Colors.white70 : AppColors.textMutedLight,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.2)
                            : (hasCustomers
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        '${group.customerCount} customers',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (hasCustomers ? AppColors.primary : AppColors.textMutedLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      CurrencyFormatter.format(group.totalDue),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDatePill(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd MMM').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Widget _buildSelectedDayDetail(ThemeData theme) {
    final group = _data!.weekdays.firstWhere(
      (w) => w.weekday == _selectedWeekday,
      orElse: () => _data!.weekdays.first,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: AppSpacing.roundedSm,
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Sub-header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available_rounded, size: 18.0, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${group.weekday} Collections (${group.customerCount} customers)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              Text(
                'Total Due: ${CurrencyFormatter.format(group.totalDue)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          if (group.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 36.0,
                      color: AppColors.textMutedLight.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      'No customers scheduled for collection on this ${group.weekday}.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: group.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8.0),
              itemBuilder: (context, index) {
                final item = group.items[index];
                return _buildCustomerDueCard(item);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerDueCard(WeeklyDueItem item) {
    return Card(
      color: AppColors.surfaceLight,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.roundedSm,
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm + 2.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Borrower Avatar
            CircleAvatar(
              radius: 18.0,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                item.customerName.isNotEmpty ? item.customerName[0].toUpperCase() : 'B',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.0,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Customer Name & Phone
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2.0),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 12.0, color: AppColors.textSecondaryLight),
                      const SizedBox(width: 3.0),
                      Text(
                        item.phoneNumber,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondaryLight),
                      ),
                      if (item.planCode.isNotEmpty) ...[
                        const SizedBox(width: 6.0),
                        Text(
                          '• ${item.planCode}',
                          style: const TextStyle(fontSize: 11.0, color: AppColors.textMutedLight),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Due Date & Installment Number
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due: ${item.dueDate}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Week #${item.installmentNumber}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMutedLight),
                  ),
                ],
              ),
            ),

            // Amount Due & Outstanding Balance
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(item.installmentAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Bal: ${CurrencyFormatter.format(item.outstandingBalance)}',
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: item.outstandingBalance > 0 ? AppColors.error : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),

            // Status Badge (Paid / Pending / Overdue)
            _buildStatusBadge(item.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'paid':
        bg = AppColors.successContainer;
        fg = AppColors.onSuccessContainer;
        label = 'Paid';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'overdue':
        bg = AppColors.errorContainer;
        fg = AppColors.onErrorContainer;
        label = 'Overdue';
        icon = Icons.error_outline_rounded;
        break;
      default:
        bg = AppColors.warningContainer;
        fg = AppColors.onWarningContainer;
        label = 'Pending';
        icon = Icons.schedule_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.0, color: fg),
          const SizedBox(width: 3.0),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 36.0, color: AppColors.error),
            const SizedBox(height: 8.0),
            Text(
              _errorMessage ?? 'Error loading weekly collections',
              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8.0),
            TextButton.icon(
              onPressed: _loadWeeklyCollections,
              icon: const Icon(Icons.refresh_rounded, size: 16.0),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
