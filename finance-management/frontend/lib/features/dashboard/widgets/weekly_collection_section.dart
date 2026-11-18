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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final cardPadding = isMobile ? 12.0 : 16.0;

        return Card(
          color: AppColors.surfaceLight,
          elevation: 1.0,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedMd,
            side: const BorderSide(color: AppColors.borderLight),
          ),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title & Week Controls
                _buildHeader(theme),
                const SizedBox(height: 12.0),

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
                  // Week Summary Bar (Responsive KPI tiles)
                  _buildWeekSummaryBar(theme),
                  const SizedBox(height: 14.0),

                  // Weekday Cards Selector (Monday — 12 customers, Tuesday — 8 customers...)
                  _buildWeekdaySelectorRow(theme),
                  const SizedBox(height: 14.0),

                  // Selected Weekday Installment List
                  _buildSelectedDayDetail(theme),
                ],
              ],
            ),
          ),
        );
      },
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
                    'Grouped by weekday for scheduled installments',
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
                  minimumSize: const Size(34, 34),
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
                  minimumSize: const Size(34, 34),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 460;

        Widget buildTile(String label, String value, IconData icon, Color color, Color bgColor) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6.0),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 15.0, color: color),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1.0),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (isNarrow) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: buildTile(
                      'Due Customers',
                      '${_data!.totalWeeklyCustomers}',
                      Icons.people_alt_outlined,
                      AppColors.primary,
                      AppColors.primaryContainer.withValues(alpha: 0.25),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: buildTile(
                      'Total Collected',
                      CurrencyFormatter.format(_data!.totalWeeklyCollected),
                      Icons.check_circle_outline_rounded,
                      AppColors.success,
                      AppColors.successContainer.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6.0),
              buildTile(
                'Total Scheduled for Week',
                CurrencyFormatter.format(_data!.totalWeeklyAmountDue),
                Icons.payments_outlined,
                AppColors.primaryDark,
                AppColors.backgroundLight,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: buildTile(
                'Due Customers',
                '${_data!.totalWeeklyCustomers}',
                Icons.people_alt_outlined,
                AppColors.primary,
                AppColors.primaryContainer.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: buildTile(
                'Total Scheduled',
                CurrencyFormatter.format(_data!.totalWeeklyAmountDue),
                Icons.payments_outlined,
                AppColors.primaryDark,
                AppColors.backgroundLight,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: buildTile(
                'Total Collected',
                CurrencyFormatter.format(_data!.totalWeeklyCollected),
                Icons.check_circle_outline_rounded,
                AppColors.success,
                AppColors.successContainer.withValues(alpha: 0.25),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeekdaySelectorRow(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
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
                width: 128.0,
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
                            ? AppColors.primary.withValues(alpha: 0.35)
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
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        '${group.customerCount} ${group.customerCount == 1 ? "customer" : "customers"}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (hasCustomers ? AppColors.primary : AppColors.textMutedLight),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5.0),
                    Text(
                      CurrencyFormatter.format(group.totalDue),
                      style: TextStyle(
                        fontSize: 12.0,
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
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Sub-header with responsive layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 400;

              final titlePart = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.event_available_rounded, size: 18.0, color: AppColors.primary),
                  const SizedBox(width: 6.0),
                  Text(
                    '${group.weekday} Collections',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      '${group.customerCount}',
                      style: const TextStyle(
                        fontSize: 11.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              );

              final totalDueBadge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Total Due: ${CurrencyFormatter.format(group.totalDue)}',
                  style: const TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titlePart,
                    const SizedBox(height: 6.0),
                    totalDueBadge,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titlePart),
                  const SizedBox(width: 8.0),
                  totalDueBadge,
                ],
              );
            },
          ),
          const SizedBox(height: 10.0),

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
    String formattedDueDate;
    try {
      final dt = DateTime.parse(item.dueDate);
      formattedDueDate = DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      formattedDueDate = item.dueDate;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4.0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Avatar, Customer Name & Phone on Left, Status Badge on Right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 18.0,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    item.customerName.isNotEmpty ? item.customerName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),

                // Name & Contact
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.customerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
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
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          if (item.planCode.isNotEmpty) ...[
                            const SizedBox(width: 6.0),
                            Flexible(
                              child: Text(
                                '• ${item.planCode}',
                                style: const TextStyle(
                                  fontSize: 11.0,
                                  color: AppColors.textMutedLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),

                // Status Badge
                _buildStatusBadge(item.status),
              ],
            ),

            const SizedBox(height: 10.0),
            const Divider(height: 1.0, color: AppColors.borderLight),
            const SizedBox(height: 10.0),

            // Row 2: Due Date & Week on Left, Installment Due & Outstanding Balance on Right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Column: Due date & week
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 12.0, color: AppColors.textSecondaryLight),
                          const SizedBox(width: 4.0),
                          Text(
                            'Due: $formattedDueDate',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Text(
                          'Week #${item.installmentNumber}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMutedLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8.0),

                // Right Column: Weekly Installment Amount & Outstanding Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Due: ',
                          style: TextStyle(
                            fontSize: 11.0,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(item.installmentAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Bal: ',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(item.outstandingBalance),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: item.outstandingBalance > 0 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
